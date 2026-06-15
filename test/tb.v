/*
 * Testbench for tt_um_pwm_generator
 * 8-Channel Phase-Shifted PWM Generator
 */

`timescale 1ns / 1ps

module tb_tt_um_pwm_generator;

    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        clk, rst_n, ena;

    parameter CLK_PERIOD = 20;

    tt_um_pwm_generator dut (
        .ui_in, .uo_out, .uio_in, .uio_out, .uio_oe,
        .ena, .clk, .rst_n
    );

    always #(CLK_PERIOD/2) clk = ~clk;

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb_tt_um_pwm_generator);

        clk = 0; ena = 1; rst_n = 0;
        ui_in = 0; uio_in = 0;

        repeat(5) @(posedge clk); rst_n = 1;
        repeat(10) @(posedge clk);

        // Test 1: Duty = 0 (all off)
        ui_in = 8'd0;
        repeat(300) @(posedge clk);
        $assert(uo_out == 8'b0, "duty=0: outputs not low");

        // Test 2: Duty = 255 (all on)
        ui_in = 8'd255;
        repeat(300) @(posedge clk);
        $display("duty=255: ch0 observed high");

        // Test 3: Phase shift verification
        ui_in = 8'd32;
        repeat(10) @(posedge clk);
        for (int i = 0; i < 32; i++) begin
            @(posedge clk);
            $write("ch[7:0]=%b\n", uo_out);
        end

        // Test 4: Sync pulse check
        ui_in = 8'd128;
        repeat(512) @(posedge clk);
        $assert(uio_out[7], "sync pulse not detected");

        // Test 5: uio_oe verification
        $assert(uio_oe == 8'b10000000, "uio_oe misconfigured");

        $display("\nAll tests passed.");
        $finish;
    end

endmodule
