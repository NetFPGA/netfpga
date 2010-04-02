///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: oq_reg_helper.v 5424 2009-05-01 00:17:23Z grg $
//
// Module: oq_reg_helper.v
// Project: NF2.1
// Description: decodes and handles reg requests for a single queue
//
///////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps

  module oq_reg_helper
    #(
       parameter SRAM_ADDR_WIDTH     = 19,
       parameter CTRL_WIDTH          = 8,
       parameter UDP_REG_SRC_WIDTH   = 2,
       parameter NUM_OUTPUT_QUEUES   = 5,
       parameter OQ_NUM              = 0,
       parameter NUM_OQ_WIDTH        = log2(NUM_OUTPUT_QUEUES),
       parameter PKT_LEN_WIDTH       = 11)

   (
      input                                  reg_req_in,
      input                                  reg_ack_in,
      input                                  reg_rd_wr_L_in,
      input  [`UDP_REG_ADDR_WIDTH-1:0]       reg_addr_in,
      input  [`CPCI_NF2_DATA_WIDTH-1:0]      reg_data_in,
      input  [UDP_REG_SRC_WIDTH-1:0]         reg_src_in,

      output reg                             reg_req_out,
      output reg                             reg_ack_out,
      output reg                             reg_rd_wr_L_out,
      output reg [`UDP_REG_ADDR_WIDTH-1:0]   reg_addr_out,
      output reg [`CPCI_NF2_DATA_WIDTH-1:0]  reg_data_out,
      output reg [UDP_REG_SRC_WIDTH-1:0]     reg_src_out,

     input      [NUM_OQ_WIDTH-1:0]        removed_pkt_oq,
     input      [NUM_OQ_WIDTH-1:0]        src_oq,
     input      [NUM_OQ_WIDTH-1:0]        dst_oq,

     input      [SRAM_ADDR_WIDTH-1:0]     src_oq_rd_addr_new,
     input                                pkt_removed,
     input                                pkt_read,
     input      [PKT_LEN_WIDTH-1:0]       removed_pkt_data_length,
     input      [CTRL_WIDTH-1:0]          removed_pkt_overhead_length,
     input      [SRAM_ADDR_WIDTH-1:0]     dst_oq_wr_addr_new,
     input                                pkt_stored,
     input      [PKT_LEN_WIDTH-1:0]       stored_pkt_data_length,
     input      [CTRL_WIDTH-1:0]          stored_pkt_overhead_length,
     input                                pkt_dropped,

     output reg                           oq_empty,
     output reg                           oq_full,
     output     [SRAM_ADDR_WIDTH-1:0]     oq_wr_addr,
     output     [SRAM_ADDR_WIDTH-1:0]     oq_rd_addr,
     output     [SRAM_ADDR_WIDTH-1:0]     oq_addr_hi,
     output     [SRAM_ADDR_WIDTH-1:0]     oq_addr_lo,
     output     [`CPCI_NF2_DATA_WIDTH-1:0] num_words_in_q,

     output                               enable_send_pkt,

     // --- Misc
     input                                clk,
     input                                reset
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

   // ------------- Internal parameters --------------
   localparam MAX_PKT          = 2048/CTRL_WIDTH;   // allow for 2K bytes
   localparam NUM_REGS_USED    = 17;

   localparam ADDR_WIDTH       = log2(NUM_REGS_USED);

   localparam LOCAL_TAG        = {`OQ_BLOCK_ADDR, `OQ_QUEUE_INST_BLOCK_ADDR_WIDTH'h0} +
                                 OQ_NUM * `OQ_QUEUE_INST_BLOCK_ADDR_WIDTH'h1;

   // ------------- Wires/reg ------------------

   reg [`CPCI_NF2_DATA_WIDTH-1:0]       reg_file [0:NUM_REGS_USED-1];

   wire [`CPCI_NF2_DATA_WIDTH-1:0]      num_pkt_bytes_stored;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      num_overhead_bytes_stored;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      num_pkts_stored;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      num_pkts_dropped;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      num_pkt_bytes_removed;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      num_overhead_bytes_removed;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      num_pkts_removed;
   wire [15:0]                          max_pkts_in_q;
   wire [15:0]                          num_pkts_in_q;
   wire [SRAM_ADDR_WIDTH-1:0]           num_words_left;
   wire [`CPCI_NF2_DATA_WIDTH-1:0]      control_reg;
   wire [SRAM_ADDR_WIDTH-1:0]           oq_addr_hi_reg;
   wire [SRAM_ADDR_WIDTH-1:0]           oq_addr_lo_reg;
   wire [SRAM_ADDR_WIDTH-1:0]           oq_wr_addr_reg;
   wire [SRAM_ADDR_WIDTH-1:0]           oq_rd_addr_reg;

   wire [SRAM_ADDR_WIDTH-1:0]           oq_full_thresh;  // used to limit the space used in the queue

   wire [ADDR_WIDTH-1:0]                addr;
   wire [`OQ_QUEUE_INST_REG_ADDR_WIDTH - 1:0] reg_addr;
   wire [`UDP_REG_ADDR_WIDTH -
         `OQ_QUEUE_INST_REG_ADDR_WIDTH - 1:0] tag_addr;

   wire                                 addr_good;
   wire                                 tag_hit;

   reg [SRAM_ADDR_WIDTH-1:0]            wr_addr_less_rd_addr;

   reg [SRAM_ADDR_WIDTH-1:0]            dst_oq_wr_addr_new_d1;
   reg [PKT_LEN_WIDTH-1:0]              stored_pkt_data_length_d1;
   reg [CTRL_WIDTH-1:0]                 stored_pkt_overhead_length_d1;
   reg                                  pkt_stored_in_q;
   reg                                  pkt_dropped_in_q;

   // -------------- Logic --------------------
   assign control_reg                   = reg_file[`OQ_QUEUE_CTRL];
   assign num_pkt_bytes_stored          = reg_file[`OQ_QUEUE_NUM_PKT_BYTES_STORED];
   assign num_overhead_bytes_stored     = reg_file[`OQ_QUEUE_NUM_OVERHEAD_BYTES_STORED];
   assign num_pkts_stored               = reg_file[`OQ_QUEUE_NUM_PKTS_STORED];
   assign num_pkts_dropped              = reg_file[`OQ_QUEUE_NUM_PKTS_DROPPED];
   assign num_pkt_bytes_removed         = reg_file[`OQ_QUEUE_NUM_PKT_BYTES_REMOVED];
   assign num_overhead_bytes_removed    = reg_file[`OQ_QUEUE_NUM_OVERHEAD_BYTES_REMOVED];
   assign num_pkts_removed              = reg_file[`OQ_QUEUE_NUM_PKTS_REMOVED];
   assign oq_addr_hi_reg                = reg_file[`OQ_QUEUE_ADDR_HI];
   assign oq_addr_lo_reg                = reg_file[`OQ_QUEUE_ADDR_LO];
   assign oq_wr_addr_reg                = reg_file[`OQ_QUEUE_WR_ADDR];
   assign oq_rd_addr_reg                = reg_file[`OQ_QUEUE_RD_ADDR];
   assign max_pkts_in_q                 = reg_file[`OQ_QUEUE_MAX_PKTS_IN_Q];
   assign num_pkts_in_q                 = reg_file[`OQ_QUEUE_NUM_PKTS_IN_Q];
   assign num_words_left                = reg_file[`OQ_QUEUE_NUM_WORDS_LEFT];
   assign num_words_in_q                = reg_file[`OQ_QUEUE_NUM_WORDS_IN_Q];

   assign oq_full_thresh                = reg_file[`OQ_QUEUE_FULL_THRESH];

   assign oq_addr_hi                    = oq_addr_hi_reg[SRAM_ADDR_WIDTH-1:0];
   assign oq_addr_lo                    = oq_addr_lo_reg[SRAM_ADDR_WIDTH-1:0];
   assign oq_wr_addr                    = oq_wr_addr_reg[SRAM_ADDR_WIDTH-1:0];
   assign oq_rd_addr                    = oq_rd_addr_reg[SRAM_ADDR_WIDTH-1:0];

   assign enable_send_pkt               = control_reg[`OQ_ENABLE_SEND_BIT_NUM];
   assign initialize_oq                 = control_reg[`OQ_INITIALIZE_OQ_BIT_NUM];

   assign pkt_removed_from_q            = pkt_removed && (removed_pkt_oq == OQ_NUM);
   assign pkt_read_from_q               = pkt_read    && (src_oq         == OQ_NUM);

   assign addr = reg_addr_in[ADDR_WIDTH-1:0];
   assign reg_addr = reg_addr_in[`OQ_QUEUE_INST_REG_ADDR_WIDTH-1:0];
   assign tag_addr = reg_addr_in[`UDP_REG_ADDR_WIDTH - 1:`OQ_QUEUE_INST_REG_ADDR_WIDTH];

   assign addr_good = (reg_addr<NUM_REGS_USED);
   assign tag_hit = tag_addr == LOCAL_TAG;

   always @(posedge clk) begin

      reg_req_out <= reg_req_in;
      reg_rd_wr_L_out <= reg_rd_wr_L_in;
      reg_addr_out <= reg_addr_in;
      reg_src_out <= reg_src_in;

      if(reset) begin

         pkt_stored_in_q                             <= 0;
         pkt_dropped_in_q                            <= 0;

         reg_ack_out                                 <= 0;
         reg_data_out                                <= 0;

         reg_file[`OQ_QUEUE_CTRL]                        <= `OQ_ENABLE_SEND_BIT_NUM;
         reg_file[`OQ_QUEUE_NUM_PKT_BYTES_STORED]        <= 0;
         reg_file[`OQ_QUEUE_NUM_OVERHEAD_BYTES_STORED]   <= 0;
         reg_file[`OQ_QUEUE_NUM_PKTS_STORED]             <= 0;
         reg_file[`OQ_QUEUE_NUM_PKTS_DROPPED]            <= 0;
         reg_file[`OQ_QUEUE_NUM_PKT_BYTES_REMOVED]       <= 0;
         reg_file[`OQ_QUEUE_NUM_OVERHEAD_BYTES_REMOVED]  <= 0;
         reg_file[`OQ_QUEUE_NUM_PKTS_REMOVED]            <= 0;
         reg_file[`OQ_QUEUE_ADDR_HI]                     <= `OQ_DEFAULT_ADDR_HIGH(OQ_NUM, NUM_OUTPUT_QUEUES);
         reg_file[`OQ_QUEUE_ADDR_LO]                     <= `OQ_DEFAULT_ADDR_LOW(OQ_NUM, NUM_OUTPUT_QUEUES);
         reg_file[`OQ_QUEUE_WR_ADDR]                     <= `OQ_DEFAULT_ADDR_LOW(OQ_NUM, NUM_OUTPUT_QUEUES);
         reg_file[`OQ_QUEUE_RD_ADDR]                     <= `OQ_DEFAULT_ADDR_LOW(OQ_NUM, NUM_OUTPUT_QUEUES);
         reg_file[`OQ_QUEUE_MAX_PKTS_IN_Q]               <= `OQ_DEFAULT_MAX_PKTS;
         reg_file[`OQ_QUEUE_NUM_PKTS_IN_Q]               <= 0;
         reg_file[`OQ_QUEUE_NUM_WORDS_LEFT]              <= `OQ_DEFAULT_ADDR_HIGH(OQ_NUM, NUM_OUTPUT_QUEUES) -
                                                            `OQ_DEFAULT_ADDR_LOW(OQ_NUM, NUM_OUTPUT_QUEUES);
         reg_file[`OQ_QUEUE_FULL_THRESH]                 <= 0;
         oq_full     <= 0;
         oq_empty    <= 1;
      end
      else begin
         pkt_stored_in_q                             <= pkt_stored  && (dst_oq == OQ_NUM);
         pkt_dropped_in_q                            <= pkt_dropped && (dst_oq == OQ_NUM);
         stored_pkt_overhead_length_d1               <= stored_pkt_overhead_length;
         stored_pkt_data_length_d1                   <= stored_pkt_data_length;
         dst_oq_wr_addr_new_d1                       <= dst_oq_wr_addr_new;

         oq_full                                     <= (num_words_left < 2*MAX_PKT) || (num_pkts_in_q >= max_pkts_in_q) || (num_words_left < oq_full_thresh);
         oq_empty                                    <= initialize_oq ? 1 : (num_pkts_in_q==0);

         // writable regs
         reg_file[`OQ_QUEUE_NUM_PKT_BYTES_STORED]        <= (num_pkt_bytes_stored + (pkt_stored_in_q ? stored_pkt_data_length_d1 : 0));
         reg_file[`OQ_QUEUE_NUM_OVERHEAD_BYTES_STORED]   <= (num_overhead_bytes_stored + (pkt_stored_in_q ? stored_pkt_overhead_length_d1 : 0));

         if(pkt_stored_in_q) begin
            reg_file[`OQ_QUEUE_NUM_PKTS_STORED]          <= (num_pkts_stored + 1'b1);
         end

         if(pkt_dropped_in_q) begin
            reg_file[`OQ_QUEUE_NUM_PKTS_DROPPED]         <= (num_pkts_dropped + 1'b1);
         end

         reg_file[`OQ_QUEUE_NUM_PKT_BYTES_REMOVED]       <= (num_pkt_bytes_removed + (pkt_removed_from_q ? removed_pkt_data_length : 0));
         reg_file[`OQ_QUEUE_NUM_OVERHEAD_BYTES_REMOVED]  <= (num_overhead_bytes_removed + (pkt_removed_from_q ? removed_pkt_overhead_length : 0));

         if(pkt_removed_from_q) begin
            reg_file[`OQ_QUEUE_NUM_PKTS_REMOVED]         <= (num_pkts_removed + 1'b1);
         end

         reg_file[`OQ_QUEUE_ADDR_HI]                     <= oq_addr_hi_reg;
         reg_file[`OQ_QUEUE_ADDR_LO]                     <= oq_addr_lo_reg;
         reg_file[`OQ_QUEUE_WR_ADDR]                     <= (initialize_oq ? {13'h0, oq_addr_lo_reg[SRAM_ADDR_WIDTH-1:0]}
                                                           : (pkt_stored_in_q ? {13'h0, dst_oq_wr_addr_new_d1} : {13'h0, oq_wr_addr_reg[SRAM_ADDR_WIDTH-1:0]}));
         reg_file[`OQ_QUEUE_RD_ADDR]                     <= (initialize_oq ? {13'h0, oq_addr_lo_reg[SRAM_ADDR_WIDTH-1:0]}
                                                           : (pkt_read_from_q ? {13'h0, src_oq_rd_addr_new} : {13'h0, oq_rd_addr_reg[SRAM_ADDR_WIDTH-1:0]}));

         /* handle writes */
         if (reg_req_in && tag_hit) begin
            if(addr_good && !reg_rd_wr_L_in) begin // write
               reg_file[addr] <= reg_data_in;
            end

            if(addr_good) begin
               reg_data_out <= reg_file[addr];
            end
            else begin
               reg_data_out <= 32'hdead_beef;
            end

            reg_ack_out <= 1'b 1;
         end
         else begin
            reg_ack_out <= reg_ack_in;
            reg_data_out <= reg_data_in;
         end

         // read-only regs
         case ({pkt_stored_in_q, pkt_removed_from_q})
            2'b10: reg_file[`OQ_QUEUE_NUM_PKTS_IN_Q]     <= (num_pkts_in_q + 1'b1);
            2'b01: reg_file[`OQ_QUEUE_NUM_PKTS_IN_Q]     <= (num_pkts_in_q - 1'b1);
            default: reg_file[`OQ_QUEUE_NUM_PKTS_IN_Q]   <= num_pkts_in_q;
         endcase // case({(pkt_stored && dst_oq==i), (pkt_removed && removed_pkt_oq==i)})

         if((oq_wr_addr >= oq_rd_addr)) begin
            reg_file[`OQ_QUEUE_NUM_WORDS_LEFT]             <= {13'h0, (oq_addr_hi - oq_wr_addr) + (oq_rd_addr - oq_addr_lo)};
            reg_file[`OQ_QUEUE_NUM_WORDS_IN_Q]             <= {13'h0, wr_addr_less_rd_addr};
         end
         else begin
            reg_file[`OQ_QUEUE_NUM_WORDS_LEFT]             <= {13'h0, (oq_rd_addr - oq_wr_addr)};
            reg_file[`OQ_QUEUE_NUM_WORDS_IN_Q]             <= {13'h0, (oq_addr_hi + wr_addr_less_rd_addr) - (oq_addr_lo + 1'b1)};
         end

         wr_addr_less_rd_addr <= (oq_wr_addr - oq_rd_addr);

      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // oq_reg_helper


