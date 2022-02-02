--CameraCRTL 
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity cameraCTRL is 
   port(
	--global signal
	CTRLclk : IN STD_LOGIC;
	CTRLn_Reset: IN STD_LOGIC;

    --signal from the camera 
	CTRLCamPixel : IN STD_LOGIC_VECTOR(11 downto 0);
	CTRLLVal : IN STD_LOGIC;
	CTRLFVal : IN STD_LOGIC;
	CTRLPixClk : IN STD_LOGIC; 
	CTRLMClk : OUT STD_LOGIC;
	CTRLcamReset_n : out STD_LOGIC; 
	CTRLtrigger : out std_logic; 

	--Signal for the avalon slave  
	CTRLaddress : IN STD_LOGIC_VECTOR(2 downto 0);
	CTRLwrite : IN STD_LOGIC;
	CTRLread : IN STD_LOGIC;
	CTRLwritedata : IN STD_LOGIC_VECTOR(31 downto 0);
	CTRLreaddata : OUT STD_LOGIC_VECTOR(31 downto 0);

	--Signal for the avalon master
	CTRLAM_Adr : OUT STD_LOGIC_VECTOR(31 downto 0) ;
	CTRLAM_ByteEnable : OUT STD_LOGIC_VECTOR(3 downto 0) ;
	CTRLAM_Write : OUT STD_LOGIC ;
 	CTRLAM_DataWrite : OUT STD_LOGIC_VECTOR(31 downto 0) ;
 	CTRLAM_WaitRequest : IN STD_LOGIC;
 	CTRLAM_BurstCount : OUT STD_LOGIC_VECTOR(4 downto 0)
    );
end entity;

architecture struct of cameraCTRL is

	-- Avalon Slave 
	component avalonslave
	port(
	    --GLobal Signal
     	Clk : IN STD_LOGIC ;
     	Reset_n : IN STD_LOGIC ;

	    -- INTERNAL INTERFACE 
	    address : IN STD_LOGIC_VECTOR(2 downto 0);
	    write : IN STD_LOGIC;
	    read : IN STD_LOGIC;
	    writedata : IN STD_LOGIC_VECTOR(31 downto 0);
	    readdata : OUT STD_LOGIC_VECTOR(31 downto 0);


	    --EXTERNAL INTERFACE

	    -- To Avalon master:
     	AS_Adr : OUT STD_LOGIC_VECTOR(31 downto 0);
     	AS_Length : OUT STD_LOGIC_VECTOR(31 downto 0);
     	Start : OUT STD_LOGIC ;
     	Status : IN STD_LOGIC_VECTOR(1 downto 0);
	    DMA_ack: IN STD_LOGIC_VECTOR(31 downto 0);
	    -- To Camera Interface : 
     	Cmd : Out STD_LOGIC;
     	StartCam : OUT STD_LOGIC;
	    status_pw : in std_logic_vector(1 downto 0);
	    camdata_ack: in std_logic_vector(31 downto 0)
	);
	end component; 
	
	component DMA
	port(
	    --GLobal Signal
	    Clk : IN STD_LOGIC ;
     	Reset_n : IN STD_LOGIC ;

	    -- Fifo
     	fifo_data : IN STD_LOGIC_VECTOR(31 downto 0) ;
     	fifo_rdusedw : IN STD_LOGIC_VECTOR(7 downto 0) ;
     	fifo_rdreq : OUT STD_LOGIC ;

	    -- Avalon Slave :
     	AS_Adr : IN STD_LOGIC_VECTOR(31 downto 0);
     	AS_Length : IN STD_LOGIC_VECTOR(31 downto 0);
     	Start : IN STD_LOGIC ;
     	Status : OUT STD_LOGIC_VECTOR(1 downto 0) ;
     	DMA_ack: OUT STD_LOGIC_VECTOR(31 downto 0);

	    -- Avalon Master :
	    AM_Adr : OUT STD_LOGIC_VECTOR(31 downto 0) ;
     	AM_ByteEnable : OUT STD_LOGIC_VECTOR(3 downto 0) ;
     	AM_Write : OUT STD_LOGIC ;
     	AM_DataWrite : OUT STD_LOGIC_VECTOR(31 downto 0) ;
     	AM_WaitRequest : IN STD_LOGIC;
     	AM_BurstCount : OUT STD_LOGIC_VECTOR(4 downto 0)
	);
	end component; 

	--DC Fifo
	component DCFIFO_32bits
	port(
	    data: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
	    rdclk: IN STD_LOGIC ;
	    rdreq: IN STD_LOGIC ;
	    wrclk: IN STD_LOGIC ;
	    wrreq: IN STD_LOGIC ;
	    q: OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
	    rdusedw	: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
	);
	end component; 

	
	--component camera_interface
	component cameraInterface
	port(
        clk : in std_logic; --used for XCLKIN
        nReset : in std_logic; 
        
        --Camera signals
        D : in std_logic_vector(11 downto 0);      --pixel data
        FVAL : in std_logic;                       --frame valid
        LVAL : in std_logic;                       --line valid
        PIXCLK : in std_logic;                     --pixel clock  
        camReset_n : out std_logic;                --camera reset
        XCLKIN : out std_logic;                    --camera clock
        TRIGGER : out std_logic;
        
        --avalon slave
        start : in std_logic;                      --start catching a frame
        power : in std_logic;                      -- 1: ON ; 0: 0FF
        status_pw : out std_logic_vector(1 downto 0);
        camdata_ack: out std_logic_vector(31 downto 0);  
        
        -- DC FIFO
        DCFIFO_wrreq : out std_logic;              --write request
        pxRGB : out std_logic_vector(15 downto 0)  --16 bit RGB pixel
	);
	end component;

	--camera interface/DC_fifo
	signal iPixelRGB : STD_LOGIC_VECTOR(15 downto 0);
	signal iDC_wreq : STD_LOGIC;

	--DC fifo/DMA
	signal iData2pix : STD_LOGIC_VECTOR(31 downto 0);
	signal iDC_rdusedw : STD_LOGIC_VECTOR(7 downto 0);
	signal iDC_rdreq: STD_LOGIC;
	
	--DMA/avalon slave
	signal iStartAdress: STD_LOGIC_VECTOR(31 downto 0);
	signal iLengthAdr: STD_LOGIC_VECTOR(31 downto 0);
	signal iStartCam: STD_LOGIC;
	signal iStartDMA: STD_LOGIC;
	signal iStatusCam: STD_LOGIC_VECTOR(1 downto 0);
	signal iDMA_ack: STD_LOGIC_VECTOR(31 downto 0);

	--Avalon slave/camera
	signal iCmdCam: STD_LOGIC; 
	signal iStatus_PW: STD_LOGIC_VECTOR(1 downto 0);
	signal icamdata_ack: STD_LOGIC_VECTOR(31 downto 0);
	
