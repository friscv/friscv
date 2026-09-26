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
    lui  x30, 0x40000          # result address 0x40000000
    li   x28, 0                # accumulator
    li   x29, 0                # test counter
    csrw mie, x0               # suppress timer interrupt

    la   x1, trap_handler
    csrw mtvec, x1             # direct-mode trap vector

    li   x5, 0x80000900        # protected scratch address
    li   x6, 0x0000C0DE        # sentinel

    # set the sentinel while the region is unprotexted
    sw   x6, 0(x5)
    lw   x7, 0(x5)
    bne  x7, x6, test_fail

    # configure PMP entry 0
    li   x1, 0x20000241
    csrw pmpaddr0, x1
    li   x1, 0x9D              # L=1, A=NAPOT, X=1, W=0, R=1
    csrw pmpcfg0, x1

    j    test1

trap_handler:
    li   x10, 1                # flag
    csrr x1, mepc
    addi x1, x1, 4
    csrw mepc, x1
    mret

# TEST 1 - store to W-denied region: must fault with mcause=7 and not write
test1:
    li   x10, 0                # clear trap flag
    li   x8, 0x80000900        # target
    li   x11, 0x00BADBAD       # value that must not reach memory

test1_store:
    sw   x11, 0(x8)            # denied: traps and handler skips to next instruction

    li   x1, 1
    bne  x10, x1, test_fail    # no trap -> PMP write-deny broken
    csrr x2, mcause
    li   x1, 7
    bne  x2, x1, test_fail     # wrong cause

    lw   x7, 0(x5)             # read back through allowed R
    li   x6, 0x0000C0DE
    bne  x7, x6, test_fail     # sentinel changed -> the store escaped

test1_pass:
    addi x28, x28, 0x111
    addi x29, x29, 1
    li   x27, 0x111
    bne  x28, x27, test_fail

# TEST 2 - load from R-allowed region: succeeds, no trap
test2:
    li   x10, 0
    lw   x7, 0(x5)
    bne  x10, x0, test_fail    # unexpected trap on allowed load
    li   x6, 0x0000C0DE
    bne  x7, x6, test_fail

test2_pass:
    addi x28, x28, 0x222
    addi x29, x29, 1
    li   x27, 0x333
    bne  x28, x27, test_fail

# TEST 3 - store to an unprotected address still works
test3:
    li   x10, 0
    li   x9, 0x80000A00        # outside the protected region
    li   x12, 0x12345678
    sw   x12, 0(x9)            # allowed
    bne  x10, x0, test_fail    # unexpected trap on allowed store
    lw   x7, 0(x9)
    bne  x7, x12, test_fail    # store did not land

test3_pass:
    addi x28, x28, 0x333
    addi x29, x29, 1
    li   x27, 0x666
    bne  x28, x27, test_fail

all_tests_pass:
    li   x1, 3
    bne  x29, x1, test_fail
    li   x1, 0x666
    bne  x28, x1, test_fail

    li   x1, 0xAABBCCDD
    sw   x1, 0(x30)
    j    end_program

test_fail:
    li   x1, 0xBADC0DE
    sw   x1, 0(x30)

end_program:
    lui  x10, 0x50000
    sw   x0, 0(x10)

.data
