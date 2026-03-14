`timescale 1ns / 1ps

module tb;

  // Parameters
  localparam PARA_IMEM_SIZE = 8192;
  localparam PARA_DMEM_DEPTH = 256;
  localparam PARA_APB_WAIT_STATES = 0;
  localparam PARA_RESET_VECTOR = 32'h00001000;
  localparam [11:0] PARA_INT_VECTOR = 12'h100;
  localparam END_PC = 32'h0000109c;

  // Clock and reset
  reg            clk_i;
  reg            rst_ni;

  // Interrupt
  reg            interrupt_i;

  // APB3 interface
  wire    [31:0] imem_addr;
  wire    [31:0] imem_data;
  wire    [31:0] paddr;
  wire    [31:0] pwdata;
  wire    [31:0] prdata;
  wire           pwrite;
  wire           psel;
  wire           penable;
  wire           pready;

  // Debug
  wire    [31:0] pc_debug;

  reg     [31:0] pc_after_100;
  reg     [31:0] pc_prev;
  reg     [31:0] interrupt_return_pc_expected;
  integer        timeout;
  integer        interrupt_wait;

  // Control-flow check flags
  reg            branch_taken_pc_ok;
  reg            branch_not_taken_pc_ok;
  reg            jal_pc_ok;
  reg            jalr_pc_ok;
  reg            interrupt_vector_hit;
  reg            interrupt_entry_captured;
  reg            hit_beq_taken_fallthrough;
  reg            hit_jal_fallthrough_1;
  reg            hit_jal_fallthrough_2;
  reg            hit_jalr_fallthrough;

  // DUT instantiation
  m_vlsit_mrv_cpu #(
      .PARA_RESET_VECTOR(PARA_RESET_VECTOR),
      .PARA_INT_VECTOR  (PARA_INT_VECTOR)
  ) dut (
      .i_clk      (clk_i),
      .i_rst_n    (rst_ni),
      .i_interrupt(interrupt_i),
      .o_imem_addr(imem_addr),
      .i_imem_data(imem_data),
      .o_paddr    (paddr),
      .o_pwdata   (pwdata),
      .i_prdata   (prdata),
      .o_pwrite   (pwrite),
      .o_psel     (psel),
      .o_penable  (penable),
      .i_pready   (pready)
  );

  assign pc_debug = dut.reg_pc;

  // Clock generation
  initial clk_i = 0;
  always #5 clk_i = ~clk_i;  // 10ns period = 100MHz

  // Task: wait for positive edge
  task wait_posedge;
    @(posedge clk_i);
  endtask

  // Task: reset the system
  task sys_reset;
    rst_ni = 0;
    repeat (3) wait_posedge;
    @(negedge clk_i);
    rst_ni = 1;
  endtask

  apb_slave_bfm #(
      .PARA_DMEM_DEPTH     (PARA_DMEM_DEPTH),
      .PARA_APB_WAIT_STATES(PARA_APB_WAIT_STATES)
  ) u_apb_slave_bfm_0 (
      .i_clk    (clk_i),
      .i_rst_n  (rst_ni),
      .i_paddr  (paddr),
      .i_pwdata (pwdata),
      .o_prdata (prdata),
      .i_pwrite (pwrite),
      .i_psel   (psel),
      .i_penable(penable),
      .o_pready (pready)
  );

  imem #(
      .PARA_SIZE(PARA_IMEM_SIZE)
  ) u_imem_0 (
      .i_addr    (imem_addr[$clog2(PARA_IMEM_SIZE)-1:0]),
      .o_data_out(imem_data)
  );

  // Monitor PC transitions to validate control-flow behavior.
  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      pc_prev <= PARA_RESET_VECTOR;
      branch_taken_pc_ok <= 1'b0;
      branch_not_taken_pc_ok <= 1'b0;
      jal_pc_ok <= 1'b0;
      jalr_pc_ok <= 1'b0;
      interrupt_vector_hit <= 1'b0;
      interrupt_entry_captured <= 1'b0;
      interrupt_return_pc_expected <= 32'h0;
      hit_beq_taken_fallthrough <= 1'b0;
      hit_jal_fallthrough_1 <= 1'b0;
      hit_jal_fallthrough_2 <= 1'b0;
      hit_jalr_fallthrough <= 1'b0;
    end else begin
      // Check branch/jump PC transition immediately after control instruction.
      if (pc_prev == 32'h00001040 && pc_debug == 32'h00001048) branch_taken_pc_ok <= 1'b1;
      if (pc_prev == 32'h00001054 && pc_debug == 32'h00001058) branch_not_taken_pc_ok <= 1'b1;
      if (pc_prev == 32'h00001060 && pc_debug == 32'h0000106c) jal_pc_ok <= 1'b1;
      if (pc_prev == 32'h00001078 && pc_debug == 32'h00001080) jalr_pc_ok <= 1'b1;
      if (pc_debug == {20'h0, PARA_INT_VECTOR}) interrupt_vector_hit <= 1'b1;
      if ((pc_debug == {20'h0, PARA_INT_VECTOR}) && !interrupt_entry_captured) begin
        interrupt_entry_captured <= 1'b1;
        interrupt_return_pc_expected <= pc_prev;
      end

      // Track whether fall-through instructions were executed when they should be skipped.
      if (pc_debug == 32'h00001044) hit_beq_taken_fallthrough <= 1'b1;
      if (pc_debug == 32'h00001064) hit_jal_fallthrough_1 <= 1'b1;
      if (pc_debug == 32'h00001068) hit_jal_fallthrough_2 <= 1'b1;
      if (pc_debug == 32'h0000107c) hit_jalr_fallthrough <= 1'b1;

      pc_prev <= pc_debug;
    end
  end

  // Test counters
  integer tests_passed = 0;
  integer tests_failed = 0;

  // Assertion macros
  `define ASSERT(cond, msg) \
    if (!(cond)) begin \
      $display("[%0t] FAIL: %s", $time, msg); \
      tests_failed = tests_failed + 1; \
    end else begin \
      $display("[%0t] PASS: %s", $time, msg); \
      tests_passed = tests_passed + 1; \
    end

  `define ASSERT_EQ(actual, expected, msg) \
    if ((actual) !== (expected)) begin \
      $display("[%0t] FAIL: %s (expected=0x%0h, actual=0x%0h)", $time, msg, expected, actual); \
      tests_failed = tests_failed + 1; \
    end else begin \
      $display("[%0t] PASS: %s", $time, msg); \
      tests_passed = tests_passed + 1; \
    end

  `define ASSERT_REG_EQ(reg_idx, expected, msg) \
    `ASSERT_EQ(dut.u_regfile_0.reg_array[reg_idx], expected, msg)

  //============================================================
  // Continuous Run With Precompiled IMEM
  //============================================================
  initial begin
    $display("========================================");
    $display("RISC-V RV32I Single-Cycle CPU Testbench");
    $display("========================================");

    interrupt_i = 0;
    sys_reset();

    // Test 1: Reset vector check
    $display("\n--- Test 1: Reset Vector ---");
    `ASSERT_EQ(pc_debug, PARA_RESET_VECTOR, "PC should be PARA_RESET_VECTOR after reset");

    // Test 2: Continuous execution from precompiled imem.hex
    $display("\n--- Test 2: Continuous Program Run (imem.hex) ---");
    timeout = 0;
    while ((pc_debug !== END_PC) && (timeout < 300)) begin
      wait_posedge;
      timeout = timeout + 1;
    end
    `ASSERT((pc_debug == END_PC), "Program should reach end loop PC");
    repeat (5) wait_posedge;
    pc_after_100 = pc_debug;
    `ASSERT((pc_after_100[1:0] == 2'b00), "PC should stay word-aligned");

    // Test 3: Probe RegFile results from sim/tests/instructions_test/test.S
    $display(
        "\n--- Test 3: RegFile Probe (sim/tests/instructions_test/test.S expected results) ---");
    `ASSERT_REG_EQ(1, 32'h0000000f, "x1 should be 0x0000000f");
    `ASSERT_REG_EQ(2, 32'h000000ff, "x2 should be 0x000000ff");
    `ASSERT_REG_EQ(3, 32'h00000000, "x3 should be 0x00000000");
    `ASSERT_REG_EQ(4, 32'h12345000, "x4 should be 0x12345000");
    `ASSERT_REG_EQ(5, 32'h00000100, "x5 should be 0x00000100");
    `ASSERT_REG_EQ(6, 32'h0abcd000, "x6 should be 0x0abcd000");
    `ASSERT_REG_EQ(7, 32'h0abcd000, "x7 should be 0x0abcd000");
    `ASSERT_REG_EQ(8, 32'h000000ff, "x8 should be 0x000000ff");
    `ASSERT_REG_EQ(9, 32'h0000000f, "x9 should be 0x0000000f");
    `ASSERT_REG_EQ(10, 32'h0000000f, "x10 should be 0x0000000f");
    `ASSERT_REG_EQ(11, 32'h000000ff, "x11 should be 0x000000ff");
    `ASSERT_REG_EQ(12, 32'h00000005, "x12 should be 0x00000005");
    `ASSERT_REG_EQ(13, 32'h00000005, "x13 should be 0x00000005");
    `ASSERT_REG_EQ(14, 32'h00000000, "x14 should be 0x00000000 (skipped)");
    `ASSERT_REG_EQ(15, 32'h00000002, "x15 should be 0x00000002");
    `ASSERT_REG_EQ(16, 32'h00000005, "x16 should be 0x00000005");
    `ASSERT_REG_EQ(17, 32'h00000003, "x17 should be 0x00000003");
    `ASSERT_REG_EQ(18, 32'h00000001, "x18 should be 0x00000001");
    `ASSERT_REG_EQ(19, 32'h00000003, "x19 should be 0x00000003");
    `ASSERT_REG_EQ(20, 32'h00001064, "x20 should hold JAL return PC");
    `ASSERT_REG_EQ(21, 32'h00000000, "x21 should be 0x00000000 (skipped)");
    `ASSERT_REG_EQ(22, 32'h00000000, "x22 should be 0x00000000 (skipped)");
    `ASSERT_REG_EQ(23, 32'h00000003, "x23 should be 0x00000003");
    `ASSERT_REG_EQ(24, 32'h00001080, "x24 should hold jalr_target address");
    `ASSERT_REG_EQ(25, 32'h0000107c, "x25 should hold JALR return PC");
    `ASSERT_REG_EQ(26, 32'h00000000, "x26 should be 0x00000000 (skipped)");
    `ASSERT_REG_EQ(27, 32'h00000002, "x27 should be 0x00000002");
    `ASSERT_REG_EQ(28, 32'h00000014, "x28 should be 0x00000014");
    `ASSERT_REG_EQ(29, 32'h00000008, "x29 should be 0x00000008");
    `ASSERT_REG_EQ(30, 32'h0000000c, "x30 should be 0x0000000c");
    `ASSERT_REG_EQ(31, 32'h000000ff, "x31 should be 0x000000ff");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[64], 32'h0abcd000, "DMEM[0x100] should be 0x0abcd000");

    // Test 4: Control-flow PC checks
    $display("\n--- Test 4: Control-Flow PC Checks ---");
    `ASSERT(branch_taken_pc_ok, "BEQ taken should jump PC 0x1040 -> 0x1048");
    `ASSERT(!hit_beq_taken_fallthrough, "BEQ taken should skip PC 0x1044");
    `ASSERT(branch_not_taken_pc_ok, "BEQ not-taken should advance PC 0x1054 -> 0x1058");
    `ASSERT(jal_pc_ok, "JAL should jump PC 0x1060 -> 0x106c");
    `ASSERT(!hit_jal_fallthrough_1, "JAL should skip PC 0x1064");
    `ASSERT(!hit_jal_fallthrough_2, "JAL should skip PC 0x1068");
    `ASSERT(jalr_pc_ok, "JALR should jump PC 0x1078 -> 0x1080");
    `ASSERT(!hit_jalr_fallthrough, "JALR should skip PC 0x107c");
    `ASSERT_REG_EQ(20, 32'h00001064, "JAL should write return PC+4 to x20");
    `ASSERT_REG_EQ(25, 32'h0000107c, "JALR should write return PC+4 to x25");

    // Test 5: Interrupt behavior
    $display("\n--- Test 5: Interrupt Handling ---");
    @(negedge clk_i);
    interrupt_i = 1'b1;
    wait_posedge;
    @(negedge clk_i);
    interrupt_i = 1'b0;

    // Wait for interrupt vector entry (sync + edge detection adds latency).
    interrupt_wait = 0;
    while (!interrupt_vector_hit && (interrupt_wait < 20)) begin
      wait_posedge;
      interrupt_wait = interrupt_wait + 1;
    end
    `ASSERT(interrupt_vector_hit, "Interrupt handler at PARA_INT_VECTOR should be executed");
    `ASSERT(interrupt_entry_captured, "Interrupt entry return PC should be captured");
    `ASSERT_EQ(dut.u_regfile_0.reg_array[1], interrupt_return_pc_expected,
               "Interrupt should save interrupted PC into x1");

    // Wait until handler returns to the saved PC at least once.
    interrupt_wait = 0;
    while ((pc_debug !== dut.u_regfile_0.reg_array[1]) && (interrupt_wait < 20)) begin
      wait_posedge;
      interrupt_wait = interrupt_wait + 1;
    end
    `ASSERT((pc_debug == dut.u_regfile_0.reg_array[1]),
            "Handler should return to saved interrupted PC");
    `ASSERT_REG_EQ(3, 32'h00000001, "Interrupt handler should execute side-effect (x3 += 1)");

    // Summary
    #20;
    $display("\n========================================");
    $display("Test Summary");
    $display("========================================");
    $display("Tests Passed: %0d", tests_passed);
    $display("Tests Failed: %0d", tests_failed);
    if (tests_failed == 0) begin
      $display("ALL TESTS PASSED!");
    end else begin
      $display("SOME TESTS FAILED!");
    end
    $display("========================================");

    $finish;
  end

  // Waveform dump
  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb);
  end

endmodule
