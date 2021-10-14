
-- Davide Brescia, Lorenzo Giancristofaro, Simone Polge


------------------------------ Introduzione al Progetto -----------------------------------
-- La media dei bytes è realizzata tramite due blocchi in serie:
-- 1. axi_sum:     Sommatore con interfaccia d'ingresso e di uscita Axi4-Stream (con ready)   
-- 2. axi_div_*:   Divisore  con interfaccia d'ingresso e di uscita Axi4-Stream (con ready)
--
-- I due moduli comunicano tra di loro in Axi4-Stream. Vantaggi:
-- 1. Separazione completa del problema della somma e della divisione 
-- 2. Blocchi impiegabili singolarmente, utilizzabili in progetti diversi
-- 3. Divisore intercambiabile; in funzione delle risorse disponibili della particolare
-- board e della frequenza operativa, possiamo scegliere diversi blocchi. 
-- PS: Nel nostro caso il critical path sarà causato dalla Uart quindi il blocco divisore 
-- non influisce sulla massima frequenza del sistema, l'intercambiabilità può essere utile 
-- in vista di altri progetti.
-- 
-- Con Basys3 la migliore scelta del divisore è:
-- "bram": axi_div_bram, ovvero implementazione tramite Rom sincrona: RamB18E1,
-- per il limitato utilizzo di risorse e l'ottimo delay*.
-- 
-- In alternativa, tramite la generic 'DIVIDER_BLOCK' si può scegliere: 
-- "rom": axi_div_rom:     ROM asincrona
-- "col": axi_div_col:     algoritmo di divisione 'in colonna', asincrona
-- Per ulteriori informazioni, si rimanda ai commenti iniziali dei singoli moduli.
--
-- Il design di tutti i moduli è stato studiato per non far accadere
-- deasserzioni non strettamente necessarie di 'ready', pur non usando FIFO. 
-- In questo modo il sistema è in grado di comportarsi in maniera ottimale 
-- in qualsiasi situazione si trovino il master e lo slave esterni.
-- Per un caso pratico, si rimanda alla testbench 'random_stimulus'.
-- In questo particolare progetto tale ottimizzazione è superflua, perché il 'collo
-- di bottiglia' è rappresentato dal baudrate della comunicazione seriale, ma può
-- essere utile in vista di altri progetti.
--
-- A fine file, dopo l'architecture, troverete un commento riguardante un quarto modo
-- che abbiamo studiato per realizzare il blocco divisore, il metodo:
-- 'x / 3 = (x + 4x + 16x + 64x + 256x + 1024x) / 4096'
-- che non abbiamo introdotto nel progetto.
-------------------------------------------------------------------------------------------


--------------------------------------- axi_mean ------------------------------------------

-- Fa la media di 'pacchetti' di bytes che riceve in comunicazione seriale.
-- Interfaccia d'ingresso e di uscita Axi4-Stream.


---------- DEFAULT LIBRARY ---------
library IEEE;
	use IEEE.STD_LOGIC_1164.all;
	use IEEE.NUMERIC_STD.ALL;
	use IEEE.MATH_REAL.all;
------------------------------------

entity axi_mean is  
    Generic (
        -- Numero di bytes di cui si vuole fare la media.
        N_BYTES : POSITIVE := 3;
        
        -- Tramite questa stringa si può scegliere quale blocco divisore utilizzare, in funzione
        -- delle risorse disponibili e della frequenza di clock. 
        -- Possibili scelte:
        -- "bram": la migliore con Basys3
        -- "rom":  ROM asincrona, realizzata con LUTs invece che con la RamB
        -- "col":  la migliore per risorse utilizzate grazie all'ottimizzazione di Vivado
        --  Attenzione: se si utilizza "col", è obbligatorio impostare N_BYTES = 3
        DIVIDER_BLOCK : STRING := "bram"
    );
    Port ( 
        ---------------------------
        clk      : in    STD_LOGIC;
        rst      : in    STD_LOGIC;
        ---------------------------
        s_tready : out   STD_LOGIC;
        s_tvalid : in    STD_LOGIC;
        s_tdata  : in    STD_LOGIC_VECTOR(7 downto 0);  
        ---------------------------
        m_tready : in    STD_LOGIC;
        m_tvalid : out   STD_LOGIC;
        m_tdata  : out   STD_LOGIC_VECTOR(7 downto 0)   
        ---------------------------
    );
end axi_mean;
    
