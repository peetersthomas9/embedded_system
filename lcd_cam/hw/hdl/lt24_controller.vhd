
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity LT24_controller is
	port(

		-- System signals
		clk			: in std_logic;
		res_n		: in std_logic;

		-- Registers signals
		dcx_in				: in std_logic;
		start_command			: in std_logic;
		sending_command			: out std_logic;
		LCD_on_in			: in std_logic;
		LCD_resn_in			: in std_logic;
		data_reg			: in std_logic_vector(15 downto 0);
		reset_lcd			: in std_logic;
		command_data			: in std_logic;
		continue			: in std_logic;

		-- FIFO signals
		fifo_data	: in std_logic_vector(15 downto 0);
		useddw		: in unsigned(11 downto 0);
		rd_req		: out std_logic;

		-- IL8080
		csx				: out std_logic;
		dcx_out		: out std_logic;
		wrx				: out std_logic;
		data			: out std_logic_vector(15 downto 0);

		-- LT24 global signals, registered outputs
		LCD_on_out			: out std_logic;
		LCD_resn_out		: out std_logic

	);
end entity LT24_controller;
architecture rtl of LT24_controller is
	signal counter		: unsigned(16 downto 0);
	type State_type IS (RESET, WAIT_DCX, LOAD_COMMAND, LOAD_DATA, WAIT_COMMAND_1,
				WAIT_COMMAND_2,WAIT_COMMAND_3, WAIT_LOAD_1,WAIT_LOAD_2,WAIT_LOAD_3);  -- Define the states
	signal State, next_state : State_Type;    -- Create a signal that uses
							      -- the different states
	constant FRAME_LENGTH	: integer := 76800;
begin

process(clk, res_n)
-- At each clock cycle next_state is assigned to state
-- https://vhdlguide.readthedocs.io/en/latest/vhdl/fsm.html

    begin
        if (res_n = '0') then -- go to state zero if reset
        	State <= RESET;

        elsif (clk'event and clk = '1') then -- otherwise update the states
            state <= next_state;
        else
            null;
        end if;
    end process;

  --Next state FSM
  process(state, start_command, command_data, dcx_in, data_reg, useddw, fifo_data, reset_lcd, counter)
    begin
        -- store current state as next
        next_state <= state; --required: when no case statement is satisfied
	sending_command <= '0';
        case state is
		when RESET =>
			sending_command <= '1';
           		next_state <= WAIT_DCX;

            	when WAIT_DCX =>
			--csx <= '1';
			sending_command <= '0';
	        	if start_command = '1' and command_data = '0' then
		 	   	if reset_lcd = '1' then
					sending_command <= '1';
					next_state <= RESET;
				else
					sending_command <= '1';
	        			next_state <= LOAD_COMMAND;
				end if;
			elsif useddw /= to_unsigned(0,useddw'length) and command_data = '1' then
		 		next_state <= LOAD_DATA;
			else
				null;
                	end if;
		when LOAD_COMMAND =>
			--csx <= '0';
			--dcx_out <= dcx_in;
			--wrx <= '0';
			--data <= data_reg;
			sending_command <= '1';
			next_state <= WAIT_COMMAND_1;
		when WAIT_COMMAND_1=>
			sending_command <= '1';
			next_state <= WAIT_COMMAND_2;
		when WAIT_COMMAND_2=>
			--wrx <= '1';
			sending_command <= '1';
			next_state <= WAIT_COMMAND_3;
		when WAIT_COMMAND_3=>
			sending_command <= '1';
			next_state <= WAIT_DCX;
		when LOAD_DATA =>
--			csx <= '0';
--               		dcx_out <= '1';
--			wrx <= '0';
--			data <= fifo_data;
			next_state <= WAIT_LOAD_1;
		when WAIT_LOAD_1=>
			next_state <= WAIT_LOAD_2;
		when WAIT_LOAD_2=>
			--wrx <= '1';
			next_state <= WAIT_LOAD_3;
		when WAIT_LOAD_3=>
			if (start_command = '1' and command_data = '0') or counter = to_unsigned(FRAME_LENGTH - 1, counter'length) or useddw = to_unsigned(0,useddw'length) then
				next_state <= WAIT_DCX;
			else
				next_state <= LOAD_DATA;
			end if;
        end case;
    end process;
process(clk)
-- At each clock cycle next_state is assigned to state
-- https://vhdlguide.readthedocs.io/en/latest/vhdl/fsm.html
begin
	if rising_edge(clk) then -- otherwise update the states
		case state is
			when RESET =>
				LCD_on_out <= LCD_on_in;
	    			LCD_resn_out <= LCD_resn_in;
			when WAIT_DCX =>
				rd_req <= '0';
				csx <= not continue;
				counter <= to_unsigned(0, counter'length);
--				sending_command <= '0';
			when LOAD_COMMAND =>
--				sending_command <= '1';
				csx <= '0';
				dcx_out <= dcx_in;
				wrx <= '0';
				data <= data_reg;
			when WAIT_COMMAND_2 =>
				wrx <= '1';
			when LOAD_DATA =>
				rd_req <= '0';
				csx <= '0';
               			dcx_out <= '1';
			wrx <= '0';
			data <= fifo_data;
			when WAIT_LOAD_2 =>
				wrx <= '1';
			when WAIT_LOAD_3 =>
				rd_req <= '1';
				counter <= counter +1;
				if counter = to_unsigned(FRAME_LENGTH - 1, counter'length) then
					csx <= '1';
				end if;
			when others =>
				null;

        	end case;
        else
            null;
        end if;
    end process;

end architecture rtl;
