//////////////////////////////////////////////////////////////////////////////
// $Id: testbench.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: testbench.v
// Project: NetFPGA-1G board testbench
// Description: Instantiates the NetFPGA-1G board  and runs a test.
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns/1 ns

module testbench;

   parameter ETH_10   = 2'b00,
             ETH_100  = 2'b01,
             ETH_1000 = 2'b10;

   wire [1:0] link_speed = ETH_1000;
//   wire [1:0] link_speed = ETH_100;

   wire [3:0]  rgmii_0_tx_d;
   wire [3:0]  rgmii_1_tx_d;
   wire [3:0]  rgmii_2_tx_d;
   wire [3:0]  rgmii_3_tx_d;

   wire [3:0]  rgmii_0_rx_d;
   wire [3:0]  rgmii_1_rx_d;
   wire [3:0]  rgmii_2_rx_d;
   wire [3:0]  rgmii_3_rx_d;

   // Need to specify wires for rx_dv and rx_er if net module is
   // not instantiated for the remaining 3 ports.
   wire        rgmii_1_rx_dv;
   wire        rgmii_1_rx_er;
   wire        rgmii_2_rx_dv;
   wire        rgmii_2_rx_er;
   wire        rgmii_3_rx_dv;
   wire        rgmii_3_rx_er;


   wire        host32_is_active;  // tells us when config is done and we
   // can start to do things.

   // Instantiate the board and host32 and target32 modules
   `include "board_h32_t32.v"


   // The net modules instantiate the ethernet packet source
   // and sink entities.
   // The sources (ingress) read from a file that specifies the ingress packets.
   // The sinks (egress) capture all egress packets and write them to files.

   net net1 (
             .portID          (32'd1),   // which port instance are we
             .rgmii_rx_d       (rgmii_0_rx_d),
             .rgmii_rx_ctl      (rgmii_0_rx_ctl),
             .rgmii_rx_clk     (rgmii_0_rx_clk),
             .rgmii_tx_d       (rgmii_0_tx_d),
             .rgmii_tx_ctl      (rgmii_0_tx_ctl),
             .rgmii_tx_clk     (rgmii_0_tx_clk),
             .link_speed      (link_speed),
             .host32_is_active(host32_is_active)
             );

   net net2 (
             .portID          (32'd2),   // which port instance are we
             .rgmii_rx_d       (rgmii_1_rx_d),
             .rgmii_rx_ctl      (rgmii_1_rx_ctl),
             .rgmii_rx_clk     (rgmii_1_rx_clk),
             .rgmii_tx_d       (rgmii_1_tx_d),
             .rgmii_tx_ctl      (rgmii_1_tx_ctl),
             .rgmii_tx_clk     (rgmii_1_tx_clk),
             .link_speed      (link_speed),
             .host32_is_active(host32_is_active)
             );

   net net3 (
             .portID          (32'd3),   // which port instance are we
             .rgmii_rx_d       (rgmii_2_rx_d),
             .rgmii_rx_ctl      (rgmii_2_rx_ctl),
             .rgmii_rx_clk     (rgmii_2_rx_clk),
             .rgmii_tx_d       (rgmii_2_tx_d),
             .rgmii_tx_ctl      (rgmii_2_tx_ctl),
             .rgmii_tx_clk     (rgmii_2_tx_clk),
             .link_speed      (link_speed),
             .host32_is_active(host32_is_active)
             );

   net net4 (
             .portID          (32'd4),   // which port instance are we
             .rgmii_rx_d       (rgmii_3_rx_d),
             .rgmii_rx_ctl      (rgmii_3_rx_ctl),
             .rgmii_rx_clk     (rgmii_3_rx_clk),
             .rgmii_tx_d       (rgmii_3_tx_d),
             .rgmii_tx_ctl      (rgmii_3_tx_ctl),
             .rgmii_tx_clk     (rgmii_3_tx_clk),
             .link_speed      (link_speed),
             .host32_is_active(host32_is_active)
             );


   // ---------------------------------------
   // --- The main test routines ------------
   // ---------------------------------------


   initial begin

      // add any user defined code
      `ifdef SIM_INCLUDE
         `SIM_INCLUDE;
      `endif

      // wait for the host32 to complete the PCI configuration.
      wait (host32_is_active === 1'b1);
      $display("%t System appears to be up.",$time);

      while(1) begin
         #10000 $display("Timecheck: %t",$time);
      end

   end // main test routine



   initial begin
      $timeformat(-9,2,"ns", 10); // -9 =ns  2=digits after .
   end
endmodule // testbench
