# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# RV32I M-mode Interrupt Test
# Tests: IRQ handler entry, MRET return, register preservation, MIE gate
#
# Final result will be 0xAABBCCDD only if all tests pass correctly

.option arch, +zicsr
.text
.globl _start

_start:
    lui  x31, 0x80000          # Checkpoint base: 0x80000000
    addi x31, x31, 0x700       # 0x80000700
    lui  x30, 0x40000          # Final result: 0x40000000
    li   x28, 0                # Accumulator
    li   x29, 0                # Test counter
    j    main_start

# ============================================================
# HANDLER 1 - test 1 (interrupt entry)
# ============================================================
handler1:
    addi x10, x10, 1
    csrr x15, mepc             # save mepc for boundary check
    lui  x5, 0x2004            # mtimecmp base: 0x02004000
    li   x6, -1
    sw   x6, 0(x5)             # mtimecmp[31:0]  = 0xFFFFFFFF (suppress IRQ)
    sw   x6, 4(x5)             # mtimecmp[63:32] = 0xFFFFFFFF
    mret

# ============================================================
# HANDLER 2 - tests 2 and 3 (MRET return, register integrity)
# ============================================================
handler2:
    li   x12, 0xBEEF
    lui  x5, 0x2004            # mtimecmp base: 0x02004000
    li   x6, -1
    sw   x6, 0(x5)             # mtimecmp[31:0]  = 0xFFFFFFFF (suppress IRQ)
    sw   x6, 4(x5)             # mtimecmp[63:32] = 0xFFFFFFFF
    mret

# ============================================================
# HANDLER 4 - test 4 (WFI)
# ============================================================
handler4:
    addi x10, x10, 1
    lui  x5, 0x2004            # disable timer
    li   x6, -1
    sw   x6, 0(x5)             # mtimecmp[31:0]  = 0xFFFFFFFF
    sw   x6, 4(x5)             # mtimecmp[63:32] = 0xFFFFFFFF
    csrr x15, mepc             # save mepc for the boundary check
    mret

# ============================================================
# HANDLER 3 - test 3 (MIE gate)
# Must NEVER execute: IRQ cannot be taken with MIE = 0.
# Increments x14 to leave a detectable trace if called.
# ============================================================
handler3:
    addi x14, x14, 1
    lui  x5, 0x2004            # mtimecmp base: 0x02004000
    li   x6, -1
    sw   x6, 0(x5)             # mtimecmp[31:0]  = 0xFFFFFFFF (suppress IRQ)
    sw   x6, 4(x5)             # mtimecmp[63:32] = 0xFFFFFFFF
    mret

# ============================================================
main_start:

# ================================================================
# TEST 1 - interrupt handler is entered
#
# Pass: x10 == 1  (handler called exactly once)
# Fail: timeout (handler never entered) or x10 != 1
# ================================================================
test1:
    li   x10, 0                # x10 = handler_count

    la   x1, handler1
    csrw 0x305, x1             # mtvec = handler1

    # Reset mtime to 0 (addr 0x0200BFF8 = lui 0x200C + addi -8)
    lui  x5, 0x200C
    sw   x0, -8(x5)            # mtime[31:0]  = 0  (0x0200BFF8)
    sw   x0, -4(x5)            # mtime[63:32] = 0  (0x0200BFFC)

    # Set mtimecmp = 64 (addr 0x02004000)
    lui  x5, 0x2004
    li   x6, 64
    sw   x6, 0(x5)             # mtimecmp[31:0]  = 64 (fire after 64 ticks)
    sw   x0, 4(x5)             # mtimecmp[63:32] = 0

    li   x6, 4096              # spin limit

    li   x1, 0x80
    csrw mie, x1               # mie.MTIE = 1 (bit 7)
    li   x1, 8
    csrw mstatus, x1           # mstatus.MIE = 1
test1_spin:
    bnez x10, test1_done       # exit when handler has fired
    addi x6, x6, -1
    bnez x6, test1_spin
    j    test_fail             # timeout: handler never called

test1_done:
    csrw mstatus, x0           # disable MIE

    li   x1, 1
    bne  x10, x1, test_fail    # must be exactly 1 (single entry, timer disabled)

    # Verify mepc was within the spin loop: test1_spin <= mepc <= test1_spin+8
    la   x1, test1_spin
    bltu x15, x1, test_fail    # mepc before spin loop - fail
    addi x1, x1, 8             # last valid mepc = 3rd instruction of spin loop
    bgtu x15, x1, test_fail    # mepc after spin loop - fail

    sw   x15, 4(x31)           # checkpoint: mepc value (expect within spin loop)

test1_pass:
    addi x28, x28, 0x111
    sw   x10, 0(x31)           # checkpoint 0: handler_count (expect 1)
    addi x29, x29, 1
    li   x27, 0x111
    bne  x28, x27, test_fail

