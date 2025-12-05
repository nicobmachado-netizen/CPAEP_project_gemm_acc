`timescale 1ns/1ps

module tb_tile_mac_pe;

localparam int InDataWidth  = 8;
localparam int OutDataWidth = 32;
localparam int sqDim        = 4;
localparam int NumInputs    = 4;

logic clk;
logic rst;
logic a_valid_i, b_valid_i, init_save, acc_clr;

// A and B as 2D arrays
logic signed [InDataWidth-1:0] a_data [sqDim][sqDim];
logic signed [InDataWidth-1:0] b_data [sqDim][sqDim];

// C as 2D array of outputs
logic signed [sqDim][sqDim][OutDataWidth-1:0] c_out;

initial clk = 0;
always #5 clk = ~clk;

tile_mac_pe #(
    .InDataWidth (InDataWidth),
    .OutDataWidth(OutDataWidth),
    .sqDim       (sqDim)
) dut (
    .clk_i      (clk),
    .rst_ni     (rst),
    .a_valid_i  (a_valid_i),
    .b_valid_i  (b_valid_i),
    .init_save_i(init_save),
    .acc_clr_i  (acc_clr),
    .a_data     (a_data),
    .b_data     (b_data),
    .c_out      (c_out)
);

// ---------------------------------------------------------------------------
// Simple task to print a matrix
// ---------------------------------------------------------------------------
task automatic print_matrix_int;
    input string name;
    input int unsigned rows;
    input int unsigned cols;
    input logic signed [InDataWidth-1:0] mat [sqDim][sqDim];
    int i, j;
begin
    $display("%s =", name);
    for (i = 0; i < rows; i++) begin
        $write("  ");
        for (j = 0; j < cols; j++) begin
            $write("%0d", mat[i][j]);
            if (j != cols-1) $write("\t");
        end
        $write("\n");
    end
    $display("");
end
endtask

task automatic print_matrix_out;
    input string name;
    input int unsigned rows;
    input int unsigned cols;
    input logic signed [OutDataWidth-1:0] mat [sqDim][sqDim];
    int i, j;
begin
    $display("%s =", name);
    for (i = 0; i < rows; i++) begin
        $write("  ");
        for (j = 0; j < cols; j++) begin
            $write("%0d", mat[i][j]);
            if (j != cols-1) $write("\t");
        end
        $write("\n");
    end
    $display("");
end
endtask

task automatic print_matrix_out_2;
    input string name;
    input int unsigned rows;
    input int unsigned cols;
    input logic signed [sqDim][sqDim][OutDataWidth-1:0] mat;
    int i, j;
begin
    $display("%s =", name);
    for (i = 0; i < rows; i++) begin
        $write("  ");
        for (j = 0; j < cols; j++) begin
            $write("%0d", mat[i][j]);
            if (j != cols-1) $write("\t");
        end
        $write("\n");
    end
    $display("");
end
endtask

// stimulus
initial begin
    $display("Starting tile simulation");
    rst        = 0;
    a_valid_i  = 0;
    b_valid_i  = 0;
    init_save  = 0;
    acc_clr    = 0;

    #20 rst = 1;

    // -----------------------------------------------------------------------
    // Initialize A and B
    // -----------------------------------------------------------------------
    foreach (a_data[i,j]) begin
        a_data[i][j] = i + j+1;
        b_data[i][j] = i * j+1;
    end

    $display("Input matrices");
    print_matrix_int("A", sqDim, sqDim, a_data);
    print_matrix_int("B", sqDim, sqDim, b_data);

    // -----------------------------------------------------------------------
    // First accumulation
    // -----------------------------------------------------------------------
    a_valid_i = 1;
    b_valid_i = 1;
    init_save = 1;
    #10 init_save = 0;

    // Wait a few cycles so c_out settles (adjust if needed)
    #1;

    $display("Result C = A*B (first accumulation)");
    print_matrix_out_2("C", sqDim, sqDim, c_out);

    // -----------------------------------------------------------------------
    // Second accumulation (accumulate twice)
    // -----------------------------------------------------------------------
    a_valid_i = 1;
    b_valid_i = 1;
    // If needed, change init_save/acc_clr depending on how DUT accumulates
    #10;

    $display("Result C after accumulating twice");
    print_matrix_out_2("C_twice", sqDim, sqDim, c_out);

    // -----------------------------------------------------------------------
    // Reset and check reset behavior
    // -----------------------------------------------------------------------
    rst = 0;
    #10 rst = 1;

    $display("Result C after reset");
    print_matrix_out_2("C_after_reset", sqDim, sqDim, c_out);

    $finish;
end

endmodule

`default_nettype wire