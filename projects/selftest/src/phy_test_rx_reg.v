///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: phy_test_rx_reg.v 5971 2010-03-06 06:44:56Z grg $
//
// Module: phy_test_reg.v
// Project: NetFPGA
// Description: Selftest module for Ethernet Phys.
//
// Maintains the registers for a single RX source
//
///////////////////////////////////////////////////////////////////////////////


module phy_test_rx_reg #(parameter
      REG_ADDR_WIDTH = 5,
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

      // Rx interface logic
      input                                     active,
      input                                     good_pkt,
      input                                     err_pkt,
      input [SEQ_NO_WIDTH - 1:0]                seq_no,
      input                                     seq_no_valid,
      input                                     done,
      input                                     pass,
      input                                     locked,
      input [2:0]                               src_port,

      //-- misc
      input                                     clk,
      input                                     reset
   );

   // ===========================================
   // Local variables

   reg [31:0] err_cnt;
   reg [31:0] good_cnt;

   reg local_locked;
   reg [2:0] local_src_port;

   reg reset_err;
   reg reset_good;

   reg reg_acked;

   reg active_d1;



   // =====================================================
   // Process register requests
   always @(posedge clk)
   begin
      // Reset the register group
      if (reset) begin
         reg_acked <= 1'b0;
         reset_err <= 1'b0;
         reset_good <= 1'b0;
         reg_acked <= 1'b0;
      end
      else begin
         // Process register requests
         if (reg_req) begin
            // Ack the request if the request is new
            if (!reg_acked) begin
               reg_ack <= 1'b1;

               // Work out which register is being accessed
               case ({{(`PHY_TEST_REG_ADDR_WIDTH - REG_ADDR_WIDTH){1'b0}}, reg_addr})
                  `PHY_TEST_PHY_RX_STATUS - `PHY_TEST_PHY_RX_STATUS : begin
                     reg_rd_data <= {8'b0, 5'b0, local_src_port, 3'b0, seq_no_valid, 3'b0, local_locked, 3'b0, pass, 3'b0, done};
                  end

                  `PHY_TEST_PHY_RX_GOOD_PKT_CNT - `PHY_TEST_PHY_RX_STATUS : begin
                     reg_rd_data <= good_cnt;
                  end

                  `PHY_TEST_PHY_RX_ERR_PKT_CNT - `PHY_TEST_PHY_RX_STATUS : begin
                     reg_rd_data <= err_cnt;
                  end

                  `PHY_TEST_PHY_RX_SEQ_NO - `PHY_TEST_PHY_RX_STATUS : begin
                     reg_rd_data <= seq_no;
                  end

                  `PHY_TEST_PHY_RX_CTRL - `PHY_TEST_PHY_RX_STATUS : begin
                     reg_rd_data <= 'h0;

                     // Handle the write if appropriate
                     if (!reg_rd_wr_L) begin
                        reset_good <= reg_wr_data[`PHY_TEST_PHY_RX_CTRL_RESET_GOOD_POS];
                        reset_err <= reg_wr_data[`PHY_TEST_PHY_RX_CTRL_RESET_ERR_POS];
                     end
                  end

                  default : begin
                     reg_rd_data <= 'h dead_beef;
                  end
               endcase
            end
            else begin
               reg_ack <= 1'b0;
               reset_good <= 1'b0;
               reset_err <= 1'b0;
            end

            // Record that we've processed this request
            reg_acked <= 1'b1;
         end
         else begin
            reg_acked <= 1'b0;
            reg_ack <= 1'b0;
            reset_good <= 1'b0;
            reset_err <= 1'b0;
         end
      end
   end



   // =====================================================
   // Process packet done events and
   // latch the local variables if we are active
   always @(posedge clk)
   begin
      if (reset || active && !active_d1) begin
         good_cnt <= 'h0;
         err_cnt <= 'h0;

         local_locked <= 1'b0;
         local_src_port <= 'h0;
      end
      else if (active) begin
         // Increment the packet counter
         if (reset_good)
            good_cnt <= 'h0;
         else if (good_pkt)
            good_cnt <= good_cnt + 'h1;

         // Increment the iteration counter
         if (reset_err)
            err_cnt <= 'h0;
         else if (err_pkt)
            err_cnt <= err_cnt + 'h1;

         local_locked <= locked;
         local_src_port <= src_port;
      end

      active_d1 <= active;
   end


endmodule // phy_test_rx_reg
