library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi4stream_data_out is
	Generic (
		DATA_WIDTH		: positive := 8;
		RESET_VALUE		: integer := 0
	);
	Port (
		-- Clock and reset
		clk				: in std_logic;
		resetn			: in std_logic;

		-- AXI4-Stream slave interface
		s_axis_tvalid	: in std_logic;
		s_axis_tdata	: in std_logic_vector(DATA_WIDTH-1 downto 0);
		s_axis_tready	: out std_logic;

		-- Output data
		data_out		: out std_logic_vector(DATA_WIDTH-1 downto 0)
	);
end axi4stream_data_out;


architecture Behavioral of axi4stream_data_out is

	signal m_axis_tready_int	: std_logic;

begin

	-- We will use the value of tready in our logic, but it is an "out" port so
	-- it can not be read: use a "replica" signal.
	s_axis_tready	<= m_axis_tready_int;

	process(clk, resetn)
	begin
		if resetn = '0' then

			-- Set the bits to RESET_VALUE on a reset
			data_out		<= std_logic_vector(to_unsigned(RESET_VALUE, data_out'length));

			-- Refuse incoming data during resets
			m_axis_tready_int	<= '0';

		elsif rising_edge(clk) then

			-- We're always ready to accept new data when not reset
			m_axis_tready_int	<= '1';

			-- If the input data is valid...
			if s_axis_tvalid = '1' and m_axis_tready_int = '1' then
				-- ... copy s_axis_tdata onto data_out
				data_out	<= s_axis_tdata;
			end if;

		end if;
	end process;

end Behavioral;
