//==============================================================================
// RV32I RISC-V Core - 3-Stage Pipeline (Fetch | Decode/Execute | Writeback)
//==============================================================================
// Memory-Mapped I/O interface: addr, wdata, rdata, we, sel.
// Synchronous reset; no initial blocks; all registers resettable.
// Sub-modules: alu, control, regfile (separate files for floorplanning).
//==============================================================================

module riscv_core #(
    parameter RESET_VECTOR = 32'h0000_0000
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        ext_stall,  // External stall (e.g. from APB when mem_wait)

    // Memory / MMIO interface (single port, shared fetch and data)
    output reg  [31:0] addr,
    output reg  [31:0] wdata,
    input  wire [31:0] rdata,
    output reg         we,
    output reg  [3:0]  sel
);

    //----------------------------------------------------------------------
    // Instruction field decode (from current instruction in Decode stage)
    //----------------------------------------------------------------------
    wire [6:0] opcode;
    wire [4:0] rd, rs1, rs2;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;
    wire [31:0] imm_eff;

    // Pipeline register: Fetch -> Decode/Execute
    reg [31:0] fd_ir;      // instruction
    reg [31:0] fd_pc_plus4;

    // Decode stage: drive from fd_ir
    assign opcode = fd_ir[6:0];
    assign rd     = fd_ir[11:7];
    assign funct3 = fd_ir[14:12];
    assign rs1    = fd_ir[19:15];
    assign rs2    = fd_ir[24:20];
    assign funct7 = fd_ir[31:25];

    // Immediate decode (combinational)
    assign imm_i = { {20{fd_ir[31]}}, fd_ir[31:20] };
    assign imm_s = { {20{fd_ir[31]}}, fd_ir[31:25], fd_ir[11:7] };
    assign imm_b = { {19{fd_ir[31]}}, fd_ir[31], fd_ir[7], fd_ir[30:25], fd_ir[11:8], 1'b0 };
    assign imm_u = { fd_ir[31:12], 12'b0 };
    assign imm_j = { {11{fd_ir[31]}}, fd_ir[31], fd_ir[19:12], fd_ir[20], fd_ir[30:21], 1'b0 };

    // Effective immediate (by imm_type from control)
    wire [2:0] ctrl_imm_type;
    assign imm_eff = (ctrl_imm_type == 3'd0) ? imm_i :
                     (ctrl_imm_type == 3'd1) ? imm_s :
                     (ctrl_imm_type == 3'd2) ? imm_b :
                     (ctrl_imm_type == 3'd3) ? imm_u :
                     imm_j;

    //----------------------------------------------------------------------
    // Control unit (combinational)
    //----------------------------------------------------------------------
    wire [3:0]  ctrl_alu_op;
    wire        ctrl_alu_src;
    wire        ctrl_rf_we;
    wire [1:0]  ctrl_wb_sel;
    wire        ctrl_mem_we;
    wire        ctrl_mem_re;
    wire [2:0]  ctrl_mem_width;
    wire        ctrl_branch;
    wire [2:0]  ctrl_branch_op;
    wire        ctrl_jal;
    wire        ctrl_jalr;

    control u_control (
        .opcode   (opcode),
        .funct3   (funct3),
        .funct7   (funct7),
        .alu_op   (ctrl_alu_op),
        .alu_src  (ctrl_alu_src),
        .rf_we    (ctrl_rf_we),
        .wb_sel   (ctrl_wb_sel),
        .mem_we   (ctrl_mem_we),
        .mem_re   (ctrl_mem_re),
        .mem_width(ctrl_mem_width),
        .branch   (ctrl_branch),
        .branch_op(ctrl_branch_op),
        .jal      (ctrl_jal),
        .jalr     (ctrl_jalr),
        .imm_type (ctrl_imm_type)
    );

    //----------------------------------------------------------------------
    // Register file (read in D/E, write in WB)
    //----------------------------------------------------------------------
    wire [31:0] rs1_rdata, rs2_rdata;
    wire [31:0] rf_wdata;
    wire        rf_we_wb;
    wire [4:0]  rd_wb;

    regfile #(.ADDR_W(5), .DATA_W(32)) u_regfile (
        .clk      (clk),
        .rst      (rst),
        .rs1_addr (rs1),
        .rs2_addr (rs2),
        .rd_addr  (rd_wb),
        .rd_we    (rf_we_wb),
        .rd_wdata (rf_wdata),
        .rs1_rdata(rs1_rdata),
        .rs2_rdata(rs2_rdata)
    );

    // Forwarding: WB result to D/E when WB writes rd == rs1 or rs2
    wire [31:0] rs1_eff = (rd_wb == rs1 && rf_we_wb && |rd_wb) ? rf_wdata : rs1_rdata;
    wire [31:0] rs2_eff = (rd_wb == rs2 && rf_we_wb && |rd_wb) ? rf_wdata : rs2_rdata;

    //----------------------------------------------------------------------
    // ALU (Decode/Execute stage)
    //----------------------------------------------------------------------
    localparam [6:0] OP_AUIPC = 7'b0010111;
    localparam [6:0] OP_LUI   = 7'b0110111;
    wire [31:0] alu_a = (opcode == OP_LUI)   ? imm_eff :
                        (opcode == OP_AUIPC) ? (fd_pc_plus4 - 32'd4) : rs1_eff;
    wire [31:0] alu_b = ctrl_alu_src ? imm_eff : rs2_eff;
    wire [31:0] alu_result;
    wire        alu_zero, alu_lt, alu_ltu;

    alu u_alu (
        .op    (ctrl_alu_op),
        .a     (alu_a),
        .b     (alu_b),
        .result(alu_result),
        .zero  (alu_zero),
        .lt    (alu_lt),
        .ltu   (alu_ltu)
    );

    // Branch taken (combinational)
    wire branch_taken = ctrl_branch && (
        (ctrl_branch_op == 3'b000 && alu_zero) ||   // beq
        (ctrl_branch_op == 3'b001 && !alu_zero) ||  // bne
        (ctrl_branch_op == 3'b100 && alu_lt) ||     // blt
        (ctrl_branch_op == 3'b101 && !alu_lt) ||    // bge
        (ctrl_branch_op == 3'b110 && alu_ltu) ||    // bltu
        (ctrl_branch_op == 3'b111 && !alu_ltu)      // bgeu
    );
    wire [31:0] branch_target = fd_pc_plus4 + imm_b;
    wire [31:0] jal_target    = fd_pc_plus4 + imm_j;
    wire [31:0] jalr_target   = (rs1_eff + imm_i) & 32'hFFFF_FFFE;

    //----------------------------------------------------------------------
    // PC and Fetch stage
    //----------------------------------------------------------------------
    reg [31:0] pc;
    wire       stall;   // use memory for load/store or external wait
    wire       is_load_store = ctrl_mem_we | ctrl_mem_re;
    assign stall = is_load_store | ext_stall;

    // Shared PC+4 adder (used for next PC and WB)
    wire [31:0] pc_plus4 = pc + 32'd4;

    // Next PC (when not stalled)
    wire [31:0] next_pc = (jalr)           ? jalr_target :
                          (jal)            ? jal_target  :
                          (branch_taken)   ? branch_target :
                          pc_plus4;

    always @(posedge clk) begin
        if (rst) begin
            pc <= RESET_VECTOR;
        end else if (!stall) begin
            pc <= next_pc;
        end
    end

    //----------------------------------------------------------------------
    // Memory interface (single port: fetch vs load/store)
    //----------------------------------------------------------------------
    wire [31:0] mem_addr  = stall ? alu_result : pc;
    wire        mem_we    = stall && ctrl_mem_we;
    wire [31:0] mem_wdata = rs2_eff;

    // Byte strobes from store size and address
    wire [1:0] mem_addr_lo = alu_result[1:0];
    wire [3:0] mem_sel = (ctrl_mem_width == 3'b000) ? (4'b0001 << mem_addr_lo) :
                         (ctrl_mem_width == 3'b001) ? (alu_result[1] ? 4'b1100 : 4'b0011) :
                         4'b1111;

    always @(posedge clk) begin
        if (rst) begin
            addr  <= 32'b0;
            wdata <= 32'b0;
            we    <= 1'b0;
            sel   <= 4'b0;
        end else begin
            addr  <= mem_addr;
            wdata <= mem_wdata;
            we    <= mem_we;
            sel   <= mem_we ? mem_sel : 4'b1111;
        end
    end

    //----------------------------------------------------------------------
    // Pipeline register: F -> D/E (instruction and PC+4)
    //----------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            fd_ir       <= 32'h0000_0013;  // NOP (addi x0,x0,0)
            fd_pc_plus4 <= 32'b0;
        end else if (stall) begin
            fd_ir       <= fd_ir;
            fd_pc_plus4 <= fd_pc_plus4;
        end else if (jalr | jal | branch_taken) begin
            fd_ir       <= 32'h0000_0013;
            fd_pc_plus4 <= next_pc;
        end else begin
            fd_ir       <= rdata;
            fd_pc_plus4 <= pc_plus4;
        end
    end

    //----------------------------------------------------------------------
    // Pipeline register: D/E -> WB (writeback controls and data)
    //----------------------------------------------------------------------
    reg [31:0] wb_alu_result;
    reg [31:0] wb_pc_plus4;
    reg [1:0]  wb_sel_r;
    reg        wb_rf_we;
    reg [4:0]  wb_rd;
    reg [2:0]  wb_mem_width;
    reg        wb_load_unsigned;
    reg [1:0]  wb_load_addr_lo;

    // Load result register (captured when we use memory for load)
    reg [31:0] wb_load_data;
    reg        wb_load_valid;

    always @(posedge clk) begin
        if (rst) begin
            wb_alu_result     <= 32'b0;
            wb_pc_plus4       <= 32'b0;
            wb_sel_r          <= 2'b00;
            wb_rf_we          <= 1'b0;
            wb_rd             <= 5'b0;
            wb_mem_width      <= 3'b010;
            wb_load_unsigned  <= 1'b0;
            wb_load_data      <= 32'b0;
            wb_load_valid     <= 1'b0;
            wb_load_addr_lo   <= 2'b0;
        end else if (stall && ctrl_mem_re) begin
            wb_load_valid    <= 1'b1;
            wb_rd            <= rd;
            wb_rf_we         <= ctrl_rf_we;
            wb_sel_r         <= 2'b01;
            wb_mem_width     <= ctrl_mem_width;
            wb_load_unsigned <= (funct3[2] == 1'b1);
            wb_load_data     <= rdata;
            wb_load_addr_lo  <= alu_result[1:0];
        end else if (!stall) begin
            wb_load_valid <= 1'b0;
            if (!wb_load_valid) begin
                wb_alu_result     <= alu_result;
                wb_pc_plus4       <= fd_pc_plus4;
                wb_sel_r          <= ctrl_wb_sel;
                wb_rf_we          <= ctrl_rf_we;
                wb_rd             <= rd;
                wb_mem_width     <= ctrl_mem_width;
                wb_load_unsigned <= (funct3[2] == 1'b1);
                wb_load_data     <= wb_load_data;
                wb_load_addr_lo  <= wb_load_addr_lo;
            end
        end
    end

    // Extract byte/half from loaded word by address, then sign/zero extend
    wire [7:0]  load_byte  = (wb_load_addr_lo == 2'd0) ? wb_load_data[7:0]   :
                             (wb_load_addr_lo == 2'd1) ? wb_load_data[15:8]  :
                             (wb_load_addr_lo == 2'd2) ? wb_load_data[23:16] : wb_load_data[31:24];
    wire [15:0] load_half  = wb_load_addr_lo[1] ? wb_load_data[31:16] : wb_load_data[15:0];
    wire [31:0] load_ext   = (wb_mem_width == 3'b000) ? (wb_load_unsigned ? {24'b0, load_byte}  : {{24{load_byte[7]}},  load_byte}) :
                             (wb_mem_width == 3'b001) ? (wb_load_unsigned ? {16'b0, load_half} : {{16{load_half[15]}}, load_half}) :
                             wb_load_data;

    assign rd_wb   = wb_rd;
    assign rf_we_wb = wb_rf_we;
    assign rf_wdata = (wb_sel_r == 2'b00) ? wb_alu_result :
                      (wb_sel_r == 2'b01) ? load_ext :
                      wb_pc_plus4;

endmodule
