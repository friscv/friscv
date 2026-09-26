# Pinned versions
LINUX_REPO   := https://github.com/torvalds/linux.git
LINUX_REF    := v7.1-rc2

OPENSBI_REPO := https://github.com/riscv-software-src/opensbi.git
OPENSBI_REF  := v1.8.1

TOYBOX_REPO  := https://github.com/landley/toybox.git
TOYBOX_REF   := 0.8.13

MUSL_REPO    := https://git.musl-libc.org/git/musl
MUSL_REF     := v1.2.5

LLVM_REPO    := https://github.com/llvm/llvm-project.git
LLVM_REF     := llvmorg-21.1.8

# Paths
SRCDIR       := $(CURDIR)/src
BUILDDIR     := $(CURDIR)/build
LINUX_DIR    ?= $(SRCDIR)/linux
OPENSBI_DIR  ?= $(SRCDIR)/opensbi
TOYBOX_DIR   ?= $(SRCDIR)/toybox
MUSL_DIR     ?= $(SRCDIR)/musl
MUSL_INSTALL := $(SRCDIR)/musl-install
LLVM_DIR     := $(SRCDIR)/llvm-project
ROOTFS_DIR   := $(BUILDDIR)/rootfs

# Toolchain
TARGET       := riscv32-unknown-linux-musl
ARCH_FLAGS   := -march=rv32ima -mabi=ilp32
LLVM_SUFFIX  ?=
LLVM         := $(if $(LLVM_SUFFIX),$(LLVM_SUFFIX),1)
HOSTCC       ?= cc
DTC          ?= $(LINUX_DIR)/scripts/dtc/dtc
NPROC        := $(shell nproc)

# Derived paths
TOYBOX_BIN   := $(TOYBOX_DIR)/toybox
INITRAMFS    := $(BUILDDIR)/initramfs.cpio.gz
LINUX_IMAGE  := $(LINUX_DIR)/arch/riscv/boot/Image
DTB          := $(BUILDDIR)/friscv.dtb
FW_BIN       := $(OPENSBI_DIR)/build/platform/generic/firmware/fw_payload.bin
FIRMWARE     := $(BUILDDIR)/fw_payload.bin
MUSL_LIBC    := $(MUSL_INSTALL)/lib/libc.a
RT_BUILTINS  := $(SRCDIR)/rt-builtins/libclang_rt.builtins.a

# Boot on the core sim
TARGET_SIM_ROOT := ../../target/sim
SIM_CONFIG      ?= full
SIM_MEM_MB      := 256
SIM_MAX_CYCLES  ?= 3000000000
SIM_PASS_STR    := FRISCV Linux booted successfully!

.PHONY: firmware toybox initramfs linux opensbi dtb musl compiler-rt run console clean distclean

firmware:    $(FIRMWARE)  # Keep this first (default target)
toybox:      $(TOYBOX_BIN)
initramfs:   $(INITRAMFS)
linux:       $(LINUX_IMAGE)
opensbi:     $(FW_BIN)
dtb:         $(DTB)
musl:        $(MUSL_LIBC)
compiler-rt: $(RT_BUILTINS)

# Clone sources

$(LINUX_DIR)/.git:
	git clone --depth 1 --branch $(LINUX_REF) $(LINUX_REPO) $(LINUX_DIR)

$(OPENSBI_DIR)/.git:
	git clone --depth 1 --branch $(OPENSBI_REF) $(OPENSBI_REPO) $(OPENSBI_DIR)

$(TOYBOX_DIR)/.git:
	git clone --depth 1 --branch $(TOYBOX_REF) $(TOYBOX_REPO) $(TOYBOX_DIR)

$(MUSL_DIR)/.git:
	git clone --depth 1 --branch $(MUSL_REF) $(MUSL_REPO) $(MUSL_DIR)

$(LLVM_DIR)/.git:
	git clone --filter=blob:none --sparse --depth 1 --branch $(LLVM_REF) $(LLVM_REPO) $(LLVM_DIR)
	cd $(LLVM_DIR) && git sparse-checkout set compiler-rt cmake

# compiler-rt builtins for rv32

