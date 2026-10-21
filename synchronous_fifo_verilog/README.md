# Synchronous FIFO — Nexys A7-100T

## Contents
- `rtl/synchronous_fifo.v`: parameterized FIFO RTL
- `rtl/nexys_a7_fifo_top.v`: board-level top and button synchronizer/debouncer
- `tb/tb_synchronous_fifo.v`: self-checking RTL testbench
- `constraints/nexys_a7_100t_fifo.xdc`: Nexys A7-100T pin assignments and 100 MHz clock constraint

## Hardware controls
- `SW[7:0]`: byte to write into the FIFO
- `BTNU` (Up): write one byte; debounced and converted to a one-clock pulse
- `BTND` (Down): read one byte; debounced and converted to a one-clock pulse
- `BTNC` (Center): synchronous active-high FIFO reset
- `LED[7:0]`: most recently read byte
- `LED[8]`: FIFO full
- `LED[9]`: FIFO empty
- `LED[13:10]`: low four bits of occupancy count (0–15)
- `LED[15:14]`: unused, held low

Note: `count` ranges from 0 to 16, requiring 5 bits. Since only four count bits are mapped to LEDs, occupancy 16 is shown as `0000`; use `LED[8]` (full) to distinguish full from empty. The RTL's full/empty outputs remain correct.

## Vivado setup
1. Create an RTL project and select **Boards → Nexys A7-100T**, or part `xc7a100tcsg324-1` if selecting by part.
2. Add `rtl/synchronous_fifo.v` and `rtl/nexys_a7_fifo_top.v` as Design Sources.
3. Add `tb/tb_synchronous_fifo.v` as Simulation Sources and set `tb_synchronous_fifo` as simulation top for behavioral simulation.
4. For FPGA synthesis, set `nexys_a7_fifo_top` as the top module.
5. Add `constraints/nexys_a7_100t_fifo.xdc` under Constraints.
6. Run behavioral simulation, synthesis, implementation, then generate the bitstream.
7. Connect the board over USB, program the FPGA, and test using the controls above.

## Notes
- The XDC uses Digilent's Nexys A7-100T master pin mapping for the clock, switches, buttons, and LEDs.
- The clock constraint requests a 100 MHz clock (10 ns period); it does not guarantee timing closure.
- No LUT/FF count or maximum clock frequency is claimed here because those require actual Vivado synthesis and implementation reports.
- This is a synchronous FIFO, not an asynchronous clock-domain-crossing FIFO.
