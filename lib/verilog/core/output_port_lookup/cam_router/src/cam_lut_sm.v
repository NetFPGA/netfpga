///////////////////////////////////////////////////////////////////////////////
// $Id: cam_lut_sm.v 3000 2007-11-21 09:09:56Z jnaous $
//
// Module: cam_lut_sm.v
// Project: NF2.1
// Description: controls a cam and provides a LUT. Matches data and provides reg access
//
///////////////////////////////////////////////////////////////////////////////

  module cam_lut_sm
    #(parameter CMP_WIDTH  = 32,
      parameter DATA_WIDTH = 3,
      parameter LUT_DEPTH  = 16,
      parameter LUT_DEPTH_BITS = log2(LUT_DEPTH),
      parameter DEFAULT_DATA = 0                       // DATA to return on a miss
      )
   (// --- Interface for lookups
    input                              lookup_req,
    input      [CMP_WIDTH-1:0]         lookup_cmp_data,
    input      [CMP_WIDTH-1:0]         lookup_cmp_dmask,
    output reg                         lookup_ack,
    output reg                         lookup_hit,
    output     [DATA_WIDTH-1:0]        lookup_data,

    // --- Interface to registers
    // --- Read port
    input [LUT_DEPTH_BITS-1:0]         rd_addr,          // address in table to read
    input                              rd_req,           // request a read
    output [DATA_WIDTH-1:0]            rd_data,          // data found for the entry
    output [CMP_WIDTH-1:0]             rd_cmp_data,      // matching data for the entry
    output [CMP_WIDTH-1:0]             rd_cmp_dmask,     // don't cares entry
    output reg                         rd_ack,           // pulses high

    // --- Write port
    input [LUT_DEPTH_BITS-1:0]         wr_addr,
    input                              wr_req,
    input [DATA_WIDTH-1:0]             wr_data,          // data found for the entry
    input [CMP_WIDTH-1:0]              wr_cmp_data,      // matching data for the entry
    input [CMP_WIDTH-1:0]              wr_cmp_dmask,     // don't cares for the entry
    output reg                         wr_ack,

    // --- CAM interface
    input                              cam_busy,
    input                              cam_match,
    input [LUT_DEPTH_BITS-1:0]         cam_match_addr,
    output     [CMP_WIDTH-1:0]         cam_cmp_din,
    output reg [CMP_WIDTH-1:0]         cam_din,
    output reg                         cam_we,
    output reg [LUT_DEPTH_BITS-1:0]    cam_wr_addr,
    output     [CMP_WIDTH-1:0]         cam_cmp_data_mask,
    output reg [CMP_WIDTH-1:0]         cam_data_mask,

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

   //-------------------- Internal Parameters ------------------------

   //---------------------- Wires and regs----------------------------
   reg [LUT_DEPTH_BITS-1:0]              lut_rd_addr;
   reg [DATA_WIDTH+2*CMP_WIDTH-1:0]      lut_rd_data;
   reg [DATA_WIDTH+2*CMP_WIDTH-1:0]      lut[LUT_DEPTH-1:0];

   reg                                   lookup_latched;
   reg                                   cam_match_found;
   reg                                   cam_lookup_done;
   reg                                   rd_req_latched;

   //------------------------- Logic --------------------------------

   assign cam_cmp_din       = lookup_cmp_data;
   assign cam_cmp_data_mask = lookup_cmp_dmask;

   assign lookup_data       = (lookup_hit & lookup_ack) ? lut_rd_data[DATA_WIDTH-1:0] : DEFAULT_DATA;

   assign rd_data           = lut_rd_data[DATA_WIDTH-1:0];
   assign rd_cmp_data       = lut_rd_data[DATA_WIDTH+CMP_WIDTH-1:DATA_WIDTH];
   assign rd_cmp_dmask      = lut_rd_data[DATA_WIDTH+2*CMP_WIDTH-1:DATA_WIDTH+CMP_WIDTH];

   always @(posedge clk) begin

      if(reset) begin
         lookup_latched     <= 0;
         cam_match_found    <= 0;
         cam_lookup_done    <= 0;
         rd_req_latched     <= 0;
         lookup_ack         <= 0;
         lookup_hit         <= 0;
         rd_ack             <= 0;
         cam_we             <= 0;
         cam_wr_addr        <= 0;
         cam_din            <= 0;
         cam_data_mask      <= 0;
         wr_ack             <= 0;
      end // if (reset)
      else begin
         /* first pipeline stage -- do CAM lookup */
         lookup_latched     <= lookup_req;

         /* second pipeline stage -- CAM result/LUT input*/
         cam_match_found    <= lookup_latched & cam_match;
         cam_lookup_done    <= lookup_latched;
         lut_rd_addr        <= (!lookup_latched && rd_req) ? rd_addr : cam_match_addr;
         rd_req_latched     <= (!lookup_latched && rd_req);

         /* third pipeline stage -- read LUT */
         lookup_ack         <= cam_lookup_done;
         lookup_hit         <= cam_match_found;
         lut_rd_data        <= lut[lut_rd_addr];
         rd_ack             <= rd_req_latched;

         /* Handle writes */
         if(wr_req & !cam_busy & !lookup_latched & !cam_match_found) begin
            cam_we           <= 1;
            cam_wr_addr      <= wr_addr;
            cam_din          <= wr_cmp_data ;
            cam_data_mask    <= wr_cmp_dmask;
            lut[wr_addr]     <= {wr_cmp_dmask, wr_cmp_data, wr_data};
            wr_ack           <= 1;
         end
         else begin
            cam_we    <= 0;
            wr_ack    <= 0;
         end
      end // else: !if(reset)

   end // always @ (posedge clk)

endmodule // cam_lut_sm




