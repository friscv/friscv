AOS_REPO := https://github.com/cappig/apheleiaOS.git
AOS_REF  := 774a1f57f0cb7ee911bde35316129b20af4b2bba
AOS_ROOT := apheleiaOS
# Applied to AOS_REF
AOS_PATCHES := $(sort $(wildcard $(CURDIR)/patches/*.patch))

AOS_BUILD_FLAGS := ARCH=riscv_32 TOOLCHAIN=llvm RISCV_FRISC=true LIBGCC_FALLBACK_CC=
JOBS ?= $(shell nproc 2>/dev/null || echo 4)

# Boot on the core sim
TARGET_SIM_ROOT := ../../target/sim
SIM_CONFIG      ?= full
SIM_MEM_MB      := 256
SIM_MAX_CYCLES  ?= 1000000000
SIM_PASS_STR    := login:

AOS_IMAGE = $(firstword $(filter-out %.rootfs.img,$(wildcard $(AOS_ROOT)/bin/apheleia_*_riscv_32.img)))

.PHONY: all clone build run console clean distclean

all: build

# Skip already applied patches
clone:
	@if [ ! -d $(AOS_ROOT)/.git ]; then            \
		git clone $(AOS_REPO) $(AOS_ROOT);         \
		cd $(AOS_ROOT) && git checkout $(AOS_REF); \
	fi
	@for p in $(AOS_PATCHES); do                                                          \
		if git -C $(AOS_ROOT) apply --reverse --check $$p 2>/dev/null; then continue; fi; \
		echo "Applying $$(basename $$p)";                                                 \
		git -C $(AOS_ROOT) apply $$p || exit 1;                                           \
	done

build: clone
	$(MAKE) -C $(AOS_ROOT) all $(AOS_BUILD_FLAGS) -j$(JOBS)

run: build
	$(MAKE) -C $(TARGET_SIM_ROOT) core CONFIG=$(SIM_CONFIG)
	$(TARGET_SIM_ROOT)/obj_dir_$(SIM_CONFIG)/friscv_cpu_verilator --bin $(AOS_IMAGE) \
		--mem-mb $(SIM_MEM_MB) --max-cycles $(SIM_MAX_CYCLES) \
		--pass-str "$(SIM_PASS_STR)" --fail-str "kernel panic" --fail-str "fatal"

console: build
	$(MAKE) -C $(TARGET_SIM_ROOT) console CONFIG=$(SIM_CONFIG) IMG=$(abspath $(AOS_IMAGE)) MEM_MB=$(SIM_MEM_MB)

clean:
	-$(MAKE) -C $(AOS_ROOT) clean $(AOS_BUILD_FLAGS)

distclean:
	rm -rf $(AOS_ROOT)
