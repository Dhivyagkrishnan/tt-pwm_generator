/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 *
 * tt_um_pwm_generator
 *
 * An 8-channel PWM generator with configurable duty cycle and
 * configurable PWM period (resolution).
 *
 *  - ui_in[7:0]  : duty cycle setting (0-255), shared by all 8 channels
 *  - uo_out[7:0] : 8 PWM outputs, all driven with the same duty cycle
 *                  but each phase-shifted by (channel_index * 32) counts,
 *                  producing a "PWM bar graph" / running-light effect
 *                  useful for LED chaser demos as well as motor control.
 *  - uio_in[1:0] : prescaler select (clock divider, 2 bits -> 4 ranges)
 *  - uio_out[7]  : heartbeat / sync pulse, goes high once per full PWM
 *                  period, useful for synchronizing external logic
 *  - uio_out[6:0]: unused, driven low
 *  - uio_oe      : only bit 7 driven as output, rest are inputs
 */

`default_nettype none

module tt_um_pwm_generator (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 1=output)
    input  wire       ena,      // always 1 when powered, ignore
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    // ------------------------------------------------------------------
    // Pin mapping
    // ------------------------------------------------------------------
    // ui_in[7:0]   : duty cycle (0 = always off, 255 = always on)
    // uio_in[1:0]  : prescaler select
    //                00 -> divide by 1   (full speed)
    //                01 -> divide by 4
    //                10 -> divide by 16
    //                11 -> divide by 64
    // uio_in[7:2]  : unused (inputs, ignored)
    //
    // uo_out[7:0]  : 8 PWM channels, each phase-offset by 32 counts
    // uio_out[7]   : sync pulse (high for 1 cycle at start of each period)
    // uio_out[6:0] : unused, driven low
    // uio_oe       : 8'b1000_0000

    // ------------------------------------------------------------------
    // Prescaler: divides the system clock down before driving the
    // 8-bit PWM counter, allowing the user to slow the PWM frequency
    // for visible LED effects or speed it up for motor control.
    // ------------------------------------------------------------------
    reg [5:0] presc_cnt;
    wire      presc_tick;

    always @(posedge clk) begin
        if (!rst_n) begin
            presc_cnt <= 6'd0;
        end else begin
            presc_cnt <= presc_cnt + 1'b1;
        end
    end

    // Select which prescaler bit toggles the PWM counter
    reg presc_tick_r;
    always @(*) begin
        case (uio_in[1:0])
            2'b00: presc_tick_r = 1'b1;          // every cycle
            2'b01: presc_tick_r = presc_cnt[1:0] == 2'b00; // /4
            2'b10: presc_tick_r = presc_cnt[3:0] == 4'b0000; // /16
            2'b11: presc_tick_r = presc_cnt[5:0] == 6'b000000; // /64
            default: presc_tick_r = 1'b1;
        endcase
    end
    assign presc_tick = presc_tick_r;

    // ------------------------------------------------------------------
    // 8-bit free-running PWM counter
    // ------------------------------------------------------------------
    reg [7:0] pwm_cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            pwm_cnt <= 8'd0;
        end else if (presc_tick) begin
            pwm_cnt <= pwm_cnt + 1'b1;
        end
    end

    // ------------------------------------------------------------------
    // Registered duty cycle (sampled to avoid glitches mid-period)
    // ------------------------------------------------------------------
    reg [7:0] duty;

    always @(posedge clk) begin
        if (!rst_n) begin
            duty <= 8'd0;
        end else if (presc_tick && pwm_cnt == 8'hFF) begin
            // latch new duty cycle once per period, at the wrap point
            duty <= ui_in;
        end
    end

    // ------------------------------------------------------------------
    // 8 phase-shifted PWM channels
    //   channel i compares (pwm_cnt + i*32) against duty
    // ------------------------------------------------------------------
    genvar g;
    generate
        for (g = 0; g < 8; g = g + 1) begin : pwm_ch
            wire [7:0] phase_cnt = pwm_cnt + (g * 32);
            assign uo_out[g] = (phase_cnt < duty) ? 1'b1 : 1'b0;
        end
    endgenerate

    // ------------------------------------------------------------------
    // Sync pulse: high for one prescaled tick at the start of each
    // PWM period (pwm_cnt == 0)
    // ------------------------------------------------------------------
    reg sync_pulse;
    always @(posedge clk) begin
        if (!rst_n) begin
            sync_pulse <= 1'b0;
        end else begin
            sync_pulse <= presc_tick && (pwm_cnt == 8'd0);
        end
    end

    assign uio_out[7]   = sync_pulse;
    assign uio_out[6:0] = 7'b0;
    assign uio_oe       = 8'b1000_0000;

    // List unused inputs to prevent warnings
    wire _unused = &{ena, uio_in[7:2], 1'b0};

endmodule
