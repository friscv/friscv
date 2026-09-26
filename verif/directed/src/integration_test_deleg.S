# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# RV32I Supervisor-mode Delegation Integration Test
#
# Tests exception delegation via medeleg/mideleg:
#   TEST 1 - S-mode ecall delegated to stvec
#   TEST 2 - SIE cleared on entry, SPIE=old SIE, sepc=ecall addr, SIE restored by SRET
#   TEST 3 - S-mode ecall NOT delegated (medeleg[9]=0) goes to mtvec (mcause=9)
#   TEST 4 - M-mode ecall not delegated even when medeleg[11]=1 (mcause=11)
#   TEST 5 - SRET restores U-mode (SPP=0); U-mode ecall goes to mtvec (mcause=8)

.option arch, +zicsr
.text
.globl _start

_start:
    lui  x31, 0x80001
    addi x31, x31, -0x800      # checkpoint base = 0x80000800
    lui  x30, 0x40000          # result address  = 0x40000000
    li   x28, 0
    li   x29, 0
    csrw mie, x0               # disable all interrupts

    li   t0, 0xFFFFFFFF      # NAPOT covering the whole address space
    csrw pmpaddr0, t0
    li   t0, 0x1F            # L=0, A=NAPOT, X=1, W=1, R=1
    csrw pmpcfg0, t0

    j    main_start

# ================================================================
# M-MODE HANDLERS
# ================================================================

# Generic exit: return to M-mode at x25.
# Used when an illegal instruction in S-mode code needs to bring
# execution back to M-mode.  Sets mpp=M_MODE so mret goes there.
m_handler_exit:
    li   x1, 0x1800            # mstatus.mpp = M_MODE (2'b11 << 11)
    csrw mstatus, x1
    csrw mepc, x25
    mret

# TEST 3: S-mode ecall, medeleg[9]=0 => this M-mode handler fires.
# Captures mcause, then returns to M-mode at x25.
m_handler_t3:
    addi x20, x20, 1
    csrr x21, mcause
    li   x1, 0x1800
    csrw mstatus, x1
    csrw mepc, x25
    mret

# TEST 4: M-mode ecall; medeleg[11]=1 but privilege==M so not delegated.
# Normal mret back to M-mode code (mepc already points past ecall).
m_handler_t4:
    addi x22, x22, 1
    csrr x23, mcause
    csrr x1, mepc
    addi x1, x1, 4
    csrw mepc, x1
    mret

# TEST 5: U-mode ecall => M-mode.  Captures mcause, returns to M-mode at x25.
m_handler_t5:
    addi x24, x24, 1
    csrr x26, mcause
    li   x1, 0x1800
    csrw mstatus, x1
    csrw mepc, x25
    mret

# ================================================================
# S-MODE HANDLERS
# ================================================================

# TEST 1: Basic delegation.  Counts entries, captures scause.
s_handler_t1:
    addi x10, x10, 1
    csrr x12, scause
    csrr x1, sepc
    addi x1, x1, 4
    csrw sepc, x1
    sret

# TEST 2: SIE state machine + sepc accuracy.
# Captures sstatus at trap entry (SIE must be 0, SPIE must be 1).
# Captures sepc (must equal address of the ecall instruction).
s_handler_t2:
    csrr x13, sstatus          # SIE cleared, SPIE=old SIE on entry
    csrr x14, sepc             # must equal address of ecall instruction
    csrr x1, sepc
    addi x1, x1, 4
    csrw sepc, x1
    sret

# TEST 5: Clears SPP so sret returns to U-mode.
s_handler_t5:
    csrw sstatus, x0           # clear spp(8),spie(5),sie(1) -> sret goes to U_MODE
    csrr x1, sepc
    addi x1, x1, 4
    csrw sepc, x1
    sret                       # privilege = spp = 0 = U_MODE

# ================================================================
main_start:

# ================================================================
# TEST 1: Ecall from S-mode delegated to stvec (scause = 9)
# ================================================================
test1:
    li   x10, 0
    li   x12, 0

    la   x25, verify_t1        # m_handler_exit jumps here
    la   x1, m_handler_exit
    csrw mtvec, x1

    li   x1, (1 << 9)          # delegate cause 9 (S-mode ecall) to S-mode
    csrw medeleg, x1

    la   x1, s_handler_t1
    csrw stvec, x1             # direct mode

    li   x1, 0x800             # mstatus.mpp = S_MODE (01 << 11)
    csrw mstatus, x1
    la   x1, s_code_t1
    csrw mepc, x1
    mret                       # -> S-mode

s_code_t1:
    ecall                      # cause=9, medeleg[9]=1 -> s_handler_t1 via stvec
    .word 0x00000000           # illegal inst -> m_handler_exit -> verify_t1

verify_t1:
    li   x1, 1
    bne  x10, x1, test_fail    # s_handler_t1 not entered

    li   x1, 9
    bne  x12, x1, test_fail    # scause != 9

test1_pass:
    addi x28, x28, 0x111
    sw   x10, 0(x31)
    addi x29, x29, 1
    li   x27, 0x111
    bne  x28, x27, test_fail

