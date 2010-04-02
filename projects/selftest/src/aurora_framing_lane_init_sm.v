///////////////////////////////////////////////////////////////////////////////
//
//      Project:  Aurora Module Generator version 2.6
//
//         Date:  $Date: 2006/12/28 05:14:10 $
//          Tag:  $Name: i+IP+121336 $
//         File:  $RCSfile: lane_init_sm.ejava,v $
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
//  LANE_INIT_SM
//
//  Author: Nigel Gulstone
//          Xilinx - Embedded Networking System Engineering Group
//
//  Description: This logic manages the initialization of the MGT in 2-byte mode.
//               It consists of a small state machine, a set of counters for
//               tracking the progress of initializtion and detecting problems,
//               and some additional support logic.
//

`timescale 1 ns / 10 ps

module aurora_framing_LANE_INIT_SM
(
    // MGT Interface
    RX_NOT_IN_TABLE,
    RX_DISP_ERR,
    RX_CHAR_IS_COMMA,
    RX_REALIGN,

    RX_RESET,
    TX_RESET,
    RX_POLARITY,


    // Comma Detect Phase Alignment Interface
    ENA_COMMA_ALIGN,


    // Symbol Generator Interface
    GEN_K,
    GEN_SP_DATA,
    GEN_SPA_DATA,


    // Symbol Decoder Interface
    RX_SP,
    RX_SPA,
    RX_NEG,

    DO_WORD_ALIGN,


    // Error Detection Logic Interface
    ENABLE_ERROR_DETECT,
    HARD_ERROR_RESET,


    // Global Logic Interface
    LANE_UP,


    // System Interface
    USER_CLK,
    RESET

);
`define DLY #1


//******************************* Parameter Declarations ****************************

    parameter   EXTEND_WATCHDOGS            =   0;


//***********************************Port Declarations*******************************

    // MGT Interface
    input   [1:0]   RX_NOT_IN_TABLE;     // MGT received invalid 10b code.
    input   [1:0]   RX_DISP_ERR;         // MGT received 10b code w/ wrong disparity.
    input   [1:0]   RX_CHAR_IS_COMMA;    // MGT received a Comma.
    input           RX_REALIGN;          // MGT had to change alignment due to new comma.

    output          RX_RESET;            // Reset the RX side of the MGT.
    output          TX_RESET;            // Reset the TX side of the MGT.
    output          RX_POLARITY;         // Sets polarity used to interpet rx'ed symbols.


    // Comma Detect Phase Alignment Interface
    output          ENA_COMMA_ALIGN;     // Turn on SERDES Alignment in MGT.


    // Symbol Generator Interface
    output          GEN_K;               // Generate a comma on the MSByte of the Lane.
    output  [0:1]   GEN_SP_DATA;         // Generate SP data symbol on selected byte(s).
    output  [0:1]   GEN_SPA_DATA;        // Generate SPA data symbol on selected byte(s).


    // Symbol Decoder Interface
    input           RX_SP;               // Lane rx'ed SP sequence w/ + or - data.
    input           RX_SPA;              // Lane rx'ed SPA sequence.
    input           RX_NEG;              // Lane rx'ed inverted SP or SPA data.

    output          DO_WORD_ALIGN;       // Enable word alignment.


    // Error Detection Logic Interface
    input           HARD_ERROR_RESET;    // Reset lane due to hard error.

    output          ENABLE_ERROR_DETECT; // Turn on Soft Error detection.



    // Global Logic Interface
    output          LANE_UP;             // Lane is initialized.


    // System Interface
    input           USER_CLK;            // Clock for all non-MGT Aurora logic.
    input           RESET;               // Reset Aurora Lane.


//**************************External Register Declarations****************************

    reg             ENABLE_ERROR_DETECT;


//**************************Internal Register Declarations****************************



    reg             odd_word_r;
    reg     [0:7]   counter1_r;
    reg     [0:15]  counter2_r;
    reg     [0:3]   counter3_r;
    reg     [0:15]  counter4_r;
    reg     [0:15]  counter5_r;
    reg             rx_polarity_r;
    reg             prev_char_was_comma_r;
    reg             comma_over_two_cycles_r;
    reg             prev_count_128d_done_r;
    reg     [0:31]  extend_r;
    reg             extend_n_r;
    reg             do_watchdog_count_r;
    reg             reset_count_r;



    // FSM states, encoded for one-hot implementation
    reg             begin_r;        //Begin initialization
    reg             rst_r;          //Reset MGTs
    reg             align_r;        //Align SERDES
    reg             realign_r;      //Verify no spurious realignment
    reg             polarity_r;     //Verify polarity of rx'ed symbols
    reg             ack_r;          //Ack initialization with partner
    reg             ready_r;        //Lane ready for Bonding/Verification



