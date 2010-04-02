///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: phy_test_port_grp.v 4196 2008-06-23 23:12:37Z grg $
//
// Module: phy_test_port_grp.v
// Project: NetFPGA
// Description: Selftest module for Ethernet Phys.
//
// Contains all necessary logic for a sinlge port group
//
//
///////////////////////////////////////////////////////////////////////////////

module phy_test_port_grp #(parameter
      REG_ADDR_WIDTH = `PHY_TEST_REG_ADDR_WIDTH - 1 - 2,
      NUM_PATTERNS = 5,
      SEQ_NO_WIDTH = 32,
      SEQ_RANGE = 256          // Allowable range for a sequence
   )
   (
      //--- PHY test signals
      input [2:0]                   port,
      input [10:0]                  pkt_size,
      input [NUM_PATTERNS - 1:0]    pat_en,

      input                         start,      // Start or continue a test

      input [SEQ_NO_WIDTH - 1 : 0]  init_seq_no, // Initial sequence number
      output [SEQ_NO_WIDTH - 1 : 0] tx_seq_no, // Current TX sequence number

      input [SEQ_NO_WIDTH - 1 : 0]  port_1_seq_no, // Current sequence number of port 1
      input [SEQ_NO_WIDTH - 1 : 0]  port_2_seq_no, // Current sequence number of port 2
      input [SEQ_NO_WIDTH - 1 : 0]  port_3_seq_no, // Current sequence number of port 3
      input [SEQ_NO_WIDTH - 1 : 0]  port_4_seq_no, // Current sequence number of port 4

      output                        done,
      output                        success,
      output                        busy,

      //--- sigs to/from nf2_mac_grp for Rx FIFOs (ingress)
      input             rx_almost_empty,
      input [35:0]      rx_data,
      output            rx_rd_en,


      //--- sigs to/from cnet_mac_grp for Tx FIFOs (egress)

      output [35:0]     tx_data,
      output            tx_wr_en,
      input             tx_almost_full,          // 0 = room for max pkt

      //-- sigs to/from nf2_reg_grp
      input                                     reg_req,
      input                                     reg_rd_wr_L,    // 1 = read, 0 = write
      input [REG_ADDR_WIDTH - 1:0]              reg_addr,
      input [`CPCI_NF2_DATA_WIDTH - 1:0]        reg_wr_data,

      output                                    reg_ack,
      output [`CPCI_NF2_DATA_WIDTH -1:0]        reg_rd_data,

      // misc
      input reset,
      input clk
   );

   // Register addresses
   localparam TX_REG_ADDR        = 'd 0;
   localparam RX_REG_ADDR        = 'd 1;
   localparam RX_LOG_REG_ADDR    = 'd 2;
   localparam UNUSED_REG_ADDR    = 'd 3;


   // ===========================================
   // Local variables

   wire [3:0]                             local_reg_req;
   wire [3:0]                             local_reg_rd_wr_L;
   wire [4 * (REG_ADDR_WIDTH - 2) - 1:0]  local_reg_addr;
   wire [4 * `CPCI_NF2_DATA_WIDTH -1:0]   local_reg_wr_data;

   wire [3:0]                             local_reg_ack;
   wire [4 * `CPCI_NF2_DATA_WIDTH -1:0]   local_reg_rd_data;

   // TX signals
   wire [NUM_PATTERNS - 1:0] tx_pat;

   wire tx_busy;
   wire tx_pkt_done;
   wire tx_iter_done;

   // RX signals
   wire [2:0] rx_port;
   wire [NUM_PATTERNS - 1:0] rx_pattern;
   wire [SEQ_NO_WIDTH - 1:0] rx_seq_no;
   wire rx_locked;
   wire rx_busy;
   wire rx_done;
   wire rx_bad;

   wire [31:0] log_rx_data;
   wire [31:0] log_exp_data;
   wire [8:0] log_addr;
   wire log_data_wr;
   wire log_done;
   wire log_hold;

   // Internal signals
   wire start_d1;
   wire restart;

   wire rx_seq_good;

   reg rx_done_d1;
   reg rx_bad_d1;

   always @(posedge clk)
   begin
      rx_done_d1 <= rx_done;
      rx_bad_d1 <= rx_bad;
   end



   // =====================================================
   // Instantiate the various submodules

   // Controlling module
   phy_test_port_ctrl #(
      .NUM_PATTERNS (NUM_PATTERNS),
      .SEQ_NO_WIDTH (SEQ_NO_WIDTH),
      .SEQ_RANGE (SEQ_RANGE)
   ) phy_test_port_ctrl (
      // Phy test signals
      .port                         (port),
      .pkt_size                     (pkt_size),
      .pat_en                       (pat_en),

      .start                        (start),      // Start or continue a test

      .init_seq_no                  (init_seq_no), // Initial sequence number
      .tx_seq_no                    (tx_seq_no), // Current TX sequence number

      .port_1_seq_no                (port_1_seq_no), // Current sequence number of port 1
      .port_2_seq_no                (port_2_seq_no), // Current sequence number of port 2
      .port_3_seq_no                (port_3_seq_no), // Current sequence number of port 3
      .port_4_seq_no                (port_4_seq_no), // Current sequence number of port 4

      .done                         (done),
      .success                      (success),
      .busy                         (busy),

      // Tx signals
      .tx_busy                      (tx_busy),
      .tx_iter_done                 (tx_iter_done),

      // Rx signals
      .rx_port                      (rx_port),
      .rx_pattern                   (rx_pattern),
      .rx_seq_no                    (rx_seq_no),
      .rx_busy                      (rx_busy),
      .rx_done                      (rx_done),
      .rx_bad                       (rx_bad),

      // General control signals
      .start_d1                     (start_d1),
      .restart                      (restart),
      .rx_seq_good                  (rx_seq_good),

      // misc
      .reset(reset),
      .clk  (clk)
   );

   // Packet source for generating packets
   phy_test_pktsrc #(
      .NUM_PATTERNS (NUM_PATTERNS),
      .SEQ_NO_WIDTH (SEQ_NO_WIDTH)
   ) phy_test_pktsrc (

      //--- sigs to/from nf2_mac_grp for Tx FIFOs (egress)
      .tx_data                (tx_data),
      .tx_wr_en               (tx_wr_en),
      .tx_almost_full         (tx_almost_full),

      //--- signs to coordinate the tests
      .port                   (port),
      .pkt_size               (pkt_size),
      .pat_en                 (pat_en),
      .seq_no                 (tx_seq_no),

      .start                  (start_d1),

      .curr_pat               (tx_pat),

      .busy                   (tx_busy),
      .pkt_done               (tx_pkt_done),
      .iter_done              (tx_iter_done),

      //--- misc
      .reset                  (reset || restart),
      .clk                    (clk)
   );

   // Packet sink for performing packet comparisons
   phy_test_pktcmp #(
      .NUM_PATTERNS (NUM_PATTERNS),
      .SEQ_NO_WIDTH (SEQ_NO_WIDTH)
   ) phy_test_pktcmp (
      //--- sigs to/from nf2_mac_grp for RX Fifos (ingress)
      .rx_almost_empty       (rx_almost_empty),
      .rx_data               (rx_data),
      .rx_rd_en              (rx_rd_en),

      //--- sigs to/from phy_test to coordinate the tests
      .port                   (rx_port),
      .pattern                (rx_pattern),

      .pkt_size               (pkt_size),
      .pat_en                 (pat_en),

      .seq_no                 (rx_seq_no),

      .locked                 (rx_locked),

      .busy                   (rx_busy),
      .done                   (rx_done),
      .bad                    (rx_bad),

      // Log signals
      .log_rx_data            (log_rx_data),
      .log_exp_data           (log_exp_data),
      .log_addr               (log_addr),
      .log_data_wr            (log_data_wr),
      .log_done               (log_done),
      .log_hold               (log_hold),

      //--- misc
      .reset                  (reset || restart),
      .clk                    (clk)
   );

   // TX registers
   phy_test_tx_reg #(
      .REG_ADDR_WIDTH (REG_ADDR_WIDTH - 2),
      .NUM_PATTERNS (NUM_PATTERNS),
      .SEQ_NO_WIDTH (SEQ_NO_WIDTH)
   ) phy_test_tx_reg (
      // Register interface signals
      .reg_req                                  (local_reg_req[`WORD(TX_REG_ADDR,1)]),
      .reg_ack                                  (local_reg_ack[`WORD(TX_REG_ADDR,1)]),
      .reg_rd_wr_L                              (local_reg_rd_wr_L[`WORD(TX_REG_ADDR,1)]),
      .reg_addr                                 (local_reg_addr[`WORD(TX_REG_ADDR, (REG_ADDR_WIDTH - 2))]),

      .reg_rd_data                              (local_reg_rd_data[`WORD(TX_REG_ADDR, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data                              (local_reg_wr_data[`WORD(TX_REG_ADDR, `CPCI_NF2_DATA_WIDTH)]),

      // Tx interface logic
      .pkt_done                                 (tx_pkt_done),
      .iter_done                                (tx_iter_done),
      .done                                     (!tx_busy),
      .curr_pat                                 (tx_pat),
      .curr_seq_no                              (tx_seq_no),
      .restart                                  (restart),

      //-- misc
      .clk                                      (clk),
      .reset                                    (reset)
   );

   // RX registers
   phy_test_rx_reg #(
      .REG_ADDR_WIDTH (REG_ADDR_WIDTH - 2),
      .SEQ_NO_WIDTH (SEQ_NO_WIDTH)
   ) phy_test_rx_reg (
      // Register interface signals
      .reg_req                                  (local_reg_req[`WORD(RX_REG_ADDR,1)]),
      .reg_ack                                  (local_reg_ack[`WORD(RX_REG_ADDR,1)]),
      .reg_rd_wr_L                              (local_reg_rd_wr_L[`WORD(RX_REG_ADDR,1)]),
      .reg_addr                                 (local_reg_addr[`WORD(RX_REG_ADDR, (REG_ADDR_WIDTH - 2))]),

      .reg_rd_data                              (local_reg_rd_data[`WORD(RX_REG_ADDR, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data                              (local_reg_wr_data[`WORD(RX_REG_ADDR, `CPCI_NF2_DATA_WIDTH)]),

      // Rx interface logic
      .active                                   (busy),
      .good_pkt                                 (rx_done_d1 && !rx_bad_d1 && rx_seq_good),
      .err_pkt                                  (rx_done_d1 && (rx_bad_d1 || !rx_seq_good)),
      .seq_no                                   (rx_seq_no),
      .seq_no_valid                             (rx_seq_good),
      .done                                     (done),
      .pass                                     (success),
      .locked                                   (rx_locked),
      .src_port                                 (rx_port),

      //-- misc
      .clk                                      (clk),
      .reset                                    (reset || restart)
   );

   // RX log registers
   phy_test_rx_log_reg #(
      .REG_ADDR_WIDTH (REG_ADDR_WIDTH - 2)
   ) phy_test_rx_log_reg (
      // Register interface signals
      .reg_req                                  (local_reg_req[`WORD(RX_LOG_REG_ADDR,1)]),
      .reg_ack                                  (local_reg_ack[`WORD(RX_LOG_REG_ADDR,1)]),
      .reg_rd_wr_L                              (local_reg_rd_wr_L[`WORD(RX_LOG_REG_ADDR,1)]),
      .reg_addr                                 (local_reg_addr[`WORD(RX_LOG_REG_ADDR, (REG_ADDR_WIDTH - 2))]),

      .reg_rd_data                              (local_reg_rd_data[`WORD(RX_LOG_REG_ADDR, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data                              (local_reg_wr_data[`WORD(RX_LOG_REG_ADDR, `CPCI_NF2_DATA_WIDTH)]),

      // Rx interface logic
      .log_rx_data                              (log_rx_data),
      .log_exp_data                             (log_exp_data),
      .log_addr                                 (log_addr),
      .log_data_wr                              (log_data_wr),
      .log_done                                 (log_done),      // Indicates this is the last word of the packet
      .log_hold                                 (log_hold),      // Indicates that the log entry should be held

      .restart                                  (restart),

      //-- misc
      .clk                                      (clk),
      .reset                                    (reset)
   );

   // Port level register switch
   reg_grp #(
      .REG_ADDR_BITS(REG_ADDR_WIDTH),
      .NUM_OUTPUTS(4)
   ) reg_grp (
      // Upstream register interface
      .reg_req                                  (reg_req),
      .reg_rd_wr_L                              (reg_rd_wr_L),
      .reg_addr                                 (reg_addr),
      .reg_wr_data                              (reg_wr_data),

      .reg_ack                                  (reg_ack),
      .reg_rd_data                              (reg_rd_data),


      // Downstream register interface
      .local_reg_req                            (local_reg_req),
      .local_reg_rd_wr_L                        (local_reg_rd_wr_L),
      .local_reg_addr                           (local_reg_addr),
      .local_reg_wr_data                        (local_reg_wr_data),

      .local_reg_ack                            (local_reg_ack),
      .local_reg_rd_data                        (local_reg_rd_data),


      //-- misc
      .clk                                      (clk),
      .reset                                    (reset)
   );

   unused_reg #(
      .REG_ADDR_WIDTH(REG_ADDR_WIDTH - 2)
   ) unused_reg (
      // Register interface signals
      .reg_req       (local_reg_req[`WORD(UNUSED_REG_ADDR,1)]),
      .reg_ack       (local_reg_ack[`WORD(UNUSED_REG_ADDR,1)]),
      .reg_rd_wr_L   (local_reg_rd_wr_L[`WORD(UNUSED_REG_ADDR,1)]),
      .reg_addr      (local_reg_addr[`WORD(UNUSED_REG_ADDR, (REG_ADDR_WIDTH - 2))]),

      .reg_rd_data   (local_reg_rd_data[`WORD(UNUSED_REG_ADDR, `CPCI_NF2_DATA_WIDTH)]),
      .reg_wr_data   (local_reg_wr_data[`WORD(UNUSED_REG_ADDR, `CPCI_NF2_DATA_WIDTH)]),

      //
      .clk           (core_clk_int),
      .reset         (reset)
   );

endmodule   // phy_test_port_grp
