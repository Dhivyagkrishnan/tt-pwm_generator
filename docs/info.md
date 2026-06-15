<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->
## How it works

An 8-bit free-running counter defines the PWM period (256 ticks). Each channel compares this counter (offset by channel×32) against the latched duty cycle from ui_in[7:0], creating staggered outputs. A 2-bit prescaler (uio_in[1:0]) divides the clock by 1/4/16/64, and uio_out[7] outputs a sync pulse once per period.

## How to test

Drive ui_in[7:0] with duty cycle (0–255), set uio_in[1:0] for desired speed, and observe uo_out[7:0] on LEDs or oscilloscope — channels will turn on/off sequentially. Change duty cycle mid-run to see glitch-free updates at period boundaries.

## External hardware

Optional: 8 LEDs with current-limiting resistors on uo_out[7:0] for visual bar-graph effect, or an oscilloscope/logic analyzer to verify PWM waveforms and sync pulse on uio_out[7].
