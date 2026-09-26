# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# SV32 Paging Integration Test
#
# Tests ITLB and DTLB translation via the Page Table Walker:
#   - S-mode instruction fetch through ITLB (csrw satp, sfence.vma, mret)
#   - S-mode data load through DTLB
#
# Physical memory layout:
#   0x80000000: M-mode code
#   0x80001000: L1 page table
#   0x80002000: L0 page table
#   0x80003000: S-mode code
#   0x80004000: S-mode data
#
# Virtual address mapping (SV32, VPN[1]=1):
#   VA 0x00400000 -> PA 0x80003000 (code, R+X+A+V)
#   VA 0x00401000 -> PA 0x80004000 (data, R+W+D+A+V)

.option arch, +zicsr
.text
.globl _start

_start:
    lui  x30, 0x40000          # GPIO address = 0x40000000

    li   t0, 0xFFFFFFFF      # NAPOT covering the whole address space
    csrw pmpaddr0, t0
    li   t0, 0x1F            # L=0, A=NAPOT, X=1, W=1, R=1
    csrw pmpcfg0, t0

    csrw mie, x0               # disable all interrupts
    j    main_start

# ================================================================
# M-MODE TRAP HANDLER
# ================================================================
# Expects S-mode ecall (mcause=9).
# x10 = value loaded by S-mode from the virtual data page.
m_handler:
    csrr x1, mcause
    li   x2, 9                 # S-mode ecall
    bne  x1, x2, test_fail

    # Verify S-mode loaded the magic value through DTLB
    li   x2, 0x12345678
    bne  x10, x2, test_fail
    j    all_tests_pass

# ================================================================
main_start:

    # Set M-mode trap vector
    la   x1, m_handler
    csrw mtvec, x1

    # ============================================================
    # Build SV32 page tables
    # ============================================================

    # L1 page table at PA 0x80001000
    # PTE = (0x80002 << 10) | V = 0x20000801
    lui  x1, 0x80001           # L1 base
    li   x2, 0x20000801
    sw   x2, 4(x1)

    # L0 page table at PA 0x80002000
    # L0[0]: leaf code page, PPN=0x80003, perm = A+X+R+V = 0x4B
    # PTE = (0x80003 << 10) | 0x4B = 0x20000C4B
    lui  x3, 0x80002           # L0 base
    li   x4, 0x20000C4B
    sw   x4, 0(x3)             # L0[0]

    # L0[1]: leaf data page, PPN=0x80004, perm = D+A+W+R+V = 0xC7
    # PTE = (0x80004 << 10) | 0xC7 = 0x200010C7
    lui  x5, 0x20001
    addi x5, x5, 0xC7          # x5 = 0x200010C7
    sw   x5, 4(x3)             # L0[1]

    # Write magic value to data page at PA 0x80004000
    lui  x6, 0x80004
    li   x7, 0x12345678
    sw   x7, 0(x6)

    # Enable SV32 paging
    # satp = {mode=1(SV32), asid=0, ppn=0x80001}
    li  x1, 0x80080001
    csrw satp, x1

    # Flush TLB
    sfence.vma

    # Enter S-mode at virtual address
    li   x1, 0x800
    csrw mstatus, x1

    # mepc = VA 0x00400000 (S-mode code entry)
    lui  x1, 0x00400
    csrw mepc, x1

    # mret: privilege -> S-mode, PC -> 0x00400000
    # IF will fetch through ITLB (miss -> PTW -> L1[1] -> L0[0] -> fill)
    mret

# ================================================================
all_tests_pass:
    li   x1, 0xAABBCCDD
    sw   x1, 0(x30)
    j    end_program

test_fail:
    li   x1, 0xBADC0DE
    sw   x1, 0(x30)

end_program:
    lui  x10, 0x50000
    sw   x0, 0(x10)

# ================================================================
# S-mode code at PA 0x80003000 (offset 0x3000 from .text start)
# Runs at VA 0x00400000 after mret with paging enabled
# ================================================================
.org 0x3000
s_code:
    # Load magic value from VA 0x00401000 (DTLB miss -> page walk)
    lui  x8, 0x00401
    lw   x10, 0(x8)            # x10 = mem[VA 0x00401000] = 0x12345678

    # Return to M-mode
    ecall

.data
