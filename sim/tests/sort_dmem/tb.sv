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
  integer        tests_passed = 0;
  integer        tests_failed = 0;

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
    $display("RISC-V RV32I Sort DMEM Test");
    $display("========================================");

    interrupt_i = 1'b0;
    sys_reset();

    // Wait until program sets x31=1 (done flag) or timeout
    timeout = 0;
    while ((dut.u_regfile_0.reg_array[31] !== 32'h00000001) && (timeout < 1200)) begin
      wait_posedge;
      timeout = timeout + 1;
    end

    `ASSERT((dut.u_regfile_0.reg_array[31] == 32'h00000001),
            "Program should complete and set x31=1");
    `ASSERT((pc_debug[1:0] == 2'b00), "PC should stay word-aligned");

    // Input writes at DMEM 0x100..0x124
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[64], 32'd7, "DMEM[0x100] input[0]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[65], 32'd2, "DMEM[0x104] input[1]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[66], 32'd9, "DMEM[0x108] input[2]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[67], 32'd1, "DMEM[0x10c] input[3]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[68], 32'd5, "DMEM[0x110] input[4]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[69], 32'd3, "DMEM[0x114] input[5]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[70], 32'd8, "DMEM[0x118] input[6]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[71], 32'd4, "DMEM[0x11c] input[7]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[72], 32'd6, "DMEM[0x120] input[8]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[73], 32'd0, "DMEM[0x124] input[9]");

    // Sorted output at DMEM 0x200..0x224
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[128], 32'd0, "DMEM[0x200] sorted[0]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[129], 32'd1, "DMEM[0x204] sorted[1]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[130], 32'd2, "DMEM[0x208] sorted[2]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[131], 32'd3, "DMEM[0x20c] sorted[3]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[132], 32'd4, "DMEM[0x210] sorted[4]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[133], 32'd5, "DMEM[0x214] sorted[5]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[134], 32'd6, "DMEM[0x218] sorted[6]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[135], 32'd7, "DMEM[0x21c] sorted[7]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[136], 32'd8, "DMEM[0x220] sorted[8]");
    `ASSERT_EQ(u_apb_slave_bfm_0.dmem[137], 32'd9, "DMEM[0x224] sorted[9]");

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
