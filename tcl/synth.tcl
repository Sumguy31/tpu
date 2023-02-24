yosys -import
read_verilog -sv rtl/*vh rtl/*.sv
procs; opt;
synth -top tpu
stat -tech cmos
