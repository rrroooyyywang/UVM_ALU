// dut/simple_alu.sv
module simple_alu (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        req,
  output logic        ack,
  input  logic [1:0]  op,     // 0:add 1:sub 2:xor 3:and
  input  logic [7:0]  a,
  input  logic [7:0]  b,
  output logic [7:0]  y
);
  logic        req_q;
  logic [7:0]  res_q;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      req_q <= 0;
      res_q <= '0;
    end else begin
      req_q <= req;
      unique case (op)
        2'd0: res_q <= a + b;
        2'd1: res_q <= a - b;
        2'd2: res_q <= a ^ b;
        2'd3: res_q <= a & b;
      endcase
    end
  end
  

  assign ack = req_q;   // 固定 1 拍后给应答
  assign y   = res_q;
endmodule
