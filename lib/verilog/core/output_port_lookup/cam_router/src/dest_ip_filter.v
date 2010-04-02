///////////////////////////////////////////////////////////////////////////////
// $Id: dest_ip_filter.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: dest_ip_filter.v
// Project: NF2.1
// Description: matches the ip destination to on in a list and indicates hits
//
///////////////////////////////////////////////////////////////////////////////

  module dest_ip_filter
    #(parameter DATA_WIDTH = 64,
      parameter LUT_DEPTH = `ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH,
      parameter LUT_DEPTH_BITS = log2(LUT_DEPTH)
      )
   (// --- Interface to the previous stage
    input  [DATA_WIDTH-1:0]            in_data,

    // --- Interface to process block
    output                             dest_ip_hit,
    output                             dest_ip_filter_vld,
    input                              rd_dest_ip_filter_result,

    // --- Interface to preprocess block
    input                              word_IP_SRC_DST,
    input                              word_IP_DST_LO,

    // --- Interface to registers
    // --- Read port
    input  [LUT_DEPTH_BITS-1:0]        dest_ip_filter_rd_addr,          // address in table to read
    input                              dest_ip_filter_rd_req,           // request a read
    output [31:0]                      dest_ip_filter_rd_ip,            // ip to match in the CAM
    output                             dest_ip_filter_rd_ack,           // pulses high

    // --- Write port
    input [LUT_DEPTH_BITS-1:0]         dest_ip_filter_wr_addr,
    input                              dest_ip_filter_wr_req,
    input [31:0]                       dest_ip_filter_wr_ip,            // data to match in the CAM
    output                             dest_ip_filter_wr_ack,

    // --- Misc
    input                              reset,
    input                              clk
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

   //---------------------- Wires and regs----------------------------

   wire                                  cam_busy;
   wire                                  cam_match;
   wire [LUT_DEPTH-1:0]                  cam_match_addr;
   wire [31:0]                           cam_cmp_din, cam_cmp_data_mask;
   wire [31:0]                           cam_din, cam_data_mask;
   wire                                  cam_we;
   wire [LUT_DEPTH_BITS-1:0]             cam_wr_addr;

   reg                                   dst_ip_vld;
   reg [31:0]                            dst_ip;

   //------------------------- Modules-------------------------------

   // 1 cycle read latency, 2 cycles write latency
   // priority encoded for the smallest address.
   bram_cam_unencoded_32x32 dest_ip_cam
     (
      // Outputs
      .busy                             (cam_busy),
      .match                            (cam_match),
      .match_addr                       (cam_match_addr),
      // Inputs
      .clk                              (clk),
      .cmp_din                          (cam_cmp_din),
      .din                              (cam_din),
      .we                               (cam_we),
      .wr_addr                          (cam_wr_addr));

   unencoded_cam_lut_sm
     #(.CMP_WIDTH(32),                  // IPv4 addr width
       .DATA_WIDTH(1),                  // no data
       .LUT_DEPTH(LUT_DEPTH),
       .DEFAULT_DATA(0)
      ) cam_lut_sm
       (// --- Interface for lookups
        .lookup_req          (dst_ip_vld),
        .lookup_cmp_data     (dst_ip),
        .lookup_cmp_dmask    (32'h0),
        .lookup_ack          (lookup_ack),
        .lookup_hit          (lookup_hit),
        .lookup_data         (),

        // --- Interface to registers
        // --- Read port
        .rd_addr             (dest_ip_filter_rd_addr),    // address in table to read
        .rd_req              (dest_ip_filter_rd_req),     // request a read
        .rd_data             (),                          // data found for the entry
        .rd_cmp_data         (dest_ip_filter_rd_ip),      // matching data for the entry
        .rd_cmp_dmask        (),                          // don't cares entry
        .rd_ack              (dest_ip_filter_rd_ack),     // pulses high

        // --- Write port
        .wr_addr             (dest_ip_filter_wr_addr),
        .wr_req              (dest_ip_filter_wr_req),
        .wr_data             (1'b0),                    // data found for the entry
        .wr_cmp_data         (dest_ip_filter_wr_ip),    // matching data for the entry
        .wr_cmp_dmask        (32'h0),                   // don't cares for the entry
        .wr_ack              (dest_ip_filter_wr_ack),

        // --- CAM interface
        .cam_busy            (cam_busy),
        .cam_match           (cam_match),
        .cam_match_addr      (cam_match_addr),
        .cam_cmp_din         (cam_cmp_din),
        .cam_din             (cam_din),
        .cam_we              (cam_we),
        .cam_wr_addr         (cam_wr_addr),
        .cam_cmp_data_mask   (cam_cmp_data_mask),
        .cam_data_mask       (cam_data_mask),

        // --- Misc
        .reset               (reset),
        .clk                 (clk));

   fallthrough_small_fifo #(.WIDTH(1), .MAX_DEPTH_BITS(2))
      dest_ip_filter_fifo
        (.din           (lookup_hit), // Data in
         .wr_en         (lookup_ack),             // Write enable
         .rd_en         (rd_dest_ip_filter_result),       // Read the next word
         .dout          (dest_ip_hit),
         .full          (),
         .nearly_full   (),
         .prog_full     (),
         .empty         (empty),
         .reset         (reset),
         .clk           (clk)
         );

   //------------------------- Logic --------------------------------

   assign dest_ip_filter_vld = !empty;

   /*****************************************************************
    * find the dst IP address and do the lookup
    *****************************************************************/
   always @(posedge clk) begin
      if(reset) begin
         dst_ip <= 0;
         dst_ip_vld <= 0;
      end
      else begin
         if(word_IP_SRC_DST) begin
            dst_ip[31:16] <= in_data[15:0];
            dst_ip_vld <= 0;
         end
         if(word_IP_DST_LO) begin
            dst_ip[15:0]  <= in_data[DATA_WIDTH-1:DATA_WIDTH-16];
            dst_ip_vld <= 1;
         end
         else begin
            dst_ip_vld <= 0;
         end
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // dest_ip_filter



