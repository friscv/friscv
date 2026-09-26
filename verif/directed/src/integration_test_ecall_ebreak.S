# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# RV32I ECALL/EBREAK Exception Integration Test
# Tests: exception entry, mcause values, mepc accuracy,
#        MIE=0 does not gate exceptions, mstatus state machine,
#        vectored mtvec uses base address for exceptions

.option arch, +zicsr
.text
.globl _start

_start:
    lui  x31, 0x80001          # Checkpoint base: 0x80000800
    addi x31, x31, -0x800      # = 0x80001000 - 0x800 = 0x80000800
    lui  x30, 0x40000          # Final result address: 0x40000000
    li   x28, 0                # Accumulator
    li   x29, 0                # Test counter

    # Suppress timer interrupt for the entire test
    csrw mie, x0

    j    main_start

# ============================================================
# HANDLER 1 - TEST 1
# ECALL taken despite mstatus.MIE=0: proves exceptions bypass MIE gate.
# Sets x10=1, advances mepc past ecall, returns.
# ============================================================
handler1:
    addi x10, x10, 1           # x10: handler entry count
    csrr x1, mepc
    addi x1, x1, 4
    csrw mepc, x1              # mepc += 4  (skip past ecall)
    mret

# ============================================================
# HANDLER 2 - TEST 2
# Saves mepc into x15 before advancing it, then returns.
# Caller verifies x15 == exact address of the ecall instruction.
# ============================================================
handler2:
    csrr x15, mepc             # save mepc before advancing
    csrr x1,  mepc
    addi x1, x1, 4
    csrw mepc, x1
    mret

# ============================================================
# HANDLER 3 - TEST 3
# EBREAK taken: sets x11=1, advances mepc past ebreak, returns.
# ============================================================
handler3:
    addi x11, x11, 1           # x11: ebreak handler entry count
    csrr x1, mepc
    addi x1, x1, 4
    csrw mepc, x1
    mret

# ============================================================
# HANDLER 4 - TEST 4
# Captures full mstatus at trap entry into x16, advances mepc, returns.
# ============================================================
handler4:
    csrr x16, mstatus          # capture mstatus at trap entry
    csrr x1,  mepc
    addi x1, x1, 4
    csrw mepc, x1
    mret

# ============================================================
# HANDLER 5 - TEST 5
# ECALL in vectored mtvec mode (mtvec[0]=1) must still land at the
# base address, NOT at base + cause*4.
# Sets x14=1, advances mepc, returns.
# ============================================================
handler5:
    addi x14, x14, 1           # x14: vectored-mode handler entry count
    csrr x1, mepc
    addi x1, x1, 4
    csrw mepc, x1
    mret

# ============================================================
main_start:

# ================================================================
# TEST 1 - ECALL entered despite mstatus.MIE = 0
# Synchronous exceptions are unconditional: mstatus.MIE must not gate them.
# ================================================================
test1:
    li   x10, 0
    csrw mstatus, x0           # mstatus.MIE = 0

    la   x1, handler1
    csrw mtvec, x1             # mtvec = handler1 (direct mode)

    ecall                      # cause=11, mepc=&ecall; handler runs and mrets here

    li   x1, 1
    bne  x10, x1, test_fail    # handler was not entered

    csrr x2, mcause            # mcause
    li   x1, 11
    bne  x2, x1, test_fail     # mcause != 11

test1_pass:
    addi x28, x28, 0x111
    sw   x10, 0(x31)
    addi x29, x29, 1
    li   x27, 0x111
    bne  x28, x27, test_fail

# ================================================================
# TEST 2 - mepc points to the ECALL instruction itself
# The spec requires mepc = PC of the trapping instruction (not PC+4).
# ================================================================
test2:
    la   x1, handler2
    csrw mtvec, x1             # mtvec = handler2

test2_ecall:
    ecall                      # handler2 saves mepc in x15, advances, mrets

    la   x1, test2_ecall
    bne  x15, x1, test_fail    # mepc != address of ecall instruction

test2_pass:
    addi x28, x28, 0x222
    sw   x15, 4(x31)
    addi x29, x29, 1
    li   x27, 0x333
    bne  x28, x27, test_fail

# ================================================================
# TEST 3 - EBREAK is taken, mcause == 3
# ================================================================
test3:
    li   x11, 0

    la   x1, handler3
    csrw mtvec, x1             # mtvec = handler3

    ebreak                     # cause=3, mepc=&ebreak; handler runs and mrets here

    li   x1, 1
    bne  x11, x1, test_fail    # ebreak handler not entered

    csrr x2, mcause            # mcause
    li   x1, 3
    bne  x2, x1, test_fail     # mcause != 3

test3_pass:
    addi x28, x28, 0x333
    sw   x11, 8(x31)
    addi x29, x29, 1
    li   x27, 0x666
    bne  x28, x27, test_fail

# ================================================================
# TEST 4 - mstatus state machine on trap entry and MRET
# Before ECALL: mstatus.MIE = 1
# On entry:     MIE must be cleared (0), MPIE must hold old MIE (1)
# After MRET:   MIE must be restored to 1
# ================================================================
test4:
    li   x16, 0                # will be overwritten by handler4

    la   x1, handler4
    csrw mtvec, x1             # mtvec = handler4

    li   x1, 8
    csrw mstatus, x1           # mstatus.MIE = 1 (bit 3); mie reg = 0 so no IRQ fires

    ecall                      # handler4 captures mstatus into x16, advances mepc, mrets

    # Check mie (bit 3) was 0 on trap entry (cleared by hardware)
    andi x1, x16, 8
    bnez x1, test_fail         # mie was not cleared on entry

    # Check mpie (bit 7) was 1 on trap entry (= old mie = 1)
    andi x1, x16, 0x80
    beqz x1, test_fail         # mpie was not set to old mie

    # Check mstatus.MIE is restored to 1 after MRET (mie <= mpie)
    csrr x1, mstatus
    andi x1, x1, 8
    beqz x1, test_fail         # mie not restored after mret

    csrw mstatus, x0           # clear mstatus.MIE for remainder of test

test4_pass:
    addi x28, x28, 0x444
    sw   x16, 12(x31)
    addi x29, x29, 1
    li   x27, 0xAAA
    bne  x28, x27, test_fail

# ================================================================
# TEST 5 - Vectored mtvec uses base address for exceptions
# ================================================================
test5:
    li   x14, 0

    la   x1, handler5
    ori  x1, x1, 1             # set mtvec[0]=1 (vectored mode)
    csrw mtvec, x1             # mtvec = handler5 | 1

    ecall                      # cause=11; must go to base (handler5), not base+44

    li   x1, 1
    bne  x14, x1, test_fail    # handler5 was not entered (wrong address used)

test5_pass:
    addi x28, x28, 0x555
    sw   x14, 16(x31)
    addi x29, x29, 1
    li   x27, 0xFFF
    bne  x28, x27, test_fail

# ================================================================
# All tests passed
# ================================================================
all_tests_pass:
    li   x1, 5
    bne  x29, x1, test_fail
    li   x2, 0xFFF
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
