/***************************************************************************
 * Implements the calibration technique. performs the following functions:
 * 1. control circuit that determines each tap value
 * 2. hold the total delay value of different taps.
 * 3. determine the tap to use for a given frequency -> select the appropriate tap
 *
 ***************************************************************************/
`define idleSetup 4'b0000
`define idleD0 4'b0001
`define idleD1 4'b0010
`define idleD2 4'b0011
`define idleD3 4'b0100
`define idleD4 4'b0101
`define idleD5 4'b0110

`define waitSetup 4'b0111
`define waitDcmD0 4'b1000
`define waitDcmD1 4'b1001
`define waitDcmD2 4'b1010
`define waitDcmD3 4'b1011
`define waitDcmD4 4'b1100
`define waitDcmD5 4'b1101

`define idleDone 4'b1110

`define idleReset 1'b1
`define waitReset 1'b0
 `define lBound 8'b0011_0010 // 1000ps, = 1000ps/20 taps.
 `define uBound 8'b0101_0000 // 1600ps, = 1600ps/20 taps.
// `define lBound 8'b0001_0100 // for sims
// `define uBound 8'b0010_0000 // for sims
`define slipCnt 4'b1100

`define tap1 5'b00000
`define tap2 5'b10000
`define tap3 5'b11000
`define tap4 5'b11100
`define tap5 5'b11110
`define tap6 5'b11111
`define defaultTap `tap3

`timescale 1ns/100ps

