#!/usr/bin/env python3
# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/

"""FRISC-V PYNQ-Z2 build and board flow.

Runs natively on Linux and Windows. Xilinx tools are found on PATH, or under
$XILINX_VIVADO/bin and $XILINX_VITIS/bin.

commands:
  project           create the Vivado project (build/vivado)
  bitstream         synthesize and implement, export to build/out, then generate BOOT.bin
  boot-bin          generate the FSBL and BOOT.bin from build/out/friscv.xsa
  program           program the FPGA over JTAG
  flash             write BOOT.bin to QSPI flash
  load --bin FILE   hold FRISC-V in reset and load FILE to DRAM (0x8000_0000)
  run               pulse the FRISC-V reset
  go [--bin FILE]   program, optionally load, then run (-t opens a serial terminal)
  status            print the start of DRAM
  open              open the project in the Vivado GUI
  export-bd         write the block design back to bd/design1.tcl
  zsbl-rom          regenerate src/friscv_zsbl_rom.sv from sw/zsbl.S (needs a RISC-V toolchain)
  clean             remove build/
"""

import argparse
import fnmatch
import os
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import NoReturn

TARGET_DIR = Path(__file__).resolve().parent
REPO_ROOT = TARGET_DIR.parents[2]
SCRIPTS_DIR = TARGET_DIR / "scripts"
BUILD_DIR = TARGET_DIR / "build"
PROJECT_NAME = "friscv-pynq-z2"
PROJECT_DIR = BUILD_DIR / "vivado"
PROJECT_XPR = PROJECT_DIR / f"{PROJECT_NAME}.xpr"
OUT_DIR = BUILD_DIR / "out"
SOURCES_TCL = BUILD_DIR / "sources.tcl"
BD_TCL = TARGET_DIR / "bd" / "design1.tcl"
# Source list and block design the project was created from
PROJECT_SOURCES_TCL = PROJECT_DIR / "sources.tcl"
PROJECT_BD_TCL = PROJECT_DIR / "design1.tcl"

BIT = OUT_DIR / "friscv.bit"
XSA = OUT_DIR / "friscv.xsa"
PS7_INIT = OUT_DIR / "ps7_init.tcl"
FSBL_ELF = OUT_DIR / "fsbl.elf"
BOOT_BIN = OUT_DIR / "BOOT.bin"

# AXI address of CPU address 0x8000_0000, see friscv_remap.sv
DRAM_AXI_BASE = "0x00100000"

BENDER_TARGETS = ["xilinx", "fpga", "synthesis"]


# Enables ANSI escape processing in the Windows console
if os.name == "nt":
    os.system("")


def _color(code: str):
    return lambda msg: f"\033[{code}m{msg}\033[0m" if sys.stdout.isatty() else msg


_cyan, _green, _yellow, _red, _grey = (_color(c) for c in ("36", "32", "33", "31", "90"))


def info(msg: str) -> None:
    print(_cyan(msg))


def section(msg: str) -> None:
    print(_green(f"\n=== {msg} ==="))


def warn(msg: str) -> None:
    print(_yellow(f"WARNING: {msg}"), file=sys.stderr)


def die(msg: str) -> NoReturn:
    print(_red(f"ERROR: {msg}"), file=sys.stderr)
    sys.exit(1)


def find_tool(name: str) -> str:
    """Resolve a tool to a full path. On Windows this also finds the .bat launchers Xilinx ships."""
    path = shutil.which(name)
    if path:
        return path
    for env in ("XILINX_VIVADO", "XILINX_VITIS"):
        if env in os.environ:
            path = shutil.which(name, path=str(Path(os.environ[env]) / "bin"))
            if path:
                return path
    die(f"{name} not found. Add the Vivado/Vitis bin directory to PATH or set XILINX_VIVADO/XILINX_VITIS.")


def run(cmd: list, check: bool = True, **kwargs) -> bool:
    cmd = [str(c) for c in cmd]
    print(_grey("  $ " + " ".join(cmd)))
    ok = subprocess.run(cmd, **kwargs).returncode == 0
    if check and not ok:
        die(f"{Path(cmd[0]).name} failed")
    return ok


def vivado(script: str, *args) -> None:
    cmd = [find_tool("vivado"), "-mode", "batch", "-nolog", "-nojournal", "-notrace",
           "-source", (SCRIPTS_DIR / script).as_posix()]
    if args:
        cmd += ["-tclargs", *[a.as_posix() if isinstance(a, Path) else a for a in args]]
    # Vivado drops .Xil/ and stray files in its working directory
    BUILD_DIR.mkdir(exist_ok=True)
    run(cmd, cwd=BUILD_DIR)


def xsdb(script: str, *args) -> None:
    if not PS7_INIT.exists():
        die(f"{PS7_INIT.name} not found, run 'bitstream' first")
    BUILD_DIR.mkdir(exist_ok=True)
    run([find_tool("xsdb"), (SCRIPTS_DIR / script).as_posix(), PS7_INIT.as_posix(),
         *[a.as_posix() if isinstance(a, Path) else a for a in args]], cwd=BUILD_DIR)


