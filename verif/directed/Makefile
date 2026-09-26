SHELL := /bin/bash

# Toolchain
PREFIX ?= riscv64-unknown-elf-
AS = $(PREFIX)as
LD = $(PREFIX)ld
OBJCOPY = $(PREFIX)objcopy
OBJDUMP = $(PREFIX)objdump

ASFLAGS = -march=rv32i -mabi=ilp32
LDFLAGS = -m elf32lriscv -T linker.ld

# Directories
SRC_DIR    = src
ELF_DIR    = elf
BIN_DIR    = bin
DISASM_DIR = disasm
PROG_DIR   = prog

# Test sources are looked up in src/ first, then in the current directory
vpath %.S $(SRC_DIR) .

INTEGRATION_SRCS = $(notdir $(wildcard $(SRC_DIR)/integration_test_*.S))
INTEGRATION_NAMES = $(INTEGRATION_SRCS:.S=)
INTEGRATION_ELFS = $(addprefix $(ELF_DIR)/,$(INTEGRATION_NAMES:=.elf))
INTEGRATION_BINS = $(addprefix $(BIN_DIR)/,$(INTEGRATION_NAMES:=.bin))
INTEGRATION_DISS = $(addprefix $(DISASM_DIR)/,$(INTEGRATION_NAMES:=.dis))

.PHONY: all clean help prog run

all: $(INTEGRATION_ELFS) $(INTEGRATION_BINS) $(INTEGRATION_DISS)
	@echo ""
	@echo "Built $(words $(INTEGRATION_BINS)) integration test(s)"

# <name>.S -> elf/<name>.elf
$(ELF_DIR)/%.elf: %.S linker.ld | $(ELF_DIR)
	@$(AS) $(ASFLAGS) -o $(@:.elf=.o) $< && \
	$(LD) $(LDFLAGS) -o $@ $(@:.elf=.o) && \
	rm -f $(@:.elf=.o) && \
	echo "Built $< -> $@"

# elf/<name>.elf -> bin/<name>.bin
$(BIN_DIR)/%.bin: $(ELF_DIR)/%.elf | $(BIN_DIR)
	@$(OBJCOPY) -O binary $< $@

# elf/<name>.elf -> disasm/<name>.dis
$(DISASM_DIR)/%.dis: $(ELF_DIR)/%.elf | $(DISASM_DIR)
	@$(OBJDUMP) -d -M no-aliases,numeric $< > $@

$(ELF_DIR) $(BIN_DIR) $(DISASM_DIR):
	@mkdir -p $@

TARGET_SIM_ROOT := ../../target/sim

# Only run directed tests for full configs
DIRECTED_CONFIGS ?= full full-itermul

run: all
	@failed="";                                                                          \
	for c in $(DIRECTED_CONFIGS); do                                                     \
		$(MAKE) -C $(TARGET_SIM_ROOT) core CONFIG=$$c || { failed="$$failed $$c"; continue; }; \
		python3 $(TARGET_SIM_ROOT)/scripts/run.py $(ELF_DIR) $$c || failed="$$failed $$c";  \
	done;                                                                                \
	if [ -n "$$failed" ]; then echo "Failing configs:$$failed"; exit 1; fi

help:
	@echo "Usage:"
	@echo "  make                        - Build all integration tests into elf/, bin/, disasm/"
	@echo "  make run                    - Build and run all integration tests on the core sim"
	@echo "  make prog TEST=<name>       - Build <name>.S into prog/prog.{elf,bin,dis} (for GUI sim)"
	@echo "  make clean                  - Remove build artifacts"

# Always rebuilt
prog:
	@test -n "$(TEST)" || (echo "Error: specify TEST=<name>  e.g. make prog TEST=integration_test_Zaamo"; exit 1)
	@mkdir -p $(PROG_DIR)
	@SRC=$$(for d in $(SRC_DIR) .; do [ -f "$$d/$(TEST).S" ] && echo "$$d/$(TEST).S" && break; done); \
	test -n "$$SRC" || { echo "Error: $(TEST).S not found in $(SRC_DIR)/ or ./"; exit 1; }; \
	$(AS) $(ASFLAGS) -o $(PROG_DIR)/prog.o $$SRC && \
	$(LD) $(LDFLAGS) -o $(PROG_DIR)/prog.elf $(PROG_DIR)/prog.o && \
	$(OBJCOPY) -O binary $(PROG_DIR)/prog.elf $(PROG_DIR)/prog.bin && \
	$(OBJDUMP) -d -M no-aliases,numeric $(PROG_DIR)/prog.elf > $(PROG_DIR)/prog.dis && \
	rm -f $(PROG_DIR)/prog.o && \
	echo "Built $$SRC -> $(PROG_DIR)/prog.bin"

clean:
	rm -rf $(ELF_DIR) $(BIN_DIR) $(DISASM_DIR) $(PROG_DIR)
