--AVALON SLAVE 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

Entity avalonslave is

Port(

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
 Status: IN STD_LOGIC_VECTOR(1 downto 0);
 DMA_ack: IN STD_LOGIC_VECTOR(31 downto 0);

-- To Camera Interface : 
 Cmd : Out STD_LOGIC;
 StartCam : OUT STD_LOGIC;
 Status_pw : IN std_logic_vector(1 downto 0);
 camdata_ack:IN std_logic_vector(31 downto 0)
);
end avalonslave;

architecture comp of avalonslave is

signal iRegAdr : STD_LOGIC_VECTOR(31 downto 0);
signal iRegLength : STD_LOGIC_VECTOR(31 downto 0);
signal iRegStart: STD_LOGIC;
signal iRegCmd: STD_LOGIC;
signal iRegStatus: STD_LOGIC_VECTOR(1 downto 0);
signal iRegStatus_pw: STD_LOGIC_VECTOR(1 downto 0);

signal cycleCnt : natural;
constant cycleCntMax : natural := 15000; 

signal iRegDMA_ack: STD_LOGIC_VECTOR(31 downto 0);
signal icamdata_ack: STD_LOGIC_VECTOR(31 downto 0);
begin

   process(clk, Reset_n)
   begin
        if Reset_n = '0' then
            cycleCnt <= 0;
        elsif rising_edge(clk) then
            if iRegStart = '1' then
                cycleCnt <= cycleCnt + 1;
            end if;
            if cycleCnt = cycleCntMax then
                cycleCnt <= 0;
            end if;
        end if;
   end process;


   process(clk, Reset_n)
	begin
	if Reset_n = '0' then
		iRegAdr <= (others => '0');
		iRegLength <= (others => '0');
		iRegStart <='0';
		iRegCmd <= '0';

	elsif rising_edge(clk) then
	    if cycleCnt = cycleCntMax then
	        iRegStart <= '0';   --reset iRegStart after it has been catched by camInterface
	    end if;
	    if write = '1' then
			case Address is
				when "000" => iRegAdr <= writedata;
				when "001" => iRegLength <= writedata;
				when "010" => iRegStart <= writedata(0);
				when "011" => iRegCmd <= writedata(0);
				when others => null;
			end case;
		end if;
	end if;
    end process;

-- Avalon slave read from registers.
    process(clk)
	begin
	if rising_edge(clk) then
		readdata <= (others => '0');
		if read = '1' then
			case address is
				when "000" => readdata <=iRegAdr ;
				when "001" => readdata <=iRegLength ;
				when "010" => readdata(0) <=iRegStart ;
				when "011" => readdata(0) <=iRegCmd ;
				when "100" => readdata(1 downto 0) <=iRegStatus ;
				when "101" => readdata(1 downto 0) <=iRegStatus_pw;
				when "110" => readdata <=icamdata_ack;
				when "111" => readdata <=iRegDMA_ack;
				when others => null;
			end case;
		end if;
	end if;
    end process;


    process(clk)
    begin 
        if rising_edge(clk) then
            -- outputs : 
            AS_Adr <= iRegAdr;
            AS_Length <= iRegLength;
            Start <= iRegStart;
            StartCam <= iRegStart;
            Cmd <= iRegCmd;

            iRegStatus <= Status;   
            iRegDMA_ack <= DMA_ack;              
            icamdata_ack<=camdata_ack;             
            	                      
            iRegStatus_pw <= Status_pw;
        end if;
    end process;
end comp;
 
