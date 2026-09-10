/*
 * tb_simon.sv -- verify simon_enc against model vectors (official + random).
 *   iverilog -g2012 -DUNROLL=k -I rtl rtl/simon_enc.sv tb/tb_simon.sv
 *   vvp a.out +vec=sim/vectors.hex
 */
`timescale 1ns/1ps
`ifndef UNROLL
 `define UNROLL 1
`endif
module tb_simon;
    `include "simon_consts.svh"
    localparam CLKP = 4;

    logic clk = 0, rst, i_valid, i_ready, o_ready, o_valid;
    logic [255:0] i_key, i_block, o_ct;
    always #(CLKP/2) clk = ~clk;

    simon_enc #(.UNROLL(`UNROLL)) dut (
        .clk(clk), .rst(rst), .i_key(i_key), .i_block(i_block),
        .i_valid(i_valid), .o_ready(o_ready),
        .o_ct(o_ct), .o_valid(o_valid), .i_ready(i_ready));

    integer fd, ret, errors, total;
    reg [255:0] key, pt, ct;
    string vecfile;

    initial begin
        if (!$value$plusargs("vec=%s", vecfile)) vecfile = "sim/vectors.hex";
        rst = 1; i_valid = 0; i_ready = 0; i_key = 0; i_block = 0;
        errors = 0; total = 0;
        repeat (4) @(negedge clk);
        rst = 0;
        fd = $fopen(vecfile, "r");
        if (fd == 0) begin $display("FATAL: cannot open %s", vecfile); $finish; end

        while ($fscanf(fd, "%h %h %h", key, pt, ct) == 3) begin
            @(negedge clk);
            while (!o_ready) @(negedge clk);
            i_key = key; i_block = pt; i_valid = 1;
            @(negedge clk); i_valid = 0;
            while (!o_valid) @(negedge clk);
            if (o_ct[BLK-1:0] !== ct[BLK-1:0]) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("MISMATCH #%0d key=%h pt=%h exp=%h got=%h",
                             total, key[KEYW-1:0], pt[BLK-1:0], ct[BLK-1:0], o_ct[BLK-1:0]);
            end
            total = total + 1;
            i_ready = 1; @(negedge clk); i_ready = 0;
        end
        $fclose(fd);
        if (errors == 0)
            $display("TEST PASSED: %0d/%0d vectors exact (UNROLL=%0d, T=%0d)",
                     total, total, `UNROLL, T);
        else
            $display("TEST FAILED: %0d mismatches / %0d (UNROLL=%0d)", errors, total, `UNROLL);
        $finish;
    end

    initial begin #2000000; $display("FATAL: timeout"); $finish; end
endmodule
