//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
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


   wire        net1_activity;
   wire        net2_activity;
   wire        net3_activity;
   wire        net4_activity;

   wire        pci_activity;

   wire        net1_barrier_req;
   wire        net2_barrier_req;
   wire        net3_barrier_req;
   wire        net4_barrier_req;

   wire        pci_barrier_req;

   wire        net1_done;
   wire        net2_done;
   wire        net3_done;
   wire        net4_done;

   wire        pci_done;

   wire        sim_end;

   wire        barrier_proceed;


   wire        host32_is_active;  // tells us when config is done and we
   // can start to do things.

   // Instantiate the board and host32 and target32 modules
   `include "board_h32_t32.v"


   // The net modules instantiate the ethernet packet source
   // and sink entities.
   // The sources (ingress) read from a file that specifies the ingress packets.
   // The sinks (egress) capture all egress packets and write them to files.

   net net1 (
            .portID           (32'd1),   // which port instance are we
            .rgmii_rx_d       (rgmii_0_rx_d),
            .rgmii_rx_ctl     (rgmii_0_rx_ctl),
            .rgmii_rx_clk     (rgmii_0_rx_clk),
            .rgmii_tx_d       (rgmii_0_tx_d),
            .rgmii_tx_ctl     (rgmii_0_tx_ctl),
            .rgmii_tx_clk     (rgmii_0_tx_clk),
            .link_speed       (link_speed),
            .host32_is_active (host32_is_active),
            .done             (net1_done),
            .sim_end          (sim_end),
            .activity         (net1_activity),
            .barrier_req      (net1_barrier_req),
            .barrier_proceed  (barrier_proceed)
         );

   net net2 (
            .portID           (32'd2),   // which port instance are we
            .rgmii_rx_d       (rgmii_1_rx_d),
            .rgmii_rx_ctl     (rgmii_1_rx_ctl),
            .rgmii_rx_clk     (rgmii_1_rx_clk),
            .rgmii_tx_d       (rgmii_1_tx_d),
            .rgmii_tx_ctl     (rgmii_1_tx_ctl),
            .rgmii_tx_clk     (rgmii_1_tx_clk),
            .link_speed       (link_speed),
            .host32_is_active (host32_is_active),
            .done             (net2_done),
            .sim_end          (sim_end),
            .activity         (net2_activity),
            .barrier_req      (net2_barrier_req),
            .barrier_proceed  (barrier_proceed)
         );

   net net3 (
            .portID           (32'd3),   // which port instance are we
            .rgmii_rx_d       (rgmii_2_rx_d),
            .rgmii_rx_ctl     (rgmii_2_rx_ctl),
            .rgmii_rx_clk     (rgmii_2_rx_clk),
            .rgmii_tx_d       (rgmii_2_tx_d),
            .rgmii_tx_ctl     (rgmii_2_tx_ctl),
            .rgmii_tx_clk     (rgmii_2_tx_clk),
            .link_speed       (link_speed),
            .host32_is_active (host32_is_active),
            .done             (net3_done),
            .sim_end          (sim_end),
            .activity         (net3_activity),
            .barrier_req      (net3_barrier_req),
            .barrier_proceed  (barrier_proceed)
         );

   net net4 (
            .portID           (32'd4),   // which port instance are we
            .rgmii_rx_d       (rgmii_3_rx_d),
            .rgmii_rx_ctl     (rgmii_3_rx_ctl),
            .rgmii_rx_clk     (rgmii_3_rx_clk),
            .rgmii_tx_d       (rgmii_3_tx_d),
            .rgmii_tx_ctl     (rgmii_3_tx_ctl),
            .rgmii_tx_clk     (rgmii_3_tx_clk),
            .link_speed       (link_speed),
            .host32_is_active (host32_is_active),
            .done             (net4_done),
            .sim_end          (sim_end),
            .activity         (net4_activity),
            .barrier_req      (net4_barrier_req),
            .barrier_proceed  (barrier_proceed)
         );

   // Barrier module for performing synchronization across modules
   barrier_ctrl barrier_ctrl (
      .if_activity            ({
                                 net1_activity,
                                 net2_activity,
                                 net3_activity,
                                 net4_activity
                               }),
      .pci_activity           (pci_activity),

      .if_good                ({
                                 net1_barrier_req,
                                 net2_barrier_req,
                                 net3_barrier_req,
                                 net4_barrier_req
                               }),
      .pci_good               (pci_barrier_req),

      .barrier_proceed        (barrier_proceed)
   );

   // Finish module for handling the end of the simulation
   finish_ctrl finish_ctrl (
      .if_done                ({
                                 net1_done,
                                 net2_done,
                                 net3_done,
                                 net4_done
                               }),
      .pci_done               (pci_done),
      .sim_end                (sim_end),
      .host32_is_active       (host32_is_active)
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
