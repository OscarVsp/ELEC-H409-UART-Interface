LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
ENTITY parallel_serial_register IS
    GENERIC (
        INPUT_SIZE : INTEGER := 16;
        OUTPUT_SIZE : INTEGER := 32;
        MAX_SIZE : INTEGER := 32
    );
    PORT (
        -- CLOCK AND RESET
        clock : IN STD_LOGIC; -- system clock
        reset : IN STD_LOGIC; -- high active synchronous reset
        load : IN STD_LOGIC;
        shift : IN STD_LOGIC;
        -- UART interface
        serial_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        parallel_in : IN STD_LOGIC_VECTOR(INPUT_SIZE * 8 - 1 DOWNTO 0);
        parallel_out : OUT STD_LOGIC_VECTOR(OUTPUT_SIZE * 8 - 1 DOWNTO 0);
        serial_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
END parallel_serial_register;

ARCHITECTURE rtl OF parallel_serial_register IS

    SIGNAL word_buffer : STD_LOGIC_VECTOR(MAX_SIZE * 8 - 1 DOWNTO 0);

BEGIN
    parallel_out <= word_buffer(OUTPUT_SIZE * 8 - 1 DOWNTO 0);
    serial_out <= word_buffer(MAX_SIZE * 8 - 1 DOWNTO MAX_SIZE * 8 - 8);

    PROCESS (clock) IS
    BEGIN
        IF rising_edge (clock) THEN
            IF reset = '1' THEN
                word_buffer <= (OTHERS => '0');
            ELSE
                IF load = '1' THEN
                    word_buffer(INPUT_SIZE * 8 - 1 DOWNTO 0) <= parallel_in;
                ELSIF shift = '1' THEN
                    word_buffer <= word_buffer(MAX_SIZE * 8 - 9 DOWNTO 0) & serial_in;
                END IF;
            END IF;
        END IF;

    END PROCESS;
END rtl;