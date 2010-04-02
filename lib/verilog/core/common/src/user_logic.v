//----------------------------------------------------------------------------
// user_logic.v - module
//----------------------------------------------------------------------------
//
// ***************************************************************************
// ** Copyright (c) 1995-2005 Xilinx, Inc.  All rights reserved.            **
// **                                                                       **
// ** Xilinx, Inc.                                                          **
// ** XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS"         **
// ** AS A COURTESY TO YOU, SOLELY FOR USE IN DEVELOPING PROGRAMS AND       **
// ** SOLUTIONS FOR XILINX DEVICES.  BY PROVIDING THIS DESIGN, CODE,        **
// ** OR INFORMATION AS ONE POSSIBLE IMPLEMENTATION OF THIS FEATURE,        **
// ** APPLICATION OR STANDARD, XILINX IS MAKING NO REPRESENTATION           **
// ** THAT THIS IMPLEMENTATION IS FREE FROM ANY CLAIMS OF INFRINGEMENT,     **
// ** AND YOU ARE RESPONSIBLE FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE      **
// ** FOR YOUR IMPLEMENTATION.  XILINX EXPRESSLY DISCLAIMS ANY              **
// ** WARRANTY WHATSOEVER WITH RESPECT TO THE ADEQUACY OF THE               **
// ** IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OR        **
// ** REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE FROM CLAIMS OF       **
// ** INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS       **
// ** FOR A PARTICULAR PURPOSE.                                             **
// **                                                                       **
// ** YOU MAY COPY AND MODIFY THESE FILES FOR YOUR OWN INTERNAL USE SOLELY  **
// ** WITH XILINX PROGRAMMABLE LOGIC DEVICES AND XILINX EDK SYSTEM OR       **
// ** CREATE IP MODULES SOLELY FOR XILINX PROGRAMMABLE LOGIC DEVICES AND    **
// ** XILINX EDK SYSTEM. NO RIGHTS ARE GRANTED TO DISTRIBUTE ANY FILES      **
// ** UNLESS THEY ARE DISTRIBUTED IN XILINX PROGRAMMABLE LOGIC DEVICES.     **
// **                                                                       **
// ***************************************************************************
//
//----------------------------------------------------------------------------
// Filename:          user_logic.v
// Version:           1.00.a
// Description:       User logic module.
// Date:              Thu Oct 27 09:06:38 2005 (by Create and Import Peripheral Wizard)
// Verilog Standard:  Verilog-2001
//----------------------------------------------------------------------------
// Naming Conventions:
//   active low signals:                    "*_n"
//   clock signals:                         "clk", "clk_div#", "clk_#x"
//   reset signals:                         "rst", "rst_n"
//   generics:                              "C_*"
//   user defined types:                    "*_TYPE"
//   state machine next state:              "*_ns"
//   state machine current state:           "*_cs"
//   combinatorial signals:                 "*_com"
//   pipelined or register delay signals:   "*_d#"
//   counter signals:                       "*cnt*"
//   clock enable signals:                  "*_ce"
//   internal version of output port:       "*_i"
//   device pins:                           "*_pin"
//   ports:                                 "- Names begin with Uppercase"
//   processes:                             "*_PROCESS"
//   component instantiations:              "<ENTITY_>I_<#|FUNC>"
//----------------------------------------------------------------------------

module user_logic
(
  // -- ADD USER PORTS BELOW THIS LINE ---------------
  // --USER ports added here
  // -- ADD USER PORTS ABOVE THIS LINE ---------------

  // -- DO NOT EDIT BELOW THIS LINE ------------------
  // -- Bus protocol ports, do not add to or delete
  Bus2IP_Clk,                     // Bus to IP clock
  Bus2IP_Reset,                   // Bus to IP reset
  Bus2IP_Addr,                    // Bus to IP address bus
  Bus2IP_RNW,                     // Bus to IP read/not write
  IP2Bus_Ack,                     // IP to Bus acknowledgement
  IP2Bus_Retry,                   // IP to Bus retry response
  IP2Bus_Error,                   // IP to Bus error response
  IP2Bus_ToutSup,                 // IP to Bus timeout suppress
  Bus2IP_ArData,                  // Bus to IP data bus for address ranges
  Bus2IP_ArBE,                    // Bus to IP byte enables for address ranges
  Bus2IP_ArCS,                    // Bus to IP chip select for address ranges
  IP2Bus_ArData                   // IP to Bus data bus for address ranges
  // -- DO NOT EDIT ABOVE THIS LINE ------------------
); // user_logic

// -- ADD USER PARAMETERS BELOW THIS LINE ------------
// --USER parameters added here

// SRAM is 512K x 36 bits, so 19 bits of address.
parameter SRAM_ADDR_WIDTH = 19;
parameter SRAM_DATA_WIDTH = 36;
// But we CANT USE THESE BECAUSE XST IS BROKEN!!!!!

