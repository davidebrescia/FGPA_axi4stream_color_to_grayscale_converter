library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

-- This module can be used to remove the "bouncing" of a signal, so that the
-- output changes no more than once every DEBOUNCE_MS milliseconds
entity debouncer is
	generic (
		DEBOUNCE_MS		: positive := 10;
		CLOCK_FREQ		: positive := 100_000_000
	);
	Port (
		-- Clock and reset
		clk				: in std_logic;
		reset			: in std_logic;

		-- I/Os
		input_signal	: in std_logic;
		debounced		: out std_logic
	);
end debouncer;

architecture Behavioral of debouncer is

	constant COUNTER_HIGH	: integer := CLOCK_FREQ / 1000 * DEBOUNCE_MS - 1;

	signal debounced_int	: std_logic;
	signal counter			: integer range 0 to COUNTER_HIGH;

begin

	-- To be able to read the value of input_debounced (which is an "out" port)
	-- we have to declare a signal and assign that to the external port.
	debounced	<= debounced_int;

	process(clk, reset)
	begin
		if reset = '1' then

			debounced_int	<= input_signal;
			counter			<= 0;

		elsif rising_edge(clk) then

			if counter = 0 then

				-- Keep sampling input_signal.
				debounced_int	<= input_signal;

				-- If input_signal has changed from the last sample, start
				-- the timer.
				if debounced_int /= input_signal then
					counter		<= COUNTER_HIGH;
				end if;

			else
				-- When the timer is running, no change is recorded, so the
				-- output stays constant.
				counter	 <= counter - 1;
			end if;

		end if;
	end process;


end Behavioral;
