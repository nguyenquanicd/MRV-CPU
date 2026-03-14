`timescale 1ns / 1ps

//--------------------------------------
//Project: Mini RISC-V CPU
//Module:  Top-level CPU Core
//Function: Top-level Mini RV32I single-cycle core with APB3 BIU
//Author:  Thang Luong (superzeldalink)
//Page:    VLSI Technology
//--------------------------------------
module m_vlsit_mrv_cpu #(
    parameter [31:0] PARA_RESET_VECTOR = 32'h00001000,
    parameter [11:0] PARA_INT_VECTOR   = 12'h100
) (
    // Clock, Reset
    input logic i_clk,
    input logic i_rst_n,

    // Interrupt
    input logic i_interrupt,

    // IMEM interface
    output logic [31:0] o_imem_addr,
    input  logic [31:0] i_imem_data,

    // APB interface
    output logic [31:0] o_paddr,
    output logic [31:0] o_pwdata,
    input  logic [31:0] i_prdata,
    output logic        o_pwrite,
    output logic        o_psel,
    output logic        o_penable,
    input  logic        i_pready
);

  logic [31:0] reg_pc;
  logic [31:0] w_pc_plus_four;
  logic [31:0] w_pc_new;
  logic [31:0] w_inst;
  logic [31:0] w_alu_out;
  logic [31:0] w_data_w;
  logic [31:0] w_imm;
  logic [31:0] w_mem_data;
  logic [ 1:0] w_pc_sel;
  logic [31:0] w_data_r1;
  logic [31:0] w_data_r2;
  logic        w_br_eq;
  logic        w_mem_w;
  logic        w_mem_r;
  logic        w_a_sel;
  logic        w_b_sel;
  logic        w_reg_wen;
  logic [ 3:0] w_alu_sel;
  logic [ 4:0] w_imm_sel;
  logic [ 1:0] w_wb_sel;
  logic        w_biu_stall;
  logic        reg_interrupt_meta;
  logic        reg_interrupt_sync;
  logic        reg_interrupt_sync_d;
  logic        w_interrupt_edge;
  logic [31:0] w_alu_in_a;
  logic [31:0] w_alu_in_b;

  assign w_interrupt_edge = reg_interrupt_sync & ~reg_interrupt_sync_d;

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
      reg_interrupt_meta   <= 1'b0;
      reg_interrupt_sync   <= 1'b0;
      reg_interrupt_sync_d <= 1'b0;
    end else begin
      reg_interrupt_meta   <= i_interrupt;
      reg_interrupt_sync   <= reg_interrupt_meta;
      reg_interrupt_sync_d <= reg_interrupt_sync;
    end
  end

  assign w_alu_in_a = w_a_sel ? reg_pc : w_data_r1;
  assign w_alu_in_b = w_b_sel ? w_imm : w_data_r2;
  assign w_pc_plus_four = reg_pc + 32'd4;

  // PCSel: [1]=hold (stall/interrupt), [0]=jump/branch
  // Priority: interrupt > stall > branch/jump > PC+4
  assign w_pc_new = w_pc_sel[1] ? reg_pc :  // Hold PC (stall)
      w_pc_sel[0] ? w_alu_out :  // Jump/branch target
      w_pc_plus_four;  // Sequential

  assign w_data_w = (w_wb_sel == 2'b01) ? w_alu_out :
                    (w_wb_sel == 2'b10) ? w_pc_plus_four :
                    (w_wb_sel == 2'b11) ? reg_pc :  // Interrupt saves PC
      w_mem_data;

  assign o_imem_addr = reg_pc;
  assign w_inst = w_interrupt_edge ? {PARA_INT_VECTOR, 20'b00000000000011100111} : i_imem_data;

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
      reg_pc <= PARA_RESET_VECTOR;
    end else begin
      reg_pc <= w_pc_new;
    end
  end

  m_vlsit_mrv_cpu_regfile u_regfile_0 (
      .i_clk    (i_clk),
      .i_rst_n  (i_rst_n),
      .i_rs_w   (w_inst[11:7]),
      .i_rs_r1  (w_inst[19:15]),
      .i_rs_r2  (w_inst[24:20]),
      .i_data_w (w_data_w),
      .i_reg_wen(w_reg_wen),
      .o_data_r1(w_data_r1),
      .o_data_r2(w_data_r2)
  );

  m_vlsit_mrv_cpu_brcomp u_brcomp_0 (
      .i_data_a  (w_data_r1),
      .i_data_b  (w_data_r2),
      .o_br_equal(w_br_eq)
  );

  m_vlsit_mrv_cpu_ctrl u_ctrl_0 (
      .i_inst     (w_inst),
      .i_br_eq    (w_br_eq),
      .i_biu_stall(w_biu_stall),
      .i_interrupt(w_interrupt_edge),
      .o_imm_sel  (w_imm_sel),
      .o_alu_sel  (w_alu_sel),
      .o_pc_sel   (w_pc_sel),
      .o_reg_wen  (w_reg_wen),
      .o_a_sel    (w_a_sel),
      .o_b_sel    (w_b_sel),
      .o_mem_w    (w_mem_w),
      .o_mem_r    (w_mem_r),
      .o_wb_sel   (w_wb_sel)
  );

  m_vlsit_mrv_cpu_immgen u_immgen_0 (
      .i_instr(w_inst[31:7]),
      .i_sel  (w_imm_sel),
      .o_imm  (w_imm)
  );

  m_vlsit_mrv_cpu_alu u_alu_0 (
      .i_data_a(w_alu_in_a),
      .i_data_b(w_alu_in_b),
      .i_sel   (w_alu_sel),
      .o_data  (w_alu_out)
  );

  m_vlsit_mrv_cpu_biu u_biu_0 (
      .i_clk    (i_clk),
      .i_rst_n  (i_rst_n),
      .i_addr   (w_alu_out),
      .i_data_w (w_data_r2),
      .o_data_r (w_mem_data),
      .i_mem_r  (w_mem_r),
      .i_mem_w  (w_mem_w),
      .o_paddr  (o_paddr),
      .o_pwdata (o_pwdata),
      .i_prdata (i_prdata),
      .o_pwrite (o_pwrite),
      .o_psel   (o_psel),
      .o_penable(o_penable),
      .i_pready (i_pready),
      .o_stall  (w_biu_stall)
  );

endmodule
