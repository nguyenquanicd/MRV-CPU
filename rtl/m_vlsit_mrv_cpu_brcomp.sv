`timescale 1ns / 1ps

//--------------------------------------
//Project: Mini RISC-V CPU
//Module:  Branch Comparator
//Function: Branch comparator (equality compare)
//Author:  Thang Luong (superzeldalink)
//Page:    VLSI Technology
//--------------------------------------
module m_vlsit_mrv_cpu_brcomp (
    input  logic [31:0] i_data_a,
    input  logic [31:0] i_data_b,
    output logic        o_br_equal
);

  assign o_br_equal = ~|(i_data_a ^ i_data_b);

endmodule
