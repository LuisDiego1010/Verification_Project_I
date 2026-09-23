interface bus_interface #(
  parameter int drvrs = 4,      // Cantidad de dispositivos conectados
  parameter int pckg_sz = 16,   // Tamaño del paquete en bits
  parameter int bits = 1        // Dimensión adicional del prototipo
) (
  input logic clk,
  input logic reset

);

    logic               pndng [bits-1:0][drvs-1:0];
    logic               push  [bits-1:0][drvs-1:0];
    logic               pop   [bits-1:0][drvs-1:0];
    logic [width-1:0]   D_pop [bits-1:0][drvs-1:0];
    logic [width-1:0]   D_push[bits-1:0][drvs-1:0];

endinterface
