/*******************************************************************************
 * vim:set shiftwidth=3 softtabstop=3 expandtab:
 * $Id$
 *
 * Module: output_port_lookup.v
 * Project: generic lookups
 * Author: Jad Naous <jnaous@stanford.edu>
 *
 ******************************************************************************/
`timescale 1ns/1ps
  module output_port_lookup
    #(parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH=DATA_WIDTH/8,
      parameter UDP_REG_SRC_WIDTH = 2,
      parameter IO_QUEUE_STAGE_NUM = `IO_QUEUE_STAGE_NUM,
      parameter NUM_OUTPUT_QUEUES = 8,
      parameter SRAM_ADDR_WIDTH = 19,

      /* the following parameters need to be overridden
       * for the module to work properly!!! */
      parameter SELECT_BYTES_MASK              = 64'h0, // indicates what bytes to use from the packet
      parameter INCLUDE_SRC_PORT               = 1'b0,  // is the src port part of the rule?
      parameter INCLUDE_ADDITIONAL_WORD        = 1'b0,  // use an additional rule from a module header?
      parameter ADDITIONAL_WORD_BYTES_MASK     = 8'h0,  // mask to use on additional module header
      parameter ADDITIONAL_WORD_CTRL           = 0,     // identifies module header to use

      parameter EXACT_LOOKUP_PKT_CNTR_WIDTH    = 0,     // these fields identify the organization
      parameter EXACT_LOOKUP_LAST_SEEN_WIDTH   = 0,     // of the counter word stored in SRAM
      parameter EXACT_LOOKUP_BYTE_CNTR_WIDTH   = 0,
      parameter EXACT_LOOKUP_PKT_CNTR_POS      = 0,
      parameter EXACT_LOOKUP_LAST_SEEN_POS     = 0,
      parameter EXACT_LOOKUP_BYTE_CNTR_POS     = 0,

      parameter TOTAL_LOOKUP_BYTES             = 64,    // number of bytes over which to do the lookup
      parameter NUM_RULE_BYTES                 = 40,    // number of bytes in the full rule
      parameter NUM_ENTRY_DATA_BYTES           = 8,     // number of data bytes associated with the entry

      parameter WILDCARD_REG_ADDR_WIDTH        = 0,
      parameter WILDCARD_LOOKUP_BLOCK_TAG      = 0,

      parameter OPL_LOOKUP_BLOCK_TAG           = 0,
      parameter OPL_LOOKUP_REG_ADDR_WIDTH      = 0,

      parameter OPL_PROCESSOR_BLOCK_TAG        = 0,
      parameter OPL_PROCESSOR_REG_ADDR_WIDTH   = 0
)

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

    // --- SRAM Interface
    output [SRAM_ADDR_WIDTH-1:0]       wr_0_addr,
    output                             wr_0_req,
    input                              wr_0_ack,
    output [DATA_WIDTH+CTRL_WIDTH-1:0] wr_0_data,

    input                              rd_0_ack,
    input  [DATA_WIDTH+CTRL_WIDTH-1:0] rd_0_data,
    input                              rd_0_vld,
    output [SRAM_ADDR_WIDTH-1:0]       rd_0_addr,
    output                             rd_0_req,

    // --- Misc
    input                              clk,
    input                              reset);

   `LOG2_FUNC
   `CEILDIV_FUNC

   //-------------------- Internal Parameters ------------------------
   localparam PKT_SIZE_WIDTH                 = 12;

   localparam ENTRY_DATA_WIDTH               = NUM_ENTRY_DATA_BYTES*8;

   localparam WILDCARD_TABLE_SIZE            = 32;

   localparam NUM_RULE_BITS                  = NUM_RULE_BYTES*8;
   //------------------------ Wires/Regs -----------------------------
   wire [ENTRY_DATA_WIDTH-1:0]                                exact_data;
   wire [ENTRY_DATA_WIDTH-1:0]                                wildcard_data;

   wire [CTRL_WIDTH-1:0]                                      in_fifo_ctrl;
   wire [DATA_WIDTH-1:0]                                      in_fifo_data;

   wire [DATA_WIDTH-1:0]                                      rule_word;
   wire [7:0]                                                 pkt_src_port;
   wire [PKT_SIZE_WIDTH-1:0]                                  pkt_size;

   reg [31:0]                                                 s_counter;
   reg [27:0]                                                 ns_counter;

   wire [`UDP_REG_ADDR_WIDTH-1:0]                             wildcard_reg_addr_out;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]                            wildcard_reg_data_out;
   wire [UDP_REG_SRC_WIDTH-1:0]                               wildcard_reg_src_out;

   wire [`UDP_REG_ADDR_WIDTH-1:0]                             processor_reg_addr_out;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]                            processor_reg_data_out;
   wire [UDP_REG_SRC_WIDTH-1:0]                               processor_reg_src_out;

   //------------------------- Modules -------------------------------

   fallthrough_small_fifo #(.WIDTH(CTRL_WIDTH+DATA_WIDTH), .MAX_DEPTH_BITS(7))
      input_fifo
        (.din           ({in_ctrl, in_data}),  // Data in
         .wr_en         (in_wr),             // Write enable
         .rd_en         (in_fifo_rd_en),    // Read the next word
         .dout          ({in_fifo_ctrl, in_fifo_data}),
         .full          (),
         .prog_full     (),
         .nearly_full   (in_fifo_nearly_full),
         .empty         (in_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   rule_selector
     #(.NUM_RULE_BYTES               (NUM_RULE_BYTES),
       .TOTAL_LOOKUP_BYTES           (TOTAL_LOOKUP_BYTES),
       .SELECT_BYTES_MASK            (SELECT_BYTES_MASK),
       .INCLUDE_SRC_PORT             (INCLUDE_SRC_PORT),
       .INCLUDE_ADDITIONAL_WORD      (INCLUDE_ADDITIONAL_WORD),
       .ADDITIONAL_WORD_BYTES_MASK   (ADDITIONAL_WORD_BYTES_MASK),
       .ADDITIONAL_WORD_CTRL         (ADDITIONAL_WORD_CTRL),
       .DATA_WIDTH                   (DATA_WIDTH),
       .CTRL_WIDTH                   (CTRL_WIDTH),
       .PKT_SIZE_WIDTH               (PKT_SIZE_WIDTH)
       ) rule_selector
       ( // --- Interface to datapath
         .in_data                      (in_data),
         .in_ctrl                      (in_ctrl),
         .in_wr                        (in_wr),

         // --- Interface to lookup modules
         .pkt_size                     (pkt_size),
         .pkt_size_vld                 (pkt_size_vld),

         .rule_word                    (rule_word),
         .rule_word_vld                (rule_word_vld),

         .pkt_src_port                 (pkt_src_port),
         .pkt_src_port_vld             (pkt_src_port_vld),

         // --- Misc
         .reset                        (reset),
         .clk                          (clk)
         );

   exact_match
     #(.NUM_OUTPUT_QUEUES              (NUM_OUTPUT_QUEUES),
       .PKT_SIZE_WIDTH                 (PKT_SIZE_WIDTH),
       .NUM_RULE_BYTES                 (NUM_RULE_BYTES),
       .ENTRY_DATA_WIDTH               (ENTRY_DATA_WIDTH),
       .SRAM_ADDR_WIDTH                (SRAM_ADDR_WIDTH),
       .DATA_WIDTH                     (DATA_WIDTH),
       .EXACT_LOOKUP_PKT_CNTR_WIDTH    (EXACT_LOOKUP_PKT_CNTR_WIDTH),
       .EXACT_LOOKUP_LAST_SEEN_WIDTH   (EXACT_LOOKUP_LAST_SEEN_WIDTH),
       .EXACT_LOOKUP_BYTE_CNTR_WIDTH   (EXACT_LOOKUP_BYTE_CNTR_WIDTH),
       .EXACT_LOOKUP_PKT_CNTR_POS      (EXACT_LOOKUP_PKT_CNTR_POS),
       .EXACT_LOOKUP_LAST_SEEN_POS     (EXACT_LOOKUP_LAST_SEEN_POS),
       .EXACT_LOOKUP_BYTE_CNTR_POS     (EXACT_LOOKUP_BYTE_CNTR_POS),
       .CTRL_WIDTH                     (CTRL_WIDTH)
       ) exact_match
       (// --- Interface for lookups
        .pkt_size         (pkt_size),
        .pkt_size_vld     (pkt_size_vld),
        .rule_word        (rule_word),
        .rule_word_vld    (rule_word_vld),

        // --- Interface to processor
        .exact_hit        (exact_hit),
        .exact_miss       (exact_miss),
        .exact_data       (exact_data),
        .exact_data_vld   (exact_data_vld),

        .exact_wins       (exact_wins),
        .exact_loses      (exact_loses),

        // --- SRAM Interface
        .wr_addr          (wr_0_addr),
        .wr_req           (wr_0_req),
        .wr_ack           (wr_0_ack),
        .wr_data          (wr_0_data),

        .rd_ack           (rd_0_ack),
        .rd_data          (rd_0_data),
        .rd_vld           (rd_0_vld),
        .rd_addr          (rd_0_addr),
        .rd_req           (rd_0_req),

        // --- Misc
        .timer            (s_counter),
        .reset            (reset),
        .clk              (clk)
        );

   wildcard_match
     #(.NUM_OUTPUT_QUEUES           (NUM_OUTPUT_QUEUES),
       .PKT_SIZE_WIDTH              (PKT_SIZE_WIDTH),
       .NUM_RULE_BYTES              (NUM_RULE_BYTES),
       .ENTRY_DATA_WIDTH            (ENTRY_DATA_WIDTH),
       .UDP_REG_SRC_WIDTH           (UDP_REG_SRC_WIDTH),
       .WILDCARD_TABLE_SIZE         (WILDCARD_TABLE_SIZE),
       .WILDCARD_REG_ADDR_WIDTH     (WILDCARD_REG_ADDR_WIDTH),
       .WILDCARD_LOOKUP_BLOCK_TAG   (WILDCARD_LOOKUP_BLOCK_TAG),
       .DATA_WIDTH                  (DATA_WIDTH)
       ) wildcard_match
       ( // --- Interface for lookups
         .rule_word                            (rule_word),
         .rule_word_vld                        (rule_word_vld),
         .pkt_size                             (pkt_size),
         .pkt_size_vld                         (pkt_size_vld),

         // --- Interface to processor
         .wildcard_hit                         (wildcard_hit),
         .wildcard_miss                        (wildcard_miss),
         .wildcard_data                        (wildcard_data),
         .wildcard_data_vld                    (wildcard_data_vld),
         .wildcard_wins                        (wildcard_wins),
         .wildcard_loses                       (wildcard_loses),

         // --- Interface to register bus
         .reg_req_in                           (reg_req_in),
         .reg_ack_in                           (reg_ack_in),
         .reg_rd_wr_L_in                       (reg_rd_wr_L_in),
         .reg_addr_in                          (reg_addr_in),
         .reg_data_in                          (reg_data_in),
         .reg_src_in                           (reg_src_in),

         .reg_req_out                          (wildcard_reg_req_out),
         .reg_ack_out                          (wildcard_reg_ack_out),
         .reg_rd_wr_L_out                      (wildcard_reg_rd_wr_L_out),
         .reg_addr_out                         (wildcard_reg_addr_out),
         .reg_data_out                         (wildcard_reg_data_out),
         .reg_src_out                          (wildcard_reg_src_out),

         .timer                                (s_counter), // bus size 32

         .clk                                  (clk),
         .reset                                (reset));

   opl_processor
     #(.NUM_OUTPUT_QUEUES              (NUM_OUTPUT_QUEUES),
       .PKT_SIZE_WIDTH                 (PKT_SIZE_WIDTH),
       .NUM_RULE_BYTES                 (NUM_RULE_BYTES),
       .ENTRY_DATA_WIDTH               (ENTRY_DATA_WIDTH),
       .OPL_PROCESSOR_REG_ADDR_WIDTH   (OPL_PROCESSOR_REG_ADDR_WIDTH),
       .OPL_PROCESSOR_BLOCK_TAG        (OPL_PROCESSOR_BLOCK_TAG),
       .DATA_WIDTH                     (DATA_WIDTH),
       .CTRL_WIDTH                     (CTRL_WIDTH),
       .UDP_REG_SRC_WIDTH              (UDP_REG_SRC_WIDTH)
       ) opl_processor
       (// --- interface to lookups
        .wildcard_hit        (wildcard_hit),
        .wildcard_miss       (wildcard_miss),
        .wildcard_data       (wildcard_data),
        .wildcard_data_vld   (wildcard_data_vld),
        .wildcard_wins       (wildcard_wins),
        .wildcard_loses      (wildcard_loses),

        .exact_hit           (exact_hit),
        .exact_miss          (exact_miss),
        .exact_data          (exact_data),
        .exact_data_vld      (exact_data_vld),
        .exact_wins          (exact_wins),
        .exact_loses         (exact_loses),

        .pkt_src_port        (pkt_src_port),
        .pkt_src_port_vld    (pkt_src_port_vld),

        // --- interface to input fifo
        .in_fifo_ctrl        (in_fifo_ctrl),
        .in_fifo_data        (in_fifo_data),
        .in_fifo_rd_en       (in_fifo_rd_en),
        .in_fifo_empty       (in_fifo_empty),

        // --- interface to output
        .out_wr              (out_wr),
        .out_rdy             (out_rdy),
        .out_data            (out_data),
        .out_ctrl            (out_ctrl),

        // --- interface to register bus
        .reg_req_in          (wildcard_reg_req_out),
        .reg_ack_in          (wildcard_reg_ack_out),
        .reg_rd_wr_L_in      (wildcard_reg_rd_wr_L_out),
        .reg_addr_in         (wildcard_reg_addr_out),
        .reg_data_in         (wildcard_reg_data_out),
        .reg_src_in          (wildcard_reg_src_out),

        .reg_req_out         (processor_reg_req_out),
        .reg_ack_out         (processor_reg_ack_out),
        .reg_rd_wr_L_out     (processor_reg_rd_wr_L_out),
        .reg_addr_out        (processor_reg_addr_out),
        .reg_data_out        (processor_reg_data_out),
        .reg_src_out         (processor_reg_src_out),

        // --- Misc
        .clk                 (clk),
        .reset               (reset));

   generic_regs
     #(.UDP_REG_SRC_WIDTH (UDP_REG_SRC_WIDTH),
       .TAG (OPL_LOOKUP_BLOCK_TAG),
       .REG_ADDR_WIDTH (OPL_LOOKUP_REG_ADDR_WIDTH),
       .RESET_ON_READ (0),
       .NUM_COUNTERS (2*2
                      ),
       .NUM_SOFTWARE_REGS (0),
       .NUM_HARDWARE_REGS (1),
       .COUNTER_INPUT_WIDTH (1)
       )
   generic_regs
     (
      .reg_req_in        (processor_reg_req_out),
      .reg_ack_in        (processor_reg_ack_out),
      .reg_rd_wr_L_in    (processor_reg_rd_wr_L_out),
      .reg_addr_in       (processor_reg_addr_out),
      .reg_data_in       (processor_reg_data_out),
      .reg_src_in        (processor_reg_src_out),

      .reg_req_out       (reg_req_out),
      .reg_ack_out       (reg_ack_out),
      .reg_rd_wr_L_out   (reg_rd_wr_L_out),
      .reg_addr_out      (reg_addr_out),
      .reg_data_out      (reg_data_out),
      .reg_src_out       (reg_src_out),

      // --- counters interface
      .counter_updates   ({exact_wins,
                           exact_miss,
                           wildcard_wins,
                           wildcard_miss}
                          ),
      .counter_decrement (4'h0),

      // --- SW regs interface
      .software_regs     (),

      // --- HW regs interface
      .hardware_regs     (s_counter),

      .clk               (clk),
      .reset             (reset));

   //--------------------------- Logic ------------------------------
   assign in_rdy = !in_fifo_nearly_full;

   // timer
   always @(posedge clk) begin
      if(reset) begin
         ns_counter <= 0;
         s_counter  <= 0;
      end
      else begin
         if(ns_counter == (1_000_000_000/`FAST_CLOCK_PERIOD - 1'b1)) begin
            s_counter  <= s_counter + 1'b1;
            ns_counter <= 0;
         end
         else begin
            ns_counter <= ns_counter + 1'b1;
         end
      end // else: !if(reset)
   end // always @ (posedge clk)


endmodule // output_port_lookup

