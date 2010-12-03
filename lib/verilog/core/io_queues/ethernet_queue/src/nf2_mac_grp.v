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

   // ethernet MAC

   gig_eth_mac gig_eth_mac
     (
       // Reset, clocks
       .reset			(reset_MAC),
       .tx_clk			(txgmiimiiclk),
       .rx_clk			(rxgmiimiiclk),

       // Run-time Configuration (takes effect between frames)
       .conf_tx_en		(tx_mac_en),
       .conf_rx_en		(rx_mac_en),
       .conf_tx_no_gen_crc	(disable_crc_gen),
       .conf_rx_no_chk_crc	(disable_crc_check),
       .conf_tx_jumbo_en	(enable_jumbo_tx),
       .conf_rx_jumbo_en	(enable_jumbo_rx),

       // TX Client Interface
       .mac_tx_data		(gmac_tx_data),
       .mac_tx_dvld		(gmac_tx_dvld),
       .mac_tx_ack		(gmac_tx_ack),
       .mac_tx_underrun		(1'b0),

       // RX Client Interface
       .mac_rx_data		(gmac_rx_data),
       .mac_rx_dvld		(gmac_rx_dvld),
       .mac_rx_goodframe	(gmac_rx_goodframe),
       .mac_rx_badframe		(gmac_rx_badframe),

       // TX GMII Interface
       .gmii_tx_data		(gmii_tx_d),
       .gmii_tx_en		(gmii_tx_en),
       .gmii_tx_er		(gmii_tx_er),

       // RX GMII Interface
       .gmii_rx_data		(gmii_rx_d),
       .gmii_rx_dvld		(gmii_rx_dv),
       .gmii_rx_er		(gmii_rx_er),

       .gmii_col		(gmii_col),
       .gmii_crs	        (gmii_crs));

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
