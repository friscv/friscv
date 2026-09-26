# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

.option arch, +zicsr
.text
.globl _start

_start:
    lui  x30, 0x40000          # GPIO result address
    csrw mie, x0               # disable interrupts

    # PMP: entry0 deny-W on data page, entry1 permit-all
    li   x1, 0x200011FF        # NAPOT 4KB @ 0x80004000
    csrw pmpaddr0, x1
    li   x1, 0xFFFFFFFF        # NAPOT whole space
    csrw pmpaddr1, x1
    li   x1, 0x00001F19        # cfg1=0x1F (RWX), cfg0=0x19 (R, NAPOT, no W)
    csrw pmpcfg0, x1

    la   x1, m_handler
    csrw mtvec, x1

    # sentinel at PA 0x80004000
    lui  x6, 0x80004
    li   x7, 0x0000C0DE
    sw   x7, 0(x6)

    # build page tables
    lui  x1, 0x80001           # L1[1] -> L0 table @ 0x80002000
    li   x2, 0x20000801
    sw   x2, 4(x1)

    lui  x3, 0x80002           # L0[0] -> code leaf 0x80003000 (A+X+R+V)
    li   x4, 0x20000C4B
    sw   x4, 0(x3)

    li   x5, 0x200010C7        # L0[1] -> data leaf 0x80004000 (D+A+W+R+V)
    sw   x5, 4(x3)

    # enable paging, go to S-mode
    li   x1, 0x80080001        # satp: SV32, ppn=0x80001
    csrw satp, x1
    sfence.vma

    li   x1, 0x800             # mstatus.MPP = S
    csrw mstatus, x1
    lui  x1, 0x00400           # mepc = VA 0x00400000 (S-mode code)
    csrw mepc, x1
    mret

# M-mode trap handler: expect the S-mode store to take a store access fault,
# then verify the write did not reach memory.
m_handler:
    csrr x1, mcause
    li   x2, 7                 # store/AMO access fault
    bne  x1, x2, test_fail     # no fault, or wrong cause

    lui  x6, 0x80004           # physical read-back (M-mode, PMP bypassed)
    lw   x7, 0(x6)
    li   x8, 0x0000C0DE        # sentinel
    bne  x7, x8, test_fail     # the denied store escaped to memory

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

# S-mode code at PA 0x80003000, executes at VA 0x00400000
.org 0x3000
s_code:
    lui  x8, 0x00401           # VA 0x00401000 -> PA 0x80004000
    li   x9, 0x00BADBAD        # value that must never reach memory
    sw   x9, 0(x8)             # denied store, PMP fault -> trap to M-mode
    ecall                      # only reached if the store did not fault -> fail

.data
