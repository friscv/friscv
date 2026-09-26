# FRISC-V

FRISC-V is a 32-bit RISC-V core developed at [FER](https://www.fer.unizg.hr/en), University of Zagreb. It has a 5-stage in-order pipeline and can boot Linux. This repo also contains a reference SoC for the TUL PYNQ-Z2 board.

**ISA:** RV32I (or RV32E) + M (multiply/divide) + A (atomics) + Zicsr + Zifencei + Zicntr + Sstc + Sv32

> [!IMPORTANT]
> **Read all of the [documentation](#documentation) before changing anything.** Especially:
>
> - [CONTRIBUTING.md](CONTRIBUTING.md): how to use git here. All work goes into the `dev` branch, never directly into `main`.
> - [docs/TESTING.md](docs/TESTING.md): all tests must pass before you commit, and every new feature needs its own tests.
> - How not to destroy the Vivado project: never create files from inside Vivado, export the block design after every change, and recreate the project after switching branches. See [CONTRIBUTING.md](CONTRIBUTING.md#adding-new-rtl-files).

## Layout

| Path | Contents |
| ---- | -------- |
| `rtl/` | Core RTL. The top module is `friscv` (`rtl/friscv.sv`) |
| `target/sim/` | Verilator simulation of the core, with C++ models of memory, UART and CLINT |
| `target/xilinx/pynq-z2/` | Reference SoC for the PYNQ-Z2, see its [README](target/xilinx/pynq-z2/README.md) |
| `verif/` | Tests: directed tests, architecture tests, Linux and apheleiaOS boot |
| `examples/` | Small example programs (blink an LED, timer, interrupts) |

The core talks to memory through one request/response port (`mem_req_o`, `mem_rsp_i`). The types and bus adapters (for example to AXI4) come from [friscv-mem-utils](https://github.com/EmilPopovic/friscv-mem-utils), which [bender](https://github.com/pulp-platform/bender) fetches automatically.

## Setup

All tools are provided by a Nix shell. On Linux or WSL2, run once:

```bash
./setup.sh
```

This installs Nix and [nix-direnv](https://github.com/nix-community/nix-direnv). After `direnv allow`, tools are loaded every time you `cd` into the repo. Without direnv, run `nix develop` instead.

Vivado is not part of the Nix shell. You only need it for the FPGA, see the [PYNQ-Z2 README](target/xilinx/pynq-z2/README.md).

## Quick Start

Build a program and run it on the simulated core, with your terminal connected to the UART:

```bash
make -C verif/directed prog TEST=../../examples/blink_led
make console IMG=verif/directed/prog/prog.elf
```

Programs must be linked at `0x8000_0000`, the start of DRAM. `IMG` can be an ELF or a raw binary. Press `Ctrl-A x` to quit.

## Make Targets

Run from the repo root:

| Target | Description |
| ------ | ----------- |
| `make build-sim` | Build the Verilator model of the core |
| `make run-directed` | Run the directed tests |
| `make run-act` | Run the compliance tests (build them first with `make build-act`) |
| `make run-all` | Run all of the above |
| `make run-linux` | Build Linux and boot it on the simulated core |
| `make run-aos` | Build apheleiaOS and boot it on the simulated core |
| `make console IMG=FILE` | Run `FILE` with the terminal connected to the UART |
| `make -C verif/linux console` | Boot Linux with the terminal connected to the UART, so you can use its shell |
| `make -C verif/aos console` | Boot apheleiaOS with the terminal connected to the UART, so you can log in |
| `make lint` | Run all linters (slang, Verilator, Yosys, and the Xilinx target) |

## Documentation

| Document | Description |
| -------- | ----------- |
| [docs/TESTING.md](docs/TESTING.md) | Directed and architecture tests, simulation configurations |
| [docs/LINUX.md](docs/LINUX.md) | Building and booting Linux and apheleiaOS |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Git workflow, adding files, checklist before committing |
| [target/xilinx/pynq-z2/README.md](target/xilinx/pynq-z2/README.md) | Building the FPGA design, loading and running programs |
| [target/xilinx/pynq-z2/docs/QUICKSTART.md](target/xilinx/pynq-z2/docs/QUICKSTART.md) | Step by step: clone, bitstream, program, run on the board |
| [target/xilinx/pynq-z2/docs/BOOT.md](target/xilinx/pynq-z2/docs/BOOT.md) | Boot modes, ZSBL, QSPI flash |
| [target/xilinx/pynq-z2/docs/UART.md](target/xilinx/pynq-z2/docs/UART.md) | UART pinout, registers, host connection, C examples |

## License

Copyright 2026 FER, HPC Architecture and Application Research Center.

Unless otherwise noted, everything in this repository is licensed under the Solderpad Hardware License v2.1 (`Apache-2.0 WITH SHL-2.1`), see [LICENSE.md](LICENSE.md). As permitted by the license, you may at your option treat any of this work as licensed under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0) instead.
