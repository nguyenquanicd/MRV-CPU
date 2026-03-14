//------------------------------------------------------------------------------
// Module: imem
// Description: Instruction memory with combinational read.
//------------------------------------------------------------------------------
module imem #(
    parameter PARA_SIZE = 2048  // Size of the memory, default is 2048=2KB
) (
    input  logic [$clog2(PARA_SIZE)-1:0] i_addr,
    output logic [                 31:0] o_data_out
);

  logic [$clog2(PARA_SIZE/4)-1:0] w_mem_addr;
  assign w_mem_addr = i_addr[$clog2(PARA_SIZE)-1:2];

  logic [31:0] mem_array[0:PARA_SIZE/4-1];

  initial begin
    for (int i = 0; i < PARA_SIZE / 4; i += 1) begin
      mem_array[i] = '0;
    end
    $readmemh("imem.hex", mem_array);
  end

  assign o_data_out = mem_array[w_mem_addr];

endmodule
