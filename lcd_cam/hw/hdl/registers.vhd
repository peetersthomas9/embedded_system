library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity registers is
	port(
		clk					: in  std_logic;
		res_n					: in  std_logic;
		
		--Registers
		dcx				: out  std_logic:='0';
		start_command			: out  std_logic:='0';
		sending_command			: in  std_logic:= '0';
		reset_LCD			: out  std_logic:='0';
		LCD_on				: out  std_logic := '0';
		LCD_resn			: out  std_logic:='0';
		start_master			: out  std_logic:='0';
		running_master			: in  std_logic:='0';
		burstcount			: out  unsigned(5 downto 0) := to_unsigned(8,6);
		command_data			: out std_logic := '0';
		continue			: out std_logic:='0';
		data_reg			: out  std_logic_vector(15 downto 0) :=(others => '0');
		start_address			: out  std_logic_vector(31 downto 0) := (others => '0');
		frame_length			: out  unsigned(16 downto 0):= to_unsigned(0,17);
 
		--Avalon Slave signals
		as_address			: in std_logic_vector(1 downto 0) := "00";
		as_write			: in std_logic := '0' ;
		as_writedata			: in  std_logic_vector(31 downto 0):=(others => '0');
		as_read				: in std_logic := '0';
		as_waitrequest		 	: out std_logic := '0';
		as_readdata			: out  std_logic_vector(31 downto 0):=(others => '0')

		
	);
end entity registers;
architecture rtl of registers is
signal icommand_data : std_logic;
signal icontinue : std_logic;
signal idcx : std_logic;
signal istart_command : std_logic;
signal isending_command : std_logic:='0';
signal ireset_LCD : std_logic;
signal iLCD_on	 : std_logic;
signal iLCD_resn : std_logic;
signal istart_master : std_logic;
signal irunning_master : std_logic:='0';
signal iburstcount : std_logic_vector(5 downto 0);
signal idata_reg : std_logic_vector(15 downto 0);
signal iRegAddressRam : std_logic_vector(31 downto 0);
signal iRegFrameLength : std_logic_vector(16 downto 0);
signal reading : std_logic := '0';
signal reading_ready :std_logic :='0';
signal writing_ready : std_logic := '0';

begin
	reading_ready <= '0' when reading = '1' else as_read;
	writing_ready <= '0' when (istart_command = '0' and isending_command = '0') else as_write;
	as_waitrequest <= reading_ready or writing_ready;

	-- Writing process
	process(clk, res_n)
	begin
		
		if res_n = '0' then
			icommand_data <= '0';
			icontinue <= '0';
			idcx <= '0';
			istart_command <= '0';
			ireset_LCD <= '0';
			iLCD_on	 <= '0';
 			iLCD_resn <= '0';
 			istart_master <= '0';
 			iburstcount <= (others => '0');
 			idata_reg <= (others => '0');
			iRegAddressRam <= (others => '0');
			iRegFrameLength <= (others => '0');

		elsif rising_edge(clk) then
			
			if(isending_command = '1') then
				istart_command <='0';
			end if;
			if(irunning_master = '1') then
				istart_master <='0';
			end if;
			if as_write = '1' then
				case as_address is
					--Write the bits according to the register Map
					--Check sending command and running master to avoid modifying their values while they are running
					when "00" => 
						if(isending_command = '0') then
							idcx <= as_writedata(0);
							istart_command <= as_writedata(1);
							ireset_LCD <= as_writedata(3);
			 				iLCD_on	 <= as_writedata(4);
			 				iLCD_resn <= as_writedata(5);
							icommand_data <= as_writedata(14);
							icontinue <= as_writedata(15);
							idata_reg <= as_writedata(31 downto 16);
						end if;
						if(irunning_master = '0') then
			 				istart_master <= as_writedata(6);
			 				iburstcount <= as_writedata(13 downto 8);
						end if;
					when "01" => 
						if(irunning_master = '0') then
			 				iRegAddressRam <= as_writedata;
						end if;
					when "10" => 
						if(irunning_master = '0') then
							iRegFrameLength <= as_writedata(16 downto 0);
						end if;
					when others => null;
				end case;
			end if;
		end if;
	end process;

	-- Reading process
	process(clk)
	begin
		if rising_edge(clk) then
			as_readdata <= (others => '0');
			reading <= '0';
			if as_read = '1' then
				reading <= '1';
				case as_address is
					-- Assign the bits to the readata signal according to the register Map
					when "00" => as_readdata <= idata_reg & icontinue & icommand_data & iburstcount 
									& irunning_master & istart_master & iLCD_resn
									& iLCD_on & ireset_lcd & isending_command & istart_command 
									& idcx;
					when "01" => as_readdata <= iRegAddressRam;
					when "10" => as_readdata <=  (31 downto iRegFrameLength'length => '0') & iRegFrameLength;
					when others => null;
				end case;
			end if;
		end if;
	end process;
	
	-- LT24 process
	process(idcx, icommand_data, istart_command, sending_command, idata_reg, iLCD_on, iLCD_resn, ireset_LCD,icontinue)
	begin
		--Assign the internal signal to the DMA signals
		isending_command <= sending_command;
		continue <= icontinue;
		reset_LCD <= ireset_LCD;
		LCD_on <= iLCD_on;
		LCD_resn <= iLCD_resn;
		data_reg <= idata_reg;
		command_data <= icommand_data;
		dcx <= idcx;
		start_command <= istart_command;	
	end process;

	--  MASTER process
	process(istart_master, running_master, iburstcount, iRegAddressRam, iRegFrameLength)
	begin
		--Assign the internal signal to the DMA signals
		irunning_master <= running_master;
		start_address <= iRegAddressRam;
		frame_length <= unsigned(iRegFrameLength);
		burstcount <= unsigned(iburstcount);
		start_master <= istart_master;	
	end process;

end rtl;
