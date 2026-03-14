// RV32I-limited sort program for this CPU.
// Behavior:
// 1) Write 10 pseudo-random values to DMEM[0x100..0x124] via BIU
// 2) Read them back and count frequencies (values 0..9)
// 3) Write sorted output to DMEM[0x200..0x224]

__attribute__((naked, section(".interrupt"))) void interrupt_handler(void) {
  __asm__ volatile("jalr x0, x1, 0\n");
}

__attribute__((naked, section(".text"))) void _start(void) {
  __asm__ volatile(
      ".option norvc\n"
      "addi x5,  x0, 256\n"   // input base  0x100
      "addi x6,  x0, 512\n"   // output base 0x200

      // Input values: 7,2,9,1,5,3,8,4,6,0
      "addi x10, x0, 7\n"
      "sw   x10, 0(x5)\n"
      "addi x10, x0, 2\n"
      "sw   x10, 4(x5)\n"
      "addi x10, x0, 9\n"
      "sw   x10, 8(x5)\n"
      "addi x10, x0, 1\n"
      "sw   x10, 12(x5)\n"
      "addi x10, x0, 5\n"
      "sw   x10, 16(x5)\n"
      "addi x10, x0, 3\n"
      "sw   x10, 20(x5)\n"
      "addi x10, x0, 8\n"
      "sw   x10, 24(x5)\n"
      "addi x10, x0, 4\n"
      "sw   x10, 28(x5)\n"
      "addi x10, x0, 6\n"
      "sw   x10, 32(x5)\n"
      "add  x10, x0, x0\n"
      "sw   x10, 36(x5)\n"

      // Counters c0..c9 in x12..x21
      "add  x12, x0, x0\n"
      "add  x13, x0, x0\n"
      "add  x14, x0, x0\n"
      "add  x15, x0, x0\n"
      "add  x16, x0, x0\n"
      "add  x17, x0, x0\n"
      "add  x18, x0, x0\n"
      "add  x19, x0, x0\n"
      "add  x20, x0, x0\n"
      "add  x21, x0, x0\n"

      // Read back and count
      "addi x7,  x0, 0\n"     // i = 0
      "addi x8,  x0, 10\n"    // N = 10
      "addi x5,  x0, 256\n"   // reset input pointer
      "read_loop:\n"
      "beq  x7,  x8, write_sorted\n"
      "lw   x11, 0(x5)\n"
      "addi x5,  x5, 4\n"
      "add  x10, x0, x0\n"
      "beq  x11, x10, inc0\n"
      "addi x10, x0, 1\n"
      "beq  x11, x10, inc1\n"
      "addi x10, x0, 2\n"
      "beq  x11, x10, inc2\n"
      "addi x10, x0, 3\n"
      "beq  x11, x10, inc3\n"
      "addi x10, x0, 4\n"
      "beq  x11, x10, inc4\n"
      "addi x10, x0, 5\n"
      "beq  x11, x10, inc5\n"
      "addi x10, x0, 6\n"
      "beq  x11, x10, inc6\n"
      "addi x10, x0, 7\n"
      "beq  x11, x10, inc7\n"
      "addi x10, x0, 8\n"
      "beq  x11, x10, inc8\n"
      "addi x10, x0, 9\n"
      "beq  x11, x10, inc9\n"
      "jal  x0, next_read\n"

      "inc0:\n"
      "addi x12, x12, 1\n"
      "jal  x0, next_read\n"
      "inc1:\n"
      "addi x13, x13, 1\n"
      "jal  x0, next_read\n"
      "inc2:\n"
      "addi x14, x14, 1\n"
      "jal  x0, next_read\n"
      "inc3:\n"
      "addi x15, x15, 1\n"
      "jal  x0, next_read\n"
      "inc4:\n"
      "addi x16, x16, 1\n"
      "jal  x0, next_read\n"
      "inc5:\n"
      "addi x17, x17, 1\n"
      "jal  x0, next_read\n"
      "inc6:\n"
      "addi x18, x18, 1\n"
      "jal  x0, next_read\n"
      "inc7:\n"
      "addi x19, x19, 1\n"
      "jal  x0, next_read\n"
      "inc8:\n"
      "addi x20, x20, 1\n"
      "jal  x0, next_read\n"
      "inc9:\n"
      "addi x21, x21, 1\n"

      "next_read:\n"
      "addi x7,  x7, 1\n"
      "jal  x0, read_loop\n"

      // Write sorted values to 0x200
      "write_sorted:\n"
      "w0_check:\n"
      "beq  x12, x0, w1_check\n"
      "add  x10, x0, x0\n"
      "sw   x10, 0(x6)\n"
      "addi x6,  x6, 4\n"
      "addi x12, x12, -1\n"
      "jal  x0, w0_check\n"

      "w1_check:\n"
      "beq  x13, x0, w2_check\n"
      "addi x10, x0, 1\n"
      "sw   x10, 0(x6)\n"
      "addi x6,  x6, 4\n"
      "addi x13, x13, -1\n"
      "jal  x0, w1_check\n"

      "w2_check:\n"
      "beq  x14, x0, w3_check\n"
      "addi x10, x0, 2\n"
      "sw   x10, 0(x6)\n"
      "addi x6,  x6, 4\n"
      "addi x14, x14, -1\n"
      "jal  x0, w2_check\n"

      "w3_check:\n"
      "beq  x15, x0, w4_check\n"
      "addi x10, x0, 3\n"
      "sw   x10, 0(x6)\n"
      "addi x6,  x6, 4\n"
      "addi x15, x15, -1\n"
      "jal  x0, w3_check\n"

      "w4_check:\n"
      "beq  x16, x0, w5_check\n"
      "addi x10, x0, 4\n"
      "sw   x10, 0(x6)\n"
      "addi x6,  x6, 4\n"
      "addi x16, x16, -1\n"
      "jal  x0, w4_check\n"

      "w5_check:\n"
      "beq  x17, x0, w6_check\n"
      "addi x10, x0, 5\n"
      "sw   x10, 0(x6)\n"
      "addi x6,  x6, 4\n"
      "addi x17, x17, -1\n"
      "jal  x0, w5_check\n"

      "w6_check:\n"
      "beq  x18, x0, w7_check\n"
      "addi x10, x0, 6\n"
      "sw   x10, 0(x6)\n"
      "addi x6,  x6, 4\n"
      "addi x18, x18, -1\n"
      "jal  x0, w6_check\n"

      "w7_check:\n"
      "beq  x19, x0, w8_check\n"
      "addi x10, x0, 7\n"
      "sw   x10, 0(x6)\n"
      "addi x6,  x6, 4\n"
      "addi x19, x19, -1\n"
      "jal  x0, w7_check\n"

      "w8_check:\n"
      "beq  x20, x0, w9_check\n"
      "addi x10, x0, 8\n"
      "sw   x10, 0(x6)\n"
      "addi x6,  x6, 4\n"
      "addi x20, x20, -1\n"
      "jal  x0, w8_check\n"

      "w9_check:\n"
      "beq  x21, x0, done\n"
      "addi x10, x0, 9\n"
      "sw   x10, 0(x6)\n"
      "addi x6,  x6, 4\n"
      "addi x21, x21, -1\n"
      "jal  x0, w9_check\n"

      "done:\n"
      "addi x31, x0, 1\n"  // done flag for TB
      "end_loop:\n"
      "jal  x0, end_loop\n");
}
