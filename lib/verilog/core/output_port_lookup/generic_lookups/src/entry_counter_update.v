/*******************************************************************************
 * $Id$
 *
 * Module: entry_counter_update.v
 * Project: generic lookups
 * Author: Jad Naous <jnaous@stanford.edu>
 * Description: updates the counters for an entry that hit in the lookup
 *
 *******************************************************************************/

module entry_counter_update
    #(parameter NUM_RULE_BYTES = 48,
      parameter ENTRY_DATA_WIDTH = 128,
      parameter ENTRY_ADDR_WIDTH = 15,
      parameter SRAM_ADDR_WIDTH = 19,
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8,
      parameter PKT_CNTR_WIDTH = 25,
      parameter LAST_SEEN_WIDTH = 7,
      parameter BYTE_CNTR_WIDTH = 32,
      parameter PKT_CNTR_POS = 0,
      parameter LAST_SEEN_POS = PKT_CNTR_POS + PKT_CNTR_WIDTH,
      parameter BYTE_CNTR_POS = LAST_SEEN_POS + LAST_SEEN_WIDTH,
      parameter PKT_SIZE_WIDTH = 12
      )
   (// --- SRAM Interface
    input                                   wr_ack,
    output reg [DATA_WIDTH-1:0]             wr_data,
    output reg [SRAM_ADDR_WIDTH-1:0]        wr_addr,
    output reg                              wr_req,

    // --- rule maker interface
    input [PKT_SIZE_WIDTH-1:0]              pkt_size,
    input                                   pkt_size_vld,

    // --- Lookup results
    input  [ENTRY_ADDR_WIDTH-1:0]           found_entry_hash,
    input                                   entry_hit,
    input                                   entry_miss,

    input                                   exact_wins,
    input                                   exact_loses,

    input      [DATA_WIDTH-1:0]             entry_counters,
    input                                   entry_data_vld,

    // --- Misc
    input [7:0]                             timer,
    input                                   reset,
    input                                   clk
   );

   `LOG2_FUNC
   `CEILDIV_FUNC

   //-------------------- Internal Parameters ------------------------
   localparam NUM_RULE_WORDS       = ceildiv(NUM_RULE_BYTES*8, DATA_WIDTH);
   localparam NUM_DATA_WORDS       = ceildiv(ENTRY_DATA_WIDTH, DATA_WIDTH);
   localparam ENTRY_IDX_WIDTH      = SRAM_ADDR_WIDTH - ENTRY_ADDR_WIDTH;

   //---------------------- Wires and regs----------------------------
   reg                         rd_hashes_fifo;
   reg                         rd_pkt_size_fifo;
   reg                         rd_cntr_fifo;
   reg                         rd_status_fifo;

   reg [DATA_WIDTH-1:0]        wr_data_nxt;
   reg [SRAM_ADDR_WIDTH-1:0]   wr_addr_nxt;
   reg                         wr_req_nxt;

   wire                        dout_entry_hit;
   wire [ENTRY_ADDR_WIDTH-1:0] dout_hash;

   wire [PKT_SIZE_WIDTH-1:0]   dout_pkt_size;
   wire [DATA_WIDTH-1:0]       dout_cntr;

   wire [DATA_WIDTH-1:0]       new_entry_counters;

   //------------------------- Modules -------------------------------
   fallthrough_small_fifo
     #(.WIDTH(1+ENTRY_ADDR_WIDTH), .MAX_DEPTH_BITS(2))
      hashes_fifo
        (.din           ({entry_hit, found_entry_hash}),
         .wr_en         (entry_hit | entry_miss),
         .rd_en         (rd_hashes_fifo),
         .dout          ({dout_entry_hit, dout_hash}),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (hash_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   fallthrough_small_fifo
     #(.WIDTH(PKT_SIZE_WIDTH), .MAX_DEPTH_BITS(2))
      pkt_size_fifo
        (.din           (pkt_size),
         .wr_en         (pkt_size_vld),
         .rd_en         (rd_pkt_size_fifo),
         .dout          (dout_pkt_size),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (pkt_size_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   fallthrough_small_fifo
     #(.WIDTH(DATA_WIDTH), .MAX_DEPTH_BITS(2))
      cntr_fifo
        (.din           (entry_counters),
         .wr_en         (entry_data_vld),
         .rd_en         (rd_cntr_fifo),
         .dout          (dout_cntr),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (cntr_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   fallthrough_small_fifo
     #(.WIDTH(1), .MAX_DEPTH_BITS(2))
      update_status_fifo
        (.din           (exact_wins),
         .wr_en         (exact_wins | exact_loses),
         .rd_en         (rd_status_fifo),
         .dout          (dout_exact_wins),
         .full          (),
         .prog_full     (),
         .nearly_full   (),
         .empty         (status_fifo_empty),
         .reset         (reset),
         .clk           (clk)
         );

   //-------------------------- Logic --------------------------------

   assign new_entry_counters[BYTE_CNTR_POS + BYTE_CNTR_WIDTH - 1 : BYTE_CNTR_POS]
          = dout_cntr[BYTE_CNTR_POS + BYTE_CNTR_WIDTH - 1 : BYTE_CNTR_POS] + dout_pkt_size;

   assign new_entry_counters[PKT_CNTR_POS + PKT_CNTR_WIDTH - 1 : PKT_CNTR_POS]
          = dout_cntr[PKT_CNTR_POS + PKT_CNTR_WIDTH - 1 : PKT_CNTR_POS] + 1'b1;

   assign new_entry_counters[LAST_SEEN_POS + LAST_SEEN_WIDTH - 1 : LAST_SEEN_POS]
          = timer;

   always @(*) begin
      /* defaults */
      rd_hashes_fifo      = 0;
      rd_pkt_size_fifo    = 0;
      rd_cntr_fifo        = 0;
      rd_status_fifo      = 0;
      wr_req_nxt          = wr_req;
      wr_data_nxt         = wr_data;
      wr_addr_nxt         = wr_addr;

      /* wait until the last request is acked */
      if(wr_req == 0) begin
         /* wait until we know what to do with the info */
         if(!hash_fifo_empty && !status_fifo_empty) begin
            /* if it were a hit */
            if(dout_entry_hit) begin
               /* wait until updated info is available */
               if(!cntr_fifo_empty && !pkt_size_fifo_empty) begin
                  /* if we want to record it, then write*/
                  if(dout_exact_wins) begin
                     wr_req_nxt          = 1'b1;
                     wr_data_nxt         = new_entry_counters;
                     wr_addr_nxt         = {dout_hash,
                                            NUM_RULE_WORDS[ENTRY_IDX_WIDTH-1:0]};
                  end
                  /* go to next info from fifos */
                  rd_hashes_fifo      = 1'b1;
                  rd_pkt_size_fifo    = 1'b1;
                  rd_cntr_fifo        = 1'b1;
                  rd_status_fifo      = 1'b1;
               end // if (!cntr_fifo_empty && !pkt_size_fifo_empty)
            end // if (dout_entry_hit)

            /* otherwise if the entry is a miss, then we won't get
             * the entry counter */
            else begin
               if(!pkt_size_fifo_empty) begin
                  /* go to next info from fifos */
                  rd_hashes_fifo      = 1'b1;
                  rd_pkt_size_fifo    = 1'b1;
                  rd_status_fifo      = 1'b1;
               end
            end // else: !if(dout_entry_hit)
         end // if (!hash_fifo_empty && !status_fifo_empty)
      end // if (wr_req == 0)

      /* we are waiting for a request to be satisfied.
       * if the ack arrives, then lower the request */
      else if(wr_ack) begin
         wr_req_nxt   = 0;
      end
   end // always @ (*)

   always @(posedge clk) begin
      if(reset) begin
         wr_req     <= 0;
         wr_data    <= 0;
         wr_addr    <= 0;
      end
      else begin
         wr_req     <= wr_req_nxt;
         wr_data    <= wr_data_nxt;
         wr_addr    <= wr_addr_nxt;
      end // else: !if(reset)
   end // always @ (posedge clk)

endmodule // entry_counter_update
