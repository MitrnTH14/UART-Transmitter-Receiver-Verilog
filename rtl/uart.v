`timescale 1ns/1ps
// ============================================================
//  Simple UART (8N1)  -  Transmitter + Receiver + Top
//
//  Frame on the wire:  idle(1) | start(0) | D0..D7 (LSB first) | stop(1)
//  CLKS_PER_BIT = clock frequency / baud rate  (50 MHz / 115200 = 434)
// ============================================================
 
 
// ------------------------------------------------------------
//  TRANSMITTER
//  Idea: load the whole 10-bit frame {stop, data, start} into a
//  shift register and shift it out one bit every CLKS_PER_BIT clocks.
// ------------------------------------------------------------
module uart_tx #(parameter CLKS_PER_BIT = 434) (
    input        clk, rst,
    input        tx_start,          // 1-clock pulse: send tx_data
    input  [7:0] tx_data,
    output       tx,                // serial output
    output reg   tx_busy,           // 1 while sending
    output reg   tx_done            // 1-clock pulse when finished
);
    reg [9:0]  frame;               // bits still to send, frame[0] is on the wire
    reg [3:0]  bit_cnt;             // which bit of the frame (0..9)
    reg [15:0] clk_cnt;             // clocks spent on the current bit (baud counter)
 
    assign tx = frame[0];           // line idles high because frame resets to all 1s
 
    always @(posedge clk) begin
        if (rst) begin
            frame   <= 10'h3FF;
            tx_busy <= 0;
            tx_done <= 0;
            bit_cnt <= 0;
            clk_cnt <= 0;
        end else begin
            tx_done <= 0;
 
            if (!tx_busy) begin
                if (tx_start) begin                       // load the frame
                    frame   <= {1'b1, tx_data, 1'b0};     // stop, data, start
                    tx_busy <= 1;
                    bit_cnt <= 0;
                    clk_cnt <= 0;
                end
            end
            else if (clk_cnt == CLKS_PER_BIT - 1) begin   // one bit time is over
                clk_cnt <= 0;
                frame   <= {1'b1, frame[9:1]};            // shift next bit out, fill with 1
                if (bit_cnt == 9) begin                   // stop bit finished
                    tx_busy <= 0;
                    tx_done <= 1;
                end else
                    bit_cnt <= bit_cnt + 1;
            end
            else
                clk_cnt <= clk_cnt + 1;
        end
    end
endmodule
 
 
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
 
