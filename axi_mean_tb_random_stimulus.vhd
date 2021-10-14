
-- Simulazione di axi_mean con stimoli s_tdata, s_tvalid, m_tready randomici


---------- DEFAULT LIBRARY ---------
library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.ALL;
	use IEEE.MATH_REAL.all;
------------------------------------

------------------------------------
entity axi_mean_tb_random_stimulus is
end;
------------------------------------

architecture bench of axi_mean_tb_random_stimulus is
    
  ------------ SIM CONSTANTS ------------
  constant seed :  positive   := 3514523; -- Seed. Cambia il seed per generare diverse simulazioni
  constant max_duration : positive := 5;  -- Lo stimolo cambia al massimo dopo 'max_duration' colpi di clock
  constant clock_period: time := 10 ns;
  ------------ TOP CONSTANTS ------------
  constant N_BYTES   : INTEGER := 3;
  constant DIVIDER_BLOCK : STRING := "bram";
  ---------------------------------------
  
  ------------- FUNCTION 1 --------------
  function rand_time( min : real; max : real; r : real) return time is
  -- PARAMETRI: REAL_TIME (MINIMO, MASSIMO, NUMERO CASUALE TRA 0 E 1 REAL )
    variable random_floor : real;
    variable random_time : time;
  begin
    random_floor := floor(r * (max-min) + min + 0.5);
    random_time := random_floor * clock_period;
    return random_time;
  end function;
  ---------------------------------------
  
  ------------- FUNCTION 2 --------------  
  function rand_integer( min_int : integer; max_int : integer; r : real) return integer is
  -- PARAMETRI: REAL_TIME (MINIMO, MASSIMO, NUMERO CASUALE TRA 0 E 1 REAL )
    variable random_integer : integer;
    variable max, min : real;
  begin
    max := real(max_int);
    min := real(min_int);
    random_integer := integer(floor(r * (max - min) + min + 0.5));
    return random_integer;
  end function;
  ---------------------------------------

  ------------- COMPONENTS  -------------
  component axi_mean
      Generic (
        -- Numero di byte consecutivi di cui si vuol far la somma 
        N_BYTES   : POSITIVE;
        DIVIDER_BLOCK : STRING
        );
      Port ( 
             ---------------------------
             clk      : in    STD_LOGIC;
             rst      : in    STD_LOGIC;
             ---------------------------
             m_tvalid : out   STD_LOGIC;
             m_tready : in    STD_LOGIC;
             m_tdata  : out   STD_LOGIC_VECTOR  (7 downto 0);
             ---------------------------
             s_tvalid : in    STD_LOGIC;
             s_tready : out   STD_LOGIC;
             s_tdata  : in    STD_LOGIC_VECTOR  (7 downto 0)
             ---------------------------
             );
  end component;
  ---------------------------------------
  
  ---------- OTHER CONSTANTS ------------
  constant S_TDATA_WIDTH : integer := 8;
  constant max_duration_r : REAL := real(max_duration);
  ---------------------------------------
  
  -------------- SIGNALS ----------------
  signal clk: STD_LOGIC := '1';
  signal rst: STD_LOGIC := '1';
  signal m_tvalid: STD_LOGIC;
  signal m_tready: STD_LOGIC := '0';
  signal s_tvalid: STD_LOGIC := '0';
  signal s_tready: STD_LOGIC;
  signal s_tdata: STD_LOGIC_VECTOR (7 downto 0) := ( OTHERS => '0' );
  signal m_tdata: STD_LOGIC_VECTOR (7 downto 0);
  ---------------------------------------
begin
    
    clk <= not clk after clock_period/2;
    
    ------------------ TOP --------------------
    uut: axi_mean
        generic map ( 
               N_BYTES => N_BYTES,
               DIVIDER_BLOCK => DIVIDER_BLOCK 
            )
        port map (   
               clk      => clk,
               rst      => rst,
               m_tvalid => m_tvalid,
               m_tready => m_tready,
               s_tvalid => s_tvalid,
               s_tready => s_tready,
               s_tdata  => s_tdata,
               m_tdata  => m_tdata );
    ---------------------------------------------


-------------- RESET PROCESS ----------------
    reset: process
    begin
        rst <= '1';    
        wait for 11 ns;
        rst <= '0';
        wait for 489 ns;
    end process;
    ---------------------------------------------
    
    ------------- RANDOM M_TREADY ---------------
    m_tready_random: process
        variable seed1, seed2 : positive := seed;
        variable r : real;
    begin
        -- genera numero casuale
        uniform(seed1,seed2,r);
        wait for rand_time(1.0, max_duration_r, r);
        
        m_tready <= not m_tready;
    end process;
    ---------------------------------------------
    
    ------------- RANDOM S_TVALID ---------------
    s_tvalid_random: process
        variable seed1, seed2 : positive := seed + 2020;
        variable r : real;
    begin
        -- genera numero casuale 
        uniform(seed1,seed2,r);
        wait for rand_time(1.0, max_duration_r, r);  
               
        s_tvalid <= not s_tvalid;
    end process;
    ---------------------------------------------
    
    -------------- RANDOM S_TDATA ---------------
    s_tdata_random: process
        variable seed1, seed2 : positive := seed * 2;      -- PS: nella simulazione s_tdata e s_tvalid sono casuali e indipendenti,
        variable r1,r2 : real;                             -- può capitare che lo stimolo esterno (s_uart) non sia realistico, 
    begin                                                  -- per esempio s_tvalid potrebbe deasserirsi senza che il 
        -- genera numero casuale                           -- dato sia stato trasferito.
        uniform(seed1,seed2,r1);
        uniform(seed2,seed1,r2);   
        
        wait for rand_time(1.0, max_duration_r, r1);
        s_tdata <= std_logic_vector(to_unsigned(rand_integer(0, 255, r2), S_TDATA_WIDTH));
    end process;
    ---------------------------------------------
    
end;