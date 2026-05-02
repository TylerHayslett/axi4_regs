vcom *.vhd  -mixedsvvh
vlog -sv -sv12compat *.sv  -mixedsvvh

vopt tb_axi4_regs_slave_vhd -o tb_axi4_regs_slave_vhd_opt

vsim -onfinish stop -voptargs="+acc" tb_axi4_regs_slave_vhd

view wave
add wave -position end  sim:/tb_axi4_regs_slave_vhd/*
WaveRestoreZoom {0ps} {400000ps}

run 1000000ps

view wave
WaveRestoreZoom {0ps} {400000ps}
