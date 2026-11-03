# UART Transmitter and Receiver (Verilog HDL)

A UART transmitter and receiver in Verilog for the standard **8N1** frame: 8 data bits, no parity, 1 stop bit. A self-checking testbench verifies it with 5 directed tests.

**Result:** all tests pass on Cadence Xcelium (EDA Playground).

---

## UART frame (8N1)

```
 idle | start | D0  D1  D2  D3  D4  D5  D6  D7 | stop | idle
  1   |   0   | <---- 8 data bits, LSB first -> |  1   |  1
```

- The line stays **high** when idle.
- The **start bit (0)** tells the receiver a byte is coming.
- Data is sent **LSB first**.
- The **stop bit (1)** ends the frame, so one byte takes 10 bit-times.

**Baud rate:** each bit is held for `CLKS_PER_BIT` clock cycles.

```
CLKS_PER_BIT = clock frequency / baud rate = 50 MHz / 115200 = 434
```

---

## Design (`uart.v`)

### Transmitter: `uart_tx`
- On `tx_start`, it loads the full 10-bit frame `{stop, data, start}` into a shift register.
- A baud counter (`clk_cnt`) shifts out one bit every `CLKS_PER_BIT` clocks, and `tx` is always `frame[0]`.
- The frame resets to all 1s, so the line idles high on its own.
- `tx_busy` is high while sending. `tx_done` pulses for 1 clock at the end of the stop bit.

### Receiver: `uart_rx`
- **2-flip-flop synchronizer:** `rx` comes from another device and is asynchronous to `clk`, so it passes through two flip-flops to avoid metastability.
- **Mid-bit sampling:** on a falling edge, it waits **half a bit** to reach the middle of the start bit. After that it waits a **full bit** each time, so every sample lands in the middle of a bit.
- **Glitch rejection:** if the line is back high at the middle of the start bit, it was noise, and the receiver returns to idle.
- **Framing error:** if the stop bit is 0, it raises `frame_err` and drops the byte. If the stop bit is 1, it outputs `rx_data` with a 1-clock `rx_valid` pulse.
- `bit_cnt` tracks the position in the frame: 0 = start, 1–8 = data, 9 = stop.

### Top: `uart_top`
Connects the TX and RX with the same `CLKS_PER_BIT`, so both always run at the same baud rate.

| Port | Dir | Description |
|------|-----|-------------|
| `clk`, `rst` | in | Clock, synchronous active-high reset |
| `tx_start` | in | 1-clock pulse to send `tx_data` |
| `tx_data[7:0]` | in | Byte to transmit |
| `tx` | out | Serial output |
| `tx_busy` / `tx_done` | out | Sending / finished (1-clock pulse) |
| `rx` | in | Serial input |
| `rx_data[7:0]` | out | Received byte |
| `rx_valid` | out | 1-clock pulse: good byte received |
| `frame_err` | out | 1-clock pulse: stop bit was 0 |

---

## Verification (`uart_tb.v`)

The testbench is self-checking: it compares every result automatically and prints `PASS` or `FAIL`. It has its own reference transmitter and receiver tasks, so it does not trust the DUT to check itself.

| # | Test | What it checks |
|---|------|----------------|
| 1 | TX | DUT transmits, testbench decodes the `tx` line and compares the byte and stop bit |
| 2 | RX | Testbench drives a correct frame on `rx`, DUT must output the same byte with exactly one `rx_valid` |
| 3 | Loopback | `tx` wired to `rx`, bytes sent back-to-back |
| 4 | Framing error | Frame sent with stop bit = 0, DUT must raise `frame_err` and no `rx_valid` |
| 5 | Glitch | Low pulse shorter than half a bit on `rx`, DUT must ignore it |

**Test bytes:** corner values `00`, `FF`, `55`, `AA`, `01`, `80`, then random bytes (26 per test). `CLKS_PER_BIT = 16` in the testbench to keep simulation fast.

### Simulation output

```
Test 1: TX
Test 2: RX
Test 3: Loopback
Test 4: Framing error
Test 5: Glitch
ALL UART TESTS PASSED
Simulation complete via $finish(1) at time 133475 NS + 0
```

### Waveform

<img width="1568" height="470" alt="image" src="https://github.com/user-attachments/assets/59f8d169-5e3f-4b76-93ca-c4e578f750a8" />


- **0 – ~44 µs (Test 1):** `tx` carries each byte, and `got` matches `tx_data` every time (`errors` stays 0).
- **~44 – ~90 µs (Test 2):** the testbench drives `rx`, and `rx_data` follows the same bytes with one `rx_valid` pulse per frame.
- **~90 µs onwards (Test 3):** `loopback` goes high and `tx` feeds straight back into `rx`.

---

## How to run

1. Open [EDA Playground](https://www.edaplayground.com/).
2. Paste `uart.v` into the **Design** pane and `uart_tb.v` into the **Testbench** pane.
3. Select **Cadence Xcelium** as the simulator and tick **Open EPWave after run**.
4. Click **Run**. The log should end with `ALL UART TESTS PASSED`.

---

## Files

```
uart.v            UART transmitter, receiver and top module
uart_tb.v         Self-checking testbench (5 tests)
docs/waveform.png Simulation waveform (EPWave)
```

## Author

**R S Muthu Mitrn**, ECE, Easwari Engineering College, Chennai