// -- ADD USER PARAMETERS ABOVE THIS LINE ------------

// -- DO NOT EDIT BELOW THIS LINE --------------------
// -- Bus protocol parameters, do not add to or delete
parameter C_AWIDTH                       = 32;
parameter C_MAX_AR_DWIDTH                = 32;
parameter C_NUM_ADDR_RNG                 = 1;
// -- DO NOT EDIT ABOVE THIS LINE --------------------

// -- ADD USER PORTS BELOW THIS LINE -----------------
// --USER ports added here
// -- ADD USER PORTS ABOVE THIS LINE -----------------

// -- DO NOT EDIT BELOW THIS LINE --------------------
// -- Bus protocol ports, do not add to or delete
input                                     Bus2IP_Clk;
input                                     Bus2IP_Reset;
input      [0 : C_AWIDTH-1]               Bus2IP_Addr;
input                                     Bus2IP_RNW;
output                                    IP2Bus_Ack;
output                                    IP2Bus_Retry;
output                                    IP2Bus_Error;
output                                    IP2Bus_ToutSup;
input      [0 : C_MAX_AR_DWIDTH-1]        Bus2IP_ArData;
input      [0 : C_MAX_AR_DWIDTH/8-1]      Bus2IP_ArBE;
input      [0 : C_NUM_ADDR_RNG-1]         Bus2IP_ArCS;
output     [0 : C_MAX_AR_DWIDTH-1]        IP2Bus_ArData;
// -- DO NOT EDIT ABOVE THIS LINE --------------------

//----------------------------------------------------------------------------
// Implementation
//----------------------------------------------------------------------------


   /*

    Description
    ===========

    This implements an interface between the OPB on one side, and the NetFPGA2
    SRAM on the other. It is needed because the NetFPGA-1G SRAMs dont support Byte Write enables.
    So if the CPU does a byte write or short write (16 bits) then this module
    will do a read-modify-write to emulate support for byte write enables.
    It assumes accesses are aligned (see operation below). If operations are
    not aligned (word or short accesses) then this module will assert both
    IP2Bus_Ack and IP2Bus_Error, indicating a bus error.

    Operation:
    ==========

    For uBlaze, accesses must be aligned. (bytes on any byte boundary,
    half-words on halfword boundar (0,2,4,...) and words on word boundary
    (0,4,8,...)

    READS:

    Take the address on Bus2IP_Addr[] and  set Least Sig 2 bits to zero
    (because we only do word accesses).
    Read that word from memory and return the full 32 bits to the OPB.
    The byte steering logic within the IPIF will extract the correct data
    in the case of a byte or 16-bit access (i.e. this module doesn't need to do it)

    WRITES:

    Bytes: Bytes will be in correct byte location. use BE to decide which
           bytes are written:

    ADDR:  XXXXXXX0  XXXXXXX1  XXXXXXX2  XXXXXXX3

    DATA:  DDxxxxxx  xxDDxxxx  xxxxDDxx  xxxxxxDD  (big endian)

    BE[0:3] 1000       0100       0010     0001


    Half-words (shorts, or 16 bits)

    ADDR:  XXXXXXX0  XXXXXXX2

    DATA:  DDDDxxxx  xxxxDDDD

    BE[0:3] 1100       0011


    Words: Addr = XXXXXXX0 DATA: DDDDDDDD  BE[0:3] = 1111


    Note: ArCS not necessarily valid for the entire cycle so latch BE, Addr,
    Data when CS high.

    ToutSup is TImeout suppress - need to assert this if we cant Ack
    within 8 cycles of CS asserted.

    */

  // --USER nets declarations added here, as needed for user logic


  // --USER logic implementation added here

  // ------------------------------------------------------------
  // Example code to drive IP to Bus signals  assign IP2Bus_ArData      = (IP2Bus_Ack & Bus2IP_RNW) ? 32'h01020304 : 32'h0;


  // ------------------------------------------------------------

   reg  IP2Bus_Error, IP2Bus_Error_nxt;

   assign IP2Bus_Retry       = 0;
   assign IP2Bus_ToutSup     = 0;

//   wire [SRAM_DATA_WIDTH-1 : 0] sram_rd_data_pin;
   wire [35 : 0] sram_rd_data_pin;
//   reg [SRAM_DATA_WIDTH-1 : 0] 	sram_wr_data_pin;
   reg [35 : 0]  sram_wr_data_pin;
   reg [C_MAX_AR_DWIDTH-1 : 0] wr_data, wr_data_nxt, rmw_data;
   reg [18 : 0] 	       sram_addr_pin;
