SRC = rtl/uart_tx.v rtl/uart_rx.v rtl/uart_top.v tb/uart_tb.v

.PHONY: sim wave clean

sim:
	iverilog -g2005 -o uart_sim $(SRC)
	vvp -n uart_sim

wave: sim
	gtkwave uart_tb.vcd

clean:
	rm -f uart_sim uart_tb.vcd
