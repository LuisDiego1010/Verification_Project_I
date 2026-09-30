`timescale 1ns/1ps

// DUT sources. Library.sv includes "../FIFO_Latches/fifo.sv" unless FIFOS is defined, so fifo.sv is included here and the macro set beforehand.
`ifndef FIFOS
    `define FIFOS
    `include "fifo.sv"
`endif
`include "Library.sv"

// Environment sources, in dependency order
`include "interface.sv"
`include "transaction.sv"
`include "generator.sv"
`include "agent.sv"
`include "driver.sv"
`include "monitor.sv"
`include "scoreboard.sv"
`include "checker.sv"
`include "env.sv"
`include "test.sv"

// Module testbench. The testbench module is responsible for the clock, the reset, the DUT, the interface and for launching the test.
module testbench;

    // Packet width (16, 32 or 64) and number of terminals
    parameter int p_width = 16;
    parameter int p_drvs = 4;
    // Broadcast ID given to the DUT and to the environment. The RTL compares against 8'hFF internally, so any other value is expected to fail
    parameter bit [7:0] p_bcast = 8'hFF;

    logic clk;
    bus_test #(p_width, p_drvs) test;

    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // bits = 1: one bus (it is the number of buses, not the data width)
    dut_compl_if #(p_width, p_drvs, 1) vif (
        .clk(clk)
    );

    bs_gnrtr_n_rbtr #(
        .bits(1),
        .drvrs(p_drvs),
        .pckg_sz(p_width),
        .broadcast(p_bcast)
    ) dut (
        .clk(clk),
        .reset(vif.reset),
        .pndng(vif.pndng),
        .push(vif.push),
        .pop(vif.pop),
        .D_pop(vif.D_pop),
        .D_push(vif.D_push)
    );

    initial begin
        if (!(p_width inside {16, 32, 64})) begin
            $fatal(1, "[TOP] p_width debe ser 16, 32 o 64 (se recibio %0d)", p_width);
        end
        if (p_bcast < p_drvs) begin
            $fatal(1, "[TOP] p_bcast no puede ser la direccion de una terminal (se recibio %0d)", p_bcast);
        end
        if ($test$plusargs("DUMP")) begin
            $dumpfile("dump.vcd");
            $dumpvars(0, testbench);
        end

        // The env is built at time 0 so the FIFOs are idle during reset.
        // Reset starts at 0 and rises at 1ns: the DUT flops reset on "posedge reset", and a 1 written at time 0 can be missed depending on which process the simulator starts first.
        vif.reset = 1'b0;
        test = new(vif, p_bcast);
        fork
            test.run();
        join_none
        #1 vif.reset = 1'b1;
        repeat (5) @(posedge clk);
        vif.reset = 1'b0;

        wait fork;
        $finish;
    end

endmodule
