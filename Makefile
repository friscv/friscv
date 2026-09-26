# Make flist
sources.f: Bender.yml Bender.lock
	rm sources.f || true
	bender script flist-plus -t rtl -t synthesis > $@

#################
# Build targets #
#################

.PHONY: build-act
build-act:
	$(MAKE) -C verif/arch-test act-build

.PHONY: build-directed
build-directed:
	$(MAKE) -C verif/directed

.PHONY: build-sim
build-sim:
	$(MAKE) -C target/sim core

.PHONY: build-linux
build-linux:
	$(MAKE) -C verif/linux firmware

.PHONY: build-aos
build-aos:
	$(MAKE) -C verif/aos build

#############
# Run tests #
#############

.PHONY: run-act
run-act:
	$(MAKE) -C verif/arch-test act-run

.PHONY: run-directed
run-directed:
	$(MAKE) -C verif/directed run

# Run ELF or bin on the core sim connected to a terminal
.PHONY: console
console:
	$(MAKE) -C target/sim console IMG=$(abspath $(IMG))

# OS boots on the core sim
.PHONY: run-linux
run-linux:
	$(MAKE) -C verif/linux run

.PHONY: run-aos
run-aos:
	$(MAKE) -C verif/aos run

.PHONY: run-all
run-all:
	@status=0;                          \
	$(MAKE) run-act      || status=1;   \
	$(MAKE) run-directed || status=1;   \
	exit $$status

################
# Lint targets #
################

SLANG_SUPPRESS := .bender/...,rtl/vendored/...

SLANG_LINT_FLAGS := --top friscv --timescale 1ns/1ps      \
                    -Wno-duplicate-definition             \
					-Wno-case-redundant-default           \
                    --suppress-warnings $(SLANG_SUPPRESS) \
                    -Weverything -Werror

VERILATOR_LINT_FLAGS := --lint-only --top-module friscv +define+ASSERTS_OFF

YOSYS_LINT_LOG := yosys_lint.log

.PHONY: lint
lint: lint-slang lint-verilator lint-yosys lint-xilinx

.PHONY: lint-slang
lint-slang: sources.f
	slang -f sources.f $(SLANG_LINT_FLAGS)

YOSYS_LINT_ALLOW := 

.PHONY: lint-yosys
lint-yosys: sources.f
	@yosys -p "read_slang -F sources.f --top friscv -Wno-unknown-warning-option; \
	           hierarchy -check -top friscv" > $(YOSYS_LINT_LOG) 2>&1            \
	    || { tail -20 $(YOSYS_LINT_LOG); exit 1; }
	@if grep 'warning:' $(YOSYS_LINT_LOG) | grep '^rtl/' | grep -vE '$(YOSYS_LINT_ALLOW)' > /dev/null; then \
	    echo 'synthesis warnings in rtl/:';                                                                 \
	    grep 'warning:' $(YOSYS_LINT_LOG) | grep '^rtl/' | grep -vE '$(YOSYS_LINT_ALLOW)';                  \
	    exit 1;                                                                                             \
	fi
	@echo 'lint-yosys: no synthesis warnings in rtl/'

.PHONY: lint-verilator
lint-verilator: sources.f
	verilator $(VERILATOR_LINT_FLAGS) verilator_lint.vlt -f sources.f

.PHONY: lint-xilinx
lint-xilinx:
	$(MAKE) -C target/xilinx/pynq-z2 lint
