module tb_one_mac_gemm;
  //---------------------------
  // Design Time Parameters
  //---------------------------

  //---------------------------
  // DESIGN NOTE:
  // Parameters are a way to customize your design at
  // compile time. Here we define the data width,
  // memory depth, and number of ports for the
  // multi-port memory instances used in the DUT.
  //
  // In other test benches, you can also have test parameters,
  // such as the number of tests to run, or the sizes of
  // matrices to be used in the tests.
  //
  // You can customize these parameters as needed.
  // Or you can also add your own parameters.
  //---------------------------

  // General Parameters
  parameter int unsigned InDataWidth   = 8;
  parameter int unsigned OutDataWidth  = 32;
  parameter int unsigned DataDepth     = 4096;
  parameter int unsigned AddrWidth     = (DataDepth <= 1) ? 1 : $clog2(DataDepth);
  parameter int unsigned SizeAddrWidth = 8;

  // Test Parameters
  parameter int unsigned MaxNum   = 32;
  parameter int unsigned NumTests = 10;

  parameter int unsigned SingleM = 8;
  parameter int unsigned SingleK = 8;
  parameter int unsigned SingleN = 8;

  //---------------------------
  // Wires
  //---------------------------

  // Size control
  logic [SizeAddrWidth-1:0] M_i, K_i, N_i;

  // Clock, reset, and other signals
  logic clk_i;
  logic rst_ni;
  logic start;
  logic done;
  logic [AddrWidth-1:0] test_depth;

  //---------------------------
  // Memory
  //---------------------------
  // Golden data dump
  logic signed [OutDataWidth-1:0] G_memory [DataDepth];

  // Memory control
  logic [AddrWidth-1:0] sram_a_addr;
  logic [AddrWidth-1:0] sram_b_addr;
  logic [AddrWidth-1:0] sram_c_addr;

  // Memory access
  logic signed [ InDataWidth-1:0] sram_a_rdata;
  logic signed [ InDataWidth-1:0] sram_b_rdata;
  logic signed [OutDataWidth-1:0] sram_c_wdata;
  logic                           sram_c_we = '1;

  //---------------------------
  // Declaration of input and output memories
  //---------------------------

  //---------------------------
  // DESIGN NOTE:
  // These are where the memories are instantiated for the DUT.
  // You can modify the data width and data depth parameters.
  //
  // This can be useful for increasing your memory bandwidth.
  // However, you need to think about and take care of how to,
  // initialize the memories accordingly.
  // That includes knowing how to pack the data accordingly.
  //
  // Make sure that the connection for the address, data, and wen
  // signals are consistent with the number of ports.
  //
  // Refer to the single_port_memory.sv and 
  // tb_single_port_memory.sv file for more details.
  //---------------------------

  // Input memory A
  // Note: this is read only
  single_port_memory #(
    .DataWidth     ( InDataWidth  ),
    .DataDepth     ( DataDepth    ),
    .AddrWidth     ( AddrWidth    )
  ) i_sram_a (
    .clk_i         ( clk_i        ),
    .rst_ni        ( rst_ni       ),
    .mem_addr_i    ( sram_a_addr  ),
    .mem_we_i      ( '0           ),
    .mem_wr_data_i ( '0           ),
    .mem_rd_data_o ( sram_a_rdata )
  );

  // Input memory B
  // Note: this is read only
  single_port_memory #(
    .DataWidth     ( InDataWidth  ),
    .DataDepth     ( DataDepth    ),
    .AddrWidth     ( AddrWidth    )
  ) i_sram_b (
    .clk_i         ( clk_i        ),
    .rst_ni        ( rst_ni       ),
    .mem_addr_i    ( sram_b_addr  ),
    .mem_we_i      ( '0           ),
    .mem_wr_data_i ( '0           ),
    .mem_rd_data_o ( sram_b_rdata )
  );

  // Output memory C
  // Note: this is write only
  single_port_memory #(
    .DataWidth     ( OutDataWidth ),
    .DataDepth     ( DataDepth    ),
    .AddrWidth     ( AddrWidth    )
  ) i_sram_c (
    .clk_i         ( clk_i        ),
    .rst_ni        ( rst_ni       ),
    .mem_addr_i    ( sram_c_addr  ),
    .mem_we_i      ( sram_c_we    ),
    .mem_wr_data_i ( sram_c_wdata ),
    .mem_rd_data_o ( /* unused */ )
  );

  //---------------------------
  // DUT instantiation
  //---------------------------
  gemm_accelerator #(
        .AddrWidth   (AddrWidth),
        .InDataWidth (8),
        .OutDataWidth(32),
        .sqDim       (4)
    ) i_dut (
        .clk_i         (clk_i),
        .rst_ni        (rst_ni),
        .start_i       (start),
        .M_rows_i      (M_i),
        .K_cols_i      (K_i),
        .N_cols_i      (N_i),
        .busy_o        (busy_o),
        .done_o        (done_o),
        .A_addr_o      (sram_a_addr),
        .A_rd_data_i   (sram_a_rdata),
        .B_addr_o      (sram_b_addr),
        .B_rd_data_i   (sram_b_rdata),
        .C_addr_o      (sram_c_addr),
        .C_wr_data_o   (sram_c_wdata)
    );

  //---------------------------
  // Tasks and functions
  //---------------------------
  `include "includes/common_tasks.svh"
  `include "includes/test_tasks.svh"
  `include "includes/test_func.svh"

  //---------------------------
  // Test control
  //---------------------------

  // Clock generation
  initial begin
    clk_i = 1'b0;
    forever #5 clk_i = ~clk_i;  // 100MHz clock
  end

  //---------------------------
  // DESIGN NOTE:
  //
  // The sequence driver is usually the main stimulus
  // generator for the test bench. Here is where
  // you define the sequence of operations to be
  // performed during the simulation.
  //
  // It often starts with an initial reset sequence,
  // by loading default values and asserting the reset.
  //
  // We also do for-loops to run multiple tests
  // with different input parameters. In this case,
  // we randomize the matrix sizes for each test.
  //
  // You can also customize in here the way
  // the memories are initialized, how the golden
  // results are generated, and how the results
  // are verified.
  //
  // Refer to the tasks and functions included above
  // for more details.
  //---------------------------

  // Sequence driver
  initial begin

    // Initial reset
    start  = 1'b0;
    rst_ni = 1'b0;
    #50;
    rst_ni = 1'b1;

    for (integer num_test = 0; num_test < NumTests; num_test++) begin
      $display("Test number: %0d", num_test);

      if (NumTests > 1) begin
        M_i = $urandom_range(1, MaxNum/4)*4;
        K_i = $urandom_range(1, MaxNum/4)*4;
        N_i = $urandom_range(1, MaxNum/4)*4;
      end else begin
        M_i = SingleM;
        K_i = SingleK;
        N_i = SingleN;
      end

      $display("M: %0d, K: %0d, N: %0d", M_i, K_i, N_i);

      //---------------------------
      // DESIGN NOTE:
      // You will most likely modify this part
      // to initialize the input memories
      // according to your design requirements.
      //
      // In here, we simply fill the memories
      // with random data for testing.
      //
      // We assume a row-major storage for both matrices A and B.
      // Row major means that the elements of each row
      // are stored in contiguous memory locations.
      //
      // We also make the assumption that the matrix output C
      // will be stored in row-major format as well.
      //
      // Take note that you WILL change this part according to your design.
      // Just make sure that the way you initialize the memories
      // is consistent with the way you generate the golden results
      // and the way your DUT reads/writes the data.
      //
      // The tricky part here is that since the data accesses are
      // shared within a single long bit-width (suppose you use longer)
      // memory word. For example, if your memory word is 32 bits wide
      // and your data width is 8 bits, then you can pack
      // 4 data elements in a single memory word.
      // So when you initialize the memory, you need to
      // make sure that the data elements are packed
      // correctly within each memory word.
      //---------------------------

      // Initialize memories with random data
      for (integer m = 0; m < M_i; m++) begin
        for (integer k = 0; k < K_i; k++) begin
          i_sram_a.memory[m*K_i+k] = $urandom() % (2 ** InDataWidth);
        end
      end

      for (integer k = 0; k < K_i; k++) begin
        for (integer n = 0; n < N_i; n++) begin
          i_sram_b.memory[k*N_i+n] = $urandom() % (2 ** InDataWidth);
        end
      end

      // Generate golden result
      gemm_golden(M_i, K_i, N_i, i_sram_a.memory, i_sram_b.memory, G_memory);

      // Just delay 1 cycle
      clk_delay(1);

      // Execute the GeMM
      start_and_wait_gemm();

      test_depth = M_i * N_i;
      // Verify the result
      verify_result_c(G_memory, i_sram_c.memory, test_depth,
                      0 // Set this to 1 to make mismatches fatal
      );

      // Just some trailing cycles
      // For easier monitoring in waveform
      clk_delay(10);
    end

    $display("All test tasks completed successfully!");
    $finish;
  end

endmodule