def require(path: Path, hint: str) -> None:
    if not path.exists():
        die(f"{path.relative_to(TARGET_DIR)} not found, run '{hint}' first")


def extract_from_xsa(pattern: str, dest: Path) -> bool:
    with zipfile.ZipFile(XSA) as z:
        names = [n for n in z.namelist() if fnmatch.fnmatch(Path(n).name, pattern)]
        if not names:
            return False
        dest.write_bytes(z.read(names[0]))
        return True


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_sources() -> None:
    """Generate the Vivado source list with bender."""
    bender = shutil.which("bender") or die("bender not found on PATH (https://github.com/pulp-platform/bender)")
    cmd = [bender, "-d", str(REPO_ROOT), "script", "vivado"]
    for t in BENDER_TARGETS:
        cmd += ["-t", t]
    print(_grey("  $ " + " ".join(cmd)))
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        die(f"bender failed:\n{result.stderr}")

    # bender emits `set ROOT "<native path>"`. Backslashes in a Windows path would be Tcl escapes.
    lines = result.stdout.splitlines()
    lines = [f"set ROOT {{{REPO_ROOT.as_posix()}}}" if l.startswith("set ROOT ") else l for l in lines]
    BUILD_DIR.mkdir(exist_ok=True)
    SOURCES_TCL.write_text("\n".join(lines) + "\n")


def cmd_project() -> None:
    section("CREATING VIVADO PROJECT")
    if PROJECT_DIR.exists():
        shutil.rmtree(PROJECT_DIR)
    cmd_sources()
    vivado("create_project.tcl", PROJECT_DIR, PROJECT_NAME, SOURCES_TCL)
    shutil.copy2(SOURCES_TCL, PROJECT_SOURCES_TCL)
    shutil.copy2(BD_TCL, PROJECT_BD_TCL)
    info(f"Project: {PROJECT_XPR}")


def project_stale() -> bool:
    """True if the source list or the block design changed since the project was created."""
    return any(not snap.exists() or snap.read_text() != cur.read_text()
               for snap, cur in ((PROJECT_SOURCES_TCL, SOURCES_TCL), (PROJECT_BD_TCL, BD_TCL)))


def cmd_bitstream(jobs: int, boot_bin: bool) -> None:
    if not PROJECT_XPR.exists():
        cmd_project()
    else:
        # The project only holds the files and block design it was created with. Recreate it when the source
        # list (added, removed or renamed files, bender updates) or bd/design1.tcl changes.
        cmd_sources()
        if project_stale():
            info("Source list or block design changed, recreating the project")
            cmd_project()

    section("BUILDING BITSTREAM")
    if OUT_DIR.exists():
        shutil.rmtree(OUT_DIR)
    vivado("build_bitstream.tcl", PROJECT_XPR, OUT_DIR, str(jobs))

    require(BIT, "bitstream")
    if not extract_from_xsa("ps7_init.tcl", PS7_INIT):
        die("ps7_init.tcl not found in the XSA")
    info(f"Outputs in {OUT_DIR}:")
    for f in sorted(OUT_DIR.iterdir()):
        if f.is_file():
            print(f"  {f.name:24} {f.stat().st_size / 1024:10.1f} KiB")

    if boot_bin:
        cmd_boot_bin(best_effort=True)


def cmd_boot_bin(best_effort: bool = False) -> None:
    section("GENERATING BOOT IMAGE")
    require(XSA, "bitstream")

    if best_effort and not (shutil.which("xsct") or os.environ.get("XILINX_VITIS")):
        warn("xsct not found, skipping BOOT.bin. Run 'boot-bin' once Vitis is on PATH.")
        return

    fsbl_dir = BUILD_DIR / "fsbl"
    if fsbl_dir.exists():
        shutil.rmtree(fsbl_dir)
    fsbl_dir.mkdir(parents=True)

    if not run([find_tool("xsct"), (SCRIPTS_DIR / "gen_fsbl.tcl").as_posix(), XSA.as_posix(), fsbl_dir.as_posix()],
               check=not best_effort, cwd=BUILD_DIR):
        warn("FSBL generation failed, BOOT.bin not generated")
        return

    elf = fsbl_dir / "executable.elf"
    if not elf.exists():
        (warn if best_effort else die)("FSBL build produced no executable.elf")
        return
    shutil.copy2(elf, FSBL_ELF)

    bif = BUILD_DIR / "boot.bif"
    bif.write_text(f"the_ROM_image:\n{{\n  [bootloader] {FSBL_ELF.as_posix()}\n  {BIT.as_posix()}\n}}\n")
    run([find_tool("bootgen"), "-arch", "zynq", "-image", bif, "-o", BOOT_BIN, "-w"], cwd=BUILD_DIR)
    info(f"BOOT.bin: {BOOT_BIN}")


