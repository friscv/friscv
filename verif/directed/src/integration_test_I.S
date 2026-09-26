# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# RV32I Hazard Detection and Stall Test
# Tests: RAW hazards, load-use hazards, branch hazards, forwarding paths
# Results stored at checkpoints (0x80000400+) and final result (0x40000000)
# Final result will be 0xAABBCCDD only if all tests pass correctly

.text
.globl _start

_start:
    # Initialize base addresses
    lui x31, 0x80000      # Checkpoint base: 0x80000000
    addi x31, x31, 0x500  # Offset to 0x80000500
    lui x30, 0x40000      # Final result base: 0x40000000
    
    # Initialize accumulator and test counter
    li x28, 0             # Accumulator for final result
    li x29, 0             # Test counter
    
# TEST 1: Basic RAW hazard (back-to-back data dependency)
test1:
    li x1, 100
    addi x2, x1, 50       # RAW: x2 depends on x1
    addi x3, x2, 25       # RAW: x3 depends on x2
    add x4, x3, x1        # RAW: x4 depends on x3
    # Expected: x4 = 275
    li x5, 275
    beq x4, x5, test1_pass
    j test_fail
test1_pass:
    addi x28, x28, 0x111  # Accumulate
    sw x4, 0(x31)         # Checkpoint 0
    addi x29, x29, 1
    li x27, 0x0111        # Expected accumulator
    bne x28, x27, test_fail

# TEST 2: Load-Use hazard (most critical stall case)
test2:
    li x1, 0x12345678
    sw x1, 4(x31)         # Store to checkpoint 1
    lw x2, 4(x31)         # Load from memory
    addi x3, x2, 1        # Load-use: must stall here!
    srli x4, x3, 4        # Use result immediately
    # Expected: x4 = 0x01234567
    lui x5, 0x01234
    addi x5, x5, 0x567
    beq x4, x5, test2_pass
    j test_fail
test2_pass:
    addi x28, x28, 0x222
    sw x4, 8(x31)         # Checkpoint 2
    addi x29, x29, 1
    li x27, 0x0333        # Expected accumulator
    bne x28, x27, test_fail

# TEST 3: Multiple consecutive loads (cascading load-use)
test3:
    li x1, 0xAAAA
    li x2, 0xBBBB
    sw x1, 12(x31)
    sw x2, 16(x31)
    lw x3, 12(x31)        # Load 1
    lw x4, 16(x31)        # Load 2
    add x5, x3, x4        # Use both loads: 0xAAAA + 0xBBBB = 0x16665
    slli x6, x5, 1        # Use result: 0x16665 << 1 = 0x2CCCA
    # Expected: x6 = 0x2CCCA
    lui x7, 0x0002D
    addi x7, x7, -822     # 0x2D000 + (-822) = 0x2D000 - 0x336 = 0x2CCCA
    beq x6, x7, test3_pass
    j test_fail
test3_pass:
    addi x28, x28, 0x333
    sw x6, 20(x31)        # Checkpoint 5
    addi x29, x29, 1
    li x27, 0x0666        # Expected accumulator
    bne x28, x27, test_fail

# TEST 4: Store-Load dependency (memory dependency)
test4:
    li x1, 0xFEED
    sw x1, 24(x31)        # Store
    lw x2, 24(x31)        # Load same address
    addi x3, x2, 100      # Use loaded value
    # Expected: x3 = 0xFF51 (0xFEED + 100)
    li x4, 0xFF51
    beq x3, x4, test4_pass
    j test_fail
test4_pass:
    addi x28, x28, 0x444
    sw x3, 28(x31)        # Checkpoint 7
    addi x29, x29, 1
    li x27, 0x0AAA        # Expected accumulator
    bne x28, x27, test_fail

# TEST 5: Branch hazards - data dependency in branch
test5:
    li x1, 50
    addi x2, x1, 50       # x2 = 100
    beq x2, x1, test_fail # Should not branch (100 != 50)
    bne x2, x1, test5_cont # Should branch
    j test_fail
test5_cont:
    addi x3, x2, -50      # x3 = 50
    beq x3, x1, test5_pass # Should branch (50 == 50)
    j test_fail
test5_pass:
    addi x28, x28, 0x555
    sw x3, 32(x31)        # Checkpoint 8
    addi x29, x29, 1
    li x27, 0x0FFF        # Expected accumulator
    bne x28, x27, test_fail

# TEST 6: Complex ALU operations with hazards
test6:
    li x1, 0xFF
    slli x2, x1, 8        # x2 = 0xFF00
    ori x3, x2, 0xFF      # x3 = 0xFFFF
    xori x4, x3, 0x0F0    # x4 = 0xFF0F
    andi x5, x4, 0x00F    # x5 = 0x000F
    # Expected: x5 = 0x000F
    li x6, 0x000F
    beq x5, x6, test6_pass
    j test_fail
