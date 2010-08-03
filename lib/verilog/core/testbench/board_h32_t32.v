//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
//
// Module: board_h32_t32.v
// Project: NetFPGA-1G board testbench
// Description: Instantiates the NetFPGA-1G board and host32 and target32
// Include this file in your testbench.
//
///////////////////////////////////////////////////////////////////////////////

// `timescale 1 ns/1 ns


   parameter Tpclk = 15;    // half cycle time is 15ns for 33MHz PCI clk
   parameter Trst = 300;    // Duration to assert rst at time 0

   // --- Instantiate the board

   wire [31:0] AD;
   wire [3:0]  CBE;
   reg         PCLK;
   tri1        FRAME_N;
   tri1        TRDY_N;
   tri1        IRDY_N;
   tri1        STOP_N;
   tri1        DEVSEL_N;
   tri1        INTR_A;
   tri1        PERR_N;
   tri1        SERR_N;
   tri1        REQ_N;
   //tri1        GNT_N;
   reg         GNT_N;

   reg 	       gtx_clk;
   reg 	       mii_tx_clk;

   wire        rgmii_0_rx_clk = gtx_clk;
   wire        rgmii_1_rx_clk = gtx_clk;
   wire        rgmii_2_rx_clk = gtx_clk;
   wire        rgmii_3_rx_clk = gtx_clk;

   tri1        phy_mdio;

 u_board u_board (
        .AD           (AD),
        .CBE          (CBE),
        .PAR          (PAR),
        .FRAME_N      (FRAME_N),
        .TRDY_N       (TRDY_N),
        .IRDY_N       (IRDY_N),
        .STOP_N       (STOP_N),
        .DEVSEL_N     (DEVSEL_N),
        .INTR_A       (INTR_A),
        .RST_N        (RST_N),
        .IDSEL        (IDSEL),
        .PERR_N       (PERR_N),
        .SERR_N       (SERR_N),
        .REQ_N        (REQ_N),
        .GNT_N        (GNT_N),
        .PCLK         (PCLK),
        .rgmii_0_tx_d  (rgmii_0_tx_d),
        .rgmii_0_tx_ctl (rgmii_0_tx_ctl),
        .rgmii_0_tx_clk(rgmii_0_tx_clk),
        .rgmii_0_rx_clk(rgmii_0_rx_clk),
        .rgmii_0_rx_d  (rgmii_0_rx_d),
        .rgmii_0_rx_ctl (rgmii_0_rx_ctl),
        .rgmii_1_tx_d  (rgmii_1_tx_d),
        .rgmii_1_tx_ctl (rgmii_1_tx_ctl),
        .rgmii_1_tx_clk(rgmii_1_tx_clk),
        .rgmii_1_rx_clk(rgmii_1_rx_clk),
        .rgmii_1_rx_d  (rgmii_1_rx_d),
        .rgmii_1_rx_ctl (rgmii_1_rx_ctl),
        .rgmii_2_tx_d  (rgmii_2_tx_d),
        .rgmii_2_tx_ctl (rgmii_2_tx_ctl),
        .rgmii_2_tx_clk(rgmii_2_tx_clk),
        .rgmii_2_rx_clk(rgmii_2_rx_clk),
        .rgmii_2_rx_d  (rgmii_2_rx_d),
        .rgmii_2_rx_ctl (rgmii_2_rx_ctl),
        .rgmii_3_tx_d  (rgmii_3_tx_d),
        .rgmii_3_tx_ctl (rgmii_3_tx_ctl),
        .rgmii_3_tx_clk(rgmii_3_tx_clk),
        .rgmii_3_rx_clk(rgmii_3_rx_clk),
        .rgmii_3_rx_d  (rgmii_3_rx_d),
        .rgmii_3_rx_ctl (rgmii_3_rx_ctl),
        .phy_mdc      (phy_mdc),
        .serial_TXP_0        (serial_TXP_0),
        .serial_TXN_0        (serial_TXN_0),
        .serial_RXP_0        (serial_RXP_0),
        .serial_RXN_0        (serial_RXN_0),
        .serial_TXP_1        (serial_TXP_1),
        .serial_TXN_1        (serial_TXN_1),
        .serial_RXP_1        (serial_RXP_1),
        .serial_RXN_1        (serial_RXN_1),
        .phy_mdio     (phy_mdio),
        .gtx_clk      (gtx_clk),
        .mii_tx_clk   (mii_tx_clk),
        .host32_is_active (host32_is_active)
        );

   // loopback SATA connectors
   assign serial_RXP_0 = serial_TXP_1;
   assign serial_RXN_0 = serial_TXN_1;
   assign serial_RXP_1 = serial_TXP_0;
   assign serial_RXN_1 = serial_TXN_0;

   // Specify clocks

   always #Tpclk PCLK       = ~PCLK;       //33MHz
   always #4     gtx_clk    = ~gtx_clk;    // 125MHz
   always #20    mii_tx_clk = ~mii_tx_clk; // 25MHz
   initial begin
      PCLK = 0;
      gtx_clk = 0;
      mii_tx_clk = 0;
   end

   // Perform power-on reset

   reg rst;
   initial
     begin
	rst <= 1'b1;
	#Trst;
	@(negedge PCLK)	rst <= 1'b0;
     end


   assign IDSEL = AD[16];
   //assign GNT_N = REQ_N;
   assign RST_N = !rst;
   assign u_board.phy_int_b = 1'b1;  // turn off PHY interrupt.
   assign u_board.rp_init_b = 1'b1;
   assign u_board.rp_done = 1'b1;


   integer   seed;  // random number seed
   initial begin seed = 1; end


   // Arbitrator for the bus
   //
   // This is deliberately async.
   reg host_req_d1;
   wire host_req;
   reg host_gnt;

   always @(posedge PCLK or posedge host_req)
      host_req_d1 <= host_req;

   initial
      begin
         GNT_N = 1'b1;
	 host_gnt = 1'b1;
      end

   always @*
   begin
      // Grant access to the real PCI device when it requests it
      // unless we've already granted access to the host
      if (!GNT_N && REQ_N)
         GNT_N = 1'b1;
      else if (GNT_N && !REQ_N && (!host_req && !host_req_d1))
         GNT_N = 1'b0;

      // Grant access to the host only if the PCI device hasn't been
      // granted and there isn't currently an operation in progress
      if (host_gnt && !host_req && !host_req_d1)
         host_gnt = 1'b0;
      else if (GNT_N && host_req && IRDY_N && TRDY_N && FRAME_N)
         host_gnt = 1'b1;
   end


   // MDIO interface -- pretends to be the PHY
   phy_mdio_port phy_mdio_port (
         .mdio (phy_mdio),
         .mdc (phy_mdc)
       );



   // host32 manages PCI and read and writes that are sourced (mastered)
   // by the CPU.

   host32 host32 (
		  .AD              (AD),
		  .CBE             (CBE),
		  .PAR             (PAR),
		  .FRAME_N         (FRAME_N),
		  .TRDY_N          (TRDY_N),
		  .IRDY_N          (IRDY_N),
		  .STOP_N          (STOP_N),
		  .DEVSEL_N        (DEVSEL_N),
		  .INTR_A          (INTR_A),
		  .RST_N           (RST_N),
		  .CLK             (PCLK),
		  .req	   	   (host_req),
		  .grant	   (host_gnt),
		  .host32_is_active(host32_is_active),
                  .done            (pci_done),
                  .activity        (pci_activity),
                  .barrier_req     (pci_barrier_req),
                  .barrier_proceed (barrier_proceed)
		  );


   target32 target32 (
		      .AD (AD),
		      .CBE (CBE),
		      .PAR (PAR),
		      .FRAME_N (FRAME_N),
		      .TRDY_N (TRDY_N),
		      .IRDY_N (IRDY_N),
		      .STOP_N (STOP_N),
		      .DEVSEL_N (DEVSEL_N),
		      .RST_N (RST_N),
		      .CLK (PCLK),
                      .sim_end (sim_end)
		      );


// end of include
