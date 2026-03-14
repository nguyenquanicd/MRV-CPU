`timescale 1ns / 1ps

//--------------------------------------
//Project: Mini RISC-V CPU
//Module:  Bus Interface Unit (BIU)
//Function: APB3 bus interface unit with simple request/stall handshake
//Author:  Thang Luong (superzeldalink)
//Page:    VLSI Technology
//--------------------------------------
module m_vlsit_mrv_cpu_biu (
    // Clock, Reset
    input logic i_clk,
    input logic i_rst_n,

    // CPU interface
    input  logic [31:0] i_addr,
    input  logic [31:0] i_data_w,
    output logic [31:0] o_data_r,
    input  logic        i_mem_r,
    input  logic        i_mem_w,
    output logic        o_stall,

    // APB interface
    output logic [31:0] o_paddr,
    output logic [31:0] o_pwdata,
    input  logic [31:0] i_prdata,
    output logic        o_pwrite,
    output logic        o_psel,
    output logic        o_penable,
    input  logic        i_pready
);

  typedef enum logic [1:0] {
    ST_IDLE   = 2'b00,
    ST_SETUP  = 2'b01,
    ST_ACCESS = 2'b10,
    ST_DONE   = 2'b11
  } state_t;

  state_t reg_state;
  state_t w_next_state;
  logic [31:0] reg_data_r;

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) reg_state <= ST_IDLE;
    else reg_state <= w_next_state;
  end

  // Register APB handshake outputs.
  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
      o_psel    <= 1'b0;
      o_penable <= 1'b0;
    end else begin
      case (w_next_state)
        ST_IDLE: begin
          o_psel    <= 1'b0;
          o_penable <= 1'b0;
        end
        ST_SETUP: begin
          o_psel    <= 1'b1;
          o_penable <= 1'b0;
        end
        ST_ACCESS: begin
          o_psel    <= 1'b1;
          o_penable <= 1'b1;
        end
        ST_DONE: begin
          o_psel    <= 1'b0;
          o_penable <= 1'b0;
        end
        default: begin
          o_psel    <= 1'b0;
          o_penable <= 1'b0;
        end
      endcase
    end
  end

  always_comb begin
    w_next_state = reg_state;
    case (reg_state)
      ST_IDLE: begin
        if (i_mem_r || i_mem_w) w_next_state = ST_SETUP;
      end
      ST_SETUP: begin
        w_next_state = ST_ACCESS;
      end
      ST_ACCESS: begin
        if (i_pready) w_next_state = ST_DONE;
        else w_next_state = ST_ACCESS;
      end
      ST_DONE: begin
        w_next_state = ST_IDLE;
      end
      default: begin
        w_next_state = ST_IDLE;
      end
    endcase
  end

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) begin
      o_paddr  <= 32'b0;
      o_pwdata <= 32'b0;
      o_pwrite <= 1'b0;
    end else begin
      casez ({
        i_mem_r, i_mem_w
      })
        2'b?1: begin
          o_paddr  <= i_addr;
          o_pwdata <= i_data_w;
          o_pwrite <= 1'b1;
        end
        2'b10: begin
          o_paddr  <= i_addr;
          o_pwrite <= 1'b0;
        end
        default: begin
          // Hold previous APB command fields.
        end
      endcase
    end
  end

  always_comb begin
    case (reg_state)
      ST_IDLE: begin
        o_stall = i_mem_r || i_mem_w;
      end
      ST_SETUP: begin
        o_stall = 1'b1;
      end
      ST_ACCESS: begin
        o_stall = 1'b1;
      end
      ST_DONE: begin
        o_stall = 1'b0;
      end
      default: begin
        o_stall = 1'b0;
      end
    endcase
  end

  always_ff @(posedge i_clk or negedge i_rst_n) begin
    if (~i_rst_n) reg_data_r <= 32'b0;
    else if (reg_state == ST_ACCESS && i_pready && i_mem_r) reg_data_r <= i_prdata;
  end

  assign o_data_r = reg_data_r;

endmodule