module cal_ctl(
	       clk,
	       okToSelTap,
	       psDone,
	       reset,
	       hxSamp1,
	       phSamp1,
	       locReset,
	       selTap,
	       psEn,
	       psInc,
	       dcmlocked,
	       tapForDqs
	       );

   input         clk;
   input 	 dcmlocked;
   input 	 psDone;
   input 	 reset;
   input 	 hxSamp1;
   input 	 phSamp1;

   input 	 okToSelTap;

   output 	 locReset;
   output 	 psEn;
   output 	 psInc;
   output [4:0]  selTap;    /*  synthesis syn_keep = 1 */
   output [4:0]  tapForDqs; /*  synthesis syn_keep = 1 */

   reg 		 psEn;
   reg 		 psInc;
   reg [4:0] 	 selTap;
   reg [3:0] 	 state;
   reg [7:0] 	 posPhShft;
   reg [7:0] 	 negPhShft;
   reg 		 prevSamp;

   reg [7:0] 	 d0Shft;
   reg [7:0] 	 d1Shft;
   reg [7:0] 	 d2Shft;
   reg [7:0] 	 d3Shft;
   reg [7:0] 	 d4Shft;
   reg [7:0] 	 d5Shft;
   reg [7:0] 	 suShft;

   reg [4:0]	 tapForDqs;

   reg 		 waitOneCycle;
   reg 		 waitTwoCycle;
   reg 		 wait3Cycle;
   reg 		 wait4Cycle;
   reg 		 psDoneReg;
   reg 		 wait5Cycle;
   reg [7:0] 	 decPosSh;
   reg [7:0] 	 decNegSh;
   reg 		 rstate;
   reg 		 resetDcm;
   reg [4:0] 	 inTapForDqs;
   reg [3:0] 	 selCnt;
   reg [4:0] 	 newTap;
   reg 		 okSelCnt;
   reg [3:0] 	 midPt;
   reg [2:0] 	 uPtr;
   reg [2:0] 	 lPtr;

   reg [7:0] 	 ozShft;
   reg [7:0] 	 zoShft;

   wire      	 locReset;


   assign locReset = (~reset && dcmlocked) ? 1'b0 : 1'b1;


   always @(posedge clk) begin
      if (reset) begin
	 ozShft[7:0] <= 8'h00;
	 zoShft[7:0] <= 8'h00;
      end else begin
	 zoShft[7:0] <= suShft[7:0] - posPhShft[7:0];
	 ozShft[7:0] <= negPhShft[7:0]+ suShft[7:0];
      end
   end

   // 1. divide clock by 2 since there is no way to get from clock net to D input.
   // this is done outside in module cal_div2

   // 2. register normal clock with phClkDiv2 twice to prvent metastability.
   // done outside this block now.

   // 3. at offset of 0 between clkDiv2 and phSamp1, set up time may not be met.
   // increase the offset using phase shift to meet the set up time. the number of
   // phase shifts required to meet set up is determined.
   always @(posedge clk) begin
      if (reset) begin
	 psEn     <= 1'b0;
	 psInc    <= 1'b0;
	 state    <= `idleSetup;
	 prevSamp <= 1'b0;

	 posPhShft[7:0] <= 8'h00;
	 negPhShft[7:0] <= 8'h00;

	 d0Shft[7:0] <= 8'h00;
	 d1Shft[7:0] <= 8'h00;
	 d2Shft[7:0] <= 8'h00;
	 d3Shft[7:0] <= 8'h00;
	 d4Shft[7:0] <= 8'h00;
	 d5Shft[7:0] <= 8'h00;
	 suShft[7:0] <= 8'h00;

	 selTap[4:0] <= `tap1;
	 waitOneCycle <= 1'b1;
	 waitTwoCycle <= 1'b0;
	 wait3Cycle <= 1'b0;
	 wait4Cycle <= 1'b0;
	 wait5Cycle <= 1'b0;
	 psDoneReg <= 1'b0;
	 decPosSh[7:0] <= 8'h00;
	 decNegSh[7:0] <= 8'h00;
	 resetDcm <= 1'b0;
	 rstate <= `idleReset;
      end else begin // if (!reset)
	 psDoneReg <= psDone;
	 if (dcmlocked) begin
	    if (resetDcm) begin
	       if (rstate == `idleReset) begin
		  if (posPhShft[7:0] != decPosSh[7:0]) begin
		     psEn          <= 1'b1;
		     psInc         <= 1'b0;
		     decPosSh[7:0] <= decPosSh[7:0] + 1'b1;
		     rstate        <= `waitReset;
		  end else if (negPhShft[7:0] != decNegSh[7:0]) begin
		     psEn          <= 1'b1;
		     psInc         <= 1'b1;
		     decNegSh[7:0] <= decNegSh[7:0] + 1'b1;
		     rstate        <= `waitReset;
		  end else begin
		     resetDcm       <= 1'b0;
		     posPhShft[7:0] <= 8'h00;
		     negPhShft[7:0] <= 8'h00;
		     decNegSh[7:0]  <= 8'h00;
		     decPosSh[7:0]  <= 8'h00;
		  end
	       end else if (rstate == `waitReset) begin
		  psEn <= 1'b0;
		  if (psDoneReg) rstate <= `idleReset;
		  else rstate           <= `waitReset;
	       end

	    end else begin // if (resetDcm)

	       if (waitOneCycle) begin
		  waitOneCycle <= 1'b0;
		  waitTwoCycle <= 1'b1;
	       end else if (waitTwoCycle) begin
		  waitTwoCycle <= 1'b0;
		  wait3Cycle <= 1'b1;
	       end else if (wait3Cycle) begin
		  wait3Cycle <= 1'b0;
		  wait4Cycle <= 1'b1;
	       end else if (wait4Cycle) begin
	          wait4Cycle <= 1'b0;
		  wait5Cycle <= 1'b1;
	       end else if (wait5Cycle) begin
		  wait5Cycle <= 1'b0;
		  if (state == `idleSetup) prevSamp <= phSamp1;
		  else prevSamp <= hxSamp1;
	       end else begin
		  if (state == `idleSetup) begin
		     if ((phSamp1 == 1'b1) && (prevSamp == 1'b0))begin // 0 to 1 transition
			suShft[7:0] <= posPhShft[7:0];
			state        <= `idleD0;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
			waitOneCycle <= 1'b1;
		     end else if ((phSamp1 == 1'b0) && (prevSamp == 1'b1)) begin // shd never happen
			suShft[7:0] <= negPhShft[7:0];
			state        <= `idleD0;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
			waitOneCycle <= 1'b1;
		     end else if ((phSamp1 == 1'b0) && (prevSamp == 1'b0))begin
			//increment shift
			psEn     <= 1'b1;
			psInc    <= 1'b1;
			state    <= `waitSetup;
			prevSamp <= 1'b0;
		     end else if ((phSamp1 == 1'b1) && (prevSamp == 1'b1))begin
			psEn     <= 1'b1;
			psInc    <= 1'b0;
			prevSamp <= 1'b1;
			state    <= `waitSetup;
		     end
		  end else if (state == `waitSetup)begin // if (state == `idleSetup)
		     psEn <= 1'b0;
		     if (psDoneReg)  state <= `idleSetup;
		  end else if (state == `idleD0) begin
		     if ((hxSamp1 == 1'b1) && (prevSamp == 1'b0)) begin
			d0Shft[7:0]  <= zoShft;
			selTap[4:0]  <= `tap2;
			waitOneCycle <= 1'b1;
			state        <= `idleD1;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b1) ) begin
			d0Shft[7:0]  <= ozShft;
			selTap[4:0]  <= `tap2;
			waitOneCycle <= 1'b1;
			state        <= `idleD1;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b0)) begin
			// increment phase shift delay
			psEn     <= 1'b1;
			psInc    <= 1'b1;
			state    <= `waitDcmD0;
			prevSamp <= 1'b0;
		     end else if ((hxSamp1 == 1'b1) && (prevSamp == 1'b1)) begin
			// decrement variable delay
			psEn     <= 1'b1;
			psInc    <= 1'b0;
			state    <= `waitDcmD0;
			prevSamp <= 1'b1;
		     end
 		  end else if (state == `waitDcmD0) begin
		     psEn <= 1'b0;
		     if (psDoneReg) begin
			state <= `idleD0;
		     end
		  end else if (state == `idleD1) begin
		     if ((hxSamp1 == 1'b1) && (prevSamp == 1'b0)) begin
			d1Shft[7:0]  <= zoShft[7:0];
			selTap[4:0]  <= `tap3;
			waitOneCycle <= 1'b1;
			state        <= `idleD2;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b1) ) begin
			d1Shft[7:0]  <= ozShft;
			selTap[4:0]  <= `tap3;
			waitOneCycle <= 1'b1;
			state        <= `idleD2;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b0)) begin
			// increment phase shift delay
			psEn     <= 1'b1;
			psInc    <= 1'b1;
			state    <= `waitDcmD1;
			prevSamp <= 1'b0;
		     end else if ((hxSamp1 == 1'b1) && (prevSamp == 1'b1)) begin
			// decrement variable delay
			psEn     <= 1'b1;
			psInc    <= 1'b0;
			state    <= `waitDcmD1;
			prevSamp <= 1'b1;
		     end
 		  end else if (state == `waitDcmD1) begin
		     psEn <= 1'b0;
		     if (psDoneReg) begin
			state <= `idleD1;
		     end

		  end else if (state == `idleD2) begin
		     if ((hxSamp1 == 1'b1) && (prevSamp == 1'b0)) begin
			d2Shft[7:0]  <= zoShft[7:0];
			selTap[4:0]  <= `tap4;
			waitOneCycle <= 1'b1;
			state        <= `idleD3;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b1) ) begin
			d2Shft[7:0]  <= ozShft[7:0];
			selTap[4:0]  <= `tap4;
			waitOneCycle <= 1'b1;
			state        <= `idleD3;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b0)) begin
			// increment phase shift delay
			psEn     <= 1'b1;
			psInc    <= 1'b1;
			state    <= `waitDcmD2;
			prevSamp <= 1'b0;
		     end else if ((hxSamp1 == 1'b1) && (prevSamp == 1'b1)) begin
			// decrement variable delay
			psEn     <= 1'b1;
			psInc    <= 1'b0;
			state    <= `waitDcmD2;
			prevSamp <= 1'b1;
		     end
 		  end else if (state == `waitDcmD2) begin
		     psEn <= 1'b0;
		     if (psDoneReg) begin
			state <= `idleD2;
		     end

		  end else if (state == `idleD3) begin
		     if ((hxSamp1 == 1'b1) && (prevSamp == 1'b0)) begin
			d3Shft[7:0]  <= zoShft[7:0];
			selTap[4:0]  <= `tap5;
			waitOneCycle <= 1'b1;
			state        <= `idleD4;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b1) ) begin
			d3Shft[7:0]  <= ozShft[7:0];
			selTap[4:0]  <= `tap5;
			waitOneCycle <= 1'b1;
			state        <= `idleD4;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b0)) begin
			// increment phase shift delay
			psEn     <= 1'b1;
			psInc    <= 1'b1;
			state    <= `waitDcmD3;
			prevSamp <= 1'b0;
		     end else if ((hxSamp1 == 1'b1) && (prevSamp == 1'b1)) begin
			// decrement variable delay
			psEn     <= 1'b1;
			psInc    <= 1'b0;
			state    <= `waitDcmD3;
			prevSamp <= 1'b1;
		     end
 		  end else if (state == `waitDcmD3) begin
		     psEn <= 1'b0;
		     if (psDoneReg) begin
			state <= `idleD3;
		     end

		  end else if (state == `idleD4) begin
		     if ((hxSamp1 == 1'b1) && (prevSamp == 1'b0)) begin
			d4Shft[7:0]  <= zoShft[7:0];
			selTap[4:0]  <= `tap6;
			waitOneCycle <= 1'b1;
			state        <= `idleD5;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b1) ) begin
			d4Shft[7:0]  <= ozShft[7:0];
			selTap[4:0]  <= `tap6;
			waitOneCycle <= 1'b1;
			state        <= `idleD5;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b0)) begin
			// increment phase shift delay
			psEn     <= 1'b1;
			psInc    <= 1'b1;
			state    <= `waitDcmD4;
			prevSamp <= 1'b0;
		     end else if ((hxSamp1 == 1'b1) && (prevSamp == 1'b1)) begin
			// decrement variable delay
			psEn     <= 1'b1;
			psInc    <= 1'b0;
			state    <= `waitDcmD4;
			prevSamp <= 1'b1;
		     end
 		  end else if (state == `waitDcmD4) begin
		     psEn <= 1'b0;
		     if (psDoneReg) begin
			state <= `idleD4;
		     end
		  end else if (state == `idleD5) begin
		     if ((hxSamp1 == 1'b1) && (prevSamp == 1'b0)) begin
			d5Shft[7:0]  <= zoShft[7:0];
			selTap[4:0]  <= `tap1;
			waitOneCycle <= 1'b1;
			state        <= `idleD0;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b1) ) begin
			d5Shft[7:0]  <= ozShft[7:0];
			selTap[4:0]  <= `tap1;
			waitOneCycle <= 1'b1;
			state        <= `idleD0;
			rstate       <= `idleReset;
			resetDcm     <= 1'b1;
		     end else if ((hxSamp1 == 1'b0) && (prevSamp == 1'b0)) begin
			// increment phase shift delay
			psEn     <= 1'b1;
			psInc    <= 1'b1;
			state    <= `waitDcmD5;
			prevSamp <= 1'b0;
		     end else if ((hxSamp1 == 1'b1) && (prevSamp == 1'b1)) begin
			// decrement variable delay
			psEn     <= 1'b1;
			psInc    <= 1'b0;
			state    <= `waitDcmD5;
			prevSamp <= 1'b1;
		     end
 		  end else if (state == `waitDcmD5) begin
		     psEn <= 1'b0;
		     if (psDoneReg) begin
			state <= `idleD5;
		     end
		     //end else if (state == `idleDone) begin
		  end
	       end // else: !if(wait4Cycle)

	    end // else: !if(resetDcm)


	    if (psDoneReg && rstate != `waitReset)
	      if (psInc) posPhShft[7:0] <= posPhShft[7:0] + 1'b1;
	      else negPhShft[7:0] <= negPhShft[7:0] + 1'b1;

	 end // if (dcmlocked)

      end // else: !if(reset)

   end // always @ (posedge clk)

   // Logic to figure out the number of tap delays to use for dqs
   // generate the output tapForDqs

   always @(posedge clk) begin
      if (reset) begin
	 lPtr[2:0] <= 3'b000;
	 uPtr[2:0] <= 3'b101;
	 tapForDqs[4:0] <= `defaultTap;
	 inTapForDqs[4:0] <= `defaultTap;
	 newTap <= `defaultTap;
	 midPt[3:0] <= 4'b0011;
	 okSelCnt <= 1'b0;
      end else begin
	 if (d0Shft[7:0] > `lBound) lPtr[2:0] <= 3'b000;
	 else if (d1Shft[7:0] > `lBound) lPtr[2:0] <= 3'b001;
	 else if (d2Shft[7:0] > `lBound) lPtr[2:0] <= 3'b010;
	 else if (d3Shft[7:0] > `lBound) lPtr[2:0] <= 3'b011;
	 else if (d4Shft[7:0] > `lBound) lPtr[2:0] <= 3'b100;
	 else lPtr[2:0] <= 3'b101;

	 if (d5Shft[7:0] < `uBound) uPtr[2:0] <= 3'b101;
	 else if (d4Shft[7:0] < `uBound) uPtr[2:0] <= 3'b100;
	 else if (d3Shft[7:0] < `uBound) uPtr[2:0] <= 3'b011;
	 else if (d2Shft[7:0] < `uBound) uPtr[2:0] <= 3'b010;
	 else if (d1Shft[7:0] < `uBound) uPtr[2:0] <= 3'b001;
	 else uPtr[2:0] <= 3'b000;

	 midPt[3:0] <= (uPtr[2:0] + lPtr[2:0]) ;

	 case (midPt[3:1])
	   3'b000: inTapForDqs[4:0] <= `tap1;
	   3'b001: inTapForDqs[4:0] <= `tap2;
	   3'b010: inTapForDqs[4:0] <= `tap3;
	   3'b011: inTapForDqs[4:0] <= `tap4;
	   3'b100: inTapForDqs[4:0] <= `tap5;
	   3'b101: inTapForDqs[4:0] <= `tap6;
	   default: inTapForDqs[4:0] <= inTapForDqs[4:0];
	 endcase // case(midPt[2:0])

	 // tap output shouldn't change unless the same tap value is selected n number of times.
	 newTap[4:0] <= inTapForDqs[4:0];
	 if (inTapForDqs[4:0] == newTap[4:0]) begin

	    if (wait4Cycle) selCnt[3:0] <= selCnt[3:0] + 1'b1;
	    if (selCnt[3:0] == `slipCnt) okSelCnt <= 1'b1;
	    else okSelCnt <= 1'b0;
	 end else begin
	    selCnt[3:0] <= 4'b0000;
	    okSelCnt <= 1'b0;
	 end

	 if (okToSelTap && okSelCnt) tapForDqs[4:0] <= newTap[4:0];

      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // cal_ctl




