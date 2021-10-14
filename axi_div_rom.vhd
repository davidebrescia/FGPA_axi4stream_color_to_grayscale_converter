
------------------------------------------- axi_div_rom --------------------------------------------

-- Divisione approssimata per eccesso tra dividendo in input e divisore costante scelto dall'utente. 
-- Interfaccia d'ingresso e di uscita Axi4-Stream.
--
-- Implementazione tramite Rom asincrona.
--
-- Nel caso di DIVIDEND_MAX = 255*3 e DIVIDER = 3: 
-- 32 LUTs. Delay* 7.335
-- L'utilizzo è sconsigliato per dividendi troppo grandi

-- A seconda del design esterno e della 'rigidezza' dei timing constraints, il modulo necessiterebbe 
-- di registri in ingresso per migliorare il delay del sistema. Questa aggiunta viene fatta  
-- automaticamente dal tool di sintesi.


---------- DEFAULT LIBRARY ---------
library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.ALL;
------------------------------------

entity axi_div_rom is
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
        s_tready : out   STD_LOGIC;
        s_tvalid : in    STD_LOGIC;
        s_tdata  : in    STD_LOGIC_VECTOR (S_TDATA_WIDTH-1 DOWNTO 0);  
        ---------------------------
        m_tready : in    STD_LOGIC;
        m_tvalid : out   STD_LOGIC;
        m_tdata  : out   STD_LOGIC_VECTOR (M_TDATA_WIDTH-1 DOWNTO 0)   
        ---------------------------
    );
end axi_div_rom;


architecture Behavioral of axi_div_rom is

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
	constant	mem_data :	matrix := DefineMEM;
	-----------------------------------

begin
    ---------------------- DATA FLOW ------------------------
    s_tready <= m_tready;
    
    m_tvalid <= s_tvalid;
    
    m_tdata <=  mem_data( TO_INTEGER ( UNSIGNED (s_tdata) ) );
    ---------------------------------------------------------
end Behavioral;
----------------------------------------------------------------------------------------------------
