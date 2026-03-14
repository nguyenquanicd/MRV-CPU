# Makefile for RISC-V RV32I Single-Cycle CPU Testbench (Verilator)

# Directories
RTL_DIR    := $(MRV_CPU_HOME)/rtl
SIM_ROOT   := $(MRV_CPU_HOME)/sim
TESTS_DIR  := $(SIM_ROOT)/tests
TEST       ?= instructions_test
TEST_DIR   := $(TESTS_DIR)/$(TEST)
SW_DIR     := $(TEST_DIR)/sw
SIM_DIR    := $(shell pwd)
OBJ_DIR    := $(SIM_DIR)/obj_dir
TB_SRC     ?= $(TEST_DIR)/tb.sv
TB_LOCAL   := $(SIM_DIR)/tb.sv
SW_SRC     ?= $(firstword $(wildcard $(TEST_DIR)/test.S $(SW_DIR)/test.S $(TEST_DIR)/test.c $(SW_DIR)/test.c))
SW_LINKER  ?= $(MRV_CPU_HOME)/utils/linker.ld
IMEM_HEX   ?= $(TEST_DIR)/imem.hex
IMEM_BASE  ?= auto

# Tool
VERILATOR ?= verilator

# Source file lists
RTL_FILELIST  = $(RTL_DIR)/filelist.f
TB_LIB_SRCS   = $(SIM_ROOT)/lib/apb_slave_bfm.sv \
                $(SIM_ROOT)/lib/imem.sv
TB_BUILD_SRCS = $(TB_LIB_SRCS) $(TB_LOCAL)

# Verilator flags
VL_FLAGS = --binary \
           --sv \
           --top-module tb \
           --timing \
           --trace \
           --Mdir $(OBJ_DIR) \
           -Wno-fatal

# Build targets
.PHONY: all simv run hex clean sync_hex sync_tb

all: simv

simv: sync_tb $(RTL_FILELIST) $(TB_LIB_SRCS)
	@mkdir -p $(SIM_DIR)
	MRV_CPU_HOME=$(MRV_CPU_HOME) $(VERILATOR) $(VL_FLAGS) -f $(RTL_FILELIST) $(TB_BUILD_SRCS) -o $(SIM_DIR)/simv

sync_hex:
	cp $(IMEM_HEX) $(SIM_DIR)/imem.hex

sync_tb:
	@mkdir -p $(SIM_DIR)
	@if [ ! -f "$(TB_LOCAL)" ] || ! cmp -s "$(TB_SRC)" "$(TB_LOCAL)"; then \
		cp "$(TB_SRC)" "$(TB_LOCAL)"; \
	fi

run: sync_hex simv
	cd $(SIM_DIR) && ./simv

# Build imem.hex from source (requires riscv64-unknown-elf-gcc)
hex: $(SW_SRC)
	python3 $(MRV_CPU_HOME)/utils/build_imem.py $(SW_SRC) --linker $(SW_LINKER) --out-hex $(IMEM_HEX) --work-dir $(TEST_DIR) --base-addr $(IMEM_BASE)
	cp $(IMEM_HEX) $(SIM_DIR)/imem.hex

wave:
	gtkwave waveform.vcd

clean:
	rm -rf $(OBJ_DIR) $(SIM_DIR)/simv $(SIM_DIR)/simv.d $(SIM_DIR)/imem.hex $(SIM_DIR)/tb.sv $(SIM_DIR)/*.vcd $(SIM_DIR)/*.log
	rm -f $(TEST_DIR)/*.elf $(TEST_DIR)/*.bin $(TEST_DIR)/*.dump
