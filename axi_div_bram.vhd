
------------------------------------------- axi_div_bram --------------------------------------------

-- Divisione approssimata per eccesso tra dividendo in input e divisore costante scelto dall'utente. 
-- Interfaccia d'ingresso e di uscita Axi4-Stream.
--
-- Implementazione tramite Rom sincrona: RamB18E1.
-- La BRam è implementata tramite descrizione behavioral, nel codice non è istanziato alcun componente. 
-- L'implementazione voluta potrebbe non essere riconosciuta da altri software di sintesi. 
--
-- Nel caso di DIVIDEND_MAX = 255*3 e DIVIDER = 3: 
-- Basso utilizzo di risorse (0.5/50 RamB), basso delay*: 5.839
-- L'utilizzo è sconsigliato per dividendi troppo grandi. 


---------- DEFAULT LIBRARY ---------
library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.ALL;
------------------------------------

entity axi_div_bram is
    Generic (
        -- Dividendo massimo
        DIVIDEND_MAX  : POSITIVE;
        -- Divisore
        DIVIDER       : POSITIVE;
        -- Larghezza dato in ingresso
        S_TDATA_WIDTH : POSITIVE;
        -- Larghezza dato in uscita
        M_TDATA_WIDTH : POSITIVE
    );
    Port ( 
        ---------------------------
        clk      : in    STD_LOGIC;
        rst      : in    STD_LOGIC;
        ---------------------------
        s_tready : out   STD_LOGIC;
        s_tvalid : in    STD_LOGIC;
        s_tdata  : in    STD_LOGIC_VECTOR (S_TDATA_WIDTH-1 DOWNTO 0);  
        ---------------------------
        m_tready : in    STD_LOGIC;
        m_tvalid : out   STD_LOGIC;
        m_tdata  : out   STD_LOGIC_VECTOR (M_TDATA_WIDTH-1 DOWNTO 0)   
        ---------------------------
    );
end axi_div_bram;

architecture Behavioral of axi_div_bram is
    
    ------- TYPES DECLARATION ---------
    type matrix is array ( 0 to DIVIDEND_MAX ) of STD_LOGIC_VECTOR ( M_TDATA_WIDTH-1 DOWNTO 0 );
    -----------------------------------
    
    ------- Hashmap definition --------
    function DefineMEM return matrix is
		variable mem_tmp : matrix;
	begin
		for I in mem_tmp'RANGE loop
		  -- Divisione approssimata per eccesso (i + n/2)/n
			mem_tmp(I) := STD_LOGIC_VECTOR  ( to_unsigned( (I + DIVIDER/2)/DIVIDER, M_TDATA_WIDTH) ); 
		end loop;
		return mem_tmp;
	end function;
    -----------------------------------
    
    ------------ CONSTANTS ------------
	constant mem : matrix := DefineMEM;
	-----------------------------------
	
	------------ SIGNALS --------------
	signal s_tready_int : STD_LOGIC := '0';
	signal m_tvalid_int : STD_LOGIC := '0'; 
    signal address      : INTEGER range 0 TO DIVIDEND_MAX;
	-----------------------------------
begin
    --------------------- DATA FLOW ------------------------
    -- Quando è pronto il valore in uscita ma m_tready = '0' allora non siamo  
    -- pronti a ricevere nuovi dati da dividere perché l'uscita della RamB è occupata
    s_tready <= s_tready_int;
    s_tready_int <= '0' when (m_tvalid_int = '1' and m_tready = '0') or rst = '1' else
                    '1';
    
    m_tvalid <= m_tvalid_int;
    
    m_tdata <= mem( address );
    --------------------------------------------------------
    
    --------------------- PROCESS --------------------------
    process(clk, rst)
    begin
        -------- ASYNC  ---------
        if rst = '1' then
            m_tvalid_int <= '0';
        -------- SYNC  ----------
        elsif rising_edge(clk) then 
        
            if m_tvalid_int = '1' and m_tready = '1' then       -- Dato uscito
                m_tvalid_int <= '0';
            end if;
                                    
            if s_tvalid = '1' and s_tready_int = '1' then       -- Dato entrato 
                address <= to_integer ( unsigned ( s_tdata ) );
                m_tvalid_int <= '1';
            end if;
        end if;
    --------------------------------------------------------
    end process;
    
end Behavioral;
-----------------------------------------------------------------------------------------------------
