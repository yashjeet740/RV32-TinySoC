//==============================================================================
// Control - RV32I Instruction Decoder & Control Signals
//==============================================================================
// Combinational decode from opcode, funct3, funct7.
// Synthesizable, no state, no initial blocks.
// Used by: riscv_core (Decode/Execute stage).
//==============================================================================

module control (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,

    output reg [3:0]  alu_op,     // ALU operation (see alu.v ALU_OP_*)
    output reg        alu_src,    // 1 = use immediate, 0 = use rs2
    output reg        rf_we,      // Register file write enable
    output reg [1:0]  wb_sel,     // 00=ALU, 01=mem, 10=PC+4 (JAL/JALR)
    output reg        mem_we,     // Memory write enable (store)
    output reg        mem_re,     // Memory read enable (load)
    output reg [2:0]  mem_width, // 000=byte, 001=half, 010=word (for load/store size)
    output reg        branch,    // Branch instruction
    output reg [2:0]  branch_op, // Branch type: 000=eq, 001=ne, 100=lt, 101=ge, 110=ltu, 111=geu
    output reg        jal,
    output reg        jalr,
    output reg [2:0]  imm_type   // I=000, S=001, B=010, U=011, J=100
);

    //----------------------------------------------------------------------
    // RV32I Opcodes (7-bit)
    //----------------------------------------------------------------------
    localparam [6:0] OP_LUI   = 7'b0110111;
    localparam [6:0] OP_AUIPC = 7'b0010111;
    localparam [6:0] OP_JAL   = 7'b1101111;
    localparam [6:0] OP_JALR  = 7'b1100111;
    localparam [6:0] OP_BRANCH= 7'b1100011;
    localparam [6:0] OP_LOAD  = 7'b0000011;
    localparam [6:0] OP_STORE = 7'b0100011;
    localparam [6:0] OP_IMM   = 7'b0010011;
    localparam [6:0] OP_REG   = 7'b0110011;

    //----------------------------------------------------------------------
    // ALU op encoding (must match alu.v)
    //----------------------------------------------------------------------
    localparam [3:0] ALU_ADD  = 4'd0;
    localparam [3:0] ALU_SUB  = 4'd1;
    localparam [3:0] ALU_SLL  = 4'd2;
    localparam [3:0] ALU_SLT  = 4'd3;
    localparam [3:0] ALU_SLTU = 4'd4;
    localparam [3:0] ALU_XOR  = 4'd5;
    localparam [3:0] ALU_SRL  = 4'd6;
    localparam [3:0] ALU_SRA  = 4'd7;
    localparam [3:0] ALU_OR   = 4'd8;
    localparam [3:0] ALU_AND  = 4'd9;
    localparam [3:0] ALU_PASS = 4'd10;

    localparam [2:0] IMM_I = 3'd0;
    localparam [2:0] IMM_S = 3'd1;
    localparam [2:0] IMM_B = 3'd2;
    localparam [2:0] IMM_U = 3'd3;
    localparam [2:0] IMM_J = 3'd4;

    always @(*) begin
        alu_op    = ALU_ADD;
        alu_src   = 1'b1;   // default immediate
        rf_we     = 1'b0;
        wb_sel    = 2'b00;  // ALU
        mem_we    = 1'b0;
        mem_re    = 1'b0;
        mem_width = 3'b010; // word
        branch    = 1'b0;
        branch_op = 3'b000;
        jal       = 1'b0;
        jalr      = 1'b0;
        imm_type  = IMM_I;

        case (opcode)
            OP_LUI: begin
                alu_op  = ALU_PASS;
                alu_src = 1'b1;
                rf_we   = 1'b1;
                wb_sel  = 2'b00;
                imm_type = IMM_U;
            end
            OP_AUIPC: begin
                alu_op   = ALU_ADD;  // PC + imm
                alu_src  = 1'b1;
                rf_we    = 1'b1;
                wb_sel   = 2'b00;
                imm_type = IMM_U;
            end
            OP_JAL: begin
                jal     = 1'b1;
                rf_we   = 1'b1;
                wb_sel  = 2'b10;    // PC+4
                imm_type = IMM_J;
            end
            OP_JALR: begin
                jalr    = 1'b1;
                alu_op  = ALU_ADD;  // rs1 + imm for target
                alu_src = 1'b1;
                rf_we   = 1'b1;
                wb_sel  = 2'b10;
                imm_type = IMM_I;
            end
            OP_BRANCH: begin
                branch = 1'b1;
                alu_src = 1'b0;     // compare rs1, rs2
                alu_op  = ALU_SUB;  // for eq/ne (zero), others use lt/ltu
                imm_type = IMM_B;
                case (funct3)
                    3'b000: branch_op = 3'b000; // beq
                    3'b001: branch_op = 3'b001; // bne
                    3'b100: branch_op = 3'b100; // blt
                    3'b101: branch_op = 3'b101; // bge
                    3'b110: branch_op = 3'b110; // bltu
                    3'b111: branch_op = 3'b111; // bgeu
                    default: branch_op = 3'b000;
                endcase
            end
            OP_LOAD: begin
                alu_op   = ALU_ADD;  // base + offset
                alu_src  = 1'b1;
                rf_we    = 1'b1;
                wb_sel   = 2'b01;    // mem
                mem_re   = 1'b1;
                imm_type = IMM_I;
                case (funct3)
                    3'b000: mem_width = 3'b000; // lb
                    3'b001: mem_width = 3'b001; // lh
                    3'b010: mem_width = 3'b010; // lw
                    3'b100: mem_width = 3'b000; // lbu (same size, sext in WB)
                    3'b101: mem_width = 3'b001; // lhu
                    default: mem_width = 3'b010;
                endcase
            end
            OP_STORE: begin
                alu_op   = ALU_ADD;
                alu_src  = 1'b1;
                mem_we   = 1'b1;
                imm_type = IMM_S;
                case (funct3)
                    3'b000: mem_width = 3'b000; // sb
                    3'b001: mem_width = 3'b001; // sh
                    3'b010: mem_width = 3'b010; // sw
                    default: mem_width = 3'b010;
                endcase
            end
            OP_IMM: begin
                alu_src  = 1'b1;
                rf_we    = 1'b1;
                wb_sel   = 2'b00;
                imm_type = IMM_I;
                case (funct3)
                    3'b000: alu_op = ALU_ADD;  // addi
                    3'b010: alu_op = ALU_SLT;  // slti
                    3'b011: alu_op = ALU_SLTU; // sltiu
                    3'b100: alu_op = ALU_XOR;  // xori
                    3'b110: alu_op = ALU_OR;   // ori
                    3'b111: alu_op = ALU_AND;  // andi
                    3'b001: alu_op = ALU_SLL;  // slli
                    3'b101: alu_op = (funct7[5] ? ALU_SRA : ALU_SRL); // srai / srli
                    default: alu_op = ALU_ADD;
                endcase
            end
            OP_REG: begin
                alu_src = 1'b0;
                rf_we   = 1'b1;
                wb_sel  = 2'b00;
                case (funct3)
                    3'b000: alu_op = (funct7[5] ? ALU_SUB : ALU_ADD);
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = (funct7[5] ? ALU_SRA : ALU_SRL);
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                    default: alu_op = ALU_ADD;
                endcase
            end
            default: ;
        endcase
    end

endmodule
