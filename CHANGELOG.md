<!-- markdownlint-disable MD024 -->

# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.0.0] - 2026-09-26

### Added

- Physical memory protection, set by `EnforcePmp`, `PmpEntries` and `PmpUsable`. 2.3.1 only had placeholder `pmpcfg` and `pmpaddr` registers.
- Debug support for an external RISC-V debug module: debug mode, `dcsr`, `dpc`, and the `DmBase`, `DmHaltOffset` and `DmExcOffset` parameters.
- RV32E, with `EnableIsaE`. RV32I stays the default.
- `EnableIsaM`, `EnableIsaA`, `EnableUMode`, `EnableSMode` and `EnableMmu`, so extensions, privilege modes and the MMU can be left out.
- `HartId`, `ResetVec`, `ItlbEntries`, `DtlbEntries`, `EnableFineTlbFlush`, `HaltOnEndAddress` and `HaltOnEnterEbreak` parameters.
- Bender package `friscv`. The simulation, the linters and the Vivado project take their file lists from `Bender.yml`.
- Verilator simulation of the core in `target/sim/`, with C++ models of memory, UART and CLINT. `make console` connects the terminal to the UART.
- Linux and apheleiaOS boot tests, `make run-linux` and `make run-aos`.
- Architecture tests run for several core configurations.
- `make lint`, running slang, Verilator, Yosys and the Xilinx target lint.
- CI runs the linters, the directed and architecture tests and the OS boots.
- Nix shell with every tool except Vivado, set up by `setup.sh`.

### Changed

- The ZSBL boot ROM is no longer part of the core. The PYNQ-Z2 SoC has it, and the core starts at `ResetVec`.
- The core is configured through parameters rather than `friscv_pkg`.
- Multiply and divide use one shared iterative unit. `EnableFastMul` brings back the fast multiplier.
- The core has one request/response memory port, `mem_req_o` and `mem_rsp_i`. Its types and bus adapters come from [friscv-mem-utils](https://github.com/friscv/friscv-mem-utils).
- Reorganized into the PULP layout: core RTL in `rtl/`, the PYNQ-Z2 reference SoC in `target/xilinx/pynq-z2/`, tests in `verif/`, example programs in `examples/`. `build.py` is replaced by `make` and `target/xilinx/pynq-z2/fpga.py`.
- The core follows the [lowRISC style guide](https://github.com/lowRISC/style-guides/blob/master/VerilogCodingStyle.md), and its files have no `timescale` and no file-level imports.
- The PMP check sits after `friscv_arbiter`.
- `wfi` is a no-op that waits in ID.
- `friscv_remap` takes its address map as module parameters. Its package is removed.

### Removed

- The `ENABLE_EARLY_JAL_JALR` option.

### Fixed

- An access fault from an instruction fetch that a redirect has already discarded no longer traps.
- An interrupt is no longer taken while an `mret`, `sret` or `dret` is in flight.
- A memory request is no longer translated again after the memory has taken it. An `sfence.vma` in between made the page walk read the request's own response as its PTE.
