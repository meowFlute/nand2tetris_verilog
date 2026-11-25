SHELL := /bin/bash

CC    = iverilog
FLAGS = -g2012

RTL_ROOT  = rtl
TEST_ROOT = test
BUILD_DIR = build
STATS_DIR = $(BUILD_DIR)/stats

# --- Discovery ---------------------------------------------------------------
RTL_DIRS     = $(sort $(wildcard $(RTL_ROOT)/chapter_*))
CHAPTERS     = $(sort $(patsubst $(TEST_ROOT)/chapter_%,%,$(wildcard $(TEST_ROOT)/chapter_*)))
RTL_SRCS     = $(wildcard $(RTL_ROOT)/chapter_*/*.v)
TEST_SRCS    = $(wildcard $(TEST_ROOT)/chapter_*/*.v)

# test/chapter_1/test_and_gate.v -> build/chapter_1/test_and_gate
SIM_BINARIES = $(patsubst $(TEST_ROOT)/%.v,$(BUILD_DIR)/%,$(TEST_SRCS))
CH_BINS      = $(filter $(BUILD_DIR)/chapter_$(CHAPTER)/%,$(SIM_BINARIES))

# iverilog finds modules by filename in these dirs
IV_LIBS = $(addprefix -y ,$(RTL_DIRS))

# --- Synthesis (yosys) settings ----------------------------------------------
NAND_SRC   = $(RTL_ROOT)/chapter_1/nand_gate.v
MODULES    = $(filter-out nand_gate,$(basename $(notdir $(RTL_SRCS))))
YS_LIBDIRS = $(addprefix -libdir ,$(RTL_DIRS))
YS_FLAT    = flatten -noscopeinfo; rename -hide w:*; rename -hide c:*; opt_clean -purge
# $(call ys_read,<module>): black-box nand, read the top, auto-load the rest
ys_read    = read_verilog -lib $(NAND_SRC); \
             read_verilog $(firstword $(wildcard $(RTL_ROOT)/chapter_*/$(1).v)); \
             hierarchy $(YS_LIBDIRS) -top $(1)

# --- Simulation --------------------------------------------------------------
all: $(SIM_BINARIES)

# Only the testbench is named; iverilog pulls in what it needs via -y.
# Depends on all RTL for simplicity (cheap at this scale).
$(BUILD_DIR)/%: $(TEST_ROOT)/%.v $(RTL_SRCS)
	@mkdir -p $(@D)
	@echo "Compiling $@..."
	$(CC) $(FLAGS) $(IV_LIBS) -o $@ $<

# make run CHAPTER=1   (or no CHAPTER for a picklist)
run:
ifeq ($(CHAPTER),)
	@PS3="Chapter to test: "; \
	select c in $(CHAPTERS); do \
		[ -n "$$c" ] && $(MAKE) --no-print-directory run CHAPTER=$$c; break; \
	done
else
	@$(MAKE) --no-print-directory $(CH_BINS)
	@for bin in $(CH_BINS); do \
		echo "=== Running $$bin ==="; \
		./$$bin || exit 1; \
	done
endif

# --- Synthesis targets -------------------------------------------------------
stats:
	@mkdir -p $(STATS_DIR)
	@printf "%-24s %s\n" MODULE NANDS
	@for m in $(MODULES); do \
		yosys -q -p "read_verilog -lib $(NAND_SRC); \
			read_verilog $$(echo $(RTL_ROOT)/chapter_*/$$m.v); \
			hierarchy $(YS_LIBDIRS) -top $$m; $(YS_FLAT); \
			tee -o $(STATS_DIR)/$$m.txt stat" >/dev/null 2>&1; \
		printf "%-24s %s\n" $$m "$$(awk '/^ +nand_gate +[0-9]+/{n=$$2} END{print n+0}' $(STATS_DIR)/$$m.txt)"; \
	done

show:
ifeq ($(TOP),)
	@m=$$(scripts/pick_module.sh $(RTL_ROOT)) && $(MAKE) --no-print-directory show TOP=$$m
else
	PYTHONWARNINGS=ignore yosys -p "$(call ys_read,$(TOP)); $(YS_FLAT); stat; show -notitle -stretch $(TOP)"
endif

svg:
ifeq ($(TOP),)
	@m=$$(scripts/pick_module.sh $(RTL_ROOT)) && $(MAKE) --no-print-directory svg TOP=$$m
else
	@mkdir -p $(BUILD_DIR)
	PYTHONWARNINGS=ignore yosys -q -p "$(call ys_read,$(TOP)); $(YS_FLAT); show -format svg -viewer none -prefix $(BUILD_DIR)/$(TOP)"
endif

synth: stats

help:
	@echo "make                 build all testbenches"
	@echo "make run [CHAPTER=n] build and run one chapter (picklist if omitted)"
	@echo "make stats           NAND count for every module (no GUI)"
	@echo "make show [TOP=m]    schematic for one module (picklist if omitted)"
	@echo "make svg [TOP=m]     write build/<m>.svg (picklist if omitted)"
	@echo "make clean           remove build dir and VCD files"

clean:
	rm -rf $(BUILD_DIR) *.vcd

.PHONY: all run stats show svg synth help clean
