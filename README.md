# UART Transmitter and Receiver in Verilog

A UART (Universal Asynchronous Receiver/Transmitter) in Verilog, with a self-checking testbench. It uses the standard **8N1** format: 1 start bit, 8 data bits (LSB first), no parity, and 1 stop bit. The baud rate is set with one parameter.

## UART frame

```
 idle  start  D0  D1  D2  D3  D4  D5  D6  D7  stop  idle
 ‾‾‾‾‾\_____/‾‾‾\___/‾‾‾\___/ ... ________/‾‾‾‾‾‾‾‾‾‾‾‾
   1     0    <------- 8 data bits, LSB first ------>   1
```

* The line idles at **1**.
* A **start bit (0)** tells the receiver a byte is coming.
* The **stop bit (1)** marks the end of the frame.
* Each bit lasts `CLKS_PER_BIT` clock cycles:
  `CLKS_PER_BIT = clock frequency / baud rate`. For example, 50 MHz / 115200 baud = **434**.

## Design

| File | Description |
| :--- | :--- |
| `rtl/uart_tx.v` | Transmitter: FSM + bit counter + clock counter |
| `rtl/uart_rx.v` | Receiver: 2-FF synchronizer + FSM, samples each bit at its centre |
| `rtl/uart_top.v` | Transmitter and receiver together, with one shared baud parameter |

### Transmitter FSM
```
IDLE --tx_start--> START --1 bit--> DATA (x8 bits) --> STOP --1 bit--> IDLE
```
* **IDLE:** the line is held at 1. On `tx_start`, the byte is latched.
* **START:** sends 0 for one bit time.
* **DATA:** sends the 8 bits, LSB first, each for one bit time.
* **STOP:** sends 1 for one bit time, pulses `tx_done`, and returns to IDLE.

`tx_busy` is high while a frame is in progress.

### Receiver FSM
```
IDLE --rx falls--> START --half bit--> DATA (x8, every full bit) --> STOP --> IDLE
```
* **Synchronizer:** `rx` comes from outside the chip and is asynchronous, so it passes through **2 flip-flops** first. This avoids metastability.
* **Centre sampling:** after the falling edge, the receiver waits **half a bit** to reach the middle of the start bit. If the line is back at 1 by then, it was only a glitch and the receiver returns to IDLE. After that, it waits one full bit between samples, so every bit is read at its **centre**, where it is most stable.
* **Stop-bit check:** if the stop bit is 1, the byte appears on `rx_data` with a 1-clock `rx_valid` pulse. If the stop bit is 0, the receiver pulses `frame_err` instead.

### Ports (`uart_top`)

| Port | Dir | Description |
| :--- | :--- | :--- |
| `clk`, `rst` | in | Clock, synchronous active-high reset |
| `tx_start`, `tx_data[7:0]` | in | Pulse `tx_start` for 1 clock to send `tx_data` |
| `tx`, `tx_busy`, `tx_done` | out | Serial output, busy flag, done pulse |
| `rx` | in | Serial input |
| `rx_data[7:0]`, `rx_valid`, `frame_err` | out | Received byte, valid pulse, framing-error pulse |

## Verification (`tb/uart_tb.v`)

The testbench is self-checking: it compares results itself and prints PASS or FAIL. It has its own **reference transmitter and receiver tasks**, so the transmitter and the receiver are each tested on their own, not just against each other.

| Test | What it checks |
| :--- | :--- |
| 1. TX | DUT transmits; the testbench decodes the `tx` line and checks every byte, the start bit and the stop bit |
| 2. RX | The testbench drives correct frames; the DUT must output the same byte with exactly one `rx_valid` |
| 3. Loopback | `tx` wired to `rx`, bytes sent back-to-back |
| 4. Framing error | A frame with stop bit = 0 must give `frame_err` and no `rx_valid` |
| 5. Glitch | A low pulse shorter than half a bit must be ignored |

Each of tests 1–3 sends the corner values `00, FF, 55, AA, 01, 80` plus 50 random bytes.

### Result
```
Test 1: DUT transmitter -> reference receiver
Test 2: reference transmitter -> DUT receiver
Test 3: loopback, back-to-back bytes
Test 4: stop bit = 0 must give frame_err
Test 5: short glitch on rx must be ignored
-------------------------------------------
170 checks, 0 errors
ALL UART TESTS PASSED
```

The testbench was also checked by deliberately breaking the design. Each of these bugs was caught:
* sending MSB first;
* ignoring the stop bit;
* sampling at the bit edge instead of the centre.

## How to run

On [EDA Playground](https://www.edaplayground.com):

1. In the **Design** pane, add `rtl/uart_tx.v`, `rtl/uart_rx.v` and `rtl/uart_top.v` (use the **+** button for extra files).
2. Paste `tb/uart_tb.v` into the **Testbench** pane.
3. Pick a Verilog simulator and set the top module to `uart_tb`.
4. Tick **Open EPWave after run** to see the waveform, then click **Run**.

The testbench uses `CLKS_PER_BIT = 16` to keep simulation fast; the design default is 434.

## Possible extensions
* Parity bit (even/odd) and configurable data bits
* TX and RX FIFOs so the user can queue several bytes
* Oversampling (16× per bit) with majority voting for noisy lines
* Run on an FPGA board and talk to a PC serial terminal
