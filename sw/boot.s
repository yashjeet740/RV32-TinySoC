    .section .text
    .globl _start
    .globl main

# Reset vector at 0x0000_0000
_start:
    # Clear x1..x31 (general-purpose registers)
    li x1,  0
    li x2,  0
    li x3,  0
    li x4,  0
    li x5,  0
    li x6,  0
    li x7,  0
    li x8,  0
    li x9,  0
    li x10, 0
    li x11, 0
    li x12, 0
    li x13, 0
    li x14, 0
    li x15, 0
    li x16, 0
    li x17, 0
    li x18, 0
    li x19, 0
    li x20, 0
    li x21, 0
    li x22, 0
    li x23, 0
    li x24, 0
    li x25, 0
    li x26, 0
    li x27, 0
    li x28, 0
    li x29, 0
    li x30, 0
    li x31, 0

    # Initialize stack pointer (sp = x2) to top of 16KB RAM at 0x0000_4000
    li  x2, 0x00004000

    # Call main()
    call main

    # If main returns, write 0x01 to trap address 0x4000_F000 to signal TB
    li   t0, 0x4000F000
    li   t1, 1
    sw   t1, 0(t0)

1:  j    1b          # Infinite loop after signaling trap
