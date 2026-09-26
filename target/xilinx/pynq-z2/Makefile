# Wrapper around fpga.py: `make <command>` runs `fpga.py <command>`.
# Options are passed as variables:
#   make bitstream JOBS=8 NO_BOOT_BIN=1
#   make load BIN=prog.bin
#   make go BIN=prog.bin TERMINAL=1 PORT=/dev/ttyUSB1 BAUD=115200
#   make zsbl-rom SIM=1
# ARGS is appended as written for everything else.

PYTHON ?= python3
FPGA   := $(PYTHON) $(CURDIR)/fpga.py

JOBS        ?=
NO_BOOT_BIN ?=
BIN         ?=
TERMINAL    ?=
PORT        ?=
BAUD        ?=
SIM         ?=
ARGS        ?=

COMMANDS := project bitstream boot-bin program flash load run go status open export-bd zsbl-rom clean

bin_arg = $(if $(BIN),--bin $(BIN))

args_bitstream = $(if $(JOBS),-j $(JOBS)) $(if $(NO_BOOT_BIN),--no-boot-bin)
args_load      = $(bin_arg)
args_go        = $(bin_arg) $(if $(TERMINAL),-t) $(if $(PORT),-p $(PORT)) $(if $(BAUD),-b $(BAUD))
args_zsbl-rom  = $(if $(SIM),--sim)

$(COMMANDS):
	$(FPGA) $@ $(args_$@) $(ARGS)

help:
	@$(FPGA) --help

################
# Lint targets #
################

ROOT := $(abspath ../../..)

LINT_TOPS := friscv_axi_wrap friscv_clint debounce

LINT_F := build/lint.f

comma := ,
empty :=
space := $(empty) $(empty)

SLANG_LINT_FLAGS := --top $(subst $(space),$(comma),$(LINT_TOPS)) --timescale 1ns/1ps \
                    -Wno-duplicate-definition                                         \
                    -Wno-case-redundant-default                                       \
                    --suppress-warnings $(ROOT)/.bender/...,$(ROOT)/rtl/...           \
                    -Weverything -Werror

VERILATOR_LINT_FLAGS := --lint-only -Wall +define+ASSERTS_OFF

$(LINT_F): $(ROOT)/Bender.yml $(ROOT)/Bender.lock
	@mkdir -p $(@D)
	bender -d $(ROOT) script flist-plus -t xilinx -t fpga -t synthesis > $@

lint: lint-slang lint-verilator

lint-slang: $(LINT_F)
	slang -f $(LINT_F) $(SLANG_LINT_FLAGS)

LINT_VERILATOR_TARGETS := $(addprefix lint-verilator-,$(LINT_TOPS))

lint-verilator: $(LINT_VERILATOR_TARGETS)

$(LINT_VERILATOR_TARGETS): lint-verilator-%: $(LINT_F)
	verilator $(VERILATOR_LINT_FLAGS) --top-module $* verilator_lint.vlt -f $(LINT_F)

.PHONY: $(COMMANDS) help lint lint-slang lint-verilator $(LINT_VERILATOR_TARGETS)
