# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# RV32I Zicsr CSR Instruction Integration Test

.option arch, +zicsr
.text
.globl _start

_start:
    lui  x31, 0x80001          # Checkpoint base: 0x80000800
    addi x31, x31, -0x800      # = 0x80001000 - 0x800 = 0x80000800
    lui  x30, 0x40000          # Final result: 0x40000000
    li   x28, 0                # Accumulator
    li   x29, 0                # Test counter
    j    main_start

# ================================================================
# TEST 1 - CSRRW: atomic swap (write rs1 to CSR, read old CSR into rd)
# ================================================================
main_start:
test1:
    # Write a known value to mscratch via pseudo-write (rd=x0)
    li   x1, 0xABCD1234
    csrw 0x340, x1             # mscratch = 0xABCD1234
    nop                        # 3-cycle gap: allow WB to complete without hazard stall
    nop
    nop

    # Swap: read old mscratch into x2, write new value
    li   x1, 0xDEADBEEF
    csrrw x2, 0x340, x1        # x2 = old (0xABCD1234), mscratch = 0xDEADBEEF
    nop
    nop
    nop

    # Verify old value was returned in rd
    li   x3, 0xABCD1234
    bne  x2, x3, test_fail

    # Verify new value was written to CSR
    csrr x4, 0x340             # read mscratch
    nop
    nop
    nop
    li   x3, 0xDEADBEEF
    bne  x4, x3, test_fail

test1_pass:
    addi x28, x28, 0x111
    sw   x2, 0(x31)            # checkpoint 0: old mscratch (0xABCD1234)
    addi x29, x29, 1
    li   x27, 0x111
    bne  x28, x27, test_fail

# ================================================================
# TEST 2 - CSRRS: set bits (CSR |= rs1; rd = old CSR)
# ================================================================
test2:
    li   x1, 0x00FF00FF
    csrrs x2, 0x340, x1        # x2 = old (0xDEADBEEF), mscratch = 0xDEFFBEFF
    nop
    nop
    nop

    li   x3, 0xDEADBEEF
    bne  x2, x3, test_fail     # old value must be in rd

    csrr x4, 0x340             # verify new CSR value
    nop
    nop
    nop
    li   x3, 0xDEFFBEFF
    bne  x4, x3, test_fail

test2_pass:
    addi x28, x28, 0x222
    sw   x2, 4(x31)            # checkpoint 1: old mscratch (0xDEADBEEF)
    addi x29, x29, 1
    li   x27, 0x333
    bne  x28, x27, test_fail

# ================================================================
# TEST 3 - CSRRC: clear bits (CSR &= ~rs1; rd = old CSR)
# ================================================================
test3:
    li   x1, 0x00FF00FF
    csrrc x2, 0x340, x1        # x2 = old (0xDEFFBEFF), mscratch = 0xDE00BE00
    nop
    nop
    nop

    li   x3, 0xDEFFBEFF
    bne  x2, x3, test_fail

    csrr x4, 0x340
    nop
    nop
    nop
    li   x3, 0xDE00BE00
    bne  x4, x3, test_fail

test3_pass:
    addi x28, x28, 0x333
    sw   x2, 8(x31)            # checkpoint 2: old mscratch (0xDEFFBEFF)
    addi x29, x29, 1
    li   x27, 0x666
    bne  x28, x27, test_fail

# ================================================================
# TEST 4 - Immediate variants: CSRRWI, CSRRSI, CSRRCI
# ================================================================
test4:
    # CSRRWI: write immediate 7 to mscratch
    csrrwi x1, 0x340, 7        # x1 = old mscratch (0xDE00BE00), mscratch = 7
    nop
    nop
    nop
    csrr   x2, 0x340
    nop
    nop
    nop
    li     x3, 7
    bne    x2, x3, test_fail   # mscratch must be 7

    # CSRRSI: set bits with immediate 8 - mscratch = 7 | 8 = 15
    csrrsi x1, 0x340, 8        # x1 = old mscratch (7), mscratch = 15
    nop
    nop
    nop
    csrr   x2, 0x340
    nop
    nop
    nop
    li     x3, 15
    bne    x2, x3, test_fail   # mscratch must be 15
    li     x3, 7
    bne    x1, x3, test_fail   # csrrsi must return old value (7)

    # CSRRCI: clear bits with immediate 5 - mscratch = 15 & ~5 = 10
    csrrci x1, 0x340, 5        # x1 = old mscratch (15), mscratch = 10
    nop
    nop
    nop
    csrr   x2, 0x340
    nop
    nop
    nop
    li     x3, 10
    bne    x2, x3, test_fail   # mscratch must be 10
    li     x3, 15
    bne    x1, x3, test_fail   # csrrci must return old value (15)

test4_pass:
    addi x28, x28, 0x444
    sw   x2, 12(x31)           # checkpoint 3: mscratch after imm ops (10)
    addi x29, x29, 1
    li   x27, 0xAAA
    bne  x28, x27, test_fail

