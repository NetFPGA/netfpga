///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: phy_test_reg.v 5971 2010-03-06 06:44:56Z grg $
//
// Module: phy_test_reg.v
// Project: NetFPGA
// Description: Selftest module for Ethernet Phys.
//
// Maintains the global registers for all phy tests
//
///////////////////////////////////////////////////////////////////////////////


module phy_test_reg #(parameter
      REG_ADDR_WIDTH = `PHY_TEST_REG_ADDR_WIDTH - 1,
      NUM_PATTERNS = 5,
      SEQ_NO_WIDTH = 32
   )
   (
      // Register interface signals
      input                                     reg_req,
      input                                     reg_rd_wr_L,    // 1 = read, 0 = write
      input [REG_ADDR_WIDTH - 1:0]              reg_addr,
      input [`CPCI_NF2_DATA_WIDTH - 1:0]        reg_wr_data,

      output reg                                reg_ack,
      output reg [`CPCI_NF2_DATA_WIDTH -1:0]    reg_rd_data,

      // Test interface
      input                                     done,
      input                                     good,
      input                                     busy,
      output reg                                start,
      output                                    mac_reset,

      output reg [NUM_PATTERNS - 1:0]           pat_en,
      output reg [SEQ_NO_WIDTH - 1:0]           init_seq_no,
      output reg [10:0]                         size,

      //-- misc
      input                                     clk,
      input                                     reset
   );

   // Local parameters
   localparam DEFAULT_SIZE       = 'd1514;

   // ------------- Local storage ------------------

   reg reg_acked;

   reg test_start;
   reg test_repeat;

   reg [9:0] mac_reset_delayed;

   // =====================================================
   // Process register requests
   always @(posedge clk)
   begin
      // Reset the register group
      if (reset) begin
         reg_acked <= 1'b0;

         test_start <= 1'b1;
         test_repeat <= 1'b0;
         pat_en <= {NUM_PATTERNS{1'b1}};
         init_seq_no <= 'h1;
         size <= DEFAULT_SIZE;
      end
      else begin
         // Process register requests
         if (reg_req) begin
            // Ack the request if the request is new
            if (!reg_acked) begin
               reg_ack <= 1'b1;

               // Work out which register is being accessed
               case ({{(`PHY_TEST_REG_ADDR_WIDTH - REG_ADDR_WIDTH){1'b0}}, reg_addr})
                  `PHY_TEST_STATUS: begin
                     reg_rd_data <= {16'b0, 7'b0, good, 3'b0, done, 3'b0, busy};
                  end

                  `PHY_TEST_CTRL: begin
                     reg_rd_data <= {30'b0, test_repeat, 1'b0};

                     // Handle the write if appropriate
                     if (!reg_rd_wr_L) begin
                        test_start <= reg_wr_data[`PHY_TEST_CTRL_START_POS];
                        test_repeat <= reg_wr_data[`PHY_TEST_CTRL_REPEAT_POS];
                     end
                  end

                  `PHY_TEST_SIZE: begin
                     reg_rd_data <= size;

                     // Handle the write if appropriate
                     if (!reg_rd_wr_L)
                        size <= reg_wr_data;
                  end

                  `PHY_TEST_PATTERN: begin
                     reg_rd_data <= pat_en;

                     // Handle the write if appropriate
                     if (!reg_rd_wr_L)
                        pat_en <= reg_wr_data;
                  end

                  `PHY_TEST_INIT_SEQ_NO: begin
                     reg_rd_data <= init_seq_no;

                     // Handle the write if appropriate
                     if (!reg_rd_wr_L)
                        init_seq_no <= reg_wr_data;
                  end

                  default : begin
                     reg_rd_data <= 'h dead_beef;
                  end
               endcase
            end
            else begin
               reg_ack <= 1'b0;
               test_start <= 1'b0;
            end

            // Record that we've processed this request
            reg_acked <= 1'b1;
         end
         else begin
            reg_acked <= 1'b0;
            reg_ack <= 1'b0;

            test_start <= 1'b0;
         end
      end
   end



   // Reset the ethernet MACs if reset is asserted or if we're
   // starting a test from the done state
   assign mac_reset = reset || ((test_start || test_repeat) && !busy && !(|mac_reset_delayed));

   always @(posedge clk) begin
      // Create a delayed mac_reset signal to allow time for the MACs to reset
      mac_reset_delayed <= {mac_reset_delayed[8:0], mac_reset};

      // Generate the actual start signal
      start <= (|mac_reset_delayed[9:4]) || (busy && test_repeat);
   end

endmodule // phy_test_reg
