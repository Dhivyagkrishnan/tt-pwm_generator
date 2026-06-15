/*
 * Copyright (c) 2026 Your Name
 * SPDX-License-Identifier: Apache-2.0
 *
 * tb_pwm_generator
 *
 * Self-checking Verilog testbench for tt_um_pwm_generator, written for
 * use with Vivado's XSIM (or any Verilog-2001 simulator).
 *
 * Run in Vivado:
 *   1. Add src/pwm_generator.v and sim/tb_pwm_generator.v to a simulation
 *      source set.
 *   2. Set tb_pwm_generator as the simulation top module.
 *   3. Run Behavioral Simulation. The testbench will $finish automatically
 *      and print PASS/FAIL messages to the Tcl console.
 */

`timescale 1ns / 1ps

module tb_pwm_generator;

    // DUT ports
    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

    integer errors;

    // ------------------------------------------------------------------
    // DUT instantiation
    // ------------------------------------------------------------------
    tt_um_pwm_generator dut (
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

    // ------------------------------------------------------------------
    // Clock generation: 100 MHz (10 ns period)
    // ------------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------------
    // Reusable reset task
    // ------------------------------------------------------------------
    task do_reset;
        begin
            ena    = 1'b1;
            ui_in  = 8'd0;
            uio_in = 8'd0;
            rst_n  = 1'b0;
            repeat (10) @(posedge clk);
            rst_n  = 1'b1;
            repeat (5) @(posedge clk);
        end
    endtask

    // ------------------------------------------------------------------
    // Helper: count how many of the next N clock edges have uo_out[bit]==1
    // ------------------------------------------------------------------
    task count_high_cycles(input integer bit_idx, input integer n,
                            output integer count);
        integer i;
        begin
            count = 0;
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
                if (uo_out[bit_idx] == 1'b1) count = count + 1;
            end
        end
    endtask

    // ------------------------------------------------------------------
    // Helper: count sync pulses (uio_out[7]) over N clock edges
    // ------------------------------------------------------------------
    task count_sync_pulses(input integer n, output integer count);
        integer i;
        begin
            count = 0;
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
                if (uio_out[7] == 1'b1) count = count + 1;
            end
        end
    endtask

    integer on_count;
    integer pulses;
    integer i;
    reg [7:0] prev_uo, distinct_count;
    reg [7:0] seen [0:255];

    initial begin
        errors = 0;

        // ================================================================
        // Test 1: duty = 0 -> all channels stay low
        // ================================================================
        do_reset;
        ui_in  = 8'd0;
        uio_in = 8'b00; // prescaler = /1

        repeat (260) @(posedge clk);

        if (uo_out !== 8'h00) begin
            $display("FAIL: Test1 duty=0 expected uo_out=0x00, got 0x%02h", uo_out);
            errors = errors + 1;
        end else begin
            $display("PASS: Test1 duty=0 -> uo_out=0x00");
        end

        // ================================================================
        // Test 2: duty = 255 -> channel 0 high almost always (>=250/256)
        // ================================================================
        do_reset;
        ui_in  = 8'd255;
        uio_in = 8'b00;

        repeat (270) @(posedge clk); // let duty latch
        count_high_cycles(0, 256, on_count);

        if (on_count < 250) begin
            $display("FAIL: Test2 duty=255 expected ch0 on_count>=250, got %0d", on_count);
            errors = errors + 1;
        end else begin
            $display("PASS: Test2 duty=255 -> ch0 on_count=%0d/256", on_count);
        end

        // ================================================================
        // Test 3: duty = 128 -> channel 0 high ~50% (120-136/256)
        // ================================================================
        do_reset;
        ui_in  = 8'd128;
        uio_in = 8'b00;

        repeat (270) @(posedge clk);
        count_high_cycles(0, 256, on_count);

        if (on_count < 120 || on_count > 136) begin
            $display("FAIL: Test3 duty=128 expected ch0 on_count in [120,136], got %0d", on_count);
            errors = errors + 1;
        end else begin
            $display("PASS: Test3 duty=128 -> ch0 on_count=%0d/256", on_count);
        end

        // ================================================================
        // Test 4: sync pulse fires exactly twice in ~2 periods, uio_oe check
        // ================================================================
        do_reset;
        ui_in  = 8'd64;
        uio_in = 8'b00;

        if (uio_oe !== 8'b1000_0000) begin
            $display("FAIL: Test4 expected uio_oe=0x80, got 0x%02h", uio_oe);
            errors = errors + 1;
        end else begin
            $display("PASS: Test4 uio_oe=0x80");
        end

        count_sync_pulses(520, pulses);
        if (pulses !== 2) begin
            $display("FAIL: Test4 expected 2 sync pulses in 520 cycles, got %0d", pulses);
            errors = errors + 1;
        end else begin
            $display("PASS: Test4 sync pulses=%0d in ~2 periods", pulses);
        end

        // ================================================================
        // Test 5: phase-shifted channels -> multiple distinct uo_out values
        // ================================================================
        do_reset;
        ui_in  = 8'd32;
        uio_in = 8'b00;

        repeat (270) @(posedge clk); // let duty latch

        distinct_count = 0;
        for (i = 0; i < 256; i = i + 1) begin
            @(posedge clk);
            // linear-search insert into 'seen' set
            begin : check_seen
                integer j;
                reg found;
                found = 1'b0;
                for (j = 0; j < distinct_count; j = j + 1) begin
                    if (seen[j] == uo_out) found = 1'b1;
                end
                if (!found) begin
                    seen[distinct_count] = uo_out;
                    distinct_count = distinct_count + 1;
                end
            end
        end

        if (distinct_count <= 2) begin
            $display("FAIL: Test5 expected >2 distinct uo_out patterns, got %0d", distinct_count);
            errors = errors + 1;
        end else begin
            $display("PASS: Test5 distinct uo_out patterns=%0d", distinct_count);
        end

        // ================================================================
        // Summary
        // ================================================================
        if (errors == 0) begin
            $display("=====================================");
            $display("ALL TESTS PASSED");
            $display("=====================================");
        end else begin
            $display("=====================================");
            $display("%0d TEST(S) FAILED", errors);
            $display("=====================================");
        end

        $finish;
    end

    // ------------------------------------------------------------------
    // Optional waveform dump (view in Vivado waveform viewer or GTKWave)
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("tb_pwm_generator.vcd");
        $dumpvars(0, tb_pwm_generator);
    end

endmodule
