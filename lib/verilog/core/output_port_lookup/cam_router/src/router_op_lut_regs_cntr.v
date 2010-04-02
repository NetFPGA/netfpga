///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: router_op_lut_regs_cntr.v 5499 2009-05-06 22:56:18Z grg $
//
// Module: router_op_lut_regs_cntr.v
// Project: NF2.1
// Description: Demultiplexes, stores and serves register requests
//
// Counter registers
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

module router_op_lut_regs_cntr
   #(
       parameter UDP_REG_SRC_WIDTH = 2
   )
   (
      input                                  reg_req_in,
      input                                  reg_ack_in,
      input                                  reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]         reg_src_in,

      output                                 reg_req_out,
      output                                 reg_ack_out,
      output                                 reg_rd_wr_L_out,
      output [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_out,
      output [`CPCI_NF2_DATA_WIDTH-1:0]      reg_data_out,
      output [UDP_REG_SRC_WIDTH-1:0]         reg_src_out,

      // --- interface to op_lut_process_sm
      input                                  pkt_sent_from_cpu,            // pulsed: we've sent a pkt from the CPU
      input                                  pkt_sent_to_cpu_options_ver,  // pulsed: we've sent a pkt to the CPU coz it has options/bad version
      input                                  pkt_sent_to_cpu_bad_ttl,      // pulsed: sent a pkt to the CPU coz the TTL is 1 or 0
      input                                  pkt_sent_to_cpu_dest_ip_hit,  // pulsed: sent a pkt to the CPU coz it has hit in the destination ip filter list
      input                                  pkt_forwarded,                // pulsed: forwarded pkt to the destination port
      input                                  pkt_dropped_checksum,         // pulsed: dropped pkt coz bad checksum
      input                                  pkt_sent_to_cpu_non_ip,       // pulsed: sent pkt to cpu coz it's not IP
      input                                  pkt_sent_to_cpu_arp_miss,     // pulsed: sent pkt to cpu coz we didn't find arp entry for next hop ip
      input                                  pkt_sent_to_cpu_lpm_miss,     // pulsed: sent pkt to cpu coz we didn't find lpm entry for destination ip
      input                                  pkt_dropped_wrong_dst_mac,    // pulsed: dropped pkt not destined to us

      input                                  clk,
      input                                  reset
    );

   // ------------- Internal parameters --------------
   localparam NUM_REGS_USED = 10;

   // ------------- Wires/reg ------------------

   wire [NUM_REGS_USED-1:0]   updates;

   // -------------- Logic --------------------
   generic_cntr_regs
   #(
      .UDP_REG_SRC_WIDTH   (UDP_REG_SRC_WIDTH),
      .TAG                 (`ROUTER_OP_LUT_BLOCK_ADDR),  // Tag to match against
      .REG_ADDR_WIDTH      (`ROUTER_OP_LUT_REG_ADDR_WIDTH),// Width of block addresses
      .NUM_REGS_USED       (NUM_REGS_USED),              // How many registers
      .INPUT_WIDTH         (1),                          // Width of each update request
      .MIN_UPDATE_INTERVAL (8),                          // Clocks between successive inputs
      .REG_WIDTH           (`CPCI_NF2_DATA_WIDTH),       // How wide should each counter be?
      .RESET_ON_READ       (0)
   ) generic_cntr_regs (
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

      // --- update interface
      .updates          (updates),
      .decrement        ('h0),

      .clk              (clk),
      .reset            (reset)
    );

    assign updates[`ROUTER_OP_LUT_ARP_NUM_MISSES]     = pkt_sent_to_cpu_arp_miss;
    assign updates[`ROUTER_OP_LUT_LPM_NUM_MISSES]     = pkt_sent_to_cpu_lpm_miss;
    assign updates[`ROUTER_OP_LUT_NUM_CPU_PKTS_SENT]  = pkt_sent_from_cpu;
    assign updates[`ROUTER_OP_LUT_NUM_BAD_OPTS_VER]   = pkt_sent_to_cpu_options_ver;
    assign updates[`ROUTER_OP_LUT_NUM_BAD_CHKSUMS]    = pkt_dropped_checksum;
    assign updates[`ROUTER_OP_LUT_NUM_BAD_TTLS]       = pkt_sent_to_cpu_bad_ttl;
    assign updates[`ROUTER_OP_LUT_NUM_NON_IP_RCVD]    = pkt_sent_to_cpu_non_ip;
    assign updates[`ROUTER_OP_LUT_NUM_PKTS_FORWARDED] = pkt_forwarded;
    assign updates[`ROUTER_OP_LUT_NUM_WRONG_DEST]     = pkt_dropped_wrong_dst_mac;
    assign updates[`ROUTER_OP_LUT_NUM_FILTERED_PKTS]  = pkt_sent_to_cpu_dest_ip_hit;

endmodule
