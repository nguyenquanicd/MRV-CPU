`timescale 1ns / 1ps

//--------------------------------------
//Project: Mini RISC-V CPU
//Module:  Immediate Generator
//Function: Immediate generator
//Author:  Thang Luong (superzeldalink)
//Page:    VLSI Technology
//--------------------------------------
module m_vlsit_mrv_cpu_immgen (
    input  logic [31:7] i_instr,
    input  logic [ 4:0] i_sel,
    output logic [31:0] o_imm
);

  always_comb begin
    casez (i_sel)
      5'b????1: o_imm = {{21{i_instr[31]}}, i_instr[30:20]};
      5'b???10: o_imm = {{21{i_instr[31]}}, i_instr[30:25], i_instr[11:7]};
      5'b??100: o_imm = {{20{i_instr[31]}}, i_instr[7], i_instr[30:25], i_instr[11:8], 1'b0};
      5'b?1000: o_imm = {i_instr[31:12], 12'd0};
      5'b10000: o_imm = {{12{i_instr[31]}}, i_instr[19:12], i_instr[20], i_instr[30:21], 1'b0};
      default:  o_imm = '0;
    endcase
  end

endmodule
