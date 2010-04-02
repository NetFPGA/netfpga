///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: evt_capture_top.v 1980 2007-07-20 01:37:59Z grg $
//
// Module: evt_capture_top.v
// Project: event capture
// Description: Top file that is the event capture subsystem module instantiated
//              in the user data path.
//
///////////////////////////////////////////////////////////////////////////////

module evt_capture_top
  #(parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = DATA_WIDTH/8,
    parameter UDP_REG_SRC_WIDTH = 2,
    parameter NUM_ABS_REG_PAIRS = 4,
    parameter NUM_MONITORED_SIGS = 3,
    parameter SIGNAL_ID_SIZE = 3,
    parameter SIG_VALUE_SIZE = 8,
    parameter OP_LUT_STAGE_NUM = 4,
    parameter ALL_SIGNAL_IDS_SIZE = SIGNAL_ID_SIZE*NUM_MONITORED_SIGS,
    parameter ALL_SIG_VALUES_SIZE = SIG_VALUE_SIZE*NUM_MONITORED_SIGS)
    (// interface to output data path
     output [DATA_WIDTH-1:0]     out_data,
     output [CTRL_WIDTH-1:0]     out_ctrl,
     output                      out_wr,
     input                       out_rdy,

     // interface to input data path
     input  [DATA_WIDTH-1:0]     in_data,
     input  [CTRL_WIDTH-1:0]     in_ctrl,
     input                       in_wr,
     output                      in_rdy,

     // register interface
     input                              reg_req_in,
     input                              reg_ack_in,
     input                              reg_rd_wr_L_in,
     input  [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_in,
     input  [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_in,
     input  [UDP_REG_SRC_WIDTH-1:0]     reg_src_in,

     output                             reg_req_out,
     output                             reg_ack_out,
     output                             reg_rd_wr_L_out,
     output  [`UDP_REG_ADDR_WIDTH-1:0]  reg_addr_out,
     output  [`CPCI_NF2_DATA_WIDTH-1:0] reg_data_out,
     output  [UDP_REG_SRC_WIDTH-1:0]    reg_src_out,

     // interface to events
     input [NUM_MONITORED_SIGS-1:0]  signals,
     input [ALL_SIG_VALUES_SIZE-1:0] signal_values,
     input [ALL_SIGNAL_IDS_SIZE-1:0] signal_ids,
     input [DATA_WIDTH*NUM_ABS_REG_PAIRS-1:0] reg_values,

     // misc
     input reset,
     input clk);


   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   //-------------------- Local parameters ------------------------
   parameter TIMER_RES_SIZE = 3;
   parameter HEADER_LENGTH = 7;
   parameter EVT_CAPTURE_VERSION = 4'h1;
   parameter HEADER_LENGTH_SIZE = log2(HEADER_LENGTH);
   parameter NUM_MON_SIGS_SIZE = log2(NUM_MONITORED_SIGS+2);

   //---------------- Wire and Reg Declarations -------------------
   wire			enable_events;		// From evt_capture_regs of evt_capture_regs.v
   wire [DATA_WIDTH-1:0]event_data;		// From evt_rcrdr of evt_rcrdr.v
   wire			evt_fifo_empty;		// From evt_rcrdr of evt_rcrdr.v
   wire			evt_fifo_rd_en;		// From evt_pkt_wrtr of evt_pkt_wrtr.v
   wire			evt_pkt_sent;		// From evt_pkt_wrtr of evt_pkt_wrtr.v
   wire [NUM_MON_SIGS_SIZE-1:0]evts_dropped;	// From evt_rcrdr of evt_rcrdr.v
   wire [CTRL_WIDTH-1:0]header_ctrl;		// From evt_capture_regs of evt_capture_regs.v
   wire [DATA_WIDTH-1:0]header_data;		// From evt_capture_regs of evt_capture_regs.v
   wire [HEADER_LENGTH_SIZE-1:0]header_word_number;// From evt_pkt_wrtr of evt_pkt_wrtr.v
   wire [NUM_MONITORED_SIGS-1:0]monitor_mask;	// From evt_capture_regs of evt_capture_regs.v
   wire			new_evt_pkt;		// From evt_pkt_wrtr of evt_pkt_wrtr.v
   wire [8:0]		num_evts_in_pkt;	// From evt_pkt_wrtr of evt_pkt_wrtr.v
   wire			reset_timers;		// From evt_capture_regs of evt_capture_regs.v
   wire			send_pkt;		// From evt_capture_regs of evt_capture_regs.v
   wire [TIMER_RES_SIZE-1:0]tmr_resolution;	// From evt_capture_regs of evt_capture_regs.v
   wire [2**SIGNAL_ID_SIZE-1:0] signal_id_mask;

   //--------------------- Modules ------------------------------
   evt_rcrdr
     #(.NUM_MONITORED_SIGS(NUM_MONITORED_SIGS),
       .SIGNAL_ID_SIZE (SIGNAL_ID_SIZE),
       .SIG_VALUE_SIZE (SIG_VALUE_SIZE),
       .DATA_WIDTH(DATA_WIDTH),
       .TIMER_RES_SIZE (TIMER_RES_SIZE)) evt_rcrdr
     (// Outputs
      .evts_dropped			(evts_dropped[NUM_MON_SIGS_SIZE-1:0]),
      .event_data			(event_data[DATA_WIDTH-1:0]),
      .evt_fifo_empty			(evt_fifo_empty),
      // Inputs
      .reset_timers                     (reset_timers),
      .enable_events			(enable_events),
      .monitor_mask			(monitor_mask[NUM_MONITORED_SIGS-1:0]),
      .tmr_resolution			(tmr_resolution[TIMER_RES_SIZE-1:0]),
      .signals				(signals[NUM_MONITORED_SIGS-1:0]),
      .signal_values			(signal_values[ALL_SIG_VALUES_SIZE-1:0]),
      .signal_id_mask                   (signal_id_mask),
      .signal_ids                       (signal_ids),
      .evt_fifo_rd_en			(evt_fifo_rd_en),
      .new_evt_pkt			(new_evt_pkt),
      .reset				(reset),
      .clk				(clk));

   evt_pkt_wrtr
     #(.DATA_WIDTH (DATA_WIDTH),
       .CTRL_WIDTH (CTRL_WIDTH),
       .NUM_ABS_REG_PAIRS (NUM_ABS_REG_PAIRS),
       .NUM_MONITORED_SIGS(NUM_MONITORED_SIGS),
       .HEADER_LENGTH (HEADER_LENGTH)) evt_pkt_wrtr
     (// Outputs
      .evt_fifo_rd_en			(evt_fifo_rd_en),
      .new_evt_pkt			(new_evt_pkt),
      .out_data				(out_data[DATA_WIDTH-1:0]),
      .out_ctrl				(out_ctrl[CTRL_WIDTH-1:0]),
      .out_wr				(out_wr),
      .in_rdy				(in_rdy),
      .header_word_number		(header_word_number[HEADER_LENGTH_SIZE-1:0]),
      .evt_pkt_sent			(evt_pkt_sent),
      .num_evts_in_pkt			(num_evts_in_pkt[8:0]),
      // Inputs
      .event_data                       (event_data),
      .evt_fifo_empty			(evt_fifo_empty),
      .out_rdy				(out_rdy),
      .in_data				(in_data[DATA_WIDTH-1:0]),
      .in_ctrl				(in_ctrl[CTRL_WIDTH-1:0]),
      .in_wr				(in_wr),
      .reg_values			(reg_values[DATA_WIDTH*NUM_ABS_REG_PAIRS-1:0]),
      .send_pkt				(send_pkt),
      .header_data			(header_data[DATA_WIDTH-1:0]),
      .header_ctrl			(header_ctrl[CTRL_WIDTH-1:0]),
      .enable_events			(enable_events),
      .reset				(reset),
      .clk				(clk));

   evt_capture_regs
     #(.DATA_WIDTH (DATA_WIDTH),
       .CTRL_WIDTH (CTRL_WIDTH),
       .UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
       .NUM_MONITORED_SIGS (NUM_MONITORED_SIGS),
       .NUM_ABS_REG_PAIRS (NUM_ABS_REG_PAIRS),
       .SIGNAL_ID_SIZE (SIGNAL_ID_SIZE),
       .TIMER_RES_SIZE(TIMER_RES_SIZE),
       .HEADER_LENGTH (HEADER_LENGTH),
       .OP_LUT_STAGE_NUM (OP_LUT_STAGE_NUM),
       .EVT_CAPTURE_VERSION(EVT_CAPTURE_VERSION))
     evt_capture_regs
     (
      // Registers
      .reg_req_in       (reg_req_in),
      .reg_ack_in       (reg_ack_in),
      .reg_rd_wr_L_in   (reg_rd_wr_L_in),
      .reg_addr_in      (reg_addr_in),
      .reg_data_in      (reg_data_in),
      .reg_src_in       (reg_src_in),

      .reg_req_out      (reg_req_out),
      .reg_ack_out      (reg_ack_out),
      .reg_rd_wr_L_out  (reg_rd_wr_L_out),
      .reg_addr_out     (reg_addr_out),
      .reg_data_out     (reg_data_out),
      .reg_src_out      (reg_src_out),

      // Outputs
      .send_pkt				(send_pkt),
      .header_data			(header_data[DATA_WIDTH-1:0]),
      .header_ctrl			(header_ctrl[CTRL_WIDTH-1:0]),
      .enable_events			(enable_events),
      .reset_timers			(reset_timers),
      .monitor_mask			(monitor_mask[NUM_MONITORED_SIGS-1:0]),
      .signal_id_mask                   (signal_id_mask),
      .tmr_resolution			(tmr_resolution[TIMER_RES_SIZE-1:0]),
      // Inputs
      .header_word_number		(header_word_number[HEADER_LENGTH_SIZE-1:0]),
      .evt_pkt_sent			(evt_pkt_sent),
      .num_evts_in_pkt			(num_evts_in_pkt[8:0]),
      .evts_dropped			(evts_dropped[NUM_MON_SIGS_SIZE-1:0]),
      .clk				(clk),
      .reset				(reset));

endmodule // evt_capture_top
