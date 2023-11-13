LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
ENTITY uart_top IS
    GENERIC (
        CLK_FREQ : POSITIVE := 100e6; -- system clock frequency in Hz
        BAUD_RATE : POSITIVE := 115200; -- baud rate value
        INPUT_SIZE : POSITIVE := 32; -- input size (in bits)
        OUTPUT_SIZE : POSITIVE := 16 -- ouput size (in bits)
    );
    PORT (
        -- CLOCK AND RESET
        clock : IN STD_LOGIC; -- system clock
        reset : IN STD_LOGIC; -- high active synchronous reset
        -- BUFFER INTERFACE
        input_word : OUT STD_LOGIC_VECTOR(INPUT_SIZE * 8 - 1 DOWNTO 0);
        input_valid : OUT STD_LOGIC;
        output_word : IN STD_LOGIC_VECTOR(OUTPUT_SIZE * 8 - 1 DOWNTO 0);
        output_valid : IN STD_LOGIC;
        -- UART INTERFACE
        uart_tx : OUT STD_LOGIC; -- serial transmit data
        uart_rx : IN STD_LOGIC -- serial receive data
    );
END uart_top;

ARCHITECTURE Structure OF uart_top IS

    COMPONENT uart_transmitter IS
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
    END COMPONENT;

    COMPONENT uart_controller IS
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
    END COMPONENT;

    COMPONENT parallel_serial_register IS
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
    END COMPONENT;

    SIGNAL data_stream_in_stb, data_stream_in_ack, data_stream_out_stb, shift, load : STD_LOGIC := '0';
    SIGNAL data_stream_out, data_stream_in : STD_LOGIC_VECTOR(7 DOWNTO 0);
BEGIN

    u : uart_transmitter
    GENERIC MAP(
        clock_frequency => CLK_FREQ, baud => BAUD_RATE
    )
    PORT MAP(
        clock => clock, reset => reset,
        tx => uart_tx, rx => uart_rx,
        data_stream_in => data_stream_in, data_stream_in_stb => data_stream_in_stb, data_stream_in_ack => data_stream_in_ack,
        data_stream_out => data_stream_out, data_stream_out_stb => data_stream_out_stb
    );

    -- MAX_SIZE need to be the maximum between INPUT and OUTPUT SIZE
    cond_A : IF INPUT_SIZE > OUTPUT_SIZE GENERATE       
        buf_A : parallel_serial_register
        GENERIC MAP(
            INPUT_SIZE => OUTPUT_SIZE,
            OUTPUT_SIZE => INPUT_SIZE,
            MAX_SIZE => INPUT_SIZE
        )
        PORT MAP(
            clock => clock, reset => reset, load => load, shift => shift,
            serial_in => data_stream_out, serial_out => data_stream_in,
            parallel_in => output_word, parallel_out => input_word
        );
        ctrl_A : uart_controller
        GENERIC MAP(
            INPUT_SIZE => INPUT_SIZE,
            OUTPUT_SIZE => OUTPUT_SIZE,
            MAX_SIZE => INPUT_SIZE
        )
        PORT MAP(
            clock => clock, reset => reset,
            data_stream_in_stb => data_stream_in_stb, data_stream_in_ack => data_stream_in_ack, data_stream_out_stb => data_stream_out_stb,
            input_valid => input_valid, output_valid => output_valid,
            load => load, shift => shift
        );
    END GENERATE;

    cond_B : IF INPUT_SIZE <= OUTPUT_SIZE GENERATE

        buf_B : parallel_serial_register
        GENERIC MAP(
            INPUT_SIZE => OUTPUT_SIZE,
            OUTPUT_SIZE => INPUT_SIZE,
            MAX_SIZE => OUTPUT_SIZE
        )
        PORT MAP(
            clock => clock, reset => reset, load => load, shift => shift,
            serial_in => data_stream_out, serial_out => data_stream_in,
            parallel_in => output_word, parallel_out => input_word
        );
        ctrl_B : uart_controller
        GENERIC MAP(
            INPUT_SIZE => INPUT_SIZE,
            OUTPUT_SIZE => OUTPUT_SIZE,
            MAX_SIZE => OUTPUT_SIZE
        )
        PORT MAP(
            clock => clock, reset => reset,
            data_stream_in_stb => data_stream_in_stb, data_stream_in_ack => data_stream_in_ack, data_stream_out_stb => data_stream_out_stb,
            input_valid => input_valid, output_valid => output_valid,
            load => load, shift => shift
        );
    END GENERATE;
END Structure;