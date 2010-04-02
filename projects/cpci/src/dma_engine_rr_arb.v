///////////////////////////////////////////////////////////////////////////////
// $Id: dma_engine_rr_arb.v 3617 2008-04-16 23:16:30Z grg $
//
// Module: dma_engine_rr_arb.v
// Project: CPCI (PCI Control FPGA)
// Description: Arbiter for choosing from input queues
//
// Note: read and write are from the perspective of the driver.
//       Read means retrieve a packet from the CNET and place in memory.
//       Write means send a packet from memory to CNET.
//
// Change history: 12/10/07 - Split from dma_engine
//
// Issues to address:
//
///////////////////////////////////////////////////////////////////////////////

module dma_engine_rr_arb (
            // CPCI register interface signals
            input [3:0]    dma_wr_mac,    // Which MAC to write data to

            // CNET DMA interface signals
            input [15:0]   dma_pkt_avail, // Packets available in which buffers in CNET
            input          dma_rd_request, // Request packet from buffer

            // DMA engine signals
            output reg [3:0] dma_rd_request_q,
            output [15:0]  dma_wr_mac_one_hot,

            output reg     dma_rd_request_q_vld,

            input          ctrl_done,

            input          dma_in_progress,
            input          xfer_is_rd,

            // Miscelaneous signals
            input          cnet_reprog,   // Indicates that the CNET is
                                          // currently being reprogrammed

            input          reset,
            input          clk
         );


// ==================================================================
// Local
// ==================================================================

// Round robin lookup for reads
reg [3:0] pref_to_read;
reg [3:0] mac_search;
wire [15:0] mac_search_one_hot;

// ==================================================================
// Round robin allocator
// ==================================================================

always @(posedge clk)
begin
   // On either reset or the CNET being reprogrammed, reset to MAC0
   if (reset || cnet_reprog)
      pref_to_read <= 4'h0;
   // Rotate to the next MAC when this one is done
   else if (ctrl_done && xfer_is_rd)
      pref_to_read <= pref_to_read + 'h1;
   // Work out which MAC is being read
   else if (dma_rd_request)
      pref_to_read <= dma_rd_request_q;
end

always @(posedge clk)
begin
   // On either reset or the CNET being reprogrammed, reset to MAC0
   if (reset || cnet_reprog) begin
      dma_rd_request_q <= 4'hf;
      mac_search <= 4'hf;
      dma_rd_request_q_vld <= 1'b0;
   end
   else if (dma_rd_request && xfer_is_rd) begin
      dma_rd_request_q_vld <= 1'b0;
   end
   else if (ctrl_done && xfer_is_rd) begin
      dma_rd_request_q <= pref_to_read;
      mac_search <= pref_to_read;
      dma_rd_request_q_vld <= 1'b0;
   end
   // Work out which mac to request a packet from
   else begin
      // Keep searching until the mac we're requesting from is the one we'd
      // prefer to read next
      if (dma_rd_request_q != pref_to_read) begin
         // Search between the current best match and pref_to_read
         // Don't need to consider matches that aren't as good.
         if (mac_search == pref_to_read)
            mac_search <= dma_rd_request_q;
         else
            mac_search <= mac_search - 'h1;

         // If we find a match, then update the dma_rd_request_q signal to
         // reflect this
         if (mac_search_one_hot & dma_pkt_avail) begin
            dma_rd_request_q <= mac_search;
            dma_rd_request_q_vld <= 1'b1;
         end
      end
   end
end

// Work out which MAC to request the next packet from
assign dma_wr_mac_one_hot = {dma_wr_mac == 4'h f,
                             dma_wr_mac == 4'h e,
                             dma_wr_mac == 4'h d,
                             dma_wr_mac == 4'h c,
                             dma_wr_mac == 4'h b,
                             dma_wr_mac == 4'h a,
                             dma_wr_mac == 4'h 9,
                             dma_wr_mac == 4'h 8,
                             dma_wr_mac == 4'h 7,
                             dma_wr_mac == 4'h 6,
                             dma_wr_mac == 4'h 5,
                             dma_wr_mac == 4'h 4,
                             dma_wr_mac == 4'h 3,
                             dma_wr_mac == 4'h 2,
                             dma_wr_mac == 4'h 1,
                             dma_wr_mac == 4'h 0};

assign mac_search_one_hot = {mac_search == 4'h f,
                             mac_search == 4'h e,
                             mac_search == 4'h d,
                             mac_search == 4'h c,
                             mac_search == 4'h b,
                             mac_search == 4'h a,
                             mac_search == 4'h 9,
                             mac_search == 4'h 8,
                             mac_search == 4'h 7,
                             mac_search == 4'h 6,
                             mac_search == 4'h 5,
                             mac_search == 4'h 4,
                             mac_search == 4'h 3,
                             mac_search == 4'h 2,
                             mac_search == 4'h 1,
                             mac_search == 4'h 0};

endmodule // dma_engine_rr_arb

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
