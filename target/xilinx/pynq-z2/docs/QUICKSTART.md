# FRISC-V Quick-Start Guide

This guide walks through the full workflow from a fresh clone to running a program on the PYNQ-Z2.

## 1. Prerequisites

- **Vivado 2025.2** on `PATH` (source `settings64.sh` on Linux or `settings64.bat` on Windows)
- **Python 3.10+**, and `pip install pyserial` for the serial terminal
- **[bender](https://github.com/pulp-platform/bender)** on `PATH`
- **`riscv64-unknown-elf` toolchain** + `make` to build programs (Linux or WSL2 on Windows)
- PYNQ-Z2 board connected via USB (JTAG), and the I/O board's USB-to-UART bridge for the serial output (see [UART.md](UART.md))

On Linux, the Nix shell from the [repo setup](../../../../README.md#setup) provides everything except Vivado.

Verify Vivado is on PATH:

```bash
vivado -version
```

## 2. Clone and Build the Bitstream

```bash
git clone https://github.com/friscv/friscv.git
cd friscv/target/xilinx/pynq-z2
python3 fpga.py bitstream
```

This creates the Vivado project in `build/vivado/` and builds the bitstream into `build/out/`. It takes a while. You only need to do this again after changing the RTL or the block design.

To open the project in the GUI afterwards:

```bash
python3 fpga.py open
```

## 3. Build a Program

Programs are assembled from `.S` files. This step requires the RISC-V toolchain. On Windows, run this inside WSL2. From the repo root:

```bash
make -C verif/directed prog TEST=../../examples/blink_led
```

Output files: `verif/directed/prog/prog.bin` (raw binary), `prog.elf`, `prog.dis` (disassembly).

## 4. Program, Load, and Run

Make sure the board is powered on, the USB cable is connected, and both switches (`SW0`, `SW1`) are down (boot mode 0, see [BOOT.md](BOOT.md)). From `target/xilinx/pynq-z2/`:

```bash
python3 fpga.py go --bin ../../../verif/directed/prog/prog.bin
```

This is equivalent to running these three steps individually:

```bash
python3 fpga.py program             # load friscv.bit into the FPGA
python3 fpga.py load --bin prog.bin # write prog.bin to DDR via XSDB
python3 fpga.py run                 # release FRISC-V from reset, program starts
```

To open a serial terminal immediately after run:

```bash
python3 fpga.py go --bin prog.bin -t
```

## 4a. Running Without Hardware

If you don't have a board, you can run the same program on the simulated core. From the repo root:

```bash
make console IMG=verif/directed/prog/prog.elf
```

See [TESTING.md](../../../../docs/TESTING.md) for running the tests.

## 5. Observe Output (UART)

The ZSBL prints a boot message over UART at **115200 8N1** before handing off to the loaded program. Connect with any serial terminal:

```bash
# Linux
screen /dev/ttyUSB0 115200  # Or ttyUSB1/2/...

# Windows (PowerShell)
# Use PuTTY, TeraTerm, or: python -m serial.tools.miniterm COM3 115200
```

Expected output on boot:

```text
[ZSBL] Ready
[ZSBL] Mode: DRAM
```

## 6. UART Boot Mode (No JTAG Needed)

Set **SW0 = 1, SW1 = 0** before releasing reset to enter UART boot mode. The bootloader will wait for a binary over Xmodem-CRC:

```bash
python3 scripts/xmodem_load.py --bin prog.bin --port /dev/ttyUSB0
# Windows: --port COM3
```

The ZSBL prints `[ZSBL] Mode: UART` and starts the transfer automatically. The program executes immediately after the transfer completes.

## 7. Flash to QSPI (Optional)

To have the board program itself on power-on without JTAG, write the boot image to QSPI flash. This needs Vitis:

```bash
python3 fpga.py flash
```

See [BOOT.md](BOOT.md#qspi-flash-boot) for jumper settings and details.

## Command Reference

```text
python3 fpga.py project              # create Vivado project
python3 fpga.py open                 # open project in Vivado GUI
python3 fpga.py bitstream            # build → build/out/friscv.bit
python3 fpga.py program              # program FPGA via JTAG
python3 fpga.py load --bin FILE      # load binary to DDR via XSDB
python3 fpga.py run                  # release FRISC-V from reset
python3 fpga.py go [--bin FILE] [-t] # program + load + run
python3 fpga.py status               # print the first words of DRAM
python3 fpga.py zsbl-rom             # regenerate boot ROM
python3 fpga.py clean                # remove build/
python3 fpga.py -h                   # full usage
```