architecture Behavioral of axi_mean is

    ---------------------- FUNCTION -------------------------
    function TDATA_INT_gen return INTEGER is                    -- Questa funzione decide la larghezza di 'tdata'
		variable width : REAL;                                  -- dell'interfaccia intermedia che collega i due blocchi,
	begin                                                       -- che contiene la somma del 'pacchetto' di bytes.
		if DIVIDER_BLOCK = "col" then                           -- "col" necessita di un'interfaccia larga 10 bit.
            if N_BYTES = 3 then                                 -- Per gli altri divider tdata è largo quanto il numero 
                return 10;                                      -- multiplo di 8 più piccolo necessario a contenere la
            end if;                                             -- somma dei bytes. PS: in ogni caso i bit superflui 
        else                                                    -- non verranno implementati.
            width := ceil( log2( REAL(N_BYTES) * 255.0 ));
            for I in 0 to 1000 loop
              if width / 8.0 - floor( width / 8.0 ) = 0.0 then
                  return INTEGER(width);
              end if;
              width := width + 1.0;
            end loop;
        end if;  
		return -1;  -- -1 = errore da parte dell'utente
	end function;
	---------------------------------------------------------
	
    --------------------- ADDER AXI -------------------------
    component axi_sum is    
        Generic (
           N_BYTES       : POSITIVE;
           M_TDATA_WIDTH : POSITIVE
        );
        Port ( 
           ---------------------------
           clk      : in    STD_LOGIC;
           rst      : in    STD_LOGIC;
           ---------------------------  
           s_tready : out   STD_LOGIC;
           s_tvalid : in    STD_LOGIC;
           s_tdata  : in    STD_LOGIC_VECTOR(7 downto 0);  
           ---------------------------
           m_tready : in    STD_LOGIC;
           m_tvalid : out   STD_LOGIC;
           m_tdata  : out   STD_LOGIC_VECTOR(M_TDATA_WIDTH -1 downto 0)   
           ---------------------------  
        );
    end component;
    ---------------------------------------------------------
    
    -------------------- DIVIDERS AXI -----------------------
    component axi_div_bram is    
        Generic (
           DIVIDEND_MAX  : POSITIVE;
           DIVIDER       : POSITIVE;
           S_TDATA_WIDTH : POSITIVE;
           M_TDATA_WIDTH : POSITIVE
        );
        Port ( 
           clk      : in    STD_LOGIC;
           rst      : in    STD_LOGIC;
           ---------------------------
           s_tready : out   STD_LOGIC;
           s_tvalid : in    STD_LOGIC;
           s_tdata  : in    STD_LOGIC_VECTOR(S_TDATA_WIDTH-1 downto 0);  
           ---------------------------
           m_tready : in    STD_LOGIC;
           m_tvalid : out   STD_LOGIC;
           m_tdata  : out   STD_LOGIC_VECTOR(M_TDATA_WIDTH-1 downto 0)     
           ---------------------------
        );
    end component;
    
    component axi_div_rom is    
        Generic (
            DIVIDEND_MAX  : POSITIVE;
            DIVIDER       : POSITIVE;
            S_TDATA_WIDTH : POSITIVE;
            M_TDATA_WIDTH : POSITIVE
        );
        Port ( 
           ---------------------------
           s_tready : out   STD_LOGIC;
           s_tvalid : in    STD_LOGIC;
           s_tdata  : in    STD_LOGIC_VECTOR(S_TDATA_WIDTH-1 downto 0);  
           ---------------------------
           m_tready : in    STD_LOGIC;
           m_tvalid : out   STD_LOGIC;
           m_tdata  : out   STD_LOGIC_VECTOR(M_TDATA_WIDTH-1 downto 0)     
           ---------------------------
        );
    end component;
    
    component axi_div_col is    
        Generic (
           -- Queste generic NON sono modificabili dall'utente
           S_TDATA_WIDTH : POSITIVE := 10;
           M_TDATA_WIDTH : POSITIVE := 8
        );
        Port ( 
           ---------------------------
           s_tready : out   STD_LOGIC;
           s_tvalid : in    STD_LOGIC;
           s_tdata  : in    STD_LOGIC_VECTOR(S_TDATA_WIDTH-1 downto 0);  
           ---------------------------
           m_tready : in    STD_LOGIC;
           m_tvalid : out   STD_LOGIC;
           m_tdata  : out   STD_LOGIC_VECTOR(M_TDATA_WIDTH-1 downto 0)     
           ---------------------------
        );
    end component;
    ---------------------------------------------------------
    
    
    -------------- INTERFACCIA INTERMEDIA -------------------
    -- Larghezza del dato tra il sommatore e il divisore.
    -- Ogni larghezza sufficiente a contenere la somma di N_BYTES bytes va bene. 
    -- Per rispettare la convenzione Axi4-Stream, è bene che tale larghezza
    -- sia multipla di 8. In ogni caso i bit superflui non verranno implementati.
    constant TDATA_INT : POSITIVE := TDATA_INT_gen; 
    ---------------------------------------------------------
    
    ------------------------SIGNALS--------------------------
    signal ready : STD_LOGIC;
    signal valid : STD_LOGIC;
    signal data :  STD_LOGIC_VECTOR( TDATA_INT-1 downto 0 );
    ---------------------------------------------------------
    
