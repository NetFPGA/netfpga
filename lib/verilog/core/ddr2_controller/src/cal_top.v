/**********************************************************************************
 * Top level for calibration circuit.
 *  - instantiate DCM, calib control, and ckt to calibrate
 *********************************************************************************/
`timescale 1ns/100ps

`define noMuxF5 1'b1


module cal_top(
	       clk,
	       clk0,
	       clk0dcmlock,
	       reset,
	       okToSelTap,
	       tapForDqs
               );

   input    clk;
   input    clk0;
   input 	  clk0dcmlock;
   input 	  reset;
   input 	  okToSelTap;

   output [4:0]   tapForDqs;

   wire 	  reset;
   wire 	  phShftClk;
   wire 	  phShftClkDcm;
   wire 	  psInc;
   wire 	  psEn;
   wire 	  dcmlocked;
   wire 	  psDone;
   wire 	  hexClk;
   wire 	  clkDiv2;
   wire 	  phClkDiv2;
   wire [4:0] 	  selTap;
   wire [4:0] 	  tapForDqs;
   wire [3:0] 	  state;
   wire 	  locReset;
   wire 	  hxSamp1;

   wire 	  clk0;//signals added for additional dcm
   wire    divRst;
   reg 	  fpga_rst;//


   // synopsys translate_off
   // Attributes for RTL simulation
   defparam cal_dcm.CLKOUT_PHASE_SHIFT = "VARIABLE" ;
   defparam cal_dcm.DLL_FREQUENCY_MODE = "LOW" ;
   defparam cal_dcm.PHASE_SHIFT = 128 ;
  // defparam cal_dcm.DUTY_CYCLE_CORRECTION = "TRUE" ;

//   defparam cal_dcm.CLKDV_DIVIDE = 4.0 ;
 //  defparam cal_dcm.CLKIN_DIVIDE_BY_2 = "FALSE" ;
   // synopsys translate_on

   DCM cal_dcm (
		.CLKIN(clk),                     // input clock
		.CLKFB(phShftClk),               // output clock
		.DSSEN(1'b0),
		.PSINCDEC(psInc),
		.PSEN(psEn),
		.PSCLK(clk0),
		.RST(~reset),   //changed from rstn
		.CLK0(phShftClkDcm),
		.CLK90(),
		.CLK180(),
		.CLK270(),
		.CLK2X(),
		.CLK2X180(),
		.CLKDV(),
		.CLKFX(),
		.CLKFX180(),
		.LOCKED(dcmlocked),
		.PSDONE(psDone),
		.STATUS())



    //synthesis attribute CLKOUT_PHASE_SHIFT of cal_dcm is "VARIABLE";
    //synthesis attribute DUTY_CYCLE_CORRECTION of cal_dcm is "TRUE";
    //synthesis attribute DLL_FREQUENCY_MODE of cal_dcm is "LOW";
    //synthesis attribute PHASE_SHIFT of cal_dcm is 128;

   ;

always @ (posedge clk0)
begin
  fpga_rst <= ~(reset & dcmlocked & clk0dcmlock);
end

assign   divRst = ~(dcmlocked && clk0dcmlock);


   BUFG phclk_bufg (.I(phShftClkDcm),
		    .O(phShftClk)
		    );

   cal_ctl cal_ctl0(
		    .clk (clk0),
		    .psDone(psDone),
		    .reset(fpga_rst),//changed from reset
		    .okToSelTap(okToSelTap),
		    .locReset(locReset),
		    .hxSamp1(hxSamp1),
		    .phSamp1(phSamp1),
		    .selTap(selTap[4:0]),
		    .psEn(psEn),
		    .psInc(psInc),
		    .dcmlocked(dcmlocked),
		    .tapForDqs(tapForDqs[4:0])
		    );


   cal_div2 cal_clkd2(
		      .reset (divRst),
		      .iclk(clk0),
		      .oclk(clkDiv2)
		      )/* synthesis syn_noprune = 1 */;


   cal_div2f cal_phClkd2(
			.reset(divRst),
			.iclk(phShftClk),
			.oclk(phClkDiv2)
			)/* synthesis syn_noprune = 1 */;



   cal_reg hxSampReg0(
		      .reset (fpga_rst), //changed from reset
		      .clk(hexClk),
		      .dInp(clkDiv2),
		      .iReg(hxSamp0),
		      .dReg(hxSamp1)
		      );


   cal_div2 cal_suClkd2(
			.reset (divRst),
			.iclk(clk0),
			.oclk(suClkDiv2)
			);



   cal_div2f cal_suPhClkd2(
			  .reset (divRst),
			  .iclk(phShftClk),
			  .oclk(suPhClkDiv2)
			  );


   cal_reg phSampReg0(
		      .reset (fpga_rst), //changed from reset
		      .clk(suPhClkDiv2),
		      .dInp(suClkDiv2),
		      .iReg(phSamp0),
		      .dReg(phSamp1)
		      );




   dqs_delay  ckt_to_cal
     //dqs_dly_sim ckt_to_cal
     (
      .clk_in (phClkDiv2),
      .sel_in(selTap[4:0]),
      .clk_out(hexClk)
      );



endmodule // cal_top








