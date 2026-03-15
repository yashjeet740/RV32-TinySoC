//==============================================================================
// APB Interconnect - Bridges RISC-V Core Memory Interface to APB Slaves
//==============================================================================
// Converts core's raw memory interface (addr, wdata, rdata, we, sel) into
// APB protocol. Provides address decoder and PRDATA multiplexer.
//
// Memory Map:
//   0x0000_0000 - 0x0000_3FFF  (16 KB)  Instruction/Data RAM  (Slave 0)
//   0x4000_0000                (4 B)   UART Controller         (Slave 1)
//   0x4000_1000                (4 B)   GPIO Controller        (Slave 2)
//   0x4000_F000                (4 B)   Trap / test exit        (Slave 3)
//
// APB is 2-phase: SETUP (PSEL=1, PENABLE=0) then ENABLE (PSEL=1, PENABLE=1).
// Output mem_wait is asserted during a transfer so the core can stall.
//==============================================================================

module apb_interconnect (
    input  wire        clk,
    input  wire        rst,

    //---------------------- Core (Master) Interface --------------------------
    input  wire [31:0] core_addr,
    input  wire [31:0] core_wdata,
    input  wire        core_we,
    input  wire [3:0]  core_sel,
    output reg  [31:0] core_rdata,
    output wire        mem_wait,   // Asserted while APB transfer in progress (core should stall)

    //---------------------- APB Master -> Slaves (shared bus) ----------------
    output reg  [31:0] PADDR,
    output reg  [31:0] PWDATA,
    output reg         PWRITE,
    output reg  [3:0]  PSTRB,
    output reg         PENABLE,

    // Slave 0: RAM (0x0000_0000 - 0x0000_3FFF)
    output wire        PSEL0,
    input  wire        PREADY0,
    input  wire [31:0] PRDATA0,

    // Slave 1: UART (0x4000_0000)
    output wire        PSEL1,
    input  wire        PREADY1,
    input  wire [31:0] PRDATA1,

    // Slave 2: GPIO (0x4000_1000)
    output wire        PSEL2,
    input  wire        PREADY2,
    input  wire [31:0] PRDATA2,

    // Slave 3: Trap / test exit (0x4000_F000)
    output wire        PSEL3,
    input  wire        PREADY3,
    input  wire [31:0] PRDATA3
);

    //----------------------------------------------------------------------
    // Memory map constants
    //----------------------------------------------------------------------
    localparam [31:0] RAM_BASE   = 32'h0000_0000;
    localparam [31:0] RAM_END    = 32'h0000_3FFF;   // 16 KB
    localparam [31:0] UART_BASE  = 32'h4000_0000;
    localparam [31:0] GPIO_BASE  = 32'h4000_1000;

    //----------------------------------------------------------------------
    // Address decoder (combinational)
    // Decodes current transfer address into one-hot slave select.
    //----------------------------------------------------------------------
    wire sel_ram  = (core_addr[31:14] == 18'b0);                    // 0x0000_0000 - 0x0000_3FFF
    wire sel_uart = (core_addr[31:12] == 20'h40000);                // 0x4000_0000 (1 page)
    wire sel_gpio = (core_addr[31:12] == 20'h40001);                // 0x4000_1000 (1 page)
    wire sel_trap = (core_addr[31:12] == 20'h4000F);                // 0x4000_F000 (1 page)

    // Latch address and decode at start of transfer for stable PSEL during APB
    reg [31:0] latched_addr;
    reg        latched_we;
    reg [31:0] latched_wdata;
    reg [3:0]  latched_sel;
    reg        latched_sel_ram;
    reg        latched_sel_uart;
    reg        latched_sel_gpio;
    reg        latched_sel_trap;

    //----------------------------------------------------------------------
    // APB state machine (IDLE -> SETUP -> ENABLE)
    //----------------------------------------------------------------------
    localparam [1:0] S_IDLE   = 2'd0,
                     S_SETUP  = 2'd1,
                     S_ENABLE = 2'd2;

    reg [1:0] state, state_next;

    always @(*) begin
        state_next = state;
        case (state)
            S_IDLE:   state_next = S_SETUP;
            S_SETUP:  state_next = S_ENABLE;
            S_ENABLE: if (PREADY_sel) state_next = S_IDLE;
            default:  state_next = S_IDLE;
        endcase
    end

    always @(posedge clk) begin
        if (rst)
            state <= S_IDLE;
        else
            state <= state_next;
    end

    // Latch core request when entering SETUP
    always @(posedge clk) begin
        if (rst) begin
            latched_addr   <= 32'b0;
            latched_we     <= 1'b0;
            latched_wdata  <= 32'b0;
            latched_sel    <= 4'b0;
            latched_sel_ram <= 1'b0;
            latched_sel_uart<= 1'b0;
            latched_sel_gpio<= 1'b0;
            latched_sel_trap<= 1'b0;
        end else if (state == S_IDLE && state_next == S_SETUP) begin
            latched_addr     <= core_addr;
            latched_we       <= core_we;
            latched_wdata    <= core_wdata;
            latched_sel      <= core_sel;
            latched_sel_ram  <= sel_ram;
            latched_sel_uart <= sel_uart;
            latched_sel_gpio <= sel_gpio;
            latched_sel_trap <= sel_trap;
        end
    end

    //----------------------------------------------------------------------
    // APB outputs: drive from latched or core values
    //----------------------------------------------------------------------
    wire [31:0] apb_addr   = (state == S_IDLE) ? core_addr   : latched_addr;
    wire        apb_we     = (state == S_IDLE) ? core_we     : latched_we;
    wire [31:0] apb_wdata  = (state == S_IDLE) ? core_wdata  : latched_wdata;
    wire [3:0]  apb_strb   = (state == S_IDLE) ? core_sel    : latched_sel;

    always @(posedge clk) begin
        if (rst) begin
            PADDR   <= 32'b0;
            PWDATA  <= 32'b0;
            PWRITE  <= 1'b0;
            PSTRB   <= 4'b0;
            PENABLE <= 1'b0;
        end else begin
            PADDR   <= apb_addr;
            PWDATA  <= apb_wdata;
            PWRITE  <= apb_we;
            PSTRB   <= apb_we ? apb_strb : 4'b1111;
            PENABLE <= (state == S_ENABLE);
        end
    end

    // Active slave select: use latched decode in SETUP/ENABLE so PSEL is stable
    wire active_sel_ram  = (state != S_IDLE) && latched_sel_ram;
    wire active_sel_uart = (state != S_IDLE) && latched_sel_uart;
    wire active_sel_gpio = (state != S_IDLE) && latched_sel_gpio;
    wire active_sel_trap = (state != S_IDLE) && latched_sel_trap;

    // PSEL: one-hot to slaves (only one asserted per transfer)
    assign PSEL0 = active_sel_ram;
    assign PSEL1 = active_sel_uart;
    assign PSEL2 = active_sel_gpio;
    assign PSEL3 = active_sel_trap;

    // PREADY from selected slave
    wire PREADY_sel = (active_sel_ram  & PREADY0) |
                      (active_sel_uart & PREADY1) |
                      (active_sel_gpio & PREADY2) |
                      (active_sel_trap & PREADY3);

    //----------------------------------------------------------------------
    // PRDATA multiplexer (read data from selected slave)
    //----------------------------------------------------------------------
    wire [31:0] PRDATA_mux = (active_sel_ram  ? PRDATA0 :
                              active_sel_uart ? PRDATA1 :
                              active_sel_gpio ? PRDATA2 :
                              active_sel_trap ? PRDATA3 :
                              32'b0);

    // Drive core rdata when transfer completes (PREADY in ENABLE)
    always @(posedge clk) begin
        if (rst)
            core_rdata <= 32'b0;
        else if (state == S_ENABLE && PREADY_sel)
            core_rdata <= PRDATA_mux;
    end

    assign mem_wait = (state != S_IDLE);

endmodule
