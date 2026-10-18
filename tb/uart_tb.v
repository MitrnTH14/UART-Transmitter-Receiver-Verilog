// ============================================================
// Self-checking testbench for the UART
//
//  Test 1: TX check  - DUT transmits, testbench decodes the tx line
//                      with its own reference receiver task
//  Test 2: RX check  - testbench drives a correct serial frame,
//                      DUT receiver must output the same byte
//  Test 3: Loopback  - tx wired to rx, bytes sent back-to-back
//  Test 4: Framing   - testbench sends a frame with stop bit = 0,
//                      DUT must raise frame_err (no rx_valid)
//  Test 5: Glitch    - short low pulse on rx (shorter than half a bit),
//                      DUT must ignore it
//
//  Bytes used: corner values 00, FF, 55, AA, 01, 80 + random bytes.
// ============================================================
`timescale 1ns/1ps
module uart_tb;

    localparam CLKS_PER_BIT = 16;          // small value to keep simulation fast
    localparam CLK_PERIOD   = 10;          // 100 MHz
    localparam BIT_TIME     = CLKS_PER_BIT * CLK_PERIOD;
    localparam N_RANDOM     = 50;

    reg        clk = 0, rst = 1;
    reg        tx_start = 0;
    reg  [7:0] tx_data  = 0;
    reg        loopback = 0;               // 1: rx = tx, 0: rx = rx_drive
    reg        rx_drive = 1;
    wire       tx, tx_busy, tx_done, rx_valid, frame_err;
    wire [7:0] rx_data;
    wire       rx = loopback ? tx : rx_drive;

    uart_top #(.CLKS_PER_BIT(CLKS_PER_BIT)) dut (
        .clk(clk), .rst(rst),
        .tx_start(tx_start), .tx_data(tx_data),
        .tx(tx), .tx_busy(tx_busy), .tx_done(tx_done),
        .rx(rx), .rx_data(rx_data), .rx_valid(rx_valid), .frame_err(frame_err)
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    integer errors = 0, checks = 0, i;
    reg [7:0] patterns [0:5];
    reg [7:0] got, b;

    // ---------- count DUT output pulses ----------
    integer n_valid = 0, n_ferr = 0;
    reg [7:0] last_rx;
    always @(posedge clk) begin
        if (rx_valid)  begin n_valid = n_valid + 1; last_rx = rx_data; end
        if (frame_err) n_ferr = n_ferr + 1;
    end

    task check(input [7:0] got_v, input [7:0] exp_v, input [8*12-1:0] name);
        begin
            checks = checks + 1;
            if (got_v !== exp_v) begin
                errors = errors + 1;
                $display("  FAIL %0s: got %h, expected %h", name, got_v, exp_v);
            end
        end
    endtask

    // ---------- DUT transmits one byte ----------
    task dut_send(input [7:0] d);
        begin
            @(negedge clk); while (tx_busy) @(negedge clk);
            tx_data = d; tx_start = 1;
            @(negedge clk); tx_start = 0;
        end
    endtask

    // ---------- reference receiver: decode the tx line ----------
    task tb_receive(output [7:0] d);
        integer k;
        begin
            @(negedge tx);                       // start bit begins
            #(BIT_TIME/2);                       // middle of start bit
            if (tx !== 1'b0) begin errors = errors + 1; $display("  FAIL TX: bad start bit"); end
            for (k = 0; k < 8; k = k + 1) begin
                #(BIT_TIME);
                d[k] = tx;                       // LSB first
            end
            #(BIT_TIME);
            if (tx !== 1'b1) begin errors = errors + 1; $display("  FAIL TX: bad stop bit"); end
        end
    endtask

    // ---------- reference transmitter: drive the rx line ----------
    task tb_send(input [7:0] d, input stop_bit);
        integer k;
        begin
            rx_drive = 0; #(BIT_TIME);           // start bit
            for (k = 0; k < 8; k = k + 1) begin
                rx_drive = d[k]; #(BIT_TIME);    // data, LSB first
            end
            rx_drive = stop_bit; #(BIT_TIME);    // stop bit
            rx_drive = 1; #(BIT_TIME);           // idle gap
        end
    endtask

    function [7:0] pick(input integer idx);
        pick = (idx < 6) ? patterns[idx] : $random;
    endfunction

    initial begin
        patterns[0] = 8'h00; patterns[1] = 8'hFF; patterns[2] = 8'h55;
        patterns[3] = 8'hAA; patterns[4] = 8'h01; patterns[5] = 8'h80;

        repeat (3) @(negedge clk);
        rst = 0;

        // ---------------- Test 1: TX ----------------
        $display("Test 1: DUT transmitter -> reference receiver");
        for (i = 0; i < 6 + N_RANDOM; i = i + 1) begin
            b = pick(i);
            fork
                dut_send(b);
                tb_receive(got);
            join
            check(got, b, "TX");
        end

        // ---------------- Test 2: RX ----------------
        $display("Test 2: reference transmitter -> DUT receiver");
        for (i = 0; i < 6 + N_RANDOM; i = i + 1) begin
            b = pick(i);
            n_valid = 0;
            tb_send(b, 1'b1);
            if (n_valid != 1) begin errors = errors + 1; $display("  FAIL RX: rx_valid count %0d", n_valid); end
            check(last_rx, b, "RX");
        end

        // ---------------- Test 3: loopback ----------------
        $display("Test 3: loopback, back-to-back bytes");
        loopback = 1;
        for (i = 0; i < 6 + N_RANDOM; i = i + 1) begin
            b = pick(i);
            dut_send(b);
            @(posedge rx_valid); #1;
            check(rx_data, b, "LOOPBACK");
        end
        @(negedge tx_busy);
        loopback = 0;
        repeat (2 * CLKS_PER_BIT) @(negedge clk);

        // ---------------- Test 4: framing error ----------------
        $display("Test 4: stop bit = 0 must give frame_err");
        n_valid = 0; n_ferr = 0;
        tb_send(8'hA5, 1'b0);
        checks = checks + 1;
        if (n_ferr != 1 || n_valid != 0) begin
            errors = errors + 1;
            $display("  FAIL FRAME: frame_err=%0d rx_valid=%0d", n_ferr, n_valid);
        end

        // ---------------- Test 5: glitch ----------------
        $display("Test 5: short glitch on rx must be ignored");
        n_valid = 0; n_ferr = 0;
        rx_drive = 0; #(BIT_TIME/4); rx_drive = 1;
        #(BIT_TIME * 12);
        checks = checks + 1;
        if (n_valid != 0 || n_ferr != 0) begin
            errors = errors + 1;
            $display("  FAIL GLITCH: rx_valid=%0d frame_err=%0d", n_valid, n_ferr);
        end

        $display("-------------------------------------------");
        $display("%0d checks, %0d errors", checks, errors);
        if (errors == 0) $display("ALL UART TESTS PASSED");
        else             $display("UART TESTS FAILED");
        $finish;
    end

    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);
    end

endmodule
