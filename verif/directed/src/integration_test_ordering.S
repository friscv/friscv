# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# Paging / Ordering Integration Test
#
# Verifies the ordering boundaries around a translation-context switch:
#   1. A physical store immediately before csrw satp still commits physically.
#   2. csrw satp -> sfence.vma -> mret reaches S-mode at a virtual PC.
#   3. A virtual load and a back-to-back virtual store both retire before a
#      following synchronous trap (ecall) is handled.
#
# Physical memory layout:
#   0x80001000: L1 page table
#   0x80002000: L0 page table
#   0x80003000: S-mode code
#   0x80004000: Virtual load source
#   0x80005000: Physical-only sentinel store
#   0x80006000: Virtual store target
#
# Virtual mapping:
#   0x00400000 -> 0x80003000  (code, R+X+A+V)
#   0x00401000 -> 0x80004000  (data, R+W+D+A+V)
#   0x00402000 -> 0x80006000  (data, R+W+D+A+V)

.option arch, +zicsr
.text
.globl _start

_start:
    li   x31, 0x80000800       # checkpoint base = 0x80000800
    lui  x30, 0x40000          # GPIO = 0x40000000

    li   t0, 0xFFFFFFFF      # NAPOT covering the whole address space
    csrw pmpaddr0, t0
    li   t0, 0x1F            # L=0, A=NAPOT, X=1, W=1, R=1
    csrw pmpcfg0, t0

    csrw mie, x0
    j    main_start

# ================================================================
# M-mode trap handler
# Expects an S-mode ECALL after the ordered virtual load/store pair.
# ================================================================
m_handler:
    csrr x1, mcause
    li   x2, 9                 # S-mode ecall
    bne  x1, x2, test_fail

    li   x2, 0x12345678        # value loaded through the DTLB
    bne  x10, x2, test_fail
    sw   x10, 0(x31)

    lui  x3, 0x80005           # physical sentinel store, done before satp
    lw   x4, 0(x3)
    li   x5, 0x13579bdf
    bne  x4, x5, test_fail
    sw   x4, 4(x31)

    lui  x3, 0x80006           # value stored through the DTLB before ecall
    lw   x4, 0(x3)
    li   x5, 0x89abcdef
    bne  x4, x5, test_fail
    sw   x4, 8(x31)

    li   x6, 1
    sw   x6, 12(x31)           # handler reached exactly after ordered pair
    j    all_tests_pass

# ================================================================
main_start:
    la   x1, m_handler
    csrw mtvec, x1

    # L1 page table at PA 0x80001000
    # VPN[1] = 1 -> next level at PA 0x80002000
    lui  x1, 0x80001
    li   x2, 0x20000801
    sw   x2, 4(x1)

    # L0 page table at PA 0x80002000
    lui  x3, 0x80002

    # L0[0]: code page at PA 0x80003000, R+X+A+V
    li   x4, 0x20000c4b
    sw   x4, 0(x3)

    # L0[1]: load source at PA 0x80004000, R+W+D+A+V
    li   x4, 0x200010c7
    sw   x4, 4(x3)

    # L0[2]: store target at PA 0x80006000, R+W+D+A+V
    li   x4, 0x200018c7
    sw   x4, 8(x3)

    # Seed the translated data pages
    lui  x6, 0x80004
    li   x7, 0x12345678
    sw   x7, 0(x6)

    lui  x6, 0x80006
    sw   x0, 0(x6)

    # Physical store immediately before the translation context switch
    lui  x6, 0x80005
    li   x7, 0x13579bdf
    sw   x7, 0(x6)

    # Enable SV32 paging: satp = {mode=1, asid=0, ppn=0x80001}
    li   x1, 0x80080001
    csrw satp, x1
    sfence.vma

    # Drop to S-mode at VA 0x00400000
    li   x1, 0x800
    csrw mstatus, x1

    lui  x1, 0x00400
    csrw mepc, x1
    mret

# ================================================================
all_tests_pass:
    li   x1, 0xAABBCCDD
    sw   x1, 0(x30)
    j    end_program

test_fail:
    li   x1, 0x0BADC0DE
    sw   x1, 0(x30)

end_program:
    lui  x10, 0x50000
    sw   x0, 0(x10)

# ================================================================
# S-mode code at PA 0x80003000 / VA 0x00400000
# ================================================================
.org 0x3000
s_code:
    lui  x8, 0x00401
    lw   x10, 0(x8)            # ordered virtual load

    lui  x9, 0x00402
    li   x11, 0x89abcdef
    sw   x11, 0(x9)            # ordered virtual store

    ecall                      # handler must observe both operations complete

.data
