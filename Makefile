SHELL := /bin/bash

# Compiler and flags
CC = iverilog
FLAGS = -g2012

# Directories
RTL_DIR = rtl
TEST_DIR = test
BUILD_DIR = build

# Automatically find all RTL files and testbenches
RTL_SRCS = $(wildcard $(RTL_DIR)/*.v)
TEST_SRCS = $(wildcard $(TEST_DIR)/*.v)

# Generate simulation binary names (e.g., tb/tb_not.v -> sim_tb_not)
SIM_BINARIES = $(patsubst $(TEST_DIR)/%.v, $(BUILD_DIR)/sim_%, $(TEST_SRCS))

# --- Synthesis (yosys) settings ---------------------------------------------
# nand_gate is the one leaf cell: read as a black box, everything else is
# flattened down to instances of it.
NAND_SRC   = $(RTL_DIR)/nand_gate.v
OTHER_SRCS = $(filter-out $(NAND_SRC),$(RTL_SRCS))
# assumes module name == file name (and_gate.v defines and_gate)
MODULES    = $(basename $(notdir $(OTHER_SRCS)))
STATS_DIR  = $(BUILD_DIR)/stats

YS_READ = read_verilog -lib $(NAND_SRC); read_verilog $(OTHER_SRCS)
YS_FLAT = flatten -noscopeinfo; rename -hide w:*; rename -hide c:*; opt_clean -purge

# Default target: build all testbenches
all: | $(BUILD_DIR) $(SIM_BINARIES)

$(BUILD_DIR):
	@echo "creating build dir $(BUILD_DIR)..."
	@mkdir -p $(BUILD_DIR)

# Pattern rule: compiles any testbench with all RTL source files
$(BUILD_DIR)/sim_%: $(TEST_DIR)/%.v $(RTL_SRCS) | $(BUILD_DIR)
	@echo "Compiling $@..."
	$(CC) $(FLAGS) -o $@ $(RTL_SRCS) $<

# Target to run all compiled simulations sequentially
run: all
	@for bin in $(SIM_BINARIES); do \
		echo "=== Running $$bin ==="; \
		./$$bin || exit 1; \
	done

# --- Synthesis targets --------------------------------------------------------

# NAND counts for every module, no GUI
stats: | $(BUILD_DIR)
	@mkdir -p $(STATS_DIR)
	@printf "%-24s %s\n" MODULE NANDS
	@for m in $(MODULES); do \
		yosys -q -p "$(YS_READ); hierarchy -top $$m; $(YS_FLAT); tee -o $(STATS_DIR)/$$m.txt stat" >/dev/null 2>&1; \
		printf "%-24s %s\n" $$m "$$(awk '/^ +nand_gate +[0-9]+/{n=$$2} END{print n+0}' $(STATS_DIR)/$$m.txt)"; \
	done

# Schematic for one module: make show TOP=and_gate (or no TOP for a picklist)
show: | $(BUILD_DIR)
ifeq ($(TOP),)
	@PS3="Module to view: "; \
	select m in $(MODULES); do \
		[ -n "$$m" ] && $(MAKE) --no-print-directory show TOP=$$m; break; \
	done
else
	PYTHONWARNINGS=ignore yosys -p "$(YS_READ); hierarchy -top $(TOP); $(YS_FLAT); stat; show -notitle -stretch $(TOP)"
endif

# Same as show, but writes build/<TOP>.svg instead of opening a viewer
# (better for big designs): make svg TOP=alu
svg: | $(BUILD_DIR)
ifeq ($(TOP),)
	@PS3="Module to view: "; \
	select m in $(MODULES); do \
		[ -n "$$m" ] && $(MAKE) --no-print-directory svg TOP=$$m; break; \
	done
else
	PYTHONWARNINGS=ignore yosys -q -p "$(YS_READ); hierarchy -top $(TOP); $(YS_FLAT); show -format svg -viewer none -prefix $(BUILD_DIR)/$(TOP)"
endif

# Old entry point, kept so muscle memory still works
synth: stats

help:
	@echo "make               build all testbenches"
	@echo "make run           build and run all testbenches"
	@echo "make stats         NAND count for every module (no GUI)"
	@echo "make show [TOP=m]  schematic for one module (picklist if TOP omitted)"
	@echo "make svg [TOP=m]   write build/<m>.svg (picklist if TOP omitted)"
	@echo "make clean         remove build dir and VCD files"

# Clean up built binaries and VCD waveform files
clean:
	rm -rf $(BUILD_DIR) *.vcd

.PHONY: all run stats show svg synth help clean
