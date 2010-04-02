///////////////////////////////////////////////////////////////////////////////
// $Id: selftest_result.v 1530 2007-03-24 16:46:02Z jnaous $
//
// Module: selftest_result.v
// Project: NetFPGA
// Description: Generate the results of the self-test.
//
// Note: Result: 1  -> Board good
//       Result: Steady blink -> Tests running
//       Result: 1 x Blink, long pause -> DRAM failed
//       Result: 2 x Blink, long pause -> SRAM failed
//       Result: 3 x Blink, long pause -> Ethernet failed
//
///////////////////////////////////////////////////////////////////////////////

module selftest_result(
   output reg result,              // Result of test

   input dram_done,                // DRAM test complete
   input dram_success,             // DRAM test sucess
   input sram_done,                // SRAM test complete
   input sram_success,             // SRAM test success
   input eth_done,                 // Ethernet test complete
   input eth_success,              // Ethernet test success
   input serial_done,              // Serial test complete
   input serial_success,           // Serial test success

   input clk,
   input reset
);

// Define the number of clock ticks per second (assume 125 MHz, but could be 62.5 MHz)
parameter ONE_SECOND = 125000000;
parameter HALF_SECOND = ONE_SECOND / 2;

reg [31:0] ticks;
reg [3 : 0] count, count_nxt;
reg result_nxt;


// =======================================================
// Keep track of time
//

always @(posedge clk)
begin
   if (reset)
      ticks <= HALF_SECOND - 'd1;
   else if (ticks == 'd0)
      ticks <= HALF_SECOND - 'd1;
   else
      ticks <= ticks - 'd1;
end



// =======================================================
// State machine to track self-test state
//

// Make sure TEST_PASS is the last item because the number of
// blinks is generated from the state
parameter TEST_RUN         = 4'd0;
parameter TEST_DRAM_FAIL   = 4'd1;
parameter TEST_SRAM_FAIL   = 4'd2;
parameter TEST_ETH_FAIL    = 4'd3;
parameter TEST_SERIAL_FAIL = 4'd4;
parameter TEST_PASS        = 4'd5;

reg [2:0] state;
wire [2:0] blinks = state;

always @(posedge clk)
begin
   if (reset)
      state <= TEST_RUN;
   else
      case (state)
         TEST_RUN :
         begin
            if (dram_done && dram_success &&
               sram_done && sram_success &&
               eth_done && eth_success &&
               serial_done && serial_success)
               state <= TEST_PASS;
            else if (dram_done && !dram_success)
               state <= TEST_DRAM_FAIL;
            else if (sram_done && !sram_success)
               state <= TEST_SRAM_FAIL;
            else if (eth_done && !eth_success)
               state <= TEST_ETH_FAIL;
            else if (serial_done && !serial_success)
               state <= TEST_SERIAL_FAIL;
         end

         TEST_DRAM_FAIL :
         begin
            // Should be a terminating state
            state <= TEST_DRAM_FAIL;
         end

         TEST_SRAM_FAIL :
         begin
            // Should be a terminating state
            state <= TEST_SRAM_FAIL;
         end

         TEST_ETH_FAIL :
         begin
            // Should be a terminating state
            state <= TEST_ETH_FAIL;
         end

         TEST_SERIAL_FAIL :
         begin
            // Should be a terminating state
            state <= TEST_SERIAL_FAIL;
         end

         TEST_PASS :
         begin
            // Should be a terminating state
            state <= TEST_PASS;
         end
      endcase
end


// =======================================================
// Control the blinking of the result signal
//

always @(posedge clk)
begin
   result <= result_nxt;
   count <= count_nxt;
end

always @*
begin
   // Initialize values to their current state
   result_nxt = result;
   count_nxt = count;

   if (reset)
   begin
      result_nxt = 1'b0;
      count = 'd0;
   end
   else if (state == TEST_PASS)
   begin
      result_nxt = 1'b1;
      count = 'd0;
   end
   else if (ticks == 'd0)
   begin
      count_nxt = count_nxt + 'd1;

      if (state != TEST_RUN)
      begin
         // Blink once
         if (count < blinks << 2)
            result_nxt = !count[0];
         // 2-sec pause
         else
            result_nxt = 1'b0;

         // Reset count after blinks and pause
         if (count == (blinks << 2) + 4 - 1)
            count_nxt = 1'b0;
      end
      else
         result_nxt = count[0];
   end
end



endmodule

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
