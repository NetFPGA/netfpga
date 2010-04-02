///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: clk_test_reg.v 5541 2009-05-09 02:13:11Z g9coving $
//
// Module: clk_test_reg.v
// Project: NetFPGA
// Description: Selftest module for clock testing
//
// Counts clock ticks (nothing exciting)
//
// Resets the counter on reads
//
///////////////////////////////////////////////////////////////////////////////


module clk_test_reg
   (
      // Register interface signals
      input                                     reg_req,
      input                                     reg_rd_wr_L,    // 1 = read, 0 = write
      input [`CLOCK_TEST_REG_ADDR_WIDTH -1:0]   reg_addr,
      input [`CPCI_NF2_DATA_WIDTH -1:0]         reg_wr_data,

      output reg                                reg_ack,
      output reg [`CPCI_NF2_DATA_WIDTH -1:0]    reg_rd_data,

      //-- misc
      input                                     clk,
      input                                     reset
   );

   // ------------- Local storage ------------------

   reg reg_acked;

   reg [31:0] ticks;

   // =====================================================
   // Process register requests
   always @(posedge clk)
   begin
      // Reset the register group
      if (reset) begin
         reg_acked <= 1'b0;

         ticks <= 'h0;
      end
      else begin
         // Process register requests
         if (reg_req) begin
            // Ack the request if the request is new
            if (!reg_acked) begin
               reg_ack <= 1'b1;

               // Work out which register is being accessed
               case (reg_addr)
                  `CLOCK_TEST_TICKS : begin
                     reg_rd_data <= ticks;

                     // Reset the tick counter on a read
                     if (reg_rd_wr_L)
                        ticks <= 'h0;
                  end

                  default : begin
                     reg_rd_data <= 'h dead_beef;

                     ticks <= ticks + 'h1;
                  end
               endcase
            end
            else begin
               reg_ack <= 1'b0;

               ticks <= ticks + 'h1;
            end

            // Record that we've processed this request
            reg_acked <= 1'b1;
         end
         else begin
            reg_acked <= 1'b0;
            reg_ack <= 1'b0;

            ticks <= ticks + 'h1;
         end
      end
   end
endmodule // clk_test_reg