begin

	iDMA : DMA PORT MAP(
		Clk	=>	CTRLclk,
		Reset_n =>	CTRLn_Reset,
		
		-- Fifo
 		fifo_data=>	iData2pix,
		fifo_rdusedw =>	iDC_rdusedw,
 		fifo_rdreq =>	iDC_rdreq,

		-- Avalon Slave :
 		AS_Adr =>	iStartAdress,
 		AS_Length =>	iLengthAdr,
 		Start  =>	iStartDMA,
 		Status =>	iStatusCam,
 		DMA_ack =>	iDMA_ack,	
		AM_Adr =>	CTRLAM_Adr,
 		AM_ByteEnable =>CTRLAM_ByteEnable,
 		AM_Write =>	CTRLAM_Write,
 		AM_DataWrite =>	CTRLAM_DataWrite,
 		AM_WaitRequest =>CTRLAM_WaitRequest,
 		AM_BurstCount =>CTRLAM_BurstCount

	);

	DCFIFO_32bits_inst : DCFIFO_32bits PORT MAP (
		data	 => 	iPixelRGB,
		rdclk	 => 	CTRLclk,  
		rdreq	 => 	iDC_rdreq,
		wrclk	 => 	CTRLPixClk,
		wrreq	 => 	iDC_wreq,
		q	 => 	    iData2pix,
		rdusedw	 => 	iDC_rdusedw
	);

	iAvalonSlave : avalonslave PORT MAP(
		--GLobal Signal
 		Clk  =>		CTRLclk,
 		Reset_n  =>	CTRLn_Reset,

		-- INTERNAL INTERFACE 
		address  =>	CTRLaddress,
		write  =>	CTRLwrite,
		read  =>	CTRLread, 
		writedata  =>	CTRLwritedata,
		readdata  =>	CTRLreaddata,

		--EXTERNAL INTERFACE
		-- To Avalon master:
 		AS_Adr  =>	iStartAdress,
 		AS_Length  =>	iLengthAdr,
 		Start  =>	iStartDMA,
 		Status =>	iStatusCam,
		DMA_ack =>	iDMA_ack,
			
		-- To Camera Interface : 
 		Cmd  =>		iCmdCam,
 		StartCam  =>	iStartCam,
		status_pw =>	iStatus_PW,
		camdata_ack=>   icamdata_ack
		
	);

	iCameraInterface : cameraInterface PORT MAP(


		clk =>		CTRLclk,
    	nReset  =>	CTRLn_Reset,
    
   		--Camera signals
    	D =>    	CTRLCamPixel,  	    --pixel data
    	FVAL =>    	CTRLFVal,           --frame valid
    	LVAL  =>    	CTRLLVal,       --line valid
    	PIXCLK  => 	CTRLPixClk,         --pixel clock  
    	camReset_n =>   CTRLcamReset_n, --camera reset
    	XCLKIN =>       CTRLMClk,       --camera clock
    	TRIGGER => CTRLtrigger,
    
    	--avalon slave
    	start =>        iStartCam,       --start catching a frame
    	power =>        iCmdCam,         -- 1: ON ; 0: 0FF
    	status_pw =>	iStatus_PW,
    	camdata_ack=>   icamdata_ack,
    	

	    -- DC FIFO
    	DCFIFO_wrreq  => iDC_wreq ,      --write request
    	pxRGB =>	iPixelRGB	         --16 bit RGB pixel

	);
	

end struct;