begin     
    
    --------------------- ADDER AXI -------------------------
    Sum: axi_sum 
        Generic map (
            N_BYTES => N_BYTES,
            M_TDATA_WIDTH => TDATA_INT
        )
        Port Map (
            clk => clk,
            rst => rst,
            s_tready => s_tready,
            s_tvalid => s_tvalid,
            s_tdata => s_tdata,
            m_tready => ready,
            m_tvalid => valid,
            m_tdata => data
        );
    ------------------------------------------------------------
    
    
    --------------------- DIVIDERS AXI -------------------------
    Choice0: if DIVIDER_BLOCK = "bram" generate
        Div0: axi_div_bram 
            Generic Map (
                DIVIDEND_MAX  => N_BYTES*255,
                DIVIDER       => N_BYTES,
                S_TDATA_WIDTH => TDATA_INT,
                M_TDATA_WIDTH => 8
            )
            Port Map (
                clk => clk,
                rst => rst,
                s_tready => ready,
                s_tvalid => valid,
                s_tdata  => data,
                m_tready => m_tready,
                m_tvalid => m_tvalid,
                m_tdata  => m_tdata
            );
    end generate;
    
    Choice1: if DIVIDER_BLOCK = "rom" generate
        Div: axi_div_rom
            Generic Map (
                DIVIDEND_MAX  => N_BYTES*255,
                DIVIDER       => N_BYTES,
                S_TDATA_WIDTH => TDATA_INT,
                M_TDATA_WIDTH => 8
                )
            Port Map (
                s_tready => ready,
                s_tvalid => valid,
                s_tdata  => data,
                m_tready => m_tready,
                m_tvalid => m_tvalid,
                m_tdata  => m_tdata
            );
    end generate;
    
    Choice2: if DIVIDER_BLOCK = "col" generate
        Div: axi_div_col
            Generic Map (
                -- Queste generic NON sono modificabili dall'utente
                S_TDATA_WIDTH => 10,
                M_TDATA_WIDTH => 8
            )
            Port Map (
                s_tready => ready,
                s_tvalid => valid,
                s_tdata  => data,
                m_tready => m_tready,
                m_tvalid => m_tvalid,
                m_tdata  => m_tdata
            );
    end generate;
    -----------------------------------------------------------
    
end Behavioral;
-----------------------------------------------------------------------------------------------------------



------------------ Studi su un altro possibile divisore: metodo delle potenze di 2 ------------------------
-- Inizialmente abbiamo lavorato su un blocco divisore basato sulle potenze di 2. Nonostante fosse il più
-- intrigante, abbiamo dovuto scartarlo perché aveva un utilizzo troppo elevato di risorse, sebbene avesse
-- un delay molto buono, confrontabile con "bram".
--
-- In binario la moltiplicazione e la divisione per potenze di 2 è un'operazione estremamente semplice. 
-- Con un programma in C di brute-force, abbiamo scoperto che questa serie di operazioni:
-- (x + 4x + 16x + 64x + 256x + 1024x) / 4096
-- è quella che approssima meglio x / 3, perché contiene il più basso numero di somme al numeratore senza 
-- commettere errori rispetto alla vera divisione approssimata per eccesso, per dividendi fino a 765 (255*3).
-- 
-- L'implementazione prevede 6 adders (5 come le somme al numeratore + 1 per approssimare per eccesso), per 
-- un totale di 46 LUTs. Il problema di tale implementazione combinatoria è però il worst delay.
-- Tuttavia l'algoritmo si presta bene ad essere pipelinizzato. 
-- In effetti, suddividendo in 2 colpi di clock l'intera serie di operazioni si raggiunge:
-- 46 LUTs + 19 FF, worst delay* = 9.444
-- Effettuando invece la massima pipelinizzazione, scomponendo l'operazione in 6 colpi di clock, si ottiene:
-- 46 LUTs + 85 FF, worst delay* = 5.703
------------------------------------------------------------------------------------------------------------



-- (*) "delay": stima molto grezza del critical path propagation delay dell'entity, da noi reputata utile solo  
--     per confrontare diversi designs. Abbiamo utilizzato il "Report timing summary" di post sintesi, guardando 
--     il peggior setup delay degli "unconstrained paths". Putroppo non abbiamo potuto sfruttare la lezione 
--     sulla Timing Analysis, perché coincideva con il giorno di consegna del progetto.


