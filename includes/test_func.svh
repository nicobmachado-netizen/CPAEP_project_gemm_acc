//--------------------------
// Useful functions for testing
//--------------------------
function automatic void gemm_golden(
  input  logic [AddrWidth-1:0] M,
  input  logic [AddrWidth-1:0] K,
  input  logic [AddrWidth-1:0] N,
  input  logic signed [ InDataWidth-1:0] A_i [DataDepth],
  input  logic signed [ InDataWidth-1:0] B_i [DataDepth],
  output logic signed [OutDataWidth-1:0] Y_o [DataDepth]
);
  int unsigned m, n, k;
  int signed acc;

  for (m = 0; m < M; m++) begin
    for (n = 0; n<N; n++) begin
      acc = 0;
      for (k = 0; k < K; k++) begin
        acc += $signed(A_i[m*K + k]) * $signed(B_i[k*N + n]);
      end
      Y_o[m*N + n] = acc;
    end
end
endfunction