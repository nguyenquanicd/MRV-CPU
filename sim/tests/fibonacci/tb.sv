`timescale 1ns / 1ps

module tb;

  localparam PARA_IMEM_SIZE = 8192;
  localparam PARA_DMEM_DEPTH = 256;
  localparam PARA_APB_WAIT_STATES = 0;
  localparam PARA_RESET_VECTOR = 32'h00001000;
  localparam [11:0] PARA_INT_VECTOR = 12'h100;

  reg            clk_i;
  reg            rst_ni;
  reg            interrupt_i;

  wire    [31:0] imem_addr;
  wire    [31:0] imem_data;
  wire    [31:0] paddr;
  wire    [31:0] pwdata;
  wire    [31:0] prdata;
  wire           pwrite;
  wire           psel;
  wire           penable;
  wire           pready;
  wire    [31:0] pc_debug;

  integer        timeout;
  integer        interrupt_wait;
  integer        tests_passed = 0;
  integer        tests_failed = 0;
  reg     [31:0] pc_prev;
  reg     [31:0] interrupt_return_pc_expected;
  reg            interrupt_vector_hit;
  reg            interrupt_entry_captured;

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

  initial clk_i = 1'b0;
  always #5 clk_i = ~clk_i;

  // Track interrupt entry PC and expected return PC.
  always @(posedge clk_i or negedge rst_ni) begin
    if (~rst_ni) begin
      pc_prev <= PARA_RESET_VECTOR;
      interrupt_vector_hit <= 1'b0;
      interrupt_entry_captured <= 1'b0;
      interrupt_return_pc_expected <= 32'h0;
    end else begin
      if (pc_debug == {20'h0, PARA_INT_VECTOR}) interrupt_vector_hit <= 1'b1;
      if ((pc_debug == {20'h0, PARA_INT_VECTOR}) && !interrupt_entry_captured) begin
        interrupt_entry_captured <= 1'b1;
        interrupt_return_pc_expected <= pc_prev;
      end
      pc_prev <= pc_debug;
    end
  end

  task wait_posedge;
    @(posedge clk_i);
  endtask

  task sys_reset;
    rst_ni = 1'b0;
    repeat (3) wait_posedge;
    @(negedge clk_i);
    rst_ni = 1'b1;
  endtask

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

  initial begin
    $display("========================================");
    $display("RISC-V RV32I Fibonacci DMEM Test");
    $display("========================================");

    interrupt_i = 1'b0;
    sys_reset();

    // Inject an interrupt mid-execution, after initial fib terms are written.
    repeat (80) wait_posedge;
    @(negedge clk_i);
    interrupt_i = 1'b1;
    wait_posedge;
    @(negedge clk_i);
    interrupt_i = 1'b0;

    interrupt_wait = 0;
    while (!interrupt_vector_hit && (interrupt_wait < 20)) begin
      wait_posedge;
      interrupt_wait = interrupt_wait + 1;
    end
    `ASSERT(interrupt_vector_hit, "Interrupt should jump to PARA_INT_VECTOR during run");
    `ASSERT(interrupt_entry_captured, "Interrupt entry should capture return PC");
    `ASSERT_EQ(dut.u_regfile_0.reg_array[1], interrupt_return_pc_expected,
               "Interrupt should save interrupted PC into x1");

    interrupt_wait = 0;
    while ((pc_debug !== dut.u_regfile_0.reg_array[1]) && (interrupt_wait < 20)) begin
      wait_posedge;
      interrupt_wait = interrupt_wait + 1;
    end
    `ASSERT((pc_debug == dut.u_regfile_0.reg_array[1]),
            "Interrupt handler should return to saved PC");

    timeout = 0;
    while ((dut.u_regfile_0.reg_array[31] !== 32'h00000001) && (timeout < 600)) begin
      wait_posedge;
      timeout = timeout + 1;
    end

    `ASSERT((dut.u_regfile_0.reg_array[31] == 32'h00000001),
            "Program should complete and set x31=1");
    `ASSERT((pc_debug[1:0] == 2'b00), "PC should stay word-aligned");

    // Expected fibonacci numbers written at 0x300..0x324.
    // fib[0] is overwritten by ISR with fib[2] + fib[4] = 1 + 3 = 4.
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[192], 32'd4, "DMEM[0x300] fib[0] overwritten by ISR");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[193], 32'd1, "DMEM[0x304] fib[1]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[194], 32'd1, "DMEM[0x308] fib[2]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[195], 32'd2, "DMEM[0x30c] fib[3]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[196], 32'd3, "DMEM[0x310] fib[4]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[197], 32'd5, "DMEM[0x314] fib[5]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[198], 32'd8, "DMEM[0x318] fib[6]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[199], 32'd13, "DMEM[0x31c] fib[7]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[200], 32'd21, "DMEM[0x320] fib[8]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[201], 32'd34, "DMEM[0x324] fib[9]");

    #20;
    $display("\n========================================");
    $display("Test Summary");
    $display("========================================");
    $display("Tests Passed: %0d", tests_passed);
    $display("Tests Failed: %0d", tests_failed);
    if (tests_failed == 0) $display("ALL TESTS PASSED!");
    else $display("SOME TESTS FAILED!");
    $display("========================================");
    $finish;
  end

  initial begin
    $dumpfile("waveform.vcd");
    $dumpvars(0, tb);
  end

endmodule
