CORE_TOP = friscv_cpu_verilator

CONFIG   ?= full
CONFIGS  := $(basename $(notdir $(wildcard configs/*.f)))

CORE_DIR = obj_dir_$(CONFIG)
CORE_BIN = $(CORE_DIR)/$(CORE_TOP)

CORE_CPP = $(wildcard cpp/*.cpp)

# friscv_mem_pkg from friscv-mem-utils, then the core in Bender.yml order
CORE_SRCS = $(shell bender -d ../.. script flist -t rtl | grep -E '/friscv_mem_pkg\.sv$$|^$(abspath ../..)/rtl/')

core:
	@test -f configs/$(CONFIG).f || { echo "Unknown CONFIG '$(CONFIG)', expected one of: $(CONFIGS)"; exit 1; }
	verilator --cc --exe --build -j 0 --top-module $(CORE_TOP) --timescale 1ns/1ps      \
		-f configs/$(CONFIG).f                                                          \
		--Mdir $(CORE_DIR) $(CORE_SRCS) rtl/$(CORE_TOP).sv $(CORE_CPP) -o $(CORE_TOP)

# Run an ELF or bin with the terminal connected to UART (not a test)
IMG    ?=
MEM_MB ?= 256

console: core
	@test -n "$(IMG)" || { echo "usage: make console IMG=<file> [CONFIG=$(CONFIG)] [MEM_MB=$(MEM_MB)]"; exit 1; }
	./$(CORE_BIN) $(if $(shell head -c 4 $(IMG) 2>/dev/null | grep -a ELF),--elf,--bin) $(IMG) \
		--mem-mb $(MEM_MB) --interactive

clean:
	rm -rf obj_dir_*

all: core

.PHONY: all core console clean
