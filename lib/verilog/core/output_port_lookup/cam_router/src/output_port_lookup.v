///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: output_port_lookup.v 5240 2009-03-14 01:50:42Z grg $
//
// Module: router_output_port.v
// Project: NF2.1
// Description: reads incoming packets parses them and decides on the output port
//  and adds it as a header. The design of this module assumes that only one eop
//  will be in the pipeline of this module at any given time.
//  i.e. we assume pkt length incl pkt and module headers >= 8*DATA_WIDTH bits
//  for a 64 bit datapath, this is 64 bytes.
//
//  Data coming in goes into the input fifo and is preprocessed for lookups,... by
//  the preprocess block. Then the data is pulled out of the fifo when the preprocess
//  is done and modified on it's way to the output queues.
//
//  There are five operations happening in the preprocess simultaneously:
//    1- eth_parser: will decide if the destination MAC addr is us, and the pkt type (ARP, IP, ...)
//    2- IP_LPM then ARP_lookup: give the next hop mac, and the output port
//    3- ip_cheksum_ttl: validates the IP checksum, makes the new checksum, and validates the hdr len/version
//    4- op_lut_hdr_parser: checks to see if the pkt is from the CPU
//    5- dest_ip_filter: checks to see if the destination ip address says the packet should go to the cpu
//
//  The op_lut_process_sm block will then pull out the data from the input fifo, modify the
//  next hop MAC and src addresses, modify the IP TTL and send the pkt out to
//  the output queues for an IP packet. For an ARP packet or a packet whose
//  next hop MAC is not found, the pkt is sent to the CPU (also sent are ip pkts with
//  options, unknown protocols, version!=4)
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
  module output_port_lookup
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter INPUT_ARBITER_STAGE_NUM = 2,
      parameter IO_QUEUE_STAGE_NUM = `IO_QUEUE_STAGE_NUM,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter NUM_IQ_BITS = 3,
      parameter STAGE_NUM = 4,
      parameter CPU_QUEUE_NUM = 0)

   (// --- data path interface
    output     [DATA_WIDTH-1:0]        out_data,
    output     [CTRL_WIDTH-1:0]        out_ctrl,
    output                             out_wr,
    input                              out_rdy,

    input  [DATA_WIDTH-1:0]            in_data,
    input  [CTRL_WIDTH-1:0]            in_ctrl,
    input                              in_wr,
    output                             in_rdy,

    // --- Register interface
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

    // --- Misc
    input                              clk,
    input                              reset);

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
   parameter LPM_LUT_DEPTH = `ROUTER_OP_LUT_ROUTE_TABLE_DEPTH;
   parameter LPM_LUT_DEPTH_BITS = log2(LPM_LUT_DEPTH);
   parameter ARP_LUT_DEPTH = `ROUTER_OP_LUT_ARP_TABLE_DEPTH;
   parameter ARP_LUT_DEPTH_BITS = log2(ARP_LUT_DEPTH);
   parameter FILTER_DEPTH = `ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH;
   parameter FILTER_DEPTH_BITS = log2(FILTER_DEPTH);
   parameter NUM_QUEUES = NUM_OUTPUT_QUEUES;
   parameter NUM_QUEUES_WIDTH = log2(NUM_QUEUES);

   //---------------------- Wires/Regs -------------------------------
   wire [47:0]                 mac_0, mac_1, mac_2, mac_3;
   wire [NUM_QUEUES_WIDTH-1:0] mac_dst_port_num;
   wire [31:0]                 next_hop_ip;

   wire [NUM_QUEUES-1:0]       lpm_output_port;
   wire [LPM_LUT_DEPTH_BITS-1:0]   lpm_rd_addr;
   wire [31:0]                 lpm_rd_ip;
   wire [31:0]                 lpm_rd_next_hop_ip;
   wire [31:0]                 lpm_rd_mask;
   wire [NUM_QUEUES-1:0]       lpm_rd_oq;
   wire [LPM_LUT_DEPTH_BITS-1:0]   lpm_wr_addr;
   wire [31:0]                 lpm_wr_ip;
   wire [31:0]                 lpm_wr_next_hop_ip;
   wire [31:0]                 lpm_wr_mask;
   wire [NUM_QUEUES-1:0]       lpm_wr_oq;

   wire [47:0]                 next_hop_mac;
   wire [NUM_QUEUES-1:0]       output_port;

   wire [ARP_LUT_DEPTH_BITS-1:0]   arp_rd_addr;
   wire [47:0]                 arp_rd_mac;
   wire [31:0]                 arp_rd_ip;
   wire [ARP_LUT_DEPTH_BITS-1:0]   arp_wr_addr;
   wire [47:0]                 arp_wr_mac;
   wire [31:0]                 arp_wr_ip;

   wire [FILTER_DEPTH_BITS-1:0]dest_ip_filter_rd_addr;
   wire [31:0]                 dest_ip_filter_rd_ip;
   wire [FILTER_DEPTH_BITS-1:0]dest_ip_filter_wr_addr;
   wire [31:0]                 dest_ip_filter_wr_ip;

   wire [7:0]                  ip_new_ttl;
   wire [15:0]                 ip_new_checksum;

   wire [NUM_QUEUES-1:0]       to_cpu_output_port;
   wire [NUM_QUEUES-1:0]       from_cpu_output_port;
   wire [NUM_QUEUES_WIDTH-1:0] input_port_num;

   wire [CTRL_WIDTH-1:0]       in_fifo_ctrl;
   wire [DATA_WIDTH-1:0]       in_fifo_data;

   wire                        in_fifo_nearly_full;

   //----------------------- Modules ---------------------------------

   assign in_rdy = !in_fifo_nearly_full;
   fallthrough_small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(5))
      input_fifo
        (.din           ({in_ctrl, in_data}),  // Data in
         .wr_en         (in_wr),             // Write enable
         .rd_en         (in_fifo_rd_en),    // Read the next word
         .dout          ({in_fifo_ctrl, in_fifo_data}),
         .full          (),
         .nearly_full   (in_fifo_nearly_full),
         .prog_full     (),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   preprocess_control
     #(.DATA_WIDTH                  (DATA_WIDTH),
       .CTRL_WIDTH                  (CTRL_WIDTH)) preprocess_control
       ( // --- Interface to the previous stage
         .in_data                   (in_data),
         .in_ctrl                   (in_ctrl),
         .in_wr                     (in_wr),

         // --- Interface to other preprocess blocks
         .word_MAC_DA_HI            (word_MAC_DA_HI),
         .word_MAC_DASA             (word_MAC_DASA),
         .word_MAC_SA_LO            (word_MAC_SA_LO),
         .word_ETH_IP_VER           (word_ETH_IP_VER),
         .word_IP_LEN_ID            (word_IP_LEN_ID),
         .word_IP_FRAG_TTL_PROTO    (word_IP_FRAG_TTL_PROTO),
         .word_IP_CHECKSUM_SRC_HI   (word_IP_CHECKSUM_SRC_HI),
         .word_IP_SRC_DST           (word_IP_SRC_DST),
         .word_IP_DST_LO            (word_IP_DST_LO),

         // --- Misc
         .reset                     (reset),
         .clk                       (clk)
         );

   eth_parser
     #(.DATA_WIDTH(DATA_WIDTH),
       .NUM_QUEUES(NUM_QUEUES)
       ) eth_parser
       ( // --- Interface to the previous stage
         .in_data               (in_data),

         // --- Interface to process block
         .is_arp_pkt            (is_arp_pkt),
         .is_ip_pkt             (is_ip_pkt),
         .is_for_us             (is_for_us),
         .is_broadcast          (is_broadcast),
         .mac_dst_port_num      (mac_dst_port_num),
         .eth_parser_rd_info    (rd_preprocess_info),
         .eth_parser_info_vld   (eth_parser_info_vld),

         // --- Interface to preprocess block
         .word_MAC_DA_HI        (word_MAC_DA_HI),
         .word_MAC_DASA         (word_MAC_DASA),
         .word_ETH_IP_VER       (word_ETH_IP_VER),

         // --- Interface to registers
         .mac_0                 (mac_0),    // address of rx queue 0
         .mac_1                 (mac_1),    // address of rx queue 1
         .mac_2                 (mac_2),    // address of rx queue 2
         .mac_3                 (mac_3),    // address of rx queue 3

         // --- Misc
         .reset                 (reset),
         .clk                   (clk)
         );

   ip_lpm
     #(.DATA_WIDTH(DATA_WIDTH),
       .NUM_QUEUES(NUM_QUEUES)
       ) ip_lpm
       ( // --- Interface to the previous stage
         .in_data              (in_data),

         // --- Interface to arp_lut
         .next_hop_ip          (next_hop_ip),
         .lpm_output_port      (lpm_output_port),
         .lpm_vld              (lpm_vld),
         .lpm_hit              (lpm_hit),

         // --- Interface to preprocess block
         .word_IP_SRC_DST      (word_IP_SRC_DST),
         .word_IP_DST_LO       (word_IP_DST_LO),

         // --- Interface to registers
         // --- Read port
         .lpm_rd_addr          (lpm_rd_addr),          // address in table to read
         .lpm_rd_req           (lpm_rd_req),           // request a read
         .lpm_rd_ip            (lpm_rd_ip),            // ip to match in the CAM
         .lpm_rd_mask          (lpm_rd_mask),          // subnet mask
         .lpm_rd_oq            (lpm_rd_oq),            // output queue
         .lpm_rd_next_hop_ip   (lpm_rd_next_hop_ip),   // ip addr of next hop
         .lpm_rd_ack           (lpm_rd_ack),           // pulses high

         // --- Write port
         .lpm_wr_addr          (lpm_wr_addr),
         .lpm_wr_req           (lpm_wr_req),
         .lpm_wr_oq            (lpm_wr_oq),
         .lpm_wr_next_hop_ip   (lpm_wr_next_hop_ip),   // ip addr of next hop
         .lpm_wr_ip            (lpm_wr_ip),            // data to match in the CAM
         .lpm_wr_mask          (lpm_wr_mask),
         .lpm_wr_ack           (lpm_wr_ack),

         // --- Misc
         .reset                (reset),
         .clk                  (clk)
         );

   ip_arp
     #(.NUM_QUEUES(NUM_QUEUES)
       ) ip_arp
       ( // --- Interface to ip_arp
         .next_hop_ip       (next_hop_ip),
         .lpm_output_port   (lpm_output_port),
         .lpm_vld           (lpm_vld),
         .lpm_hit           (lpm_hit),

         // --- interface to process block
         .next_hop_mac      (next_hop_mac),
         .output_port       (output_port),
         .arp_mac_vld       (arp_mac_vld),
         .rd_arp_result     (rd_preprocess_info),
         .arp_lookup_hit    (arp_lookup_hit),
         .lpm_lookup_hit    (lpm_lookup_hit),

         // --- Interface to registers
         // --- Read port
         .arp_rd_addr       (arp_rd_addr),          // address in table to read
         .arp_rd_req        (arp_rd_req),           // request a read
         .arp_rd_mac        (arp_rd_mac),           // data read from the LUT at rd_addr
         .arp_rd_ip         (arp_rd_ip),            // ip to match in the CAM
         .arp_rd_ack        (arp_rd_ack),           // pulses high

         // --- Write port
         .arp_wr_addr       (arp_wr_addr),
         .arp_wr_req        (arp_wr_req),
         .arp_wr_mac        (arp_wr_mac),
         .arp_wr_ip         (arp_wr_ip),            // data to match in the CAM
         .arp_wr_ack        (arp_wr_ack),

         // --- Misc
         .reset             (reset),
         .clk               (clk)
         );

   dest_ip_filter
     dest_ip_filter
       ( // --- Interface to the previous stage
         .in_data                  (in_data),

         // --- Interface to preprocess block
         .word_IP_SRC_DST          (word_IP_SRC_DST),
         .word_IP_DST_LO           (word_IP_DST_LO),

         // --- interface to process block
         .dest_ip_hit              (dest_ip_hit),
         .dest_ip_filter_vld       (dest_ip_filter_vld),
         .rd_dest_ip_filter_result (rd_preprocess_info),

         // --- Interface to registers
         // --- Read port
         .dest_ip_filter_rd_addr   (dest_ip_filter_rd_addr),
         .dest_ip_filter_rd_req    (dest_ip_filter_rd_req),
         .dest_ip_filter_rd_ip     (dest_ip_filter_rd_ip), // ip to match in the cam
         .dest_ip_filter_rd_ack    (dest_ip_filter_rd_ack),

         // --- Write port
         .dest_ip_filter_wr_addr   (dest_ip_filter_wr_addr),
         .dest_ip_filter_wr_req    (dest_ip_filter_wr_req),
         .dest_ip_filter_wr_ip     (dest_ip_filter_wr_ip),
         .dest_ip_filter_wr_ack    (dest_ip_filter_wr_ack),

         // --- Misc
         .reset                    (reset),
         .clk                      (clk)
         );

   ip_checksum_ttl
     #(.DATA_WIDTH(DATA_WIDTH)
       ) ip_checksum_ttl
       ( //--- datapath interface
         .in_data                   (in_data),
         .in_wr                     (in_wr),

         //--- interface to preprocess
         .word_ETH_IP_VER           (word_ETH_IP_VER),
         .word_IP_LEN_ID            (word_IP_LEN_ID),
         .word_IP_FRAG_TTL_PROTO    (word_IP_FRAG_TTL_PROTO),
         .word_IP_CHECKSUM_SRC_HI   (word_IP_CHECKSUM_SRC_HI),
         .word_IP_SRC_DST           (word_IP_SRC_DST),
         .word_IP_DST_LO            (word_IP_DST_LO),

         // --- interface to process
         .ip_checksum_vld           (ip_checksum_vld),
         .ip_checksum_is_good       (ip_checksum_is_good),
         .ip_hdr_has_options        (ip_hdr_has_options),
         .ip_ttl_is_good            (ip_ttl_is_good),
         .ip_new_ttl                (ip_new_ttl),
         .ip_new_checksum           (ip_new_checksum),     // new checksum assuming decremented TTL
         .rd_checksum               (rd_preprocess_info),

         // misc
         .reset                     (reset),
         .clk                       (clk)
         );

   op_lut_hdr_parser
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .NUM_QUEUES(NUM_QUEUES),
       .INPUT_ARBITER_STAGE_NUM(INPUT_ARBITER_STAGE_NUM),
       .IO_QUEUE_STAGE_NUM(IO_QUEUE_STAGE_NUM)
       ) op_lut_hdr_parser
       ( // --- Interface to the previous stage
         .in_data               (in_data),
         .in_ctrl               (in_ctrl),
         .in_wr                 (in_wr),

         // --- Interface to process block
         .is_from_cpu           (is_from_cpu),
         .to_cpu_output_port    (to_cpu_output_port),
         .from_cpu_output_port  (from_cpu_output_port),
         .input_port_num        (input_port_num),
         .rd_hdr_parser         (rd_preprocess_info),
         .is_from_cpu_vld       (is_from_cpu_vld),

         // --- Misc
         .reset                 (reset),
         .clk                   (clk)
         );

   op_lut_process_sm
     #(.DATA_WIDTH(DATA_WIDTH),
       .CTRL_WIDTH(CTRL_WIDTH),
       .NUM_QUEUES(NUM_QUEUES),
       .STAGE_NUM(STAGE_NUM)
       ) op_lut_process_sm
       ( // --- interface to input fifo - fallthrough
         .in_fifo_vld                   (!in_fifo_empty),
         .in_fifo_data                  (in_fifo_data),
         .in_fifo_ctrl                  (in_fifo_ctrl),
         .in_fifo_rd_en                 (in_fifo_rd_en),

         // --- interface to eth_parser
         .is_arp_pkt                    (is_arp_pkt),
         .is_ip_pkt                     (is_ip_pkt),
         .is_for_us                     (is_for_us),
         .is_broadcast                  (is_broadcast),
         .mac_dst_port_num              (mac_dst_port_num),
         .eth_parser_info_vld           (eth_parser_info_vld),

         // --- interface to ip_arp
         .next_hop_mac                  (next_hop_mac),
         .output_port                   (output_port),
         .arp_mac_vld                   (arp_mac_vld),
         .arp_lookup_hit                (arp_lookup_hit),
         .lpm_lookup_hit                (lpm_lookup_hit),

         // --- interface to op_lut_hdr_parser
         .is_from_cpu                   (is_from_cpu),
         .to_cpu_output_port            (to_cpu_output_port),
         .from_cpu_output_port          (from_cpu_output_port),
         .is_from_cpu_vld               (is_from_cpu_vld),
         .input_port_num                (input_port_num),

         // --- interface to dest_ip_filter
         .dest_ip_hit                   (dest_ip_hit),
         .dest_ip_filter_vld            (dest_ip_filter_vld),

         // --- interface to IP_checksum
         .ip_checksum_vld               (ip_checksum_vld),
         .ip_checksum_is_good           (ip_checksum_is_good),
         .ip_new_checksum               (ip_new_checksum),     // new checksum assuming decremented TTL
         .ip_ttl_is_good                (ip_ttl_is_good),
         .ip_new_ttl                    (ip_new_ttl),
         .ip_hdr_has_options            (ip_hdr_has_options),

         // -- connected to all preprocess blocks
         .rd_preprocess_info            (rd_preprocess_info),

         // --- interface to next module
         .out_wr                        (out_wr),
         .out_data                      (out_data),
         .out_ctrl                      (out_ctrl),     // new checksum assuming decremented TTL
         .out_rdy                       (out_rdy),

         // --- interface to registers
         .pkt_sent_from_cpu             (pkt_sent_from_cpu),              // pulsed: we've sent a pkt from the CPU
         .pkt_sent_to_cpu_options_ver   (pkt_sent_to_cpu_options_ver),    // pulsed: we've sent a pkt to the CPU coz it has options/bad version
         .pkt_sent_to_cpu_bad_ttl       (pkt_sent_to_cpu_bad_ttl),        // pulsed: sent a pkt to the CPU coz the TTL is 1 or 0
         .pkt_sent_to_cpu_dest_ip_hit   (pkt_sent_to_cpu_dest_ip_hit),    // pulsed: sent a pkt to the CPU coz it has hit in the destination ip filter list
         .pkt_forwarded                 (pkt_forwarded     ),             // pulsed: forwarded pkt to the destination port
         .pkt_dropped_checksum          (pkt_dropped_checksum),           // pulsed: dropped pkt coz bad checksum
         .pkt_sent_to_cpu_non_ip        (pkt_sent_to_cpu_non_ip),         // pulsed: sent pkt to cpu coz it's not IP
         .pkt_sent_to_cpu_arp_miss      (pkt_sent_to_cpu_arp_miss),       // pulsed: sent pkt to cpu coz no entry in arp table
         .pkt_sent_to_cpu_lpm_miss      (pkt_sent_to_cpu_lpm_miss),       // pulsed: sent pkt to cpu coz no entry in lpm table
         .pkt_dropped_wrong_dst_mac     (pkt_dropped_wrong_dst_mac),      // pulsed: dropped pkt not destined to us
         .mac_0                         (mac_0),    // address of rx queue 0
         .mac_1                         (mac_1),    // address of rx queue 1
         .mac_2                         (mac_2),    // address of rx queue 2
         .mac_3                         (mac_3),    // address of rx queue 3

         // misc
         .reset                         (reset),
         .clk                           (clk)
         );

   router_op_lut_regs
   #(
      .NUM_QUEUES(NUM_QUEUES),
      .LPM_LUT_DEPTH_BITS(LPM_LUT_DEPTH_BITS),
      .ARP_LUT_DEPTH_BITS(ARP_LUT_DEPTH_BITS),
      .FILTER_DEPTH_BITS(FILTER_DEPTH_BITS),
      .UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH)
   ) op_lut_regs
   (// --- register interface
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

      // --- interface to op_lut_process_sm
      .pkt_sent_from_cpu             (pkt_sent_from_cpu),              // pulsed: we've sent a pkt from the CPU
      .pkt_sent_to_cpu_options_ver   (pkt_sent_to_cpu_options_ver),    // pulsed: we've sent a pkt to the CPU coz it has options/bad version
      .pkt_sent_to_cpu_bad_ttl       (pkt_sent_to_cpu_bad_ttl),        // pulsed: sent a pkt to the CPU coz the TTL is 1 or 0
      .pkt_sent_to_cpu_dest_ip_hit   (pkt_sent_to_cpu_dest_ip_hit),    // pulsed: sent a pkt to the CPU coz it has hit in the destination ip filter list
      .pkt_forwarded                 (pkt_forwarded     ),             // pulsed: forwarded pkt to the destination port
      .pkt_dropped_checksum          (pkt_dropped_checksum),           // pulsed: dropped pkt coz bad checksum
      .pkt_sent_to_cpu_non_ip        (pkt_sent_to_cpu_non_ip),         // pulsed: sent pkt to cpu coz it's not IP
      .pkt_sent_to_cpu_arp_miss      (pkt_sent_to_cpu_arp_miss),       // pulsed: sent pkt to cpu coz no entry in arp table
      .pkt_sent_to_cpu_lpm_miss      (pkt_sent_to_cpu_lpm_miss),       // pulsed: sent pkt to cpu coz no entry in lpm table
      .pkt_dropped_wrong_dst_mac     (pkt_dropped_wrong_dst_mac),      // pulsed: dropped pkt not destined to us

      // --- interface to ip_lpm
      .lpm_rd_addr                   (lpm_rd_addr),          // address in table to read
      .lpm_rd_req                    (lpm_rd_req),           // request a read
      .lpm_rd_ip                     (lpm_rd_ip),            // ip to match in the CAM
      .lpm_rd_mask                   (lpm_rd_mask),          // subnet mask
      .lpm_rd_oq                     (lpm_rd_oq),            // input queue
      .lpm_rd_next_hop_ip            (lpm_rd_next_hop_ip),   // ip addr of next hop
      .lpm_rd_ack                    (lpm_rd_ack),           // pulses high
      .lpm_wr_addr                   (lpm_wr_addr),
      .lpm_wr_req                    (lpm_wr_req),
      .lpm_wr_oq                     (lpm_wr_oq),
      .lpm_wr_next_hop_ip            (lpm_wr_next_hop_ip),   // ip addr of next hop
      .lpm_wr_ip                     (lpm_wr_ip),            // data to match in the CAM
      .lpm_wr_mask                   (lpm_wr_mask),
      .lpm_wr_ack                    (lpm_wr_ack),

      // --- ip_arp
      .arp_rd_addr                   (arp_rd_addr),          // address in table to read
      .arp_rd_req                    (arp_rd_req),           // request a read
      .arp_rd_mac                    (arp_rd_mac),           // data read from the LUT at rd_addr
      .arp_rd_ip                     (arp_rd_ip),            // ip to match in the CAM
      .arp_rd_ack                    (arp_rd_ack),           // pulses high
      .arp_wr_addr                   (arp_wr_addr),
      .arp_wr_req                    (arp_wr_req),
      .arp_wr_mac                    (arp_wr_mac),
      .arp_wr_ip                     (arp_wr_ip),            // data to match in the CAM
      .arp_wr_ack                    (arp_wr_ack),

      // --- interface to ip_lpm
      .dest_ip_filter_rd_addr        (dest_ip_filter_rd_addr),          // address in table to read
      .dest_ip_filter_rd_req         (dest_ip_filter_rd_req),           // request a read
      .dest_ip_filter_rd_ip          (dest_ip_filter_rd_ip),            // ip to match in the CAM
      .dest_ip_filter_rd_ack         (dest_ip_filter_rd_ack),           // pulses high
      .dest_ip_filter_wr_addr        (dest_ip_filter_wr_addr),
      .dest_ip_filter_wr_req         (dest_ip_filter_wr_req),
      .dest_ip_filter_wr_ip          (dest_ip_filter_wr_ip),            // data to match in the CAM
      .dest_ip_filter_wr_ack         (dest_ip_filter_wr_ack),

      // --- eth_parser
      .mac_0                         (mac_0),    // address of rx queue 0
      .mac_1                         (mac_1),    // address of rx queue 1
      .mac_2                         (mac_2),    // address of rx queue 2
      .mac_3                         (mac_3),    // address of rx queue 3

      // --- misc
      .clk                           (clk),
      .reset                         (reset)
      );
endmodule // router_output_port
