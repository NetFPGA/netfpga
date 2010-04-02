///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2007/01/05 06:08:33 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: aurora.ejava,v $
//          Rev:  $Revision: 1.1.2.3 $
//
//      Company:  Xilinx
// Contributors:  R. K. Awalt, B. L. Woodard, N. Gulstone
//
//   Disclaimer:  XILINX IS PROVIDING THIS DESIGN, CODE, OR
//                INFORMATION "AS IS" SOLELY FOR USE IN DEVELOPING
//                PROGRAMS AND SOLUTIONS FOR XILINX DEVICES.  BY
//                PROVIDING THIS DESIGN, CODE, OR INFORMATION AS
//                ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE,
//                APPLICATION OR STANDARD, XILINX IS MAKING NO
//                REPRESENTATION THAT THIS IMPLEMENTATION IS FREE
//                FROM ANY CLAIMS OF INFRINGEMENT, AND YOU ARE
//                RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY
//                REQUIRE FOR YOUR IMPLEMENTATION.  XILINX
//                EXPRESSLY DISCLAIMS ANY WARRANTY WHATSOEVER WITH
//                RESPECT TO THE ADEQUACY OF THE IMPLEMENTATION,
//                INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR
//                REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE
//                FROM CLAIMS OF INFRINGEMENT, IMPLIED WARRANTIES
//                OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
//                PURPOSE.
//
//                (c) Copyright 2004 Xilinx, Inc.
//                All rights reserved.
//
///////////////////////////////////////////////////////////////////////////////
//
//  aurora_framing
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: This is the top level module for a 1 2-byte lane Aurora
//               reference design module. This module supports the following features:
//
//               * Immediate Mode Native Flow Control
//               * Supports Virtex 2 Pro
//

`timescale 1 ns / 10 ps

module aurora_framing
(
    // LocalLink TX Interface
    TX_D,
    TX_REM,
    TX_SRC_RDY_N,
    TX_SOF_N,
    TX_EOF_N,

    TX_DST_RDY_N,


    // LocalLink RX Interface
    RX_D,
    RX_REM,
    RX_SRC_RDY_N,
    RX_SOF_N,
    RX_EOF_N,

    // Native Flow Control Interface
    NFC_REQ_N,
    NFC_NB,
    NFC_ACK_N,



    // MGT Serial I/O
    RXP,
    RXN,

    TXP,
    TXN,


    // MGT Reference Clock Interface
    TOP_REF_CLK,


    // Error Detection Interface
    HARD_ERROR,
    SOFT_ERROR,
    FRAME_ERROR,


    // Status
    CHANNEL_UP,
    LANE_UP,


    // Clock Compensation Control Interface
    WARN_CC,
    DO_CC,


    // System Interface
    DCM_NOT_LOCKED,
    USER_CLK,
    RESET,
    POWER_DOWN,
    LOOPBACK

);

`define DLY #1


//*******************************Parameter Declarations******************************

    parameter   EXTEND_WATCHDOGS    =   0;


//***********************************Port Declarations*******************************


    // LocalLink TX Interface
    input   [0:15]     TX_D;
    input              TX_REM;
    input              TX_SRC_RDY_N;
    input              TX_SOF_N;
    input              TX_EOF_N;

    output             TX_DST_RDY_N;


    // LocalLink RX Interface
    output  [0:15]     RX_D;
    output             RX_REM;
    output             RX_SRC_RDY_N;
    output             RX_SOF_N;
    output             RX_EOF_N;

    // Native Flow Control Interface
    input              NFC_REQ_N;
    input   [0:3]      NFC_NB;

    output             NFC_ACK_N;



    // MGT Serial I/O
    input              RXP;
    input              RXN;

    output             TXP;
    output             TXN;


    // MGT Reference Clock Interface
    input              TOP_REF_CLK;


    // Error Detection Interface
    output             HARD_ERROR;
    output             SOFT_ERROR;
    output             FRAME_ERROR;


    // Status
    output             CHANNEL_UP;
    output             LANE_UP;


    // Clock Compensation Control Interface
    input              WARN_CC;
    input              DO_CC;


    // System Interface
    input              DCM_NOT_LOCKED;
    input              USER_CLK;
    input              RESET;
    input              POWER_DOWN;
    input   [1:0]      LOOPBACK;




