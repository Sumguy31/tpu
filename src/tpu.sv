`default_nettype none
`include "defines.vh"

module tpu
#(parameter MATRIX_DIM=16,
  parameter CONV_DIM=3)
 (input  logic clk, rst,
  input  logic insert_kernal, insert_matrix, ready,
  input  data_t data_in,
  output logic done,
  output data_t data_out);

  typedef struct packed {
    logic [$clog2(MATRIX_DIM)-1:0] x,y;
  } base_coord_t;

  typedef struct packed {
    logic [$clog2(MATRIX_DIM):0] x,y;
  } matrix_coord_t;

  typedef struct packed {
    logic [$clog2(CONV_DIM)-1:0] x,y;
  } conv_coord_t;

  // KERNAL LOGIC
  // HACK: Yosys doesn't support packed arrays https://github.com/YosysHQ/yosys/issues/340
  data_t kernal_data;
  conv_coord_t kernal_addr;
  logic [($clog2(CONV_DIM*CONV_DIM))-1:0] kernal_data_sel;
  always_comb begin
    kernal_data_sel = kernal_addr.x * CONV_DIM
                      + {{$clog2(CONV_DIM){1'b0}},kernal_addr.y};
  end

  matrix #(.MATRIX_DIM(CONV_DIM))
         KERNAL_MAT(.clk, .rst, .we(insert_kernal),
                    .D(data_in), .Q(kernal_data),
                    .addr(kernal_data_sel));
  // MATRIX LOGIC
  // HACK: Yosys doesn't support packed arrays https://github.com/YosysHQ/yosys/issues/340
  data_t matrix_data;
  matrix_coord_t matrix_addr;
  logic [($clog2(MATRIX_DIM*MATRIX_DIM))-1:0] matrix_data_sel;
  always_comb begin
    matrix_data_sel = matrix_addr.x[$clog2(MATRIX_DIM)-1:0] *  MATRIX_DIM
                    + {{$clog2(MATRIX_DIM){1'b0}}, matrix_addr.y[$clog2(MATRIX_DIM)-1:0]};
  end
  matrix #(.MATRIX_DIM(MATRIX_DIM))
         MATRIX_MAT(.clk, .rst, .we(insert_matrix),
                    .D(data_in), .Q(matrix_data),
                    .addr(matrix_data_sel));


  // CONVOLUTION CONTROL
  base_coord_t base_addr;

  logic kernal_y_incr;
  assign kernal_y_incr = & kernal_addr.x;
  counter #($bits(kernal_addr.x)) kernal_addr_x_counter(.clk, .rst, .en(1'b1), .Q(kernal_addr.x));
  counter #($bits(kernal_addr.y)) kernal_addr_y_counter(.clk, .rst, .en(kernal_y_incr), .Q(kernal_addr.y));

  logic base_y_incr, base_x_incr;
  assign base_x_incr = & kernal_y_incr;
  assign base_y_incr = & base_addr.x;
  counter #($bits(base_addr.x)) base_addr_x_counter(.clk, .rst, .en(base_x_incr), .Q(base_addr.x));
  counter #($bits(base_addr.y)) base_addr_y_counter(.clk, .rst, .en(base_y_incr), .Q(base_addr.y));

  parameter DIFF = $clog2(MATRIX_DIM)-$clog2(CONV_DIM);
  assign matrix_addr.x = base_addr.x + {{DIFF{1'b0}}, kernal_addr.x};
  assign matrix_addr.y = base_addr.y + {{DIFF{1'b0}}, kernal_addr.y};

  // MAC LOGIC
  // TODO: double check reset logic and its interaction with Done/Ready
  logic mac_en, mac_rst;
  assign mac_rst = base_x_incr & ready;
  assign done = mac_rst;
  assign mac_en = 1'b1; // TODO:
  mac #(`DATA_WIDTH,`DATA_WIDTH)
      conv_mac (.clk, .rst(mac_rst), .en(mac_en),
                .a(kernal_data),
                .b(matrix_data),
                .sum(data_out));

endmodule : tpu
