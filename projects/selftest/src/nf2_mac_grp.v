///////////////////////////////////////////////////////////////////////////////
// $Id: nf2_mac_grp.v 3064 2007-12-05 22:59:36Z g9coving $
//
// Module: nf2_mac_grp.v
// Project: NetFPGA Rev 2.1
// Description: Upper level module that instantiates the MAC FIFOs
//
///////////////////////////////////////////////////////////////////////////////

  module nf2_mac_grp
    (
     //--- sigs to/from nf2_regs_grp for Tx FIFO

     input [35:0] txf_data,
     input        txf_wr_en,
     output       txf_full,
     output       txf_almost_full,
     output       txf_prog_full,          // 0 = room for max pkt
     output [7:0] txf_num_pkts_waiting,
     output       txf_pkt_sent_ok,        // pulsed
     output       txf_pkt_underrun,       // pulsed 1 = error


     //--- sigs to/from nf2_regs_grp for Rx FIFO

     output         rxf_empty,
     output         rxf_almost_empty,
     output         rxf_pkt_lost,
     output         rxf_pkt_rcvd,
     output  [7:0]  rxf_num_pkts_waiting,

     //--- sigs to nf2_ingress_arb to read ingress packets from the RXFIFO

     output [35:0]  rxf_data,
     input          rxf_rd_en,
     output         rxf_pkt_avail,

     //--- signals to GMII pins

     output [7:0] gmii_tx_d,
     output       gmii_tx_en,
     output       gmii_tx_er,
     input        gmii_crs,
     input        gmii_col,
     input [7:0]  gmii_rx_d,
     input        gmii_rx_dv,
     input        gmii_rx_er,


     //--- misc

     input        enable_txf_transmit,
     input        enable_rxf_receive,

     input [5:0]  mac_config_reg,
     input        reset_MAC,
//     input        txcoreclk,
//     input        rxcoreclk,
     input        txgmiimiiclk,
     input        rxgmiimiiclk,
//     output       speedis100,
//     output       speedis10100,

     input        clk
     );



   wire [7:0] 	  gmac_tx_data;
   wire [7:0] 	  gmac_rx_data;

   //wire          gmac_tx_enable          = 1'b1;
   //wire          gmac_rx_enable          = 1'b1;

   wire [1:0]    mac_speed               = 2'b10;       // set MAC speed to 1G, note: 10M and 100M are not supported

   // See Tri-Mode Ethernet MAC user Guide "Configuration Vector Description" (p66)
   // TODO: Should we hard-code the first 2 bits to be 10 for 1000Mbps?
   wire [66 : 0] tieemacconfigvec =
		 {mac_speed[1:0],        // 66:65 = MAC speed  00=10M 01=100M 10=1000M (default)
		  1'b0,                  // 64 0 = promiscuous mode
		  1'b0,                  // 63 0 = perform length/error checks
		  1'b0,                  // 62 0 = ignore pause frames (pass them thru)
		  1'b0,                  // 61 0 = ignore clientemacpausereq signal
		  reset_MAC,             // 60 1 = reset transmitter (asynch)
		  mac_config_reg[2],     // 59 1 = allow Tx of Jumbos (dflt 0)
		  mac_config_reg[4],     // 58 1 = user will supply FCS 0 = MAC will compute it (dflt)
		  1'b1,                  // 57 1 = Transmitter Enable
		  1'b1,                  // 56 1 = Enable VLAN frames to be sent
		  mac_config_reg[5],     // 55 0 = Tx is full duplex (dflt), 1 = half duplex
		  1'b0,                  // 54 0 = Tx inter Frame Gap is ignored (always legal)
		  reset_MAC,             // 53 0 = reset receiver (asynch)
		  mac_config_reg[2],     // 52 1 = allow Rx of Jumbos (dflt 0)
		  mac_config_reg[3],     // 51 1 = receiver will provide FCS 0 = no FCS (dflt = 0)
		  1'b1,                  // 50 1 = Receiver Enable
		  1'b1,                  // 49 1 = Enable VLAN frames to be received
		  mac_config_reg[5],     // 48 0 = Rx is full duplex (dflt), 1 = half duplex
		  48'haaaaaa_bbbbbb      // 47:0 = MAC Pause Frame SA (ignored anyway)
		  };


   // TX FIFO

nf2_txfifo_sm nf2_txfifo_sm (
        .txf_din                (txf_data),
        .txf_wr_en              (txf_wr_en),
        .txf_prog_full          (txf_prog_full),
        .txf_full               (txf_full),
        .txf_almost_full        (txf_almost_full),
        .txf_pkt_sent_ok        (txf_pkt_sent_ok),
        .txf_pkt_underrun       (txf_pkt_underrun),
        .txf_num_pkts_waiting   (txf_num_pkts_waiting),
        .gmac_tx_ack            (gmac_tx_ack),
        .gmac_tx_dvld           (gmac_tx_dvld),
        .gmac_tx_data           (gmac_tx_data),
        .gmac_tx_client_underrun(gmac_tx_client_underrun),
        .enable_txf_transmit    (enable_txf_transmit),
        .reset                  (reset_MAC),
        .clk                    (clk),
        .txcoreclk              (txgmiimiiclk)     // TODO: What to use here? txgmiimiiclk?
        );

   // RX FIFO
   nf2_rxfifo_sm nf2_rxfifo_sm (
        .rxf_dout            (rxf_data),
        .rxf_rd_en           (rxf_rd_en),
        .rxf_empty           (rxf_empty),
        .rxf_almost_empty    (rxf_almost_empty),
        .rxf_pkt_avail       (rxf_pkt_avail),
        .rxf_pkt_lost        (rxf_pkt_lost),
        .rxf_pkt_rcvd        (rxf_pkt_rcvd),
        .rxf_num_pkts_waiting(rxf_num_pkts_waiting),
        .gmac_rx_data        (gmac_rx_data),
        .gmac_rx_dvld        (gmac_rx_dvld),
        .gmac_rx_goodframe   (gmac_rx_goodframe),
        .gmac_rx_badframe    (gmac_rx_badframe),
        .enable_rxf_receive  (enable_rxf_receive),
        .reset               (reset_MAC),
        .clk                 (clk),
        .rxcoreclk           (rxgmiimiiclk)
        );


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
        .clientemactxunderrun   (gmac_tx_client_underrun),
        .emacclienttxcollision  (),
        .emacclienttxretransmit (),
        .clientemactxifgdelay   (8'd12), // see Interframe Gap Adjust in Tri-mode_MAC User Guide
        .clientemacpausereq     (1'b0),
        .clientemacpauseval     (16'h0),
        .clientemactxenable     (mac_config_reg[0]),    // default = 1
        .emacclientrxd          (gmac_rx_data),
        .emacclientrxdvld       (gmac_rx_dvld),
        .emacclientrxgoodframe  (gmac_rx_goodframe),
        .emacclientrxbadframe   (gmac_rx_badframe),
        .clientemacrxenable     (mac_config_reg[1]),    // default = 1
        .emacclienttxstats      (),  // dont use stats
        .emacclienttxstatsvld   (),
        .emacclientrxstats      (),
        .emacclientrxstatsvld   (),

        .tieemacconfigvec       (tieemacconfigvec),

        .txgmiimiiclk           (txgmiimiiclk),
        .rxgmiimiiclk           (rxgmiimiiclk),
        .speedis100             (),
        .speedis10100           (),
        .corehassgmii           (1'b0)
);



endmodule // nf2_mac_grp
