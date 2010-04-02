/*******************************************************************************
 * $Id$
 *
 * Module: sram_muxer.v
 * Project: generic lookups
 * Author: Jad Naous <jnaous@stanford.edu>
 * Description: provides two read ports to the SRAM
 *
 *******************************************************************************/

module sram_muxer
  #(parameter SRAM_ADDR_WIDTH = 19,
    parameter SRAM_DATA_WIDTH = 72)

    (// --- interface to SRAM
     input                              rd_ack,
     input  [SRAM_DATA_WIDTH-1:0]       rd_data,
     input                              rd_vld,
     output reg [SRAM_ADDR_WIDTH-1:0]   rd_addr,
     output reg                         rd_req,

     // --- read port 0
     output                             rd_0_rdy,
     output [SRAM_DATA_WIDTH-1:0]       rd_0_data,
     output                             rd_0_vld,
     input  [SRAM_ADDR_WIDTH-1:0]       rd_0_addr,
     input                              rd_0_req,

     // --- read port 1
     output                             rd_1_rdy,
     output [SRAM_DATA_WIDTH-1:0]       rd_1_data,
     output                             rd_1_vld,
     input  [SRAM_ADDR_WIDTH-1:0]       rd_1_addr,
     input                              rd_1_req,

     // --- Misc
     input                              reset,
     input                              clk
     );

   //-------------------- Internal Parameters ------------------------

   localparam  PRIORITY_CYCLES_WIDTH = 3;

   //---------------------- Wires and regs----------------------------
   reg  [1:0]                 rd_fifo_rd_en;
   wire [SRAM_ADDR_WIDTH-1:0] dout_rd_addr[1:0];
   wire [SRAM_ADDR_WIDTH-1:0] dout_rd_addr_sel, dout_rd_addr_other_sel;
   wire [1:0]                 rd_fifo_full;
   wire [1:0]                 rd_fifo_empty;

   reg [PRIORITY_CYCLES_WIDTH-1:0] count;
   reg                             priority_port;

   reg                             rd_req_d1;
   reg [SRAM_ADDR_WIDTH-1:0]       rd_addr_d1;

   //------------------------- Modules -------------------------------

   /* transforms the ack to rdy signals for the read ports */
   fallthrough_small_fifo
     #(.WIDTH(SRAM_ADDR_WIDTH), .MAX_DEPTH_BITS(2))
      rd_0_fifo
        (.din           (rd_0_addr),
         .wr_en         (rd_0_req),
         .rd_en         (rd_fifo_rd_en[0]),
         .dout          (dout_rd_addr[0]),
         .full          (),
         .prog_full     (),
         .nearly_full   (rd_fifo_full[0]),
         .empty         (rd_fifo_empty[0]),
         .reset         (reset),
         .clk           (clk)
         );

   /* transforms the ack to rdy signals for the read ports */
   fallthrough_small_fifo
     #(.WIDTH(SRAM_ADDR_WIDTH), .MAX_DEPTH_BITS(2))
      rd_1_fifo
        (.din           (rd_1_addr),
         .wr_en         (rd_1_req),
         .rd_en         (rd_fifo_rd_en[1]),
         .dout          (dout_rd_addr[1]),
         .full          (),
         .prog_full     (),
         .nearly_full   (rd_fifo_full[1]),
         .empty         (rd_fifo_empty[1]),
         .reset         (reset),
         .clk           (clk)
         );

   /* maintains the order in which reads where issued to
    * issue the rd_vld in the correct order */
   fallthrough_small_fifo
     #(.WIDTH(1), .MAX_DEPTH_BITS(3))
      order_fifo
        (.din           (rd_fifo_rd_en[1]),
         .wr_en         (|rd_fifo_rd_en),
         .rd_en         (rd_vld),
         .dout          (port_num),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (),
         .reset         (reset),
         .clk           (clk)
         );


   //-------------------------- Logic --------------------------------
   assign rd_0_rdy          = !rd_fifo_full[0];
   assign rd_0_data         = rd_data;
   assign rd_0_vld          = rd_vld & !port_num;

   assign rd_1_rdy          = !rd_fifo_full[1];
   assign rd_1_data         = rd_data;
   assign rd_1_vld          = rd_vld & port_num;

   assign dout_rd_addr_sel  = dout_rd_addr[priority_port];
   assign dout_rd_addr_other_sel  = dout_rd_addr[~priority_port];

   always @(*) begin
      /* defaults */
      rd_addr         = rd_addr_d1;
      rd_req          = rd_req_d1;
      rd_fifo_rd_en   = 0;

      /* do something only if we are not waiting for an ack
       * or if an ack has arrived */
      if(!rd_req_d1 || rd_ack) begin
         if(!rd_fifo_empty[priority_port]) begin
            rd_addr                         = dout_rd_addr_sel;
            rd_req                          = 1'b1;
            rd_fifo_rd_en[priority_port]    = 1'b1;
         end
         else if(!rd_fifo_empty[~priority_port]) begin
            rd_addr                         = dout_rd_addr_other_sel;
            rd_req                          = 1'b1;
            rd_fifo_rd_en[~priority_port]   = 1'b1;
         end
         else begin
            rd_req   = 0;
         end
      end // if (!rd_req || rd_ack)
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         count            <= 0;
         priority_port    <= 0;
         rd_req_d1        <= 0;
         rd_addr_d1       <= 0;
      end
      else begin

         count        <= count + 1'b1;
         rd_req_d1    <= rd_req;
         rd_addr_d1   <= rd_addr;

         /* give priority to the other port when the cycle is over. */
         if(&count) begin
            priority_port <= ~priority_port;
         end

      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // sram_muxer
