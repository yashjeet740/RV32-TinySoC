module uart_rx #(
    parameter CLKS_PER_BIT = 87
)(
    input clk,
    input rst,
    input uart_ce,      // Clock enable for power gating
    input rx,
    output reg [7:0] data_out,
    output reg rx_done
);

    localparam [1:0] IDLE=2'b00, START=2'b01, DATA=2'b10, STOP=2'b11;

    reg [1:0] state;
    reg [15:0] clk_count;
    reg [2:0] bit_index;

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            rx_done   <= 1'b0;
            clk_count <= 16'b0;
            bit_index <= 3'b0;
            data_out  <= 8'b00000000;
        end else if (uart_ce) begin
            // Pulse rx_done for only 1 clock cycle when finished
            rx_done <= 1'b0; 
            
            case (state)
                IDLE: begin
                    clk_count <= 16'b0;
                    bit_index <= 3'b0;
                    // Detect the falling edge of the Start bit (rx drops to 0)
                    if (rx == 1'b0) begin
                        state <= START;
                    end
                end

                START: begin
                    // Wait until the MIDDLE of the start bit to sample
                    if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        if (rx == 1'b0) begin // Verify it's still 0 (valid start bit)
                            clk_count <= 16'b0; // Reset counter for the data bits
                            state     <= DATA;
                        end else begin
                            state <= IDLE;  // False alarm (noise glitch)
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    // Wait one full bit period to sample the middle of the next bit
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 16'b0;
                        data_out[bit_index] <= rx; // Sample the bit!
                        
                        if (bit_index < 3'd7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 3'b0;
                            state     <= STOP;
                        end
                    end
                end

                STOP: begin
                    // Wait one full bit period for the Stop bit (rx should be 1)
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        rx_done <= 1'b1; // Tell the system a byte is ready!
                        state   <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
