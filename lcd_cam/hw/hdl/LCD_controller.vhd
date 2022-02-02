library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LCD_controller is
	port(
		-- System signals
		clk		: in std_logic;
		reset_n	: in std_logic;
		
		--Avalon Slave signals
		avs_address				: in  std_logic_vector(1 downto 0):="00";
		avs_write				: in  std_logic:='0';
		avs_writedata				: in  std_logic_vector(31 downto 0):=(others => '0');
		avs_read				: in  std_logic:='0';
		avs_waitrequest				: out  std_logic:='0';
		avs_readdata				: out std_logic_vector(31 downto 0);

		--Avalon Master signals
		avm_address				: out std_logic_vector(31 downto 0);
		avm_read				: out std_logic;
		avm_readdata				: in  std_logic_vector(31 downto 0):=(others => '0');
		avm_waitrequest				: in  std_logic := '0';
		avm_byteenable	   			: out std_logic_vector(3 downto 0);
		avm_burstcount				: out std_logic_vector(5 downto 0);
		avm_readdatavalid			: in  std_logic := '0';
		
		-- ILI9341 communication signals	(8080 I interface)
		csx		: out std_logic;
		dcx		: out std_logic;
		wrx		: out std_logic;
		data		: out std_logic_vector(15 downto 0);
		
		-- LT24 global signals, registered outputs
		LCD_on		: out std_logic;
		LCD_resn	: out std_logic
		
		);
end LCD_controller;

