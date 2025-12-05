//--------------------------
// Multi-Port Memory Testbench
//
// Description:
// This testbench instantiates a single multi-port memory module
// for testing purposes. It sets up the necessary parameters and
// connects the memory ports appropriately.
// A simple read and write operation can be added to
// verify the functionality of the multi-port memory.
//
// Take note that each port has one address, one write enable,
// one write data, and one read data signal.
//
// Parameters:
// - DataWidth : Width of each data word.
// - DataDepth : Depth of the memory (number of addressable locations).
// - AddrWidth : Width of the address bus, calculated based on DataDepth.
//--------------------------


module tb_single_port_memory;

  //---------------------------
  // Design Time Parameters
  //---------------------------

  // General parameters
  parameter int unsigned DataWidth = 8;
  parameter int unsigned DataDepth = 4096;
  parameter int unsigned AddrWidth = (DataDepth <= 1) ? 1 : $clog2(DataDepth);

  // Test parameters
  parameter int unsigned NumIterations = DataDepth;

  //---------------------------
  // Wires
  //---------------------------
  // Clock and reset
  logic clk_i, rst_ni;

  // Some other signals
  logic        [AddrWidth-1:0] addr;

  // Memory control
  logic        [AddrWidth-1:0] mem_addr;
  logic                        mem_we;
  logic signed [DataWidth-1:0] mem_wr_data;
  logic signed [DataWidth-1:0] mem_rd_data;
  // Golden data dump
  logic signed [DataWidth-1:0] G_memory [DataDepth];

  //---------------------------
  // DUT instantiation
  //---------------------------
  single_port_memory #(
    .DataWidth     ( DataWidth   ),
    .DataDepth     ( DataDepth   )
  ) i_sram_a (
    .clk_i         ( clk_i       ),
    .rst_ni        ( rst_ni      ),
    .mem_addr_i    ( mem_addr    ),
    .mem_we_i      ( mem_we      ),
    .mem_wr_data_i ( mem_wr_data ),
    .mem_rd_data_o ( mem_rd_data )
  );

  //---------------------------
  // Tasks and functions
  //---------------------------
  `include "includes/common_tasks.svh"

  //---------------------------
  // Test control
  //---------------------------
  // Clock generation
  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;  // 100MHz clock
  end

  // Sequence driver
  initial begin
    // Initial reset
    clk_i       = 1'b0;
    rst_ni      = 1'b0;
    mem_addr    = '0;
    mem_we      = '0;
    mem_wr_data = '0;

    // Initialize golden memory
    for (int unsigned i = 0; i < DataDepth; i++) begin
      G_memory[i] = $urandom();  // Random values
    end

    clk_delay(1);

    // Release reset
    rst_ni = 1'b1;

    // Fill in the contents of actual memory with the golden data
    for (int unsigned iter = 0; iter < NumIterations; iter++) begin
      // Calculate the address
      addr        = iter;
      // Load the control signals
      mem_addr    = addr;
      mem_we      = 1'b1;
      mem_wr_data = G_memory[addr];
      clk_delay(1);
      // Disable after
      mem_we = '0;
    end

    // Trailing cycles for waveform clarity only
    clk_delay(5);

    // Read and compare the loaded data to the golden data
    for (int unsigned iter = 0; iter < NumIterations; iter++) begin
      // Read the data first
      mem_addr = iter;
      // Get data in next cycle
      clk_delay(1);

      // Compare read data with golden data
      addr = iter;
      if (mem_rd_data !== G_memory[addr]) begin
        $error("Data mismatch at address %0d: expected %0d, got %0d",
          addr, G_memory[addr], mem_rd_data);
      end
    end

    // Finish simulation
    clk_delay(5);
    $display("Single-port memory test completed successfully.");
    $finish;
  end

endmodule
