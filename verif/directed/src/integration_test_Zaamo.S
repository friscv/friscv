# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# RV32A Atomic Extension Test (Zaamo: AMO instructions)
# Tests: AMOSWAP, AMOADD, AMOXOR, AMOAND, AMOOR,
#        AMOMIN, AMOMAX, AMOMINU, AMOMAXU
# Final result will be 0xAABBCCDD only if all tests pass correctly

.option arch, +a
.text
.globl _start

_start:
    lui x31, 0x80000       # Test data base: 0x80000000
    addi x31, x31, 0x700   # 0x80000700
    lui x30, 0x40000       # Final result address: 0x40000000

    li x28, 0              # Accumulator
    li x29, 0              # Test counter

# ============================================================
# TEST 1: AMOSWAP.W - basic operation
# rd = old mem[addr]; mem[addr] = rs2
# ============================================================
test1:
    li x1, 0xDEADBEEF
    sw x1, 0(x31)
    li x2, 0xCAFEBABE
    amoswap.w x3, x2, (x31)   # x3 = 0xDEADBEEF, mem = 0xCAFEBABE
    li x4, 0xDEADBEEF
    bne x3, x4, test_fail     # rd must be old value
    lw x5, 0(x31)
    li x4, 0xCAFEBABE
    beq x5, x4, test1_pass
    j test_fail
test1_pass:
    addi x28, x28, 0x111
    addi x29, x29, 1
    li x27, 0x0111
    bne x28, x27, test_fail

# ============================================================
# TEST 2: AMOADD.W - basic operation
# rd = old mem[addr]; mem[addr] = mem[addr] + rs2
# ============================================================
test2:
    li x1, 0x00001000
    sw x1, 0(x31)
    li x2, 0x00000FFF
    amoadd.w x3, x2, (x31)    # x3 = 0x1000, mem = 0x1FFF
    li x4, 0x00001000
    bne x3, x4, test_fail
    lw x5, 0(x31)
    li x4, 0x00001FFF
    beq x5, x4, test2_pass
    j test_fail
test2_pass:
    addi x28, x28, 0x222
    addi x29, x29, 1
    li x27, 0x0333
    bne x28, x27, test_fail

# ============================================================
# TEST 3: AMOXOR.W - basic operation
# rd = old mem[addr]; mem[addr] = mem[addr] ^ rs2
# ============================================================
test3:
    li x1, 0xFF00FF00
    sw x1, 0(x31)
    li x2, 0x0F0F0F0F
    amoxor.w x3, x2, (x31)    # x3 = 0xFF00FF00, mem = 0xF00FF00F
    li x4, 0xFF00FF00
    bne x3, x4, test_fail
    lw x5, 0(x31)
    li x4, 0xF00FF00F
    beq x5, x4, test3_pass
    j test_fail
test3_pass:
    addi x28, x28, 0x333
    addi x29, x29, 1
    li x27, 0x0666
    bne x28, x27, test_fail

# ============================================================
# TEST 4: AMOAND.W - basic operation
# rd = old mem[addr]; mem[addr] = mem[addr] & rs2
# ============================================================
test4:
    li x1, 0xFFFF0000
    sw x1, 0(x31)
    li x2, 0x0000FFFF
    amoand.w x3, x2, (x31)    # x3 = 0xFFFF0000, mem = 0x00000000
    li x4, 0xFFFF0000
    bne x3, x4, test_fail
    lw x5, 0(x31)
    bne x5, x0, test_fail     # mem must be 0
    beq x0, x0, test4_pass
test4_pass:
    addi x28, x28, 0x444
    addi x29, x29, 1
    li x27, 0x0AAA
    bne x28, x27, test_fail

# ============================================================
# TEST 5: AMOOR.W - basic operation
# rd = old mem[addr]; mem[addr] = mem[addr] | rs2
# ============================================================
test5:
    li x1, 0xF0F0F0F0
    sw x1, 0(x31)
    li x2, 0x0F0F0F0F
    amoor.w x3, x2, (x31)     # x3 = 0xF0F0F0F0, mem = 0xFFFFFFFF
    li x4, 0xF0F0F0F0
    bne x3, x4, test_fail
    lw x5, 0(x31)
    li x4, 0xFFFFFFFF
    beq x5, x4, test5_pass
    j test_fail
