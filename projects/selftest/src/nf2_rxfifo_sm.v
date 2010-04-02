///////////////////////////////////////////////////////////////////////////////
// $Id: nf2_rxfifo_sm.v 1962 2007-07-17 01:16:59Z grg $
//
// Module: nf2_rxfifo_sm.v
// Project: NetFPGA Rev 2.1
// Description: Instantiates the speed matching FIFO that accepts
//              packets from the ingress MAC.
//
// On the write side is the 125/12.5/1.25MHz MAC clock which feeds
// data 9 bits wide into the fifo (bit 8 is EOP).
// After the packet has been written we also store a 4 byte status
// word that indicates if the packet was received OK or not.
// Note: two reasons for the packet to NET be OK:
//       1. FCS (CRC) error
//       2. Ran out of buffer space (oveflow).
//
// On the read side (62MHz core clock) Bits 35,26,17 and 8 indicate
// if that byte is the EOP.
// The first byte written in will appear on the top 9 bits (35:27).
//
// Prog_full is true if there is <90 bytes available (which is enough for
// a min sized packet plus final status word.
//
// CAUTION!!!! The Rx MAC can operate at 125MHz, 12.5MHz or 1.25MHz for
//             1000/100/10 mode respectively.
//
//
// NOTE: the write side MUST ALWAYS write bytes in groups of 4.
//
///////////////////////////////////////////////////////////////////////////////



