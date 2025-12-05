// matrix_reader_rowstride.sv
module matrix_reader #(
    parameter int unsigned AddrWidth = 8
) (
    input  logic                   clk_i,
    input  logic                   rst_ni,

    // Control interface
    input  logic                   start_i,
    input  logic [AddrWidth-1:0]   base_addr_i,    // base address of matrix in memory (word addr)
    input  logic [15:0]            matrix_cols_i,  // number of columns in matrix (stride, in elements)
    input  logic [15:0]            start_row_i,    // tile start row
    input  logic [15:0]            start_col_i,    // tile start col

    output logic                   busy_o,
    output logic                   done_o,         // 1-cycle pulse when 4x4 tile is read

    // Memory interface (1 byte per word)
    output logic [AddrWidth-1:0]   mem_addr_o,
    input  logic signed [7:0]      mem_rd_data_i,

    // 4x4 matrix output (row-major)
    output logic signed [7:0]      matrix_o [0:3][0:3]
);

    typedef enum logic [1:0] {IDLE, READ} state_t;
    state_t state_q, state_d;

    // Latched control inputs
    logic [AddrWidth-1:0] base_addr_q, base_addr_d;
    logic [15:0]          matrix_cols_q, matrix_cols_d;
    logic [15:0]          start_row_q, start_row_d;
    logic [15:0]          start_col_q, start_col_d;

    // Tile row/col indices (0..3)
    logic [1:0] tile_row_q, tile_row_d;
    logic [1:0] tile_col_q, tile_col_d;

    logic busy_q, busy_d;
    logic done_d;

    // Default memory write (read-only)
    assign busy_o        = busy_q;

    // ----------------------------------------------------------------
    // Address generation (row-stride)
    // ----------------------------------------------------------------
    always_comb begin
        int global_row;
        int global_col;
        int elem_index;  // linear index in matrix (row-major)

        mem_addr_o = '0;

        if (state_q == READ) begin
            // Global matrix coordinates of current tile element
            global_row = start_row_q + tile_row_q;
            global_col = start_col_q + tile_col_q;

            // row-major: index = row * matrix_cols + col
            elem_index = global_row * matrix_cols_q + global_col;

            // 1 byte per word => addr = base_addr + elem_index
            mem_addr_o = base_addr_q + elem_index[AddrWidth-1:0];
        end
    end

    // ----------------------------------------------------------------
    // FSM + tile index + data capture
    // ----------------------------------------------------------------
    always_comb begin
        state_d      = state_q;
        base_addr_d  = base_addr_q;
        matrix_cols_d= matrix_cols_q;
        start_row_d  = start_row_q;
        start_col_d  = start_col_q;
        tile_row_d   = tile_row_q;
        tile_col_d   = tile_col_q;
        busy_d       = busy_q;
        done_d       = 1'b0;

        case (state_q)
            IDLE: begin
                busy_d = 1'b0;

                if (start_i) begin
                    // Latch control parameters
                    base_addr_d   = base_addr_i;
                    matrix_cols_d = matrix_cols_i;
                    start_row_d   = start_row_i;
                    start_col_d   = start_col_i;

                    // Start at tile (0,0)
                    tile_row_d = 2'd0;
                    tile_col_d = 2'd0;

                    busy_d  = 1'b1;
                    state_d = READ;
                end
            end

            READ: begin
                busy_d = 1'b1;

                // After mem_addr_o is driven combinationally using tile_row_q/col_q,
                // mem_rd_data_i already contains the correct byte
                // (since memory read is combinational).
                // The actual write into matrix_o happens in the sequential block.

                // Tile index update
                if ((tile_row_q == 2'd3) && (tile_col_q == 2'd3)) begin
                    // Last element of 4x4 tile
                    busy_d  = 1'b0;
                    done_d  = 1'b1;
                    state_d = IDLE;
                end else begin
                    // Move to next element in row-major order inside tile
                    if (tile_col_q == 2'd3) begin
                        tile_col_d = 2'd0;
                        tile_row_d = tile_row_q + 2'd1;
                    end else begin
                        tile_col_d = tile_col_q + 2'd1;
                    end
                end
            end

            default: begin
                state_d = IDLE;
            end
        endcase
    end

    // Sequential part: state, control regs, tile indices, matrix capture
    always_ff @(posedge clk_i or negedge rst_ni) begin
        integer r, c;
        if (!rst_ni) begin
            state_q       <= IDLE;
            base_addr_q   <= '0;
            matrix_cols_q <= '0;
            start_row_q   <= '0;
            start_col_q   <= '0;
            tile_row_q    <= 2'd0;
            tile_col_q    <= 2'd0;
            busy_q        <= 1'b0;
            done_o        <= 1'b0;

            // clear matrix
            for (r = 0; r < 4; r = r + 1) begin
                for (c = 0; c < 4; c = c + 1) begin
                    matrix_o[r][c] <= '0;
                end
            end
        end else begin
            state_q       <= state_d;
            base_addr_q   <= base_addr_d;
            matrix_cols_q <= matrix_cols_d;
            start_row_q   <= start_row_d;
            start_col_q   <= start_col_d;
            tile_row_q    <= tile_row_d;
            tile_col_q    <= tile_col_d;
            busy_q        <= busy_d;
            done_o        <= done_d;

            // Capture data into matrix when in READ
            if (state_q == READ) begin
                matrix_o[tile_row_q][tile_col_q] <= mem_rd_data_i;
            end
        end
    end

endmodule