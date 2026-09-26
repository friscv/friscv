# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# RV32IA Atomic Extension Test (LR.W / SC.W)
# Tests: basic operation, success/failure conditions, reservation semantics
# Final result will be 0xAABBCCDD only if all tests pass correctly

.option arch, +a
.text
.globl _start

_start:
    lui x31, 0x80000       # Test data base: 0x80000000
    addi x31, x31, 0x600   # 0x80000600
    lui x30, 0x40000       # Final result address: 0x40000000

    li x28, 0              # Accumulator
    li x29, 0              # Test counter

# ============================================================
# TEST 1: LR.W reads the correct value from memory
# ============================================================
test1:
    li x1, 0xA5A5A5A5
    sw x1, 0(x31)
    lr.w x2, (x31)         # x2 = LR.W(x31): expect 0xA5A5A5A5
    beq x2, x1, test1_pass
    j test_fail
test1_pass:
    addi x28, x28, 0x111
    addi x29, x29, 1
    li x27, 0x0111
    bne x28, x27, test_fail

# ============================================================
# TEST 2: SC.W after LR.W to same address succeeds (returns 0)
#         and the written value appears in memory
# ============================================================
test2:
    li x1, 0xDEADBEEF
    sw x1, 0(x31)
    li x3, 0xCAFEBABE
    lr.w x2, (x31)         # x2 = 0xDEADBEEF, reservation set
    sc.w x4, x3, (x31)     # x4 = SC.W result, must be 0 (success)
    bne x4, x0, test_fail
    lw x5, 0(x31)          # Memory must contain new value
    beq x5, x3, test2_pass
    j test_fail
test2_pass:
    addi x28, x28, 0x222
    addi x29, x29, 1
    li x27, 0x0333
    bne x28, x27, test_fail

# ============================================================
# TEST 3: SC.W without a prior LR.W fails (returns 1)
#         and does not modify memory
# ============================================================
test3:
    li x1, 0x11111111
    sw x1, 0(x31)
    li x2, 0x22222222
    sc.w x3, x2, (x31)     # No reservation: must fail (return 1)
    li x4, 1
    bne x3, x4, test_fail
    lw x5, 0(x31)          # Memory must be unchanged
    beq x5, x1, test3_pass
    j test_fail
test3_pass:
    addi x28, x28, 0x333
    addi x29, x29, 1
    li x27, 0x0666
    bne x28, x27, test_fail

# ============================================================
# TEST 4: Successful SC.W clears the reservation;
#         a second SC.W to the same address fails (returns 1)
# ============================================================
test4:
    li x1, 0xAAAAAAAA
    sw x1, 0(x31)
    lr.w x2, (x31)         # Set reservation
    li x3, 0xBBBBBBBB
    sc.w x4, x3, (x31)     # First SC.W: must succeed (return 0)
    bne x4, x0, test_fail
    li x5, 0xCCCCCCCC
    sc.w x6, x5, (x31)     # Second SC.W: reservation cleared, must fail (return 1)
    li x7, 1
    beq x6, x7, test4_pass
    j test_fail
test4_pass:
    addi x28, x28, 0x444
    addi x29, x29, 1
    li x27, 0x0AAA
    bne x28, x27, test_fail

# ============================================================
# TEST 5: SC.W to a different address than reserved fails (returns 1)
#         and does not modify the target address
# ============================================================
test5:
    li x1, 0x55555555
    sw x1, 0(x31)          # Slot A (reserved address)
    li x2, 0x66666666
    sw x2, 4(x31)          # Slot B (different address)
    lr.w x3, (x31)         # Reserve slot A (x31+0)
    li x4, 0x77777777
    addi x10, x31, 4       # x10 = address of slot B
    sc.w x5, x4, (x10)     # SC.W to slot B: wrong address, must fail
    li x6, 1
    bne x5, x6, test_fail
    lw x7, 4(x31)          # Slot B must be unchanged
    beq x7, x2, test5_pass
    j test_fail
test5_pass:
    addi x28, x28, 0x555
    addi x29, x29, 1
    li x27, 0x0FFF
    bne x28, x27, test_fail

