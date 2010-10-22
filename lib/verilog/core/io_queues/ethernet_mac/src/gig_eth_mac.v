///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: nf2_mac_grp.v 4444 2008-08-27 19:23:02Z gac1 $
//
// Module: gig_eth_mac.v
// Project: NetFPGA Rev 2.1
// Description: Wraps the Xilinx TEMAC into a standard API
//
///////////////////////////////////////////////////////////////////////////////

  module gig_eth_mac
   (
    // Reset, clocks
    input  wire reset,
    input  wire tx_clk,
    input  wire rx_clk,

    // Configuration (takes effect between frames)
    input  wire conf_tx_en,
    input  wire conf_rx_en,
    input  wire conf_tx_no_gen_crc,
    input  wire conf_rx_no_chk_crc,
    input  wire conf_tx_jumbo_en,
    input  wire conf_rx_jumbo_en,

    // TX Client Interface
    input  wire [7:0] mac_tx_data,
    input  wire mac_tx_dvld,
    output wire mac_tx_ack,
    input  wire mac_tx_underrun,

    // RX Client Interface
    output wire [7:0] mac_rx_data,
    output wire mac_rx_dvld,
    output wire mac_rx_goodframe,
    output wire mac_rx_badframe,

    // TX GMII Interface
    output wire [7:0] gmii_tx_data,
    output wire gmii_tx_en,
    output wire gmii_tx_er,

    // RX GMII Interface
    input  wire [7:0] gmii_rx_data,
    input  wire gmii_rx_dvld,
    input  wire gmii_rx_er,

    input  wire gmii_col,
    input  wire gmii_crs
    );

   wire [1:0]     mac_speed               = 2'b10;       // set MAC speed to 1G, note: 10M and 100M are not supported

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
                  reset,                 // 60 1 = reset transmitter (asynch)
                  conf_tx_jumbo_en,      // 59 1 = allow Tx of Jumbos (dflt 1)
                  conf_tx_no_gen_crc,    // 58 1 = user will supply FCS 0 = MAC will compute it (dflt = 0)
                  1'b1,                  // 57 1 = Transmitter Enable
                  1'b1,                  // 56 1 = Enable VLAN frames to be sent
                  1'b0,                  // 55 0 = Tx is full duplex (dflt), 1 = half duplex
                  1'b0,                  // 54 0 = Tx inter Frame Gap is ignored (always legal)
                  reset,                 // 53 0 = reset receiver (asynch)
                  conf_rx_jumbo_en,      // 52 1 = allow Rx of Jumbos (dflt 1)
                  conf_rx_no_chk_crc,    // 51 1 = receiver will provide FCS 0 = no FCS (dflt = 0)
                  1'b1,                  // 50 1 = Receiver Enable
                  1'b1,                  // 49 1 = Enable VLAN frames to be received
                  1'b0,                  // 48 0 = Rx is full duplex (dflt), 1 = half duplex
                  48'haaaaaa_bbbbbb      // 47:0 = MAC Pause Frame SA (ignored anyway)
                  };

   // tri-mode MAC

   tri_mode_eth_mac tri_mode_eth_mac (
        .reset                  (reset),
        .emacphytxd             (gmii_tx_data),
        .emacphytxen            (gmii_tx_en),
        .emacphytxer            (gmii_tx_er),
        .phyemaccrs             (gmii_crs),
        .phyemaccol             (gmii_col),
        .phyemacrxd             (gmii_rx_data),
        .phyemacrxdv            (gmii_rx_dvld),
        .phyemacrxer            (gmii_rx_er),

        .clientemactxd          (mac_tx_data),
        .clientemactxdvld       (mac_tx_dvld),
        .emacclienttxack        (mac_tx_ack),
        .clientemactxunderrun   (mac_tx_underrun),
        .emacclienttxcollision  (),
        .emacclienttxretransmit (),
        .clientemactxifgdelay   (8'd13), // see Interframe Gap Adjust in Tri-mode_MAC User Guide
        .clientemacpausereq     (1'b0),
        .clientemacpauseval     (16'h0),
        .clientemactxenable     (conf_tx_en),    // default = 1
        .emacclientrxd          (mac_rx_data),
        .emacclientrxdvld       (mac_rx_dvld),
        .emacclientrxgoodframe  (mac_rx_goodframe),
        .emacclientrxbadframe   (mac_rx_badframe),
        .clientemacrxenable     (conf_rx_en),    // default = 1
        .emacclienttxstats      (),  // dont use stats
        .emacclienttxstatsvld   (),
        .emacclientrxstats      (),
        .emacclientrxstatsvld   (),

        .tieemacconfigvec       (tieemacconfigvec),

        .txgmiimiiclk           (tx_clk),
        .rxgmiimiiclk           (rx_clk),
        .speedis100             (),
        .speedis10100           (),
        .corehassgmii           (1'b0));

endmodule // gig_eth_mac
