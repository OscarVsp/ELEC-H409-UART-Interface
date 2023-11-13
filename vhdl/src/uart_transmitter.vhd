-------------------------------------------------------------------------------
-- UART
-- Implements a universal asynchronous receiver transmitter
-- Made by: https://github.com/pabennett/uart
-- License: Apache License
-------------------------------------------------------------------------------
-- clock
--      Input clock, must match frequency value given on clock_frequency
--      generic input.
-- reset
--      Synchronous reset.  
-- data_stream_in
--      Input data bus for bytes to transmit.
-- data_stream_in_stb
--      Input strobe to qualify the input data bus.
-- data_stream_in_ack
--      Output acknowledge to indicate the UART has begun sending the byte
--      provided on the data_stream_in port.
-- data_stream_out
--      Data output port for received bytes.
-- data_stream_out_stb
--      Output strobe to qualify the received byte. Will be valid for one clock
--      cycle only. 
-- tx
--      Serial transmit.
-- rx
--      Serial receive
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.numeric_std.ALL;
USE ieee.math_real.ALL;

ENTITY uart_transmitter IS
    GENERIC (
        baud : POSITIVE;
        clock_frequency : POSITIVE
    );
    PORT (
        clock : IN STD_LOGIC;
        reset : IN STD_LOGIC;
        data_stream_in : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        data_stream_in_stb : IN STD_LOGIC;
        data_stream_in_ack : OUT STD_LOGIC;
        data_stream_out : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        data_stream_out_stb : OUT STD_LOGIC;
        tx : OUT STD_LOGIC;
        rx : IN STD_LOGIC
    );
END uart_transmitter;

