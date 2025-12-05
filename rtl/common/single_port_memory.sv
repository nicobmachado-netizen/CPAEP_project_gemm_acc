//-----------------------------
// Single Port Memory Module
//
// Description: This module implements a single-port memory with
// configurable data width and depth. It supports synchronous write
// operations and combinational read operations.
//
// Parameters:
// - DataWidth: Width of the data bus (default: 8 bits)
// - DataDepth: Depth of the memory (default: 4096 entries)
// - AddrWidth: Width of the address bus (calculated based on DataDepth)
//
// Ports:
// - clk_i: Clock input
// - rst_ni: Active low reset input
// - mem_addr_i: Memory address input
// - mem_we_i: Memory write enable input
// - mem_wr_data_i: Memory write data input
// - mem_rd_data_o: Memory read data output
//-----------------------------

//-----------------------------
// DESIGN NOTE:
// You are allowed to modify the Datadepth and
// DataWidth parameters to suit your design requirements.
//-----------------------------
module single_port_memory #(
    parameter int unsigned DataWidth = 8,
    parameter int unsigned DataDepth = 4096,
    parameter int unsigned AddrWidth = (DataDepth <= 1) ? 1 : $clog2(DataDepth)
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,
    input  logic        [AddrWidth-1:0] mem_addr_i,
    input  logic                        mem_we_i,
    input  logic signed [DataWidth-1:0] mem_wr_data_i,
    output logic signed [DataWidth-1:0] mem_rd_data_o
);

  // Memory array
  logic signed [DataWidth-1:0] memory[DataDepth];

  // Memory read access
  always_comb begin
    mem_rd_data_o = memory[mem_addr_i];
  end

  // Memory write access
  always_ff @(posedge clk_i) begin
    // Write when write enable is asserted
    if (mem_we_i) begin
      memory[mem_addr_i] <= mem_wr_data_i;
    end
  end
endmodule