test6_pass:
    addi x28, x28, 0x666
    sw x5, 36(x31)        # Checkpoint 9
    addi x29, x29, 1
    li x27, 0x1665        # Expected accumulator
    bne x28, x27, test_fail

# TEST 7: Shift operations with dependencies
test7:
    li x1, 0x80000001
    srli x2, x1, 1        # Logical right: 0x40000000
    srai x3, x1, 1        # Arithmetic right: 0xC0000000
    add x4, x2, x3        # Sum them
    slli x5, x4, 1        # Shift result
    # Expected: x5 = 0x00000000 (overflow behavior)
    li x6, 0
    beq x5, x6, test7_pass
    j test_fail
test7_pass:
    addi x28, x28, 0x777
    sw x5, 40(x31)        # Checkpoint 10
    addi x29, x29, 1
    li x27, 0x1DDC        # Expected accumulator
    bne x28, x27, test_fail

# TEST 8: SLT/SLTU operations with hazards
test8:
    li x1, -10
    li x2, 10
    slt x3, x1, x2        # Signed: -10 < 10 = 1
    sltu x4, x1, x2       # Unsigned: big < 10 = 0
    add x5, x3, x4        # x5 = 1
    slti x6, x5, 2        # 1 < 2 = 1
    sltiu x7, x5, 2       # 1 < 2 = 1
    add x8, x6, x7        # x8 = 2
    # Expected: x8 = 2
    li x9, 2
    beq x8, x9, test8_pass
    j test_fail
test8_pass:
    addi x28, x28, 0x088
    sw x8, 44(x31)        # Checkpoint 11
    addi x29, x29, 1
    li x27, 0x1E64        # Expected accumulator
    bne x28, x27, test_fail

# TEST 9: JAL/JALR with dependencies
test9:
    li x1, 0
    jal x2, test9_target  # Jump and link, x2 = PC of next instr
test9_return:
    addi x1, x1, 1        # x1 = 101 (executed after jalr returns here)
    # Expected: x1 = 101
    li x5, 101
    beq x1, x5, test9_pass
    j test_fail
test9_target:
    addi x1, x1, 100      # x1 = 100
    jalr x4, x2, 0        # Jump back to x2 (test9_return)
    j test_fail           # Should skip this
test9_pass:
    addi x28, x28, 0x099
    sw x1, 48(x31)        # Checkpoint 12
    addi x29, x29, 1
    li x27, 0x1EFD        # Expected accumulator
    bne x28, x27, test_fail

# TEST 10: LUI/AUIPC with dependencies
test10:
    lui x1, 0xABCDE       # Upper immediate
    addi x2, x1, 0x321    # Use immediately
    auipc x3, 0           # PC-relative
    add x4, x3, x2        # Combine them
    srli x5, x4, 12       # Extract upper bits
    # Just check it doesn't crash and produces some result
    addi x28, x28, 0x0AA
    sw x5, 52(x31)        # Checkpoint 13
    addi x29, x29, 1
    li x27, 0x1FA7        # Expected accumulator
    bne x28, x27, test_fail

# TEST 11: Branch delay slot edge case
test11:
    li x1, 0
    li x2, 100
test11_loop:
    addi x1, x1, 1
    bne x1, x2, test11_loop # Loop with dependency
    # Expected: x1 = 100
    beq x1, x2, test11_pass
    j test_fail
test11_pass:
    addi x28, x28, 0x0BB
    sw x1, 56(x31)        # Checkpoint 14
    addi x29, x29, 1
    li x27, 0x2062        # Expected accumulator
    bne x28, x27, test_fail

# TEST 12: Load byte/half variants with sign extension
test12:
    li x1, 0xFFFFFF80     # Negative byte
    sb x1, 60(x31)
    lb x2, 60(x31)        # Load signed byte
    lbu x3, 60(x31)       # Load unsigned byte
    add x4, x2, x3        # x2=-128, x3=128, sum=0
    # Expected: x4 = 0
    li x5, 0
    beq x4, x5, test12_pass
    j test_fail
test12_pass:
    addi x28, x28, 0x0CC
    sw x4, 64(x31)        # Checkpoint 16
    addi x29, x29, 1
    li x27, 0x212E        # Expected accumulator
    bne x28, x27, test_fail

# TEST 13: Complex forwarding chain
test13:
    li x1, 1
    add x2, x1, x1        # x2 = 2
    add x3, x2, x2        # x3 = 4
    add x4, x3, x3        # x4 = 8
    add x5, x4, x4        # x5 = 16
    add x6, x5, x5        # x6 = 32
    add x7, x6, x6        # x7 = 64
    # Expected: x7 = 64
    li x8, 64
    beq x7, x8, test13_pass
    j test_fail
test13_pass:
    addi x28, x28, 0x0DD
    sw x7, 68(x31)        # Checkpoint 17
    addi x29, x29, 1
    li x27, 0x220B        # Expected accumulator
    bne x28, x27, test_fail

