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

# Target to run synthesis and view schematic
synth: | $(BUILD_DIR)
	yosys scripts/synth_not.ys

# Clean up built binaries and VCD waveform files
clean:
	rm -rf $(BUILD_DIR) *.vcd
