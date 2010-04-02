///////////////////////////////////////////////////////////////////////////////
// $Id: nf2_txfifo_sm.v 1962 2007-07-17 01:16:59Z grg $
//
// Module: nf2_txfifo_sm.v
// Project: NetFPGA Rev 2.1
// Description: Instantiates the speed matching FIFO that feeds into
//              a Tx MAC.
//
// On the write side is the 62.5/125 MHz core clock which feeds in data 36 bits
// wide. Bits 35,26,17 and 8 indicate if that byte is the EOP.
// Prog_full is true if there is NOT enough space for a MAX packet (allowing for
// about 16 clocks of additional latency in the write FIFO)
//
// On the read side is the Tx MAC (called txcoreclk in the Tri-mode MAC docs)
//
// CAUTION!!!! The Tx MAC can operate at 125MHz, 12.5MHz or 1.25MHz for
//             1000/100/10 mode.
//
// Operation: Provide data to the GMAC and assert gmac_tx_dvld.
//            Wait until gmac_tx_ack is high (for one clock) and then provide
//            new data on every clock.
//            Deassert gmac_tx_dvld after the last byte (NO FCS) is sent.
//
// NOTE: the read side must always read out words in groups of 4.
//
///////////////////////////////////////////////////////////////////////////////



module nf2_txfifo_sm
  (

   // --- Core side signals (clk domain)

   input [35:0]     txf_din,
   input            txf_wr_en,
   output           txf_prog_full,
   output           txf_full,
   output           txf_almost_full,
   output reg       txf_pkt_sent_ok,
   output reg       txf_pkt_underrun,

   output reg [7:0] txf_num_pkts_waiting,

   // --- MAC side signals (txcoreclk domain)

   input             gmac_tx_ack,
   output reg        gmac_tx_dvld,
   output wire [7:0] gmac_tx_data,
   output reg        gmac_tx_client_underrun,

   // --- Misc

   input enable_txf_transmit,
   input reset,
   input clk,
   input txcoreclk

   );

   reg 	 rd_en;
   wire  eop;

   // The FIFO will send words m.s.byte first, so we have to swap these around

   wire [35:0] txf_adjusted_din = txf_din;
   /*wire [35:0] txf_adjusted_din = {txf_din[8:0],
				   txf_din[17:9],
				   txf_din[26:18],
				   txf_din[35:27]};*/
   /*wire [35:0] txf_adjusted_din = {txf_din[8:0],
				   txf_din[17:9],
				   txf_din[26:18],
				   txf_din[35:27]};*/


   txfifo_512x36_to_9 gmac_tx_fifo (

        .din       (txf_adjusted_din),
        .wr_en     (txf_wr_en),
        .wr_clk    (clk),
        .dout      ({eop,gmac_tx_data}),
        .rd_en     (rd_en),
        .rd_clk    (txcoreclk),
        .empty     (empty),
        .full      (txf_full),
        .almost_full (txf_almost_full),
        .rst       (reset),
        .prog_full (txf_prog_full),
        .underflow (underflow)
   );

   reg [3:0]	 pkt_sent_long, saw_underrun_long;

   //------ Following is in core clock domain (62.5MHz)  -------------------
   //
   // We need to know when EOP is seen because we must not start to transmit
   // the packet until it is all here.

   reg 	 saw_wr_eop;

   always @(posedge clk) saw_wr_eop <= reset ? 0 :
				    txf_wr_en & (txf_din[35] | txf_din[26] | txf_din[17] | txf_din[8]);

   // synchronize the pkt_sent signal into the clk domain

   reg [2:0] pkt_sent_clk_long;
   // synthesis attribute ASYNC_REG of pkt_sent_clk_long is TRUE ;
   reg [2:0] saw_underrun_clk_long;
   // synthesis attribute ASYNC_REG of saw_underrun_clk_long is TRUE ;

   reg       pkt_sent_clk;       // generate pulse from rising edge of pkt_sent_clk_long

   always @(posedge clk)
     if (reset) begin
	pkt_sent_clk_long     <= 'h0;
	pkt_sent_clk          <=   0;
	saw_underrun_clk_long <= 'h0;
     end
     else begin
	pkt_sent_clk_long     <= {pkt_sent_clk_long[1:0],pkt_sent_long[3]};
	pkt_sent_clk          <= !pkt_sent_clk_long[2] & pkt_sent_clk_long[1];
	saw_underrun_clk_long <= {saw_underrun_clk_long[1:0],saw_underrun_long[3]};
     end


   // keep a count of the number of packets waiting to be sent

   always @(posedge clk)
     if (reset)
       txf_num_pkts_waiting <= 'h0;
     else begin
	case ({pkt_sent_clk, saw_wr_eop})
	  2'b01 : txf_num_pkts_waiting <= txf_num_pkts_waiting + 1;
	  2'b10 : txf_num_pkts_waiting <= txf_num_pkts_waiting - 1;
	  default: begin end
	endcase
     end

   wire not_empty_clk = (txf_num_pkts_waiting != 'h0);


   // generate strobes back to the core logic to tell it when we sent a good
   // or bad packet (so it can track statistics)

   always @(posedge clk) begin
      txf_pkt_sent_ok  <= reset ? 0 : ( pkt_sent_clk & !saw_underrun_clk_long[2] );
      txf_pkt_underrun <= reset ? 0 : ( pkt_sent_clk &  saw_underrun_clk_long[2] );
   end

   // fwd declaration
   reg 	     reset_txcoreclk;
   // synthesis attribute ASYNC_REG of reset_txcoreclk is TRUE ;

   // extend reset over to MAC domain
   reg reset_long;
   // synthesis attribute ASYNC_REG of reset_long is TRUE ;
   always @(posedge clk) begin
      if (reset ) reset_long <= 1;
      else if (reset_txcoreclk) reset_long <= 0;
   end

   //
   //------ Following is in MAC clock domain (125MHz/12.5Mhz/1.25Mhz) -----------
   //

   // pulse pkt_sent when we have sent a packet.

   always @(posedge txcoreclk) reset_txcoreclk <= reset_long;

   reg       pkt_sent;

   reg [1:0] byte_count;
   reg [4:0] tx_mac_state_nxt, tx_mac_state;
   reg 	     gmac_tx_dvld_nxt, byte_count_ld, byte_count_en;
   reg 	     saw_underrun, gmac_tx_client_underrun_nxt;

   reg [3:0] ipg_timer;
   reg 	     ipg_timer_ld;

   reg [3:0] not_empty_mac; // synch not_empty_clk into mac clock
   // synthesis attribute ASYNC_REG of not_empty_mac is TRUE ;

   always @(posedge txcoreclk)
      not_empty_mac <= reset_txcoreclk ? 4'h0 : {not_empty_mac[2:0],not_empty_clk};

   reg 	     enable;
   // synthesis attribute ASYNC_REG of enable is TRUE ;
   always @(posedge txcoreclk)  enable <= enable_txf_transmit;

   // read state machine states (one-hot)

   parameter IDLE = 1,WAIT_FOR_ACK = 2, WAIT_FOR_EOP = 4, WAIT_FOR_BYTE_COUNT_3 = 8,
	     TX_DONE = 16;

   //
   // ------ BEGIN STATE MACHINE
   //

   always @* begin

      // set defaults
      tx_mac_state_nxt = tx_mac_state;
      gmac_tx_dvld_nxt = 0;
      rd_en = 0;
      byte_count_ld = 0;
      byte_count_en = 0;
      gmac_tx_client_underrun_nxt = 0;
      pkt_sent = 0;
      ipg_timer_ld = 0;

      case (tx_mac_state)

	IDLE: if (not_empty_mac[3] & !empty & enable) begin

	   rd_en = 1;   // this will make DOUT of FIFO valid after the NEXT clock
	   gmac_tx_dvld_nxt = 1;
	   tx_mac_state_nxt = WAIT_FOR_ACK;
	   byte_count_ld = 1;

	end

	WAIT_FOR_ACK: begin

	   gmac_tx_dvld_nxt = 1;
	   if (gmac_tx_ack) begin   // now provide the rest of the packet
	      rd_en = 1;
	      gmac_tx_dvld_nxt = 1;
	      byte_count_en = 1;
	      tx_mac_state_nxt = WAIT_FOR_EOP;
	   end
	end

	WAIT_FOR_EOP: begin

	   if (eop) begin
	      gmac_tx_client_underrun_nxt = saw_underrun | underflow;

	      if (byte_count == 2'b11) begin // the last data byte was the last of the quad so we are done.
		 ipg_timer_ld = 1;
		 tx_mac_state_nxt = TX_DONE;
	      end
	      else begin // need to keep reading until we have read last of the quad
		 rd_en = 1;
		 byte_count_en = 1;
		 tx_mac_state_nxt = WAIT_FOR_BYTE_COUNT_3;
	      end
	   end // if (eop)

	   else begin // Not EOP - keep reading!
	      rd_en = 1;
	      gmac_tx_dvld_nxt = 1;
	      byte_count_en = 1;
	   end
	end

	WAIT_FOR_BYTE_COUNT_3: begin

	   if (byte_count == 2'b11) begin
	      ipg_timer_ld = 1;
	      tx_mac_state_nxt = TX_DONE;
	   end
	   else begin // need to keep reading until we have read last of the quad
	      rd_en = 1;
	      byte_count_en = 1;
	   end
	end

	TX_DONE: begin
	   if (ipg_timer == 4'hf)
	     pkt_sent = 1;
	   if (ipg_timer == 4'h0)
	     tx_mac_state_nxt = IDLE;
	end

	default: begin // synthesis translate_off
	  if (!reset && $time > 4000) $display("%t ERROR (%m) state machine in illegal state 0x%x",
		   $time, tx_mac_state);
	   // synthesis translate_on
	end

      endcase // case(tx_mac_state)

   end // always @ *

   //
   // ------ END STATE MACHINE
   //

   // update sequential elements
   always @(posedge txcoreclk) begin
      tx_mac_state <= reset_txcoreclk ? IDLE : tx_mac_state_nxt;
      gmac_tx_dvld <= reset_txcoreclk ? 0    : gmac_tx_dvld_nxt;
      gmac_tx_client_underrun <= reset_txcoreclk ? 0 : gmac_tx_client_underrun_nxt;
   end

   // saw_underrun tracks the underrun signal from the FIFO
   always @(posedge txcoreclk)
     if (reset_txcoreclk | byte_count_ld) saw_underrun <= 0;
     else saw_underrun <= underflow | saw_underrun;

   // stretch saw_underrun out by 4 clocks so that clk will always see it
   always @(posedge txcoreclk)
     if (reset_txcoreclk) saw_underrun_long <= 4'h0;
     else if (saw_underrun) saw_underrun_long <= 4'hf;
     else saw_underrun_long <= {saw_underrun_long[2:0],1'b0};

   // byte counter.
   always @(posedge txcoreclk)
     if ( reset_txcoreclk | byte_count_ld ) byte_count <= 2'b00;
     else if ( byte_count_en )    byte_count <= byte_count + 2'b01;

   // stretch pkt_sent out by 4 clocks so that clk will always see it
   always @(posedge txcoreclk)
     if (reset_txcoreclk) pkt_sent_long <= 4'h0;
     else if (pkt_sent) pkt_sent_long <= 4'hf;
     else pkt_sent_long <= {pkt_sent_long[2:0],1'b0};

   // Inter packet gap timer (this is just to allow time for FIFO
   // signals to become valid at the end of one packet and before the next
   always @(posedge txcoreclk)
     if (reset_txcoreclk | ipg_timer_ld) ipg_timer <= 4'hf;
     else if (ipg_timer != 0) ipg_timer <= ipg_timer - 4'h1;

endmodule // nf2_txfifo_sm