# ================================================================
# TEST 5 - CSR RAW pipeline hazard: write then immediately read same CSR
# ================================================================
test5:
    # Part A: immediate read after write (0-instruction gap)
    li   x1, 0x12345678
    csrw 0x340, x1             # mscratch = 0x12345678
    csrr x2, 0x340             # NO GAP: CSR hazard stall must fire
                               # After stall, must read the new value 0x12345678
    li   x3, 0x12345678
    bne  x2, x3, test_fail     # fail if stale value was read
    li   x1, 0xCAFEF00D
    csrw 0x340, x1             # mscratch = 0xCAFEF00D
    li   x4, 0xBEEFDEAD        # 2-instruction gap (lui + addi); WB of csrw completes
    csrrw x5, 0x340, x4        # x5 = current mscratch (0xCAFEF00D), mscratch = 0xBEEFDEAD
    li   x3, 0xCAFEF00D
    bne  x5, x3, test_fail     # csrrw must return the value written by preceding csrw

test5_pass:
    addi x28, x28, 0x555
    sw   x2, 16(x31)           # checkpoint 4: post-hazard read (0x12345678)
    addi x29, x29, 1
    li   x27, 0xFFF
    bne  x28, x27, test_fail

# ================================================================
# TEST 6 - Pseudo-read and pseudo-write
# ================================================================
test6:
    li   x1, 0x55AA55AA
    csrw 0x340, x1             # mscratch = 0x55AA55AA
    nop
    nop
    nop

    # Pseudo-read: rs1=x0, so CSR must NOT be modified
    csrrs x2, 0x340, x0        # x2 = 0x55AA55AA; mscratch unchanged
    nop
    nop
    nop
    li   x3, 0x55AA55AA
    bne  x2, x3, test_fail     # rd must contain old value

    csrr x4, 0x340             # re-read to confirm CSR was not changed
    nop
    nop
    nop
    bne  x4, x3, test_fail     # CSR must still be 0x55AA55AA

    # Pseudo-write: rd=x0, result discarded - but CSR must still be updated.
    csrrci x0, 0x340, 2        # mscratch &= ~2; rd=x0 (discarded)
    nop
    nop
    nop
    csrr x5, 0x340
    nop
    nop
    nop
    li   x3, 0x55AA55A8
    bne  x5, x3, test_fail     # CSR must reflect the pseudo-write

test6_pass:
    addi x28, x28, 0x666
    sw   x2, 20(x31)           # checkpoint 5: pseudo-read value (0x55AA55AA)
    addi x29, x29, 1
    li   x27, 0x1665
    bne  x28, x27, test_fail

# ================================================================
# TEST 7 - Consecutive CSR writes to different CSRs + mcountinhibit
# ================================================================
test7:
    # Part A: two consecutive CSR writes to DIFFERENT CSRs
    li   x1, 0x11111111
    li   x2, 0x22222222
    csrw 0x340, x1             # mscratch = 0x11111111
    csrw 0x341, x2             # mepc = 0x22222222 (no stall: addr 0x340 ≠ 0x341)

    # Reading mscratch: it was in MEM when csrw mepc was in EX - 1 stall fires
    csrr x3, 0x340             # hazard stall: reads 0x11111111 after WB
    li   x4, 0x11111111
    bne  x3, x4, test_fail

    # Reading mepc: csrw mepc WB completed during the stall above
    nop
    nop
    nop
    csrr x5, 0x341
    nop
    nop
    nop
    li   x4, 0x22222222
    bne  x5, x4, test_fail

    # Restore mepc to 0 to avoid leaving test state in trap CSRs
    csrw 0x341, x0
    nop
    nop
    nop

    # Part B: mcountinhibit stops mcycle from incrementing
    li   x1, 1
    csrw 0x320, x1             # mcountinhibit[0] = 1 - mcycle frozen
    nop                        # 3-cycle gap: wait for WB to set inhibit
    nop
    nop
    csrr x6, 0xB00             # read mcycle at time T1 (inhibited)
    nop                        # 3-cycle gap: mcycle must not advance
    nop
    nop
    csrr x7, 0xB00             # read mcycle at time T2 (still inhibited)
    bne  x6, x7, test_fail     # T1 == T2: mcycle must not have changed

    # Restore: clear mcountinhibit
    csrw 0x320, x0
    nop
    nop
    nop

test7_pass:
    addi x28, x28, 0x444
    addi x28, x28, 0x444
    sw   x3, 24(x31)           # checkpoint 6: mscratch read (0x11111111)
    addi x29, x29, 1
    li   x27, 0x1EED
    bne  x28, x27, test_fail

# ================================================================
# All tests passed
# ================================================================
all_tests_pass:
    li   x1, 7
    bne  x29, x1, test_fail
    li   x2, 0x1EED
    bne  x28, x2, test_fail

    li   x1, 0xAABBCCDD
    sw   x1, 0(x30)            # write passing result to 0x40000000
    j    end_program

test_fail:
    li   x1, 0xBADC0DE
    sw   x1, 0(x30)
    j    end_program

end_program:
    lui  x10, 0x50000
    sw   x0, 0(x10)

.data
