//==============================================================================
// Register File - 32 x 32-bit (x0 hardwired to zero)
//==============================================================================
// Synthesizable, synchronous write. No explicit reset on registers so they
// infer without reset muxes; x0 is hardwired to 0 via read logic.
// Used by: riscv_core (Decode/Execute read, Writeback stage write).
//==============================================================================

module regfile #(
    parameter ADDR_W = 5,
    parameter DATA_W = 32
)(
    input  wire         clk,
    input  wire         rst,
    input  wire [ADDR_W-1:0] rs1_addr,
    input  wire [ADDR_W-1:0] rs2_addr,
    input  wire [ADDR_W-1:0] rd_addr,
    input  wire              rd_we,
    input  wire [DATA_W-1:0]  rd_wdata,
    output wire [DATA_W-1:0] rs1_rdata,
    output wire [DATA_W-1:0] rs2_rdata
);

    reg [DATA_W-1:0] regs [1:31];  // x1..x31; x0 is always 0

    // Synchronous write; no reset. x0 is handled in read muxes.
    always @(posedge clk) begin
        if (rd_we && |rd_addr) begin
            regs[rd_addr] <= rd_wdata;
        end
    end

    // Read (combinational); x0 returns 0
    assign rs1_rdata = (rs1_addr == {ADDR_W{1'b0}}) ? {DATA_W{1'b0}} : regs[rs1_addr];
    assign rs2_rdata = (rs2_addr == {ADDR_W{1'b0}}) ? {DATA_W{1'b0}} : regs[rs2_addr];

endmodule
