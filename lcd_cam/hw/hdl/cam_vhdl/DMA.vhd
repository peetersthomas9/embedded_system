library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Entity DMA is
Port(
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
 Status: OUT STD_LOGIC_VECTOR(1 downto 0) ;
 DMA_ack: OUT STD_LOGIC_VECTOR(31 downto 0);

-- Avalon Master :
 AM_Adr : OUT STD_LOGIC_VECTOR(31 downto 0) ;
 AM_ByteEnable : OUT STD_LOGIC_VECTOR(3 downto 0) ;
 AM_Write : OUT STD_LOGIC ;
 AM_DataWrite : OUT STD_LOGIC_VECTOR(31 downto 0) ;
 AM_WaitRequest : IN STD_LOGIC;
 AM_BurstCount : OUT STD_LOGIC_VECTOR(4 downto 0)
) ; 

end DMA;

Architecture Comp of DMA is

TYPE AcqState IS (Idle, WaitData, WriteData);

Signal CntAddress: STD_LOGIC_VECTOR(31 downto 0);
Signal CntLength: UNSIGNED(31 downto 0);
signal CntBurst: UNSIGNED(31 downto 0);
Signal State: AcqState; 

signal wait_rdreq : std_logic;
signal ififo_rdreq : std_logic;
signal writedata_init : std_logic;

Begin 

    DMA_ack <= std_logic_vector(CntLength);
    fifo_rdreq <= ififo_rdreq;
    

    -- Acquisition
    pAcquisition: Process(Clk, Reset_n)
    Begin
     if Reset_n = '0' then
     	State <= Idle;
	    Status <="00";
     	AM_Write <= '0';
     	AM_ByteEnable <= "0000";
     	CntAddress <= (others => '0');
     	CntLength <= (others => '0');
	    CntBurst <= (others => '0');
	    AM_BurstCount <= (others=> '0');
	    ififo_rdreq <= '0';
	    AM_Adr <= (others=> '0');
	    AM_DataWrite <= (others=> '0');
	    wait_rdreq <= '0';
	    writedata_init <= '0';
     elsif rising_edge(Clk) then
	    case State is 
	        when Idle => 
	        
		        if Start='1' then
			        Status <= "01";                   --'Wait data'
         			State <= WaitData;
			        CntAddress <= AS_Adr;
			        CntLength <= unsigned(AS_Length);
		        end if; 

	        when WaitData =>
	            
		        if unsigned(fifo_rdusedw) >= 16 then  --16 data in the FIFO 
			        State <= WriteData;		
			        Status <= "11";                   --'Write data'
			        CntBurst <= to_unsigned(16,32);
			        
			        AM_Write <= '1';
	                AM_ByteEnable <= "1111";
	                AM_Adr <= CntAddress;
	                ififo_rdreq <= '1';               
	                wait_rdreq <= '1';                --before rdreq is 0
	                AM_DataWrite <= fifo_data;
	                AM_BurstCount <= "10000";
	                writedata_init <= '1';
		        end if; 
		        

	        when WriteData =>
	            writedata_init <= '0';
	            if wait_rdreq = '1' then
	                wait_rdreq <= '0';
	                AM_Write <= '1';
	            end if;
	            
	            if CntBurst = 1 then
	                if CntLength = 1 then
	                    State <= Idle;
	                    Status <= "10";
	                else
	                    CntLength <= CntLength - 1;
	                    State <= WaitData;
	                    Status <= "01";               --'Wait data'
	                    CntAddress <= std_logic_vector(unsigned(CntAddress)+64);
	                end if;
	                AM_Write <= '0';
	                AM_ByteEnable <= "0000";
	                ififo_rdreq <= '0';
	                AM_BurstCount <= "00000";
	                
	            elsif AM_WaitRequest = '0' then
	                AM_Write <= '1';
	                if writedata_init = '1' then
	                    AM_Write <= '0';
	                elsif wait_rdreq = '0' then
	                    AM_ByteEnable <= "1111";
	                    ififo_rdreq <= '1';
	                    AM_DataWrite <= fifo_data;
	                    CntBurst <= CntBurst-1; 
	                    AM_BurstCount <= "10000";
	                    if ififo_rdreq = '0' then
	                        wait_rdreq <= '1';
	                        AM_Write <= '0';
	                    end if;
	                end if;
	                if CntBurst = 2 then
	                    ififo_rdreq <= '0';
	                end if;
	            else
	                ififo_rdreq <= '0';
	            end if;
     	    end case;
        end if;
    end Process pAcquisition;

end Comp; 