//*********************************Wire Declarations**********************************

    wire            send_sp_c;
    wire            send_spa_r;
    wire            count_8d_done_r;
    wire            count_32d_done_r;
    wire            count_128d_done_r;
    wire            symbol_error_c;
    wire            txack_16d_done_r;
    wire            rxack_4d_done_r;
    wire            sp_polarity_c;
    wire            inc_count_c;
    wire            change_in_state_c;
    wire            watchdog_done_r;
    wire            extend_n_c;
    wire            remote_reset_watchdog_done_r;

    wire            next_begin_c;
    wire            next_rst_c;
    wire            next_align_c;
    wire            next_realign_c;
    wire            next_polarity_c;
    wire            next_ack_c;
    wire            next_ready_c;


//*********************************Main Body of Code**********************************



    //________________Main state machine for managing initialization________________


    // State registers
    always @(posedge USER_CLK)
        if(RESET|HARD_ERROR_RESET)
            {begin_r,rst_r,align_r,realign_r,polarity_r,ack_r,ready_r}  <=  `DLY    7'b1000000;
        else
        begin
            begin_r     <=  `DLY    next_begin_c;
            rst_r       <=  `DLY    next_rst_c;
            align_r     <=  `DLY    next_align_c;
            realign_r   <=  `DLY    next_realign_c;
            polarity_r  <=  `DLY    next_polarity_c;
            ack_r       <=  `DLY    next_ack_c;
            ready_r     <=  `DLY    next_ready_c;
        end



    // Next state logic
    assign  next_begin_c    =   (realign_r & RX_REALIGN)  |
                                (polarity_r & !sp_polarity_c)|
                                (ack_r & watchdog_done_r)|
                                (ready_r & remote_reset_watchdog_done_r);

    assign  next_rst_c      =   begin_r |
                                (rst_r & !count_8d_done_r);



    assign  next_align_c    =   (rst_r & count_8d_done_r)|
                                (align_r & !count_128d_done_r);


    assign  next_realign_c  =   (align_r & count_128d_done_r)|
                                (realign_r & !count_32d_done_r & !RX_REALIGN);

    assign  next_polarity_c =   (realign_r & count_32d_done_r & !RX_REALIGN)|
                                (polarity_r & sp_polarity_c & odd_word_r);


    assign  next_ack_c      =   (polarity_r & sp_polarity_c & !odd_word_r)|
                                (ack_r & (!txack_16d_done_r|!rxack_4d_done_r) & !watchdog_done_r);


    assign  next_ready_c    =   (ack_r & txack_16d_done_r & rxack_4d_done_r & !watchdog_done_r)|
                                (ready_r & !remote_reset_watchdog_done_r);


    // Output Logic

    // Enable comma align when in the ALIGN state.
    assign  ENA_COMMA_ALIGN =   align_r;



    // Hold RX_RESET when in the RST state.
    assign  RX_RESET        =   rst_r;



    // Hold TX_RESET when in the RST state.
    assign  TX_RESET        =   rst_r;



    // LANE_UP is asserted when in the READY state.
    FDR lane_up_flop_i
    (
        .D(ready_r),
        .C(USER_CLK),
        .R(RESET),
        .Q(LANE_UP)
    );


    // ENABLE_ERROR_DETECT is asserted when in the ACK or READY states.  Asserting
    // it earlier will result in too many false errors.  After it is asserted,
    // higher level modules can respond to Hard Errors by resetting the Aurora Lane.
    // We register the signal before it leaves the lane_init_sm submodule.
    always @(posedge USER_CLK)
        ENABLE_ERROR_DETECT <=  `DLY    ack_r | ready_r;



    // The Aurora Lane should transmit SP sequences when not ACKing or Ready.
    assign  send_sp_c   =   !(ack_r | ready_r);



    // The Aurora Lane transmits SPA sequences while in the ACK state.
    assign  send_spa_r  =   ack_r;


    // Do word alignment when in the ALIGN state.
    assign  DO_WORD_ALIGN   =   align_r | ready_r;

    //_______________________Transmission Logic for SP and SPA sequences_______________


    // Select either the even or the odd word of the current sequence for transmission.
    // There is no reset for odd word.  It is initialized when the FPGA is configured.
    // The variable, odd_word_r, is initialized for simulation (See SIGNAL declarations).
    initial
        odd_word_r  =   1'b1;

    always @(posedge USER_CLK)
        odd_word_r  <=  `DLY    ~odd_word_r;


    // Request transmission of the commas needed for the SP and SPA sequences.
    // These commas are sent on the MSByte of the lane on all odd bytes.
    assign  GEN_K           =   odd_word_r & (send_sp_c|send_spa_r);


    // Request transmission of the SP_DATA sequence.
    assign  GEN_SP_DATA[0]  =   !odd_word_r & send_sp_c;
    assign  GEN_SP_DATA[1]  =   send_sp_c;


    // Request transmission of the SPA_DATA sequence.
    assign  GEN_SPA_DATA[0] =   !odd_word_r & send_spa_r;
    assign  GEN_SPA_DATA[1] =   send_spa_r;



    //_________Counter 1, for reset cycles, align cycles and realign cycles____________

    // The initial statement is to ensure that the counter comes up at some value other than X.
    // We have tried different initial values and it does not matter what the value is, as long
    // as it is not X since X breaks the state machine
    initial
        counter1_r = 8'h01;

    //Core of the counter
    always @(posedge USER_CLK)
        if(reset_count_r)           counter1_r   <=  `DLY    8'd1;
        else if(inc_count_c)        counter1_r   <=  `DLY    counter1_r + 8'd1;


    // Assert count_8d_done_r when bit 4 in the register first goes high.
    assign  count_8d_done_r     =   counter1_r[4];


    // Assert count_32d_done_r when bit 2 in the register first goes high.
    assign  count_32d_done_r    =   counter1_r[2];


    // Assert count_128d_done_r when bit 0 in the register first goes high.
    assign  count_128d_done_r   =   counter1_r[0];


    // The counter resets any time the RESET signal is asserted, there is a change in
    // state, there is a symbol error, or commas are not consecutive in the align state.
    always @(posedge USER_CLK)
        reset_count_r = RESET | change_in_state_c | symbol_error_c |!comma_over_two_cycles_r;



    // The counter should be reset when entering and leaving the reset state.
    assign  change_in_state_c   =   rst_r != next_rst_c;



    // Symbol error is asserted whenever there is a disparity error or an invalid
    // 10b code.
    assign  symbol_error_c  =   (RX_DISP_ERR != 2'b00) | (RX_NOT_IN_TABLE != 2'b00);



    // Previous cycle comma is used to check for consecutive commas.
    always @(posedge USER_CLK)
        prev_char_was_comma_r <=  `DLY    (RX_CHAR_IS_COMMA != 2'b00);


    // Check to see that commas are consecutive in the align state.
    always @(posedge USER_CLK)
        comma_over_two_cycles_r <= `DLY   (prev_char_was_comma_r ^
                                          (RX_CHAR_IS_COMMA != 2'b00)) | !align_r;


    // Increment count is always asserted, except in the ALIGN state when it is asserted
    // only upon the arrival of a comma character.
    assign  inc_count_c =   !align_r | (align_r & (RX_CHAR_IS_COMMA != 2'b00));




    //__________________________Counter 2, for counting tx_acks _______________________


    // This counter is implemented as a shift register.  It is constantly shifting.  As a
    // result, when the state machine is not in the ack state, the register clears out.
    // When the state machine goes into the ack state, the count is incremented every
    // cycle.  The txack_16d_done signal goes high and stays high after 16 cycles in the
    // ack state.  The signal deasserts only after it has had enough time for all the ones
    // to clear out after the machine leaves the ack state, but this is tolerable because
    // the machine will spend at least 8 cycles in reset, 256 in ALIGN and 32 in REALIGN.
    //
    // The counter is implemented seperately from the main counter because it is required
    // to stop counting when it reaches the end of its count. Adding this functionality
    // to the main counter is more expensive and more complex than implementing it seperately.

    // Counter Logic
    always @(posedge USER_CLK)
        counter2_r  <=  `DLY    {ack_r,counter2_r[0:14]};



    // The counter is done when bit 15 of the shift register goes high.
    assign txack_16d_done_r = counter2_r[15];



    //__________________________Counter 3, for counting rx_acks _______________________


    // This counter is also implemented as a shift register. It is always shifting when
    // the state machine is not in the ack state to clear it out. When the state machine
    // goes into the ack state, the register shifts only when a SPA is received. When
    // 4 SPAs have been received in the ACK state, the rxack_4d_done_r signal is triggered.
    //
    // This counter is implemented seperately from the main counter because it is required
    // to increment only when ACKs are received, and then hold its count. Adding this
    // functionality to the main counter is more expensive than creating a second counter,
    // and more complex.

    // Counter Logic
    always @(posedge USER_CLK)
        if(RX_SPA|!ack_r)   counter3_r  <=  `DLY    {ack_r,counter3_r[0:2]};



    // The counter is done when bit 3 of the shift register goes high.
    assign rxack_4d_done_r = counter3_r[3];



    //_____________________Counter 4, remote reset watchdog timer __________________


    // Another counter implemented as a shift register.  This counter puts an upper limit on
    // the number of SPs that can be received in the Ready state.  If the number of SPs
    // exceeds the limit, the Aurora Lane resets itself.  The Global logic module will reset
    // all the lanes if this occurs while they are all in the lane ready state (i.e. lane_up
    // is asserted for all.



    // Counter logic
    always @(posedge USER_CLK)
        if(RX_SP|!ready_r)  counter4_r  <=  `DLY    {ready_r,counter4_r[0:14]};



    // The counter is done when bit 15 of the shift register goes high.
    assign remote_reset_watchdog_done_r = counter4_r[15];



    //__________________________Counter 5, internal watchdog timer __________________


    // This counter puts an upper limit on the number of cycles the state machine can
    // spend in the ack state before it gives up and resets.
    //
    // The counter is implemented as a shift register extending counter 1.  The counter
    // clears out in all non-ack cycles by keeping CE asserted.  When it gets into the
    // ack state, CE is asserted only when there is a transition on the most
    // significant bit of counter 1.  This happens every 128 cycles.  We count out 32
    // of these transitions to get a count of approximately 4096 cycles.  The actual
    // number of cycles is less than this because we don't reset counter1, so it starts
    // off about 34 cycles into its count.



    // Counter logic
    always @(posedge USER_CLK)
        if(do_watchdog_count_r|!ack_r)  counter5_r  <=  `DLY    {ack_r,counter5_r[0:14]};



    // Store the count_128d_done_r result from the previous cycle.
    always @(posedge USER_CLK)
        prev_count_128d_done_r  <=  `DLY    count_128d_done_r;



    //Initialise extend_r to match initial SRL state for simulation
    initial
        extend_r    = 32'd0;


    // Extra SRLs to extend the watchdog count by muliplying it by 32
    always @(posedge USER_CLK)
        if(count_128d_done_r & !prev_count_128d_done_r)
            extend_r <=  `DLY    {extend_n_c,extend_r[0:30]};


    assign  extend_n_c  =   !extend_r[31];


    always @(posedge USER_CLK)
            extend_n_r  <=  extend_n_c;


    // Trigger CE only when the previous 128d_done is not the same as the
    // current one, and the current value is high.
    always @(posedge USER_CLK)
        if(EXTEND_WATCHDOGS)
            do_watchdog_count_r <=  `DLY    extend_r[31] & extend_n_r;
        else
            do_watchdog_count_r <=  `DLY    count_128d_done_r & !prev_count_128d_done_r;



    // The counter is done when bit 15 of the shift register goes high.
    assign watchdog_done_r = counter5_r[15];



    //___________________________Polarity Control_____________________________


    // sp_polarity_c, is low if neg symbols received, otherwise high.
    assign  sp_polarity_c   =   !RX_NEG;



    // The Polarity flop drives the polarity setting of the MGT.  We initialize it for the
    // sake of simulation. In hardware, it is initialized after configuration.
    initial
        rx_polarity_r <=  1'b0;

    always @(posedge USER_CLK)
        if(polarity_r & !sp_polarity_c)  rx_polarity_r <=  `DLY    ~rx_polarity_r;



    // Drive the rx_polarity register value on the interface.
    assign  RX_POLARITY =   rx_polarity_r;

endmodule
