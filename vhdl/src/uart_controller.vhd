LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;

ENTITY uart_controller IS
    GENERIC (
        INPUT_SIZE : INTEGER := 32;
        OUTPUT_SIZE : INTEGER := 16;
        MAX_SIZE : INTEGER := 32
    );
    PORT (
        clock : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        data_stream_in_stb : OUT STD_LOGIC;
        data_stream_in_ack : IN STD_LOGIC;
        data_stream_out_stb : IN STD_LOGIC;
        -- Register interface
        load : OUT STD_LOGIC;
        shift : OUT STD_LOGIC;
        -- Control interface
        input_valid : OUT STD_LOGIC;
        output_valid : IN STD_LOGIC
    );
END uart_controller;

ARCHITECTURE rtl OF uart_controller IS

    TYPE ctrl_state IS (reading, waiting, writing);

    SIGNAL state : ctrl_state := reading;
    SIGNAL byte_counter : INTEGER RANGE 0 TO MAX_SIZE - 1 := 0;

BEGIN
    PROCESS (clock) IS
    BEGIN
        IF rising_edge (clock) THEN
            -- Default value
            input_valid <= '0';
            data_stream_in_stb <= '0';
            shift <= '0';
            load <= '0';
            -- Reset
            IF reset = '1' THEN
                byte_counter <= 0;
                state <= reading;
            ELSE
                CASE state IS
                        --Reading bytes received from UART into the buffer
                    WHEN reading =>
                        -- Byte received from UART is valid 
                        IF data_stream_out_stb = '1' THEN
                            -- Last byte -> send "input_valid" signal then go to waiting state
                            IF byte_counter = INPUT_SIZE - 1 THEN
                                byte_counter <= 0;
                                shift <= '1';
                                input_valid <= '1';
                                state <= waiting;
                                -- Store received byte into buffer then shift by one byte
                            ELSE
                                byte_counter <= byte_counter + 1;
                                shift <= '1';
                            END IF;
                        END IF;
                        -- Waiting for the response to be ready
                    WHEN waiting =>
                        -- Response is ready -> Load into buffer then go to writing state
                        IF output_valid = '1' THEN
                            load <= '1';
                            state <= writing;
                        END IF;
                        -- Writing the bytes from the buffer through UART
                    WHEN writing =>
                        data_stream_in_stb <= '1';
                        -- UART is ready to sent the next byte
                        IF data_stream_in_ack = '1' THEN
                            -- Last byte -> go back to "reading_state"
                            IF byte_counter = OUTPUT_SIZE - 1 THEN
                                byte_counter <= 0;
                                shift <= '1';
                                state <= reading;
                                -- Send first byte of the buffer then shift by one byte
                            ELSE
                                byte_counter <= byte_counter + 1;
                                shift <= '1';
                            END IF;
                        END IF;
                END CASE;
            END IF;
        END IF;

    END PROCESS;
END rtl;