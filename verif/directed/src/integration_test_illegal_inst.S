# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# RV32I Illegal Instruction Exception Integration Test
#
# Verifies that each class of illegal instruction:
#   (a) triggers a trap (mcause = 2)
#   (b) captures the faulting instruction encoding in mtval
#   (c) resumes correctly after mepc+4 advance in handler
#
# Sources tested:
#   1. CSR write to read-only CSR     (decode_csr_ro && is_csr_write)
#   2. Access to unimplemented CSR    (csr_not_implemented)
#   3. Undefined opcode               (LOAD_FP, default case in opcode decode)
#   4. STORE with reserved funct3=3   (SD in RV64, illegal in RV32)
#   5. JALR with reserved funct3=1    (funct3 != 0 check)

.option arch, +zicsr
.text
.globl _start

_start:
    lui  x31, 0x80001          # Checkpoint base: 0x80000800
    addi x31, x31, -0x800
    lui  x30, 0x40000          # Final result address: 0x40000000
    li   x28, 0                # Accumulator
    li   x29, 0                # Test counter
    li   x10, 0                # Handler entry counter

    csrw mie, x0               # Suppress all external interrupts

    j    main_start

# ============================================================
# SHARED ILLEGAL INSTRUCTION HANDLER
#   x10: incremented on each entry
#   x11: mcause captured at trap entry
#   x12: mtval  captured at trap entry (faulting instruction encoding)
# Handler advances mepc by 4 then MRETs.
# ============================================================
handler:
    addi x10, x10, 1
    csrr x11, mcause
    csrr x12, mtval
    csrr x1,  mepc
    addi x1,  x1, 4
    csrw mepc, x1              # Skip faulting instruction
    mret

# ============================================================
main_start:
    la   x1, handler
    csrw mtvec, x1             # mtvec = handler

# ================================================================
# TEST 1 - Write to read-only CSR (mhartid = 0xF14)
# Illegal because: decode_csr_ro && is_csr_write
# mtval must equal encoding of  csrrw x0, 0xF14, x1 = 0xF1409073
# ================================================================
test1:
    li   x1, 0xDEAD
    csrw 0xF14, x1             # illegal: mhartid[11:10]=11 = read-only

    li   x1, 1
    bne  x10, x1, test_fail    # handler must have been entered once

    li   x1, 2
    bne  x11, x1, test_fail    # mcause must be 2 (illegal instruction)

    li   x1, 0xF1409073
    bne  x12, x1, test_fail    # mtval must be faulting instruction encoding

test1_pass:
    addi x28, x28, 0x111
    sw   x12, 0(x31)           # checkpoint 0: mtval of illegal CSR write
    addi x29, x29, 1
    li   x27, 0x111
    bne  x28, x27, test_fail

# ================================================================
# TEST 2 - Access to unimplemented CSR (0x7FF)
# Illegal because: csr_not_implemented
# mtval must equal encoding of  csrrs x1, 0x7FF, x0 = 0x7FF02173
# ================================================================
test2:
    csrr x2, 0x7FF             # illegal: CSR 0x7FF not in the implemented set

    li   x1, 2
    bne  x10, x1, test_fail    # handler entry count must be 2

    li   x1, 2
    bne  x11, x1, test_fail    # mcause must be 2

    li   x1, 0x7FF02173
    bne  x12, x1, test_fail    # mtval must be faulting instruction encoding

test2_pass:
    addi x28, x28, 0x222
    sw   x12, 4(x31)           # checkpoint 1
    addi x29, x29, 1
    li   x27, 0x333
    bne  x28, x27, test_fail

# ================================================================
# TEST 3 - Undefined opcode (LOAD_FP = 7'b0000111, unimplemented)
# Illegal because: default case in outer opcode switch
# mtval must equal 0x00000007
# ================================================================
test3:
    .word 0x00000007           # opcode = LOAD_FP (7'b0000111), all other fields zero

    li   x1, 3
    bne  x10, x1, test_fail    # handler entry count must be 3

    li   x1, 2
    bne  x11, x1, test_fail    # mcause must be 2

    li   x1, 0x00000007
    bne  x12, x1, test_fail    # mtval must be 0x00000007

test3_pass:
    addi x28, x28, 0x444
    sw   x12, 8(x31)           # checkpoint 2
    addi x29, x29, 1
    li   x27, 0x777
    bne  x28, x27, test_fail

# ================================================================
# TEST 4 - STORE with reserved funct3=3 (SD in RV64, illegal in RV32I)
# Encoding: opcode=STORE(0100011), funct3=011, all other fields zero
#   -> 0x00003023
# Illegal because: funct3==3'b011 check in STORE decode
# ================================================================
test4:
    .word 0x00003023           # STORE funct3=011

    li   x1, 4
    bne  x10, x1, test_fail    # handler entry count must be 4

    li   x1, 2
    bne  x11, x1, test_fail    # mcause must be 2

    li   x1, 0x00003023
    bne  x12, x1, test_fail    # mtval must be 0x00003023

test4_pass:
    addi x28, x28, 0x555
    sw   x12, 12(x31)          # checkpoint 3
    addi x29, x29, 1
    li   x27, 0xCCC
    bne  x28, x27, test_fail

# ================================================================
# TEST 5 - JALR with reserved funct3=1
# Encoding: opcode=JALR(1100111), rd=x0, funct3=001, rs1=x0, imm=0
#   -> 0x00001067
# Illegal because: funct3 != 3'b000 check in JALR decode
# ================================================================
test5:
    .word 0x00001067           # JALR funct3=001

    li   x1, 5
    bne  x10, x1, test_fail    # handler entry count must be 5

    li   x1, 2
    bne  x11, x1, test_fail    # mcause must be 2

    li   x1, 0x00001067
    bne  x12, x1, test_fail    # mtval must be 0x00001067

test5_pass:
    addi x28, x28, 0x666
    sw   x12, 16(x31)          # checkpoint 4
    addi x29, x29, 1
    li   x27, 0x1332
    bne  x28, x27, test_fail

# ================================================================
# All tests passed
# ================================================================
all_tests_pass:
    li   x1, 5
    bne  x29, x1, test_fail
    li   x2, 0x1332
    bne  x28, x2, test_fail

    li   x1, 0xAABBCCDD
    sw   x1, 0(x30)
    j    end_program

test_fail:
    li   x1, 0xBADC0DE
    sw   x1, 0(x30)
    j    end_program

end_program:
    lui  x10, 0x50000
    sw   x0, 0(x10)

.data
