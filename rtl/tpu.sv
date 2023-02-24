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
  data_t [(CONV_DIM*CONV_DIM)-1:0] kernal_data;
  conv_coord_t kernal_addr;
  logic [(CONV_DIM*CONV_DIM)-1:0] kernal_we;
  logic [($clog2(CONV_DIM*CONV_DIM))-1:0] kernal_data_sel;
  always_comb begin
    kernal_we = 'b0;
    kernal_data_sel = kernal_addr.x * CONV_DIM
                      + {{$clog2(CONV_DIM){1'b0}},kernal_addr.y};
    kernal_we[kernal_data_sel] = insert_kernal;
  end
  generate
    for (genvar i = 0; i < CONV_DIM; i++) begin : outer_loop_kernal
      for (genvar j = 0; j < CONV_DIM; j++) begin : inner_loop_kernal
        register #(`DATA_WIDTH) kernal_reg(.clk, .rst, .we(kernal_we[(i * CONV_DIM) + j]),
                                          .D(data_in), .Q(kernal_data[(i * CONV_DIM) + j]));
      end
    end
  endgenerate

  // MATRIX LOGIC
  // HACK: Yosys doesn't support packed arrays https://github.com/YosysHQ/yosys/issues/340
  data_t [(MATRIX_DIM*MATRIX_DIM)-1:0] matrix_data;
  matrix_coord_t matrix_addr;
  logic [(MATRIX_DIM*MATRIX_DIM)-1:0] matrix_we;
  logic [($clog2(MATRIX_DIM*MATRIX_DIM))-1:0] matrix_data_sel;
  always_comb begin
    matrix_we = 'b0;
    matrix_data_sel = matrix_addr.x[$clog2(MATRIX_DIM)-1:0] *  MATRIX_DIM
                    + {{$clog2(MATRIX_DIM){1'b0}}, matrix_addr.y[$clog2(MATRIX_DIM)-1:0]};
    matrix_we[matrix_data_sel] = insert_matrix;
  end
  generate
    for (genvar i = 0; i < MATRIX_DIM; i++) begin : outer_loop_matrix
      for (genvar j = 0; j < MATRIX_DIM; j++) begin : inner_loop_matrix
        register #(`DATA_WIDTH) matrix_reg(.clk, .rst, .we(matrix_we[i * MATRIX_DIM + j]),
                                          .D(data_in), .Q(matrix_data[i * MATRIX_DIM + j]));
      end
    end
  endgenerate


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
                .a(kernal_data[kernal_data_sel]),
                .b(matrix_data[matrix_data_sel]),
                .sum(data_out));

endmodule : tpu