# TEST 14: Branch misprediction test
test14:
    li x1, 0
    li x2, 5
test14_loop:
    addi x1, x1, 1
    blt x1, x2, test14_loop # Taken multiple times
    # Now test reverse
    li x3, 10
test14_loop2:
    addi x1, x1, 1
    bge x1, x3, test14_done # Not taken, then taken
    j test14_loop2
test14_done:
    # Expected: x1 = 10
    li x4, 10
    beq x1, x4, test14_pass
    j test_fail
test14_pass:
    addi x28, x28, 0x0EE
    sw x1, 72(x31)        # Checkpoint 18
    addi x29, x29, 1
    li x27, 0x22F9        # Expected accumulator
    bne x28, x27, test_fail

# TEST 15: Store-to-load forwarding with different sizes
test15:
    li x1, 0x12345678
    sw x1, 76(x31)
    lh x2, 76(x31)        # Load lower half
    lh x3, 78(x31)        # Load upper half
    slli x4, x3, 16       # Shift upper to position
    or x5, x4, x2         # Reconstruct with zero-extension issue
    lhu x6, 76(x31)       # Try unsigned
    # Expected: x6 = 0x5678
    lui x7, 0x00005
    addi x7, x7, 0x678
    beq x6, x7, test15_pass
    j test_fail
test15_pass:
    addi x28, x28, 0x0FF
    sw x6, 80(x31)        # Checkpoint 20
    addi x29, x29, 1
    li x27, 0x23F8        # Expected accumulator
    bne x28, x27, test_fail

# TEST 16: Byte/Half-word Rotation & Masking
# Verify correct placement of bytes/halves within a word
test16:
    li x1, 0x89ABCDEF
    sw x1, 84(x31)        # Store word
    lbu x2, 84(x31)       # Load byte 0 (0xEF) - Little Endian
    lbu x3, 85(x31)       # Load byte 1 (0xCD)
    lbu x4, 86(x31)       # Load byte 2 (0xAB)
    lbu x5, 87(x31)       # Load byte 3 (0x89)
    
    # Check sum: 0xEF + 0xCD + 0xAB + 0x89 = 0x2F0
    add x6, x2, x3
    add x6, x6, x4
    add x6, x6, x5
    li x7, 0x2F0
    bne x6, x7, test_fail

    # Check half-words
    lhu x8, 84(x31)       # Load half 0 (0xCDEF)
    lhu x9, 86(x31)       # Load half 1 (0x89AB)
    li x10, 0xCDEF
    bne x8, x10, test_fail
    li x10, 0x89AB
    bne x9, x10, test_fail

test16_pass:
    addi x28, x28, 0x101
    sw x6, 88(x31)        # Checkpoint 21
    addi x29, x29, 1
    li x27, 0x24F9        # Expected accumulator (0x23F8 + 0x101)
    bne x28, x27, test_fail

# TEST 17: Back-to-back Memory Accesses
# Stress test memory controller arbitration
test17:
    li x1, 0x11111111
    li x2, 0x22222222
    li x3, 0x33333333
    
    # Back-to-back stores
    sw x1, 92(x31)
    sw x2, 96(x31)
    sw x3, 100(x31)
    
    # Back-to-back loads (immediately after stores)
    lw x4, 92(x31)
    lw x5, 96(x31)
    lw x6, 100(x31)
    
    # Verify values
    bne x1, x4, test_fail
    bne x2, x5, test_fail
    bne x3, x6, test_fail
    
    # Mixed Store-Load-Store-Load
    addi x4, x4, 1        # 0x11111112
    sw x4, 92(x31)
    lw x7, 92(x31)
    addi x7, x7, 1        # 0x11111113
    sw x7, 92(x31)
    lw x8, 92(x31)
    
    # Expected: x8 = 0x11111113
    li x9, 0x11111113
    bne x8, x9, test_fail

test17_pass:
    addi x28, x28, 0x102
    sw x8, 104(x31)       # Checkpoint 22
    addi x29, x29, 1
    li x27, 0x25FB        # Expected accumulator (0x24F9 + 0x102)
    bne x28, x27, test_fail

# All tests passed! Compute final result
all_tests_pass:
    # Verify we ran all 17 tests
    li x1, 17
    bne x29, x1, test_fail
    
    # Compute final magic number from accumulator
    # New Expected accumulator = 0x25FB
    li x2, 0x25FB
    bne x28, x2, test_fail
    
    # Final result: AABBCCDD
    li x1, 0xAABBCCDD
    sw x1, 0(x30)         # Store at 0x40000000
    
    j end_program

test_fail:
    # Store failure marker
    li x1, 0xBADC0DE
    sw x1, 0(x30)         # Store at 0x40000000
    j end_program

end_program:
    # Halt by writing to 0x50000000
    lui x10, 0x50000
    sw x0, 0(x10)

.data
# Test data can be added here if needed
