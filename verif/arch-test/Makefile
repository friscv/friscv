ACT_ROOT := riscv-arch-test
ACT_REPO := https://github.com/riscv/riscv-arch-test.git
ACT_REF  := 5f69fff1851122eabe87233c08d6c4096dd0c5ac

# Test runs as <sim config>:<ACT config>
ACT_RUNS ?= full:full full-itermul:full embedded:embedded frisc:frisc

ACT_CONFIGS := $(sort $(foreach r,$(ACT_RUNS),$(word 2,$(subst :, ,$(r)))))

ACT_CONFIG_FILES := $(foreach c,$(ACT_CONFIGS),config/cores/friscv/friscv-$(c)/test_config.yaml)

ACT_EXCLUDE_EXTENSIONS ?= Sm,S,InterruptsSm,InterruptsS,InterruptsU,ExceptionsZalrsc,ExceptionsZaamo,Svade,Svadu,SvaduPMP,SvZicbo,SvPMPZicbo

UV_LINK_MODE ?= copy
JOBS ?= $(shell nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

.PHONY: act-clone
act-clone:
	@if [ ! -d $(ACT_ROOT)/.git ]; then            \
		git clone $(ACT_REPO) $(ACT_ROOT);         \
		cd $(ACT_ROOT) && git checkout $(ACT_REF); \
	fi

.PHONY: act-config
act-config: act-clone
	@for c in $(ACT_CONFIGS); do                                            \
		mkdir -p $(ACT_ROOT)/config/cores/friscv/friscv-$$c;                \
		cp config/friscv-$$c/* $(ACT_ROOT)/config/cores/friscv/friscv-$$c/; \
	done

.PHONY: act-build
act-build: act-config
	@for c in $(ACT_CONFIGS); do rm -rf $(ACT_ROOT)/work/friscv-$$c/build $(ACT_ROOT)/work/friscv-$$c/elfs; done
	cd $(ACT_ROOT) && mise install
	UV_LINK_MODE=$(UV_LINK_MODE) CONFIG_FILES="$(ACT_CONFIG_FILES)" EXCLUDE_EXTENSIONS=$(ACT_EXCLUDE_EXTENSIONS) $(MAKE) -C $(ACT_ROOT) --jobs $(JOBS)

TARGET_SIM_ROOT := ../../target/sim

# Runs every config, then fails if any of them failed
.PHONY: act-run
act-run:
	@failed="";                                                                                    \
	for r in $(ACT_RUNS); do                                                                       \
		sim=$${r%%:*}; act=$${r#*:};                                                               \
		$(MAKE) -C $(TARGET_SIM_ROOT) core CONFIG=$$sim || { failed="$$failed $$sim"; continue; }; \
		python3 $(TARGET_SIM_ROOT)/scripts/run.py $(ACT_ROOT)/work/friscv-$$act/elfs $$sim         \
			|| failed="$$failed $$sim";                                                            \
	done;                                                                                          \
	if [ -n "$$failed" ]; then echo "Failing configs:$$failed"; exit 1; fi
