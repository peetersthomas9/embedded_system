library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity cameraInterface is

    port(
        clk : in std_logic;                        --used for XCLKIN
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
        camdata_ack : out std_logic_vector(31 downto 0);
        -- DC FIFO
        DCFIFO_wrreq : out std_logic;              --write request
        pxRGB : out std_logic_vector(15 downto 0)  --16 bit RGB pixel
        
    );
    
end cameraInterface;

architecture comp of cameraInterface is
    
    --Pixel Counter
    constant pxCntMax : unsigned(18 downto 0) := to_unsigned(307200, 19) ; --pixels per frame 640*480
    constant LINEPX : unsigned(18 downto 0) := to_unsigned(640, 19);       --pixels per line
    --constant pxCntMax : unsigned(18 downto 0) := to_unsigned(80, 19) ;   --test
    --constant LINEPX : unsigned(18 downto 0) := to_unsigned(20, 19);      --test
    
    signal pxCnt : unsigned(18 downto 0);
    signal pxCntOld : unsigned(18 downto 0); 
    
    --FSM
    type fsm_states is (pw_off, pw_on, idle, activate_camReset_up, activate_camReset_down, 
                        deactivate_camReset, activate_xclkin, deactivate_xclkin, wait_frame, 
                        read_RG1line, read_BG2line, wait_endframe);
    signal acq_state, pw_state, acq_next_state, pw_next_state : fsm_states;
    
    signal xclkin_active : std_logic; 
    signal camReset_active : std_logic;
    
    --SCFIFO
    signal scfifo_D : std_logic_vector(11 downto 0); --data in
    signal scfifo_Q : std_logic_vector(11 downto 0); --data out
    signal scfifo_wrreq : std_logic;
    signal scfifo_rdreq : std_logic;
    signal scfifo_clk : std_logic;
    signal scfifo_empty : std_logic;
    signal scfifo_full : std_logic;
    signal scfifo_usedw : std_logic_vector(9 DOWNTO 0);
    
    
    component SCFIFO_12bits
	    port(
		    clock		: IN STD_LOGIC ;
		    data		: IN STD_LOGIC_VECTOR (11 DOWNTO 0);
		    rdreq		: IN STD_LOGIC ;
		    wrreq		: IN STD_LOGIC ;
		    empty		: OUT STD_LOGIC ;
		    full		: OUT STD_LOGIC ;
		    q		: OUT STD_LOGIC_VECTOR (11 DOWNTO 0);
		    usedw		: OUT STD_LOGIC_VECTOR (9 DOWNTO 0)
	    );
	end component SCFIFO_12bits;
                        
    signal regB : std_logic_vector(11 downto 0);
    signal regG1 : std_logic_vector(11 downto 0);
                     
                        