# ============================================================
# TEST 6: Failed SC.W (address mismatch) preserves the reservation;
#         the next SC.W to the correct address succeeds
# ============================================================
test6:
    li x1, 0x12345678
    sw x1, 0(x31)          # Slot A
    li x2, 0x87654321
    sw x2, 4(x31)          # Slot B
    lr.w x3, (x31)         # Reserve slot A (x31+0)
    li x4, 0xDEAD0000
    addi x10, x31, 4       # x10 = address of slot B
    sc.w x5, x4, (x10)     # SC.W slot B: fails, reservation for slot A preserved
    li x6, 1
    bne x5, x6, test_fail
    li x7, 0x0000BEEF
    sc.w x8, x7, (x31)     # SC.W slot A: reservation valid, must succeed
    bne x8, x0, test_fail
    lw x9, 0(x31)          # Verify written value
    beq x9, x7, test6_pass
    j test_fail
test6_pass:
    addi x28, x28, 0x666
    addi x29, x29, 1
    li x27, 0x1665
    bne x28, x27, test_fail

# ============================================================
# TEST 7: A second LR.W overwrites the reservation address;
#         SC.W to the first address fails, SC.W to the second succeeds
# ============================================================
test7:
    li x1, 0x11112222
    sw x1, 0(x31)          # Slot A
    li x2, 0x33334444
    sw x2, 4(x31)          # Slot B
    lr.w x3, (x31)         # Reserve slot A (x31+0)
    addi x10, x31, 4       # x10 = address of slot B
    lr.w x4, (x10)         # Reserve slot B - overwrites slot A reservation
    li x5, 0x55556666
    sc.w x6, x5, (x31)     # SC.W slot A: must fail (reservation is now for slot B)
    li x7, 1
    bne x6, x7, test_fail
    li x8, 0x77778888
    sc.w x9, x8, (x10)     # SC.W slot B: must succeed
    bne x9, x0, test_fail
    lw x10, 4(x31)         # Verify slot B was written
    beq x10, x8, test7_pass
    j test_fail
test7_pass:
    addi x28, x28, 0x777
    addi x29, x29, 1
    li x27, 0x1DDC
    bne x28, x27, test_fail

# ============================================================
# TEST 8: A regular SW to the reserved address does not
#         invalidate the reservation; subsequent SC.W still succeeds
# ============================================================
test8:
    li x1, 0xAAAA0000
    sw x1, 0(x31)
    lr.w x2, (x31)         # Reserve slot A, x2 = 0xAAAA0000
    li x3, 0xBBBB0000
    sw x3, 0(x31)          # Regular store to reserved address (no LR/SC)
    li x4, 0xCCCC0000
    sc.w x5, x4, (x31)     # Reservation still valid: must succeed (return 0)
    bne x5, x0, test_fail
    lw x6, 0(x31)          # Verify SC.W value was written (not the regular SW value)
    beq x6, x4, test8_pass
    j test_fail
test8_pass:
    addi x28, x28, 0x444
    addi x28, x28, 0x444
    addi x29, x29, 1
    li x27, 0x2664
    bne x28, x27, test_fail

# ============================================================
# TEST 9: Compare-And-Swap pattern using LR.W / SC.W
# ============================================================
test9:
    li x1, 0xFACEFACE
    sw x1, 0(x31)
    lr.w x2, (x31)         # x2 = 0xFACEFACE, reserve
    li x3, 0xFACEFACE      # Expected value
    bne x2, x3, test_fail  # CAS check: current == expected?
    li x4, 0xDECEDECE      # New value
    sc.w x5, x4, (x31)     # Conditional store: must succeed
    bne x5, x0, test_fail
    lw x6, 0(x31)          # Verify new value in memory
    beq x6, x4, test9_pass
    j test_fail
test9_pass:
    addi x28, x28, 0x099
    addi x29, x29, 1
    li x27, 0x26FD
    bne x28, x27, test_fail

# ============================================================
# TEST 10: Atomic increment loop - LR.W / SC.W retry pattern
# ============================================================
test10:
    li x1, 100
    sw x1, 0(x31)          # counter = 100
test10_loop:
    lr.w x2, (x31)         # Load counter
    addi x3, x2, 1         # Increment
    sc.w x4, x3, (x31)     # Attempt conditional store
    bne x4, x0, test10_loop  # Retry on failure
    lw x5, 0(x31)
    li x6, 101
    beq x5, x6, test10_pass
    j test_fail
test10_pass:
    addi x28, x28, 0x0AA
    addi x29, x29, 1
    li x27, 0x27A7
    bne x28, x27, test_fail

# ============================================================
# All tests passed
# ============================================================
all_tests_pass:
    li x1, 10
    bne x29, x1, test_fail

    li x2, 0x27A7
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
