//-----------------------
// Simple MAC processing element
// 
// Description:
// This module implements a simple Multiply-Accumulate (MAC) processing element (PE)
// that can handle multiple input pairs simultaneously. It takes in multiple pairs of
// input operands, performs multiplication on each pair, and accumulates the results.
// The PE supports initialization and accumulation control signals.
// This has an output stationary structure.
//
// Parameters:
// - InDataWidth  : Width of the input data (default: 8 bits)
// - NumInputs    : Number of input pairs to process simultaneously (default: 1)
// - OutDataWidth : Width of the output data (default: 32 bits)
//
// Ports:
// - clk_i        : Clock input
// - rst_ni       : Active-low reset input
// - a_i         : Input operand A (array of NumInputs elements)
// - b_i         : Input operand B (array of NumInputs elements)
// - a_valid_i    : Valid signal for input A
// - b_valid_i    : Valid asignal for input B
// - init_save_i  : Initialization signal for saving the first multiplication result
// - acc_clr_i    : Clear signal for the accumulator
// - c_o          : Output accumulated result
//-----------------------

module general_mac_pe #(
  parameter int unsigned InDataWidth  = 8,
  parameter int unsigned NumInputs    = 1,
  parameter int unsigned OutDataWidth = 32
)(
  // Clock and reset
  input  logic clk_i,
  input  logic rst_ni,
  // Input operands
  input  logic signed [NumInputs-1:0][InDataWidth-1:0] a_i,
  input  logic signed [NumInputs-1:0][InDataWidth-1:0] b_i,
  // Valid signals for inputs
  input  logic a_valid_i,
  input  logic b_valid_i,
  input  logic init_save_i,
  // Clear signal for output
  input  logic acc_clr_i,
  // Output accumulation
  output logic signed [OutDataWidth-1:0] c_o
);

  // Wires and logic
  logic acc_valid;
  logic signed [OutDataWidth-1:0] mult_result;

  assign acc_valid = a_valid_i && b_valid_i;

  // Combined multiplication
  always_comb begin
    mult_result = '0;
    for (int i = 0; i < NumInputs; i++) begin
      mult_result += $signed(a_i[i]) * $signed(b_i[i]);
    end
  end

  // Accumulation unit
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      c_o <= '0;
    end else if (init_save_i) begin
      c_o <= mult_result;
    end else if (acc_valid) begin
      c_o <= c_o + mult_result;
    end else if (acc_clr_i) begin
      c_o <= '0;
    end else begin
      c_o <= c_o;
    end
  end

endmodule
