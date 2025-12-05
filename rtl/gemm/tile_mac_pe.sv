module tile_mac_pe #(
    parameter int unsigned OutDataWidth = 32,
    parameter int unsigned InDataWidth = 8,
    
    parameter int sqDim = 4
)(
    input logic clk_i,
    input logic rst_ni,

    //Input for PEs
    input logic signed [InDataWidth-1:0] a_data [sqDim][sqDim],
    input logic signed [InDataWidth-1:0] b_data [sqDim][sqDim],

    input logic a_valid_i, b_valid_i, init_save_i, acc_clr_i,
    
    output logic signed [sqDim][sqDim][OutDataWidth-1:0] c_out

);

genvar i,j,k;
generate
    for (i = 0;i<sqDim;i++) begin
        for (j = 0;j<sqDim;j++) begin

            // Vectors feeding one MAC PE: A row i, B column j
            logic signed [sqDim][InDataWidth-1:0] a_vec;
            logic signed [sqDim][InDataWidth-1:0] b_vec;

            // Build the dot-product operands:
            // a_vec[k] = A[i][k]
            // b_vec[k] = B[k][j]
            for (k = 0; k < sqDim; k++) begin : gen_k
                assign a_vec[k] = a_data[i][k];
                assign b_vec[k] = b_data[k][j];
            end

            general_mac_pe#(
                .InDataWidth(InDataWidth),
                .NumInputs(sqDim),
                .OutDataWidth(OutDataWidth)
            ) mac_pe_inst(
                .clk_i(clk_i),
                .rst_ni(rst_ni),
                .a_i(a_vec),
                .b_i(b_vec),
                .a_valid_i(a_valid_i),
                .b_valid_i(b_valid_i),
                .init_save_i(init_save_i),
                .acc_clr_i(acc_clr_i),
                .c_o(c_out[sqDim-i-1][sqDim-j-1])
            );
        end   
    end
endgenerate

endmodule