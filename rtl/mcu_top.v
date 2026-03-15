//==============================================================================
// MCU Top-Level - RISC-V Core + APB Interconnect + RAM + UART + GPIO
//==============================================================================
// Physical Design: All I/O ports are commented for Pin Assignment / PAD mapping.
// Reset: reset_n is active-low; internal rst is active-high.
//==============================================================================

module mcu_top #(
    parameter RESET_VECTOR = 32'h0000_0000
)(
    //----------------------------------------------------------------------
    // Clock and Reset
    // Pin Assignment: clk = primary clock pad; reset_n = reset/por pad
    //----------------------------------------------------------------------
    input  wire        clk,       // System clock
    input  wire        reset_n,   // Active-low reset

    //----------------------------------------------------------------------
    // UART
    // Pin Assignment: uart_tx = TX pad; uart_rx = RX pad
    //----------------------------------------------------------------------
    output wire        uart_tx,
    input  wire        uart_rx,

    //----------------------------------------------------------------------
    // GPIO (8-bit)
    // Pin Assignment: gpio_pins[7:0] = GPIO pads 0..7
    //----------------------------------------------------------------------
    output wire [7:0]  gpio_pins
);

    //----------------------------------------------------------------------
    // Reset: active-high for core and interconnect
    //----------------------------------------------------------------------
    wire rst = ~reset_n;

    //----------------------------------------------------------------------
    // RISC-V Core <-> APB Interconnect (memory interface)
    //----------------------------------------------------------------------
    wire [31:0] core_addr;
    wire [31:0] core_wdata;
    wire        core_we;
    wire [3:0]  core_sel;
    wire [31:0] core_rdata;
    wire        mem_wait;

    riscv_core #(.RESET_VECTOR(RESET_VECTOR)) u_core (
        .clk      (clk),
        .rst      (rst),
        .ext_stall(mem_wait),
        .addr     (core_addr),
        .wdata    (core_wdata),
        .rdata    (core_rdata),
        .we       (core_we),
        .sel      (core_sel)
    );

    //----------------------------------------------------------------------
    // APB Interconnect (master side from core, slave side to RAM/UART/GPIO)
    //----------------------------------------------------------------------
    wire [31:0] PADDR;
    wire [31:0] PWDATA;
    wire        PWRITE;
    wire [3:0]  PSTRB;
    wire        PENABLE;
    wire        PSEL0, PSEL1, PSEL2, PSEL3;
    wire        PREADY0, PREADY1, PREADY2, PREADY3;
    wire [31:0] PRDATA0, PRDATA1, PRDATA2, PRDATA3;

    apb_interconnect u_apb (
        .clk       (clk),
        .rst       (rst),
        .core_addr (core_addr),
        .core_wdata(core_wdata),
        .core_we   (core_we),
        .core_sel  (core_sel),
        .core_rdata(core_rdata),
        .mem_wait  (mem_wait),
        .PADDR     (PADDR),
        .PWDATA    (PWDATA),
        .PWRITE    (PWRITE),
        .PSTRB     (PSTRB),
        .PENABLE   (PENABLE),
        .PSEL0     (PSEL0),
        .PREADY0   (PREADY0),
        .PRDATA0   (PRDATA0),
        .PSEL1     (PSEL1),
        .PREADY1   (PREADY1),
        .PRDATA1   (PRDATA1),
        .PSEL2     (PSEL2),
        .PREADY2   (PREADY2),
        .PRDATA2   (PRDATA2),
        .PSEL3     (PSEL3),
        .PREADY3   (PREADY3),
        .PRDATA3   (PRDATA3)
    );

    //----------------------------------------------------------------------
    // Slave 0: 16 KB RAM (0x0000_0000 - 0x0000_3FFF)
    //----------------------------------------------------------------------
    apb_slave_ram u_ram (
        .PCLK    (clk),
        .PRESETn (reset_n),
        .PSEL    (PSEL0),
        .PENABLE (PENABLE),
        .PADDR   (PADDR),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),
        .PSTRB   (PSTRB),
        .PREADY  (PREADY0),
        .PRDATA  (PRDATA0)
    );

    //----------------------------------------------------------------------
    // Slave 1: UART Controller (0x4000_0000) - placeholder for your UART
    //----------------------------------------------------------------------
    apb_slave_uart u_uart (
        .PCLK    (clk),
        .PRESETn (reset_n),
        .PSEL    (PSEL1),
        .PENABLE (PENABLE),
        .PADDR   (PADDR),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),
        .PREADY  (PREADY1),
        .PRDATA  (PRDATA1),
        .uart_tx (uart_tx),
        .uart_rx (uart_rx)
    );

    //----------------------------------------------------------------------
    // Slave 2: GPIO Controller (0x4000_1000) - 8 bits
    //----------------------------------------------------------------------
    apb_slave_gpio u_gpio (
        .PCLK    (clk),
        .PRESETn (reset_n),
        .PSEL    (PSEL2),
        .PENABLE (PENABLE),
        .PADDR   (PADDR),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),
        .PREADY  (PREADY2),
        .PRDATA  (PRDATA2),
        .gpio_out(gpio_pins)
    );

    //----------------------------------------------------------------------
    // Slave 3: Trap / test exit (0x4000_F000) - write 0x01 to signal pass
    //----------------------------------------------------------------------
    apb_slave_trap u_trap (
        .PCLK    (clk),
        .PRESETn (reset_n),
        .PSEL    (PSEL3),
        .PENABLE (PENABLE),
        .PADDR   (PADDR),
        .PWRITE  (PWRITE),
        .PWDATA  (PWDATA),
        .PREADY  (PREADY3),
        .PRDATA  (PRDATA3)
    );

endmodule
