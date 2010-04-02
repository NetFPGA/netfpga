add wave -divider "Core Clocks"
add wave testbench/u_board/nf2_top/nf2_core/core_clk_int
add wave testbench/u_board/nf2_top/nf2_core/cpci_clk_int
add wave testbench/u_board/nf2_top/nf2_core/clk_ddr_200
add wave testbench/u_board/nf2_top/nf2_core/clk90_ddr_200
add wave testbench/u_board/nf2_top/core_locked

add wave -divider "mem_interface"
add wave testbench/u_board/nf2_top/mem_interface_top/infrastructure_top0/dcm_lock
add wave testbench/u_board/nf2_top/mem_interface_top/infrastructure_top0/sys_clk_ibuf
add wave testbench/u_board/nf2_top/mem_interface_top/infrastructure_top0/user_rst
add wave testbench/u_board/nf2_top/mem_interface_top/infrastructure_top0/clk_int
add wave testbench/u_board/nf2_top/mem_interface_top/infrastructure_top0/clk90_int

add wave -divider "User DDR signals"
add wave -hex testbench/u_board/nf2_top/nf2_core/ddr2_addr
add wave testbench/u_board/nf2_top/nf2_core/ddr2_bank_addr
add wave testbench/u_board/nf2_top/nf2_core/ddr2_cmd
add wave testbench/u_board/nf2_top/nf2_core/ddr2_cmd_ack
add wave testbench/u_board/nf2_top/nf2_core/ddr2_burst_done
add wave -hex testbench/u_board/nf2_top/nf2_core/ddr2_rd_data
add wave testbench/u_board/nf2_top/nf2_core/ddr2_rd_data_valid
add wave -hex testbench/u_board/nf2_top/nf2_core/ddr2_wr_data
add wave testbench/u_board/nf2_top/nf2_core/ddr2_wr_data_mask
add wave testbench/u_board/nf2_top/nf2_core/ddr2_init_val
add wave testbench/u_board/nf2_top/nf2_core/ddr2_reset
add wave testbench/u_board/nf2_top/nf2_core/ddr2_reset90

add wave -divider "DDR2 Test signals"
add wave -unsigned testbench/u_board/nf2_top/nf2_core/ddr2_test/rd_pre_cnt
add wave -unsigned testbench/u_board/nf2_top/nf2_core/ddr2_test/rd_cnt
add wave -unsigned testbench/u_board/nf2_top/nf2_core/ddr2_test/wr_pre_cnt
add wave -unsigned testbench/u_board/nf2_top/nf2_core/ddr2_test/wr_cnt
add wave -unsigned testbench/u_board/nf2_top/nf2_core/ddr2_test/data_xfer
add wave testbench/u_board/nf2_top/nf2_core/ddr2_test/auto_ref_req
add wave testbench/u_board/nf2_top/nf2_core/ddr2_test/ar_done
add wave -unsigned testbench/u_board/nf2_top/nf2_core/ddr2_test/test_num
add wave -unsigned testbench/u_board/nf2_top/nf2_core/ddr2_test/test_state
add wave -unsigned testbench/u_board/nf2_top/nf2_core/ddr2_test/state
add wave -hex testbench/u_board/nf2_top/nf2_core/ddr2_test/wr_addr
add wave testbench/u_board/nf2_top/nf2_core/ddr2_test/wr_bank
add wave -hex testbench/u_board/nf2_top/nf2_core/ddr2_test/rd_addr
add wave testbench/u_board/nf2_top/nf2_core/ddr2_test/rd_bank
add wave testbench/u_board/nf2_top/nf2_core/dram_done
add wave testbench/u_board/nf2_top/nf2_core/dram_success

run 2020ns
wave zoomrange 1960ns 2020ns
