.option arch, +zicsr
.text
.globl _start

.equ TIMER_CONST, 5000000 

_start:
    j     main

.balign 4
timer_handler:
    addi  sp, sp, -12
    sw    t0, 0(sp)
    sw    t1, 4(sp)
    sw    t2, 8(sp)

    # Reset mtime to 0 so the next IRQ fires in exactly 0.5 s
    li    t0, 0x0200BFF8
    sw    x0, 0(t0)           # mtime lo = 0
    sw    x0, 4(t0)           # mtime hi = 0

    # Toggle led_state
    la    t1, led_state
    lw    t2, 0(t1)
    xori  t2, t2, 1
    sw    t2, 0(t1)
    li    t0, 0x40000000
    sw    t2, 0(t0)

    lw    t0, 0(sp)
    lw    t1, 4(sp)
    lw    t2, 8(sp)
    addi  sp, sp, 12
    mret

# ----------------------------------------------------------------
# Main
# ----------------------------------------------------------------
main:
    li    sp, 0x80000800

    la    t0, timer_handler
    csrw  0x305, t0           # mtvec

    la    t0, led_state
    sw    x0, 0(t0)
    li    t0, 0x40000000
    sw    x0, 0(t0)

    # Reset mtime to 0
    li    t0, 0x0200BFF8
    sw    x0, 0(t0)           # mtime lo = 0
    sw    x0, 4(t0)           # mtime hi = 0

    # Set mtimecmp = TIMER_CONST cycles
    li    t0, 0x02004000
    li    t1, TIMER_CONST
    sw    t1, 0(t0)           # mtimecmp lo
    sw    x0, 4(t0)           # mtimecmp hi = 0

    # Enable machine timer interrupt (MTIE) and global machine interrupts (MIE)
    li    t0, 0x80            # MTIE = bit 7
    csrw  0x304, t0           # mie
    li    t0, 8               # MIE = bit 3
    csrw  0x300, t0           # mstatus

idle:
    j     idle

.data
led_state:
    .word 0