# ================================================================
# TEST 2: SIE cleared on entry, SPIE=1, sepc accurate, SIE restored by SRET
# ================================================================
test2:
    li   x13, 0
    li   x14, 0
    li   x16, 0

    la   x25, verify_t2
    la   x1, m_handler_exit
    csrw mtvec, x1

    li   x1, (1 << 9)
    csrw medeleg, x1

    la   x1, s_handler_t2
    csrw stvec, x1

    # Enter S-mode with SIE=1 (bit 1) and MPP=S_MODE (bit 12:11 = 01 = 0x800)
    li   x1, 0x802
    csrw mstatus, x1
    la   x1, s_code_t2
    csrw mepc, x1
    mret

s_code_t2:
test2_ecall:
    ecall                      # -> s_handler_t2; SIE should be cleared on entry
    csrr x16, sstatus          # x16 = sstatus after sret; SIE should be restored
    .word 0x00000000           # -> m_handler_exit -> verify_t2

verify_t2:
    # SIE (bit 1) must be 0 on trap entry
    andi x1, x13, 2
    bnez x1, test_fail

    # SPIE (bit 5) must be 1 (= old SIE = 1)
    andi x1, x13, 0x20
    beqz x1, test_fail

    # SIE (bit 1) must be 1 after sret (restored from SPIE)
    andi x1, x16, 2
    beqz x1, test_fail

    # sepc must point to the ecall instruction itself
    la   x1, test2_ecall
    bne  x14, x1, test_fail

test2_pass:
    addi x28, x28, 0x222
    sw   x13, 4(x31)
    addi x29, x29, 1
    li   x27, 0x333
    bne  x28, x27, test_fail

# ================================================================
# TEST 3: S-mode ecall NOT delegated (medeleg[9]=0) -> mtvec, mcause=9
# ================================================================
test3:
    li   x20, 0
    li   x21, 0

    la   x25, verify_t3
    la   x1, m_handler_t3
    csrw mtvec, x1

    csrw medeleg, x0           # clear all delegation

    li   x1, 0x800             # mstatus.mpp = S_MODE
    csrw mstatus, x1
    la   x1, s_code_t3
    csrw mepc, x1
    mret

s_code_t3:
    ecall                      # cause=9, medeleg[9]=0 -> mtvec (m_handler_t3)
    nop                        # unreachable; m_handler_t3 redirects to verify_t3

verify_t3:
    li   x1, 1
    bne  x20, x1, test_fail    # m_handler_t3 not entered

    li   x1, 9
    bne  x21, x1, test_fail    # mcause != 9

test3_pass:
    addi x28, x28, 0x333
    sw   x21, 8(x31)
    addi x29, x29, 1
    li   x27, 0x666
    bne  x28, x27, test_fail

# ================================================================
# TEST 4: M-mode ecall not delegated even with medeleg[11]=1 (mcause=11)
# ================================================================
test4:
    li   x22, 0
    li   x23, 0

    la   x1, m_handler_t4
    csrw mtvec, x1

    li   x1, (1 << 11)         # medeleg[11] = 1 (M-mode ecall cause)
    csrw medeleg, x1

    csrw mstatus, x0           # MIE=0, already in M-mode

    ecall                      # cause=11; is_delegated=0 (M_MODE src) -> m_handler_t4

    li   x1, 1
    bne  x22, x1, test_fail    # handler not entered

    li   x1, 11
    bne  x23, x1, test_fail    # mcause != 11

test4_pass:
    addi x28, x28, 0x444
    sw   x23, 12(x31)
    addi x29, x29, 1
    li   x27, 0xAAA
    bne  x28, x27, test_fail

# ================================================================
# TEST 5: SRET restores U-mode (SPP=0); U-mode ecall -> mtvec (mcause=8)
# ================================================================
test5:
    li   x24, 0
    li   x26, 0

    la   x25, verify_t5
    la   x1, m_handler_t5
    csrw mtvec, x1

    # Delegate cause 9 (S-ecall) so first ecall in S-mode goes to s_handler_t5
    li   x1, (1 << 9)
    csrw medeleg, x1

    la   x1, s_handler_t5
    csrw stvec, x1

    li   x1, 0x800             # mstatus.mpp = S_MODE
    csrw mstatus, x1
    la   x1, s_code_t5
    csrw mepc, x1
    mret

s_code_t5:
    ecall                      # cause=9, delegated -> s_handler_t5; clears SPP, sret -> U-mode
    # Now in U-mode (sret with SPP=0):
    ecall                      # cause=8 (U-mode ecall), medeleg[8]=0 -> m_handler_t5 -> verify_t5
    nop                        # unreachable

verify_t5:
    li   x1, 1
    bne  x24, x1, test_fail    # m_handler_t5 not entered

    li   x1, 8
    bne  x26, x1, test_fail    # mcause != 8 (not a U-mode ecall)

test5_pass:
    addi x28, x28, 0x555
    sw   x26, 16(x31)
    addi x29, x29, 1
    li   x27, 0xFFF
    bne  x28, x27, test_fail

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

end_program:
    lui  x10, 0x50000
    sw   x0, 0(x10)

.data
