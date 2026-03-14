# RISC-V RV32I Test Program
# Tests: ADD, ADDI, LUI, LW, SW, AND, OR, BEQ, JAL, JALR, SUB, ANDI, ORI

    .section .interrupt, "ax"
    .globl interrupt_handler
interrupt_handler:
    # Simple interrupt side effect marker.
    addi    x3, x3, 1
    # Return to interrupted PC saved by CPU interrupt path in x1.
    ret

    .section .text
    .globl _start

_start:
    # Test 1: ADD instruction
    add     x1, x0, x0      # x1 = 0 + 0 = 0
    add     x2, x1, x0      # x2 = 0 + 0 = 0
    add     x3, x1, x2      # x3 = 0 + 0 = 0

    # Test 2: ADDI instruction
    addi    x1, x0, 10      # x1 = 10
    addi    x2, x1, 5       # x2 = 15

    # Test 3: LUI instruction
    lui     x4, 0x12345     # x4 = 0x12345000

    # Test 4: SW/LW instruction
    addi    x5, x0, 0x100   # x5 = base address (0x100)
    lui     x6, 0xABCD      # x6 = 0xABCD000 (use lui for large immediate)
    sw      x6, 0(x5)       # MEM[0x100] = 0xABCD000
    lw      x7, 0(x5)       # x7 = MEM[0x100] = 0xABCD000

    # Test 5: AND/OR instructions
    addi    x8, x0, 0xFF    # x8 = 0xFF
    addi    x9, x0, 0x0F    # x9 = 0x0F
    and     x10, x8, x9     # x10 = 0xFF & 0x0F = 0x0F
    or      x11, x8, x9     # x11 = 0xFF | 0x0F = 0xFF

    # Test 6: BEQ (branch taken)
    addi    x12, x0, 5      # x12 = 5
    addi    x13, x0, 5      # x13 = 5
    beq     x12, x13, branch_taken
    addi    x14, x0, 1      # skipped
branch_taken:
    addi    x15, x0, 2      # x15 = 2 (branch target)

    # Test 7: BEQ (branch not taken)
    addi    x16, x0, 5      # x16 = 5
    addi    x17, x0, 3      # x17 = 3
    beq     x16, x17, branch_not_taken
    addi    x18, x0, 1      # x18 = 1 (executed)
branch_not_taken:
    addi    x19, x0, 3      # x19 = 3

    # Test 8: JAL instruction
    jal     x20, jump_target
    addi    x21, x0, 1      # skipped
    addi    x22, x0, 2      # skipped
jump_target:
    addi    x23, x0, 3      # x23 = 3

    # Test 9: JALR instruction
    lui     x24, %hi(jalr_target)  # x24 = address of jalr_target (upper)
    addi    x24, x24, %lo(jalr_target)  # lower
    jalr    x25, x24, 0
    addi    x26, x0, 1      # skipped
jalr_target:
    addi    x27, x0, 2      # x27 = 2

    # Test 10: SUB instruction
    addi    x28, x0, 20     # x28 = 20
    addi    x29, x0, 8      # x29 = 8
    sub     x30, x28, x29   # x30 = 12

    # Test 11: ANDI/ORI instructions
    addi    x31, x0, 0xFF   # x31 = 0xFF
    andi    x1, x31, 0x0F   # x1 = 0x0F
    ori     x2, x31, 0x0F   # x2 = 0xFF

end:
    j       end             # infinite loop
