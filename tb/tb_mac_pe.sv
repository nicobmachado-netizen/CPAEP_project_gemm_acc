//--------------------------
// MAC PE Testbench
// - Unit test to check the functionality of the PE
//--------------------------

module tb_mac_pe;

  //---------------------------
  // Design Time Parameters
  //---------------------------

  // MAC Parameters
  parameter int unsigned InDataWidth  = 8;
  parameter int unsigned OutDataWidth = 32;
  parameter int unsigned NumInputs    = 4;

  //---------------------------
  // Test Parameters
  //---------------------------
  parameter int unsigned NumTests = 10;

  //---------------------------
  // Wires
  //---------------------------

  // Clock and reset
  logic clk_i, rst_ni;

  // Input signals
  logic signed [NumInputs-1:0][InDataWidth-1:0] a_i, b_i;
  logic a_valid_i, b_valid_i;
  logic init_save_i;
  logic acc_clr_i;

  // Output signal
  logic signed [OutDataWidth-1:0] c_o;
  logic signed [OutDataWidth-1:0] golden_c_o;

  // Instantiate the MAC PE module
  general_mac_pe #(
    .InDataWidth  ( InDataWidth  ),
    .NumInputs    ( NumInputs    ),
    .OutDataWidth ( OutDataWidth )
  ) i_dut (
    .clk_i        ( clk_i        ),
    .rst_ni       ( rst_ni       ),
    .a_i          ( a_i          ),
    .b_i          ( b_i          ),
    .a_valid_i    ( a_valid_i    ),
    .b_valid_i    ( b_valid_i    ),
    .init_save_i  ( init_save_i  ),
    .acc_clr_i    ( acc_clr_i    ),
    .c_o          ( c_o          )
  );

  //---------------------------
  // Tasks and functions
  //---------------------------
  `include "includes/common_tasks.svh"

  function automatic void mac_pe_golden(
    input  logic signed [NumInputs-1:0][InDataWidth-1:0] A_i,
    input  logic signed [NumInputs-1:0][InDataWidth-1:0] B_i,
    output logic signed [OutDataWidth-1:0] C_o
  );
    int unsigned i;

    C_o = '0;
    for (i = 0; i < NumInputs; i++) begin
      C_o += $signed(A_i[i]) * $signed(B_i[i]);
    end

  endfunction

  //---------------------------
  // Start of testbench
  //---------------------------

  // Clock generation
  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;  // 100MHz clock
  end

  // Test control
  initial begin

    // Initialize inputs
    clk_i       = 1'b0;
    rst_ni      = 1'b0;
    a_valid_i   = 1'b0;
    b_valid_i   = 1'b0;
    init_save_i = 1'b0;
    acc_clr_i   = 1'b0;

    for (int i = 0; i < NumInputs; i++) begin
      a_i[i] = '0;
      b_i[i] = '0;
      clk_delay(1);
    end

    clk_delay(3);

    // Release reset
    #1;
    rst_ni = 1;

    // 1 cycle delay after reset
    clk_delay(1);

    // Driver conntrol
    for (int i = 0; i < NumTests; i++) begin

      for (int j = 0; j < NumInputs; j++) begin
        a_i[j] = $urandom();
        b_i[j] = $urandom();
      end

      // Calculate golden value
      mac_pe_golden(a_i, b_i, golden_c_o);

      // Set the valid signals
      a_valid_i = 1;
      b_valid_i = 1;
      init_save_i = 1;
      clk_delay(1);

      // Check if answer is correct
      if(golden_c_o !== c_o) begin
        $display("Error in test %0d", i);
        for (int j = 0; j < NumInputs; j++) begin
          $display("A[%0d]: %d, B[%0d]: %d",
            j, $signed(a_i[j]), j, $signed(b_i[j]));
        end
        $display("OUT: %d, GOLDEN: %d", $signed(c_o), $signed(golden_c_o));
        $fatal;
      end
      $display("Test %0d passed.", i);
    end

    // Finish simulation after some time
    clk_delay(5);
    $display("All tests passed!");

    $finish;
  end

endmodule
