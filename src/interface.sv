// Interface dut_compl_if. The dut_compl_if interface is responsible for bundling every signal of the bs_gnrtr_n_rbtr DUT and for providing the clocking blocks used by the driver (cb_drv) and the monitor (cb_mon).
interface dut_compl_if #(
    parameter int width = 16,
    parameter int drvs = 4,
    parameter int bits = 1
)(
    input logic clk
);
    logic reset;
    logic pndng[bits-1:0][drvs-1:0];
    logic push[bits-1:0][drvs-1:0];
    logic pop[bits-1:0][drvs-1:0];
    logic [width-1:0] D_pop[bits-1:0][drvs-1:0];
    logic [width-1:0] D_push[bits-1:0][drvs-1:0];

    // Driver view: drives the FIFO outputs, samples the DUT requests.
    // Outputs change 1ns after the edge so the DUT never sees a race.
    clocking cb_drv @(posedge clk);
        default input #1step output #1ns;
        output pndng, D_pop;
        input push, pop, D_push, reset;
    endclocking

    // Monitor view: passive, samples everything.
    clocking cb_mon @(posedge clk);
        default input #1step;
        input pndng, D_pop, push, pop, D_push, reset;
    endclocking
endinterface
