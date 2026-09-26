.option arch, +zicsr
.text
.globl _start

_start:
    j _start2

interrupt_handler:
    li t3, 0x02000000
    li t4, -1
    sw t4, 0(t3)
    sw t4, 4(t3)
    sw x0, 8(t3)
    sw x0, 12(t3)
    
    li t0, 0x40000000
    li t1, 0xF
    sw t1, 0(t0) #LEDs turning on
    
    li t2, 0x100000
delay: addi t2, t2, -1 
    bnez t2, delay
    mret

_start2:
    la t0, interrupt_handler
    csrw 0x305, t0 #mtvec 
    
    li t0, 0x02000000
    li t1, 0x8FFFFFFF   
    sw t1, 0(t0)
    sw x0, 4(t0)
    
    li t0, 8
    csrw 0x300, t0

loop:
    li t0, 0x40000000
    sw x0, 0(t0) #LEDs turning off
    j loop
