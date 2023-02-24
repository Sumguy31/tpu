`default_nettype none

module tpu
#(parameter DATA_WIDTH=8,
  parameter MATRIX_DIM=16,
  parameter CONV_DIM=3)
 (input  logic clk, rst,
  input  logic insert_kernal, insert_matrix, ready,
  input  logic [DATA_WIDTH-1:0] data_in,
  output logic done,
  output logic [DATA_WIDTH-1:0] data_out);

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
  logic [CONV_DIM-1:0][CONV_DIM-1:0][DATA_WIDTH-1:0] kernal_data;
  conv_coord_t kernal_addr;
  logic [CONV_DIM-1:0][CONV_DIM-1:0] kernal_we;
  always_comb begin
    kernal_we = 'b0;
    kernal_we[kernal_addr.x][kernal_addr.y] = insert_kernal;
  end
  generate
    for (genvar i = 0; i < CONV_DIM; i++) begin : outer_loop_kernal
      for (genvar j = 0; j < CONV_DIM; j++) begin : inner_loop_kernal
        register #(DATA_WIDTH) kernal_reg(.clk, .rst, .we(kernal_we[i][j]),
                                          .D(data_in), .Q(kernal_data[i][j]));
      end
    end
  endgenerate

  // MATRIX LOGIC
  logic [MATRIX_DIM-1:0][MATRIX_DIM-1:0][DATA_WIDTH-1:0] matrix_data;
  matrix_coord_t matrix_addr;
  logic [MATRIX_DIM-1:0][MATRIX_DIM-1:0] matrix_we;
  always_comb begin
    matrix_we = 'b0;
    matrix_we[matrix_addr.x[$clog2(MATRIX_DIM)-1:0]]
             [matrix_addr.y[$clog2(MATRIX_DIM)-1:0]]  = insert_matrix;
  end
  generate
    for (genvar i = 0; i < MATRIX_DIM; i++) begin : outer_loop_matrix
      for (genvar j = 0; j < MATRIX_DIM; j++) begin : inner_loop_matrix
        register #(DATA_WIDTH) matrix_reg(.clk, .rst, .we(matrix_we[i][j]),
                                          .D(data_in), .Q(matrix_data[i][j]));
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
  mac #(DATA_WIDTH,DATA_WIDTH)
      conv_mac (.clk, .rst(mac_rst), .en(mac_en),
                .a(kernal_data[kernal_addr.x][kernal_addr.y]),
                .b(matrix_data[matrix_addr.x][matrix_addr.y]),
                .sum(data_out));

endmodule : tpu
