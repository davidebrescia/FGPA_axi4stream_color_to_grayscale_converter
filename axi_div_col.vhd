
------------------------------------------- axi_div_col ----------------------------------------------------

-- Divisione approssimata per eccesso tra dividendo in input e divisore costante = 3. 
-- Interfaccia d'ingresso** e di uscita Axi4-Stream.
 --  
-- Questo modello di divisore asincrono ricalca l'algoritmo della divisione in colonna e sfrutta alcune 
-- particolarità proprie della divisione per 3. 
-- (**) L'ingresso non è propriamente Axi4-Stream, perché s_tdata è largo 10 bit. Inoltre si può usare solo 
-- con DIVIDER = 3 e DIVIDEND_MAX = 765 = 255*3, ovvero nel particolare caso del progetto di laboratorio.
--
-- La peculiarità che ci ha spinti ad inserirlo come possibile soluzione è il fatto che sia il divisore 
-- che richiede in assoluto meno risorse, grazie all'ottimizzazione di Vivado. L'utilizzo di un altro
-- software potrebbe causare un'implementazione con critical path molto più lento. In tal caso non conviene
-- utilizzare "col".
--
-- 13 LUTs. Delay*: 7.484


---------- DEFAULT LIBRARY ---------
library IEEE;
    use IEEE.STD_LOGIC_1164.all;
    use IEEE.NUMERIC_STD.ALL;
------------------------------------


entity axi_div_col is
    Generic (
        -- Queste generic NON sono modificabili dall'utente
        S_TDATA_WIDTH : POSITIVE := 10;
        M_TDATA_WIDTH : POSITIVE := 8
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
end axi_div_col;


architecture Behavioral of axi_div_col is
    ---------------------------------- SIGNALS ---------------------------------------
    signal m_tdata_int :   STD_LOGIC_VECTOR ( M_TDATA_WIDTH-1 DOWNTO 0 ) := (Others => '0');
    ----------------------------------------------------------------------------------
begin
    ------------- DATA FLOW ---------------
    s_tready <= m_tready;
    
    m_tvalid <= s_tvalid;
    
    m_tdata  <= m_tdata_int;
    ---------------------------------------
    
    -------------- PROCESS ----------------
    process(s_tdata)
    
        variable resto : STD_LOGIC_VECTOR(2 downto 0);
         
        begin 
            resto := STD_LOGIC_VECTOR(s_tdata(S_TDATA_WIDTH-1 downto S_TDATA_WIDTH-3));
            for I in M_TDATA_WIDTH-1 downto 0 loop                         
                if (resto > "010") 
                then
                    m_tdata_int(I)<='1';                  
                    resto := STD_LOGIC_VECTOR(UNSIGNED(resto) - 3);                   
                else                    
                    m_tdata_int(I)<='0';                            
                end if;
                if I /= 0 then
                    resto := (resto(1 downto 0)) & s_tdata(I-1);
                end if;                     
            end loop;       
        end process;
    ---------------------------------------
    
end Behavioral;
------------------------------------------------------------------------------------------------------------
