///////////////////////////////////////////////////////////////////////////////
// $Id: evt_pkt_wrtr.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: evt_pkt_wrtr.v
// Project: event capture
// Description: Recevies events and writes them into a packet. Then dispatches
//              the packet into the store_ingress_pkts to be sent out later
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns/1 ps

  module evt_pkt_wrtr
    #(parameter DATA_WIDTH           = 64,
      parameter CTRL_WIDTH           = DATA_WIDTH/8,
      parameter NUM_ABS_REG_PAIRS    = 4,
      parameter NUM_MONITORED_SIGS   = 8,
      parameter HEADER_LENGTH        = 7,
      parameter HEADER_LENGTH_SIZE   = log2(HEADER_LENGTH))
    (

     // interface to evt_rcrdr.v
     input      [DATA_WIDTH-1:0] event_data,
     input                       evt_fifo_empty,
     output reg                  evt_fifo_rd_en,
     output reg                  new_evt_pkt,

     // interface to output data path
     output reg [DATA_WIDTH-1:0] out_data,
     output reg [CTRL_WIDTH-1:0] out_ctrl,
     output reg                  out_wr,
     input                       out_rdy,

     // interface to input data path
     input  [DATA_WIDTH-1:0]     in_data,
     input  [CTRL_WIDTH-1:0]     in_ctrl,
     input                       in_wr,
     output                      in_rdy,

     // interface to oq_sizer
     input [DATA_WIDTH*NUM_ABS_REG_PAIRS-1:0] reg_values,

     // interface to registers
     input                       send_pkt,           // low to high trasition sends evt_pkt immediately
     output [HEADER_LENGTH_SIZE-1:0] header_word_number, // number of header word requested
     output reg                  evt_pkt_sent,       // pulses high when a pkt is sent
     output [8:0]                num_evts_in_pkt,    // number of events in the current packet (to get pkt len for IP/UDP)
     input  [DATA_WIDTH-1:0]     header_data,        // header data at header_word_number
     input  [CTRL_WIDTH-1:0]     header_ctrl,        // header ctrl at header_word_number
     input                       enable_events,      // puts the pkt writer in reset mode when low

     // misc
     input                       reset,
     input                       clk
     );

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   //----------------- Parameters ---------------------------------------------
   parameter EVT_TYPE_SIZE        = log2(NUM_MONITORED_SIGS+1);

   parameter GUARD_BAND      = NUM_MONITORED_SIGS; // space before we get a timestamp
   parameter FULL_THR        = 2*((1512/CTRL_WIDTH) - HEADER_LENGTH - NUM_ABS_REG_PAIRS); // pkt_len - max num headers - num absolute regs
   parameter ALMOST_FULL_THR = FULL_THR - 2*GUARD_BAND;

   parameter NUM_INCOMING_STATES        = 6;
   parameter RESET                      = 1;
   parameter POST_RESET                 = 2;
   parameter FILLING_FIFO_EVEN          = 4;
   parameter WAITING_FOR_TS_EVEN        = 8;
   parameter FILLING_FIFO_ODD           = 16;
   parameter WAITING_FOR_TS_ODD         = 32;

   parameter NUM_OUTGOING_STATES        = 5;
   parameter WAIT_DATA_AVAIL            = 1;
   parameter WAIT_PKT_DONE              = 2;
   parameter WRITE_HDRS                 = 4;
   parameter WRITE_ABS_REGS             = 8;
   parameter WRITE_EVENT_DATA           = 16;

   //----------------- Wires and Regs------------------------------------------

   // implement mux to select words from the absolute register values
   wire [63:0]                       reg_values_words[NUM_ABS_REG_PAIRS-1:0];
   wire [63:0]                       reg_value_selected;

   wire                              local_reset;

   // fifo interface
   reg [DATA_WIDTH-1:0]              fifo_data_in;
   reg [CTRL_WIDTH-1:0]              fifo_ctrl_in;
   reg                               wr_en_fifo;
   reg                               rd_en_fifo;
   wire [DATA_WIDTH-1:0]             fifo_data_out;
   wire [CTRL_WIDTH-1:0]             fifo_ctrl_out;
   wire                              full_fifo;
   wire                              empty_fifo;

   // signals for sending packet immediately
   reg                               send_pkt_reg;
   reg                               previous_send_pkt;

   reg [8:0]                         data_count_pkt;
   reg                               reset_data_count;

   reg [8:0]                         pkt_len_fifo_din;
   wire                              almost_full_pkt;
   wire                              full_pkt;

   wire                              word_is_full_ts;
   wire                              word_is_half_ts;
   reg                               word_is_full_ts_prev;
   reg                               word_is_half_ts_prev;

   reg [NUM_INCOMING_STATES-1:0]     incoming_state;
   reg [NUM_INCOMING_STATES-1:0]     incoming_state_next;

   reg                               evt_pkt_stored;

   reg [DATA_WIDTH-1:0]              event_data_d1;

   reg [NUM_OUTGOING_STATES-1:0]     outgoing_state, outgoing_state_next;

   reg [3:0]                         count, count_next;

   reg [CTRL_WIDTH-1:0]              out_ctrl_prev;

   reg [DATA_WIDTH*NUM_ABS_REG_PAIRS-1:0] reg_values_recorded;
   reg [DATA_WIDTH*NUM_ABS_REG_PAIRS-1:0] reg_values_recorded_prev;

   reg                                    in_fifo_rd_en;
   wire [CTRL_WIDTH-1:0]                  in_fifo_ctrl_out;
   wire [DATA_WIDTH-1:0]                  in_fifo_data_out;

   //-------------------- input fifo  ------------------------------------
   fallthrough_small_fifo
     #(.WIDTH(CTRL_WIDTH+DATA_WIDTH),
       .MAX_DEPTH_BITS(2))
       input_fifo
         (.din                          ({in_ctrl, in_data}),
          .wr_en                        (in_wr),
          .rd_en                        (in_fifo_rd_en),
          .dout                         ({in_fifo_ctrl_out, in_fifo_data_out}),
          .full                         (),
          .nearly_full                  (in_fifo_nearly_full),
	  .prog_full                    (),
          .empty                        (in_fifo_empty),
          .reset                        (reset),
          .clk                          (clk));
   assign in_rdy = !in_fifo_nearly_full;

   //-------------------- Get the register values ------------------------------------
   generate
      genvar i;
      for(i=0; i<NUM_ABS_REG_PAIRS; i=i+1) begin: gen_reg_values
         assign reg_values_words[i] = {reg_values_recorded_prev[64*i+31: 64*i],reg_values_recorded_prev[64*(i+1) - 1 : 64*i+32]};
      end
   endgenerate
   // select the desired register value
   assign reg_value_selected = reg_values_words[count[log2(NUM_ABS_REG_PAIRS)-1:0]];

   //------------------------ Event disable ------------------------------------------

   assign local_reset = reset | ~enable_events;

   //------------------- Number of events in pkts fifo -------------------------------
   assign header_word_number = count;

   fallthrough_small_fifo
     #(.WIDTH(9),
       .MAX_DEPTH_BITS(4))
       pkt_len_fifo
         (.din                          (pkt_len_fifo_din),
          .wr_en                        (evt_pkt_stored),
          .rd_en                        (evt_pkt_sent),
          .dout                         (num_evts_in_pkt),
          .full                         (),
          .nearly_full                  (),
	  .prog_full                    (),
          .empty                        (pkt_len_fifo_empty),
          .reset                        (local_reset),
          .clk                          (clk));


   //------------------------ Packet Fifos Logic -------------------------------------
   evt_pkt_fifo_512x72 pkt_fifo (
                               .clk     (clk),
                               .rst     (local_reset),
                               .din     ({fifo_ctrl_in, fifo_data_in}),
                               .wr_en   (wr_en_fifo),
                               .rd_en   (rd_en_fifo),
                               .dout    ({fifo_ctrl_out, fifo_data_out}),
                               .full    (full_fifo),
                               .empty   (empty_fifo)
                               );

   always @(posedge clk) begin
      if(local_reset) begin
         send_pkt_reg         <= 0;
         previous_send_pkt    <= 0;
         data_count_pkt       <= 0;
      end
      else begin
         // set at the rising edge, and clear when pkt is sent
         if(send_pkt & !previous_send_pkt & !empty_fifo) begin
            send_pkt_reg <= 1;
         end
         else if(reset_data_count) begin
            send_pkt_reg <= 0;
         end

         previous_send_pkt    <= send_pkt;

         if(reset_data_count) begin
            data_count_pkt <= 0;
         end
         else if(wr_en_fifo) begin
            data_count_pkt <= data_count_pkt + 2;
         end
      end
   end // always @ (posedge clk)

   // signal the full and almost full signals
   assign almost_full_pkt = (data_count_pkt >= ALMOST_FULL_THR) | send_pkt_reg;
   assign full_pkt        = (data_count_pkt >= FULL_THR);

   //------------------------ Incoming data logic ------------------------------------

   // monitor the incoming TS event types
   assign word_is_full_ts = !evt_fifo_empty & (event_data[63:64-EVT_TYPE_SIZE]==0) & (word_is_full_ts_prev || !(event_data_d1[31:32-EVT_TYPE_SIZE]==0));
   assign word_is_half_ts = !evt_fifo_empty & (event_data[31:32-EVT_TYPE_SIZE]==0) & (word_is_half_ts_prev || !(event_data[63:64-EVT_TYPE_SIZE]==0));

   always @(*) begin
      //defaults
      wr_en_fifo           = 0;
      evt_fifo_rd_en       = 0;
      new_evt_pkt          = 0;
      incoming_state_next  = incoming_state;
      fifo_data_in         = event_data_d1;
      fifo_ctrl_in         = 0;
      evt_pkt_stored       = 0;
      pkt_len_fifo_din     = data_count_pkt + 2;
      reset_data_count     = 0;

      case (incoming_state)
         RESET: begin
            incoming_state_next=POST_RESET;
            new_evt_pkt=1;
         end

         POST_RESET: begin
            if(!evt_fifo_empty) begin
               incoming_state_next=FILLING_FIFO_EVEN;
               evt_fifo_rd_en = 1;
            end
         end

         FILLING_FIFO_EVEN: begin
            wr_en_fifo = !evt_fifo_empty && !full_fifo;
            evt_fifo_rd_en = !evt_fifo_empty && !full_fifo;
            if(almost_full_pkt) begin
               new_evt_pkt = 1;
               incoming_state_next=WAITING_FOR_TS_EVEN;
            end
         end

         WAITING_FOR_TS_EVEN: begin
            if(!full_fifo && !evt_fifo_empty) begin
               wr_en_fifo = 1;
               if(word_is_full_ts) begin
                  fifo_ctrl_in         = 8'h1;
                  incoming_state_next  = FILLING_FIFO_EVEN;
                  evt_pkt_stored       = 1;
                  reset_data_count     = 1;
                  evt_fifo_rd_en       = 1;
               end
               else if(word_is_half_ts) begin
                  fifo_ctrl_in         = 8'h10;
                  incoming_state_next  = FILLING_FIFO_ODD;
                  evt_pkt_stored       = 1;
                  pkt_len_fifo_din     = data_count_pkt + 1;
                  reset_data_count     = 1;
               end
	       else begin
		  evt_fifo_rd_en = 1;
	       end
            end // if (!full_fifo && !evt_fifo_empty)
         end // case: WAITING_FOR_TS_EVEN

         FILLING_FIFO_ODD: begin
            wr_en_fifo       = !evt_fifo_empty && !full_fifo;
            evt_fifo_rd_en   = !evt_fifo_empty && !full_fifo;
            fifo_data_in     = {event_data_d1[31:0], event_data[63:32]};
            if(almost_full_pkt) begin
               new_evt_pkt = 1;
               incoming_state_next = WAITING_FOR_TS_ODD;
            end
         end // case: FILLING_FIFO_ODD

         WAITING_FOR_TS_ODD: begin
            fifo_data_in = {event_data_d1[31:0], event_data[63:32]};
            if(!full_fifo && !evt_fifo_empty) begin
               wr_en_fifo     = 1;
               evt_fifo_rd_en = 1;
               if(word_is_full_ts) begin
                  fifo_ctrl_in         = 8'h10;
                  incoming_state_next  = FILLING_FIFO_EVEN;
                  evt_pkt_stored       = 1;
                  pkt_len_fifo_din     = data_count_pkt + 1;
                  reset_data_count     = 1;
               end
               else if(word_is_half_ts) begin
                  fifo_ctrl_in         = 8'h1;
                  incoming_state_next  = FILLING_FIFO_ODD;
                  evt_pkt_stored       = 1;
                  reset_data_count     = 1;
               end
            end // if (!full_fifo && !evt_fifo_empty)
         end // case: WAITING_FOR_TS_ODD

      endcase
   end // always @*

   /*
    * update sequential elements
    */
   always @(posedge clk) begin
      if(local_reset) begin
         incoming_state          <= RESET;
         event_data_d1           <= ~0;
         word_is_full_ts_prev    <= 0;
         word_is_half_ts_prev    <= 0;
      end
      else begin
         incoming_state          <= incoming_state_next;
         event_data_d1           <= evt_fifo_rd_en ? event_data : event_data_d1;
         word_is_full_ts_prev    <= evt_fifo_rd_en ? word_is_full_ts : word_is_full_ts_prev;
         word_is_half_ts_prev    <= evt_fifo_rd_en ? word_is_half_ts : word_is_half_ts_prev;
      end // else: !if(local_reset)

      // synthesis translate_off
      if(wr_en_fifo && full_pkt) begin
         $display("%t %m ERROR: Writing to event packet when the packet is full.", $time);
         $stop;
      end
      // synthesis translate_on

   end // always @ (posedge clk)

   // record the absolute register values when a new packet is started
   always @(posedge clk) begin
      if(local_reset) begin
         reg_values_recorded 	     <= 0;
         reg_values_recorded_prev    <= 0;
      end
      else if (new_evt_pkt) begin
         reg_values_recorded 	     <= reg_values;
         reg_values_recorded_prev    <= reg_values_recorded;
      end
   end

   //------------------------ Outgoing data logic ------------------------------------

   always @(*)   begin
      outgoing_state_next   = outgoing_state;
      count_next            = count;
      out_data              = in_fifo_data_out;
      out_ctrl              = in_fifo_ctrl_out;
      out_wr                = !in_fifo_empty & out_rdy;
      in_fifo_rd_en         = !in_fifo_empty & out_rdy;
      evt_pkt_sent          = 0;
      rd_en_fifo            = 0;

      case(outgoing_state)

         /* Wait until we want to send an event packet
          * or until a packet needs to pass through */
         WAIT_DATA_AVAIL: begin
            if(!in_fifo_empty && out_rdy) begin
               outgoing_state_next = WAIT_PKT_DONE;
            end
            else if(!pkt_len_fifo_empty && out_rdy) begin
               out_wr              = 0;
               in_fifo_rd_en       = 0;
               outgoing_state_next = WRITE_HDRS;
               count_next = 0;
            end
         end // case: WAIT_DATA_AVAIL

         /* wait for the EOP to arrive */
         WAIT_PKT_DONE: begin
            if(out_ctrl!=0 && out_ctrl_prev==0) begin
               outgoing_state_next = WAIT_DATA_AVAIL;
            end
         end // case: WAIT_PKT_DONE

         /* Write the headers specified from the registers */
         WRITE_HDRS: begin
            out_data = header_data;
            out_ctrl = header_ctrl;
            out_wr = out_rdy;
            in_fifo_rd_en = 0;
            if(count>=HEADER_LENGTH-1 && out_rdy) begin
               outgoing_state_next = WRITE_ABS_REGS;
               count_next = 0;
            end
            else if(out_rdy) begin
               count_next = count + 1'b1;
            end
         end // case: WRITE_HDRS

         /* Write all the absolute register pair values */
         WRITE_ABS_REGS: begin
            out_data = reg_value_selected;
            out_ctrl = 0;
            out_wr = out_rdy;
            in_fifo_rd_en = 0;
            if(count==NUM_ABS_REG_PAIRS-1 && out_rdy) begin
               outgoing_state_next = WRITE_EVENT_DATA;
               rd_en_fifo = 1;
            end
            else if(out_rdy) begin
               count_next = count + 1'b1;
            end
         end // case: WRITE_ABS_REGS

         /* Move all the events from the fifo to the output */
         WRITE_EVENT_DATA: begin
            out_data = fifo_data_out;
            out_ctrl = fifo_ctrl_out;
            out_wr   = out_rdy;
            in_fifo_rd_en  = 0;
            if(fifo_ctrl_out != 0 && out_rdy) begin
               outgoing_state_next = WAIT_DATA_AVAIL;
               evt_pkt_sent        = 1;
            end
            else begin
               rd_en_fifo          = out_rdy;
            end
         end // case: WRITE_EVENT_DATA

      endcase
   end //always @*

   always @(posedge clk) begin
      if(local_reset) begin
         outgoing_state  <= WAIT_DATA_AVAIL;
         count           <= 0;
         out_ctrl_prev   <= 0;
      end
      else begin
         outgoing_state  <= outgoing_state_next;
         count           <= count_next;
         out_ctrl_prev   <= out_wr ? out_ctrl : out_ctrl_prev;
      end
   end

   // synthesis translate_off
   integer pkt_len_counter;
   integer ip_pkt_len;
   integer word_num;
   reg 	   saw_data;

   integer num_bytes;

   always @(*) begin
      case(out_ctrl)
         1: num_bytes = 8;
         2: num_bytes = 7;
         4: num_bytes = 6;
         8: num_bytes = 5;
         16: num_bytes = 4;
         32: num_bytes = 3;
         64: num_bytes = 2;
         128: num_bytes = 1;
         default: begin
            num_bytes = 8;
         end
      endcase // case(out_ctrl)
   end // always @ (*)

   always @(posedge clk) begin
      if(outgoing_state==WAIT_DATA_AVAIL) begin
	 pkt_len_counter <= 0;
	 ip_pkt_len <= 0;
	 word_num <= 0;
	 saw_data <= 0;
      end
      else if(outgoing_state!=WAIT_PKT_DONE) begin
	 if(out_ctrl == 0) begin
	    saw_data <= 1;
	 end

	 word_num <= word_num + out_wr;

	 if(out_ctrl==0 && out_wr) begin
	    pkt_len_counter <= pkt_len_counter + CTRL_WIDTH;
	 end

	 if(word_num==3) begin
	    ip_pkt_len = out_data[63:48];
	 end

	 if(saw_data && out_ctrl!=0 && out_wr) begin
	    if(pkt_len_counter+num_bytes-14==ip_pkt_len) begin
	       $display("%t %m INFO: Sent event packet of length %u\n", $time, ip_pkt_len+14);
	    end
	    else begin
	       $display("%t %m ERROR: Event packet lengths don't match, Pkt length in IP header: %u, Actual Pkt length: %u\n", $time, ip_pkt_len, pkt_len_counter+num_bytes-14);
	       $stop;
	    end
	 end
      end // if (outgoing_state!=WAIT_PKT_DONE)
   end // always @ (posedge clk)
   // synthesis translate_on

endmodule
