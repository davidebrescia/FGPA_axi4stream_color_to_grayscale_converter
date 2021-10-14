
------------------------------------------- axi_sum ------------------------------------------------

-- Fa la somma di un numero fisso di bytes.
-- Interfaccia d'ingresso e di uscita Axi4-Stream. 
--
-- Nel caso di N_BYTES = 3:
-- 22 LUTs, 12 FlipFlops


---------- DEFAULT LIBRARY ---------
library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.ALL;
	use IEEE.MATH_REAL.all;
------------------------------------

entity axi_sum is
    Generic (
        -- Numero di bytes consecutivi di cui si vuole fare la somma.
        N_BYTES       : POSITIVE;
        -- Larghezza dell'uscita da dimensionare in funzione del numero di bytes da sommare.
        -- L'utente può scegliere se impostare una larghezza Axi4Stream (multipla di 8) o la lunghezza
        -- minima necessaria a contenere la somma dei byte. In ogni caso i bit inutilizzati vengono
        -- ignorati, le risorse utilizzate vengono ridotte al minimo indispensabile. 
        M_TDATA_WIDTH : POSITIVE
        );
    Port ( 
        ---------------------------
        clk      : in    STD_LOGIC;
        rst      : in    STD_LOGIC;
        ---------------------------
        s_tready : out   STD_LOGIC;
        s_tvalid : in    STD_LOGIC;
        s_tdata  : in    STD_LOGIC_VECTOR (7 DOWNTO 0);  
        ---------------------------
        m_tready : in    STD_LOGIC;
        m_tvalid : out   STD_LOGIC;
        m_tdata  : out   STD_LOGIC_VECTOR (M_TDATA_WIDTH-1 DOWNTO 0)   
        ---------------------------
    );
end axi_sum;


architecture Behavioral of axi_sum is
  
    --------------- CONSTANT -----------------               
    -- Per ottimizzare l'implementazione nel caso di un superfluo numero di bit in uscita.
 
    -- Numero minimo di bit per contenere la somma
    constant DATA_SUM_WIDTH : INTEGER := INTEGER ( ceil( log2( REAL(N_BYTES) * 255.0 )));
    
    -- Padding dei bit superflui
    constant s_pad : UNSIGNED ( DATA_SUM_WIDTH - 9 DOWNTO 0 )                 := ( OTHERS => '0' );                 
    constant m_pad : UNSIGNED ( M_TDATA_WIDTH - DATA_SUM_WIDTH - 1 DOWNTO 0 ) := ( OTHERS => '0' );
    ------------------------------------------
       
    --------------- SIGNALS ------------------
    signal s_tready_int :    STD_LOGIC := '0';
    signal m_tvalid_int :    STD_LOGIC := '0';
    
    -- num_data_stored è lo stato del sistema, è il numero di bytes ricevuti.
    -- in caso di N_BYTES = 3:
    -- num_data_stored = 0  Ho 0 dati. Sto aspettando il 1°.
    -- num_data_stored = 1  Ho 1 dato. Sto aspettando il 2°.
    -- num_data_stored = 2  Ho 2 dati. Sto aspettando il 3°.
    -- num_data_stored = 3  Ho 3 dati. Sto aspettando il 1°.
    signal num_data_stored : INTEGER range 0 to N_BYTES := 0;
    
    -- data_sum è l'unica memoria presente per immagazzinare i dati.
    -- Man mano che arrivano, i bytes vengono sommati qui dentro.
    signal data_sum :        UNSIGNED ( DATA_SUM_WIDTH-1 DOWNTO 0 ) := ( OTHERS => '0' );  
    ------------------------------------------
  
begin     

    --------------------- DATA FLOW ------------------------
    -- Quando è pronto il valore in uscita ma m_tready = '0' allora non siamo  
    -- pronti a ricevere nuovi dati da sommare perchè data_sum è occupato
    s_tready     <= s_tready_int;
    s_tready_int <= '0' when (m_tvalid_int = '1' and m_tready = '0') or rst = '1' else   
                    '1';  
                    
    -- Appena vengono sommati tutti gli N_BYTES il dato è pronto in uscita
    m_tvalid     <= m_tvalid_int;
    m_tvalid_int <= '1' when num_data_stored = N_BYTES else
                    '0';
    
    -- L'uscita è direttamente collegata a data_sum, con l'opportuno padding.
    -- I bit inutilizzati sono posti a '0' e non a '-'. L'uso di '-' comporta
    -- problemi in simulazione, per risolverli bisogna rendere meno compatto
    -- il codice del blocco divisore. Che si usi '0' o '-', in sintesi 
    -- si ottiene lo stesso risultato.
    m_tdata <= STD_LOGIC_VECTOR( m_pad & data_sum ); 
    --------------------------------------------------------
    
    
    --------------------- PROCESS --------------------------
    process (clk, rst) 
    begin   
        -------- ASYNC  ---------
        if rst = '1' then                        
            num_data_stored <= 0;
            data_sum <= ( OTHERS => '0');
            
        -------- SYNC  ---------
        elsif rising_edge (clk) then               
            if num_data_stored = N_BYTES then
                
                -- Dato entrato
                if s_tvalid = '1' and s_tready_int = '1' then   
                    data_sum <= s_pad & unsigned( s_tdata );                    
                    num_data_stored <= 1;
                
                -- Dato uscito (in questo if, m_tvalid è '1')
                elsif m_tready = '1' then                               
                    num_data_stored <= 0;          
                    data_sum <= ( OTHERS => '0' ); 
                end if;
                               
            else 
                -- Dato entrato
                if s_tvalid = '1' and s_tready_int = '1' then   
                    data_sum <= data_sum + unsigned(s_tdata); 
                    num_data_stored <= num_data_stored + 1;
                end if;    
                
            end if;    
        end if;
    end process;
    --------------------------------------------------------
    
end Behavioral;

----------------------------------------------------------------------------------------------------
