`default_nettype none
`include "defines.vh"

`ifndef TEST_INPUT_DIR
  `define TEST_INPUT_DIR "tb/test_inputs/"
`endif

module tpu_tb();
  parameter MATRIX_DIM = 16;
  parameter CONV_DIM = 3;
  parameter MATRIX_LENGTH = MATRIX_DIM*MATRIX_DIM;
  parameter CONV_LENGTH = CONV_DIM*CONV_DIM;

  logic clk, rst, insert_kernel, insert_matrix, ready, done;
  data_t data_in, data_out;
  tpu dut(.*);

  data_t [CONV_LENGTH-1:0] kernel_data;
  data_t [MATRIX_LENGTH-1:0] matrix_data;
  data_t [MATRIX_LENGTH-1:0] result_data;
  initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
  end

  initial begin
    init();
    send_kernel();
    send_matrix();

    recv_data();
    fini();
  end

  task init();
    $readmemh({TEST_INPUT_DIR, "16x16.hex"}, insert_matrix);
    $readmemh({TEST_INPUT_DIR, "3x3.hex"}, insert_kernel);
  endtask

  task fini();
    $writememh("out.hex", result_data);
    $finish;
  endtask
  task send_kernel();
    insert_kernel <= 1'b1;
    for (int i = 0; i < CONV_LENGTH; i++) begin
      data_in <= kernel_data[i];
      @(posedge clk);
    end
    @(posedge clk);
    insert_kernel <= 1'b0;
    @(posedge clk);
  endtask

  task send_matrix();
    insert_matrix <= 1'b1;
    for (int i = 0; i < MATRIX_LENGTH; i++) begin
      data_in <= matrix_data[i];
      @(posedge clk);
    end
    @(posedge clk);
    insert_matrix <= 1'b0;
    @(posedge clk);
  endtask

  task recv_data();
    ready <= 1'b1;
    int i = 0;
    while (i < MATRIX_LENGTH) begin
      @(posedge clk);
      if (done) begin
        result_data[i++] <= data_out;
      end
    end
  endtask
endmodule : tpu_tb
