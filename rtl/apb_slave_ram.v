//==============================================================================
// APB Slave - 16 KB RAM (0x0000_0000 - 0x0000_3FFF)
//==============================================================================
// Uses one port of dual-port ram_16k. Word address = PADDR[13:2].
// Read has 1-cycle latency (sync RAM); PREADY asserted one ENABLE cycle after.
// Reset: synchronous (PRESETn sampled on posedge PCLK) for Yosys/OpenLane.
//==============================================================================

module apb_slave_ram (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire [31:0] PADDR,
    input  wire        PWRITE,
    input  wire [31:0] PWDATA,
    input  wire [3:0]  PSTRB,
    output reg         PREADY,
    output reg  [31:0] PRDATA
);

    wire [11:0] word_addr = PADDR[13:2];
    wire        op_read   = PSEL & PENABLE & ~PWRITE;

    reg [11:0] read_addr_r;
    reg        read_pending;

    always @(posedge PCLK) begin
        if (!PRESETn) begin
            read_addr_r  <= 12'b0;
            read_pending  <= 1'b0;
            PREADY        <= 1'b0;
            PRDATA        <= 32'b0;
        end else begin
            PREADY <= 1'b0;
            if (PSEL && PENABLE) begin
                if (PWRITE) begin
                    PREADY <= 1'b1;
                end else begin
                    if (read_pending) begin
                        PREADY    <= 1'b1;
                        PRDATA    <= ram_rdata;
                        read_pending <= 1'b0;
                    end else begin
                        read_addr_r  <= word_addr;
                        read_pending  <= 1'b1;
                    end
                end
            end else
                read_pending <= 1'b0;
        end
    end

    wire [31:0] ram_rdata;
    wire [11:0] ram_addr  = read_pending ? read_addr_r : word_addr;
    wire        ram_we    = PSEL && PENABLE && PWRITE;
    wire [3:0]  ram_sel   = PSTRB;

    ram_16k #(.ADDR_W(12), .DATA_W(32)) u_ram (
        .clk    (PCLK),
        .addr_a (ram_addr),
        .we_a   (ram_we),
        .sel_a  (ram_sel),
        .wdata_a(PWDATA),
        .rdata_a(ram_rdata),
        .addr_b (12'b0),
        .we_b   (1'b0),
        .sel_b  (4'b0),
        .wdata_b(32'b0),
        .rdata_b()
    );

endmodule
