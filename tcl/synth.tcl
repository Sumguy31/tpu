yosys -import
read_verilog -sv rtl/*.sv rtl/*.vh
procs; opt;
synth -top tpu
stat -tech cmos
