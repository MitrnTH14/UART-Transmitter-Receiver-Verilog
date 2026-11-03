// Code your design here
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


// ----------------------------------------------
