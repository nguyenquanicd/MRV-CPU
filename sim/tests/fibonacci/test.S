    .section .interrupt, "ax"
    .globl interrupt_handler
interrupt_handler:
    # Read fib[2] and fib[4] from DMEM (0x308 and 0x310),
    # store their sum into fib[0] (0x300), then return.
    addi x28, x0, 0x300
    lw   x29, 8(x28)
    lw   x30, 16(x28)
    add  x29, x29, x30
    sw   x29, 0(x28)
    ret

    .section .text
    .globl _start

_start:
    # Store first 10 Fibonacci numbers to DMEM starting at 0x300.
    # fib0=0, fib1=1
    addi x5,  x0, 0x300   # base pointer
    add  x10, x0, x0      # a = 0
    addi x11, x0, 1       # b = 1
    addi x7,  x0, 0       # i = 0
    addi x8,  x0, 10      # N = 10

fib_loop:
    beq  x7,  x8, done
    sw   x10, 0(x5)       # store current fibonacci
    addi x5,  x5, 4
    add  x12, x10, x11    # next = a + b
    add  x10, x11, x0     # a = b
    add  x11, x12, x0     # b = next
    addi x7,  x7, 1
    jal  x0, fib_loop

done:
    addi x31, x0, 1       # done flag for TB

end_loop:
    jal x0, end_loop