//*********************************Wire Declarations**********************************

    wire    [15:0]     rx_data_i;
    wire    [1:0]      rx_not_in_table_i;
    wire    [1:0]      rx_disp_err_i;
    wire    [1:0]      rx_char_is_k_i;
    wire    [1:0]      rx_char_is_comma_i;
    wire               rx_buf_status_i;
    wire               tx_buf_err_i;
    wire    [1:0]      tx_k_err_i;
    wire    [2:0]      rx_clk_cor_cnt_i;
    wire               rx_realign_i;

    wire               rx_polarity_i;
    wire               rx_reset_i;
    wire    [1:0]      tx_char_is_k_i;
    wire    [15:0]     tx_data_i;
    wire               tx_reset_i;

    wire               ena_comma_align_i;


    wire               gen_scp_i;
    wire               gen_snf_i;
    wire    [0:3]      fc_nb_i;

    wire               gen_ecp_i;
    wire               gen_pad_i;
    wire    [0:15]     tx_pe_data_i;
    wire               tx_pe_data_v_i;
    wire               gen_cc_i;

    wire               rx_pad_i;
    wire    [0:15]     rx_pe_data_i;
    wire               rx_pe_data_v_i;
    wire               rx_scp_i;
    wire               rx_ecp_i;
    wire               rx_snf_i;
    wire    [0:3]      rx_fc_nb_i;

    wire               gen_a_i;
    wire    [0:1]      gen_k_i;
    wire    [0:1]      gen_r_i;
    wire    [0:1]      gen_v_i;

    wire               lane_up_i;
    wire               soft_error_i;
    wire               hard_error_i;
    wire               channel_bond_load_i;
    wire    [0:1]      got_a_i;
    wire               got_v_i;

    wire               reset_lanes_i;

    wire               rx_rec_clk_i;
    wire               ena_calign_rec_i;

    wire    [15:0]     open_rx_data_i;
    wire    [1:0]      open_rx_not_in_table_i;
    wire    [1:0]      open_rx_disp_err_i;
    wire    [1:0]      open_rx_char_is_k_i;
    wire    [1:0]      open_rx_char_is_comma_i;
    wire               open_rx_buf_status_i;
    wire    [1:0]      open_tx_k_err_i;


    wire               open_config_out_i;
    wire               open_rx_checking_crc_i;
    wire               open_rx_comma_det_i;
    wire               open_rx_crc_err_i;
    wire    [1:0]      open_rx_loss_of_sync_i;
    wire    [3:0]      open_rx_run_disp_i;
    wire    [3:0]      open_tx_run_disp_i;

    wire               ch_bond_done_i;
    wire               en_chan_sync_i;
    wire               channel_up_i;
    wire               start_rx_i;
    wire               tx_wait_i;
    wire               decrement_nfc_i;


    wire    [3:0]      chbondi_not_used_i;
    wire    [3:0]      chbondo_not_used_i;

    wire               tied_to_ground_i;
    wire               tied_to_vcc_i;
    wire               system_reset_c;




