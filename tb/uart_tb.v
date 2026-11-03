// ============================================================
//  Simple self-checking testbench for the UART
//
//  Test 1: TX       - DUT sends, testbench reads the tx line
//  Test 2: RX       - testbench drives rx, DUT must output the byte
//  Test 3: Loopback - tx wired to rx
//  Test 4: Framing  - stop bit = 0 must give frame_err
//  Test 5: Glitch   - short low pulse on rx must be ignored
//
//  Bytes: 00, FF, 55, AA, 01, 80, then random bytes
// ============================================================
`timescale 1ns/1ps
module uart_tb;

    localparam CPB      = 16;            // clocks per bit (small = fast sim)
    localparam BIT      = CPB * 10;      // one bit time in ns (10 ns clock)
    localparam N_BYTES  = 26;            // 6 corner + 20 random

    reg        clk = 0, rst = 1;
    reg        tx_start = 0;
    reg  [7:0] tx_data  = 0;
    reg        loopback = 0;
    reg        rx_drive = 1;
    wire       tx, tx_busy, tx_done, rx_valid, frame_err;
    wire [7:0] rx_data;
    wire       rx = loopback ? tx : rx_drive;

    uart_top #(CPB) dut (.clk(clk), .rst(rst), .tx_start(tx_start), .tx_data(tx_data),
                         .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done),
                         .rx(rx), .rx_data(rx_data), .rx_valid(rx_valid), .frame_err(frame_err));

    always #5 clk = ~clk;                // 100 MHz

    integer   errors = 0, i;
    reg [7:0] b, got;

    // ---- count DUT output pulses ----
    integer n_valid = 0, n_ferr = 0;
    always @(posedge clk) begin
        if (rx_valid)  n_valid = n_valid + 1;
        if (frame_err) n_ferr  = n_ferr  + 1;
    end

    // ---- test byte k: corner values first, then random ----
    function [7:0] test_byte(input integer k);
        case (k)
            0: test_byte = 8'h00;   1: test_byte = 8'hFF;
            2: test_byte = 8'h55;   3: test_byte = 8'hAA;
            4: test_byte = 8'h01;   5: test_byte = 8'h80;
            default: test_byte = $random;
        endcase
    endfunction

    // ---- compare and report ----
    task check(input [7:0] got_v, input [7:0] exp_v);
        if (got_v !== exp_v) begin
            errors = errors + 1;
            $display("  FAIL: got %h, expected %h", got_v, exp_v);
        end
    endtask

    // ---- ask the DUT to transmit one byte ----
    task dut_send(input [7:0] d);
        begin
            @(negedge clk); while (tx_busy) @(negedge clk);
            tx_data = d; tx_start = 1;
            @(negedge clk); tx_start = 0;
        end
    endtask

    // ---- read one byte from the tx line (reference receiver) ----
    task read_tx(output [7:0] d);
        begin
            @(negedge tx);                       // start bit
            #(BIT/2);                            // middle of start bit
            repeat (8) begin
                #(BIT);
                d = {tx, d[7:1]};                // LSB first
            end
            #(BIT);
            if (tx !== 1) begin errors = errors + 1; $display("  FAIL: bad stop bit on tx"); end
        end
    endtask

    // ---- drive one frame onto rx (reference transmitter) ----
    task drive_rx(input [7:0] d, input stop_bit);
        reg [9:0] frame;
        integer k;
        begin
            frame = {stop_bit, d, 1'b0};         // stop, data, start
            for (k = 0; k < 10; k = k + 1) begin
                rx_drive = frame[k]; #(BIT);
            end
            rx_drive = 1; #(BIT);                // idle gap
        end
    endtask

    initial begin
        repeat (3) @(negedge clk);
        rst = 0;

        // ---------- Test 1: TX ----------
        $display("Test 1: TX");
        for (i = 0; i < N_BYTES; i = i + 1) begin
            b = test_byte(i);
            fork
                dut_send(b);
                read_tx(got);
            join
            check(got, b);
        end

        // ---------- Test 2: RX ----------
        $display("Test 2: RX");
        for (i = 0; i < N_BYTES; i = i + 1) begin
            b = test_byte(i);
            n_valid = 0;
            drive_rx(b, 1);
            if (n_valid != 1) begin errors = errors + 1; $display("  FAIL: no rx_valid"); end
            check(rx_data, b);
        end

        // ---------- Test 3: Loopback ----------
        $display("Test 3: Loopback");
        loopback = 1;
        for (i = 0; i < N_BYTES; i = i + 1) begin
            b = test_byte(i);
            dut_send(b);
            @(posedge rx_valid); #1;
            check(rx_data, b);
        end
        wait (!tx_busy);
        loopback = 0;
        #(2 * BIT);

        // ---------- Test 4: Framing error ----------
        $display("Test 4: Framing error");
        n_valid = 0; n_ferr = 0;
        drive_rx(8'hA5, 0);
        if (n_ferr != 1 || n_valid != 0) begin
            errors = errors + 1;
            $display("  FAIL: frame_err=%0d rx_valid=%0d", n_ferr, n_valid);
        end

        // ---------- Test 5: Glitch ----------
        $display("Test 5: Glitch");
        n_valid = 0; n_ferr = 0;
        rx_drive = 0; #(BIT/4); rx_drive = 1;    // pulse shorter than half a bit
        #(12 * BIT);
        if (n_valid != 0 || n_ferr != 0) begin
            errors = errors + 1;
            $display("  FAIL: glitch was not ignored");
        end

        // ---------- Result ----------
        if (errors == 0) $display("ALL UART TESTS PASSED");
        else             $display("UART TESTS FAILED: %0d errors", errors);
        $finish;
    end

    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);
    end

endmodule
