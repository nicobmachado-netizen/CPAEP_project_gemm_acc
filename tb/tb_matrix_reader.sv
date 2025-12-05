`timescale 1ns/1ps

module tb_matrix_reader;

    localparam int unsigned BIG_ROWS   = 16;
    localparam int unsigned BIG_COLS   = 16;
    localparam int unsigned TOTAL_ELEMS= BIG_ROWS * BIG_COLS; // 256 bytes

    localparam int unsigned DATA_DEPTH = 256; // 1 byte per word
    localparam int unsigned DataWidth  = 8;
    localparam int unsigned AddrWidth  = (DATA_DEPTH <= 1) ? 1 : $clog2(DATA_DEPTH);

    logic clk;
    logic rst_ni;

    // Control
    logic start_i;
    logic [AddrWidth-1:0] base_addr_i;
    logic [15:0]          matrix_cols_i;
    logic [15:0]          start_row_i;
    logic [15:0]          start_col_i;
    logic                 busy_o;
    logic                 done_o;

    // Memory interface
    logic [AddrWidth-1:0] mem_addr;
    logic                 mem_we;
    logic signed [7:0]    mem_wr_data;
    logic signed [7:0]    mem_rd_data;

    // Tile output
    logic signed [7:0]    tile [0:3][0:3];

    // Clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Memory instance (your module)
    single_port_memory #(
        .DataWidth (DataWidth),
        .DataDepth (DATA_DEPTH),
        .AddrWidth (AddrWidth)
    ) u_mem (
        .clk_i        (clk),
        .rst_ni       (rst_ni),
        .mem_addr_i   (mem_addr),
        .mem_we_i     (mem_we),
        .mem_wr_data_i(mem_wr_data),
        .mem_rd_data_o(mem_rd_data)
    );

    // Reader instance
    matrix_reader #(
        .AddrWidth (AddrWidth)
    ) u_reader (
        .clk_i        (clk),
        .rst_ni       (rst_ni),
        .start_i      (start_i),
        .base_addr_i  (base_addr_i),
        .matrix_cols_i(matrix_cols_i),
        .start_row_i  (start_row_i),
        .start_col_i  (start_col_i),
        .busy_o       (busy_o),
        .done_o       (done_o),
        .mem_addr_o   (mem_addr),
        .mem_rd_data_i(mem_rd_data),
        .matrix_o     (tile)
    );

    // Helper: print 4x4 tile
    task automatic print_tile(input string label);
        integer r, c;
        begin
            $display("--- %s ---", label);
            for (r = 0; r < 4; r = r + 1) begin
                $write("Row %0d: ", r);
                for (c = 0; c < 4; c = c + 1) begin
                    $write("%0d ", tile[r][c]);
                end
                $write("\n");
            end
            $display("-----------------------------");
        end
    endtask

    // Helper: trigger one tile read with given start row/col and current stride
    task automatic read_tile_at(
        input int srow,
        input int scol,
        input string label
    );
        begin
            @(posedge clk);
            start_row_i  = srow;
            start_col_i  = scol;
            start_i      = 1'b1;
            @(posedge clk);
            start_i      = 1'b0;

            wait (done_o == 1'b1);
            @(posedge clk);

            print_tile(label);
        end
    endtask

    // Stimulus
    initial begin
        integer addr;
        integer r, c;
        integer idx;

        rst_ni       = 1'b0;
        start_i      = 1'b0;
        base_addr_i  = '0;
        matrix_cols_i= 16;     // stride in elements (can change at runtime)
        start_row_i  = '0;
        start_col_i  = '0;

        // Reset
        #(20);
        rst_ni = 1'b1;

        // Initialize memory with 16x16 row-major matrix: val(r,c) = r*16 + c
        for (addr = 0; addr < DATA_DEPTH; addr = addr + 1) begin
            u_mem.memory[addr] = '0;
        end

        for (r = 0; r < BIG_ROWS; r = r + 1) begin
            for (c = 0; c < BIG_COLS; c = c + 1) begin
                idx = r*BIG_COLS + c; // linear index
                u_mem.memory[idx[AddrWidth-1:0]] = idx[7:0];
            end
        end

        // Peek original 16x16 matrix
        $display("=== ORIGINAL 16x16 MATRIX (row-major) ===");
        for (r = 0; r < BIG_ROWS; r = r + 1) begin
            $write("Row %0d: ", r);
            for (c = 0; c < BIG_COLS; c = c + 1) begin
                idx = r*BIG_COLS + c;
                $write("%0d ", u_mem.memory[idx[AddrWidth-1:0]]);
            end
            $write("\n");
        end
        $display("=========================================");

        // ---- Demonstrate row-stride tile reads ----

        // base_addr_i = 0 => matrix starts at address 0
        base_addr_i = '0;

        // Tile at (0,0): top-left 4x4 of the 16x16 row-major matrix
        // Expect:
        // 0  1  2  3
        // 16 17 18 19
        // 32 33 34 35
        // 48 49 50 51
        read_tile_at(0, 0, "Tile (0,0)");

        // Tile at (3,3)
        // Rows 3..6, Cols 3..6
        read_tile_at(3, 3, "Tile (3,3)");

        // Example of changing stride at runtime:
        // Suppose now we logically treat the matrix as 8 columns
        // (the meaning of data changes, but it shows runtime configurability)
        matrix_cols_i = 8;
        read_tile_at(0, 0, "Tile (0,0) with matrix_cols=8");

        read_tile_at(1, 0, "Tile (1,0) with matrix_cols=8");

        $finish;
    end

endmodule