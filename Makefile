SV_FILES = rtl/*.sv
V_FILES = rtl/verilog/top.v
VH_FILES = rtl/*.vh
INCLUDES_DIR = rtl/

SYNTH = yosys
SYNTH_FLAGS =

.phony: synth synth.quiet

synth: $(VH_FILES) $(SV_FILES)
	$(SYNTH) $(SYNTH_FLAGS) -c tcl/synth.tcl

synth.quiet: $(VH_FILES) $(SV_FILES)
	$(SYNTH) $(SYNTH_FLAGS) -q -c tcl/synth.tcl

$(V_FILES): $(SV_FILES) $(VH_FILES)
	sv2v -I $(INCLUDES_DIR) $(SV_FILES) > $(V_FILES)
