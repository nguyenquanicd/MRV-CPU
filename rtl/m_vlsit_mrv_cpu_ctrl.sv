`timescale 1ns / 1ps

//--------------------------------------
//Project: Mini RISC-V CPU
//Module:  Control Logic
//Function: Decode and control signal generation
//Author:  Thang Luong (superzeldalink)
//Page:    VLSI Technology
//--------------------------------------
module m_vlsit_mrv_cpu_ctrl (
    input  logic [31:0] i_inst,
    input  logic        i_br_eq,
    input  logic        i_biu_stall,
    input  logic        i_interrupt,
    output logic [ 4:0] o_imm_sel,
    output logic [ 3:0] o_alu_sel,
    output logic [ 1:0] o_pc_sel,
    output logic        o_reg_wen,
    output logic        o_b_sel,
    output logic        o_a_sel,
    output logic        o_mem_w,
    output logic        o_mem_r,
    output logic [ 1:0] o_wb_sel
);

  logic [ 4:0] w_opcode;
  logic [ 2:0] w_funct3;
  logic        w_funct7;
  logic        w_branch_true;
  logic        w_r_type;
  logic        w_i_type;
  logic        w_s_type;
  logic        w_b_type;
  logic        w_j_type;
  logic        w_ji_type;
  logic        w_u_type;
  logic        w_l_type;
  /* verilator lint_off UNUSEDSIGNAL */
  logic [22:0] w_unused_inst_bits;
  /* verilator lint_on UNUSEDSIGNAL */

  assign w_opcode = i_inst[6:2];
  assign w_funct3 = i_inst[14:12];
  assign w_funct7 = i_inst[30];
  assign w_unused_inst_bits = {i_inst[31], i_inst[29:15], i_inst[11:7], i_inst[1:0]};

  assign w_r_type = (w_opcode == 5'b01100);
  assign w_i_type = ({w_opcode[4:3], w_opcode[1:0]} == 4'b0000);
  assign w_s_type = (w_opcode == 5'b01000);
  assign w_b_type = (w_opcode == 5'b11000);
  assign w_j_type = (w_opcode == 5'b11011);  // jal
  assign w_u_type = ({w_opcode[4], w_opcode[2:0]} == 4'b0101);  // lui, auipc
  assign w_ji_type = (w_opcode == 5'b11001);  // jalr
  assign w_l_type = ~(|w_opcode);  // opcode = 00000 loads (self defined)

  assign w_branch_true = (w_funct3 == 3'b000) & i_br_eq;

  assign o_pc_sel = i_biu_stall ? 2'b10 : {1'b0, w_j_type | w_ji_type | (w_b_type & w_branch_true)};
  assign o_imm_sel = {w_j_type, w_u_type, w_b_type, w_s_type, w_i_type | w_ji_type};
  assign o_a_sel = w_b_type | w_j_type | w_u_type;
  assign o_b_sel = ~w_r_type;
  assign o_mem_w = w_s_type;
  assign o_mem_r = w_l_type;
  assign o_reg_wen = ~w_b_type & ~w_s_type;
  assign o_wb_sel = i_interrupt ? 2'b11 : (w_l_type ? 2'b00 : (w_j_type | w_ji_type) ? 2'b10 : 2'b01);

  assign o_alu_sel = w_r_type ? {w_funct7, w_funct3} :
                     ((w_i_type & ~w_l_type) ? ((w_funct3 == 3'b101) ? {w_funct7, w_funct3} : {1'b0, w_funct3}) :
                     ((w_opcode == 5'b01101) ? 4'b1001 : 4'b0000));

endmodule