begin

    SCFIFO_12bits_inst : SCFIFO_12bits PORT MAP (
		    clock	 => scfifo_clk,
		    data	 => scfifo_D,
		    rdreq	 => scfifo_rdreq,
		    wrreq	 => scfifo_wrreq,
		    empty	 => scfifo_empty,
		    full	 => scfifo_full,
		    q	     => scfifo_Q,
		    usedw	 => scfifo_usedw
	);
    
    --Power Next State Logic
    PW_NSL: process(pw_state, power) is
    begin
        pw_next_state <= pw_state;
        case pw_state is
            when pw_off =>
                if power = '1' then
                    pw_next_state <= activate_camReset_up;
                end if;
            when activate_camReset_up =>    
                pw_next_state <= activate_xclkin;
            when activate_xclkin =>
                pw_next_state <= deactivate_camReset;
            when deactivate_camReset =>
                pw_next_state <= pw_on;
            when pw_on =>
                if power = '0' then
                    pw_next_state <= activate_camReset_down;
                end if;
            when activate_camReset_down =>    
                pw_next_state <= deactivate_xclkin;
            when deactivate_xclkin =>
                pw_next_state <= pw_off;
            when others =>
                null;
        end case;
    end process PW_NSL;
    
    PW_REG : process(clk, nReset) 
    begin
        if nReset = '0' then
            pw_state <= pw_off;
        elsif rising_edge(clk) then
            pw_state <= pw_next_state;
        end if;
    end process PW_REG;
    
    PW : process(clk, nReset)
    begin
        if nReset = '0' then
            camReset_active <= '0';
            xclkin_active <= '0';
        elsif rising_edge(clk) then
            case pw_state is
                when activate_camReset_up|activate_camReset_down =>
                    camReset_active <= '1';
                when deactivate_camReset =>
                    camReset_active <= '0';
                when activate_xclkin =>
                    xclkin_active <= '1';
                when deactivate_xclkin =>
                    xclkin_active <= '0';
                when others =>
                    null;
            end case;
        end if;
    end process PW;
    
    --Acquisition Next State Logic
    ACQ_NSL: process(acq_state, start, FVAL, LVAL, pxCnt, pxCntOld) is
    begin
        acq_next_state <= acq_state;
        case acq_state is
            when idle =>
                if start = '1' then
                    acq_next_state <= wait_frame;
                end if;  
            when wait_frame =>
                if FVAL = '1' then
                    acq_next_state <= read_RG1line;
                end if; 
            when read_RG1line => 
                if LVAL = '0' and pxCnt = pxCntOld+LINEPX  then 
                    acq_next_state <= read_BG2line;
                end if;
            when read_BG2line =>
                if LVAL = '0' then
                    if pxCnt = pxCntMax then
                        acq_next_state <= wait_endframe;
                    elsif pxCnt = pxCntOld+LINEPX  then 
                        acq_next_state <= read_RG1line;
                    end if;
                end if;
            when wait_endframe =>
                if FVAL = '0' then
                    acq_next_state <= idle;
                end if;
            when others =>
                null;          
        end case;
    end process ACQ_NSL;
    
    ACQ_REG : process(PIXCLK, nReset) 
    begin
        if nReset = '0' then
            acq_state <= idle;
            pxCntOld <= (others => '0');
        elsif rising_edge(PIXCLK) then
            acq_state <= acq_next_state;
            if acq_next_state = read_RG1line and acq_state = wait_frame  then
                pxCntOld <= pxCnt;
            elsif acq_next_state = read_BG2line and acq_state = read_RG1line then
                pxCntOld <= pxCnt;
            elsif acq_next_state = read_RG1line and acq_state = read_BG2line then
                pxCntOld <= pxCnt;    
            end if;
        end if;
    end process ACQ_REG;
            
    --Acquisition
    ACQ : process(PIXCLK, nReset)
    begin
        if nReset = '0' then
            pxCnt <= (others => '0');
            scfifo_rdreq <= '0';
            scfifo_wrreq <= '0';
            DCFIFO_wrreq <= '0';
            regG1 <= (others => '0');
            regB <= (others => '0');
            scfifo_D <= (others => '0');
            pxRGB <= (others => '0'); 

        elsif rising_edge(PIXCLK) then
            scfifo_rdreq <= '0';
            scfifo_wrreq <= '0';
            DCFIFO_wrreq <= '0';
            case acq_state is
                when wait_frame =>
                    pxCnt <= (others => '0');
                when read_RG1line =>
                    if LVAL = '1' then 
                        scfifo_wrreq <= '1';
                        scfifo_D <= D;
                        pxCnt <= pxCnt + 1;
                    end if;
                when read_BG2line =>
                    if LVAL = '1' then
                        if pxCnt(0) = '0' then      --B px
                            scfifo_rdreq <= '1';
                            regG1 <= scfifo_Q;      
                            regB <= D;
                            pxCnt <= pxCnt + 1;
                        else                        --G2 px
                            scfifo_rdreq <= '1';
                            DCFIFO_wrreq <= '1';

			              -- red :
			                pxRGB(15) <= regG1(11) or regG1(10);
			                pxRGB(14 downto 12) <= regG1(9 downto 7); 
			                pxRGB(11) <= regG1(6) or regG1(5);
    
			              -- green : 
			                if resize((unsigned('0'&scfifo_Q) + unsigned('0'&D)) srl (1+11), 1) = 1 or
			                   resize((unsigned('0'&scfifo_Q) + unsigned('0'&D)) srl (1+10), 1) = 1 then 
			                    pxRGB(10) <= '1';
			                else
			                    pxRGB(10) <= '0';
			                end if;
			                
			                pxRGB(9 downto 7) <= std_logic_vector(resize((unsigned('0'&scfifo_Q) + unsigned('0'&D)) srl (1+7), 3));
			            
			                if resize((unsigned('0'&scfifo_Q) + unsigned('0'&D)) srl (1+6), 1) = 1 or
			                   resize((unsigned('0'&scfifo_Q) + unsigned('0'&D)) srl (1+5), 1) = 1 then 
			                    pxRGB(6) <= '1';
			                else
			                    pxRGB(6) <= '0';
			                end if;
			                           
			                if resize((unsigned('0'&scfifo_Q) + unsigned('0'&D)) srl (1+4), 1) = 1 then 
			                    pxRGB(5) <= '1';
			                else
			                    pxRGB(5) <= '0';
			                end if;
			                
			              --blue :
			                pxRGB(4) <= regB(11) or regB(10);
			                pxRGB(3 downto 1) <= regB(9 downto 7);
			                pxRGB(0) <= regB(6) or regB(5);

                            pxCnt <= pxCnt + 1;
                        end if;
                    end if; 
                when others => 
                    null;
            end case;
        end if;
    end process ACQ;
    
    scfifo_clk <= PIXCLK;
    
    
    camReset_n <= '0' when camReset_active = '1' else
                  '1';
    
    XCLKIN <= clk when xclkin_active = '1' else
              '0';
    
    status_pw <= "00" when pw_state = pw_off else           --powered down
                 "01" when pw_state = pw_on else            --powered up
                 "10";                                      --powering
                 
    camdata_ack(18 downto 0) <= std_logic_vector(pxCnt);
    
    camdata_ack(28 downto 19) <= "0000000000";              --unused
    
    camdata_ack(31 downto 29) <= "000" when acq_state = idle else
                                 "001" when acq_state = wait_frame else
                                 "010" when acq_state = read_RG1line else
                                 "011" when acq_state = read_BG2line else
                                 "100" when acq_state = wait_endframe else
                                 "111";
    
    TRIGGER <= '1';
                                         
              
    
end comp ;
