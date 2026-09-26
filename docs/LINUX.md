# Linux Firmware Build

`verif/linux/` builds a complete Linux firmware image for FRISC-V. The output is a single binary that can be loaded and run like any other program.

## Dependencies

All dependencies (LLVM/clang 21, CMake, `fakeroot`, `cpio`, ...) are in the Nix shell. For a smaller shell with only what the OS builds need, run `nix develop .#os`.

## Build

```bash
make build-linux
```

On the first run this clones the sources (Linux, OpenSBI, toybox, musl, LLVM compiler-rt) into `verif/linux/src/`. Later builds are incremental.

The build chain is: compiler-rt + musl, toybox, initramfs, Linux kernel, OpenSBI. The result is `verif/linux/build/fw_payload.bin`.

To clean build artifacts without removing cloned sources:

```bash
make -C verif/linux clean
```

To remove everything including cloned sources:

```bash
make -C verif/linux distclean
```

## Run in Simulation

```bash
make run-linux               # boot, pass when init prints its banner
make -C verif/linux console  # boot with the terminal connected to the UART
```

Expected output: OpenSBI banner, Linux boot log, then:

```text
FRISCV Linux booted successfully!
```

followed by a shell prompt.

## Device Tree

`verif/linux/friscv.dts` describes the SoC hardware for Linux. It is compiled to `verif/linux/build/friscv.dtb` during the build.

Key nodes:

| Node | Address | Description |
| ---- | ------- | ----------- |
| `memory` | `0x80000000` | 256 MB DDR |
| `clint` | `0x02000000` | Timer and software interrupts |
| `serial` | `0x10000000` | 16550 UART |

After changing `friscv.dts`, run `make build-linux` again.

## apheleiaOS

[apheleiaOS](https://github.com/cappig/apheleiaOS) is a small hobby OS that also boots on FRISC-V. `verif/aos/` clones it into `verif/aos/apheleiaOS/` and applies the patches from `verif/aos/patches/`.

```bash
make run-aos               # boot, pass on the login prompt
make -C verif/aos console  # boot with the terminal connected to the UART
```
