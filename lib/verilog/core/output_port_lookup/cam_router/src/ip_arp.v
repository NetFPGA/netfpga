///////////////////////////////////////////////////////////////////////////////
// $Id: ip_arp.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: ip_arp.v
// Project: NF2.1
// Description: returns the next hop MAC address
//
///////////////////////////////////////////////////////////////////////////////

  module ip_arp
    #(parameter NUM_QUEUES = 8,
      parameter LUT_DEPTH = `ROUTER_OP_LUT_ARP_TABLE_DEPTH,
      parameter LUT_DEPTH_BITS = log2(LUT_DEPTH)
      )
   (// --- Interface to ip_arp
    input      [31:0]                  next_hop_ip,
    input      [NUM_QUEUES-1:0]        lpm_output_port,
    input                              lpm_vld,
    input                              lpm_hit,

    // --- interface to process block
    output     [47:0]                  next_hop_mac,
    output     [NUM_QUEUES-1:0]        output_port,
    output                             arp_mac_vld,
    output                             arp_lookup_hit,
    output                             lpm_lookup_hit,
    input                              rd_arp_result,

    // --- Interface to registers
    // --- Read port
    input [LUT_DEPTH_BITS-1:0]         arp_rd_addr,          // address in table to read
    input                              arp_rd_req,           // request a read
    output [47:0]                      arp_rd_mac,           // data read from the LUT at rd_addr
    output [31:0]                      arp_rd_ip,            // ip to match in the CAM
    output                             arp_rd_ack,           // pulses high

    // --- Write port
    input [LUT_DEPTH_BITS-1:0]         arp_wr_addr,
    input                              arp_wr_req,
    input [47:0]                       arp_wr_mac,
    input [31:0]                       arp_wr_ip,            // data to match in the CAM
    output                             arp_wr_ack,

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

   //--------------------- Internal Parameter-------------------------

   //---------------------- Wires and regs----------------------------
   wire                                  cam_busy;
   wire                                  cam_match;
   wire [LUT_DEPTH-1:0]                  cam_match_addr;
   wire [31:0]                           cam_cmp_din, cam_cmp_data_mask;
   wire [31:0]                           cam_din, cam_data_mask;
   wire                                  cam_we;
   wire [LUT_DEPTH_BITS-1:0]             cam_wr_addr;

   wire [47:0]                           next_hop_mac_result;

   wire                                  empty;

   reg [NUM_QUEUES-1:0]                  output_port_latched;
   reg                                   lpm_hit_latched;



   //------------------------- Modules-------------------------------

   // 1 cycle read latency, 2 cycles write latency
   bram_cam_unencoded_32x32 arp_cam
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
       .DATA_WIDTH(48),
       .LUT_DEPTH(LUT_DEPTH)
       ) cam_lut_sm
       (// --- Interface for lookups
        .lookup_req         (lpm_vld),
        .lookup_cmp_data    (next_hop_ip),
        .lookup_cmp_dmask   (32'h0),
        .lookup_ack         (lookup_ack),
        .lookup_hit         (lookup_hit),
        .lookup_data        (next_hop_mac_result),

        // --- Interface to registers
        // --- Read port
        .rd_addr            (arp_rd_addr),    // address in table to read
        .rd_req             (arp_rd_req),     // request a read
        .rd_data            (arp_rd_mac),     // data found for the entry
        .rd_cmp_data        (arp_rd_ip),      // matching data for the entry
        .rd_cmp_dmask       (),               // don't cares entry
        .rd_ack             (arp_rd_ack),     // pulses high

        // --- Write port
        .wr_addr            (arp_wr_addr),
        .wr_req             (arp_wr_req),
        .wr_data            (arp_wr_mac),    // data found for the entry
        .wr_cmp_data        (arp_wr_ip),     // matching data for the entry
        .wr_cmp_dmask       (32'h0),         // don't cares for the entry
        .wr_ack             (arp_wr_ack),

        // --- CAM interface
        .cam_busy           (cam_busy),
        .cam_match          (cam_match),
        .cam_match_addr     (cam_match_addr),
        .cam_cmp_din        (cam_cmp_din),
        .cam_din            (cam_din),
        .cam_we             (cam_we),
        .cam_wr_addr        (cam_wr_addr),
        .cam_cmp_data_mask  (cam_cmp_data_mask),
        .cam_data_mask      (cam_data_mask),

        // --- Misc
        .reset (reset),
        .clk   (clk));

   fallthrough_small_fifo #(.WIDTH(50+NUM_QUEUES), .MAX_DEPTH_BITS  (2))
      arp_fifo
        (.din           ({next_hop_mac_result, output_port_latched, lookup_hit, lpm_hit_latched}), // Data in
         .wr_en         (lookup_ack),             // Write enable
         .rd_en         (rd_arp_result),       // Read the next word
         .dout          ({next_hop_mac, output_port, arp_lookup_hit, lpm_lookup_hit}),
         .full          (),
         .nearly_full   (),
         .prog_full     (),
         .empty         (empty),
         .reset         (reset),
         .clk           (clk)
         );

   //------------------------- Logic --------------------------------
   assign arp_mac_vld = !empty;
   always @(posedge clk) begin
      if(reset) begin
         output_port_latched <= 0;
         lpm_hit_latched <= 0;
      end
      else if(lpm_vld) begin
         output_port_latched <= lpm_output_port;
         lpm_hit_latched <= lpm_hit;
      end
   end

endmodule // ip_arp