$(RT_BUILTINS): $(LLVM_DIR)/.git
	cmake -S $(LLVM_DIR)/compiler-rt/lib/builtins -B $(SRCDIR)/rt-build \
		-DCMAKE_C_COMPILER=$(shell which clang$(LLVM_SUFFIX)) \
		-DCMAKE_C_COMPILER_TARGET=riscv32-unknown-elf \
		-DCMAKE_ASM_COMPILER=$(shell which clang$(LLVM_SUFFIX)) \
		-DCMAKE_ASM_COMPILER_TARGET=riscv32-unknown-elf \
		-DCMAKE_C_FLAGS="$(ARCH_FLAGS)" \
		-DCMAKE_ASM_FLAGS="$(ARCH_FLAGS)" \
		-DCMAKE_EXE_LINKER_FLAGS="-fuse-ld=lld$(LLVM_SUFFIX)" \
		-DCMAKE_AR=$(shell which llvm-ar$(LLVM_SUFFIX)) \
		-DCMAKE_NM=$(shell which llvm-nm$(LLVM_SUFFIX)) \
		-DCMAKE_RANLIB=$(shell which llvm-ranlib$(LLVM_SUFFIX)) \
		-DCMAKE_C_COMPILER_WORKS=1 \
		-DCMAKE_ASM_COMPILER_WORKS=1 \
		-DCMAKE_CXX_COMPILER_WORKS=1 \
		-DCOMPILER_RT_DEFAULT_TARGET_ONLY=ON \
		-DCOMPILER_RT_BAREMETAL_BUILD=ON
	cmake --build $(SRCDIR)/rt-build -j$(NPROC)
	mkdir -p $(dir $@)
	find $(SRCDIR)/rt-build -name 'libclang_rt.builtins*.a' -type f \
		-exec cp {} $@ \;

# musl libc

$(MUSL_LIBC): $(MUSL_DIR)/.git $(LINUX_DIR)/.git
	cd $(LINUX_DIR) && make ARCH=riscv HOSTCC=$(HOSTCC) INSTALL_HDR_PATH=$(MUSL_INSTALL) headers_install
	cd $(MUSL_DIR) && \
		CC="clang$(LLVM_SUFFIX) --target=$(TARGET) $(ARCH_FLAGS)" \
		AR=llvm-ar$(LLVM_SUFFIX) \
		RANLIB=llvm-ranlib$(LLVM_SUFFIX) \
		./configure \
			--target=riscv32-linux-musl \
			--prefix=$(MUSL_INSTALL) \
			--syslibdir=$(MUSL_INSTALL)/lib \
			--disable-shared \
			LDFLAGS="-fuse-ld=lld$(LLVM_SUFFIX)" && \
		make -j$(NPROC) && \
		make install-libs install-headers

# Device tree, compiled with the kernel's dtc

$(DTB): friscv.dts | $(LINUX_IMAGE)
	@mkdir -p $(dir $@)
	$(DTC) -I dts -O dtb -o $@ $<

# Toybox

$(TOYBOX_BIN): $(TOYBOX_DIR)/.git $(MUSL_LIBC) $(RT_BUILTINS)
	make -C $(TOYBOX_DIR) HOSTCC=$(HOSTCC) defconfig
	sed -i 's/.*CONFIG_SH .*/CONFIG_SH=y/' $(TOYBOX_DIR)/.config
	sed -i 's/.*CONFIG_INIT .*/CONFIG_INIT=y/' $(TOYBOX_DIR)/.config
	sed -i 's/.*CONFIG_MOUNT .*/CONFIG_MOUNT=y/' $(TOYBOX_DIR)/.config
	make -C $(TOYBOX_DIR) \
		HOSTCC=$(HOSTCC) \
		CC=clang$(LLVM_SUFFIX) \
		CFLAGS="--target=$(TARGET) $(ARCH_FLAGS) --sysroot=$(MUSL_INSTALL) -Oz" \
		LDFLAGS="-fuse-ld=lld$(LLVM_SUFFIX) -static -nostdlib \
			$(MUSL_INSTALL)/lib/crt1.o $(MUSL_INSTALL)/lib/crti.o \
			-L$(MUSL_INSTALL)/lib -lc $(RT_BUILTINS) $(MUSL_INSTALL)/lib/crtn.o" \
		STRIP=llvm-strip$(LLVM_SUFFIX) \
		-j$(NPROC)

