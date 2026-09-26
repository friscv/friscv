#!/usr/bin/env python3
# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Matej Jurasic <matej.jurasic@cappig.dev>
# Emil Popovic <mail@emilpopovic.me>

import subprocess
import sys
from pathlib import Path

SIM_ROOT = Path(__file__).resolve().parent.parent


def red(s) -> str:   return f"\033[91m{s}\033[00m"
def green(s) -> str: return f"\033[92m{s}\033[00m"


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        print(f"usage: {sys.argv[0]} <elf directory> [config]", file=sys.stderr)
        sys.exit(1)

    config = sys.argv[2] if len(sys.argv) == 3 else "full"
    executable = SIM_ROOT / f"obj_dir_{config}" / "friscv_cpu_verilator"

    if not executable.exists():
        print("Executable not found.")
        print("Build by running")
        print(f"  make -C target/sim core CONFIG={config}")
        sys.exit(1)

    elfs_dir = Path(sys.argv[1])
    elfs = sorted(elfs_dir.rglob("*.elf")) if elfs_dir.exists() else []
    print(f"Found {len(elfs)} elfs in {elfs_dir} (config {config})")

    if not elfs:
        sys.exit(1)

    passed = 0

    for elf in elfs:
        result = subprocess.run(
            [executable, "--elf", elf, "--check-pass", "--wait-cycles", "-2"],
            capture_output=True,
            text=True,
            check=False,
        )

        if result.returncode == 0 and "PASS" in result.stderr:
            print(f"{green('PASS')} {elf.stem}")
            passed += 1
        else:
            print(f"{red('FAIL')} {elf.stem}")

    print()
    print(f"Passed {passed}/{len(elfs)} tests (config {config})")

    if passed != len(elfs):
        sys.exit(1)
