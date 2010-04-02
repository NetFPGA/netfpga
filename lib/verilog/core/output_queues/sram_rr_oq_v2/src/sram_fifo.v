/***************************************
 * $Id: sram_fifo.v 5193 2009-03-06 00:15:26Z grg $
 *
 * Module: sram_fifo.v
 * Author: Jad Naous
 * Project: output_queues v2
 * Description: Implements a FIFO in SRAM
 *
 * Change history:
 *
 ***************************************/
`timescale 1ns/1ps

  module sram_fifo
    #(parameter SRAM_WIDTH = 72,
      parameter SRAM_ADDR_WIDTH = 19)
      (/* input side */
       input     [SRAM_WIDTH-1:0]        wr_data,       /* data to write */
       input                             wr_req,        /* set high to write and keep
                                                         * until wr_ack is raised */
       output                            wr_ack,        /* indicates current word stored,
                                                         * need new word on next cycle */
       output     [SRAM_ADDR_WIDTH-1:0]  space_avail,   /* num words that can be written
                                                         * before becoming full */

       /* output side */
       input                             rd_req,        /* set high to req rd. Keep hi
                                                         * till ack */
       output                            rd_ack,        /* rd started. rd_req should go
                                                         * low next cycle if no more. */
       output     [SRAM_WIDTH-1:0]       rd_data,       /* read result */
       output                            rd_vld,        /* read result vld (a few cycles
                                                         * after rd_req) */
       output     [SRAM_ADDR_WIDTH-1:0]  words_avail,   /* num words available to read */

       /* configuration interface */
       input      [SRAM_ADDR_WIDTH-1:0]  addr_high,     /* high addr of the fifo in SRAM */
       input      [SRAM_ADDR_WIDTH-1:0]  addr_low,      /* low addr of the fifo in SRAM */

       /* SRAM interface */
       output reg [SRAM_ADDR_WIDTH-1:0]  sram_wr_addr,
       output                            sram_wr_req,
       input                             sram_wr_ack,
       output     [SRAM_WIDTH-1:0]       sram_wr_data,

       output reg [SRAM_ADDR_WIDTH-1:0]  sram_rd_addr,
       output                            sram_rd_req,
       input                             sram_rd_ack,
       input      [SRAM_WIDTH-1:0]       sram_rd_data,
       input                             sram_rd_vld,

       input                             reset,
       input                             clk
       );


   reg [SRAM_ADDR_WIDTH-1:0]             depth;

   assign sram_wr_req    = wr_req;
   assign sram_wr_data   = wr_data;

   assign sram_rd_req    = rd_req;
   assign rd_data        = sram_rd_data;
   assign rd_vld         = sram_rd_vld;
   assign words_avail    = depth;
   assign space_avail    = addr_high - addr_low - depth + 1'b1;

   assign wr_ack         = sram_wr_ack;
   assign rd_ack         = sram_rd_ack;

   always @(posedge clk) begin
      if(reset) begin
         sram_wr_addr    <= addr_low;
         sram_rd_addr    <= addr_low;
         depth           <= 0;
      end

      else begin

         if(sram_wr_ack) begin
            if(sram_wr_addr == addr_high) begin
               sram_wr_addr <= addr_low;
            end
            else begin
               sram_wr_addr <= sram_wr_addr + 1'b1;
            end
         end

         if(sram_rd_ack) begin
            if(sram_rd_addr == addr_high) begin
               sram_rd_addr <= addr_low;
            end
            else begin
               sram_rd_addr <= sram_rd_addr + 1'b1;
            end
         end

         case({sram_wr_ack, sram_rd_ack})
            2'b10: depth <= depth + 1'b1;
            2'b01: depth <= depth - 1'b1;
         endcase // case({sram_wr_ack, sram_rd_ack})

      end // else: !if(reset)

   end // always @ (posedge clk)

   // synthesis translate_off
   always @(posedge clk)
   begin
      if (wr_req && space_avail == 0) begin
         $display("%t ERROR: Attempt to write to full FIFO: %m", $time);
/* -----\/----- EXCLUDED -----\/-----
         $stop;
 -----/\----- EXCLUDED -----/\----- */
      end
      if (rd_req && depth == 'h0) begin
         $display("%t ERROR: Attempt to read an empty FIFO: %m", $time);
/* -----\/----- EXCLUDED -----\/-----
         $stop;
 -----/\----- EXCLUDED -----/\----- */
      end
   end
   // synthesis translate_on

endmodule // sram_fifo

// synthesis translate_off
module sram_fifo_tester();

   parameter SRAM_WIDTH = 72;
   parameter SRAM_ADDR_WIDTH = 19;

   wire                      rd_ack;
   wire [SRAM_WIDTH-1:0]     rd_data;
   wire                      rd_vld;
   wire [SRAM_ADDR_WIDTH-1:0]space_avail;
   wire [SRAM_ADDR_WIDTH-1:0]sram_rd_addr;
   wire [SRAM_ADDR_WIDTH-1:0]sram_wr_addr;
   wire [SRAM_WIDTH-1:0]     sram_wr_data;
   wire                      sram_wr_req;
   wire [SRAM_ADDR_WIDTH-1:0]words_avail;
   wire                      wr_ack;

   reg                       wr_req;
   reg                       rd_req;
   reg [SRAM_ADDR_WIDTH-1:0] addr_high;
   reg [SRAM_ADDR_WIDTH-1:0] addr_low;
   reg                       sram_wr_ack;
   reg                       sram_rd_ack;
   reg [SRAM_WIDTH-1:0]      sram_rd_data;
   reg                       sram_rd_vld;
   reg                       sram_rd_vld_e1;
   reg [SRAM_WIDTH-1:0]      sram_rd_data_e1;
   wire                      sram_rd_req;
   reg [SRAM_WIDTH-1:0]      wr_data = 0;

   reg                       clk = 0;
   reg                       reset = 0;

   integer                   count = 0;
   integer                   rd_count = 0;

   sram_fifo sram_fifo
     (
      // Outputs
      .wr_ack                           (wr_ack),
      .space_avail                      (space_avail[SRAM_ADDR_WIDTH-1:0]),
      .rd_ack                           (rd_ack),
      .rd_data                          (rd_data[SRAM_WIDTH-1:0]),
      .rd_vld                           (rd_vld),
      .words_avail                      (words_avail[SRAM_ADDR_WIDTH-1:0]),
      .sram_wr_addr                     (sram_wr_addr[SRAM_ADDR_WIDTH-1:0]),
      .sram_wr_req                      (sram_wr_req),
      .sram_wr_data                     (sram_wr_data[SRAM_WIDTH-1:0]),
      .sram_rd_addr                     (sram_rd_addr[SRAM_ADDR_WIDTH-1:0]),
      .sram_rd_req                      (sram_rd_req),
      .sram_rd_data                     (sram_rd_data[SRAM_WIDTH-1:0]),
      .sram_rd_vld                      (sram_rd_vld),
      // Inputs
      .wr_data                          (wr_data),
      .wr_req                           (wr_req),
      .rd_req                           (rd_req),
      .addr_high                        (addr_high[SRAM_ADDR_WIDTH-1:0]),
      .addr_low                         (addr_low[SRAM_ADDR_WIDTH-1:0]),
      .sram_wr_ack                      (sram_wr_ack),
      .sram_rd_ack                      (sram_rd_ack),
      .reset                            (reset),
      .clk                              (clk));

   always #4 clk = ~clk;

   reg [71:0]  sram[0:15];
   always @(posedge clk) begin
      sram_rd_ack       <= 0;
      sram_rd_vld_e1    <= 0;
      sram_wr_ack       <= 0;
      sram_rd_vld       <= sram_rd_vld_e1;
      sram_rd_data      <= sram_rd_data_e1;
      if(sram_rd_req) begin
         sram_rd_ack        <= 1'b1;
         sram_rd_data_e1    <= sram[sram_rd_addr];
         sram_rd_vld_e1     <= 1'b1;
      end
      if(sram_wr_req) begin
         sram_wr_ack           <= 1'b1;
         sram[sram_wr_addr]    <= sram_wr_data;
      end
   end // always @ (posedge clk)

   always @(posedge clk) begin
      count     <= count + 1;
      reset     <= 0;
      wr_req    <= 0;
      rd_req    <= 0;
      addr_high <= 15;
      addr_low  <= 0;
      rd_count  <= rd_count + rd_ack;
      wr_data   <= wr_data + wr_ack;

      if(words_avail != wr_data + wr_ack - rd_count - rd_ack) begin
         $display("%t ERROR: words_avail incorrect. exp:%u found %u: %m", $time, wr_data + wr_ack - rd_count - rd_ack, words_avail);
      end
      if(space_avail != 16-words_avail) begin
         $display("%t ERROR: space_avail incorrect. exp:%u found %u: %m", $time, 16-words_avail, space_avail);
      end
      if(rd_vld && rd_data != rd_count) begin
         $display("%t ERROR: rd_data incorrect. exp:%u found %u: %m", $time, rd_count, rd_data);
      end

      if(count < 2) begin
         reset <= 1'b1;
      end
      else if(count < 2 + 8) begin
         wr_req <= 1;
      end
      else if(count < 2 + 8 + 3) begin
         rd_req <= 1;
      end
      else if(count < 2 + 8 + 3 + 2) begin
         wr_req <= 1'b1;
      end
      else if(count < 2 + 8 + 3 + 2 + 8) begin
         wr_req <= 1'b1;
         rd_req <= 1'b1;
      end
      else if(count < 2 + 8 + 3 + 2 + 8 + 4) begin
         rd_req <= 1'b1;
      end
      else if(count < 2 + 8 + 3 + 2 + 8 + 4 + 8) begin
         wr_req <= 1'b1;
         rd_req <= 1'b1;
      end
      else begin
         $display("%t Test complete %m", $time);
      end
   end // always @ (posedge clk)
endmodule // sram_fifo_tester
// synthesis translate_on

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
