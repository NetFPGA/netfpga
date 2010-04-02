///////////////////////////////////////////////////////////////////////////////
// $Id: cpci_heartbeat.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: cpci_heartbeat.v
// Project: CPCI
// Description:
//              Implements the LED heartbeat
//
///////////////////////////////////////////////////////////////////////////////


module cpci_heartbeat

   (

    output reg heartbeat,

    input reset,
    input clk

    );

   // generate a much slower clock - 10 Hz

   parameter MAX_COUNT = 6250000;

   reg [23:0] ten_hertz_count;

   always @(posedge clk)
     if (reset) ten_hertz_count <= 'h0;
     else
       if (ten_hertz_count == MAX_COUNT) ten_hertz_count <= 'h0;
       else ten_hertz_count <= ten_hertz_count + 24'h1;


   reg 	      ten_hertz;

   always @(posedge clk)
     if (reset) ten_hertz <= 'h0;
     else ten_hertz <= (ten_hertz_count == MAX_COUNT) ? 1 : 0;


   // this is the slow counting counter

   reg [4:0]  slow_count;

   always @(posedge clk)
     if (reset) slow_count <= 'h0;
     else if (ten_hertz) begin
	if (slow_count == 20) slow_count <= 'h0;
	else                  slow_count <= slow_count + 'h1;
     end

   // Now generate hearbeat.

   reg 	      heartbeat_nxt;

   always @* begin
      heartbeat_nxt = 1;
      if (slow_count == 'd0 ) heartbeat_nxt = 0;
      if (slow_count == 'd2 ) heartbeat_nxt = 0;
      if (slow_count == 'd10) heartbeat_nxt = 0;
      if (slow_count == 'd12) heartbeat_nxt = 0;
   end

   always @(posedge clk) heartbeat <= heartbeat_nxt;

endmodule // cpci_heartbeat


