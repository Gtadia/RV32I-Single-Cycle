TARBALL = ece3058_lab1_submission.tar.gz

all: sim

core_tb: ./include/core_pkg.sv ./testbench/core_tb.sv Core.sv Fetch.sv Decode.sv ALU.sv DRAM.sv DFlipFlop.sv Register_File.sv LSU.sv
	iverilog -g2012 -I include -s Core_tb -o $@ $^

sim: core_tb
	vvp $<

submit: clean
	tar -czvf $(TARBALL) $(wildcard *.sv) include/core_pkg.sv
	@echo
	@echo 'Submission tarball written to' $(TARBALL)
	@echo 'Please decompress it yourself and make sure it looks right!'
	@echo 'Then submit it to Gradescope'


clean:
	rm -f core_tb Core_Simulation.vcd $(TARBALL)