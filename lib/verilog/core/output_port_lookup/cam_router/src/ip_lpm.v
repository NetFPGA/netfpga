///////////////////////////////////////////////////////////////////////////////
// $Id: ip_lpm.v 5089 2009-02-23 02:14:38Z grg $
//
// Module: ip_lpm.v
// Project: NF2.1
// Description: Finds the longest prefix match of the incoming IP address
//              gives the ip of the next hop and the output port
//
///////////////////////////////////////////////////////////////////////////////

  module ip_lpm
    #(parameter DATA_WIDTH = 64,
      parameter NUM_QUEUES = 5,
      parameter LUT_DEPTH = `ROUTER_OP_LUT_ROUTE_TABLE_DEPTH,
      parameter LUT_DEPTH_BITS = log2(LUT_DEPTH)
      )
   (// --- Interface to the previous stage
    input  [DATA_WIDTH-1:0]            in_data,

    // --- Interface to arp_lut
    output reg [31:0]                  next_hop_ip,
    output reg [NUM_QUEUES-1:0]        lpm_output_port,
    output reg                         lpm_vld,
    output reg                         lpm_hit,

    // --- Interface to preprocess block
    input                              word_IP_SRC_DST,
    input                              word_IP_DST_LO,

    // --- Interface to registers
    // --- Read port
    input  [LUT_DEPTH_BITS-1:0]        lpm_rd_addr,          // address in table to read
    input                              lpm_rd_req,           // request a read
    output [31:0]                      lpm_rd_ip,            // ip to match in the CAM
    output [31:0]                      lpm_rd_mask,          // subnet mask
    output [NUM_QUEUES-1:0]            lpm_rd_oq,            // output queue
    output [31:0]                      lpm_rd_next_hop_ip,   // ip addr of next hop
    output                             lpm_rd_ack,           // pulses high

    // --- Write port
    input [LUT_DEPTH_BITS-1:0]         lpm_wr_addr,
    input                              lpm_wr_req,
    input [NUM_QUEUES-1:0]             lpm_wr_oq,
    input [31:0]                       lpm_wr_next_hop_ip,   // ip addr of next hop
    input [31:0]                       lpm_wr_ip,            // data to match in the CAM
    input [31:0]                       lpm_wr_mask,
    output                             lpm_wr_ack,

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

   wire [NUM_QUEUES-1:0]                 lookup_port_result;
   wire [31:0]                           next_hop_ip_result;

   reg                                   dst_ip_vld;
   reg [31:0]                            dst_ip;
   wire [31:0]                           lpm_rd_mask_inverted;

   //------------------------- Modules-------------------------------
   assign                                lpm_rd_mask = ~lpm_rd_mask_inverted;

   // 1 cycle read latency, 16 cycles write latency
   // priority encoded for the smallest address.
   srl_cam_unencoded_32x32 lpm_cam
     (
      // Outputs
      .busy                             (cam_busy),
      .match                            (cam_match),
      .match_addr                       (cam_match_addr),
      // Inputs
      .clk                              (clk),
      .cmp_din                          (cam_cmp_din),
      .din                              (cam_din),
      .cmp_data_mask                    (cam_cmp_data_mask),
      .data_mask                        (cam_data_mask),
      .we                               (cam_we),
      .wr_addr                          (cam_wr_addr));

   unencoded_cam_lut_sm
     #(.CMP_WIDTH          (32),                // IPv4 addr width
       .DATA_WIDTH         (32+NUM_QUEUES),     // next hop ip and output queue
       .LUT_DEPTH          (LUT_DEPTH),
       .DEFAULT_DATA       (1)
      ) cam_lut_sm
       (// --- Interface for lookups
        .lookup_req          (dst_ip_vld),
        .lookup_cmp_data     (dst_ip),
        .lookup_cmp_dmask    (32'h0),
        .lookup_ack          (lpm_vld_result),
        .lookup_hit          (lpm_hit_result),
        .lookup_data         ({lookup_port_result, next_hop_ip_result}),

        // --- Interface to registers
        // --- Read port
        .rd_addr             (lpm_rd_addr),                        // address in table to read
        .rd_req              (lpm_rd_req),                         // request a read
        .rd_data             ({lpm_rd_oq, lpm_rd_next_hop_ip}),    // data found for the entry
        .rd_cmp_data         (lpm_rd_ip),                          // matching data for the entry
        .rd_cmp_dmask        (lpm_rd_mask_inverted),               // don't cares entry
        .rd_ack              (lpm_rd_ack),                         // pulses high

        // --- Write port
        .wr_addr             (lpm_wr_addr),
        .wr_req              (lpm_wr_req),
        .wr_data             ({lpm_wr_oq, lpm_wr_next_hop_ip}),    // data found for the entry
        .wr_cmp_data         (lpm_wr_ip),                          // matching data for the entry
        .wr_cmp_dmask        (~lpm_wr_mask),                       // don't cares for the entry
        .wr_ack              (lpm_wr_ack),

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

   //------------------------- Logic --------------------------------

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

   /*****************************************************************
    * latch the outputs
    *****************************************************************/
   always @(posedge clk) begin
      lpm_output_port <= lookup_port_result;
      next_hop_ip     <= (next_hop_ip_result == 0) ? dst_ip : next_hop_ip_result;
      lpm_hit         <= lpm_hit_result;

      if(reset) begin
         lpm_vld <= 0;
      end
      else begin
         lpm_vld <= lpm_vld_result;
      end // else: !if(reset)
   end // always @ (posedge clk)
endmodule // ip_lpm



