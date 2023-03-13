SV_FILES = rtl/*.sv
V_FILES = rtl/verilog/top.v
VH_FILES = rtl/*.vh
INCLUDES_DIR = rtl/

SYNTH = yosys
SYNTH_FLAGS =

.PHONY: synth synth.verilog clean

synth: $(SV_FILES) $(VH_FILES)
	$(SYNTH) $(SYNTH_FLAGS) -c tcl/synth.tcl

synth.verilog: $(V_FILES)
	$(SYNTH) $(SYNTH_FLAGS) -c tcl/synth_verilog.tcl

$(V_FILES): $(SV_FILES) $(VH_FILES)
	sv2v -I $(INCLUDES_DIR) $(SV_FILES) > $(V_FILES)
clean:
	echo "Nothing to clean"
