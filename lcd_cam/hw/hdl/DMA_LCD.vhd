library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity DMA_LCD is
	port(
		clk					: in  std_logic;
		res_n					: in  std_logic := '1';
		
		--Avalon Slave signals
		start				: in  std_logic:='0';
		running				: out  std_logic:='0';
		start_address			: in  std_logic_vector(31 downto 0) := (others => '0');
		burstcount			: in  unsigned(5 downto 0):= to_unsigned(0,6);
		frame_length			: in  unsigned(16 downto 0):= to_unsigned(0,17);
 
		--Avalon Master signals
		am_addr				: out std_logic_vector(31 downto 0):= (others => '0');
		am_read				: out std_logic:='0';
		am_readdata			: in  std_logic_vector(31 downto 0):=(others => '0');
		am_waitrequest			: in  std_logic := '0';
		am_byteenable	   		: out std_logic_vector(3 downto 0):= "1111";
		am_burstcount			: out std_logic_vector(5 downto 0):= "001000";
		am_readdatavalid		: in  std_logic:='0';
		
		--FIFO signals
		data				: out std_logic_vector(31 downto 0):= (others => '0');
		wrreq				: out std_logic:='0';
		sclr				: out std_logic := '1';
		wrusedw				: in unsigned (10 DOWNTO 0)
	);
end entity DMA_LCD;
architecture behave of DMA_LCD is
	signal burst_counter : unsigned(5 downto 0):= to_unsigned(0,6);
	signal frame_counter : unsigned(16 downto 0):= to_unsigned(0,17);
	type State_type IS (RESET, IDLE, WAIT_READ,READ_STATE, CHECK_FRAME);  -- Define the states
	signal State, next_state : State_Type;    -- Create a signal that take the different states
	signal icounter_address: unsigned(31 downto 0) := to_unsigned(0,32) ;
	constant sizeMax : integer := 2040; -- sizeMax to simulate almost full signal
begin

data <= am_readdata;

process(clk, res_n) 
-- At each clock cycle next_state is assigned to state
-- https://vhdlguide.readthedocs.io/en/latest/vhdl/fsm.html

    begin
        if (res_n = '0') then -- go to state zero if reset	
            state <= RESET;

        elsif rising_edge(clk) then  --otherwise update the states
            	state <= next_state;
        else
            null;
        end if; 
end process;

process(state, start, am_waitrequest, am_readdatavalid, wrusedw, burst_counter,
        frame_counter, burstcount, icounter_address, frame_length)
    begin 

	-- default values 
	am_read <= '0';
	running <= '0';
	wrreq <= '0';
	sclr <= '0';
	
	am_addr <= (others =>'0');
	am_burstcount <= (others => '0');
	
	case state is 
        	when RESET =>
			running <= '0';
                	next_state <= IDLE;
			sclr <= '1';

            	when IDLE =>
			-- Wait until start signal is send
			running <= '0'; -- Say to Register that it finishe
			if start = '1' then --if start is asserted it begins
				next_state <= WAIT_READ;

			else
				next_state <= IDLE;

			end if;

		when WAIT_READ =>
			running <= '1'; -- Say to Register that it began

			if wrusedw < sizeMax then  -- if FIFO not almost full go to read
				am_read <= '1';
				am_addr <= std_logic_vector(icounter_address);
				am_burstcount <= std_logic_vector(burstcount);
			end if;
			if am_waitrequest = '1' then
				next_state <= WAIT_READ;
			elsif wrusedw > sizeMax then
				next_state <= WAIT_READ;
			else 
				next_state <= READ_STATE;
			end if;
					
		when READ_STATE=>
			-- read until burstcount and go to check if frame is finished
			-- wrreq is active is following readatavalid since they have to be asserted at the same time
			running <= '1';
			wrreq <= am_readdatavalid;
			if burst_counter = burstcount then
					wrreq <= '0';
					next_state <= CHECK_FRAME;
				else
					next_state <= READ_STATE;
				end if;
				
		when CHECK_FRAME=>
			-- Check if we have read a entire frame or not, if yes go to idle
			-- else go back to wait read
			
			running <= '1';

			if frame_counter >= frame_length - 8 then
				next_state <= IDLE;

			else
				next_state <= WAIT_READ;
			end if;

		when others=>
			null;
	end case; 
end process;

am_byteenable <="1111";

process(clk, res_n) 
-- At each clock cycle next_state is assigned to state
-- https://vhdlguide.readthedocs.io/en/latest/vhdl/fsm.html

    begin
	if rising_edge(clk) then
		case state is 
			when IDLE =>
				-- Initialise the counters
				frame_counter <= to_unsigned(0, frame_counter'length);
				burst_counter <= to_unsigned(0, burst_counter'length);
				icounter_address <= unsigned(start_address);
			when WAIT_READ =>
				burst_counter <= to_unsigned(0, burst_counter'length);
			when READ_STATE =>
				if am_readdatavalid = '1' then
					-- if a data has been read increment burstcount
					burst_counter <= burst_counter + to_unsigned(1, burst_counter'length);
				end if;
			when CHECK_FRAME =>
				frame_counter <= frame_counter + burstcount;
				icounter_address <= icounter_address + 4*burstcount;
			when others=>
				null;
		end case;
	end if;
end process;



end architecture behave;
