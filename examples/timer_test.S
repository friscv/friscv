.text
.globl _start

_start:
    li x10, 0x02000000    #timer address
    li x11, 0x40000000    #LED address
    
loop:
    lw x12, 8(x10)        #reading the counter
    srli x12, x12, 28     #shift for a visible change
    sw x12, 0(x11)        #print to LEDs
    j loop
