`timescale 1ns/1ps

module tb_gemm_accelerator;

    // ------------------------------------------------------------
    // Global parameters (cover all tests)
    // ------------------------------------------------------------
    localparam int unsigned AddrWidth   = 12;   // enough for depth 4096
    localparam int unsigned DataDepth   = 4096; // A, B, C all <= this

    localparam int unsigned DataWidthAB = 8;    // A,B elements
    localparam int unsigned DataWidthC  = 32;   // C elements (results)

    // Max sizes we will test
    localparam int unsigned MAX_M       = 32;
    localparam int unsigned MAX_K       = 64;
    localparam int unsigned MAX_N       = 32;

    // ------------------------------------------------------------
    // Clock / reset
    // ------------------------------------------------------------
    logic clk;
    logic rst_ni;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // Control to GEMM accelerator
    // ------------------------------------------------------------
    logic                 start_i;
    logic [15:0]          M_rows_i;
    logic [15:0]          K_cols_i;
    logic [15:0]          N_cols_i;
    logic [AddrWidth-1:0] base_addr_A_i;
    logic [AddrWidth-1:0] base_addr_B_i;
    logic [AddrWidth-1:0] base_addr_C_i;
    logic                 busy_o;
    logic                 done_o;

    // ------------------------------------------------------------
    // Memory interfaces
    // ------------------------------------------------------------

    // A: 8-bit
    logic [AddrWidth-1:0] A_addr;
    logic                 A_we;
    logic signed [7:0]    A_wr_data;
    logic signed [7:0]    A_rd_data;

    // B: 8-bit
    logic [AddrWidth-1:0] B_addr;
    logic                 B_we;
    logic signed [7:0]    B_wr_data;
    logic signed [7:0]    B_rd_data;

    // C: 32-bit
    logic [AddrWidth-1:0] C_addr;
    logic                 C_we = '1;
    logic signed [31:0]   C_wr_data;
    logic signed [31:0]   C_rd_data;

    integer cycle_count;

    // add counter for latency estimation
    always @(posedge clk) begin
        if (!rst_ni)
            cycle_count <= 0;
        else
            cycle_count <= cycle_count + 1;
    end


    // ------------------------------------------------------------
    // Memories (your single_port_memory)
    // ------------------------------------------------------------
    single_port_memory #(
        .DataWidth (DataWidthAB),
        .DataDepth (DataDepth),
        .AddrWidth (AddrWidth)
    ) u_memA (
        .clk_i        (clk),
        .rst_ni       (rst_ni),
        .mem_addr_i   (A_addr),
        .mem_we_i     (A_we),
        .mem_wr_data_i(A_wr_data),
        .mem_rd_data_o(A_rd_data)
    );

    single_port_memory #(
        .DataWidth (DataWidthAB),
        .DataDepth (DataDepth),
        .AddrWidth (AddrWidth)
    ) u_memB (
        .clk_i        (clk),
        .rst_ni       (rst_ni),
        .mem_addr_i   (B_addr),
        .mem_we_i     (B_we),
        .mem_wr_data_i(B_wr_data),
        .mem_rd_data_o(B_rd_data)
    );

    single_port_memory #(
        .DataWidth (DataWidthC),
        .DataDepth (DataDepth),
        .AddrWidth (AddrWidth)
    ) u_memC (
        .clk_i        (clk),
        .rst_ni       (rst_ni),
        .mem_addr_i   (C_addr),
        .mem_we_i     (C_we),
        .mem_wr_data_i(C_wr_data),
        .mem_rd_data_o(C_rd_data)
    );

    // ------------------------------------------------------------
    // DUT: GEMM accelerator
    // (assumes C_wr_data_o / C_rd_data_i are 32-bit wide)
    // ------------------------------------------------------------
    gemm_accelerator #(
        .AddrWidth   (AddrWidth),
        .InDataWidth (DataWidthAB),
        .OutDataWidth(32),
        .sqDim       (4)
    ) u_dut (
        .clk_i         (clk),
        .rst_ni        (rst_ni),
        .start_i       (start_i),
        .M_rows_i      (M_rows_i),
        .K_cols_i      (K_cols_i),
        .N_cols_i      (N_cols_i),
        .busy_o        (busy_o),
        .done_o        (done_o),
        .A_addr_o      (A_addr),
        .A_rd_data_i   (A_rd_data),
        .B_addr_o      (B_addr),
        .B_rd_data_i   (B_rd_data),
        .C_addr_o      (C_addr),
        .C_wr_data_o   (C_wr_data)
    );

    // ------------------------------------------------------------
    // Task: run one GEMM test with given M, K, N
    // ------------------------------------------------------------
    // ==========================================================
    // PRINT MATRIX A (signed 8-bit)
    // ==========================================================
    task automatic print_matrix_A(input int M, input int K);
        int r, c, idx;
        begin
            $display("Matrix A (%0dx%0d):", M, K);
            for (r = 0; r < M; r++) begin
                $write("  ");
                for (c = 0; c < K; c++) begin
                    idx = r*K + c;
                    $write("%0d ", $signed(u_memA.memory[idx]));
                end
                $write("\n");
            end
            $display("");
        end
    endtask

    // ==========================================================
    // PRINT MATRIX B (signed 8-bit)
    // ==========================================================
    task automatic print_matrix_B(input int K, input int N);
        int r, c, idx;
        begin
            $display("Matrix B (%0dx%0d):", K, N);
            for (r = 0; r < K; r++) begin
                $write("  ");
                for (c = 0; c < N; c++) begin
                    idx = r*N + c;
                    $write("%0d ", $signed(u_memB.memory[idx]));
                end
                $write("\n");
            end
            $display("");
        end
    endtask

    // ==========================================================
    // PRINT MATRIX C (unsigned 32-bit)
    // ==========================================================
    task automatic print_matrix_C(input int M, input int N);
        int r, c, idx;
        begin
            $display("Matrix C (%0dx%0d) UNSIGNED 32b:", M, N);
            for (r = 0; r < M; r++) begin
                $write("  ");
                for (c = 0; c < N; c++) begin
                    idx = r*N + c;
                    // --- IMPORTANT PART ---
                    $write("%0d ", $signed(u_memC.memory[idx]));
                end
                $write("\n");
            end
            $display("");
        end
    endtask

    
    task automatic run_gemm_test(
        input int M,
        input int K,
        input int N,
        input string test_name
    );
        integer addr;
        integer r, c, k;
        integer idx;
        integer idxA;
        integer idxB;
        integer idxC;
        integer errors;
        integer golden;
        logic signed [7:0] a_val;
        logic signed [7:0] b_val;
        integer tmpA;
        integer tmpB;
        integer hw;

        integer start_cycle;
        integer end_cycle;
        integer latency_cycles;

        begin
            $display("\n========================================");
            $display("Starting test: %s (A=%0dx%0d, B=%0dx%0d, C=%0dx%0d)",
                     test_name, M, K, K, N, M, N);
            $display("========================================");

            // Clear memories
            for (addr = 0; addr < DataDepth; addr = addr + 1) begin
                u_memA.memory[addr] = '0;
                u_memB.memory[addr] = '0;
                u_memC.memory[addr] = '0;
            end

            // Initialize A: MxK, row-major: A[r][c] = (r*K + c)
            for (r = 0; r < M; r = r + 1) begin
                for (c = 0; c < K; c = c + 1) begin
                    idxA = r*K + c;
                    u_memA.memory[idxA] = idxA[7:0];
                end
            end

            // Initialize B: KxN, row-major: B[r][c] = (r*N + c)
            for (r = 0; r < K; r = r + 1) begin
                for (c = 0; c < N; c = c + 1) begin
                    idxB = r*N + c;
                    u_memB.memory[idxB] = idxB[7:0];
                end
            end

            // Program accelerator sizes and base addresses
            M_rows_i      = M;
            K_cols_i      = K;
            N_cols_i      = N;

            // Pulse start
            @(posedge clk);
            start_cycle = cycle_count;
            start_i = 1'b1;
            @(posedge clk);
            start_i = 1'b0;

            // Wait for completion
            wait (done_o == 1'b1);
            @(posedge clk);

            end_cycle = cycle_count;

            latency_cycles = end_cycle - start_cycle;

            $display("Latency for %s = %0d cycles", test_name, latency_cycles);

            // Golden check: C = A*B
            errors = 0;

            for (r = 0; r < M; r = r + 1) begin
                for (c = 0; c < N; c = c + 1) begin
                    golden = 0;
                    // sum over k: A[r][k] * B[k][c]
                    for (k = 0; k < K; k = k + 1) begin
                        // A[r][k] pattern: idxA = r*K + k
                        tmpA   = r*K + k;
                        a_val  = tmpA[7:0];  // low 8 bits, signed
                        // B[k][c] pattern: idxB = k*N + c
                        tmpB   = k*N + c;
                        b_val  = tmpB[7:0];  // low 8 bits, signed
                        golden += $signed(a_val) * $signed(b_val);
                    end

                    idxC = r*N + c;
                    hw   = u_memC.memory[idxC];

                    if (hw !== golden) begin
                        $display("MISMATCH %s: C[%0d,%0d] hw=%0d golden=%0d",
                                 test_name, r, c, hw, golden);
                        errors = errors + 1;
                    end
                end
            end

            if (errors == 0) begin
                $display(">>> TEST %s PASSED (no mismatches)", test_name);
            end else begin
                $display(">>> TEST %s FAILED (%0d mismatches)", test_name, errors);
            end

            print_matrix_A(M, K);
            print_matrix_B(K, N);
            print_matrix_C(M, N);
        end
    endtask

    // ------------------------------------------------------------
    // Top-level stimulus: run all three tests
    // ------------------------------------------------------------
    initial begin
        // Reset
        rst_ni  = 1'b0;
        start_i = 1'b0;
        #(20);
        rst_ni  = 1'b1;

        // Test 1: A = 4x64, B = 64x16, C = 4x16
        run_gemm_test(4, 64, 16, "TEST1_A4x64_B64x16_C4x16");

        // Test 2: A = 16x64, B = 64x4, C = 16x4
        run_gemm_test(16, 64, 4, "TEST2_A16x64_B64x4_C16x4");

        // Test 3: A = 32x32, B = 32x32, C = 32x32
        // (assumption: C is 32x32, not 32x3, to match GEMM and tile size)
        run_gemm_test(32, 32, 32, "TEST3_A32x32_B32x32_C32x32");
        
        $display("\nAll tests completed.");
        $finish;
    end

endmodule