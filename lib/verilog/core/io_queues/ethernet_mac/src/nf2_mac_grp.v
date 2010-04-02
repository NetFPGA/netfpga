///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: nf2_mac_grp.v 4444 2008-08-27 19:23:02Z grg $
//
// Module: nf2_mac_grp.v
// Project: NetFPGA Rev 2.1
// Description: Upper level module that instantiates the MAC FIFOs
//
///////////////////////////////////////////////////////////////////////////////

  module nf2_mac_grp
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter ENABLE_HEADER = 0,
      parameter STAGE_NUMBER = 'hff,
      parameter PORT_NUMBER = 0
      )

   (// --- register interface
    input                                mac_grp_reg_req,
    input                                mac_grp_reg_rd_wr_L,
    input  [`MAC_GRP_REG_ADDR_WIDTH-1:0] mac_grp_reg_addr,
    input  [`CPCI_NF2_DATA_WIDTH-1:0]     mac_grp_reg_wr_data,
    output [`CPCI_NF2_DATA_WIDTH-1:0]     mac_grp_reg_rd_data,
    output                               mac_grp_reg_ack,

    // --- output to data path interface
    output [DATA_WIDTH-1:0]              out_data,
    output [CTRL_WIDTH-1:0]              out_ctrl,
    output                               out_wr,
    input                                out_rdy,

    // --- input from data path interface
    input  [DATA_WIDTH-1:0]              in_data,
    input  [CTRL_WIDTH-1:0]              in_ctrl,
    input                                in_wr,
    output                               in_rdy,

    // --- pins
    output [7:0]                         gmii_tx_d,
    output                               gmii_tx_en,
    output                               gmii_tx_er,
    input                                gmii_crs,
    input                                gmii_col,
    input [7:0]                          gmii_rx_d,
    input                                gmii_rx_dv,
    input                                gmii_rx_er,

    //--- misc
    input        txgmiimiiclk,
    input        rxgmiimiiclk,
    input        clk,
    input        reset
    );


   wire          disable_crc_check;
   wire          disable_crc_gen;
   wire          enable_jumbo_rx;
   wire          enable_jumbo_tx;
   wire          rx_mac_en;
   wire          tx_mac_en;

   wire [7:0]     gmac_tx_data;
   wire [7:0]     gmac_rx_data;
   wire           reset_MAC;

   wire [1:0]     mac_speed               = 2'b10;       // set MAC speed to 1G, note: 10M and 100M are not supported

   wire [11:0]    tx_pkt_byte_cnt;
   wire [9:0]     tx_pkt_word_cnt;

   wire [11:0]    rx_pkt_byte_cnt;
   wire [9:0]     rx_pkt_word_cnt;
   wire           rx_pkt_pulled;

   // See Tri-Mode Ethernet MAC user Guide "Configuration Vector Description" (p66)
   wire [66 : 0] tieemacconfigvec =
                 {mac_speed[1:0],        // 66:65 = MAC speed  00=10M 01=100M 10=1000M (default)
                  1'b0,                  // 64 0 = promiscuous mode
                  1'b1,                  // 63 0 = perform length/error checks
                                         //        Note: When this is zero the MAC will verify that the
                                         //        length in the ethertype/length field matches the packet
                                         //        length if the length <= 1536. If the length < 46 it
                                         //        will actually result in packet truncation as it
                                         //        assumes that the packet has padding.
                                         //        This WILL cause problems unless all modules are
                                         //        capable of working with packets that are 2 words
                                         //        in length.
                                         //
                  1'b0,                  // 62 0 = ignore pause frames (pass them thru)
                  1'b0,                  // 61 0 = ignore clientemacpausereq signal
                  reset_MAC,             // 60 1 = reset transmitter (asynch)
                  enable_jumbo_tx,       // 59 1 = allow Tx of Jumbos (dflt 1)
                  disable_crc_gen,       // 58 1 = user will supply FCS 0 = MAC will compute it (dflt = 0)
                  1'b1,                  // 57 1 = Transmitter Enable
                  1'b1,                  // 56 1 = Enable VLAN frames to be sent
                  1'b0,                  // 55 0 = Tx is full duplex (dflt), 1 = half duplex
                  1'b0,                  // 54 0 = Tx inter Frame Gap is ignored (always legal)
                  reset_MAC,             // 53 0 = reset receiver (asynch)
                  enable_jumbo_rx,       // 52 1 = allow Rx of Jumbos (dflt 1)
                  disable_crc_check,     // 51 1 = receiver will provide FCS 0 = no FCS (dflt = 0)
                  1'b1,                  // 50 1 = Receiver Enable
                  1'b1,                  // 49 1 = Enable VLAN frames to be received
                  1'b0,                  // 48 0 = Rx is full duplex (dflt), 1 = half duplex
                  48'haaaaaa_bbbbbb      // 47:0 = MAC Pause Frame SA (ignored anyway)
                  };

   // tri-mode MAC

   tri_mode_eth_mac tri_mode_eth_mac (
        .reset                  (reset_MAC),
        .emacphytxd             (gmii_tx_d),
        .emacphytxen            (gmii_tx_en),
        .emacphytxer            (gmii_tx_er),
        .phyemaccrs             (gmii_crs),
        .phyemaccol             (gmii_col),
        .phyemacrxd             (gmii_rx_d),
        .phyemacrxdv            (gmii_rx_dv),
        .phyemacrxer            (gmii_rx_er),

        .clientemactxd          (gmac_tx_data),
        .clientemactxdvld       (gmac_tx_dvld),
        .emacclienttxack        (gmac_tx_ack),
        .clientemactxunderrun   (1'b0),
        .emacclienttxcollision  (),
        .emacclienttxretransmit (),
        .clientemactxifgdelay   (8'd13), // see Interframe Gap Adjust in Tri-mode_MAC User Guide
        .clientemacpausereq     (1'b0),
        .clientemacpauseval     (16'h0),
        .clientemactxenable     (tx_mac_en),    // default = 1
        .emacclientrxd          (gmac_rx_data),
        .emacclientrxdvld       (gmac_rx_dvld),
        .emacclientrxgoodframe  (gmac_rx_goodframe),
        .emacclientrxbadframe   (gmac_rx_badframe),
        .clientemacrxenable     (rx_mac_en),    // default = 1
        .emacclienttxstats      (),  // dont use stats
        .emacclienttxstatsvld   (),
        .emacclientrxstats      (),
        .emacclientrxstatsvld   (),

        .tieemacconfigvec       (tieemacconfigvec),

        .txgmiimiiclk           (txgmiimiiclk),
        .rxgmiimiiclk           (rxgmiimiiclk),
        .speedis100             (),
        .speedis10100           (),
        .corehassgmii           (1'b0));


   rx_queue
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .ENABLE_HEADER(ENABLE_HEADER),
       .STAGE_NUMBER(STAGE_NUMBER),
       .PORT_NUMBER(PORT_NUMBER)
       ) rx_queue
     (// data path interface
      .out_ctrl                         (out_ctrl),
      .out_wr                           (out_wr),
      .out_data                         (out_data),
      .out_rdy                          (out_rdy),
      // gmac interface
      .gmac_rx_data                     (gmac_rx_data),
      .gmac_rx_dvld                     (gmac_rx_dvld),
      .gmac_rx_goodframe                (gmac_rx_goodframe),
      .gmac_rx_badframe                 (gmac_rx_badframe),
      // reg signals
      .rx_pkt_good                      (rx_pkt_good),
      .rx_pkt_bad                       (rx_pkt_bad),
      .rx_pkt_dropped                   (rx_pkt_dropped),
      .rx_pkt_byte_cnt                  (rx_pkt_byte_cnt),
      .rx_pkt_word_cnt                  (rx_pkt_word_cnt),
      .rx_pkt_pulled                    (rx_pkt_pulled),
      .rx_queue_en                      (rx_queue_en),
      // misc
      .reset                            (reset),
      .clk                              (clk),
      .rxcoreclk                        (rxgmiimiiclk));

   tx_queue
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .ENABLE_HEADER(ENABLE_HEADER),
       .STAGE_NUMBER(STAGE_NUMBER)
       ) tx_queue
     (// data path interface
      .in_ctrl                          (in_ctrl),
      .in_wr                            (in_wr),
      .in_data                          (in_data),
      .in_rdy                           (in_rdy),
      // gmac interface
      .gmac_tx_data                     (gmac_tx_data),
      .gmac_tx_dvld                     (gmac_tx_dvld),
      .gmac_tx_ack                      (gmac_tx_ack),
      // reg signals
      .tx_queue_en                      (tx_queue_en),
      .tx_pkt_sent                      (tx_pkt_sent),
      .tx_pkt_stored                    (tx_pkt_stored),
      .tx_pkt_byte_cnt                  (tx_pkt_byte_cnt),
      .tx_pkt_word_cnt                  (tx_pkt_word_cnt),
      // misc
      .reset                            (reset),
      .clk                              (clk),
      .txcoreclk                        (txgmiimiiclk));

   mac_grp_regs
     #(
        .CTRL_WIDTH(CTRL_WIDTH)
        ) mac_grp_regs
       (
        .mac_grp_reg_req                 (mac_grp_reg_req),
        .mac_grp_reg_rd_wr_L             (mac_grp_reg_rd_wr_L),
        .mac_grp_reg_addr                (mac_grp_reg_addr),
        .mac_grp_reg_wr_data             (mac_grp_reg_wr_data),

        .mac_grp_reg_rd_data             (mac_grp_reg_rd_data),
        .mac_grp_reg_ack                 (mac_grp_reg_ack),

        // interface to mac controller
        .disable_crc_check               (disable_crc_check),
        .disable_crc_gen                 (disable_crc_gen),
        .enable_jumbo_rx                 (enable_jumbo_rx),
        .enable_jumbo_tx                 (enable_jumbo_tx),
        .rx_mac_en                       (rx_mac_en),
        .tx_mac_en                       (tx_mac_en),
        .reset_MAC                       (reset_MAC),

        // interface to rx queue
        .rx_pkt_good                     (rx_pkt_good),
        .rx_pkt_bad                      (rx_pkt_bad),
        .rx_pkt_dropped                  (rx_pkt_dropped),
        .rx_pkt_byte_cnt                 (rx_pkt_byte_cnt),
        .rx_pkt_word_cnt                 (rx_pkt_word_cnt),
        .rx_pkt_pulled                   (rx_pkt_pulled),

        .rx_queue_en                     (rx_queue_en),

        // interface to tx queue
        .tx_queue_en                     (tx_queue_en),
        .tx_pkt_sent                     (tx_pkt_sent),
        .tx_pkt_stored                   (tx_pkt_stored),
        .tx_pkt_byte_cnt                 (tx_pkt_byte_cnt),
        .tx_pkt_word_cnt                 (tx_pkt_word_cnt),

        .clk                             (clk),
        .reset                           (reset)
         );

endmodule // nf2_mac_grp
