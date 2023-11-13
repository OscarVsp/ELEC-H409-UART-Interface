library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_top_loopback is
    GENERIC (
        CLK_FREQ : POSITIVE := 100e6; -- system clock frequency in Hz
        BAUD_RATE : POSITIVE := 115200 -- baud rate value
    );
    Port ( clk : in STD_LOGIC;
           reset : in STD_LOGIC;
           uart_rx : in STD_LOGIC;
           uart_tx : out STD_LOGIC);
end uart_top_loopback;

architecture Behavioral of uart_top_loopback is

component uart_top IS
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
END component;

signal buffer_loopback : std_logic_vector(127 downto 0);
signal ready_loopback : std_logic;

begin

uut : uart_top generic map(
    CLK_FREQ => CLK_FREQ,
    BAUD_RATE => BAUD_RATE,
    INPUT_SIZE => 16,
    OUTPUT_SIZE => 16
    ) port map(
        clock => clk, 
        reset => reset,
        output_word => buffer_loopback,
        input_word => buffer_loopback,
        output_valid => ready_loopback,
        input_valid => ready_loopback,
        uart_tx => uart_tx, 
        uart_rx => uart_rx
    );
end Behavioral;
