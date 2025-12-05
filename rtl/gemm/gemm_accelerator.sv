module gemm_accelerator #(
    parameter int unsigned AddrWidth = 16,
    parameter int unsigned InDataWidth = 8,
    parameter int unsigned OutDataWidth = 32,
    parameter int unsigned sqDim = 4
)(
    input  logic                   clk_i,
    input  logic                   rst_ni,

    // Control
    input  logic                   start_i,
    input  logic [15:0]            M_rows_i,   // rows of A, C
    input  logic [15:0]            K_cols_i,   // cols of A / rows of B
    input  logic [15:0]            N_cols_i,   // cols of B, C

    output logic                   busy_o,
    output logic                   done_o,

    // Single-port memory A
    output logic [AddrWidth-1:0]   A_addr_o,
    input  logic signed [7:0]      A_rd_data_i,

    // Single-port memory B
    output logic [AddrWidth-1:0]   B_addr_o,
    input  logic signed [7:0]      B_rd_data_i,

    // Single-port memory C (32-bit data)s
    output logic [AddrWidth-1:0]   C_addr_o,
    output logic signed [OutDataWidth-1:0] C_wr_data_o
);

    // ----------------------------------------------------------------
    // Readers for A and B (4x4 tiles, row-stride)
    // ----------------------------------------------------------------
    logic                   rdA_start, rdA_busy, rdA_done;
    logic [AddrWidth-1:0]   rdA_base_addr;
    logic [15:0]            rdA_cols;
    logic [15:0]            rdA_start_row, rdA_start_col;
    logic signed [7:0]      A_tile [0:sqDim-1][0:sqDim-1];

    matrix_reader #(
        .AddrWidth (AddrWidth)
    ) u_rdA (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .start_i      (rdA_start),
        .base_addr_i  (rdA_base_addr),
        .matrix_cols_i(rdA_cols),
        .start_row_i  (rdA_start_row),
        .start_col_i  (rdA_start_col),
        .busy_o       (rdA_busy),
        .done_o       (rdA_done),
        .mem_addr_o   (A_addr_o),
        .mem_rd_data_i(A_rd_data_i),
        .matrix_o     (A_tile)
    );

    logic                   rdB_start, rdB_busy, rdB_done;
    logic [AddrWidth-1:0]   rdB_base_addr;
    logic [15:0]            rdB_cols;
    logic [15:0]            rdB_start_row, rdB_start_col;
    logic signed [7:0]      B_tile [0:sqDim-1][0:sqDim-1];

    matrix_reader #(
        .AddrWidth (AddrWidth)
    ) u_rdB (
        .clk_i        (clk_i),
        .rst_ni       (rst_ni),
        .start_i      (rdB_start),
        .base_addr_i  (rdB_base_addr),
        .matrix_cols_i(rdB_cols),
        .start_row_i  (rdB_start_row),
        .start_col_i  (rdB_start_col),
        .busy_o       (rdB_busy),
        .done_o       (rdB_done),
        .mem_addr_o   (B_addr_o),
        .mem_rd_data_i(B_rd_data_i),
        .matrix_o     (B_tile)
    );

    // ----------------------------------------------------------------
    // Tile MAC PE (4x4)
    // ----------------------------------------------------------------
    logic a_valid, b_valid, init_save, acc_clr;
    logic signed [sqDim-1:0][sqDim-1:0][OutDataWidth-1:0] C_tile;

    tile_mac_pe #(
        .InDataWidth (InDataWidth),
        .OutDataWidth(OutDataWidth),
        .sqDim       (sqDim)
    ) u_tile_mac (
        .clk_i      (clk_i),
        .rst_ni     (rst_ni),
        .a_data     (A_tile),
        .b_data     (B_tile),
        .a_valid_i  (a_valid),
        .b_valid_i  (b_valid),
        .init_save_i(init_save),
        .acc_clr_i  (acc_clr),
        .c_out      (C_tile)
    );

    // ----------------------------------------------------------------
    // GEMM control FSM
    // ----------------------------------------------------------------
    typedef enum logic [2:0] {
        S_IDLE,
        S_SETUP_TILE,
        S_READ_TILES,
        S_WAIT_TILES,
        S_MAC,
        S_WRITE_C,
        S_NEXT_TILE,
        S_DONE
    } state_t;

    state_t state_q, state_d;

    // Latched sizes
    logic [15:0] M_q, K_q, N_q;
    logic [AddrWidth-1:0] baseA_q, baseB_q, baseC_q;

    // Tile indices
    logic [15:0] tile_m_q, tile_n_q, tile_k_q;
    logic [15:0] tile_m_d, tile_n_d, tile_k_d;

    // How many tiles
    logic [15:0] M_tiles_q, N_tiles_q, K_tiles_q;

    // Counters for writing C tile
    logic [1:0]  wr_row_q, wr_col_q;
    logic [1:0]  wr_row_d, wr_col_d;

    // Control outputs defaults
    assign C_we_o = (state_q == S_WRITE_C);

    // Busy / done
    assign busy_o = (state_q != S_IDLE) && (state_q != S_DONE);

    // Combinational next-state
    always_comb begin
        state_d   = state_q;
        done_o    = 1'b0;

        // Defaults
        rdA_start = 1'b0;
        rdB_start = 1'b0;

        a_valid   = 1'b0;
        b_valid   = 1'b0;
        init_save = 1'b0;
        acc_clr   = 1'b0;

        tile_m_d  = tile_m_q;
        tile_n_d  = tile_n_q;
        tile_k_d  = tile_k_q;

        wr_row_d  = wr_row_q;
        wr_col_d  = wr_col_q;

        // Reader parameters (updated in S_SETUP_TILE)
        rdA_base_addr = '0;
        rdB_base_addr = '0;
        rdA_cols      = K_q;
        rdB_cols      = N_q;

        rdA_start_row = tile_m_q * sqDim;
        rdA_start_col = tile_k_q * sqDim;
        rdB_start_row = tile_k_q * sqDim;
        rdB_start_col = tile_n_q * sqDim;

        case (state_q)
            S_IDLE: begin
                if (start_i) begin
                    // tiles sizes: assume divisible by 4
                    state_d  = S_SETUP_TILE;
                end
            end

            S_SETUP_TILE: begin
                // Setup first k-block for current (tile_m, tile_n)
                tile_k_d = 16'd0;
                // clear accumulator
                acc_clr  = 1'b1;
                state_d  = S_READ_TILES;
            end

            S_READ_TILES: begin
                // Trigger readers for A_tile(m, k) and B_tile(k, n)
                rdA_start = 1'b1;
                rdB_start = 1'b1;
                state_d   = S_WAIT_TILES;
            end

            S_WAIT_TILES: begin
                if (rdA_done && rdB_done) begin
                    state_d = S_MAC;
                end
            end

            S_MAC: begin
                // One-cycle MAC for this A_tile,B_tile
                a_valid   = 1'b1;
                b_valid   = 1'b1;
                init_save = (tile_k_q == 16'd0);  // overwrite on first, accumulate later

                // Next k-block or write C
                if (tile_k_q + 16'd1 < K_tiles_q) begin
                    tile_k_d = tile_k_q + 16'd1;
                    state_d  = S_READ_TILES;
                end else begin
                    // All k-tiles done for this C tile
                    wr_row_d = 2'd0;
                    wr_col_d = 2'd0;
                    state_d  = S_WRITE_C;
                end
            end

            S_WRITE_C: begin
                // Write one element of 4x4 C_tile back to memory C each cycle
                // row/col in C:
                int g_row;
                int g_col;
                int elem_index;

                g_row = tile_m_q * sqDim + wr_row_q;
                g_col = tile_n_q * sqDim + wr_col_q;
                elem_index = g_row * N_q + g_col;

                C_addr_o    = baseC_q + elem_index[AddrWidth-1:0];
                C_wr_data_o = C_tile[wr_row_q][wr_col_q]; // full 32-bit value

                // advance tile write indices
                if ((wr_row_q == sqDim-1) && (wr_col_q == sqDim-1)) begin
                    state_d = S_NEXT_TILE;
                end else begin
                    if (wr_col_q == sqDim-1) begin
                        wr_col_d = 2'd0;
                        wr_row_d = wr_row_q + 2'd1;
                    end else begin
                        wr_col_d = wr_col_q + 2'd1;
                    end
                end
            end

            S_NEXT_TILE: begin
                // Move to next (tile_m, tile_n)
                if (tile_n_q + 16'd1 < N_tiles_q) begin
                    tile_n_d = tile_n_q + 16'd1;
                    state_d  = S_SETUP_TILE;
                end else if (tile_m_q + 16'd1 < M_tiles_q) begin
                    tile_n_d = 16'd0;
                    tile_m_d = tile_m_q + 16'd1;
                    state_d  = S_SETUP_TILE;
                end else begin
                    state_d = S_DONE;
                end
            end

            S_DONE: begin
                done_o = 1'b1;
                if (!start_i) begin
                    state_d = S_IDLE;
                end
            end

            default: state_d = S_IDLE;
        endcase
    end

    // Sequential: latch sizes, tile counts, indices, base addresses
    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            state_q    <= S_IDLE;
            M_q        <= '0;
            K_q        <= '0;
            N_q        <= '0;
            baseA_q    <= '0;
            baseB_q    <= '0;
            baseC_q    <= '0;
            tile_m_q   <= '0;
            tile_n_q   <= '0;
            tile_k_q   <= '0;
            M_tiles_q  <= '0;
            N_tiles_q  <= '0;
            K_tiles_q  <= '0;
            wr_row_q   <= 2'd0;
            wr_col_q   <= 2'd0;
        end else begin
            state_q <= state_d;

            if (state_q == S_IDLE && start_i) begin
                // Latch sizes and bases once at start
                M_q     <= M_rows_i;
                K_q     <= K_cols_i;
                N_q     <= N_cols_i;
                baseA_q <= '0;
                baseB_q <= '0;
                baseC_q <= '0;

                tile_m_q  <= 16'd0;
                tile_n_q  <= 16'd0;

                // tiles = size / 4 (assumes divisible by 4)
                M_tiles_q <= M_rows_i >> 2;
                K_tiles_q <= K_cols_i >> 2;
                N_tiles_q <= N_cols_i >> 2;
            end else begin
                tile_m_q <= tile_m_d;
                tile_n_q <= tile_n_d;
                tile_k_q <= tile_k_d;
                wr_row_q <= wr_row_d;
                wr_col_q <= wr_col_d;
            end
        end
    end

endmodule