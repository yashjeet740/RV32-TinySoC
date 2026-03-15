//==============================================================================
// 16 KB Synchronous Dual-Port RAM (Instruction / Data storage)
//==============================================================================
// 4K x 32-bit words per port; byte-write enable. Synchronous read (registered).
// Port A and Port B are independent; both can read/write. No initial blocks.
//==============================================================================

module ram_16k #(
    parameter ADDR_W = 12,   // 12 bits = 4K words = 16 KB
    parameter DATA_W = 32
)(
    input  wire         clk,

    // Port A
    input  wire [ADDR_W-1:0] addr_a,
    input  wire              we_a,
    input  wire [3:0]        sel_a,
    input  wire [DATA_W-1:0] wdata_a,
    output reg  [DATA_W-1:0] rdata_a,

    // Port B
    input  wire [ADDR_W-1:0] addr_b,
    input  wire              we_b,
    input  wire [3:0]        sel_b,
    input  wire [DATA_W-1:0] wdata_b,
    output reg  [DATA_W-1:0] rdata_b
);

    reg [DATA_W-1:0] mem [0:(1<<ADDR_W)-1];

    // Port A: synchronous write, synchronous read
    always @(posedge clk) begin
        rdata_a <= mem[addr_a];
        if (we_a) begin
            if (sel_a[0]) mem[addr_a][7:0]   <= wdata_a[7:0];
            if (sel_a[1]) mem[addr_a][15:8]  <= wdata_a[15:8];
            if (sel_a[2]) mem[addr_a][23:16] <= wdata_a[23:16];
            if (sel_a[3]) mem[addr_a][31:24] <= wdata_a[31:24];
        end
    end

    // Port B: synchronous write, synchronous read
    always @(posedge clk) begin
        rdata_b <= mem[addr_b];
        if (we_b) begin
            if (sel_b[0]) mem[addr_b][7:0]   <= wdata_b[7:0];
            if (sel_b[1]) mem[addr_b][15:8]  <= wdata_b[15:8];
            if (sel_b[2]) mem[addr_b][23:16] <= wdata_b[23:16];
            if (sel_b[3]) mem[addr_b][31:24] <= wdata_b[31:24];
        end
    end

endmodule
