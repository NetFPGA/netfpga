///////////////////////////////////////////////////////////////////////////////
// $Id: mac_cam_lut.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: mac_lut.v
// Project: NF2.1
// Description: Looks up the mac<->output port mapping for a given MAC address
//              and can learn new mappings
//
//              Does not assume that the inputs are held, so it latches them
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
  module mac_cam_lut
    #(parameter NUM_OUTPUT_QUEUES = 8,
      parameter LUT_DEPTH_BITS = 4,
      parameter LUT_DEPTH = 2**LUT_DEPTH_BITS,
      parameter NUM_IQ_BITS = 3,
      parameter DEFAULT_MISS_OUTPUT_PORTS = 8'h55) // only send to the txfifos not the cpu

   ( // --- lookup and learn port
     input [47:0]                       dst_mac,
     input [47:0]                       src_mac,
     input [NUM_IQ_BITS-1:0]            src_port,
     input                              lookup_req,
     output     [NUM_OUTPUT_QUEUES-1:0] dst_ports,
     output reg                         lookup_ack,

     // --- direct access ports
     // --- Read port
     input [LUT_DEPTH_BITS-1:0]         rd_addr,          // address in table to read
     input                              rd_req,           // request a read
     output [NUM_OUTPUT_QUEUES-1:0]     rd_oq,            // data read from the LUT at rd_addr
     output                             rd_wr_protect,    // wr_protect bit read
     output [47:0]                      rd_mac,    // data to match in the CAM
     output reg                         rd_ack,

     // --- Write port
     input [LUT_DEPTH_BITS-1:0]         wr_addr,
     input                              wr_req,
     input [NUM_OUTPUT_QUEUES-1:0]      wr_oq,
     input                              wr_protect,       // wr_protect bit to write
     input [47:0]                       wr_mac,    // data to match in the CAM
     output reg                         wr_ack,

     // --- Register signals
     output reg                         lut_hit,          // pulses high on a hit
     output reg                         lut_miss,         // pulses high on a miss

     // --- Misc
     input                              clk,
     input                              reset

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

   //--------------------- Internal Parameter-------------------------
   parameter RESET            = 1;
   parameter IDLE             = 2;
   parameter LATCH_DST_LOOKUP = 4;
   parameter CHECK_SRC_MATCH  = 8;
   parameter UPDATE_ENTRY     = 16;
   parameter ADD_ENTRY        = 32;

   //---------------------- Wires and regs----------------------------

   wire                                  cam_busy;
   wire                                  cam_match;
   wire [LUT_DEPTH_BITS-1:0]             cam_match_addr;
   reg  [LUT_DEPTH_BITS-1:0]             cam_match_addr_d1;
   reg  [47:0]                           cam_cmp_din;
   reg  [47:0]                           cam_din, cam_din_next;
   reg                                   cam_we, cam_we_next;
   reg  [LUT_DEPTH_BITS-1:0]             cam_wr_addr, cam_wr_addr_next;

   wire [NUM_OUTPUT_QUEUES-1:0]          decoded_value[NUM_OUTPUT_QUEUES-1:0];
   reg  [NUM_OUTPUT_QUEUES-1:0]          src_port_decoded;
   reg  [47:0]                           src_mac_latched;
   reg                                   latch_src;

   reg  [5:0]                            lookup_state, lookup_state_next;

   reg [LUT_DEPTH_BITS-1:0]              lut_rd_addr, lut_wr_addr, lut_wr_addr_next;
   reg                                   lut_wr_en, lut_wr_en_next;
   reg [NUM_OUTPUT_QUEUES+48:0]          lut_wr_data, lut_wr_data_next;
   reg [NUM_OUTPUT_QUEUES+48:0]          lut_rd_data;
   reg [NUM_OUTPUT_QUEUES+48:0]          lut[LUT_DEPTH-1:0];

   reg                                   reset_count_inc;
   reg [LUT_DEPTH_BITS:0]                reset_count;
   reg                                   wr_ack_next, rd_ack_next;
   reg                                   lookup_ack_next;
   reg                                   lut_hit_next, lut_miss_next;

   //------------------------- Modules-------------------------------

   // 1 cycle read latency, 16 cycles write latency
   cam_16x48 mac_cam
     (
      // Outputs
      .busy                             (cam_busy),
      .match                            (cam_match),
      .match_addr                       (cam_match_addr[LUT_DEPTH_BITS-1:0]),
      // Inputs
      .clk                              (clk),
      .cmp_din                          (cam_cmp_din[47:0]),
      .din                              (cam_din[47:0]),
      .we                               (cam_we),
      .wr_addr                          (cam_wr_addr[LUT_DEPTH_BITS-1:0]));

   //------------------------- Logic --------------------------------

   /* decode the source port number */
   generate
      genvar i;
      for(i=0; i<NUM_OUTPUT_QUEUES; i=i+1) begin: decoder
         assign decoded_value[i] = 2**i;
      end
   endgenerate

   /* assign lut outputs */
   assign rd_oq = lut_rd_data[NUM_OUTPUT_QUEUES+47:48];
   assign rd_mac = lut_rd_data[47:0];
   assign rd_wr_protect = lut_rd_data[NUM_OUTPUT_QUEUES+48];

   /* if we get a miss then set the dst port to the default ports
    * without the source */
   assign dst_ports = (lookup_ack & lut_miss) ? (DEFAULT_MISS_OUTPUT_PORTS & ~src_port_decoded)
                                           : (rd_oq & ~src_port_decoded);

   assign entry_needs_update = ((rd_oq!=src_port_decoded) && !rd_wr_protect);

   always @(*) begin
      cam_wr_addr_next = cam_match_addr;
      cam_din_next     = src_mac_latched;
      cam_we_next      = 0;
      cam_cmp_din      = 0;
      lut_rd_addr      = cam_match_addr;
      lut_wr_en_next   = 1'b0;
      lut_wr_data_next = {1'b0, src_port_decoded, src_mac_latched};
      lut_wr_addr_next = cam_match_addr;
      reset_count_inc  = 0;
      wr_ack_next      = 0;
      rd_ack_next      = 0;
      latch_src        = 0;
      lookup_ack_next  = 0;
      lut_hit_next     = 0;
      lut_miss_next    = 0;

      lookup_state_next = lookup_state;

      case(lookup_state)
        /* write to all locations */
        RESET: begin
           if( !cam_we && !cam_busy && reset_count < LUT_DEPTH-1) begin
              cam_wr_addr_next = reset_count;
              cam_we_next = 1;
              cam_din_next = 0;
              reset_count_inc = 1;
              lut_wr_addr_next = reset_count;
              lut_wr_data_next = 0;
              lut_wr_en_next = 1;
           end
           // write the broadcast
           else if( !cam_we && !cam_busy && reset_count == LUT_DEPTH-1) begin
              cam_wr_addr_next = reset_count;
              cam_we_next = 1;
              cam_din_next = ~48'h0;
              reset_count_inc = 1;
              // write the broadcast address
              lut_wr_addr_next = reset_count;
              lut_wr_data_next = {1'b1, DEFAULT_MISS_OUTPUT_PORTS, ~48'h0};
              lut_wr_en_next = 1;
           end
           else if( !cam_we && !cam_busy) begin
              lookup_state_next = IDLE;
           end
        end // case: RESET

        IDLE: begin
           if(wr_req && !cam_busy && !cam_we) begin
              cam_we_next = 1;
              cam_wr_addr_next = wr_addr;
              cam_din_next = wr_mac;
              lut_wr_data_next = {wr_protect, wr_oq, wr_mac};
              lut_wr_addr_next = wr_addr;
              wr_ack_next = 1;
              lut_wr_en_next = 1;
           end
           if(rd_req && !cam_busy && !cam_we) begin
              lut_rd_addr = rd_addr;
              rd_ack_next = 1;
           end
           cam_cmp_din = dst_mac;
           if(lookup_req && !lookup_ack) begin
              lookup_state_next = LATCH_DST_LOOKUP;
              latch_src = 1;
           end
        end // case: IDLE

        LATCH_DST_LOOKUP: begin
           /* latch the info from the lut if we have a match */
           if(cam_match) begin
              lookup_ack_next = 1;
              lut_hit_next = 1;
           end
           /* otherwise return the default address */
           else begin
              lookup_ack_next = 1;
              lut_miss_next = 1;
           end // else: !if(cam_match)

           /* if the cam is not busy, then see if the source mac is in the table */
           cam_cmp_din = src_mac_latched;
           if(!cam_busy) begin
              lookup_state_next = CHECK_SRC_MATCH;
           end
           else begin
              lookup_state_next = IDLE;
           end
        end // case: LATCH_DST_LOOKUP

        CHECK_SRC_MATCH: begin
           /* look for an empty address in case we need it */
           cam_cmp_din = 0;
           /* if we have a match then wait for lut output */
           if(cam_match) begin
              lookup_state_next = UPDATE_ENTRY;
           end
           /* otherwise we need to add the entry */
           else begin
              lookup_state_next = ADD_ENTRY;
           end
        end // case: CHECK_SRC_MATCH

        UPDATE_ENTRY: begin
           if(entry_needs_update) begin
              lut_wr_addr_next = cam_match_addr_d1;
              lut_wr_en_next = 1;
           end
           lookup_state_next = IDLE;
        end

        ADD_ENTRY: begin
           /* if we found an empty spot */
           if(cam_match) begin
              lut_wr_addr_next = cam_match_addr;
              lut_wr_en_next = 1;
              cam_wr_addr_next = cam_match_addr;
              cam_we_next = 1;
           end
           lookup_state_next = IDLE;
        end

        default: begin end
      endcase // case(lookup_state)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         lut_rd_data       <= 0;
         reset_count       <= 0;
         wr_ack            <= 0;
         rd_ack            <= 0;
         src_port_decoded  <= 0;
         src_mac_latched   <= 0;
         lookup_ack        <= 0;
         lut_hit           <= 0;
         lut_miss          <= 0;
         cam_match_addr_d1 <= 0;

         cam_wr_addr       <= 0;
         cam_din           <= 0;
         cam_we            <= 0;
         lut_wr_en         <= 0;
         lut_wr_data       <= 0;
         lut_wr_addr       <= 0;

         lookup_state      <= RESET;
      end
      else begin
         reset_count       <= reset_count_inc ? reset_count + 1 : reset_count;
         wr_ack            <= wr_ack_next;
         rd_ack            <= rd_ack_next;
         src_port_decoded  <= latch_src ? decoded_value[src_port] : src_port_decoded;
         src_mac_latched   <= latch_src ? src_mac : src_mac_latched;
         if(lookup_ack_next) begin
            lookup_ack        <= 1;
         end
         else if(!lookup_req) begin
            lookup_ack        <= 0;
         end
         lut_hit           <= lut_hit_next;
         lut_miss          <= lut_miss_next;

         lut_rd_data       <= lut[lut_rd_addr];
         if(lut_wr_en) begin
            lut[lut_wr_addr] <= lut_wr_data;
         end

         cam_match_addr_d1 <= cam_match_addr;

         cam_wr_addr       <= cam_wr_addr_next;
         cam_din           <= cam_din_next;
         cam_we            <= cam_we_next;
         lut_wr_en         <= lut_wr_en_next;
         lut_wr_data       <= lut_wr_data_next;
         lut_wr_addr       <= lut_wr_addr_next;

         lookup_state      <= lookup_state_next;
      end
   end

   // synthesis translate_off
   always @(posedge clk) begin
      if(lookup_state==LATCH_DST_LOOKUP && cam_busy && src_mac_latched == dst_mac) begin
         $display("%t %m WARNING: requested lookup for addr %012x while CAM is busy writing it. Returning broadcast.", $time, dst_mac);
      end
   end
   // synthesis translate_on

endmodule // mac_lut






