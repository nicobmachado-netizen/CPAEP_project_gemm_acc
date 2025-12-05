//-----------------------------
// Ceiling Counter Testb
//
// Description:
// This testbench instantiates a single ceiling counter module
// for testing purposes. It sets up the necessary parameters and
// connects the counter inputs and outputs appropriately.
//
// Parameters:
// - Width      : Width of the counter.
// - HasCeiling : If set to 1, the counter wraps around at the ceiling
//                value; if set to 0, it is a free-running counter.
//-----------------------------

module tb_ceiling_counter;

  //---------------------------
  // Design Time Parameters
  //---------------------------

  // General parameters
  parameter int unsigned Width      = 8;
  parameter int unsigned HasCeiling = 1;

  // Test parameters
  parameter int unsigned NumTests = 10;

  //---------------------------
  // Wires
  //---------------------------

  // Clock and reset
  logic clk_i, rst_ni;

  // Counter signals
  logic             tick_i;
  logic             clear_i;
  logic [Width-1:0] ceiling_i;
  logic [Width-1:0] count_o;
  logic             last_value_o;

  // Some other control signals
  logic [Width-1:0] ceiling_value;

  //---------------------------
  // DUT instantiation
  //---------------------------

  ceiling_counter #(
    .Width      ( Width      ),
    .HasCeiling ( HasCeiling )
  ) i_dut (
    .clk_i        ( clk_i        ),
    .rst_ni       ( rst_ni       ),
    .tick_i       ( tick_i       ),
    .clear_i      ( clear_i      ),
    .ceiling_i    ( ceiling_i    ),
    .count_o      ( count_o      ),
    .last_value_o ( last_value_o )
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
    rst_ni    = 1'b0;
    tick_i    = 1'b0;
    clear_i   = 1'b0;
    // Test all cases with a ceiling
    ceiling_i = 1'b1;

    clk_delay(1);

    // Release reset
    rst_ni = 1'b1;

    // Iterate through different NumTests
    // By giving different ceiling values
    for (int unsigned test_num = 0; test_num < NumTests; test_num++) begin

      // Set ceiling value
      ceiling_value = $urandom();
      ceiling_i     = ceiling_value;
      // Debug log
      $display("Test %0d: Ceiling value set to %0d", test_num, ceiling_value);

      // Iterate through ceiling value and per tick
      // check the output of the counter
      for (int unsigned tick_num = 0; tick_num < ceiling_value; tick_num++) begin

        // First check if the counter is correct
        // It should start at 0 from a fresh restart or clear
        // Then every iteration it updates accordingly
        if (count_o !== tick_num) begin
          $error("Count mismatch at tick %0d: expected %0d, got %0d",
                 tick_num, tick_num, count_o);
        end

        // Issue tick
        tick_i = 1'b1;
        clk_delay(1);
        tick_i = 1'b0;
      end

      // Clear the counter for the next test
      clear_i = 1'b1;
      clk_delay(1);
      clear_i = 1'b0;
    end

    $display("Ceiling Counter Testbench completed.");
    $finish;
  end

endmodule