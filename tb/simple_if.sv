// tb/simple_if.sv
interface simple_if (input logic clk, input logic rst_n);
  logic        req, ack;
  logic [1:0]  op;
  logic [7:0]  a, b, y;

  clocking cb @(posedge clk);
    output req, op, a, b;
    input  ack, y;
  endclocking

  modport drv_mp (clocking cb, input rst_n);
  modport mon_mp (input req, ack, op, a, b, y, rst_n, clk);
endinterface