module nf2_rxfifo_sm
  (

   // --- Core side signals (clk domain)

   output wire [35:0]     rxf_dout,
   input                  rxf_rd_en,
   output                 rxf_empty,
   output                 rxf_almost_empty,
   output reg             rxf_pkt_avail,
   output reg             rxf_pkt_lost,
   output reg             rxf_pkt_rcvd,  // pulse. packet may be bad or caused overflow

   output reg [7:0]       rxf_num_pkts_waiting,

   // --- MAC side signals (rxcoreclk domain)

   input wire [7:0] gmac_rx_data,
   input            gmac_rx_dvld,
   input            gmac_rx_goodframe,
   input            gmac_rx_badframe,

   // --- Misc

   input enable_rxf_receive,
   input reset,
   input clk,
   input rxcoreclk

   );

   wire [35:0] dout;

   // The FIFO will send words m.s.byte first, so we have to swap these around

   assign  rxf_dout = dout;
   /*assign  rxf_dout = {dout[8:0],
		       dout[17:9],
		       dout[26:18],
		       dout[35:27]};*/

   reg       eop;    // EOP bit being written on MAC side
   reg [7:0] rx_data_d1, rx_data_d2;
   reg 	     wr_en;

   //
   // The RxFIFO exists in both clock domains
   //

   rxfifo_8kx9_to_36 gmac_rx_fifo (
        .din({eop,rx_data_d2}),
        .wr_en(wr_en),
        .wr_clk(rxcoreclk),

        .dout(dout),
        .rd_en(rxf_rd_en),
        .rd_clk(clk),

        .empty(rxf_empty),
        .almost_empty(rxf_almost_empty),
        .full(),
        .overflow(),
        .prog_full(prog_full),
        .rst(reset)
   );

   // These _long regs are in MAC domain and bit 3 will be valid for 4 MAC clocks
   // which is >= 2 core clocks.

   reg [3:0] pkt_rcvd_long, lost_pkt_long;


   //
   //------ Following is in core clock domain (62MHz)
   //

   reg [2:0] lost_pkt_long_clk;
   // synthesis attribute ASYNC_REG of lost_pkt_long_clk is TRUE ;

   always @(posedge clk) begin
      lost_pkt_long_clk <= reset ? 'h0 :  {lost_pkt_long_clk[1:0],lost_pkt_long[3]};
      rxf_pkt_lost      <= reset ? 0   :!lost_pkt_long_clk[1] & lost_pkt_long_clk[2];
   end

   reg [2:0] pkt_rcvd_long_clk;
   // synthesis attribute ASYNC_REG of pkt_rcvd_long_clk is TRUE ;

   always @(posedge clk) begin
      pkt_rcvd_long_clk <= reset ? 'h0 :  {pkt_rcvd_long_clk[1:0],pkt_rcvd_long[3]};
      rxf_pkt_rcvd      <= reset ? 0   : !pkt_rcvd_long_clk[1] & pkt_rcvd_long_clk[2];
   end


   // watch the data being read out to see when EOP occurs.

   wire rd_eop = (rxf_dout[35] | rxf_dout[26] | rxf_dout[17] | rxf_dout[8]);

   // generate a strobe pkt_read_out when reading process reads out the last word.

   reg 	pkt_read_out;

   always @(posedge clk)
     pkt_read_out <= reset ? 0 : ( rd_eop & rxf_rd_en );

   // keep a count of the number of packets waiting to be read out of the Rx fifo

   always @(posedge clk)
     if (reset)
       rxf_num_pkts_waiting <= 'h0;
     else begin
	case ({pkt_read_out, rxf_pkt_rcvd})
	  2'b01 : rxf_num_pkts_waiting <= rxf_num_pkts_waiting + 1;
	  2'b10 : rxf_num_pkts_waiting <= rxf_num_pkts_waiting - 1;
	  default: begin end
	endcase
     end

   // rxf_pkt_avail must go low the clock AFTER EOP occurs on read side.

      always @(posedge clk)
	rxf_pkt_avail <= (reset | rd_eop | pkt_read_out | (!enable_rxf_receive)) ? 0 :
			 ( rxf_num_pkts_waiting != 0 );


   reg 	     reset_rxcoreclk;
   // synthesis attribute ASYNC_REG of reset_rxcoreclk is TRUE ;

   // extend reset over to MAC domain
   reg reset_long;
   // synthesis attribute ASYNC_REG of reset_long is TRUE ;
   always @(posedge clk) begin
      if (reset ) reset_long <= 1;
      else if (reset_rxcoreclk) reset_long <= 0;
   end


   //
   //------ Following is in MAC clock domain (125MHz/12.5Mhz/1.25Mhz) -----------
   //

   // Here is the structure of the pipeline
   //
   //                  7    +--+ rx_data_d1   +--+ rx_data_d2    7       +-------
   //    gmac_rx_data -/----|  |--------------|  |---------------/-------| FIFO
   //                       +--+              +--+                       |
   //                                                                    |
   //                                         +--+     eop               |
   //                                         |  |-----------------------|
   //                                         +--+                       +-------
   //                                                                      |
   //                               wr_en_nxt +--+     wr_en               |
   //                              -----------|  |-------------------------+
   //                                         +--+
   //
   //                       +--+ dvld_d1
   //    gmac_rx_dvld ------|  |--------------
   //                       +--+
   //


   always @(posedge rxcoreclk) reset_rxcoreclk <= reset_long;

   reg [1:0] byte_count;
   reg [6:0] rx_mac_state_nxt, rx_mac_state;
   reg [1:0] data_sel;
   reg       pkt_good, pkt_bad;
   reg 	     lost_pkt;
   reg 	     lost_info;
   reg 	     wr_en_nxt;

   // Data mux select signals.
   parameter DATA   = 1, // MAC data
	     ZERO   = 2, // 8'h0
	     STATUS = 3; // Status byte (GOOD or BAD)

   // pipeline registers for rx_data and dvld
   reg 	     dvld_d1;

   always @(posedge rxcoreclk) begin
      dvld_d1 <= gmac_rx_dvld;
      rx_data_d1 <= gmac_rx_data;
      rx_data_d2 <= (data_sel == ZERO) ? 8'h0 :
		    (data_sel == STATUS) ? {7'h0, pkt_bad} : rx_data_d1;
   end

   // write state machine states (one-hot)

   parameter IDLE             = 1,
	     RCV_PKT          = 2,
	     WAIT_GOOD_OR_BAD = 4,
	     WRITE_STATUS_0   = 8,
	     WRITE_STATUS_1   = 16,
	     WRITE_STATUS_2   = 32,
	     DROP_PKT         = 64;


   //
   // ------ BEGIN STATE MACHINE
   //

   always @* begin

      // set defaults
      rx_mac_state_nxt = rx_mac_state;
      wr_en_nxt = 0;
      data_sel  = DATA;
      lost_pkt  = 0;   // 1 = lost complete pkt (not put in FIFO)
      lost_info = 0;   // 1 = started to rcv pkt but then went full.

      case (rx_mac_state)

	IDLE:
	  if (dvld_d1 & !prog_full) begin // start writing the incoming packet
	   wr_en_nxt = 1;
	   rx_mac_state_nxt = RCV_PKT;
	end
	else
	  if (dvld_d1 & prog_full) begin // Must discard entire packet
	     // synthesis translate_off
	     $display("%t %m Warning: MAC discarding ingress pkt because ingress FIFO full",
		      $time);
	     // synthesis translate_on
	     rx_mac_state_nxt = DROP_PKT;
	  end
	RCV_PKT:
	  if (dvld_d1 & !prog_full) begin // keep writing pkt
	     wr_en_nxt = 1;
	  end
	  else
	    if (dvld_d1 & prog_full) begin // Stop writing - might run out space.
	       lost_info = 1;
	       if (!gmac_rx_dvld) // This is last byte - MUST write it in
		 wr_en_nxt = 1;
	    end

	    else // dvld_d1 == 0 - end of packet.
	      if (byte_count !== 2'b11) begin // keep writing until we have written 4 bytes
		 wr_en_nxt = 1;
		 data_sel  = ZERO;
	      end
	      else // we have written a quad of bytes so wait for good/bad
		rx_mac_state_nxt = WAIT_GOOD_OR_BAD;

	WAIT_GOOD_OR_BAD: // wait until we see the good or bad signal from rx mac
	  if ( pkt_good | pkt_bad ) begin
	     wr_en_nxt = 1;
	     data_sel  = STATUS;
	     rx_mac_state_nxt = WRITE_STATUS_0;
	  end

	WRITE_STATUS_0: begin
	   wr_en_nxt = 1;      // write 2nd byte of four
	   data_sel  = ZERO;
	   rx_mac_state_nxt = WRITE_STATUS_1;
	end

	WRITE_STATUS_1: begin
	   wr_en_nxt = 1;      // write 3rd byte of four
	   data_sel  = ZERO;
	   rx_mac_state_nxt = WRITE_STATUS_2;
	end

	WRITE_STATUS_2: begin
	   wr_en_nxt = 1;      // write 4th byte of four
	   data_sel  = ZERO;
	   rx_mac_state_nxt = IDLE;
	end

	DROP_PKT: begin  // discard entire pkt - wait until dvld goes low.
	   lost_pkt = 1;
	   if (!dvld_d1) rx_mac_state_nxt = IDLE;
	end

	default: begin // synthesis translate_off
	  if (!reset && $time > 4000) $display("%t ERROR (%m) state machine in illegal state 0x%x",
		   $time, rx_mac_state);
	   // synthesis translate_on
	end

      endcase // case(rx_mac_state)

   end // always @ *

   //
   // ------ END STATE MACHINE
   //

   always @(posedge rxcoreclk) begin

      rx_mac_state <= reset_rxcoreclk ? IDLE : rx_mac_state_nxt;
      wr_en    <= (reset_rxcoreclk) ? 0 : wr_en_nxt;
      eop      <= (reset_rxcoreclk) ? 0 : ( dvld_d1 & !gmac_rx_dvld );
      pkt_good <= (reset_rxcoreclk | (rx_mac_state == IDLE) ) ? 0 :
		  ( gmac_rx_goodframe | pkt_good );
      pkt_bad  <= (reset_rxcoreclk | (rx_mac_state == IDLE) ) ? 0 :
		  ( gmac_rx_badframe  | lost_info | pkt_bad );

   end

   // byte counter (mod 4)
   always @(posedge rxcoreclk) begin
      if ( reset_rxcoreclk | (rx_mac_state == IDLE) ) byte_count <= 2'b00;
      else
	if (wr_en) byte_count <= byte_count + 2'b01;
   end

   // provide long signals to cross clock domain.

   always @(posedge rxcoreclk) begin
      if ( reset_rxcoreclk ) lost_pkt_long <= 'h0;
      else
	if (lost_pkt) lost_pkt_long <= 'hf;
	else lost_pkt_long <= {lost_pkt_long[2:0],1'b0};
   end

   // NOTE: core clock should look at TRAILING edge of pkt_rcvd_long
   always @(posedge rxcoreclk) begin
      if ( reset_rxcoreclk ) pkt_rcvd_long <= 'h0;
      else
	if (rx_mac_state ==  WRITE_STATUS_2) pkt_rcvd_long <= 'hf;
	else pkt_rcvd_long <= {pkt_rcvd_long[2:0],1'b0};
   end


   // synthesis translate_off
   // Generate strobes for tracking packets
   reg good_pkt_rcvd;
   reg bad_pkt_rcvd;

   always @(posedge rxcoreclk) begin
      good_pkt_rcvd <= ((rx_mac_state == WRITE_STATUS_2) && !pkt_bad);
      bad_pkt_rcvd  <= ((rx_mac_state == WRITE_STATUS_2) && pkt_bad) ||
		       ((rx_mac_state == DROP_PKT) && (!dvld_d1));
   end
   // synthesis translate_on

endmodule // nf2_rxfifo_sm