architecture struct of LCD_controller is
	
	-- Interconnection signals
	-- FIFO

	signal ififo_data_in			: std_logic_vector(31 DOWNTO 0);
	signal ififo_data_out			: std_logic_vector(15 DOWNTO 0);
	signal ififo_wrreq			: std_logic;
	signal ififo_rdreq			: std_logic;
	signal ififo_wrusedw			: std_logic_vector (10 DOWNTO 0);
	signal ififo_rdusedw			: std_logic_vector (11 DOWNTO 0);
	signal ififo_sclr			: std_logic;

	--Register
		--For lt24
	signal iReg_dcx				: std_logic;
	signal iReg_start_command		: std_logic;
	signal iReg_sending_command		: std_logic;
	signal iReg_LCD_on_in			: std_logic;
	signal iReg_LCD_resn_in			: std_logic;
	signal iReg_data_reg			: std_logic_vector(15 downto 0);
	signal iReg_reset_lcd			: std_logic;
	signal iReg_command_data		: std_logic;
	signal iReg_continue			: std_logic;

		--For DMA
	signal iReg_start			: std_logic:='0';
	signal iReg_running			: std_logic:='0';
	signal iReg_start_address		: std_logic_vector(31 downto 0);
	signal iReg_burstcount			: unsigned(5 downto 0);
	signal iReg_frame_length		: unsigned(16 downto 0);
	
	component LT24_controller
		port(

		-- System signals
			clk				: in std_logic;
			res_n				: in std_logic;

		-- Registers signals
			dcx_in				: in std_logic;
			start_command			: in std_logic;
			sending_command			: out std_logic;
			LCD_on_in			: in std_logic;
			LCD_resn_in			: in std_logic;
			data_reg			: in std_logic_vector(15 downto 0);
			reset_lcd			: in std_logic;
			command_data			: in std_logic;
			continue 			: in std_logic;

		-- FIFO signals
			fifo_data			: in std_logic_vector(15 downto 0);
			useddw				: in unsigned(11 downto 0);
			rd_req				: out std_logic;

		-- IL8080
			csx				: out std_logic;
			dcx_out				: out std_logic;
			wrx				: out std_logic;
			data				: out std_logic_vector(15 downto 0);

		-- LT24 global signals, registered outputs
			LCD_on_out			: out std_logic;
			LCD_resn_out			: out std_logic
	
		);
	end component;
	
	component DMA_LCD
		port(
			clk				: in  std_logic;
			res_n				: in  std_logic;
		
		--Avalon Slave signals
			start				: in  std_logic:='0';
			running				: out  std_logic:='0';
			start_address			: in  std_logic_vector(31 downto 0);
			burstcount			: in  unsigned(5 downto 0);
			frame_length			: in  unsigned(16 downto 0);
 
		--Avalon Master signals
			am_addr				: out std_logic_vector(31 downto 0);
			am_read				: out std_logic;
			am_readdata			: in  std_logic_vector(31 downto 0):=(others => '0');
			am_waitrequest			: in  std_logic := '0';
			am_byteenable	   		: out std_logic_vector(3 downto 0);
			am_burstcount			: out std_logic_vector(5 downto 0);
			am_readdatavalid		: in  std_logic:='1';
		
		--FIFO signals
			data				: out std_logic_vector(31 downto 0);
			wrreq				: out std_logic;
			sclr				: out std_logic;
			wrusedw				: in unsigned (10 DOWNTO 0) 
		);
	end component;
	
	component FIFO
		PORT(
			aclr		: IN STD_LOGIC  := '0';
			data		: IN STD_LOGIC_VECTOR (31 DOWNTO 0);
			rdclk		: IN STD_LOGIC ;
			rdreq		: IN STD_LOGIC ;
			wrclk		: IN STD_LOGIC ;
			wrreq		: IN STD_LOGIC ;
			q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
			rdusedw		: OUT STD_LOGIC_VECTOR (11 DOWNTO 0);
			wrusedw		: OUT STD_LOGIC_VECTOR (10 DOWNTO 0)
		);
	END component;
	
	component registers
		port(
			clk					: in  std_logic;
			res_n					: in  std_logic;
		
			--Registers
			dcx				: out  std_logic:='0';
			start_command			: out  std_logic:='0';
			sending_command			: in  std_logic:='0';
			reset_LCD			: out  std_logic:='0';
			LCD_on				: out  std_logic:='0';
			LCD_resn			: out  std_logic:='0';
			start_master			: out  std_logic:='0';
			running_master			: in  std_logic:='0';
			burstcount			: out  unsigned(5 downto 0);
			command_data			: out std_logic;
			continue 			: out std_logic;
			data_reg			: out  std_logic_vector(15 downto 0);
			start_address			: out  std_logic_vector(31 downto 0);
			frame_length			: out  unsigned(16 downto 0);
 
			--Avalon Slave signals
			as_address			: in std_logic_vector(1 downto 0);
			as_write			: in std_logic;
			as_writedata			: in  std_logic_vector(31 downto 0):=(others => '0');
			as_read				: in std_logic;
			as_waitrequest				: out std_logic;
			as_readdata			: out  std_logic_vector(31 downto 0):=(others => '0')
		);
	end component;
	
	begin
		
		
		register_inst : registers
 			port map(
				clk => clk,					
				res_n => reset_n,					
		
				--Registers
				dcx => iReg_dcx,				
				start_command => iReg_start_command,		
				sending_command => iReg_sending_command,		
				reset_LCD => iReg_reset_lcd,	
				LCD_on => iReg_LCD_on_in,					
				LCD_resn => iReg_LCD_resn_in,	
				start_master => iReg_start,
				running_master => iReg_running,		
				burstcount => iReg_burstcount,	
				command_data => iReg_command_data,
				continue => iReg_continue,	
				data_reg => iReg_data_reg,		
				start_address => iReg_start_address,		
				frame_length => iReg_frame_length,			
 
				--Avalon Slave signals
				as_address => avs_address,
				as_write => avs_write,
				as_writedata => avs_writedata,
				as_read => avs_read,
				as_waitrequest => avs_waitrequest,
				as_readdata => avs_readdata
		);
		LT24_controller_inst: LT24_controller
			port map(
				-- System signals
				clk => clk,				
				res_n => reset_n,
				
				-- Registers signals
				dcx_in => iReg_dcx,					
				start_command => iReg_start_command,				
				sending_command => iReg_sending_command,	
				LCD_on_in => iReg_LCD_on_in,	
				LCD_resn_in =>	iReg_LCD_resn_in,	
				data_reg => iReg_data_reg,		
				reset_lcd => iReg_reset_lcd,		
				command_data => iReg_command_data,
				continue => iReg_continue,

				-- FIFO signals
				fifo_data => ififo_data_out,		
				useddw	=> unsigned(ififo_rdusedw),			
				rd_req	=> ififo_rdreq,	

				-- IL8080
				csx => csx,		
				dcx_out	=> dcx,	
				wrx => wrx,			
				data => data,		

				-- LT24 global signals, registered outputs
				LCD_on_out => LCD_on,		
				LCD_resn_out => LCD_resn			
	
			);
			
		Master_DMA_inst: DMA_LCD
			port map(
				clk => clk,			
				res_n => reset_n,		
		
				--Avalon Slave signals
				start	=> iReg_start,				
				running	=> iReg_running,			
				start_address =>iReg_start_address,		
				burstcount => iReg_burstcount,			
				frame_length => iReg_frame_length,			
 
				--Avalon Master signals
				am_addr	=> avm_address,			
				am_read	=> avm_read,			
				am_readdata => avm_readdata,			
				am_waitrequest => avm_waitrequest,			
				am_byteenable => avm_byteenable,	   		
				am_burstcount => avm_burstcount,			
				am_readdatavalid => avm_readdatavalid,		
		
				--FIFO signals
				sclr => ififo_sclr,
				data =>	ififo_data_in,			
				wrreq => ififo_wrreq,				
				wrusedw => unsigned(ififo_wrusedw)				 
			);
		
		FIFO_inst: FIFO
			port map
			(
				aclr    => ififo_sclr,
				data 	=> ififo_data_in,
				rdclk	=> clk,	
				rdreq	=> ififo_rdreq,		
				wrclk	=> clk,	
				wrreq	=> ififo_wrreq,	
				q	=> ififo_data_out,			
				rdusedw	=> ififo_rdusedw,		
				wrusedw => ififo_wrusedw		
					
			);
			
end architecture struct;