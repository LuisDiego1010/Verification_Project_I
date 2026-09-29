interface dut_compl_if #(
  parameter int drvrs = 4,      // Number of connected devices
  parameter int width = 16,   // Bit packet size
  parameter int bits = 1        // Device dimensions
) (
  input logic clk
);
    logic reset;
    logic               pndng [bits-1:0][drvs-1:0];
    logic               push  [bits-1:0][drvs-1:0];
    logic               pop   [bits-1:0][drvs-1:0];
    logic [width-1:0]   D_pop [bits-1:0][drvs-1:0];
    logic [width-1:0]   D_push[bits-1:0][drvs-1:0];

    clocking cb_drv @(posedge clk);
        default input #1step output #1ns;
        output pndng, D_pop;
        input  push, pop, D_push;
    endclocking

    clocking cb_mon @(posedge clk);
        default input #1step;
        input pndng, D_pop, push, pop, D_push;
    endclocking

    modport DRV (clocking cb_drv, input reset);
    modport MON (clocking cb_mon, input reset);

endinterface