# ================================================================
# TEST 2 - MRET returns execution to main code
#
# The spin loop can only be running (and exit) if MRET returned us
# to it.  Staying stuck inside the handler makes the loop invisible.
#
# Pass: x11 == 0xAA55  (register integrity)
#       x12 == 0xBEEF  (handler was entered)
#       x13 == 1       (main code continued after MRET)
# ================================================================
test2:
    li   x11, 0xAA55           # sentinel
    li   x12, 0                # handler marker
    li   x13, 0                # post-interrupt step counter

    la   x1, handler2
    csrw mtvec, x1             # mtvec = handler2

    # Reset mtime to 0 (addr 0x0200BFF8 = lui 0x200C + addi -8)
    lui  x5, 0x200C
    sw   x0, -8(x5)            # mtime[31:0]  = 0  (0x0200BFF8)
    sw   x0, -4(x5)            # mtime[63:32] = 0  (0x0200BFFC)

    # Set mtimecmp = 64
    lui  x5, 0x2004
    li   x6, 64
    sw   x6, 0(x5)             # mtimecmp[31:0]  = 64
    sw   x0, 4(x5)             # mtimecmp[63:32] = 0

    li   x6, 4096
    li   x7, 0xBEEF

    li   x1, 0x80
    csrw mie, x1               # mie.MTIE = 1
    li   x1, 8
    csrw mstatus, x1           # MIE = 1
test2_spin:
    beq  x12, x7, test2_done   # handler ran AND MRET brought us back
    addi x6, x6, -1
    bnez x6, test2_spin
    j    test_fail             # timeout: MRET never returned to main code

test2_done:
    csrw mstatus, x0           # disable MIE
    addi x13, x13, 1           # main code continues here after MRET

    li   x1, 0xAA55
    bne  x11, x1, test_fail    # x11 was modified by handler - fail
    li   x1, 0xBEEF
    bne  x12, x1, test_fail    # handler marker not set - fail
    li   x1, 1
    bne  x13, x1, test_fail    # main code did not resume - fail

test2_pass:
    addi x28, x28, 0x222
    sw   x11, 4(x31)           # checkpoint 1: sentinel (expect 0xAA55)
    addi x29, x29, 1
    li   x27, 0x333
    bne  x28, x27, test_fail

# ================================================================
# TEST 3 - MIE = 0 prevents handler from being called
#
# Pass: x14 == 0 throughout (IRQ never taken)
# Fail: x14 != 0 (interrupt taken despite MIE=0)
# ================================================================
test3:
    li   x14, 0                # spurious-entry counter

    la   x1, handler3
    csrw mtvec, x1             # mtvec = handler3

    # Reset mtime to 0 (addr 0x0200BFF8 = lui 0x200C + addi -8)
    lui  x5, 0x200C
    sw   x0, -8(x5)            # mtime[31:0]  = 0  (0x0200BFF8)
    sw   x0, -4(x5)            # mtime[63:32] = 0  (0x0200BFFC)

    # Set mtimecmp = 64
    lui  x5, 0x2004
    li   x6, 64
    sw   x6, 0(x5)             # mtimecmp[31:0]  = 64
    sw   x0, 4(x5)             # mtimecmp[63:32] = 0
    # MIE intentionally NOT enabled

    li   x6, 1024
test3_spin:
    bnez x14, test_fail        # handler fired with MIE=0 - fail
    addi x6, x6, -1
    bnez x6, test3_spin

    # clean up: set mtimecmp to max to suppress IRQ
    lui  x5, 0x2004
    li   x6, -1
    sw   x6, 0(x5)             # mtimecmp[31:0]  = 0xFFFFFFFF
    sw   x6, 4(x5)             # mtimecmp[63:32] = 0xFFFFFFFF

test3_pass:
    addi x28, x28, 0x333
    sw   x14, 8(x31)           # checkpoint 2: must be 0
    addi x29, x29, 1
    li   x27, 0x666
    bne  x28, x27, test_fail

# ================================================================
# TEST 4 - WFI suspends execution until interrupt wakes it
# ================================================================
test4:
    li   x10, 0                # handler entry counter

    la   x1, handler4
    csrw mtvec, x1             # mtvec = handler4

    lui  x5, 0x200C
    sw   x0, -8(x5)            # mtime[31:0]  = 0
    sw   x0, -4(x5)            # mtime[63:32] = 0

    lui  x5, 0x2004
    li   x6, 64
    sw   x6, 0(x5)             # mtimecmp[31:0]  = 64
    sw   x0, 4(x5)             # mtimecmp[63:32] = 0

    li   x1, 0x80
    csrw mie, x1               # mie.MTIE = 1
    li   x1, 8
    csrw mstatus, x1           # mstatus.MIE = 1

    wfi                        # suspend here until timer fires

    # MRET from handler resumes
test4_after:
    csrw mstatus, x0           # disable MIE

    li   x1, 1
    bne  x10, x1, test_fail    # handler must have been entered exactly once
    la   x1, test4_after
    bne  x15, x1, test_fail    # mepc must point past the WFI

test4_pass:
    addi x28, x28, 0x444
    sw   x10, 12(x31)          # checkpoint 3: handler entry count (expect 1)
    addi x29, x29, 1
    li   x27, 0xAAA
    bne  x28, x27, test_fail

# ================================================================
# All tests passed
# ================================================================
all_tests_pass:
    li   x1, 4
    bne  x29, x1, test_fail
    li   x2, 0xAAA
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
    sw   x0, 0(x10)            # halt: write to END_ADDRESS (0x50000000)

.data
