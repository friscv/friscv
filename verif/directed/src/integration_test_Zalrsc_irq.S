# Copyright 2026 FER, HPC Architecture and Application Research Center
# SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
#
# Licensed under the Solderpad Hardware License v 2.1 (the "License");
# you may not use this file except in compliance with the License, or,
# at your option, the Apache License version 2.0.
# You may obtain a copy of the License at https://solderpad.org/licenses/SHL-2.1/
#
# Emil Popovic <mail@emilpopovic.me>

# RV32IA Zalrsc + Interrupt Test
# Tests: interrupt clears LR reservation (SC.W must fail after IRQ),
#        SC.W succeeds without interrupt (control test).
#
# Final result: 0xAABBCCDD only if all tests pass

.option arch, +zicsr
.option arch, +a
.text
.globl _start

_start:
    lui  x31, 0x80000          # Checkpoint base: 0x80000000
    addi x31, x31, 0x700       # 0x80000700
    lui  x30, 0x40000          # Final result addr: 0x40000000
    li   x28, 0                # Accumulator
    li   x29, 0                # Test counter
    lui  x4, 0x80000           # LR/SC target high: 0x80000000
    addi x4, x4, 0x400         # 0x80000400
    j    main_start

# ============================================================
# HANDLER - fires on timer IRQ
# ============================================================
handler:
    addi x10, x10, 1
    lui  x5, 0x2004            # mtimecmp base: 0x02004000
    li   x6, -1
    sw   x6, 0(x5)             # mtimecmp[31:0]  = 0xFFFFFFFF (suppress IRQ)
    sw   x6, 4(x5)             # mtimecmp[63:32] = 0xFFFFFFFF
    mret

# ============================================================
main_start:

# ================================================================
# TEST 1 - Interrupt clears LR reservation -> SC.W must fail
# ================================================================
test1:
    li   x10, 0                # interrupt fired flag

    la   x1, handler
    csrw mtvec, x1             # mtvec = handler

    li   x7, 0xCAFEBABE
    sw   x7, 0(x4)             # store sentinel at LR/SC target

    lr.w x2, (x4)              # load-reserve (establishes reservation)

    # Reset mtime to 0 (addr 0x0200BFF8 = lui 0x200C + addi -8)
    lui  x5, 0x200C
    sw   x0, -8(x5)            # mtime[31:0]  = 0  (0x0200BFF8)
    sw   x0, -4(x5)            # mtime[63:32] = 0  (0x0200BFFC)

    # Set mtimecmp = 64 (addr 0x02004000)
    lui  x5, 0x2004
    li   x6, 64
    sw   x6, 0(x5)             # mtimecmp[31:0]  = 64 (fire after 64 ticks)
    sw   x0, 4(x5)             # mtimecmp[63:32] = 0

    li   x1, 0x80
    csrw mie, x1               # mie.MTIE = 1 (bit 7)
    li   x1, 8
    csrw mstatus, x1           # mstatus.MIE = 1

    li   x6, 4096
test1_spin:
    bnez x10, test1_irq_done   # exit when handler has fired
    addi x6, x6, -1
    bnez x6, test1_spin
    j    test_fail             # timeout: handler never called

test1_irq_done:
    csrw mie, x0               # disable MIE

    li   x7, 0x12345678        # value to attempt to store
    sc.w x8, x7, (x4)          # SC.W: must FAIL (reservation cleared by IRQ)

    li   x1, 1
    bne  x8, x1, test_fail     # SC.W result must be 1 (failure)

    lw   x9, 0(x4)             # read memory: must be unchanged
    li   x1, 0xCAFEBABE
    bne  x9, x1, test_fail     # memory was incorrectly modified

test1_pass:
    addi x28, x28, 0x111
    sw   x8, 0(x31)            # checkpoint 0: SC result (expect 1)
    addi x29, x29, 1
    li   x27, 0x111
    bne  x28, x27, test_fail

# ================================================================
# TEST 2 - SC.W succeeds when no interrupt occurred (MIE = 0)
# ================================================================
test2:
    li   x1, 0xABCD1234
    sw   x1, 0(x4)             # store new sentinel at LR/SC target

    lr.w x2, (x4)              # load-reserve; x2 should = 0xABCD1234

    li   x7, 0x55AA55AA        # new value to write
    sc.w x8, x7, (x4)          # SC.W: must SUCCEED (no interrupt, MIE=0)

    li   x1, 0
    bne  x8, x1, test_fail     # SC.W result must be 0 (success)

    lw   x9, 0(x4)             # read memory: must hold new value
    li   x1, 0x55AA55AA
    bne  x9, x1, test_fail     # memory was not updated

    li   x1, 0xABCD1234
    bne  x2, x1, test_fail     # LR.W must have read the sentinel

test2_pass:
    addi x28, x28, 0x222
    sw   x8, 4(x31)            # checkpoint 1: SC result (expect 0)
    addi x29, x29, 1
    li   x27, 0x333
    bne  x28, x27, test_fail

# ================================================================
# All tests passed
# ================================================================
all_tests_pass:
    li   x1, 2
    bne  x29, x1, test_fail
    li   x2, 0x333
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