//*********************************Main Body of Code**********************************



    assign          tied_to_ground_i = 1'b0;
    assign          tied_to_vcc_i    = 1'b1;
    assign          chbondi_not_used_i = 4'b0;

    assign          CHANNEL_UP  =   channel_up_i;
    assign          system_reset_c = RESET || DCM_NOT_LOCKED;

    aurora_framing_PHASE_ALIGN  aurora_framing_lane_phase_align_i
    (
        // Aurora Lane Interface
        .ENA_COMMA_ALIGN(ena_comma_align_i),


        // MGT Interface
        .RX_REC_CLK(rx_rec_clk_i),

        .ENA_CALIGN_REC(ena_calign_rec_i)
    );


    //_________________________Instantiate Lane 0______________________________


    assign          LANE_UP =   lane_up_i;

    defparam aurora_framing_aurora_lane_0_i.EXTEND_WATCHDOGS = EXTEND_WATCHDOGS;
    aurora_framing_AURORA_LANE aurora_framing_aurora_lane_0_i
    (
        // MGT Interface
        .RX_DATA(rx_data_i[15:0]),
        .RX_NOT_IN_TABLE(rx_not_in_table_i[1:0]),
        .RX_DISP_ERR(rx_disp_err_i[1:0]),
        .RX_CHAR_IS_K(rx_char_is_k_i[1:0]),
        .RX_CHAR_IS_COMMA(rx_char_is_comma_i[1:0]),
        .RX_BUF_STATUS(rx_buf_status_i),
        .TX_BUF_ERR(tx_buf_err_i),
        .TX_K_ERR(tx_k_err_i[1:0]),
        .RX_CLK_COR_CNT(rx_clk_cor_cnt_i[2:0]),
        .RX_REALIGN(rx_realign_i),

        .RX_POLARITY(rx_polarity_i),
        .RX_RESET(rx_reset_i),
        .TX_CHAR_IS_K(tx_char_is_k_i[1:0]),
        .TX_DATA(tx_data_i[15:0]),
        .TX_RESET(tx_reset_i),


        // Comma Detect Phase Align Interface
        .ENA_COMMA_ALIGN(ena_comma_align_i),



        // TX_LL Interface
        .GEN_SCP(gen_scp_i),
        .GEN_SNF(gen_snf_i),
        .FC_NB(fc_nb_i),

        .GEN_ECP(gen_ecp_i),
        .GEN_PAD(gen_pad_i),
        .TX_PE_DATA(tx_pe_data_i[0:15]),
        .TX_PE_DATA_V(tx_pe_data_v_i),
        .GEN_CC(gen_cc_i),


        // RX_LL Interface
        .RX_PAD(rx_pad_i),
        .RX_PE_DATA(rx_pe_data_i[0:15]),
        .RX_PE_DATA_V(rx_pe_data_v_i),
        .RX_SCP(rx_scp_i),
        .RX_ECP(rx_ecp_i),
        .RX_SNF(rx_snf_i),
        .RX_FC_NB(rx_fc_nb_i[0:3]),



        // Global Logic Interface
        .GEN_A(gen_a_i),
        .GEN_K(gen_k_i[0:1]),
        .GEN_R(gen_r_i[0:1]),
        .GEN_V(gen_v_i[0:1]),

        .LANE_UP(lane_up_i),
        .SOFT_ERROR(soft_error_i),
        .HARD_ERROR(hard_error_i),
        .CHANNEL_BOND_LOAD(channel_bond_load_i),
        .GOT_A(got_a_i[0:1]),
        .GOT_V(got_v_i),


        // System Interface
        .USER_CLK(USER_CLK),
        .RESET(reset_lanes_i)
    );

