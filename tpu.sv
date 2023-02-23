`default_nettype none

module tpu
#(parameter DATA_WIDTH=8,
  parameter MATRIX_DIM=16,
  parameter CONV_DIM=3)
 (input  logic clk, rst,
  input  logic insert_kernel, insert_matrix, ready,
  input  logic [7:0] data_in,
  output logic done,
  output logic [7:0] data_out)

  typedef struct {
    logic [$clog2(MATRIX_DIM)-1:0] x,y;
  } base_coord_t;

  typedef struct {
    logic [$clog2(MATRIX_DIM):0] x,y;
  } matrix_coord_t;

  typedef struct {
    logic [$clog2(CONV_DIM)-1:0] x,y;
  } conv_coord_t;

  // KERNAL LOGIC
  logic [CONV_DIM-1:0][DATA_WIDTH-1:0] kernal_data;
  conv_coord_t kernal_addr;
  logic kernal_re; logic [CONV_DIM-1:0] kernal_we;
  generate
    for (genvar i = 0; i < CONV_DIM; i++) : outer_loop
        sram #(CONV_DIM,DATA_WIDTH)
             kernal_sram (.clk, .rst, .re(kernal_re), .we(kernal_we),
                          .data_in, .data_out(kernal_data[i]),
                          .addr(kernal_addr.y));
  endgenerate

  // MATRIX LOGIC
  logic [MATRIX_DIM-1:0][DATA_WIDTH-1:0] matrix_data;
  matrix_coord_t matrix_addr;
  logic matrix_re; logic [MATRIX_DIM-1:0] matrix_we;
  generate
    for (genvar i = 0; i < MATRIX_DIM; i++) : outer_loop
        sram #(MATRIX_DIM,DATA_WIDTH)
             matrix_sram (.clk, .rst, .re(matrix_re), .we(kernel_we),
                          .data_in, .data_out(matrix_data[i]),
                          .addr(matrix_addr.y));
  endgenerate

  // MAC LOGIC
  logic mac_en, mac_rst;
  mac #(DATA_WIDTH,DATA_WIDTH)
      conv_mac (.clk, .rst(mac_rst) .en(mac_en),
                .a(kernal_data[kernal_addr.x]),
                .b(matrix_data[matrix_addr.x]),
                .sum(data_out));

  // CONVOLUTION CONTROL
  base_coord_t base_addr;

  logic kernal_y_incr;
  assign kernal_y_incr = | kernal_addr.x;
  counter #($bits(kernal_addr.x)) kernal_addr_x_counter(.clk, .rst, .en(1'b1), .Q(kernal_addr.x));
  counter #($bits(kernal_addr.y)) kernal_addr_y_counter(.clk, .rst, .en(kernal_y_incr), .Q(kernal_addr.y));

  logic base_y_incr;
  assign base_y_incr = | base_addr.x;
  counter #($bits(base_addr.x)) base_addr_x_counter(.clk, .rst, .en(1'b1), .Q(base_addr.x));
  counter #($bits(base_addr.y)) base_addr_y_counter(.clk, .rst, .en(base_y_incr), .Q(base_addr.y));

  assign matrix_addr.x = base_addr.x + kernal_addr.x;
  assign matrix_addr.y = base_addr.y + kernal_addr.y;


endmodule : tpu