ARCHITECTURE rtl OF uart_transmitter IS
    ---------------------------------------------------------------------------
    -- Baud generation constants
    ---------------------------------------------------------------------------
    CONSTANT c_tx_div : INTEGER := clock_frequency / baud;
    CONSTANT c_rx_div : INTEGER := clock_frequency / (baud * 16);
    CONSTANT c_tx_div_width : INTEGER
    := INTEGER(log2(real(c_tx_div))) + 1;
    CONSTANT c_rx_div_width : INTEGER
    := INTEGER(log2(real(c_rx_div))) + 1;
    ---------------------------------------------------------------------------
    -- Baud generation signals
    ---------------------------------------------------------------------------
    SIGNAL tx_baud_counter : unsigned(c_tx_div_width - 1 DOWNTO 0)
    := (OTHERS => '0');
    SIGNAL tx_baud_tick : STD_LOGIC := '0';
    SIGNAL rx_baud_counter : unsigned(c_rx_div_width - 1 DOWNTO 0)
    := (OTHERS => '0');
    SIGNAL rx_baud_tick : STD_LOGIC := '0';
    ---------------------------------------------------------------------------
    -- Transmitter signals
    ---------------------------------------------------------------------------
    TYPE uart_tx_states IS (
        tx_send_start_bit,
        tx_send_data,
        tx_send_stop_bit
    );
    SIGNAL uart_tx_state : uart_tx_states := tx_send_start_bit;
    SIGNAL uart_tx_data_vec : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL uart_tx_data : STD_LOGIC := '1';
    SIGNAL uart_tx_count : unsigned(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL uart_rx_data_in_ack : STD_LOGIC := '0';
    ---------------------------------------------------------------------------
    -- Receiver signals
    ---------------------------------------------------------------------------
    TYPE uart_rx_states IS (
        rx_get_start_bit,
        rx_get_data,
        rx_get_stop_bit
    );
    SIGNAL uart_rx_state : uart_rx_states := rx_get_start_bit;
    SIGNAL uart_rx_bit : STD_LOGIC := '1';
    SIGNAL uart_rx_data_vec : STD_LOGIC_VECTOR(7 DOWNTO 0) := (OTHERS => '0');
    SIGNAL uart_rx_data_sr : STD_LOGIC_VECTOR(1 DOWNTO 0) := (OTHERS => '1');
    SIGNAL uart_rx_filter : unsigned(1 DOWNTO 0) := (OTHERS => '1');
    SIGNAL uart_rx_count : unsigned(2 DOWNTO 0) := (OTHERS => '0');
    SIGNAL uart_rx_data_out_stb : STD_LOGIC := '0';
    SIGNAL uart_rx_bit_spacing : unsigned (3 DOWNTO 0) := (OTHERS => '0');
    SIGNAL uart_rx_bit_tick : STD_LOGIC := '0';
BEGIN
    -- Connect IO
    data_stream_in_ack <= uart_rx_data_in_ack;
    data_stream_out <= uart_rx_data_vec;
    data_stream_out_stb <= uart_rx_data_out_stb;
    tx <= uart_tx_data;
    ---------------------------------------------------------------------------
    -- OVERSAMPLE_CLOCK_DIVIDER
    -- generate an oversampled tick (baud * 16)
    ---------------------------------------------------------------------------
    oversample_clock_divider : PROCESS (clock)
    BEGIN
        IF rising_edge (clock) THEN
            IF reset = '1' THEN
                rx_baud_counter <= (OTHERS => '0');
                rx_baud_tick <= '0';
            ELSE
                IF rx_baud_counter = c_rx_div THEN
                    rx_baud_counter <= (OTHERS => '0');
                    rx_baud_tick <= '1';
                ELSE
                    rx_baud_counter <= rx_baud_counter + 1;
                    rx_baud_tick <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS oversample_clock_divider;
    ---------------------------------------------------------------------------
    -- RXD_SYNCHRONISE
    -- Synchronise rxd to the oversampled baud
    ---------------------------------------------------------------------------
    rxd_synchronise : PROCESS (clock)
    BEGIN
        IF rising_edge(clock) THEN
            IF reset = '1' THEN
                uart_rx_data_sr <= (OTHERS => '1');
            ELSE
                IF rx_baud_tick = '1' THEN
                    uart_rx_data_sr(0) <= rx;
                    uart_rx_data_sr(1) <= uart_rx_data_sr(0);
                END IF;
            END IF;
        END IF;
    END PROCESS rxd_synchronise;
    ---------------------------------------------------------------------------
    -- RXD_FILTER
    -- Filter rxd with a 2 bit counter.
    ---------------------------------------------------------------------------
    rxd_filter : PROCESS (clock)
    BEGIN
        IF rising_edge(clock) THEN
            IF reset = '1' THEN
                uart_rx_filter <= (OTHERS => '1');
                uart_rx_bit <= '1';
            ELSE
                IF rx_baud_tick = '1' THEN
                    -- filter rxd.
                    IF uart_rx_data_sr(1) = '1' AND uart_rx_filter < 3 THEN
                        uart_rx_filter <= uart_rx_filter + 1;
                    ELSIF uart_rx_data_sr(1) = '0' AND uart_rx_filter > 0 THEN
                        uart_rx_filter <= uart_rx_filter - 1;
                    END IF;
                    -- set the rx bit.
                    IF uart_rx_filter = 3 THEN
                        uart_rx_bit <= '1';
                    ELSIF uart_rx_filter = 0 THEN
                        uart_rx_bit <= '0';
                    END IF;
                END IF;
            END IF;
        END IF;
    END PROCESS rxd_filter;
    ---------------------------------------------------------------------------
    -- RX_BIT_SPACING
    ---------------------------------------------------------------------------
    rx_bit_spacing : PROCESS (clock)
    BEGIN
        IF rising_edge(clock) THEN
            uart_rx_bit_tick <= '0';
            IF rx_baud_tick = '1' THEN
                IF uart_rx_bit_spacing = 15 THEN
                    uart_rx_bit_tick <= '1';
                    uart_rx_bit_spacing <= (OTHERS => '0');
                ELSE
                    uart_rx_bit_spacing <= uart_rx_bit_spacing + 1;
                END IF;
                IF uart_rx_state = rx_get_start_bit THEN
                    uart_rx_bit_spacing <= (OTHERS => '0');
                END IF;
            END IF;
        END IF;
    END PROCESS rx_bit_spacing;
    ---------------------------------------------------------------------------
    -- UART_RECEIVE_DATA
    ---------------------------------------------------------------------------
    uart_receive_data : PROCESS (clock)
    BEGIN
        IF rising_edge(clock) THEN
            IF reset = '1' THEN
                uart_rx_state <= rx_get_start_bit;
                uart_rx_data_vec <= (OTHERS => '0');
                uart_rx_count <= (OTHERS => '0');
                uart_rx_data_out_stb <= '0';
            ELSE
                uart_rx_data_out_stb <= '0';
                CASE uart_rx_state IS
                    WHEN rx_get_start_bit =>
                        IF rx_baud_tick = '1' AND uart_rx_bit = '0' THEN
                            uart_rx_state <= rx_get_data;
                        END IF;
                    WHEN rx_get_data =>
                        IF uart_rx_bit_tick = '1' THEN
                            uart_rx_data_vec(uart_rx_data_vec'high)
                            <= uart_rx_bit;
                            uart_rx_data_vec(
                            uart_rx_data_vec'high - 1 DOWNTO 0
                            ) <= uart_rx_data_vec(
                            uart_rx_data_vec'high DOWNTO 1
                            );
                            IF uart_rx_count < 7 THEN
                                uart_rx_count <= uart_rx_count + 1;
                            ELSE
                                uart_rx_count <= (OTHERS => '0');
                                uart_rx_state <= rx_get_stop_bit;
                            END IF;
                        END IF;
                    WHEN rx_get_stop_bit =>
                        IF uart_rx_bit_tick = '1' THEN
                            IF uart_rx_bit = '1' THEN
                                uart_rx_state <= rx_get_start_bit;
                                uart_rx_data_out_stb <= '1';
                            END IF;
                        END IF;
                    WHEN OTHERS =>
                        uart_rx_state <= rx_get_start_bit;
                END CASE;
            END IF;
        END IF;
    END PROCESS uart_receive_data;
    ---------------------------------------------------------------------------
    -- TX_CLOCK_DIVIDER
    -- Generate baud ticks at the required rate based on the input clock
    -- frequency and baud rate
    ---------------------------------------------------------------------------
    tx_clock_divider : PROCESS (clock)
    BEGIN
        IF rising_edge (clock) THEN
            IF reset = '1' THEN
                tx_baud_counter <= (OTHERS => '0');
                tx_baud_tick <= '0';
            ELSE
                IF tx_baud_counter = c_tx_div THEN
                    tx_baud_counter <= (OTHERS => '0');
                    tx_baud_tick <= '1';
                ELSE
                    tx_baud_counter <= tx_baud_counter + 1;
                    tx_baud_tick <= '0';
                END IF;
            END IF;
        END IF;
    END PROCESS tx_clock_divider;
    ---------------------------------------------------------------------------
    -- UART_SEND_DATA 
    -- Get data from data_stream_in and send it one bit at a time upon each 
    -- baud tick. Send data lsb first.
    -- wait 1 tick, send start bit (0), send data 0-7, send stop bit (1)
    ---------------------------------------------------------------------------
    uart_send_data : PROCESS (clock)
    BEGIN
        IF rising_edge(clock) THEN
            IF reset = '1' THEN
                uart_tx_data <= '1';
                uart_tx_data_vec <= (OTHERS => '0');
                uart_tx_count <= (OTHERS => '0');
                uart_tx_state <= tx_send_start_bit;
                uart_rx_data_in_ack <= '0';
            ELSE
                uart_rx_data_in_ack <= '0';
                CASE uart_tx_state IS
                    WHEN tx_send_start_bit =>
                        IF tx_baud_tick = '1' AND data_stream_in_stb = '1' THEN
                            uart_tx_data <= '0';
                            uart_tx_state <= tx_send_data;
                            uart_tx_count <= (OTHERS => '0');
                            uart_rx_data_in_ack <= '1';
                            uart_tx_data_vec <= data_stream_in;
                        END IF;
                    WHEN tx_send_data =>
                        IF tx_baud_tick = '1' THEN
                            uart_tx_data <= uart_tx_data_vec(0);
                            uart_tx_data_vec(
                            uart_tx_data_vec'high - 1 DOWNTO 0
                            ) <= uart_tx_data_vec(
                            uart_tx_data_vec'high DOWNTO 1
                            );
                            IF uart_tx_count < 7 THEN
                                uart_tx_count <= uart_tx_count + 1;
                            ELSE
                                uart_tx_count <= (OTHERS => '0');
                                uart_tx_state <= tx_send_stop_bit;
                            END IF;
                        END IF;
                    WHEN tx_send_stop_bit =>
                        IF tx_baud_tick = '1' THEN
                            uart_tx_data <= '1';
                            uart_tx_state <= tx_send_start_bit;
                        END IF;
                    WHEN OTHERS =>
                        uart_tx_data <= '1';
                        uart_tx_state <= tx_send_start_bit;
                END CASE;
            END IF;
        END IF;
    END PROCESS uart_send_data;
END rtl;