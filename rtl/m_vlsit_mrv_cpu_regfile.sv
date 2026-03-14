`timescale 1ns / 1ps

//--------------------------------------
//Project: Mini RISC-V CPU
//Module:  Register File
//Function: 32 x 32 register file stored as a 2D packed array
//Author:  Thang Luong (superzeldalink)
//Page:    VLSI Technology
//--------------------------------------
module m_vlsit_mrv_cpu_regfile (
    input  logic        i_clk,
    input  logic        i_rst_n,
    input  logic [ 4:0] i_rs_w,
    input  logic [ 4:0] i_rs_r1,
    input  logic [ 4:0] i_rs_r2,
    input  logic [31:0] i_data_w,
    input  logic        i_reg_wen,
    output logic [31:0] o_data_r1,
    output logic [31:0] o_data_r2
);

  logic [31:0][31:0] reg_array;

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
      reg_array <= '0;
    end else begin
      if (i_reg_wen & (|i_rs_w)) begin
        reg_array[i_rs_w] <= i_data_w;
      end
    end
  end

  assign o_data_r1 = reg_array[i_rs_r1];
  assign o_data_r2 = reg_array[i_rs_r2];

endmodule
