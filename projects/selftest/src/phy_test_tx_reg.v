///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: phy_test_tx_reg.v 5570 2009-05-12 23:01:28Z g9coving $
//
// Module: phy_test_reg.v
// Project: NetFPGA
// Description: Selftest module for Ethernet Phys.
//
// Maintains the registers for a single TX source
//
///////////////////////////////////////////////////////////////////////////////


module phy_test_tx_reg #(parameter
      REG_ADDR_WIDTH = 5,
      NUM_PATTERNS = 5,
      SEQ_NO_WIDTH = 32
   )

   (
      // Register interface signals
      input                                     reg_req,
      input                                     reg_rd_wr_L,    // 1 = read, 0 = write
      input [REG_ADDR_WIDTH -1:0]               reg_addr,
      input [`CPCI_NF2_DATA_WIDTH -1:0]         reg_wr_data,

      output reg                                reg_ack,
      output reg [`CPCI_NF2_DATA_WIDTH -1:0]    reg_rd_data,

      // Tx interface logic
      input                                     pkt_done,
      input                                     iter_done,
      input                                     done,
      input [NUM_PATTERNS - 1:0]                curr_pat,
      input [SEQ_NO_WIDTH - 1:0]                curr_seq_no,
      input                                     restart,

      //-- misc
      input                                     clk,
      input                                     reset
   );

   // ------------- Local storage ------------------
   reg [31:0] pkt_cnt;
   reg [31:0] iter_cnt;

   reg [31:0] rand_seed;

   reg reg_acked;

   // =====================================================
   // Process register requests
   always @(posedge clk)
   begin
      // Reset the register group
      if (reset) begin
         reg_acked <= 1'b0;
         rand_seed <= 'h01;
      end
      else begin
         // Process register requests
         if (reg_req) begin
            // Ack the request if the request is new
            if (!reg_acked) begin
               reg_ack <= 1'b1;

               // Work out which register is being accessed
               case ({{(`PHY_TEST_REG_ADDR_WIDTH - REG_ADDR_WIDTH){1'b0}}, reg_addr})
                  `PHY_TEST_PHY_TX_STATUS : begin
                     reg_rd_data <= {{(16 - NUM_PATTERNS){1'b0}}, curr_pat, 15'b0, done};
                  end

                  `PHY_TEST_PHY_TX_ITER_CNT : begin
                     reg_rd_data <= iter_cnt;
                  end

                  `PHY_TEST_PHY_TX_PKT_CNT : begin
                     reg_rd_data <= pkt_cnt;
                  end

                  `PHY_TEST_PHY_TX_SEQ_NO : begin
                     reg_rd_data <= curr_seq_no;
                  end

                  `PHY_TEST_PHY_TX_RAND_SEED : begin
                     reg_rd_data <= rand_seed;

                     // Handle the write if appropriate
                     if (!reg_rd_wr_L)
                        rand_seed <= reg_wr_data;
                  end

                  default : begin
                     reg_rd_data <= 'h dead_beef;
                  end
               endcase
            end
            else
               reg_ack <= 1'b0;

            // Record that we've processed this request
            reg_acked <= 1'b1;
         end
         else begin
            reg_acked <= 1'b0;
            reg_ack <= 1'b0;
         end
      end
   end



   // =====================================================
   // Process packet done events
   always @(posedge clk)
   begin
      if (reset || restart) begin
         pkt_cnt <= 'h0;
         iter_cnt <= 'h0;
      end
      else begin
         // Increment the packet counter
         if (pkt_done)
            pkt_cnt <= pkt_cnt + 'h1;

         // Increment the iteration counter
         if (iter_done)
            iter_cnt <= iter_cnt + 'h1;
      end
   end

endmodule // phy_test_tx_reg
