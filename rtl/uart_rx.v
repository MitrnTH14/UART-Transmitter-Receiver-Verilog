// ------------------------------------------------------------
//  RECEIVER
//  1. 2-flip-flop synchronizer on rx (rx is asynchronous to clk)
//  2. On a falling edge, wait HALF a bit -> middle of start bit
//       still 0 ? real start bit : glitch, go back to idle
//  3. Then wait a FULL bit each time -> sample middle of D0..D7, stop
//  4. Stop bit 1 -> rx_valid,  stop bit 0 -> frame_err
//
//  bit_cnt: 0 = start bit, 1..8 = data bits, 9 = stop bit
// ------------------------------------------------------------
module uart_rx #(parameter CLKS_PER_BIT = 434) (
    input            clk, rst,
    input            rx,
    output reg [7:0] rx_data,
    output reg       rx_valid,      // 1-clock pulse: good byte
    output reg       frame_err      // 1-clock pulse: bad stop bit
);
    // ---- 2-FF synchronizer ----
    reg rx_meta, rx_sync;
    always @(posedge clk) begin
        if (rst) {rx_meta, rx_sync} <= 2'b11;
        else     {rx_meta, rx_sync} <= {rx, rx_meta};
    end

    reg        busy;
    reg [3:0]  bit_cnt;
    reg [15:0] clk_cnt;
    reg [7:0]  shift;

    // half a bit for the start bit, a full bit for everything after it
    wire [15:0] wait_clks = (bit_cnt == 0) ? (CLKS_PER_BIT - 1) / 2 : CLKS_PER_BIT - 1;

    always @(posedge clk) begin
        if (rst) begin
            busy <= 0; bit_cnt <= 0; clk_cnt <= 0; shift <= 0;
            rx_data <= 0; rx_valid <= 0; frame_err <= 0;
        end else begin
            rx_valid  <= 0;
            frame_err <= 0;

            if (!busy) begin
                bit_cnt <= 0;
                clk_cnt <= 0;
                if (rx_sync == 0) busy <= 1;              // falling edge: maybe a start bit
            end
            else if (clk_cnt == wait_clks) begin          // we are in the middle of a bit
                clk_cnt <= 0;
                bit_cnt <= bit_cnt + 1;

                if (bit_cnt == 0) begin                   // start bit check
                    if (rx_sync == 1) busy <= 0;          // went back high: glitch, ignore
                end
                else if (bit_cnt <= 8)                    // data bits, LSB first
                    shift <= {rx_sync, shift[7:1]};
                else begin                                // stop bit
                    busy <= 0;
                    if (rx_sync == 1) begin rx_data <= shift; rx_valid <= 1; end
                    else              frame_err <= 1;
                end
            end
            else
                clk_cnt <= clk_cnt + 1;
        end
    end
endmodule
