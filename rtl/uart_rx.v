module uart_rx #(
    parameter CLKS_PER_BIT = 434
)(
    input            clk,
    input            rst,
    input            rx,
    output reg [7:0] rx_data,
    output reg       rx_valid,
    output reg       frame_err
);

    localparam IDLE  = 2'd0,
               START = 2'd1,
               DATA  = 2'd2,
               STOP  = 2'd3;

    reg rx_meta;
    reg rx_sync;

    always @(posedge clk) begin
        if (rst) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    reg [1:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  shift_reg;

    always @(posedge clk) begin
        if (rst) begin
            state     <= IDLE;
            clk_count <= 0;
            bit_index <= 0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_valid  <= 1'b0;
            frame_err <= 1'b0;
        end else begin
            rx_valid  <= 1'b0;
            frame_err <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_sync == 1'b0)
                        state <= START;
                end

                START: begin
                    if (clk_count == (CLKS_PER_BIT - 1) / 2) begin
                        clk_count <= 0;
                        if (rx_sync == 1'b0)
                            state <= DATA;
                        else
                            state <= IDLE;
                    end else
                        clk_count <= clk_count + 1;
                end

                DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count            <= 0;
                        shift_reg[bit_index] <= rx_sync;
                        if (bit_index == 7) begin
                            bit_index <= 0;
                            state     <= STOP;
                        end else
                            bit_index <= bit_index + 1;
                    end else
                        clk_count <= clk_count + 1;
                end

                STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= 0;
                        state     <= IDLE;
                        if (rx_sync == 1'b1) begin
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end else
                            frame_err <= 1'b1;
                    end else
                        clk_count <= clk_count + 1;
                end
            endcase
        end
    end
endmodule
