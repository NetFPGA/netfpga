///////////////////////////////////////////////////////////////////////////////
// $Id: evt_rcrdr.v 3267 2008-01-29 01:08:52Z jnaous $
//
// Module: evt_rcrdr.v
// Project: event capture
// Description: Records signals with values.
//              The module is resposible for generating all the events written
//              into the events packet, including events for timer wrap-arounds
//              and for packet construction.
// An event is of the form: | EVT_TYPE | EVT_ID | EVT_VALUE | TIME_LSB |
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns/1 ps
  module evt_rcrdr
    #(parameter NUM_MONITORED_SIGS = 3,
      parameter SIGNAL_ID_SIZE = 3,
      parameter SIG_VALUE_SIZE = 8,
      parameter DATA_WIDTH = 64,
      parameter TIMER_RES_SIZE = 3,
      parameter ALL_SIG_VALUES_SIZE = SIG_VALUE_SIZE*NUM_MONITORED_SIGS,
      parameter ALL_SIGNAL_IDS_SIZE = SIGNAL_ID_SIZE*NUM_MONITORED_SIGS,
      parameter NUM_MON_SIGS_SIZE = log2(NUM_MONITORED_SIGS+2), // add 2 since timestamps are 2 words
      parameter SIMULATION = 0)
      (// interface to regs
       input                                 reset_timers,   // resets the timers
       input                                 enable_events,  // enables capture
       input       [NUM_MONITORED_SIGS-1:0]  monitor_mask,   // enables specific events
       input       [2**SIGNAL_ID_SIZE-1:0]   signal_id_mask, // filters based on signal id
       input       [TIMER_RES_SIZE-1:0]      tmr_resolution, // sets the resolution of the timers by 2*tmr_resolution
       output      [NUM_MON_SIGS_SIZE-1:0]   evts_dropped,   // number of events dropped this cycle

       // interface to events
       input       [NUM_MONITORED_SIGS-1:0]  signals,
       input       [ALL_SIG_VALUES_SIZE-1:0] signal_values,
       input       [ALL_SIGNAL_IDS_SIZE-1:0] signal_ids,

       // interface to evt_pkt_wrtr.v
       output      [DATA_WIDTH-1:0]          event_data,
       output                                evt_fifo_empty,
       input                                 evt_fifo_rd_en,
       input                                 new_evt_pkt,    // pulses high

       // misc
       input                                 reset,
       input                                 clk

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

   // We define a priority of events:
   //      1- a timer LSB wrap-around event
   //      2- signals NUM_MONITORED_SIGS-1..0
   //---------------------------- Local parameters ---------------------
   parameter SHORT_EVT_SIZE          = DATA_WIDTH/2;
   parameter LONG_EVT_SIZE           = 2*SHORT_EVT_SIZE;
   parameter EVT_TYPE_SIZE           = log2(NUM_MONITORED_SIGS+1); // one added for timestamp
   parameter TIME_DIFF_SIZE          = SHORT_EVT_SIZE-SIG_VALUE_SIZE-EVT_TYPE_SIZE-SIGNAL_ID_SIZE;
   parameter TIMESTAMP_SIZE          = LONG_EVT_SIZE-EVT_TYPE_SIZE;
   parameter NUM_RESOLUTIONS         = 2**TIMER_RES_SIZE;

   // synthesis translate_off
   defparam SIMULATION = 1;
   // synthesis translate_on

   //-------------------------Wire and Reg Declarations-----------------
   // local reset is active when evt. capture is disabled by user as well
   // as when global reset is active
   wire                                         local_reset;

   // signals a new timestamp event
   wire                                         ts_evt_sig;

   // event data from different events (including timestamps)
   reg  [SHORT_EVT_SIZE-1:0]                    evt_data [NUM_MONITORED_SIGS+1:0];
   wire [NUM_MONITORED_SIGS+1:0]                evt_signals;
   wire [TIME_DIFF_SIZE-1:0]                    evt_time_diff[NUM_MONITORED_SIGS+1:0];
   wire [SIG_VALUE_SIZE-1:0]                    evt_sig_value[NUM_MONITORED_SIGS-1:0];
   wire [SIGNAL_ID_SIZE-1:0]                    evt_sig_id[NUM_MONITORED_SIGS-1:0];
   wire [EVT_TYPE_SIZE-1:0]                     evt_type[NUM_MONITORED_SIGS-1:0];

   // Time difference counter
   reg [TIME_DIFF_SIZE+NUM_RESOLUTIONS-2:0]     time_diff_counter;
   wire [TIME_DIFF_SIZE-1:0]                    time_diff_scale [NUM_RESOLUTIONS-1:0];
   wire [TIME_DIFF_SIZE-1:0]                    time_diff_out;

   // time difference wrap around signals
   wire                                         time_diff_wrap;
   // resets counter
   wire                                         time_diff_rst;

   // Timestamp timer
   reg [TIMESTAMP_SIZE+NUM_RESOLUTIONS-2:0]     timestamp_counter;
   wire [TIMESTAMP_SIZE-1:0]                    timestamp_out;
   wire [TIMESTAMP_SIZE-1:0]                    timestamp_scale [NUM_RESOLUTIONS-1:0];
   wire                                         timestamp_rst;

   // the event data that are stored on every cycle (including timestamp events)
   wire [NUM_MON_SIGS_SIZE*(NUM_MONITORED_SIGS+2)-1:0] ordered_event_indices;
   wire [SHORT_EVT_SIZE*(NUM_MONITORED_SIGS+2)-1:0] events_to_store;

   // number of events to store in the fifo
   wire [NUM_MON_SIGS_SIZE-1:0]                 num_events;

   // wrap counter
   reg [TIMESTAMP_SIZE-1:0] 			wrap_counter;


   genvar                                       i;

   //-------------------------LSB part of the time stamp ---------------
   assign time_diff_out = timestamp_out[TIME_DIFF_SIZE-1:0];
   reg prev_bit;
   always @(posedge clk) begin
     if (local_reset) begin
       prev_bit <= 0;
     end
     else begin
       prev_bit <= timestamp_out[TIME_DIFF_SIZE];
     end
   end
   assign time_diff_wrap = (prev_bit != timestamp_out[TIME_DIFF_SIZE]);


   //-----------------------Timestamp Counter logic------------------------
   generate
      for(i=0; i<NUM_RESOLUTIONS; i=i+1) begin: timestamp_scale_assignments
         assign timestamp_scale[i] = timestamp_counter[TIMESTAMP_SIZE+i-1:i];
      end
   endgenerate
   assign timestamp_out=timestamp_scale[tmr_resolution];

   always @(posedge clk)
     timestamp_counter <= timestamp_rst? 0 : timestamp_counter + 1'b1;

   assign timestamp_rst= local_reset | reset_timers;

   //-------------------- Event Circuit Logic --------------------------
   // assign local reset
   assign local_reset=!enable_events | reset;

   // the timestamp event is caused by either a wrap of the time difference
   // timer or by a new pkt.
   assign ts_evt_sig = new_evt_pkt | time_diff_wrap;

   // create different event data sources
   generate
      // set the time difference for simultaneous events to 0;
      assign evt_time_diff[0]   = 0;
      assign evt_signals[0]     = ts_evt_sig;
      assign evt_time_diff[1]   = 0;
      assign evt_signals[1]     = ts_evt_sig;
      always @(posedge clk) begin
         evt_data[0]        <= {{EVT_TYPE_SIZE{1'b0}},timestamp_out[TIMESTAMP_SIZE-1:SHORT_EVT_SIZE]};
         evt_data[1]        <= timestamp_out[SHORT_EVT_SIZE-1:0];
      end
      for(i=2; i<NUM_MONITORED_SIGS+2; i=i+1) begin: data_sources
	 assign evt_time_diff[i]     = time_diff_out;
         assign evt_signals[i]       = signals[i-2] & monitor_mask[i-2] & signal_id_mask[evt_sig_id[i-2]];
         assign evt_sig_value[i-2]   = signal_values[SIG_VALUE_SIZE*(i-1)-1:SIG_VALUE_SIZE*(i-2)];
         assign evt_sig_id[i-2]      = signal_ids[SIGNAL_ID_SIZE*(i-1)-1:SIGNAL_ID_SIZE*(i-2)];
         assign evt_type[i-2]        = i - 1;
         always @(posedge clk) begin
            evt_data[i]          <= {evt_type[i-2],
                                     evt_sig_id[i-2],
                                     evt_sig_value[i-2],
                                     evt_time_diff[i]};
         end
      end // block: data_sources
   endgenerate

   //--------------------- Packer module ------------------------------
   /* Pack the signals so that all the valid ones are at
    * the lowest addresses. The output of this modules are the
    * numbers of the packed entries */
   parametrizable_packer
     #(.NUM_ENTRIES(NUM_MONITORED_SIGS+2)) parametrizable_packer
       (.valid_entries(evt_signals),
        .ordered_entries(ordered_event_indices),
        .num_valid_entries(num_events),
        .clk (clk),
        .reset (local_reset));

   //-------------------- Get the ordered events ----------------------
   generate
      for(i=0; i<NUM_MONITORED_SIGS+2; i = i+1) begin: events_to_store_assignments
         assign events_to_store[SHORT_EVT_SIZE*(i+1)-1:SHORT_EVT_SIZE*i] = evt_data[ordered_event_indices[NUM_MON_SIGS_SIZE*(i+1)-1:NUM_MON_SIGS_SIZE*i]];
      end
   endgenerate

   //------------------------- Event Fifo -----------------------------
   wire   event_fifo_full;

   // assign the number of events missed this clock if the fifo is full
   assign evts_dropped = event_fifo_full ? num_events : 0;

   // event fifo stores events as they come in according to priority
   wide_port_fifo
     #(.INPUT_WORD_SIZE(SHORT_EVT_SIZE),
       .NUM_INPUTS(NUM_MONITORED_SIGS+2))
       wide_port_fifo(
                      .d_in (events_to_store),
                      .increment(num_events),
                      .wr_en(|num_events & !event_fifo_full),
                      .rd_en(evt_fifo_rd_en),
                      .d_out(event_data),
                      .full(event_fifo_full),
                      .empty(evt_fifo_empty),
                      .num_words_in_fifo(),
                      .clk(clk),
                      .rst(local_reset)
                      );

endmodule
