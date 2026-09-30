`include "interface.sv"
`include "transaction.sv"
`include "generator.sv"
`include "driver.sv"
`include "agent.sv"
`include "monitor.sv"
`include "scoreboard.sv"
`include "checker.sv"
`include "env.sv"
`include "test.sv"

module testbench;

    parameter int p_width = 16;
    parameter int p_drvs  = 4;
    parameter int p_bits  = 16;

    logic clk;
    initial begin
        clk = 0;
        forever #5 clk = ~clk; 
    end

    dut_compl_if #(p_width, p_drvs, p_bits) vif (
        .clk(clk)
    );

    bs_gnrtr_n_rbtr #(
        .bits(p_bits),
        .drvrs(p_drvs),
        .pckg_sz(p_width)
    ) dut (
        .clk(clk),
        .reset(vif.reset),
        .pndng(vif.pndng),
        .push(vif.push),
        .pop(vif.pop),
        .D_pop(vif.D_pop),
        .D_push(vif.D_push)
    );

    bus_test #(p_width, p_drvs) test;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);

        $display("Aplicando reset de hardware al bus...");
        vif.reset = 1;
        #20; // Esperamos 20 unidades de tiempo
        vif.reset = 0;
        $display("Reset liberado. Arrancando software de verificacion...");

        test = new(vif);
        
        test.run();

        $finish;
    end

endmodule

