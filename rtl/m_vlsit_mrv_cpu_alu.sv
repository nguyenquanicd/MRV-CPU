`timescale 1ns / 1ps

//--------------------------------------
//Project: Mini RISC-V CPU
//Module:  Arithmetic Logic Unit (ALU)
//Function: ALU datapath operations
//Author:  Thang Luong (superzeldalink)
//Page:    VLSI Technology
//--------------------------------------
module m_vlsit_mrv_cpu_alu (
    input  logic [31:0] i_data_a,
    input  logic [31:0] i_data_b,
    input  logic [ 3:0] i_sel,
    output logic [31:0] o_data
);

  logic [31:0] w_addsub_result;
  logic [31:0] w_addsub_b;
  logic [31:0] w_a_or_b;
  logic [31:0] w_a_and_b;

  assign w_addsub_b      = i_sel[3] ? (~i_data_b + 1'b1) : i_data_b;
  assign w_addsub_result = i_data_a + w_addsub_b;

  assign w_a_or_b        = i_data_a | i_data_b;
  assign w_a_and_b       = i_data_a & i_data_b;

  always_comb begin
    casez (i_sel[2:0])
      3'b000:  o_data = w_addsub_result;
      3'b110:  o_data = w_a_or_b;
      3'b111:  o_data = w_a_and_b;
      3'b001:  o_data = i_data_b;
      default: o_data = '0;
    endcase
  end
endmodule