/*
    aurora_framing_PHASE_ALIGN  aurora_framing_lane_0_phase_align_i
    (
        // Aurora Lane Interface
        .ENA_COMMA_ALIGN(ena_comma_align_i),


        // MGT Interface
        .RX_REC_CLK(rx_rec_clk_i),

        .ENA_CALIGN_REC(ena_calign_rec_i)
    );
*/


    GT_CUSTOM  lane_0_mgt_i
    (
        // Aurora Lane Interface
        .RXPOLARITY(rx_polarity_i),
        .RXRESET(rx_reset_i),
        .TXCHARISK({2'b0, tx_char_is_k_i[1:0]}),
        .TXDATA({16'b0, tx_data_i[15:0]}),
        .TXRESET(tx_reset_i),

        .RXDATA({open_rx_data_i[15:0], rx_data_i[15:0]}),
        .RXNOTINTABLE({open_rx_not_in_table_i[1:0], rx_not_in_table_i[1:0]}),
        .RXDISPERR({open_rx_disp_err_i[1:0], rx_disp_err_i[1:0]}),
        .RXCHARISK({open_rx_char_is_k_i[1:0], rx_char_is_k_i[1:0]}),
        .RXCHARISCOMMA({open_rx_char_is_comma_i[1:0], rx_char_is_comma_i[1:0]}),
        .RXBUFSTATUS({rx_buf_status_i,open_rx_buf_status_i}),
        .TXBUFERR(tx_buf_err_i),
        .TXKERR({open_tx_k_err_i[1:0], tx_k_err_i[1:0]}),
        .RXCLKCORCNT(rx_clk_cor_cnt_i[2:0]),
        .RXREALIGN(rx_realign_i),


        // Phase Align Interface
        .ENMCOMMAALIGN(ena_calign_rec_i),
        .ENPCOMMAALIGN(ena_calign_rec_i),

        .RXRECCLK(rx_rec_clk_i),


        // Global Logic Interface
        .ENCHANSYNC(tied_to_ground_i),

        .CHBONDDONE(ch_bond_done_i),


        // Peer Channel Bonding Interface
        .CHBONDI(chbondi_not_used_i),

        .CHBONDO(chbondo_not_used_i[3:0]),


        // Unused MGT Ports
        .CONFIGOUT(open_config_out_i),
        .RXCHECKINGCRC(open_rx_checking_crc_i),
        .RXCOMMADET(open_rx_comma_det_i),
        .RXCRCERR(open_rx_crc_err_i),
        .RXLOSSOFSYNC(open_rx_loss_of_sync_i[1:0]),
        .RXRUNDISP(open_rx_run_disp_i[3:0]),
        .TXRUNDISP(open_tx_run_disp_i[3:0]),


        // Fixed MGT settings for Aurora
        .TXBYPASS8B10B(4'b0),
        .TXCHARDISPMODE(4'b0),
        .TXCHARDISPVAL(4'b0),
        .CONFIGENABLE(1'b0),
        .CONFIGIN(1'b0),
        .TXFORCECRCERR(1'b0),
        .TXINHIBIT(1'b0),
        .TXPOLARITY(1'b0),


        // Serial IO
        .RXN(RXN),
        .RXP(RXP),

        .TXN(TXN),
        .TXP(TXP),


        // Reference Clocks and User Clock
        .RXUSRCLK(USER_CLK),
        .RXUSRCLK2(USER_CLK),
        .TXUSRCLK(USER_CLK),
        .TXUSRCLK2(USER_CLK),
        .BREFCLK(tied_to_ground_i),
        .BREFCLK2(tied_to_ground_i),
        .REFCLK(TOP_REF_CLK),
        .REFCLK2(tied_to_ground_i),
        .REFCLKSEL(1'b0),




        // System Interface
        .LOOPBACK(LOOPBACK),
        .POWERDOWN(POWER_DOWN)

    );

    // Lane 0 MGT attributes.

    defparam
        lane_0_mgt_i.ALIGN_COMMA_MSB          = "TRUE",
        lane_0_mgt_i.CHAN_BOND_MODE           = "OFF",
        lane_0_mgt_i.CHAN_BOND_ONE_SHOT       = "FALSE",
        lane_0_mgt_i.CHAN_BOND_SEQ_1_1        = 11'B00101111100,
        lane_0_mgt_i.REF_CLK_V_SEL            = 0,
        lane_0_mgt_i.CLK_COR_INSERT_IDLE_FLAG = "FALSE",
        lane_0_mgt_i.CLK_COR_KEEP_IDLE        = "FALSE",
        lane_0_mgt_i.CLK_COR_REPEAT_WAIT      = 8,
        lane_0_mgt_i.CLK_COR_SEQ_1_1          = 11'B00111110111,
        lane_0_mgt_i.CLK_COR_SEQ_1_2          = 11'B00111110111,
        lane_0_mgt_i.CLK_COR_SEQ_2_USE        = "FALSE",
        lane_0_mgt_i.CLK_COR_SEQ_LEN          = 2,
        lane_0_mgt_i.CLK_CORRECT_USE          = "TRUE",
        lane_0_mgt_i.COMMA_10B_MASK           = 10'B1111111111,
        lane_0_mgt_i.MCOMMA_10B_VALUE         = 10'B1100000101,
        lane_0_mgt_i.PCOMMA_10B_VALUE         = 10'B0011111010,
        lane_0_mgt_i.RX_CRC_USE               = "FALSE",
        lane_0_mgt_i.RX_DATA_WIDTH            = 2,
        lane_0_mgt_i.RX_LOSS_OF_SYNC_FSM      = "FALSE",
        lane_0_mgt_i.RX_LOS_INVALID_INCR      = 1,
        lane_0_mgt_i.RX_LOS_THRESHOLD         = 4,
        lane_0_mgt_i.SERDES_10B               = "FALSE",
        lane_0_mgt_i.TERMINATION_IMP          = 50,
        lane_0_mgt_i.TX_CRC_USE               = "FALSE",
        lane_0_mgt_i.TX_DATA_WIDTH            = 2,
        lane_0_mgt_i.TX_DIFF_CTRL             = 600,
        lane_0_mgt_i.TX_PREEMPHASIS           = 1;




    //__________Instantiate Global Logic to combine Lanes into a Channel______

    defparam aurora_framing_global_logic_i.EXTEND_WATCHDOGS = EXTEND_WATCHDOGS;
    aurora_framing_GLOBAL_LOGIC    aurora_framing_global_logic_i
    (
        // MGT Interface
        .CH_BOND_DONE(ch_bond_done_i),

        .EN_CHAN_SYNC(en_chan_sync_i),


        // Aurora Lane Interface
        .LANE_UP(lane_up_i),
        .SOFT_ERROR(soft_error_i),
        .HARD_ERROR(hard_error_i),
        .CHANNEL_BOND_LOAD(channel_bond_load_i),
        .GOT_A(got_a_i),
        .GOT_V(got_v_i),

        .GEN_A(gen_a_i),
        .GEN_K(gen_k_i),
        .GEN_R(gen_r_i),
        .GEN_V(gen_v_i),
        .RESET_LANES(reset_lanes_i),


        // System Interface
        .USER_CLK(USER_CLK),
        .RESET(system_reset_c),
        .POWER_DOWN(POWER_DOWN),

        .CHANNEL_UP(channel_up_i),
        .START_RX(start_rx_i),
        .CHANNEL_SOFT_ERROR(SOFT_ERROR),
        .CHANNEL_HARD_ERROR(HARD_ERROR)

    );



    //_____________________________Instantiate TX_LL___________________________

    aurora_framing_TX_LL aurora_framing_tx_ll_i
    (
        // LocalLink PDU Interface
        .TX_D(TX_D),
        .TX_REM(TX_REM),
        .TX_SRC_RDY_N(TX_SRC_RDY_N),
        .TX_SOF_N(TX_SOF_N),
        .TX_EOF_N(TX_EOF_N),

        .TX_DST_RDY_N(TX_DST_RDY_N),

        // NFC Interface
        .NFC_REQ_N(NFC_REQ_N),
        .NFC_NB(NFC_NB),

        .NFC_ACK_N(NFC_ACK_N),

        // Clock Compenstaion Interface
        .WARN_CC(WARN_CC),
        .DO_CC(DO_CC),


        // Global Logic Interface
        .CHANNEL_UP(channel_up_i),


        // Aurora Lane Interface
        .GEN_SCP(gen_scp_i),
        .GEN_ECP(gen_ecp_i),
        .GEN_SNF(gen_snf_i),
        .FC_NB(fc_nb_i),
        .TX_PE_DATA_V(tx_pe_data_v_i),
        .GEN_PAD(gen_pad_i),
        .TX_PE_DATA(tx_pe_data_i),
        .GEN_CC(gen_cc_i),

        // RX_LL Interface
        .TX_WAIT(tx_wait_i),

        .DECREMENT_NFC(decrement_nfc_i),

        // System Interface
        .USER_CLK(USER_CLK)


    );




    //______________________________________Instantiate RX_LL__________________________________

    aurora_framing_RX_LL   aurora_framing_rx_ll_i
    (
        // LocalLink PDU Interface
        .RX_D(RX_D),
        .RX_REM(RX_REM),
        .RX_SRC_RDY_N(RX_SRC_RDY_N),
        .RX_SOF_N(RX_SOF_N),
        .RX_EOF_N(RX_EOF_N),


        // Global Logic Interface
        .START_RX(start_rx_i),


        // Aurora Lane Interface
        .RX_PAD(rx_pad_i),
        .RX_PE_DATA(rx_pe_data_i),
        .RX_PE_DATA_V(rx_pe_data_v_i),
        .RX_SCP(rx_scp_i),
        .RX_ECP(rx_ecp_i),
        .RX_SNF(rx_snf_i),
        .RX_FC_NB(rx_fc_nb_i),


        // TX_LL Interface
        .DECREMENT_NFC(decrement_nfc_i),

        .TX_WAIT(tx_wait_i),
        // Error Interface
        .FRAME_ERROR(FRAME_ERROR),

        // System Interface
        .USER_CLK(USER_CLK)

    );

endmodule
