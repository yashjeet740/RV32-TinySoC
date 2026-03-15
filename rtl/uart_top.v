module uart_top #(
    parameter CLKS_PER_BIT = 87
)(
    input clk,
    input rst,
    input uart_ce,
    
    // Transmitter Interface
    input tx_start,
    input [7:0] tx_data_in,
    output tx_busy,
    output uart_tx_out, // Physical TX pin
    
    // Receiver Interface
    input uart_rx_in,   // Physical RX pin
    output [7:0] rx_data_out,
    output rx_done
);

    // Instantiate the Transmitter
    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) transmitter (
        .clk(clk),
        .rst(rst),
        .uart_ce(uart_ce),
        .start(tx_start),
        .data_in(tx_data_in),
        .tx(uart_tx_out),
        .tx_busy(tx_busy)
    );

    // Instantiate the Receiver
    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) receiver (
        .clk(clk),
        .rst(rst),
        .uart_ce(uart_ce),
        .rx(uart_rx_in),
        .data_out(rx_data_out),
        .rx_done(rx_done)
    );

endmodule
