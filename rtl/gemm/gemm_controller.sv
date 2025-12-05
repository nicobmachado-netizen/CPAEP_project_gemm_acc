//---------------------------
// The GeMM Controller Module
//
// Description:
// This module implements the controller for the 1-MAC GeMM accelerator.
// It manages the operation by controlling the M, K, and N counters,
// which get into the address generation logic in the accelerator top.
//
// Unique to this controller is the interplay of counters and the
// main state machine. The controller uses the counters' last value
// signals to determine when to move to the next state.
//
// Parameters:
// - AddrWidth : Width of the address bus for SRAMs and counters.
//
// Ports:
// - clk_i        : Clock input.
// - rst_ni       : Active-low reset input.
// - start_i      : Start signal to initiate the GeMM operation.
// - input_valid_i: Input valid signal indicating data is ready.
// - result_valid_o: Result valid signal indicating output data is ready.
// - busy_o       : Busy signal indicating the controller is processing.
// - done_o       : Done signal indicating completion of the GeMM operation.
// - M_size_i     : Size of matrix M (number of rows in A and C).
// - K_size_i     : Size of matrix K (number of columns in A and rows in B).
// - N_size_i     : Size of matrix N (number of columns in B and C).
// - M_count_o    : Current count of M dimension.
// - K_count_o    : Current count of K dimension.
// - N_count_o    : Current count of N dimension.
//---------------------------

module gemm_controller #(
  parameter int unsigned AddrWidth = 16,
  parameter int unsigned TileM = 4,
  parameter int unsigned TileK = 4,
  parameter int unsigned TileN = 4
)(
  input  logic clk_i,
  input  logic rst_ni,
  input  logic start_i,
  input  logic input_valid_i,
  output logic result_valid_o,
  output logic busy_o,
  output logic done_o,
  // The target M, K, and N sizes
  input  logic [AddrWidth-1:0] M_size_i,
  input  logic [AddrWidth-1:0] K_size_i,
  input  logic [AddrWidth-1:0] N_size_i,
  // The the current M, K, and N counts
  output logic [AddrWidth-1:0] M_count_o,
  output logic [AddrWidth-1:0] K_count_o,
  output logic [AddrWidth-1:0] N_count_o,
  output logic [AddrWidth-1:0] M_base_o,
  output logic [AddrWidth-1:0] K_base_o,
  output logic [AddrWidth-1:0] N_base_o
);

  //-----------------------
  // Wires and logic
  //-----------------------
  logic move_K_counter;
  logic move_N_counter;
  logic move_M_counter;
  logic move_counter;

  assign move_K_counter = move_counter;

  logic clear_counters;
  logic last_counter_last_value;

 // We assume that M, N and K are multiples of 4 (which is true for the 4 workloads)
localparam int unsigned LOG_TILE_M = 2;
localparam int unsigned LOG_TILE_K = 2;
localparam int unsigned LOG_TILE_N = 2;

logic [AddrWidth-1:0] M_eff_size;
logic [AddrWidth-1:0] N_eff_size;
logic [AddrWidth-1:0] K_eff_size;

assign M_eff_size = M_size_i >> LOG_TILE_M;
assign N_eff_size = N_size_i >> LOG_TILE_N;
assign K_eff_size = K_size_i >> LOG_TILE_K;

assign M_base_o = M_count_o << LOG_TILE_M;
assign N_base_o  = N_count_o << LOG_TILE_N;
assign K_base_o = K_count_o << LOG_TILE_K;

  // State machine states
  typedef enum logic [1:0] {
    ControllerIdle,
    ControllerBusy,
    ControllerFinish
  } controller_state_t;

  controller_state_t current_state, next_state;

  assign busy_o = (current_state == ControllerBusy  ) ||
                  (current_state == ControllerFinish);

// Counters for M, K, N

  // K Counter
  ceiling_counter #(
    .Width        (      AddrWidth ),
    .HasCeiling   (              1 )
  ) i_K_counter (
    .clk_i        ( clk_i          ),
    .rst_ni       ( rst_ni         ),
    .tick_i       ( move_K_counter ),
    .clear_i      ( clear_counters ),
    .ceiling_i    ( K_eff_size     ),
    .count_o      ( K_count_o      ),
    .last_value_o ( move_N_counter )
  );

  // N Counter
  ceiling_counter #(
    .Width        (      AddrWidth ),
    .HasCeiling   (              1 )
  ) i_N_counter (
    .clk_i        ( clk_i          ),
    .rst_ni       ( rst_ni         ),
    .tick_i       ( move_N_counter ),
    .clear_i      ( clear_counters ),
    .ceiling_i    ( N_eff_size     ),
    .count_o      ( N_count_o      ),
    .last_value_o ( move_M_counter )
  );

  // M Counter
  ceiling_counter #(
    .Width        (               AddrWidth ),
    .HasCeiling   (                       1 )
  ) i_M_counter (
    .clk_i        ( clk_i                   ),
    .rst_ni       ( rst_ni                  ),
    .tick_i       ( move_M_counter          ),
    .clear_i      ( clear_counters          ),
    .ceiling_i    ( M_eff_size              ),
    .count_o      ( M_count_o               ),
    .last_value_o ( last_counter_last_value )
  );

// Main controller state machine
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      current_state <= ControllerIdle;
    end else begin
      current_state <= next_state;
    end
  end

  always_comb begin
    // Default assignments
    next_state     = current_state;
    clear_counters = 1'b0;
    move_counter   = 1'b0;
    result_valid_o = 1'b0;
    done_o         = 1'b0;

    case (current_state)
      ControllerIdle: begin
        if (start_i) begin
          move_counter = input_valid_i;
          next_state   = ControllerBusy;
        end
      end

      ControllerBusy: begin
        move_counter = input_valid_i;
        // Check if we are done
        if (last_counter_last_value) begin
          next_state = ControllerFinish;
        end else if (input_valid_i
                     && K_count_o == '0 
                     && (M_count_o != '0 || N_count_o != '0)) begin
          // Check when result_valid_o should be asserted
          result_valid_o = 1'b1;
        end
      end

      ControllerFinish: begin
        done_o         = 1'b1;
        result_valid_o = 1'b1;
        clear_counters = 1'b1;
        next_state     = ControllerIdle;
      end

      default: begin
        next_state = ControllerIdle;
      end
    endcase
  end
endmodule
