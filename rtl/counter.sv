`default_nettype none

module counter
#(parameter DATA_WIDTH)
 (input  logic clk, rst, en,
  output logic [DATA_WIDTH-1:0] Q);

  always_ff @(posedge clk)
    if (rst)
      Q <= 'b0;
    else if (en)
      Q <= Q + 'b1;
endmodule : counter
