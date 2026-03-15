//==============================================================================
// MCU SoC System-Level Testbench
//==============================================================================
// - Instantiates mcu_top (RISC-V core, APB interconnect, UART, GPIO, RAM, trap).
// - Loads sw/program.hex into instruction/data RAM via $readmemh.
// - 100 MHz clock, power-on reset de-asserted after 100 ns.
// - UART loopback: uart_tx -> uart_rx for serial verification.
// - Trap: when core writes 0x01 to 0x4000_F000 -> display TEST PASSED and $finish.
// - Timeout: end simulation after TIMEOUT_NS to avoid infinite run.
//==============================================================================

`timescale 1ns / 1ps

module mcu_soc_tb;

    //----------------------------------------------------------------------
    // Parameters
    //----------------------------------------------------------------------
    parameter CLK_PERIOD   = 10;     // 100 MHz
    parameter RESET_DELAY  = 100;    // Reset de-assert after 100 ns
    parameter TIMEOUT_NS   = 500_000; // 500 us timeout (adjust as needed)
    parameter PROGRAM_HEX  = "sw/program.hex";

    //----------------------------------------------------------------------
    // Clock and reset
    //----------------------------------------------------------------------
    reg        clk;
    reg        reset_n;

    //----------------------------------------------------------------------
    // UART loopback: connect TX to RX inside TB
    //----------------------------------------------------------------------
    wire       uart_tx;
    wire       uart_rx;
    assign uart_rx = uart_tx;

    //----------------------------------------------------------------------
    // GPIO (not driven in TB)
    //----------------------------------------------------------------------
    wire [7:0] gpio_pins;

    //----------------------------------------------------------------------
    // DUT
    //----------------------------------------------------------------------
    mcu_top #(.RESET_VECTOR(32'h0000_0000)) dut (
        .clk      (clk),
        .reset_n  (reset_n),
        .uart_tx  (uart_tx),
        .uart_rx  (uart_rx),
        .gpio_pins(gpio_pins)
    );

    //----------------------------------------------------------------------
    // Load program into RAM (instruction memory) at start of simulation
    // RAM is at dut.u_ram.u_ram.mem (apb_slave_ram -> ram_16k)
    //----------------------------------------------------------------------
    initial begin
        $display("[TB] Loading program from %s into SoC RAM...", PROGRAM_HEX);
        $readmemh(PROGRAM_HEX, dut.u_ram.u_ram.mem);
        $display("[TB] Program loaded.");
    end

    //----------------------------------------------------------------------
    // 100 MHz clock
    //----------------------------------------------------------------------
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    //----------------------------------------------------------------------
    // Power-on reset: assert for RESET_DELAY, then de-assert
    //----------------------------------------------------------------------
    initial begin
        reset_n = 0;
        #RESET_DELAY;
        reset_n = 1;
        $display("[TB] Reset de-asserted at t=%0t ns", $time);
    end

    //----------------------------------------------------------------------
    // Trap: core writes 0x01 to 0x4000_F000 -> TEST PASSED
    // Monitor APB write to trap slave with data 0x01 (PREADY completes xfer)
    //----------------------------------------------------------------------
    reg test_passed;
    initial test_passed = 0;

    always @(posedge clk) begin
        if (reset_n && !test_passed &&
            dut.u_apb.PSEL3 && dut.u_apb.PENABLE && dut.u_apb.PWRITE &&
            dut.u_apb.PWDATA == 32'h01 && dut.u_apb.PREADY3) begin
            test_passed = 1;
            $display("");
            $display("========================================");
            $display("  TEST PASSED");
            $display("  (Core wrote 0x01 to 0x4000_F000)");
            $display("========================================");
            $display("");
            #(5*CLK_PERIOD);
            $finish;
        end
    end

    //----------------------------------------------------------------------
    // Timeout: prevent infinite simulation
    //----------------------------------------------------------------------
    initial begin
        #(TIMEOUT_NS);
        if (!test_passed) begin
            $display("");
            $display("========================================");
            $display("  TIMEOUT: Simulation ran %0d ns without trap write", TIMEOUT_NS);
            $display("  TEST INCOMPLETE (no pass/fail from program)");
            $display("========================================");
            $display("");
        end
        $finish;
    end

    //----------------------------------------------------------------------
    // Optional: VCD dump for waveform viewing
    //----------------------------------------------------------------------
    initial begin
        $dumpfile("mcu_soc_tb.vcd");
        $dumpvars(0, mcu_soc_tb);
    end

endmodule
