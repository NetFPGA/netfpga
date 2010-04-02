///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: cnet_sram_sm.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: cnet_sram_sm.v
// Project: NetFPGA-1G
// Description: CNET SRAM controller
//
// Accepts requests for reading or writing and then services them in some
// sort of round-robin order.
//
// Set up to drive a Cypress cy7c1370 NOBL part (512Kx36), but anything with
// two clock delay from addr to data should be OK.
//
// We do not exploit the NOBL feature but instead we provide a bus turn around
// cycle because we can afford to do it.
//
///////////////////////////////////////////////////////////////////////////////

`timescale  1ns /  10ps
module cnet_sram_sm  #(parameter SRAM_ADDR_WIDTH = 19,
                       parameter SRAM_DATA_WIDTH = 36 )

   (

   // --- Requesters (read and/or write)

   input                               wr_0_req,
   input      [SRAM_ADDR_WIDTH-1:0]    wr_0_addr,
   input      [SRAM_DATA_WIDTH-1:0]    wr_0_data,
   output reg                          wr_0_ack,

   input                               wr_1_req,
   input      [SRAM_ADDR_WIDTH-1:0]    wr_1_addr,
   input      [SRAM_DATA_WIDTH-1:0]    wr_1_data,
   output reg                          wr_1_ack,

   input                               rd_0_req,
   input      [SRAM_ADDR_WIDTH-1:0]    rd_0_addr,
   output reg [SRAM_DATA_WIDTH-1:0]    rd_0_data,
   output reg                          rd_0_ack,
   output reg                          rd_0_vld,

   input                               rd_1_req,
   input      [SRAM_ADDR_WIDTH-1:0]    rd_1_addr,
   output reg [SRAM_DATA_WIDTH-1:0]    rd_1_data,
   output reg                          rd_1_ack,
   output reg                          rd_1_vld,

   // --- SRAM signals (pins and control)

   output reg [SRAM_ADDR_WIDTH-1:0]    sram_addr,
   output reg                          sram_we,
   output reg [SRAM_DATA_WIDTH/9-1:0]  sram_bw,
   output reg [SRAM_DATA_WIDTH-1:0]    sram_wr_data,
   input      [SRAM_DATA_WIDTH-1:0]    sram_rd_data,
   output reg                          sram_tri_en,

   // --- Misc

   input reset,
   input clk

   );

   //
   // --- The state machine
   //

   reg [1:0] access, access_nxt, req_type;
   reg       state, state_nxt, ack_nxt, ld_count,choose_nxt;
   reg [4:0] count, count_next;
   reg       request, ld_addr;
   reg [2:0] is_read;   // need to track the delayed access type to decide when
                        // the read data is valid.
   reg [SRAM_DATA_WIDTH-1:0] rd_data;

   reg [1:0] current_port, next_port;

   always @(posedge clk) rd_data <= sram_rd_data;

   // specify different access types. (NULL becomes a read)

   parameter NULL = 0,
             WRITE = 1,
             READ = 2;

   parameter IDLE = 0,
             BUSY = 1;

   always @* begin

      // set defaults

      ack_nxt    = 0;
      ld_count   = 0;
      state_nxt  = state;
      access_nxt = NULL;
      choose_nxt = 0;
      ld_addr = 0;

      case (state)

        IDLE: begin

           if (request) begin  // go service the request
              ack_nxt = 1;
              ld_count = 1;
              ld_addr = 1;
              state_nxt = BUSY;
           end
           else                // Still nuthing happenin'
             begin
                choose_nxt = 1;
             end
        end

        BUSY: begin

           if (!request) begin
              choose_nxt = 1;
              state_nxt = IDLE;
           end
           else if (count == 0 && next_port!=current_port) begin
              choose_nxt = 1;
              ld_addr    = 1;  // latch the selected address (and wr data)
              access_nxt = req_type;
              state_nxt  = IDLE;
           end
           else begin
              ack_nxt = 1;
              ld_addr = 1;  // latch the selected address (and wr data)
              access_nxt = req_type;
           end

        end

      endcase
   end // always @ *

   always @(posedge clk)
     if (reset) state <= IDLE;
     else state <= state_nxt;

   // simple counter to decide when to pre-empt current requester

   always @(posedge clk)
     if (reset) count <= 'h0;
     else
       if (ld_count) count <= count_next;
       else if (count != 0) count <= count - 1;

   //
   // --- OK, now we choose which port to service
   //

   parameter WR_0 = 0,
             WR_1 = 1,
             RD_0 = 2,
             RD_1 = 3;

   /* skew the counts so writes have more bw
    * This is needed to not have drops at the rx queues */
   always @* begin

      next_port = current_port;
      count_next = 20;

      case (current_port)

        WR_0: begin
           if (wr_1_req) next_port = WR_1;
           else if (rd_0_req) next_port = RD_0;
           else if (rd_1_req) next_port = RD_1;
           count_next = 20;
        end

        WR_1: begin
           if (rd_0_req) next_port = RD_0;
           else if (rd_1_req) next_port = RD_1;
           else if (wr_0_req) next_port = WR_0;
           count_next = 20;
        end

        RD_0: begin
           if (rd_1_req) next_port = RD_1;
           else if (wr_0_req) next_port = WR_0;
           else if (wr_1_req) next_port = WR_1;
           count_next = 15;
        end

        RD_1: begin
           if (wr_0_req) next_port = WR_0;
           else if (wr_1_req) next_port = WR_1;
           else if (rd_0_req) next_port = RD_0;
           count_next = 15;
        end

      endcase

   end

   always @(posedge clk)
     if (reset)
       current_port <= WR_0;
     else
       current_port <= (choose_nxt) ? next_port : current_port;

   // select/decode various signals

   reg [SRAM_ADDR_WIDTH-1:0]  addr_nxt;
   reg [SRAM_DATA_WIDTH-1:0]  wr_data_early_nxt, wr_data_early,wr_data_ph1 ;
   reg                        tri_en_ph1;

   always @* begin

      wr_data_early_nxt = wr_0_data;

      case (current_port)
        WR_0 : begin
           request  = wr_0_req;
           addr_nxt = wr_0_addr;
           wr_data_early_nxt = wr_0_data;
           req_type = WRITE;
        end
        WR_1 : begin
           request  = wr_1_req;
           addr_nxt = wr_1_addr;
           wr_data_early_nxt = wr_1_data;
           req_type = WRITE;
        end
        RD_0 : begin
           request  = rd_0_req;
           addr_nxt = rd_0_addr;
           req_type = READ;
        end
        RD_1 : begin
           request  = rd_1_req;
           addr_nxt = rd_1_addr;
           req_type = READ;
        end
        default: begin
           request = 0;
           addr_nxt = sram_addr;
           req_type = 0;
        end
      endcase
   end

   // Generate signals to the SRAM

   // latch the address and write data. Delay data by two extra clocks.

   reg [3:0] rd_0_ack_del, rd_1_ack_del;

   always @(posedge clk) begin
      sram_addr      <= (ld_addr) ? addr_nxt : sram_addr;
      wr_data_early  <= (ld_addr) ? wr_data_early_nxt : wr_data_early;
      wr_data_ph1    <= wr_data_early;
      sram_wr_data   <=
                        // synthesis translate_off
                        #2
                        // synthesis translate_on
                        wr_data_ph1;
      sram_we        <= (access_nxt == WRITE) ? 0 : 1;  // active low
      sram_bw        <= (access_nxt == WRITE) ? 'h0 : ~ 'h0;  // active low
      access         <= access_nxt;
      tri_en_ph1     <= (access == WRITE);
      sram_tri_en    <=
                        // synthesis translate_off
                        #2
                        // synthesis translate_on
                        tri_en_ph1;

      wr_0_ack <= reset ? 0 : (current_port == WR_0) & ack_nxt;
      wr_1_ack <= reset ? 0 : (current_port == WR_1) & ack_nxt;
      rd_0_ack <= reset ? 0 : (current_port == RD_0) & ack_nxt;
      rd_1_ack <= reset ? 0 : (current_port == RD_1) & ack_nxt;

      // delay the rd_ack signals in order to generate the valid signals
      rd_0_ack_del <= {rd_0_ack_del[2:0],rd_0_ack};
      rd_1_ack_del <= {rd_1_ack_del[2:0],rd_1_ack};

      // delay the access type so we can tell when it was a read
      is_read       <= {is_read[1:0],(access == READ)};

      rd_0_vld <= rd_0_ack_del[3] & is_read[2];
      rd_1_vld <= rd_1_ack_del[3] & is_read[2];
      rd_0_data <= (rd_0_ack_del[3] & is_read[2]) ? rd_data : rd_0_data;
      rd_1_data <= (rd_1_ack_del[3] & is_read[2]) ? rd_data : rd_1_data;
   end

   // synthesis translate_off

   // Synthesis code to set the we flag to 0 on startup to remove the annoying
   // "Cypress SRAM stores 'h xxxxxxxxx at addr 'h xxxxx" messages at the
   // beginning of the log file until the clock starts running.
   initial
   begin
      sram_we = 1;
   end

   // synthesis translate_on

endmodule // cnet_sram_sm