def cmd_program() -> None:
    section("PROGRAMMING FPGA")
    require(BIT, "bitstream")
    xsdb("init_ps.tcl")
    vivado("program_fpga.tcl", BIT)


def cmd_flash() -> None:
    section("FLASHING QSPI")
    require(BOOT_BIN, "boot-bin")
    require(FSBL_ELF, "boot-bin")
    run([find_tool("program_flash"), "-f", BOOT_BIN, "-offset", "0", "-flash_type", "qspi-x4-single",
         "-fsbl", FSBL_ELF, "-url", "TCP:localhost:3121", "-verify"], cwd=BUILD_DIR)


def cmd_load(prog: Path) -> None:
    section(f"LOADING {prog.name}")
    if not prog.exists():
        die(f"{prog} not found")
    xsdb("load_program.tcl", prog.resolve(), DRAM_AXI_BASE)


def cmd_run() -> None:
    section("RELEASING RESET")
    xsdb("release_reset.tcl")


def cmd_go(prog: Path | None, terminal: bool, port: str, baud: int) -> None:
    cmd_program()
    if prog:
        cmd_load(prog)
    if not terminal:
        cmd_run()
        return

    try:
        import serial
    except ImportError:
        die("pyserial not installed, run: pip install pyserial")
    sys.path.insert(0, str(SCRIPTS_DIR))
    import xmodem_load

    with serial.Serial(port, baud, timeout=0.1) as ser:
        ser.reset_input_buffer()
        cmd_run()
        xmodem_load.open_terminal(ser)


def cmd_status() -> None:
    xsdb("check_status.tcl")


def cmd_open() -> None:
    if not PROJECT_XPR.exists():
        cmd_project()
    cmd = [find_tool("vivado"), "-mode", "gui", "-nolog", "-nojournal", str(PROJECT_XPR)]
    info(f"Opening {PROJECT_XPR}")
    if os.name == "nt":
        flags = subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP  # type: ignore[attr-defined]
        subprocess.Popen(cmd, cwd=BUILD_DIR, creationflags=flags)
    else:
        subprocess.Popen(cmd, cwd=BUILD_DIR, start_new_session=True)


def cmd_export_bd() -> None:
    section("EXPORTING BLOCK DESIGN")
    require(PROJECT_XPR, "project")
    vivado("export_bd.tcl", PROJECT_XPR)
    # The project already matches the exported block design
    shutil.copy2(BD_TCL, PROJECT_BD_TCL)


def cmd_zsbl_rom(sim: bool) -> None:
    section("GENERATING ZSBL ROM")
    cmd = [sys.executable, SCRIPTS_DIR / "gen_zsbl_rom.py", TARGET_DIR / "sw" / "zsbl.S",
           TARGET_DIR / "src" / "friscv_zsbl_rom.sv", "--linker-script", TARGET_DIR / "sw" / "zsbl.ld"]
    if sim:
        cmd.append("--sim")
    run(cmd)


def cmd_clean() -> None:
    if BUILD_DIR.exists():
        try:
            shutil.rmtree(BUILD_DIR)
        except PermissionError as e:
            die(f"cannot delete {e.filename}, close Vivado and try again")
    info("Removed build/")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True, metavar="command")

    sub.add_parser("project")
    p = sub.add_parser("bitstream")
    p.add_argument("-j", "--jobs", type=int, default=max(1, (os.cpu_count() or 4) - 2))
    p.add_argument("--no-boot-bin", action="store_true", help="skip FSBL and BOOT.bin generation")
    sub.add_parser("boot-bin")
    sub.add_parser("program")
    sub.add_parser("flash")
    p = sub.add_parser("load")
    p.add_argument("--bin", type=Path, required=True)
    sub.add_parser("run")
    p = sub.add_parser("go")
    p.add_argument("--bin", type=Path)
    p.add_argument("-t", "--terminal", action="store_true", help="open a serial terminal after reset")
    p.add_argument("-p", "--port", default="COM3" if os.name == "nt" else "/dev/ttyUSB0")
    p.add_argument("-b", "--baud", type=int, default=115200)
    sub.add_parser("status")
    sub.add_parser("open")
    sub.add_parser("export-bd")
    p = sub.add_parser("zsbl-rom")
    p.add_argument("--sim", action="store_true", help="assemble with SIMULATION=1")
    sub.add_parser("clean")

    args = parser.parse_args()
    match args.command:
        case "project":   cmd_project()
        case "bitstream": cmd_bitstream(args.jobs, not args.no_boot_bin)
        case "boot-bin":  cmd_boot_bin()
        case "program":   cmd_program()
        case "flash":     cmd_flash()
        case "load":      cmd_load(args.bin)
        case "run":       cmd_run()
        case "go":        cmd_go(args.bin, args.terminal, args.port, args.baud)
        case "status":    cmd_status()
        case "open":      cmd_open()
        case "export-bd": cmd_export_bd()
        case "zsbl-rom":  cmd_zsbl_rom(args.sim)
        case "clean":     cmd_clean()


if __name__ == "__main__":
    main()
