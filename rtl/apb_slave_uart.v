//==============================================================================
// APB Slave - UART Controller (0x4000_0000)
//==============================================================================
// Bridges APB to existing uart_mmio_wrapper. UART wrapper has registered rdata,
// so read completes one cycle after addr is presented; PREADY delayed for reads.
//==============================================================================

module apb_slave_uart (
    input  wire        PCLK,
    input  wire        PRESETn,
    input  wire        PSEL,
    input  wire        PENABLE,
    input  wire [31:0] PADDR,
    input  wire        PWRITE,
    input  wire [31:0] PWDATA,
    output reg         PREADY,
    output reg  [31:0] PRDATA,

    // Physical UART pins (to uart_mmio_wrapper)
    output wire        uart_tx,
    input  wire        uart_rx
);

    wire        rst = ~PRESETn;

    wire [3:0]  uart_addr  = read_pending ? uart_addr_r : PADDR[5:2];
    wire [31:0] uart_wdata = PWDATA;
    wire        uart_we    = PSEL && PENABLE && PWRITE;

    // UART clock enable: active when APB is accessing this slave or UART is busy
    wire        uart_active;
    wire        uart_ce = (PSEL && PENABLE) | uart_active;

    reg [3:0] uart_addr_r;
    reg       read_pending;

    always @(posedge PCLK) begin
        if (!PRESETn) begin
            PREADY      <= 1'b0;
            PRDATA      <= 32'b0;
            uart_addr_r <= 4'b0;
            read_pending<= 1'b0;
        end else begin
            PREADY <= 1'b0;
            if (PSEL && PENABLE) begin
                if (PWRITE) begin
                    PREADY <= 1'b1;
                end else begin
                    if (read_pending) begin
                        PREADY       <= 1'b1;
                        PRDATA       <= uart_rdata;
                        read_pending <= 1'b0;
                    end else begin
                        uart_addr_r  <= PADDR[5:2];
                        read_pending <= 1'b1;
                    end
                end
            end else
                read_pending <= 1'b0;
        end
    end

    wire [31:0] uart_rdata;

    uart_mmio_wrapper u_uart (
        .clk        (PCLK),
        .rst        (rst),
        .addr       (uart_addr),
        .wdata      (uart_wdata),
        .we         (uart_we),
        .rdata      (uart_rdata),
        .uart_ce    (uart_ce),
        .uart_active(uart_active),
        .uart_tx    (uart_tx),
        .uart_rx    (uart_rx)
    );

endmodule
