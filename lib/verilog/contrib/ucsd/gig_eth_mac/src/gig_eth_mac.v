///////////////////////////////////////////////////////////////////////////////
//
// Gigabit Ethernet MAC
//
// Description: A very simple GbE MAC with GMII interface. Only full-duplex
// 1Gbps operation is supported. No PHY management interface. It does not
// interpret Ethernet headers. If just sends and receives frames. It handles
// preamble, zero-padding, CRC generation and checking, and interframe gap.
// Maximum frame length is enforced. CRC can be disabled. Jumbo frames can
// be enabled.
//
// Author: Erik Rubow
//
///////////////////////////////////////////////////////////////////////////////

module gig_eth_mac
#(
  parameter MAX_FRAME_SIZE_STANDARD = 1522,
  parameter MAX_FRAME_SIZE_JUMBO    = 9022
)
(
  // Reset, clocks
  input  wire reset,    // asynchronous
  input  wire tx_clk,
  input  wire rx_clk,

  // Run-time Configuration (takes effect between frames)
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

  //-------- Instantiated modules --------//
  gig_eth_mac_tx #( .MAX_FRAME_SIZE_STANDARD (MAX_FRAME_SIZE_STANDARD),
                    .MAX_FRAME_SIZE_JUMBO (MAX_FRAME_SIZE_JUMBO)) mac_tx
  (
    .reset              (reset),
    .tx_clk             (tx_clk),
    .conf_tx_en         (conf_tx_en),
    .conf_tx_no_gen_crc (conf_tx_no_gen_crc),
    .conf_tx_jumbo_en   (conf_tx_jumbo_en),
    .mac_tx_data        (mac_tx_data),
    .mac_tx_dvld        (mac_tx_dvld),
    .mac_tx_ack         (mac_tx_ack),
    .mac_tx_underrun    (mac_tx_underrun),
    .gmii_txd           (gmii_tx_data),
    .gmii_txen          (gmii_tx_en),
    .gmii_txer          (gmii_tx_er)
  );

  gig_eth_mac_rx #( .MAX_FRAME_SIZE_STANDARD (MAX_FRAME_SIZE_STANDARD),
                    .MAX_FRAME_SIZE_JUMBO (MAX_FRAME_SIZE_JUMBO)) mac_rx
  (
    .reset              (reset),
    .rx_clk             (rx_clk),
    .conf_rx_en         (conf_rx_en),
    .conf_rx_no_chk_crc (conf_rx_no_chk_crc),
    .conf_rx_jumbo_en   (conf_rx_jumbo_en),
    .mac_rx_data        (mac_rx_data),
    .mac_rx_dvld        (mac_rx_dvld),
    .mac_rx_goodframe   (mac_rx_goodframe),
    .mac_rx_badframe    (mac_rx_badframe),
    .gmii_rxd           (gmii_rx_data),
    .gmii_rxdv          (gmii_rx_dvld),
    .gmii_rxer          (gmii_rx_er)
  );

endmodule