test5_pass:
    addi x28, x28, 0x555
    addi x29, x29, 1
    li x27, 0x0FFF
    bne x28, x27, test_fail

# ============================================================
# TEST 6: AMOMIN.W - signed minimum
# rd = old mem[addr]; mem[addr] = min_signed(mem[addr], rs2)
#   Part A: mem=5, rs2=-3  → min=-3; rd=5
#   Part B: mem=-10, rs2=-3 → min=-10; rd=-10, mem unchanged
# ============================================================
test6:
    li x1, 5
    sw x1, 0(x31)
    li x2, -3
    amomin.w x3, x2, (x31)    # x3=5, mem=-3
    li x4, 5
    bne x3, x4, test_fail
    lw x5, 0(x31)
    li x4, -3
    bne x5, x4, test_fail
    li x1, -10
    sw x1, 0(x31)
    li x2, -3
    amomin.w x3, x2, (x31)    # x3=-10, mem=-10 (unchanged)
    li x4, -10
    bne x3, x4, test_fail
    lw x5, 0(x31)
    beq x5, x4, test6_pass
    j test_fail
test6_pass:
    addi x28, x28, 0x666
    addi x29, x29, 1
    li x27, 0x1665
    bne x28, x27, test_fail

# ============================================================
# TEST 7: AMOMAX.W - signed maximum
# rd = old mem[addr]; mem[addr] = max_signed(mem[addr], rs2)
#   Part A: mem=-10, rs2=3  → max=3;  rd=-10
#   Part B: mem=10,  rs2=3  → max=10; rd=10, mem unchanged
# ============================================================
test7:
    li x1, -10
    sw x1, 0(x31)
    li x2, 3
    amomax.w x3, x2, (x31)    # x3=-10, mem=3
    li x4, -10
    bne x3, x4, test_fail
    lw x5, 0(x31)
    li x4, 3
    bne x5, x4, test_fail
    li x1, 10
    sw x1, 0(x31)
    li x2, 3
    amomax.w x3, x2, (x31)    # x3=10, mem=10 (unchanged)
    li x4, 10
    bne x3, x4, test_fail
    lw x5, 0(x31)
    beq x5, x4, test7_pass
    j test_fail
test7_pass:
    addi x28, x28, 0x777
    addi x29, x29, 1
    li x27, 0x1DDC
    bne x28, x27, test_fail

# ============================================================
# TEST 8: AMOMINU.W - unsigned minimum
# Edge case: 0xFFFFFFFF is unsigned-large but signed-small (-1).
# A wrong signed comparison keeps mem unchanged; correct unsigned
# comparison writes 10 into memory.
#   Part A: mem=0xFFFFFFFF, rs2=10 → minu=10; rd=0xFFFFFFFF
#   Part B: mem=5, rs2=5           → minu=5;  equal, unchanged
# ============================================================
test8:
    li x1, 0xFFFFFFFF
    sw x1, 0(x31)
    li x2, 10
    amominu.w x3, x2, (x31)   # x3=0xFFFFFFFF, mem=10
    li x4, 0xFFFFFFFF
    bne x3, x4, test_fail
    lw x5, 0(x31)
    li x4, 10
    bne x5, x4, test_fail
    li x1, 5
    sw x1, 0(x31)
    li x2, 5
    amominu.w x3, x2, (x31)   # x3=5, mem=5 (equal, unchanged)
    li x4, 5
    bne x3, x4, test_fail
    lw x5, 0(x31)
    beq x5, x4, test8_pass
    j test_fail
test8_pass:
    addi x28, x28, 0x444
    addi x28, x28, 0x444
    addi x29, x29, 1
    li x27, 0x2664
    bne x28, x27, test_fail

