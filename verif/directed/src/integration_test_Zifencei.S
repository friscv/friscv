# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# RV32I Zifencei Extension Test (FENCE.I)
# Tests self-modifying code: store new instruction bytes before fence.i,
# then verify the modified instruction executes after pipeline refetch.
#
# Test sequence for each test:
#   1. [STORE]    sw <new_encoding>, 0(addr_of_slot)   - overwrite instruction memory
#   2. [FENCE.I]  fence.i                              - flush pipeline, refetch from PC+4
#   3. [MODIFIED] <slot executes with the new encoding>
#
# Final result: 0xAABBCCDD at 0x40000000 on pass, 0xBADC0DE on fail.

.option arch, +zifencei
.text
.globl _start

_start:
    lui  x31, 0x80000      # Test data base: 0x80000000
    addi x31, x31, 0x700   # -> 0x80000700
    lui  x30, 0x40000      # Final result address: 0x40000000

    li x28, 0              # Accumulator
    li x29, 0              # Test counter

# ============================================================
# TEST 1: NOP -> ADDI x2, x0, 0x55  (encoding 0x05500113)
# The nop at target_instr_1 is overwritten by the sw. fence.i
# flushes the pipeline so the refetched slot runs as addi.
# ============================================================
test1:
    li   x2, 0xBEEF           # Wrong if modification did not execute
    la   x1, target_instr_1   # x1 = address of the slot to overwrite
    li   x3, 0x05500113       # New instruction: addi x2, x0, 0x55
    sw   x3, 0(x1)            # [STORE] write new instruction encoding to memory
    fence.i                   # [FENCE.I] flush pipeline, refetch from PC+4
target_instr_1:
    nop                       # [MODIFIED SLOT] originally nop -> addi x2, x0, 0x55
    li   x4, 0x55
    beq  x2, x4, test1_pass
    j    test_fail
test1_pass:
    addi x28, x28, 0x111
    addi x29, x29, 1
    li   x27, 0x0111
    bne  x28, x27, test_fail

# ============================================================
# TEST 2: NOP -> ADDI x2, x0, 0x77  (encoding 0x07700113)
# Same pattern, different immediate. Confirms fence.i works
# correctly on each use and the first test was not a fluke.
# ============================================================
test2:
    li   x2, 0xBEEF
    la   x1, target_instr_2   # x1 = address of slot
    li   x3, 0x07700113       # New instruction: addi x2, x0, 0x77
    sw   x3, 0(x1)            # [STORE]
    fence.i                   # [FENCE.I]
target_instr_2:
    nop                       # [MODIFIED SLOT] -> addi x2, x0, 0x77
    li   x4, 0x77
    beq  x2, x4, test2_pass
    j    test_fail
test2_pass:
    addi x28, x28, 0x222
    addi x29, x29, 1
    li   x27, 0x0333
    bne  x28, x27, test_fail

# ============================================================
# TEST 3: NOP -> ADD x2, x3, x4  (encoding 0x00418133)
# Overwrites with a register-register instruction. x3 and x4
# are loaded AFTER the store so that the li sequence for the
# encoding does not clobber them. Expected: x2 = 10 + 20 = 30.
# ============================================================
test3:
    li   x2, 0xBEEF           # Sentinel
    la   x1, target_instr_3   # x1 = address of slot
    li   x5, 0x00418133       # New instruction: add x2, x3, x4 (x5 used as scratch)
    sw   x5, 0(x1)            # [STORE]
    li   x3, 10               # Load operands after the store to avoid clobbering
    li   x4, 20
    fence.i                   # [FENCE.I]
target_instr_3:
    nop                       # [MODIFIED SLOT] -> add x2, x3, x4
    li   x6, 30
    beq  x2, x6, test3_pass
    j    test_fail
test3_pass:
    addi x28, x28, 0x333
    addi x29, x29, 1
    li   x27, 0x0666
    bne  x28, x27, test_fail

# ============================================================
# All tests passed
# ============================================================
all_tests_pass:
    li x1, 3
    bne x29, x1, test_fail

    li x2, 0x0666
    bne x28, x2, test_fail

    li x1, 0xAABBCCDD
    sw x1, 0(x30)
    j  end_program

test_fail:
    li x1, 0xBADC0DE
    sw x1, 0(x30)

end_program:
    lui x10, 0x50000
    sw  x0, 0(x10)

.data
