yosys -import
read_verilog rtl/verilog/top.v
procs; opt;
synth -top tpu
stat -tech cmos
