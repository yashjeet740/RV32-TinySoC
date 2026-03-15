//==============================================================================
// APB Slave - Trap / Test Exit (0x4000_F000)
//==============================================================================
// When the core writes 0x01 to this address, the test has passed (e.g. TB
// monitors the bus and finishes). Always returns PREADY=1; PRDATA=0 on read.
//==============================================================================

module apb_slave_trap (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire [31:0] PADDR,
    input  wire        PWRITE,
    input  wire [31:0] PWDATA,
    output reg         PREADY,
    output reg  [31:0] PRDATA
);

    always @(posedge PCLK) begin
        if (!PRESETn) begin
            PREADY <= 1'b0;
            PRDATA <= 32'b0;
        end else begin
            PREADY <= 1'b0;
            PRDATA <= 32'b0;
            if (PSEL && PENABLE) begin
                PREADY <= 1'b1;
                if (!PWRITE)
                    PRDATA <= 32'b0;
            end
        end
    end

endmodule
