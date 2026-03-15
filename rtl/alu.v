//==============================================================================
// ALU - RV32I Arithmetic Logic Unit
//==============================================================================
// Synthesizable, synchronous reset, no initial blocks.
// Used by: riscv_core (Decode/Execute stage).
//==============================================================================

module alu #(
    parameter DATA_W = 32
)(
    input  wire [3:0]  op,      // ALU operation (see ALU_OP_*)
    input  wire [31:0] a,       // Operand A (rs1)
    input  wire [31:0] b,       // Operand B (rs2 or immediate)
    output reg  [31:0] result, // ALU result
    output reg         zero,   // Result == 0 (for branches)
    output reg         lt,     // Signed less-than (a < b)
    output reg         ltu    // Unsigned less-than (a < b)
);

    //----------------------------------------------------------------------
    // ALU operation encoding (matches control.v)
    //----------------------------------------------------------------------
    localparam [3:0] ALU_OP_ADD  = 4'd0;
    localparam [3:0] ALU_OP_SUB  = 4'd1;
    localparam [3:0] ALU_OP_SLL  = 4'd2;
    localparam [3:0] ALU_OP_SLT  = 4'd3;
    localparam [3:0] ALU_OP_SLTU = 4'd4;
    localparam [3:0] ALU_OP_XOR  = 4'd5;
    localparam [3:0] ALU_OP_SRL  = 4'd6;
    localparam [3:0] ALU_OP_SRA  = 4'd7;
    localparam [3:0] ALU_OP_OR   = 4'd8;
    localparam [3:0] ALU_OP_AND  = 4'd9;
    localparam [3:0] ALU_OP_PASS = 4'd10;  // Pass A (for LUI / link)

    wire [31:0] shamt;
    assign shamt = b[4:0];

    always @(*) begin
        zero = 1'b0;
        lt   = 1'b0;
        ltu  = 1'b0;
        result = 32'b0;
        case (op)
            ALU_OP_ADD:  result = a + b;
            ALU_OP_SUB:  result = a - b;
            ALU_OP_SLL:  result = a << shamt;
            ALU_OP_SLT:  begin result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; lt = (result == 32'd1); end
            ALU_OP_SLTU: begin result = (a < b) ? 32'd1 : 32'd0; ltu = (result == 32'd1); end
            ALU_OP_XOR:  result = a ^ b;
            ALU_OP_SRL:  result = a >> shamt;
            ALU_OP_SRA:  result = $signed(a) >>> shamt;
            ALU_OP_OR:   result = a | b;
            ALU_OP_AND:  result = a & b;
            ALU_OP_PASS: result = a;
            default:     result = a + b;
        endcase
        if (result == 32'b0) zero = 1'b1;
    end

endmodule
