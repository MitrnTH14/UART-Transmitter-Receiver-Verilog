// ============================================================
// UART Transmitter (8N1: 1 start bit, 8 data bits LSB first, 1 stop bit)
//  - CLKS_PER_BIT = clock frequency / baud rate
//    e.g. 50 MHz / 115200 baud = 434
//  - Pulse tx_start for one clock with tx_data to send a byte.
//  - tx_busy is high while a frame is being sent.
// ============================================================
module uart_tx #(
    parameter CLKS_PER_BIT = 434
)(
    input            clk,
    input            rst,        // synchronous, active high
    input            tx_start,
    input      [7:0] tx_data,
    output reg       tx,         // serial line (idle = 1)
    output           tx_busy,
    output reg       tx_done     // 1-clock pulse after the stop bit
);

    localparam IDLE  = 2'd0,
               START = 2'd1,
               DATA  = 2'd2,
               STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_count;   // counts clocks inside one bit
    reg [2:0]  bit_index;   // which data bit is being sent (0..7)
    reg [7:0]  data_reg;    // copy of the byte being sent

    assign tx_busy = (state != IDLE);

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            tx        <= 1'b1;
            clk_count <= 0;
            bit_index <= 0;
            data_reg  <= 8'd0;
            tx_done   <= 1'b0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                IDLE: begin
                    tx        <= 1'b1;            // line idles high
                    clk_count <= 0;
                    bit_index <= 0;
                    if (tx_start) begin
                        data_reg <= tx_data;      // latch the byte
                        state    <= START;
                    end
                end

                START: begin                       // send start bit (0)
                    tx <= 1'b0;
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        state     <= DATA;
                    end else
                        clk_count <= clk_count + 1;
                end

                DATA: begin                        // send 8 bits, LSB first
                    tx <= data_reg[bit_index];
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        if (bit_index == 7) begin
                            bit_index <= 0;
                            state     <= STOP;
                        end else
                            bit_index <= bit_index + 1;
                    end else
                        clk_count <= clk_count + 1;
                end

                STOP: begin                        // send stop bit (1)
                    tx <= 1'b1;
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        tx_done   <= 1'b1;
                        state     <= IDLE;
                    end else
                        clk_count <= clk_count + 1;
                end
            endcase
        end
    end

endmodule