# Initramfs

$(INITRAMFS): $(TOYBOX_BIN) init
	rm -rf $(ROOTFS_DIR)
	mkdir -p $(ROOTFS_DIR)/bin $(ROOTFS_DIR)/sbin $(ROOTFS_DIR)/etc \
		$(ROOTFS_DIR)/proc $(ROOTFS_DIR)/sys $(ROOTFS_DIR)/dev \
		$(ROOTFS_DIR)/tmp $(ROOTFS_DIR)/usr/bin $(ROOTFS_DIR)/usr/sbin
	install -m 755 $(TOYBOX_BIN) $(ROOTFS_DIR)/bin/toybox
	make -C $(TOYBOX_DIR) HOSTCC=$(HOSTCC) install PREFIX=$(ROOTFS_DIR)
	install -m 755 init $(ROOTFS_DIR)/init
	cd $(ROOTFS_DIR) && fakeroot -- sh -c \
		'mknod dev/console c 5 1 && chmod 600 dev/console && find . | cpio -o -H newc' \
		| gzip > $@

# Linux kernel

$(LINUX_IMAGE): $(LINUX_DIR)/.git $(INITRAMFS) friscv_defconfig
	cp friscv_defconfig $(LINUX_DIR)/arch/riscv/configs/friscv_defconfig
	cd $(LINUX_DIR) && \
		make ARCH=riscv LLVM=$(LLVM) HOSTCC=$(HOSTCC) friscv_defconfig && \
		./scripts/config --set-str CONFIG_INITRAMFS_SOURCE "$(INITRAMFS)" && \
		make ARCH=riscv LLVM=$(LLVM) HOSTCC=$(HOSTCC) olddefconfig && \
		make ARCH=riscv LLVM=$(LLVM) HOSTCC=$(HOSTCC) -j$(NPROC)

# OpenSBI

$(FW_BIN): $(OPENSBI_DIR)/.git $(LINUX_IMAGE) $(DTB)
	cd $(OPENSBI_DIR) && make \
		LLVM=$(LLVM) \
		PLATFORM=generic \
		PLATFORM_RISCV_XLEN=32 \
		PLATFORM_RISCV_ISA=rv32ima_zicsr_zifencei \
		FW_PAYLOAD=y \
		FW_PIC=n \
		FW_PAYLOAD_PATH=$(LINUX_IMAGE) \
		FW_FDT_PATH=$(DTB) \
		FW_FDT_PADDING=8192 \
		-j$(NPROC)

# Final firmware binary

$(FIRMWARE): $(FW_BIN)
	@mkdir -p $(dir $@)
	cp $< $@
	@echo "Firmware ready: $@"

# Boot the firmware on the core sim, pass when init prints its banner

run: $(FIRMWARE)
	$(MAKE) -C $(TARGET_SIM_ROOT) core CONFIG=$(SIM_CONFIG)
	$(TARGET_SIM_ROOT)/obj_dir_$(SIM_CONFIG)/friscv_cpu_verilator --bin $(FIRMWARE) \
		--mem-mb $(SIM_MEM_MB) --max-cycles $(SIM_MAX_CYCLES) \
		--pass-str "$(SIM_PASS_STR)" --fail-str "Kernel panic"

# Boot the firmware with the terminal on the UART

console: $(FIRMWARE)
	$(MAKE) -C $(TARGET_SIM_ROOT) console CONFIG=$(SIM_CONFIG) IMG=$(FIRMWARE) MEM_MB=$(SIM_MEM_MB)

# Clean

clean:
	rm -rf $(BUILDDIR)
	rm -rf $(SRCDIR)/rt-build $(SRCDIR)/rt-builtins
	-cd $(TOYBOX_DIR)  2>/dev/null && make distclean
	-cd $(LINUX_DIR)   2>/dev/null && make ARCH=riscv distclean
	-cd $(OPENSBI_DIR) 2>/dev/null && make distclean
	-cd $(MUSL_DIR)    2>/dev/null && make distclean

distclean: clean
	rm -rf $(SRCDIR)
