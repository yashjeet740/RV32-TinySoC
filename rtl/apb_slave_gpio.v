//==============================================================================
// APB Slave - GPIO Controller (0x4000_1000)
//==============================================================================
// 8-bit GPIO: one 32-bit register at offset 0. Write sets output; read returns output.
// Pins are output-only in this version; extend to bidir if needed.
//==============================================================================

module apb_slave_gpio (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire [31:0] PADDR,
    input  wire        PWRITE,
    input  wire [31:0] PWDATA,
    output reg         PREADY,
    output reg  [31:0] PRDATA,

    // 8-bit GPIO pins (output; for bidir, add direction register and mux)
    output wire [7:0]  gpio_out
);

    reg [7:0] gpio_reg;

    assign gpio_out = gpio_reg;

    always @(posedge PCLK) begin
        if (!PRESETn) begin
            gpio_reg <= 8'b0;
            PREADY   <= 1'b0;
            PRDATA   <= 32'b0;
        end else begin
            PREADY <= 1'b0;
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (PWRITE)
                    gpio_reg <= PWDATA[7:0];
                else
                    PRDATA <= {24'b0, gpio_reg};
            end
        end
    end

endmodule
