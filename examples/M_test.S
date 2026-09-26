.option arch, +m
.text
.globl _start   

_start:

# signed multiplication
    addi  x5, x0, 0x3        
    addi  x6, x0, 0x3
    mul  x7, x5, x6      

    lui x8, 0x40000

    addi x9,x0, 0xE
    sw x9,0(x8)

    addi x10,x0, 0x9

    bne x7,x10,skip

    # signed division
    addi x5,x0,0x8
    addi x6,x0,0x3
    div  x7,x5,x6

    addi x10, x0, 0x2
    bne x10, x7, skip


    addi x5,x0, -7
    addi x6,x0, -3
    div  x7,x5,x6

    addi x10, x0, 2
    bne x10, x7, skip   


    addi x5,x0,0x8
    addi x6,x0,0x0
    div  x7,x5,x6

    li x10, 0xFFFFFFFF
    bne x10, x7, skip   


    li x5,0x00123456
    li x6, 0x00876543
    mul  x7,x5,x6

    li x10, 0xCCC3A082
    bne x10, x7, skip 


    li x5,0x00123456
    li x6, 0x00876543
    mulh  x7,x5,x6

    li x10, 0x000009A0
    bne x10, x7, skip 


    li x5, 0x00000056
    li x6, 0xFFFFFFFF
    mul  x7,x5,x6

    li x10, 0xFFFFFFAA
    #bne x10, x7, skip 


    li x5, 0x00000056
    li x6, 0xFFFFFFFF
    mulh  x7,x5,x6

    li x10, 0xFFFFFFFF 
    bne x10, x7, skip 


    li x5, 0xFFFFFFAA
    li x6, 0xFFFFFFFF
    mul  x7,x5,x6

    li x10, 0x00000056
    bne x10, x7, skip 

# unsigned multiplication

    li x5, 0x80000000
    li x6, 0x00000002
    mulhu  x7,x5,x6

    li x10, 0x00000001
    bne x10, x7, skip


    li x5, 0x80000000
    li x6, 0x00000002
    mulhsu  x7,x5,x6

    li x10, 0xFFFFFFFF
    bne x10, x7, skip 


    li x5, 0x00000002
    li x6, 0x80000000
    mulhsu  x7,x5,x6

    li x10, 0x00000001
    bne x10, x7, skip


# signed remainder 
    addi x5,x0,0x8
    addi x6,x0,0x3
    rem  x7,x5,x6

    addi x10, x0, 0x2
    bne x10, x7, skip


    addi x5,x0, -7
    addi x6,x0, -3
    rem  x7,x5,x6

    addi x10, x0, -1
    bne x10, x7, skip   


    addi x5,x0,0x8
    addi x6,x0,0x0
    rem  x7,x5,x6

    addi x10, x0, 0x08
    bne x10, x7, skip   


    li x5,0x80000000
    addi x6,x0, -1
    rem  x7,x5,x6

    addi x10, x0, 0x0
    bne x10, x7, skip 

# signed division
    addi x5,x0,0x8
    addi x6,x0,0x3
    div  x7,x5,x6

    addi x10, x0, 0x2
    bne x10, x7, skip


    addi x5,x0, -7
    addi x6,x0, -3
    div  x7,x5,x6

    addi x10, x0, 2
    bne x10, x7, skip   


    addi x5,x0,0x8
    addi x6,x0,0x0
    div  x7,x5,x6

    li x10, 0xFFFFFFFF
    bne x10, x7, skip   


    li x5,0x80000000
    addi x6,x0, -1
    div  x7,x5,x6

    li x10, 0x80000000
    bne x10, x7, skip   


# unsigned division and remainder

    li x5,0x80000000
    li x6, 0xFFFFFFFF
    divu  x7,x5,x6

    li x10, 0x00000000
    bne x10, x7, skip 

    li x5,0x80000000
    li x6, 0xFFFFFFFF
    remu  x7,x5,x6

    li x10, 0x80000000
    bne x10, x7, skip   


# if everything is working correctly the LEDs are all on, otherwise only LD0 is on.
    addi x11,x0, 0xF
    sw x11, 0(x8)
    j end_program 

skip:

    addi x11,x0, 0x1
    sw x11, 0(x8)

end_program:
    lui  x12, 0x50000
    sw   x0, 0(x12)            # halt: write to END_ADDRESS (0x50000000)
