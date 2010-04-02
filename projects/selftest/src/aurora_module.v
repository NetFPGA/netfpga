//////////////////////////////////////////////////////////////////////////////
// $Id: aurora_module.v 2271 2007-09-18 04:14:11Z jnaous $
//
// Module: aurora_module.v
// Project: SERIAL
// Description: Aurora Core wrapper
//
// This module is a wrapper around the Aurora Core that provides inputs and
// to be sent to the register file and user pins. There are two modes to choose
// from: test_mode disregards any inputs on the data lines and sets the module
// to generate data and receive the data and check for its validity. Normal mode
// uses the data lines from the user interface.
// loopback[1:0] chooses whether the output should be looped back to the input.
// See ug024 (RocketIO MGT user guide for more info).
// reset will reset the core.
// The output status register is commented below.
// The extra lines are for additional functionality we might think of adding
// later. They can be removed to reduce complexity.
///////////////////////////////////////////////////////////////////////////////


`timescale 1 ns / 10 ps

module aurora_module
(
    // User IO
    RESET_IN,
    AURORA_CTRL_REG,    // {extra[6:0], loopback[1:0], test_mode, reset}

    AURORA_STAT_REG,    // {extra[7:0], channel_up, lane_up, hard_error, soft_error, frame_error}
    FRAME_SENT,         // pulsed
    FRAME_RCVD,         // pulsed
    ERROR_COUNT,        // only valid when testing

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

    // Clocks
    REF_CLK,
    USER_CLK,

    // MGT I/O
    RXP,
    RXN,

    TXP,
    TXN

);


//***********************************Port Declarations*******************************

    // User I/O
    input              RESET_IN;
    input   [10:0]     AURORA_CTRL_REG;
    output  [15:0]     ERROR_COUNT;
    output  [12:0]     AURORA_STAT_REG;
    output             FRAME_SENT;
    output             FRAME_RCVD;

    // LocalLink TX Interface
    input   [15:0]     TX_D;
    input              TX_REM;
    input              TX_SRC_RDY_N;
    input              TX_SOF_N;
    input              TX_EOF_N;

    output             TX_DST_RDY_N;


    // LocalLink RX Interface
    output  [15:0]     RX_D;
    output             RX_REM;
    output             RX_SRC_RDY_N;
    output             RX_SOF_N;
    output             RX_EOF_N;

    // Native Flow Control Interface
    input              NFC_REQ_N;
    input   [3:0]      NFC_NB;

    output             NFC_ACK_N;

    // Clocks
    input              REF_CLK;
    input              USER_CLK;


    // MGT I/O
    input              RXP;
    input              RXN;

    output             TXP;
    output             TXN;


//**************************External Register Declarations****************************

    reg     [12:0]     AURORA_STAT_REG;
    reg                FRAME_SENT;
    reg                FRAME_RCVD;
    reg     [15:0]     ERROR_COUNT;


//**************************Internal Register Declarations****************************

    reg                previous_tx_eof;
    reg                previous_rx_eof;

//*******************************Bit Connections**************************************

    wire    [1:0]      loopback;
    wire               test;
    wire               aurora_reset;
    wire               power_down_i;

    assign loopback         = AURORA_CTRL_REG[3:2];
    assign test             = AURORA_CTRL_REG[1];
    assign aurora_reset     = AURORA_CTRL_REG[0];
    assign power_down_i      = AURORA_CTRL_REG[4];

//********************************Wire Declarations**********************************

    // LocalLink TX Interface
    wire    [15:0]     tx_d_i;
    wire               tx_rem_i;
    wire               tx_src_rdy_n_i;
    wire               tx_sof_n_i;
    wire               tx_eof_n_i;

    wire               tx_dst_rdy_n_i;


    // LocalLink RX Interface
    wire    [15:0]     rx_d_i;
    wire               rx_rem_i;
    wire               rx_src_rdy_n_i;
    wire               rx_sof_n_i;
    wire               rx_eof_n_i;


    // Native Flow Control Interface
    wire               nfc_req_n_i;
    wire    [3:0]      nfc_nb_i;
    wire               nfc_ack_n_i;


    // Status
    wire               channel_up_i;
    wire               lane_up_i;

    // Error interface
    wire               hard_error_i;
    wire               soft_error_i;
    wire               frame_error_i;


    // Clock Compensation Control Interface
    wire               warn_cc_i;
    wire               do_cc_i;


    // System Interface
    wire               dcm_not_locked_i;


    //Frame check signals
    wire    [15:0]     error_count_i;
    wire               test_reset_i;

    //Test connections
    wire    [15:0]     tx_d_i_test;
    wire               tx_rem_i_test;
    wire               tx_src_rdy_n_i_test;
    wire               tx_sof_n_i_test;
    wire               tx_eof_n_i_test;


//*********************************Main Body of Code**********************************
   reg  [29:0] extended_reset;
   wire        RESET = extended_reset[29];

   always @(posedge USER_CLK) begin
      if(RESET_IN) begin
         extended_reset <= {30{1'b1}};
      end
      else begin
         extended_reset <= {extended_reset[28:0], 1'b0};
      end
   end

    //____________________________Register User I/O___________________________________

    // Register User Outputs from core.
    always @(posedge USER_CLK)
    begin
        AURORA_STAT_REG <=  {channel_up_i, lane_up_i, hard_error_i, soft_error_i,frame_error_i};
        ERROR_COUNT     <=  error_count_i;
    end

    // pulse the sent and rcvd signals
    always @(posedge USER_CLK)
    begin
        FRAME_SENT      <=   tx_eof_n_i ? 1'b0 : previous_tx_eof;
        previous_tx_eof <=   tx_eof_n_i;
        FRAME_RCVD      <=   rx_eof_n_i ? 1'b0 : previous_rx_eof;
        previous_rx_eof <=   rx_eof_n_i;
    end

    //____________________________Tie off unused signals_______________________________

    // System Interface
    assign  dcm_not_locked_i    =   1'b0;

    //_________________________Multiplex between test and non-test modes_______________

    // LocalLink TX Interface
    assign  tx_d_i          = test ? tx_d_i_test        : TX_D;
    assign  tx_rem_i        = test ? tx_rem_i_test      : TX_REM;
    assign  tx_src_rdy_n_i  = test ? tx_src_rdy_n_i_test: TX_SRC_RDY_N;
    assign  tx_sof_n_i      = test ? tx_sof_n_i_test    : TX_SOF_N;
    assign  tx_eof_n_i      = test ? tx_eof_n_i_test    : TX_EOF_N;

    assign  TX_DST_RDY_N    = tx_dst_rdy_n_i;

    // LocalLink RX Interface
    assign  RX_D            = rx_d_i;
    assign  RX_REM          = rx_rem_i;
    assign  RX_SRC_RDY_N    = rx_src_rdy_n_i;
    assign  RX_SOF_N        = rx_sof_n_i;
    assign  RX_EOF_N        = rx_eof_n_i;

    // Native Flow Control Interface
    assign  nfc_req_n_i     = test ? 1'b1 : NFC_REQ_N;
    assign  nfc_nb_i        = test ? 4'h0 : NFC_NB;

    assign  NFC_ACK_N       = nfc_ack_n_i;


    //Use one of the lane up signals to reset the frame generator and
    //frame checker
    assign  test_reset_i    = test ? !lane_up_i : 1'b1;

    //___________________________Module Instantiations_________________________________


    aurora_framing aurora_framing_i
    (
        // LocalLink TX Interface
        .TX_D(tx_d_i),
        .TX_REM(tx_rem_i),
        .TX_SRC_RDY_N(tx_src_rdy_n_i),
        .TX_SOF_N(tx_sof_n_i),
        .TX_EOF_N(tx_eof_n_i),

        .TX_DST_RDY_N(tx_dst_rdy_n_i),


        // LocalLink RX Interface
        .RX_D(rx_d_i),
        .RX_REM(rx_rem_i),
        .RX_SRC_RDY_N(rx_src_rdy_n_i),
        .RX_SOF_N(rx_sof_n_i),
        .RX_EOF_N(rx_eof_n_i),

        // Native Flow Control Interface
        .NFC_REQ_N(nfc_req_n_i),
        .NFC_NB(nfc_nb_i),
        .NFC_ACK_N(nfc_ack_n_i),



        // MGT Serial I/O
        .RXP(RXP),
        .RXN(RXN),

        .TXP(TXP),
        .TXN(TXN),


        // MGT Reference Clock Interface
        .TOP_REF_CLK(REF_CLK),

        // Error Detection Interface
        .HARD_ERROR(hard_error_i),
        .SOFT_ERROR(soft_error_i),
        .FRAME_ERROR(frame_error_i),


        // Status
        .CHANNEL_UP(channel_up_i),
        .LANE_UP(lane_up_i),


        // Clock Compensation Control Interface
        .WARN_CC(warn_cc_i),
        .DO_CC(do_cc_i),


        // System Interface
        .DCM_NOT_LOCKED(dcm_not_locked_i),
        .USER_CLK(USER_CLK),
        .RESET(RESET|aurora_reset),
        .POWER_DOWN(power_down_i),
        .LOOPBACK(loopback)
    );


    aurora_framing_STANDARD_CC_MODULE standard_cc_module_i
    (
        // Clock Compensation Control Interface
        .WARN_CC(warn_cc_i),
        .DO_CC(do_cc_i),


        // System Interface
        .DCM_NOT_LOCKED(dcm_not_locked_i),
        .USER_CLK(USER_CLK),
        .CHANNEL_UP(channel_up_i)

    );

    //Connect a frame generator to the TX User interface
    aurora_framing_FRAME_GEN frame_gen_i
    (
        // User Interface
        .TX_D(tx_d_i_test),
        .TX_REM(tx_rem_i_test),
        .TX_SOF_N(tx_sof_n_i_test),
        .TX_EOF_N(tx_eof_n_i_test),
        .TX_SRC_RDY_N(tx_src_rdy_n_i_test),
        .TX_DST_RDY_N(tx_dst_rdy_n_i),

        // System Interface
        .USER_CLK(USER_CLK),
        .RESET(test_reset_i)
    );


    aurora_framing_FRAME_CHECK frame_check_i
    (
        // User Interface
        .RX_D(rx_d_i),
        .RX_REM(rx_rem_i),
        .RX_SOF_N(rx_sof_n_i),
        .RX_EOF_N(rx_eof_n_i),
        .RX_SRC_RDY_N(rx_src_rdy_n_i),

        // System Interface
        .USER_CLK(USER_CLK),
        .RESET(test_reset_i),
        .ERROR_COUNT(error_count_i)
    );

endmodule
