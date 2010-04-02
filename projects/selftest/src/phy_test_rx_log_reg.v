///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: phy_test_rx_log_reg.v 5971 2010-03-06 06:44:56Z grg $
//
// Module: phy_test_reg.v
// Project: NetFPGA
// Description: Selftest module for Ethernet Phys.
//
// Maintains the log registers for a single RX source
//
///////////////////////////////////////////////////////////////////////////////


module phy_test_rx_log_reg #(parameter
      REG_ADDR_WIDTH = 5
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
      input [31:0]                              log_rx_data,
      input [31:0]                              log_exp_data,
      input [8:0]                               log_addr,
      input                                     log_data_wr,
      input                                     log_done,      // Indicates this is the last word of the packet
      input                                     log_hold,      // Indicates that the log entry should be held

      input                                     restart,


      //-- misc
      input                                     clk,
      input                                     reset
   );

   // Register addresses
   localparam RX_LOG_STATUS_reg  = 5'h 00;
   localparam RX_LOG_EXP_DATA_reg= 5'h 04;
   localparam RX_LOG_RX_DATA_reg = 5'h 08;
   localparam RX_LOG_CTRL_reg    = 5'h 0c;

   // ===========================================
   // Local variables


   reg [8:0] log_depth;
   reg log_full;
   reg log_lock;

   reg [8:0] rd_exp_addr;
   reg [8:0] rd_rx_addr;

   reg reg_acked;

   wire [31:0] rd_exp_data;
   wire [31:0] rd_rx_data;
   wire [8:0] rd_addr;

   reg reset_log;




   // =====================================================
   // Process register requests
   always @(posedge clk)
   begin
      // Reset the register group
      if (reset) begin
         reg_acked <= 1'b0;
         reset_log <= 1'b0;
      end
      else begin
         // Process register requests
         if (reg_req) begin
            // Ack the request if the request is new
            if (!reg_acked) begin
               reg_ack <= 1'b1;

               // Work out which register is being accessed
               case ({{(`PHY_TEST_REG_ADDR_WIDTH - REG_ADDR_WIDTH){1'b0}}, reg_addr})
                  `PHY_TEST_PHY_RX_LOG_STATUS - `PHY_TEST_PHY_RX_LOG_STATUS : begin
                     reg_rd_data <= {15'b0, log_depth, 7'b0, log_full};
                  end

                  `PHY_TEST_PHY_RX_LOG_EXP_DATA - `PHY_TEST_PHY_RX_LOG_STATUS : begin
                     if (!log_full || rd_exp_addr == log_depth)
                        reg_rd_data <= 'h0;
                     else
                        reg_rd_data <= rd_exp_data;
                  end

                  `PHY_TEST_PHY_RX_LOG_RX_DATA - `PHY_TEST_PHY_RX_LOG_STATUS : begin
                     if (!log_full || rd_rx_addr == log_depth)
                        reg_rd_data <= 'h0;
                     else
                        reg_rd_data <= rd_rx_data;
                  end

                  `PHY_TEST_PHY_RX_LOG_CTRL - `PHY_TEST_PHY_RX_LOG_STATUS : begin
                     reg_rd_data <= 'h0;

                     // Handle the write if appropriate
                     if (!reg_rd_wr_L) begin
                        reset_log <= reg_wr_data[`PHY_TEST_PHY_RX_LOG_CTRL_RESET_POS];
                     end
                  end

                  default : begin
                     reg_rd_data <= 'h dead_beef;
                  end
               endcase
            end
            else begin
               reg_ack <= 1'b0;
               reset_log <= 1'b0;
            end

            // Record that we've processed this request
            reg_acked <= 1'b1;
         end
         else begin
            reg_acked <= 1'b0;
            reg_ack <= 1'b0;
            reset_log <= 1'b0;
         end
      end
   end



   // =====================================================
   // process packet done events and
   // latch the local variables if we are active
   always @(posedge clk)
   begin
      if (reset || restart) begin
         rd_exp_addr <= 'h0;
         rd_rx_addr <= 'h0;

         log_depth <= 'h0;
         log_full <= 1'b0;
         log_lock <= 1'b0;
      end
      else begin
         // Handle register reads
         if (reg_req && !reg_acked && reg_rd_wr_L && log_full) begin
            if (reg_addr == `PHY_TEST_PHY_RX_LOG_EXP_DATA&&
                rd_exp_addr != log_depth)
               rd_exp_addr <= rd_exp_addr + 'h1;

            if (reg_addr == `PHY_TEST_PHY_RX_LOG_RX_DATA &&
                rd_rx_addr != log_depth)
               rd_rx_addr <= rd_rx_addr + 'h1;
         end
         else if (reset_log) begin
               rd_exp_addr <= 'h0;
               rd_rx_addr <= 'h0;
         end

         // Update the full flag and lock flags
         if (!log_lock && log_hold) begin
            log_full <= 1'b1;
            log_depth <= log_addr + 'h1;
            log_lock <= 1'b1;
         end
         else if (log_full && reset_log) begin
            log_full <= 1'b0;
            log_depth <= 'h0;
            log_lock <= !log_done;
         end
         else if (log_lock && !log_full) begin
            log_lock <= !log_done;
         end

      end
   end



   // =====================================================
   // Instantiate a pair of RAMs for the expected and rx logs
   phy_test_ram_32x512 exp_log(
	.addra    (log_addr),
	.dina     (log_exp_data),
	.wea      (log_data_wr && !log_lock),
	.addrb    (rd_exp_addr),
	.doutb    (rd_exp_data),
	.clka     (clk),
	.clkb     (clk)
     );

   phy_test_ram_32x512 rx_log(
	.addra    (log_addr),
	.dina     (log_rx_data),
	.wea      (log_data_wr && !log_lock),
	.addrb    (rd_rx_addr),
	.doutb    (rd_rx_data),
	.clka     (clk),
	.clkb     (clk)
     );

endmodule // phy_test_rx_log_reg
