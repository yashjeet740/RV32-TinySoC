module uart_tx #(
    parameter CLKS_PER_BIT = 87 // e.g., 10 MHz Clock / 115200 Baud = ~87
)(
    input clk,
    input rst,
    input uart_ce,      // Clock enable for power gating
    input start,
    input [7:0] data_in,
    output reg tx,
    output reg tx_busy // NEW: Tells the system when it's safe to send more data
);

    localparam [1:0] IDLE=2'b00, START=2'b01, DATA=2'b10, STOP=2'b11;

    reg [1:0] state;
    reg [2:0] bit_index; // Optimized to 3 bits (0-7)
    reg [7:0] data_reg;
    reg [15:0] clk_count; // NEW: Counter for the baud rate

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            tx        <= 1'b1;
            tx_busy   <= 1'b0;
            clk_count <= 16'b0;
            bit_index <= 3'b0;
            data_reg  <= 8'b0;
        end else if (uart_ce) begin
            case (state)
                IDLE: begin
                    tx        <= 1'b1;
                    tx_busy   <= 1'b0;
                    clk_count <= 16'b0;
                    if (start) begin
                        data_reg <= data_in;
                        state    <= START;
                        tx_busy  <= 1'b1;
                    end
                end

                START: begin
                    tx <= 1'b0;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'b0;
                        bit_index <= 3'b0;
                        state     <= DATA;
                    end
                end

                DATA: begin
                    tx <= data_reg[bit_index];
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'b0;
                        if (bit_index == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_index <= bit_index + 1'b1;
                        end
                    end
                end

                STOP: begin
                    tx <= 1'b1;
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
