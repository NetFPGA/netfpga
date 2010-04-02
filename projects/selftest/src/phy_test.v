///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: phy_test.v 4196 2008-06-23 23:12:37Z grg $
//
// Module: phy_test.v
// Project: NetFPGA
// Description: Selftest module for Ethernet Phys.
//
//
///////////////////////////////////////////////////////////////////////////////

module phy_test #(parameter
      NUM_PATTERNS = 5,
      SEQ_NO_WIDTH = 32,
      SEQ_RANGE = 256          // Allowable range for a sequence
   )
   (
      //--- sigs to/from nf2_mac_grp for Rx FIFOs (ingress)
      input         rx_0_almost_empty,
      input [35:0]  rx_0_data,
      output        rx_0_rd_en,

      input         rx_1_almost_empty,
      input [35:0]  rx_1_data,
      output        rx_1_rd_en,

      input         rx_2_almost_empty,
      input [35:0]  rx_2_data,
      output        rx_2_rd_en,

      input         rx_3_almost_empty,
      input [35:0]  rx_3_data,
      output        rx_3_rd_en,

      //--- sigs to/from cnet_mac_grp for Tx FIFOs (egress)
      output [35:0]     tx_0_data,
      output            tx_0_wr_en,
      input             tx_0_almost_full,

      output [35:0]     tx_1_data,
      output            tx_1_wr_en,
      input             tx_1_almost_full,

      output [35:0]     tx_2_data,
      output            tx_2_wr_en,
      input             tx_2_almost_full,

      output [35:0]     tx_3_data,
      output            tx_3_wr_en,
      input             tx_3_almost_full,

      //-- sigs to/from nf2_reg_grp
      input                                     reg_req,
      input                                     reg_rd_wr_L,    // 1 = read, 0 = write
      input [`PHY_TEST_REG_ADDR_WIDTH -1:0]     reg_addr,
      input [`CPCI_NF2_DATA_WIDTH -1:0]         reg_wr_data,

      output                                    reg_ack,
      output [`CPCI_NF2_DATA_WIDTH -1:0]        reg_rd_data,

      //--- sigs to test console
      output done,
      output success,
      output mac_reset,

      // misc
      input reset,
      input clk
   );

   wire [3:0] local_success;
   wire [3:0] local_done;
   wire [3:0] local_busy;

   wire start;
   wire busy;

   wire [NUM_PATTERNS - 1 : 0] pat_en;
   wire [SEQ_NO_WIDTH - 1 : 0] init_seq_no;
   wire [10 : 0] size;

   wire [SEQ_NO_WIDTH - 1 : 0] port_seq_no[3:0];


   // Top level register interface
   wire                                   top_reg_req[1:0];
   wire                                   top_reg_rd_wr_L[1:0];
   wire [`PHY_TEST_REG_ADDR_WIDTH - 1 - 1:0] top_reg_addr[1:0];
   wire [`CPCI_NF2_DATA_WIDTH - 1:0]      top_reg_wr_data[1:0];

   wire                                   top_reg_ack[1:0];
   wire [`CPCI_NF2_DATA_WIDTH - 1:0]      top_reg_rd_data[1:0];

   // Top level register interface (flat)
   wire [1:0]                             top_flat_reg_req;
   wire [1:0]                             top_flat_reg_rd_wr_L;
   wire [2 * (`PHY_TEST_REG_ADDR_WIDTH - 1) - 1:0] top_flat_reg_addr;
   wire [2 * `CPCI_NF2_DATA_WIDTH - 1:0]  top_flat_reg_wr_data;

   wire [1:0]                             top_flat_reg_ack;
   wire [2 * `CPCI_NF2_DATA_WIDTH - 1:0]  top_flat_reg_rd_data;


   // port level register interface
   wire                                   port_reg_req[3:0];
   wire                                   port_reg_rd_wr_L[3:0];
   wire [`PHY_TEST_REG_ADDR_WIDTH - (2 + 1) - 1:0] port_reg_addr[3:0];
   wire [`CPCI_NF2_DATA_WIDTH - 1:0]      port_reg_wr_data[3:0];

   wire                                   port_reg_ack[3:0];
   wire [`CPCI_NF2_DATA_WIDTH - 1:0]      port_reg_rd_data[3:0];

   // port level register interface (flat)
   wire [3:0]                             port_flat_reg_req;
   wire [3:0]                             port_flat_reg_rd_wr_L;
   wire [4 * (`PHY_TEST_REG_ADDR_WIDTH - (2 + 1)) - 1:0] port_flat_reg_addr;
   wire [4 * `CPCI_NF2_DATA_WIDTH - 1:0]  port_flat_reg_wr_data;

   wire [3:0]                             port_flat_reg_ack;
   wire [4 * `CPCI_NF2_DATA_WIDTH - 1:0]  port_flat_reg_rd_data;

   // Rx/Tx signals
   wire              rx_almost_empty[3:0];
   wire [35:0]       rx_data[3:0];
   wire              rx_rd_en[3:0];

   wire [35:0]       tx_data[3:0];
   wire              tx_wr_en[3:0];
   wire              tx_almost_full[3:0];

   assign done = &local_done;
   assign success = &local_success;
   assign busy = |local_busy;



   // =====================================================
   // Instantiate the core modules

   // Global registers
   phy_test_reg #(
      .REG_ADDR_WIDTH (`PHY_TEST_REG_ADDR_WIDTH - 1),
      .NUM_PATTERNS (NUM_PATTERNS),
      .SEQ_NO_WIDTH (SEQ_NO_WIDTH)
   ) phy_test_reg (
      // Register interface signals
      .reg_req                                  (top_reg_req[0]),
      .reg_rd_wr_L                              (top_reg_rd_wr_L[0]),    // 1 = read, 0 = write
      .reg_addr                                 (top_reg_addr[0]),
      .reg_wr_data                              (top_reg_wr_data[0]),

      .reg_ack                                  (top_reg_ack[0]),
      .reg_rd_data                              (top_reg_rd_data[0]),

      // Test interface
      .done                                     (done),
      .good                                     (success),
      .busy                                     (busy),
      .start                                    (start),
      .mac_reset                                (mac_reset),

      .pat_en                                   (pat_en),
      .init_seq_no                              (init_seq_no),
      .size                                     (size),

      //-- misc
      .clk                                      (clk),
      .reset                                    (reset)
   );

   // Port groups
   genvar i;
   generate
      for (i = 0; i < 4; i = i + 1) begin : port_grp
         phy_test_port_grp #(
               .REG_ADDR_WIDTH (`PHY_TEST_REG_ADDR_WIDTH - 1 - 2),
               .NUM_PATTERNS (NUM_PATTERNS),
               .SEQ_NO_WIDTH (SEQ_NO_WIDTH),
               .SEQ_RANGE (SEQ_RANGE)
            ) phy_test_port_grp  (
               //--- PHY test signals
               .port                         (i + 1),
               .pkt_size                     (size),
               .pat_en                       (pat_en),

               .start                        (start),

               .init_seq_no                  (init_seq_no),
               .tx_seq_no                    (port_seq_no[i]),

               .port_1_seq_no                (port_seq_no[0]),
               .port_2_seq_no                (port_seq_no[1]),
               .port_3_seq_no                (port_seq_no[2]),
               .port_4_seq_no                (port_seq_no[3]),

               .done                         (local_done[i]),
               .success                      (local_success[i]),
               .busy                         (local_busy[i]),

               //--- sigs to/from nf2_mac_grp for Rx FIFOs (ingress)
               .rx_almost_empty  (rx_almost_empty[i]),
               .rx_data          (rx_data[i]),
               .rx_rd_en         (rx_rd_en[i]),


               //--- sigs to/from cnet_mac_grp for Tx FIFOs (egress)

               .tx_data          (tx_data[i]),
               .tx_wr_en         (tx_wr_en[i]),
               .tx_almost_full   (tx_almost_full[i]),

               //-- sigs to/from nf2_reg_grp
               .reg_req                      (port_reg_req[i]),
               .reg_rd_wr_L                  (port_reg_rd_wr_L[i]),
               .reg_addr                     (port_reg_addr[i]),
               .reg_wr_data                  (port_reg_wr_data[i]),

               .reg_ack                      (port_reg_ack[i]),
               .reg_rd_data                  (port_reg_rd_data[i]),

               // misc
               .reset(reset),
               .clk  (clk)
            );
      end // for
   endgenerate

   // Top level register switch
   reg_grp #(
      .REG_ADDR_BITS (`PHY_TEST_REG_ADDR_WIDTH),
      .NUM_OUTPUTS   (2)
   ) reg_grp_top_level
   (
      // Upstream register interface
      .reg_req                                  (reg_req),
      .reg_rd_wr_L                              (reg_rd_wr_L),
      .reg_addr                                 (reg_addr),
      .reg_wr_data                              (reg_wr_data),

      .reg_ack                                  (reg_ack),
      .reg_rd_data                              (reg_rd_data),


      // Downstream register interface
      .local_reg_req                            (top_flat_reg_req),
      .local_reg_rd_wr_L                        (top_flat_reg_rd_wr_L),
      .local_reg_addr                           (top_flat_reg_addr),
      .local_reg_wr_data                        (top_flat_reg_wr_data),

      .local_reg_ack                            (top_flat_reg_ack),
      .local_reg_rd_data                        (top_flat_reg_rd_data),


      //-- misc
      .clk                                      (clk),
      .reset                                    (reset)
   );

   // Port level register switch
   reg_grp #(
      .REG_ADDR_BITS(`PHY_TEST_REG_ADDR_WIDTH - 1),
      .NUM_OUTPUTS(4)
   ) reg_grp_port_level
   (
      // Upstream register interface
      .reg_req                                  (top_reg_req[1]),
      .reg_rd_wr_L                              (top_reg_rd_wr_L[1]),
      .reg_addr                                 (top_reg_addr[1]),
      .reg_wr_data                              (top_reg_wr_data[1]),

      .reg_ack                                  (top_reg_ack[1]),
      .reg_rd_data                              (top_reg_rd_data[1]),


      // Downstream register interface
      .local_reg_req                            (port_flat_reg_req),
      .local_reg_rd_wr_L                        (port_flat_reg_rd_wr_L),
      .local_reg_addr                           (port_flat_reg_addr),
      .local_reg_wr_data                        (port_flat_reg_wr_data),

      .local_reg_ack                            (port_flat_reg_ack),
      .local_reg_rd_data                        (port_flat_reg_rd_data),


      //-- misc
      .clk                                      (clk),
      .reset                                    (reset)
   );



   // =====================================================
   // Copy the rx/tx signals into the arrays

   assign rx_almost_empty[0] = rx_0_almost_empty;
   assign rx_data[0] = rx_0_data;
   assign rx_0_rd_en = rx_rd_en[0];

   assign rx_almost_empty[1] = rx_1_almost_empty;
   assign rx_data[1] = rx_1_data;
   assign rx_1_rd_en = rx_rd_en[1];

   assign rx_almost_empty[2] = rx_2_almost_empty;
   assign rx_data[2] = rx_2_data;
   assign rx_2_rd_en = rx_rd_en[2];

   assign rx_almost_empty[3] = rx_3_almost_empty;
   assign rx_data[3] = rx_3_data;
   assign rx_3_rd_en = rx_rd_en[3];

   assign tx_0_data = tx_data[0];
   assign tx_0_wr_en = tx_wr_en[0];
   assign tx_almost_full[0] = tx_0_almost_full;

   assign tx_1_data = tx_data[1];
   assign tx_1_wr_en = tx_wr_en[1];
   assign tx_almost_full[1] = tx_1_almost_full;

   assign tx_2_data = tx_data[2];
   assign tx_2_wr_en = tx_wr_en[2];
   assign tx_almost_full[2] = tx_2_almost_full;

   assign tx_3_data = tx_data[3];
   assign tx_3_wr_en = tx_wr_en[3];
   assign tx_almost_full[3] = tx_3_almost_full;



   // =====================================================
   // Enapsulate/decapsulate reg signals

   generate
      for (i = 0; i < 2; i = i + 1) begin : top_reg
         assign top_reg_req[i]      = top_flat_reg_req[i];
         assign top_reg_rd_wr_L[i]  = top_flat_reg_rd_wr_L[i];
         assign top_reg_addr[i]     = top_flat_reg_addr[i * (`PHY_TEST_REG_ADDR_WIDTH - 1) +: (`PHY_TEST_REG_ADDR_WIDTH - 1)];
         assign top_reg_wr_data[i]  = top_flat_reg_wr_data[i * `CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH];

         assign top_flat_reg_ack[i] = top_reg_ack[i];
         assign top_flat_reg_rd_data[i * `CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH]  = top_reg_rd_data[i];
      end //for

      for (i = 0; i < 4; i = i + 1) begin : port_reg
         assign port_reg_req[i]     = port_flat_reg_req[i];
         assign port_reg_rd_wr_L[i] = port_flat_reg_rd_wr_L[i];
         assign port_reg_addr[i]    = port_flat_reg_addr[i * (`PHY_TEST_REG_ADDR_WIDTH - 2 - 1) +: (`PHY_TEST_REG_ADDR_WIDTH - 2 - 1)];
         assign port_reg_wr_data[i] = port_flat_reg_wr_data[i * `CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH];

         assign port_flat_reg_ack[i]= port_reg_ack[i];
         assign port_flat_reg_rd_data[i * `CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH] = port_reg_rd_data[i];
      end //for
   endgenerate

endmodule   // phy_test
