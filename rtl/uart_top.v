// ------------------------------------------------------------
//  TOP: TX and RX with the same baud setting
// ------------------------------------------------------------
module uart_top #(parameter CLKS_PER_BIT = 434) (
    input        clk, rst,
    input        tx_start,
    input  [7:0] tx_data,
    output       tx, tx_busy, tx_done,
    input        rx,
    output [7:0] rx_data,
    output       rx_valid, frame_err
);
    uart_tx #(CLKS_PER_BIT) u_tx (.clk(clk), .rst(rst), .tx_start(tx_start), .tx_data(tx_data),
                                  .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done));
 
    uart_rx #(CLKS_PER_BIT) u_rx (.clk(clk), .rst(rst), .rx(rx),
                                  .rx_data(rx_data), .rx_valid(rx_valid), .frame_err(frame_err));
endmodule
