vlib work
vlog +cover +acc -sv -f flists/tb_gemm_accelerator.flist +incdir+.
vsim -voptargs="+acc" -coverage work.tb_gemm_accelerator
add wave -r /*
run -all
