UNET_EXTRA_SRCS = $(UNET_SRC_DIR)/aurora_framing_aurora_lane.v \
		$(UNET_SRC_DIR)/aurora_framing_channel_error_detect.v \
		$(UNET_SRC_DIR)/aurora_framing_channel_init_sm.v \
		$(UNET_SRC_DIR)/aurora_framing_chbond_count_dec.v \
		$(UNET_SRC_DIR)/aurora_framing_error_detect.v \
		$(UNET_SRC_DIR)/aurora_framing_global_logic.v \
		$(UNET_SRC_DIR)/aurora_framing_idle_and_ver_gen.v \
		$(UNET_SRC_DIR)/aurora_framing_lane_init_sm.v \
		$(UNET_SRC_DIR)/aurora_framing_phase_align.v \
		$(UNET_SRC_DIR)/aurora_framing_rx_ll_nfc.v \
		$(UNET_SRC_DIR)/aurora_framing_rx_ll_pdu_datapath.v \
		$(UNET_SRC_DIR)/aurora_framing_rx_ll.v \
		$(UNET_SRC_DIR)/aurora_framing_sym_dec.v \
		$(UNET_SRC_DIR)/aurora_framing_sym_gen.v \
		$(UNET_SRC_DIR)/aurora_framing_tx_ll_control.v \
		$(UNET_SRC_DIR)/aurora_framing_tx_ll_datapath.v \
		$(UNET_SRC_DIR)/aurora_framing_tx_ll.v \
		$(UNET_SRC_DIR)/aurora_framing.v \
		$(UNET_SRC_DIR)/aurora_framing_frame_check.v \
		$(UNET_SRC_DIR)/aurora_framing_frame_gen.v \
		$(UNET_SRC_DIR)/aurora_framing_standard_cc_module.v

EXTRA_XILINX_LIBS_DIR = /hd/mckeown_users/jnaous/cad/xilinx/ise9.1i/verilog/mti_se
EXTRA_XILINX_LIBS = -y $(EXTRA_XILINX_LIBS_DIR)/simprims_ver -y $(EXTRA_XILINX_LIBS_DIR)/unisims_ver -y $(EXTRA_XILINX_LIBS_DIR)/XilinxCoreLib_ver
