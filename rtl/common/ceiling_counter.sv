//-----------------------------
// Ceiling Counter
//
// Description:
// This module implements a ceiling counter that counts up to a specified
// ceiling value. It supports an optional ceiling limit and provides a
// signal indicating when the counter has reached its last value.
//
// Parameters:
// - Width      : Width of the counter.
// - HasCeiling : If set to 1, the counter wraps around at the ceiling
//                value; if set to 0, it is a free-running counter.
// Ports:
// - clk_i        : Clock input.
// - rst_ni       : Active-low reset input.
// - tick_i       : Tick input to increment the counter.
// - clear_i      : Active-high synchronous clear input.
// - ceiling_i    : Ceiling value input.
// - count_o      : Current counter value output.
// - last_value_o : Output signal that is high when the counter reaches
//                  its last value on a tick.
//-----------------------------

module ceiling_counter #(
  parameter int Width      = 8,
  parameter int HasCeiling = 1
) (
  input  logic             clk_i,
  input  logic             rst_ni,       // active-low async reset
  input  logic             tick_i,
  input  logic             clear_i,      // active-high sync clear
  input  logic [Width-1:0] ceiling_i,
  output logic [Width-1:0] count_o,
  output logic             last_value_o
);

  // Main counter
  always_ff @(posedge clk_i or negedge rst_ni) begin
    if (!rst_ni) begin
      // Asynchronous reset to 0
      count_o <= '0;
    end else if (clear_i) begin
      // Synchronous "clear" input
      count_o <= '0;
    end else if (tick_i) begin
      // Only update on tick
      if (HasCeiling) begin
        // Compare against (ceiling_i - 1)
        if (count_o < (ceiling_i - 1'b1))
          count_o <= count_o + 1'b1;
        else count_o <= '0;
      end else begin
        // Free-running counter
        count_o <= count_o + 1'b1;
      end
    end
  end

  always_comb begin
    if (HasCeiling) begin
      // last_value_o is true if count_o == (ceiling_i - 1) AND a tick occurs
      last_value_o = (count_o == (ceiling_i - 1'b1)) && tick_i;
    end else begin
      // last_value_o is true if all bits of count_o are 1 AND a tick occurs
      last_value_o = (&count_o) && tick_i;
    end
  end

endmodule