# ============================================================
# TEST 9: AMOMAXU.W - unsigned maximum
# Edge case: 0xFFFFFFFF is unsigned-large but signed-small (-1).
# A wrong signed comparison keeps mem unchanged; correct unsigned
# comparison writes 0xFFFFFFFF into memory.
#   Part A: mem=5,   rs2=0xFFFFFFFF → maxu=0xFFFFFFFF; rd=5
#   Part B: mem=100, rs2=50         → maxu=100; rd=100, mem unchanged
# ============================================================
test9:
    li x1, 5
    sw x1, 0(x31)
    li x2, 0xFFFFFFFF
    amomaxu.w x3, x2, (x31)   # x3=5, mem=0xFFFFFFFF
    li x4, 5
    bne x3, x4, test_fail
    lw x5, 0(x31)
    li x4, 0xFFFFFFFF
    bne x5, x4, test_fail
    li x1, 100
    sw x1, 0(x31)
    li x2, 50
    amomaxu.w x3, x2, (x31)   # x3=100, mem=100 (unchanged)
    li x4, 100
    bne x3, x4, test_fail
    lw x5, 0(x31)
    beq x5, x4, test9_pass
    j test_fail
test9_pass:
    addi x28, x28, 0x099
    addi x29, x29, 1
    li x27, 0x26FD
    bne x28, x27, test_fail

# ============================================================
# TEST 10: rd = x0 - result discarded but memory still written
# ============================================================
test10:
    li x1, 0x100
    sw x1, 0(x31)
    li x2, 5
    amoadd.w x0, x2, (x31)    # x0 discarded (stays 0), mem = 0x105
    lw x3, 0(x31)
    li x4, 0x105
    bne x3, x4, test_fail     # memory must be updated
    bne x0, x0, test_fail     # x0 must still be 0 (hardwired)
    beq x0, x0, test10_pass
test10_pass:
    addi x28, x28, 0x0AA
    addi x29, x29, 1
    li x27, 0x27A7
    bne x28, x27, test_fail

# ============================================================
# TEST 11: Back-to-back AMOs to the same address
# Each AMO must see the result written by the previous one.
# ============================================================
test11:
    li x1, 0
    sw x1, 0(x31)             # mem = 0
    li x2, 1
    amoadd.w x3, x2, (x31)    # x3=0,  mem=1
    amoadd.w x4, x2, (x31)    # x4=1,  mem=2
    amoadd.w x5, x2, (x31)    # x5=2,  mem=3
    lw x6, 0(x31)
    li x7, 3
    bne x6, x7, test_fail     # final mem must be 3
    bne x3, x0, test_fail     # 1st rd = 0
    li x7, 1
    bne x4, x7, test_fail     # 2nd rd = 1
    li x7, 2
    beq x5, x7, test11_pass   # 3rd rd = 2
    j test_fail
test11_pass:
    addi x28, x28, 0x0BB
    addi x29, x29, 1
    li x27, 0x2862
    bne x28, x27, test_fail

# ============================================================
# TEST 12: AMO result used immediately (pipeline hazard)
# The returned old value must be forwarded correctly before
# the next instruction reads it.
# ============================================================
test12:
    li x1, 0x100
    sw x1, 0(x31)
    li x2, 0x10
    amoadd.w x3, x2, (x31)    # x3=0x100 (old), mem=0x110
    addi x4, x3, 0x10         # immediately use x3: x4=0x110
    li x5, 0x100
    bne x3, x5, test_fail     # rd must be old value
    li x5, 0x110
    beq x4, x5, test12_pass   # forwarded value must be correct
    j test_fail
test12_pass:
    addi x28, x28, 0x0CC
    addi x29, x29, 1
    li x27, 0x292E
    bne x28, x27, test_fail

# ============================================================
# All tests passed
# ============================================================
all_tests_pass:
    li x1, 12
    bne x29, x1, test_fail

    li x2, 0x292E
    bne x28, x2, test_fail

    li x1, 0xAABBCCDD
    sw x1, 0(x30)

    j end_program

test_fail:
    li x1, 0xBADC0DE
    sw x1, 0(x30)

end_program:
    lui x10, 0x50000
    sw x0, 0(x10)

.data