//   reg [SRAM_ADDR_WIDTH-1 : 0] 	sram_addr_pin;
   reg 				sram_data_tri_en_pin;
   reg 				tri_en_nxt;
   reg 				sram_we_bw_pin;
   reg 				we_bw_nxt; // Active low. 0=write
   reg [0:3] 			my_BE;
   reg 				IP2Bus_Ack, ack_nxt;
   reg 				load_rd_data;
   reg 				rmw, rmw_nxt;
   reg 				load_addr_BE;   // strobe to load Addr and BE

   // Bus error if short or word accesses are not aligned.
   // SHort access: bit 31 of address MUST be 0.
   // Word access: bits 30 and 31 of address MUST be 0.
   wire alignment_error = (
			   ( (Bus2IP_ArBE == 4'h3) || (Bus2IP_ArBE == 4'hc) ) &&
			   Bus2IP_Addr[31]
			  ) ||
	                  ( (Bus2IP_ArBE == 4'hf) &&
	                  (Bus2IP_Addr[30] || Bus2IP_Addr[31])
	                  );


   // State machine

   reg [2:0] state, state_ns;  // state and next_state

   // cant use parameter here cos XST is broken!
`define IDLE 0
`define WAIT_READ_1 1
`define WAIT_READ_2 2
`define WAIT_READ_VALID 3
`define RMW_DATA 4
`define WAIT_WRITE_1 5
`define WAIT_WRITE_2 6
`define WAIT 7


   always @* begin

      // set defaults here

      state_ns     = state;
      tri_en_nxt   = 0;  // Dont enable our data drivers.
      we_bw_nxt    = 1;  // Default is read. (we_bw is active low)
      load_rd_data = 0;  // assert this when SRAM rd data is valid
      ack_nxt      = 0;
      rmw_nxt      = rmw; // keeps track of whether we are doing RMW cycle.
      wr_data_nxt  = wr_data;
      load_addr_BE = 0;
      IP2Bus_Error_nxt = 0;

      case (state)

	`IDLE: begin

	   rmw_nxt     = 0;
	   wr_data_nxt = 'h0;

	   // Sit here until we get selected with CS.
	   if (Bus2IP_ArCS) begin

	      if (alignment_error) begin
		 IP2Bus_Error_nxt = 1;
		 ack_nxt = 1;
		 state_ns = `WAIT;
	      end

	      else
		begin

		   load_addr_BE = 1;

		   // A read will happen automatically as that is the default
		   // behaviour. So if it's a READ then just wait for the data.

		   if (Bus2IP_RNW) state_ns = `WAIT_READ_1;

		   // But if it's a write then we need to check the Byte enables:
		   // If it's a word write we can do the write.
		   // If it's a half-word or byte write then we need to do a
		   // Read-Modify-Write.

		   else     // WRITE
		     begin
			wr_data_nxt = Bus2IP_ArData; // save it!

			if (Bus2IP_ArBE == 4'hf) begin // word write
			   we_bw_nxt   = 0;
			   state_ns    = `WAIT_WRITE_1;
			end
			else  begin // RMW: do READ first then WRITE
			   rmw_nxt  = 1;
			   state_ns = `WAIT_READ_1;
			end
		     end

		end // else: !if(alignment_error)

	   end

	end // case: IDLE


	`WAIT_READ_1: begin
	   state_ns = `WAIT_READ_2;
	   if (IP2Bus_Error) begin
	      ack_nxt = 1;
	      state_ns = `WAIT;
	   end
	end


	`WAIT_READ_2: state_ns = `WAIT_READ_VALID;

	// load the read data and assert ACK on next cycle.

	`WAIT_READ_VALID: begin

	   load_rd_data = 1;  // store the read data from SRAM.

	   // If we were doing a RMW cycle then we need to
	   // start the WRITE cycle now.
	   if (rmw) begin
	      we_bw_nxt = 0;
	      state_ns  = `RMW_DATA;
	   end

	   // Otherwise we just finish up the READ cycle and ack.
	   else begin
	      ack_nxt      = 1;
	      state_ns     = `WAIT;
	   end
	end


	`RMW_DATA: begin
	   wr_data_nxt = rmw_data;
	   state_ns    = `WAIT_WRITE_2;
	end


	`WAIT_WRITE_1: begin
	   state_ns = `WAIT_WRITE_2;
	   if (IP2Bus_Error) begin
	      ack_nxt = 1;
	      state_ns = `WAIT;
	   end
	end

	`WAIT_WRITE_2: begin
	   tri_en_nxt = 1;   // enable data next clock.
	   // DOnt ack writes - I think they are posted.
	   // ack_nxt    = 1;
	   state_ns   = `IDLE;
	end

	// Wait here for one clock while ACK is asserted. THis gives
	// the IPIF time to deassert CS.

	`WAIT:
	  state_ns = `IDLE;


	default: begin
	   // synthesis translate_off
	   if ($time > 20000) begin
	      $display("%t ERROR: %m state in bad state: 0x%x", $time, state);
	      #10 $finish;
	   end
	   // synthesis translate_on
	   state_ns = `IDLE;
	end

      endcase

   end // always @ *


   // Generate the RMW data.
   // The new write data is in wr_data and byte enables in my_BE.
   // The original data in the RAM is in IP2Bus_ArData (for just one cycle!)
   // ALSO ... watch out that bit orderings are different - Xilinx seems to
   // like ordering registers from 0:max  rather than max:0

   always @* begin
      rmw_data = { (my_BE[0] ? wr_data[31:24] : IP2Bus_ArData[0:7]),
		   (my_BE[1] ? wr_data[23:16] : IP2Bus_ArData[8:15]),
		   (my_BE[2] ? wr_data[15:8] : IP2Bus_ArData[16:23]),
		   (my_BE[3] ? wr_data[7:0] : IP2Bus_ArData[24:31])
		   };
   end

   // sequential stuff

   always @(posedge Bus2IP_Clk)
     if (Bus2IP_Reset) state <= `IDLE;
     else state <= state_ns;

   always @(posedge Bus2IP_Clk)
     if (Bus2IP_Reset) begin
	sram_addr_pin        <= 'h0;
	my_BE                <= 'h0;
     end
     else if (load_addr_BE) begin
	sram_addr_pin        <= Bus2IP_Addr[11:29];
	my_BE                <= Bus2IP_ArBE;
     end

   always @(posedge Bus2IP_Clk)
     if (Bus2IP_Reset) begin
	sram_data_tri_en_pin <= 0;
	sram_we_bw_pin       <= 1;   // READ
	IP2Bus_Ack           <= 0;
	rmw                  <= 0;
	IP2Bus_Error         <= 0;
     end
     else begin
	sram_data_tri_en_pin <= tri_en_nxt;
	sram_we_bw_pin       <= we_bw_nxt;
	IP2Bus_Ack           <= ack_nxt;
	rmw                  <= rmw_nxt;
	IP2Bus_Error         <= IP2Bus_Error_nxt;
     end

   // This looks weird I know. The reason we use sram_wr_data_pin
   // AND wr_data is that we want sram_wr_data_pin to be placed
   // in the IOB, but if there is a feedback path (to wr_data_nxt)
   // then it cant be put there. So we replicate the register.

   always @(posedge Bus2IP_Clk) begin
      sram_wr_data_pin     <= {4'h0, wr_data_nxt};
      wr_data              <= wr_data_nxt;
   end



   // The spec requires us to drive 0 on the read data at all times
   // except when we are providing actual read data (ack asserted)
   reg    [0 : C_MAX_AR_DWIDTH-1]        IP2Bus_ArData;
   always @(posedge Bus2IP_Clk)
     if (load_rd_data)
       IP2Bus_ArData <= sram_rd_data_pin[C_MAX_AR_DWIDTH-1 : 0];
       //IP2Bus_ArData <= 32'h12345678;
     else
       IP2Bus_ArData <= 'h0;




   /************************************************
    This section is a fake SRAM so that we can test
    the operation of the RAM controller without having
    a physical RAM attached.
    This is modelled on a Cypress CY7C1370C 512Kx36 NOBL device.

    The external signals are the XXX_pin signals above.
   *************************************************/

   reg [35:0]   s_data_0, s_data_1, s_data_2, s_data_3;  // the actual ram data
   reg [2:0] 	addr_1, addr_2;
   reg 		weB_1, weB_2;
   reg [35:0] 	r_rd_data;

   // 2 pipeline stages for address and write enable...
   always @(posedge Bus2IP_Clk) begin
      addr_1 <= sram_addr_pin[2:0];
      addr_2 <= addr_1;
      weB_1  <= sram_we_bw_pin;
      weB_2  <= weB_1;
   end

   // handle writes
   always @(posedge Bus2IP_Clk)
     if (!weB_2 & sram_data_tri_en_pin)
       case (addr_2[1:0])
	 0: s_data_0 <= sram_wr_data_pin;
	 1: s_data_1 <= sram_wr_data_pin;
	 2: s_data_2 <= sram_wr_data_pin;
	 3: s_data_3 <= sram_wr_data_pin;
       endcase
     else if (!weB_2 & !sram_data_tri_en_pin) begin
	$display($time, "ERROR %m: Saw WE active but tristate enable not active.");
	#10 $finish;
     end

   // handle reads
   always @(negedge Bus2IP_Clk)
     case (addr_2[1:0])
       0: r_rd_data <= s_data_0;
       1: r_rd_data <= s_data_1;
       2: r_rd_data <= s_data_2;
       3: r_rd_data <= s_data_3;
     endcase // case(addr_2[1:0])

   assign sram_rd_data_pin = r_rd_data;


endmodule
