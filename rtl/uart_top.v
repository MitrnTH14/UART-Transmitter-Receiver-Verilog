// ============================================================
// UART top: transmitter + receiver with a common baud setting.
// Connect tx to another device's rx (and rx to its tx).
// For a loopback test, connect tx directly to rx.
// ============================================================
module uart_top #(
    parameter CLKS_PER_BIT = 434      // 50 MHz / 115200 baud
)(
    input        clk,
    input        rst,
    // transmit side
    input        tx_start,
    input  [7:0] tx_data,
    output       tx,
    output       tx_busy,
    output       tx_done,
    // receive side
    input        rx,
    output [7:0] rx_data,
    output       rx_valid,
    output       frame_err
);

    uart_tx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_tx (
        .clk(clk), .rst(rst),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done)
    );

    uart_rx #(.CLKS_PER_BIT(CLKS_PER_BIT)) u_rx (
        .clk(clk), .rst(rst),
        .rx(rx),
        .rx_data(rx_data), .rx_valid(rx_valid), .frame_err(frame_err)
    );

endmodule
