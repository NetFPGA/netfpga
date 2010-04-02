//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: serial_test.v 4196 2008-06-23 23:12:37Z grg $
//
// Module: serial_test.v
// Project: NetFPGA
// Description: the top module for SATA tests
//
// This module runs the test for the MGTs using the Aurora core. Two tests are run.
// In the first test, the MGTs are connected in external loopback (loopback at
// the pins). In the second test, we require that the MGTs be cross connected.
//
///////////////////////////////////////////////////////////////////////////////

module serial_test
   #(
      parameter COUNT_WIDTH = 28
   )

   ( // --- Testing interface
     output reg test_running,
     output reg test_done,
     output reg test_successful,

     // --- Interface to register demux
     input                             serial_tst_reg_req,
     input                             serial_tst_reg_rd_wr_L,
     output                            serial_tst_reg_ack,
     input  [`SERIAL_TEST_REG_ADDR_WIDTH-1:0] serial_tst_reg_addr,
     input  [`CPCI_NF2_DATA_WIDTH-1:0] serial_tst_reg_wr_data,
     output [`CPCI_NF2_DATA_WIDTH-1:0] serial_tst_reg_rd_data,


     // --- MGT interface
     output  serial_TXP_0,
     output  serial_TXN_0,
     input   serial_RXP_0,
     input   serial_RXN_0,

     output  serial_TXP_1,
     output  serial_TXN_1,
     input   serial_RXP_1,
     input   serial_RXN_1,

     // --- Misc
     input clk,
     input reset);

   reg [COUNT_WIDTH-1:0] count;
   wire       test, restart_test, nonstop_test;

   reg [15:0] serial_error_count_0;
   reg [15:0] serial_error_count_1;

   wire [15:0] error_count_0, error_count_1;

   wire       usr_reset_0;
   wire       usr_reset_1;
   wire       channel_up_0, lane_up_0, hard_error_0, soft_error_0, frame_error_0;
   wire       channel_up_1, lane_up_1, hard_error_1, soft_error_1, frame_error_1;

   wire       serial_frame_sent_0, serial_frame_rcvd_0;
   wire       serial_frame_sent_1, serial_frame_rcvd_1;

   wire [1:0] loopback_0, loopback_1;

   aurora_module aurora_module_0
     (
      // User IO
      .RESET_IN             (reset),
      .AURORA_CTRL_REG      ({7'h0, loopback_0, test, usr_reset_0}),

      .AURORA_STAT_REG      ({channel_up_0, lane_up_0, hard_error_0, soft_error_0, frame_error_0}),
      .FRAME_SENT           (serial_frame_sent_0),         // pulsed
      .FRAME_RCVD           (serial_frame_rcvd_0),         // pulsed
      .ERROR_COUNT          (error_count_0),        // only valid when testing

      // LocalLink TX Interface
      .TX_D                 (16'h0),
      .TX_REM               (1'b0),
      .TX_SRC_RDY_N         (1'b1),
      .TX_SOF_N             (1'b1),
      .TX_EOF_N             (1'b1),

      .TX_DST_RDY_N         (),


      // LocalLink RX Interface
      .RX_D                 (),
      .RX_REM               (),
      .RX_SRC_RDY_N         (),
      .RX_SOF_N             (),
      .RX_EOF_N             (),

      // Native Flow Control Interface
      .NFC_REQ_N            (1'b1),
      .NFC_NB               (4'h0),
      .NFC_ACK_N            (),

      .REF_CLK              (clk),
      .USER_CLK             (clk),

      // MGT I/O
      .RXP                  (serial_RXP_0),
      .RXN                  (serial_RXN_0),

      .TXP                  (serial_TXP_0),
      .TXN                  (serial_TXN_0)

      );

   aurora_module aurora_module_1
     (
      // User IO
      .RESET_IN             (reset),
      .AURORA_CTRL_REG      ({7'h0, 2'b0, test, usr_reset_1}),

      .AURORA_STAT_REG      ({channel_up_1, lane_up_1, hard_error_1, soft_error_1, frame_error_1}),
      .FRAME_SENT           (serial_frame_sent_1),         // pulsed
      .FRAME_RCVD           (serial_frame_rcvd_1),         // pulsed
      .ERROR_COUNT          (error_count_1),        // only valid when testing

      // LocalLink TX Interface
      .TX_D                 (16'h0),
      .TX_REM               (1'b0),
      .TX_SRC_RDY_N         (1'b1),
      .TX_SOF_N             (1'b1),
      .TX_EOF_N             (1'b1),

      .TX_DST_RDY_N         (),


      // LocalLink RX Interface
      .RX_D                 (),
      .RX_REM               (),
      .RX_SRC_RDY_N         (),
      .RX_SOF_N             (),
      .RX_EOF_N             (),

      // Native Flow Control Interface
      .NFC_REQ_N            (1'b1),
      .NFC_NB               (4'h0),
      .NFC_ACK_N            (),

      .REF_CLK              (clk),
      .USER_CLK             (clk),

      // MGT I/O
      .RXP                  (serial_RXP_1),
      .RXN                  (serial_RXN_1),

      .TXP                  (serial_TXP_1),
      .TXN                  (serial_TXN_1)

      );

   serial_tst_regs #(
      .COUNT_WIDTH(COUNT_WIDTH)
   ) serial_tst_regs (
      .serial_tst_reg_req (serial_tst_reg_req),
      .serial_tst_reg_rd_wr_L (serial_tst_reg_rd_wr_L),
      .serial_tst_reg_ack (serial_tst_reg_ack),
      .serial_tst_reg_addr(serial_tst_reg_addr),
      .serial_tst_reg_wr_data (serial_tst_reg_wr_data),
      .serial_tst_reg_rd_data (serial_tst_reg_rd_data),

      .test_running(test_running),
      .test_done (test_done),
      .test_successful(test_successful),

      .serial_error_count_0(serial_error_count_0),
      .channel_up_0(channel_up_0),
      .lane_up_0(lane_up_0),
      .hard_error_0(hard_error_0),
      .soft_error_0(soft_error_0),
      .frame_error_0(frame_error_0),

      .serial_frame_rcvd_0(serial_frame_rcvd_0),
      .serial_frame_sent_0(serial_frame_sent_0),

      .serial_error_count_1(serial_error_count_1),
      .channel_up_1(channel_up_1),
      .lane_up_1(lane_up_1),
      .hard_error_1(hard_error_1),
      .soft_error_1(soft_error_1),
      .frame_error_1(frame_error_1),

      .serial_frame_rcvd_1(serial_frame_rcvd_1),
      .serial_frame_sent_1(serial_frame_sent_1),

      .usr_reset_0(usr_reset_0),
      .usr_reset_1(usr_reset_1),
      .restart_test(restart_test),
      .nonstop_test(nonstop_test),
      .count (count),
      .loopback_0 (loopback_0),
      .loopback_1 (loopback_1),

      .clk(clk),
      .reset(reset));

   always @(posedge clk) begin
      test_running <= (!(&count) || nonstop_test) && (channel_up_0 && channel_up_1 && lane_up_0 && lane_up_1);
      test_done <= (&count) && !nonstop_test;
      if(reset | restart_test) begin
         count <= 0;
         test_successful <= 1;
         serial_error_count_0 <= 0;
         serial_error_count_1 <= 0;
      end
      else begin
         if((!(&count) || nonstop_test) && (channel_up_0 && channel_up_1 && lane_up_0 && lane_up_1)) begin
            count <= count+1;
            test_successful <= test_successful && !(|serial_error_count_0)  && !(|serial_error_count_1);
            serial_error_count_0 <= error_count_0;
            serial_error_count_1 <= error_count_1;
         end
      end
    end // always @ (posedge clk)

   assign test = (!(&count) || nonstop_test);

endmodule // serial_test

