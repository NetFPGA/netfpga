/*******************************************************************************
 * vim:set shiftwidth=3 softtabstop=3 expandtab:
 * $Id: opl_processor.v 3584 2008-04-10 19:54:57Z jnaous $
 *
 * Module: opl_processor.v
 * Project: generic lookups
 * Author: Jad Naous <jnaous@stanford.edu>
 * Description: Generic processor module that does nothing. Should be used as
 * a template for other designs. Counts number of passing packets from each port.
 *
 * The exact_wins and wildcard_wins are signalled with priority to exact.
 *
 ******************************************************************************/
`timescale 1ns/1ps

module opl_processor
  #(parameter NUM_OUTPUT_QUEUES = 8,
    parameter PKT_SIZE_WIDTH = 12,
    parameter NUM_RULE_BYTES = 48,
    parameter ENTRY_DATA_WIDTH = 128,
    parameter OPL_PROCESSOR_REG_ADDR_WIDTH = 6,   // needs to be overridden
    parameter OPL_PROCESSOR_BLOCK_TAG = 0,        // needs to be overridden
    parameter DATA_WIDTH = 64,
    parameter CTRL_WIDTH = DATA_WIDTH/8,
    parameter UDP_REG_SRC_WIDTH = 2)
  (// --- interface to lookups
   input                                   wildcard_hit,
   input                                   wildcard_miss,
   input[ENTRY_DATA_WIDTH-1:0]             wildcard_data,
   input                                   wildcard_data_vld,
   output reg                              wildcard_wins,
   output reg                              wildcard_loses,

   input                                   exact_hit,
   input                                   exact_miss,
   input[ENTRY_DATA_WIDTH-1:0]             exact_data,
   input                                   exact_data_vld,
   output reg                              exact_wins,
   output reg                              exact_loses,

   input [7:0]                             pkt_src_port,
   input                                   pkt_src_port_vld,

   // --- interface to input fifo
   input [CTRL_WIDTH-1:0]                  in_fifo_ctrl,
   input [DATA_WIDTH-1:0]                  in_fifo_data,
   output reg                              in_fifo_rd_en,
   input                                   in_fifo_empty,

   // --- interface to output
   output reg [DATA_WIDTH-1:0]             out_data,
   output reg [CTRL_WIDTH-1:0]             out_ctrl,
   output reg                              out_wr,
   input                                   out_rdy,

   // --- interface to register bus
   input                                   reg_req_in,
   input                                   reg_ack_in,
   input                                   reg_rd_wr_L_in,
   input  [`UDP_REG_ADDR_WIDTH-1:0]        reg_addr_in,
   input  [`CPCI_NF2_DATA_WIDTH-1:0]       reg_data_in,
   input  [UDP_REG_SRC_WIDTH-1:0]          reg_src_in,

   output                                  reg_req_out,
   output                                  reg_ack_out,
   output                                  reg_rd_wr_L_out,
   output  [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_out,
   output  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_data_out,
   output  [UDP_REG_SRC_WIDTH-1:0]         reg_src_out,

   // --- Misc
   input                                   clk,
   input                                   reset);

   `LOG2_FUNC
   `CEILDIV_FUNC

   //-------------------- Internal Parameters ------------------------
   localparam NUM_STATES = 2;
   localparam WAIT_FOR_LOOKUPS         = 1,
              WRITE_PACKET             = 2;

   //------------------------ Wires/Regs -----------------------------
   reg [NUM_STATES-1:0]                            state, state_nxt;
   reg                                             out_wr_nxt;
   reg [DATA_WIDTH-1:0]                            out_data_nxt;
   reg [CTRL_WIDTH-1:0]                            out_ctrl_nxt;

   reg                                             rd_wildcard_hit_fifo;
   reg                                             rd_wildcard_data_fifo;
   wire [ENTRY_DATA_WIDTH-1:0]                     dout_wildcard_data;

   reg                                             rd_exact_hit_fifo;
   reg                                             rd_exact_data_fifo;
   wire [ENTRY_DATA_WIDTH-1:0]                     dout_exact_data;

   reg                                             rd_src_port_fifo;
   wire [log2(NUM_OUTPUT_QUEUES)-1:0]              dout_pkt_src_port;

   reg [NUM_OUTPUT_QUEUES-1:0]                     src_port_decoded;
   reg  [NUM_OUTPUT_QUEUES-1:0]                    pkts_passed;
   reg [NUM_OUTPUT_QUEUES-1:0]                     pkts_passed_nxt;

   reg                                             in_fifo_ctrl_prev_0;

   //-------------------------- Modules ------------------------------

   /* store the input into fifos until we are ready to use it. */
   fallthrough_small_fifo
     #(.WIDTH(1), .MAX_DEPTH_BITS(2))
      wildcard_hit_fifo
        (.din           (wildcard_hit),
         .wr_en         (wildcard_hit | wildcard_miss),
         .rd_en         (rd_wildcard_hit_fifo),
         .dout          (dout_wildcard_hit),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (wildcard_hit_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   fallthrough_small_fifo
     #(.WIDTH(ENTRY_DATA_WIDTH), .MAX_DEPTH_BITS(2))
      wildcard_data_fifo
        (.din           (wildcard_data),
         .wr_en         (wildcard_data_vld | wildcard_miss),
         .rd_en         (rd_wildcard_data_fifo),
         .dout          (dout_wildcard_data),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (wildcard_data_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   fallthrough_small_fifo
     #(.WIDTH(1), .MAX_DEPTH_BITS(2))
      exact_hit_fifo
        (.din           (exact_hit),
         .wr_en         (exact_hit | exact_miss),
         .rd_en         (rd_exact_hit_fifo),
         .dout          (dout_exact_hit),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (exact_hit_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   fallthrough_small_fifo
     #(.WIDTH(ENTRY_DATA_WIDTH), .MAX_DEPTH_BITS(2))
      exact_data_fifo
        (.din           (exact_data),
         .wr_en         (exact_data_vld | exact_miss),
         .rd_en         (rd_exact_data_fifo),
         .dout          (dout_exact_data),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (exact_data_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   fallthrough_small_fifo
     #(.WIDTH(log2(NUM_OUTPUT_QUEUES)), .MAX_DEPTH_BITS(2))
      src_port_fifo
        (.din           (pkt_src_port[log2(NUM_OUTPUT_QUEUES)-1:0]),
         .wr_en         (pkt_src_port_vld),
         .rd_en         (rd_src_port_fifo),
         .dout          (dout_pkt_src_port),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (src_port_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   generic_regs
     #(.UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
       .TAG (OPL_PROCESSOR_BLOCK_TAG),
       .REG_ADDR_WIDTH (OPL_PROCESSOR_REG_ADDR_WIDTH),
       .NUM_COUNTERS (NUM_OUTPUT_QUEUES),
       .RESET_ON_READ (0),
       .NUM_SOFTWARE_REGS (0),
       .NUM_HARDWARE_REGS (0),
       .COUNTER_INPUT_WIDTH (1)
       )
   generic_regs
     (
      .reg_req_in        (reg_req_in),
      .reg_ack_in        (reg_ack_in),
      .reg_rd_wr_L_in    (reg_rd_wr_L_in),
      .reg_addr_in       (reg_addr_in),
      .reg_data_in       (reg_data_in),
      .reg_src_in        (reg_src_in),

      .reg_req_out       (reg_req_out),
      .reg_ack_out       (reg_ack_out),
      .reg_rd_wr_L_out   (reg_rd_wr_L_out),
      .reg_addr_out      (reg_addr_out),
      .reg_data_out      (reg_data_out),
      .reg_src_out       (reg_src_out),

      // --- counters interface
      .counter_updates   (pkts_passed),
      .counter_decrement ({NUM_OUTPUT_QUEUES{1'b0}}),

      // --- SW regs interface
      .software_regs     (),

      // --- HW regs interface
      .hardware_regs     (),

      .clk               (clk),
      .reset             (reset));

   //-------------------------- Logic --------------------------------
   /* decode source port */
   always @(*) begin
      src_port_decoded = 0;
      src_port_decoded[dout_pkt_src_port] = 1'b1;
   end

   always @(*) begin
      state_nxt               = state;
      out_wr_nxt              = 0;
      out_data_nxt            = in_fifo_data;
      out_ctrl_nxt            = in_fifo_ctrl;
      in_fifo_rd_en           = 0;
      pkts_passed_nxt         = 0;

      rd_exact_data_fifo      = 1'b0;
      rd_exact_hit_fifo       = 1'b0;
      rd_wildcard_data_fifo   = 1'b0;
      rd_wildcard_hit_fifo    = 1'b0;
      rd_src_port_fifo        = 1'b0;

      exact_wins              = 1'b0;
      exact_loses             = 1'b0;
      wildcard_wins           = 1'b0;
      wildcard_loses          = 1'b0;

      case (state)
         WAIT_FOR_LOOKUPS: begin
            if(!exact_hit_fifo_empty && !wildcard_hit_fifo_empty
               && !exact_data_fifo_empty && !wildcard_data_fifo_empty
               && out_rdy) begin

               exact_wins              = dout_exact_hit;
               exact_loses             = !dout_exact_hit;
               wildcard_wins           = !dout_exact_hit && dout_wildcard_hit;
               wildcard_loses          = dout_exact_hit || !dout_wildcard_hit;

               rd_exact_data_fifo      = 1'b1;
               rd_exact_hit_fifo       = 1'b1;
               rd_wildcard_data_fifo   = 1'b1;
               rd_wildcard_hit_fifo    = 1'b1;
               rd_src_port_fifo        = 1'b1;

               state_nxt               = WRITE_PACKET;
               pkts_passed_nxt         = src_port_decoded;

               out_wr_nxt              = 1'b1;
               in_fifo_rd_en           = 1'b1;
            end
         end

         /* write the rest of the module headers and the packet data */
         WRITE_PACKET: begin
            if(out_rdy && !in_fifo_empty) begin
               out_wr_nxt      = 1'b1;
               in_fifo_rd_en   = 1'b1;
               if(in_fifo_ctrl !=0 && in_fifo_ctrl_prev_0 == 1) begin // eop
                  state_nxt = WAIT_FOR_LOOKUPS;
               end
            end
         end // case: WRITE_PACKET
      endcase // case(state)
   end // always @ (*)

   always @(posedge clk) begin
      if (reset) begin
         state           <= WAIT_FOR_LOOKUPS;
         out_wr          <= 0;
         out_data        <= 0;
         out_ctrl        <= 1;
         pkts_passed     <= 0;
         in_fifo_ctrl_prev_0 <= 0;
      end
      else begin
         state           <= state_nxt;
         out_wr          <= out_wr_nxt;
         out_data        <= out_data_nxt;
         out_ctrl        <= out_ctrl_nxt;
         pkts_passed     <= pkts_passed_nxt;
         if(in_fifo_rd_en)  in_fifo_ctrl_prev_0 <= in_fifo_ctrl == 0;
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // opl_processor


