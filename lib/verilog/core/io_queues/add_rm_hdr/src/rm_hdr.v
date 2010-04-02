///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: rm_hdr.v 2055 2007-07-30 22:44:59Z grg $
//
// Module: rm_hdr.v
// Project: NF2.1
// Description: Removes any headers that might be on the packets
//
///////////////////////////////////////////////////////////////////////////////

module rm_hdr
   #(
      parameter DATA_WIDTH = 64,
      parameter CTRL_WIDTH = DATA_WIDTH/8
   )
   (
      input  [DATA_WIDTH-1:0]             in_data,
      input  [CTRL_WIDTH-1:0]             in_ctrl,
      input                               in_wr,
      output                              in_rdy,

      output [DATA_WIDTH-1:0]             out_data,
      output [CTRL_WIDTH-1:0]             out_ctrl,
      output reg                          out_wr,
      input                               out_rdy,

      // --- Misc
      input                               reset,
      input                               clk
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


   // ------------- Regs/ wires -----------

   reg                              in_pkt;
   wire                             fifo_wr;
   wire                             almost_full;
   wire                             empty;


   // ------------ Modules -------------

   hdr_fifo rm_hdr_fifo
   (
      .din({in_ctrl, in_data}),
      .wr_en(fifo_wr),

      .dout({out_ctrl, out_data}),
      .rd_en(out_rdy && !empty),

      .empty(empty),
      .full(),
      .almost_full(almost_full),
      .rst(reset),
      .clk(clk)
   );


   // ------------- Logic ------------

   // Work out whether we're in a packet or not
   always @(posedge clk) begin
      if (reset)
         in_pkt <= 1'b0;
      else if (in_wr) begin
         if (in_pkt && |in_ctrl)
            in_pkt <= 1'b0;
         else if (!in_pkt && !(|in_ctrl))
            in_pkt <= 1'b1;
      end
   end

   assign fifo_wr = in_wr && (!(|in_ctrl) || in_pkt);

   always @(posedge clk)
      out_wr <= out_rdy && !empty;

   assign in_rdy = !almost_full;

endmodule // rm_hdr
