///////////////////////////////////////////////////////////////////////////////
// $Id: unencoded_cam_lut_sm.v 3553 2008-04-04 22:05:21Z jnaous $
//
// Module: unencoded_cam_lut_sm.v
// Project: NF2.1
// Author: Jad Naous <jnaous@stanford.edu>
// Description: controls an unencoded muli-match cam and provides a LUT.
//  Matches data and provides reg access
//
//  The sizes of the compare input and the data to store in the LUT can be
//  specified either by number of words or by exact size. The benefit of the
//  first is that you don't have to calculate the exact number of words used
//  in the parent module, but then the granularity of your matches will be
//  in increments of `CPCI_NF2_DATA_WIDTH bits, which might or might not matter
///////////////////////////////////////////////////////////////////////////////

  module unencoded_cam_lut_sm
    #(parameter CMP_NUM_WORDS  = 1,
      parameter DATA_NUM_WORDS = 1,
      parameter DATA_WIDTH = DATA_NUM_WORDS*`CPCI_NF2_DATA_WIDTH,
      parameter CMP_WIDTH = CMP_NUM_WORDS*`CPCI_NF2_DATA_WIDTH,
      parameter LUT_DEPTH  = 16,
      parameter FLIP_BYTE_ORDER = 1,                    // flip the bytes ordering of the lookup/data
      parameter LUT_DEPTH_BITS = log2(LUT_DEPTH),
      parameter DEFAULT_DATA = 0,                       // DATA to return on a miss
      parameter RESET_DATA = {DATA_WIDTH{1'b0}},        // value of data on reset
      parameter RESET_CMP_DATA = {CMP_WIDTH{1'b0}},     // value of compare data on reset
      parameter RESET_CMP_DMASK = {CMP_WIDTH{1'b0}},    // value compare of data mask on reset
      parameter UDP_REG_SRC_WIDTH = 2,                  // identifies which module started this request
      parameter TAG = 0,                                // Tag identifying the address block
      parameter REG_ADDR_WIDTH = 5                      // Width of addresses in the same block
      )
   (// --- Interface for lookups
    input                              lookup_req,
    input      [CMP_WIDTH-1:0]         lookup_cmp_data,
    input      [CMP_WIDTH-1:0]         lookup_cmp_dmask,
    output reg                         lookup_ack,
    output reg                         lookup_hit,
    output     [DATA_WIDTH-1:0]        lookup_data,
    output reg [LUT_DEPTH_BITS-1:0]    lookup_address,

    // --- Interface to registers
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

    // --- CAM interface
    input                              cam_busy,
    input                              cam_match,
    input      [LUT_DEPTH-1:0]         cam_match_addr,
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


   `LOG2_FUNC
   `CEILDIV_FUNC

   //-------------------- Internal Parameters ------------------------
   localparam NUM_DATA_WORDS_USED = ceildiv(DATA_WIDTH,`CPCI_NF2_DATA_WIDTH);
   localparam NUM_CMP_WORDS_USED  = ceildiv(CMP_WIDTH, `CPCI_NF2_DATA_WIDTH);
   localparam NUM_REGS_USED = (2 // for the read and write address registers
                               + NUM_DATA_WORDS_USED // for data associated with an entry
                               + NUM_CMP_WORDS_USED  // for the data to match on
                               + NUM_CMP_WORDS_USED);  // for the don't cares

   localparam READ_ADDR  = NUM_REGS_USED-2;
   localparam WRITE_ADDR = READ_ADDR+1;

   localparam RESET = 0;
   localparam READY = 1;

   localparam WAIT_FOR_REQUEST = 1;
   localparam WAIT_FOR_READ_ACK = 2;
   localparam WAIT_FOR_WRITE_ACK = 4;

   //---------------------- Wires and regs----------------------------
   wire [CMP_WIDTH-1:0]                  lookup_cmp_data_int;
   wire [CMP_WIDTH-1:0]                  lookup_cmp_dmask_int;
   wire [DATA_WIDTH-1:0]                 lookup_data_int;

   reg [LUT_DEPTH_BITS-1:0]              lut_rd_addr;
   reg [DATA_WIDTH+2*CMP_WIDTH-1:0]      lut_rd_data;
   reg [DATA_WIDTH-1:0]                  lut_wr_data;

   reg [DATA_WIDTH+2*CMP_WIDTH-1:0]      lut[LUT_DEPTH-1:0];

   reg                                   lookup_latched;
   reg                                   cam_match_found;
   reg                                   cam_lookup_done;
   reg                                   rd_req_latched;

   reg                                   cam_match_encoded;
   reg                                   cam_match_found_d1;
   reg [LUT_DEPTH-1:0]                   cam_match_unencoded_addr;

   reg [LUT_DEPTH_BITS-1:0]              cam_match_encoded_addr;
   // synthesis attribute PRIORITY_EXTRACT of cam_match_encoded_addr is force;

   /* used to track the addresses for resetting the CAM and the LUT */
   reg [LUT_DEPTH_BITS:0]                reset_count;
   reg                                   state;

   wire [REG_ADDR_WIDTH-1:0]             addr;
   wire [`UDP_REG_ADDR_WIDTH-REG_ADDR_WIDTH-1:0] tag_addr;

   wire                                  addr_good;
   wire                                  tag_hit;

   reg [`CPCI_NF2_DATA_WIDTH-1:0]        reg_file[0:NUM_REGS_USED-1];

   reg [2:0]                             reg_state;

   integer                               i;

   reg [LUT_DEPTH_BITS-1:0]              rd_addr;          // address in table to read
   reg                                   rd_req;           // request a read
   wire [DATA_WIDTH-1:0]                 rd_data;          // data found for the entry
   wire [CMP_WIDTH-1:0]                  rd_cmp_data;      // matching data for the entry
   wire [CMP_WIDTH-1:0]                  rd_cmp_dmask;     // don't cares entry
   reg                                   rd_ack;           // pulses high

   reg [LUT_DEPTH_BITS-1:0]              wr_addr;
   reg                                   wr_req;
   wire [DATA_WIDTH-1:0]                 wr_data;          // data found for the entry
   wire [CMP_WIDTH-1:0]                  wr_cmp_data;      // matching data for the entry
   wire [CMP_WIDTH-1:0]                  wr_cmp_dmask;     // don't cares for the entry
   reg                                   wr_ack;

   //------------------------- Logic --------------------------------

   /* swap the bytes of the incoming lookups and outgoing
    * lookup results. This is to take care of the pesky
    * endianness issue when using structs.
    */
   generate
      genvar g;
      if(FLIP_BYTE_ORDER) begin
         for(g=0; g<CMP_WIDTH/8; g=g+1) begin:flip_cmp_data
            assign lookup_cmp_data_int[8*g+7:8*g]    = lookup_cmp_data[CMP_WIDTH-1-g*8:CMP_WIDTH-8-g*8];
            assign lookup_cmp_dmask_int[8*g+7:8*g]   = lookup_cmp_dmask[CMP_WIDTH-1-g*8:CMP_WIDTH-8-g*8];
         end
         for(g=0; g<DATA_WIDTH/8; g=g+1) begin:flip_data
            assign lookup_data[8*g+7:8*g]   = lookup_data_int[DATA_WIDTH-1-g*8:DATA_WIDTH-8-g*8];
         end
      end // if (FLIP_BYTE_ORDER)
      else begin
         assign lookup_cmp_data_int    = lookup_cmp_data;
         assign lookup_cmp_dmask_int   = lookup_cmp_dmask;
         assign lookup_data            = lookup_data_int;
      end // else: !if(FLIP_BYTE_ORDER)
   endgenerate

   assign cam_cmp_din         = lookup_cmp_data_int;
   assign cam_cmp_data_mask   = lookup_cmp_dmask_int;

   assign lookup_data_int     = (lookup_hit & lookup_ack) ? lut_rd_data[DATA_WIDTH-1:0] : DEFAULT_DATA;

   assign rd_data             = lut_rd_data[DATA_WIDTH-1:0];
   assign rd_cmp_data         = lut_rd_data[DATA_WIDTH+CMP_WIDTH-1:DATA_WIDTH];
   assign rd_cmp_dmask        = lut_rd_data[DATA_WIDTH+2*CMP_WIDTH-1:DATA_WIDTH+CMP_WIDTH];

   assign addr                = reg_addr_in;            // addresses in this module
   assign tag_addr            = reg_addr_in[`UDP_REG_ADDR_WIDTH - 1:REG_ADDR_WIDTH];

   assign addr_good           = addr < NUM_REGS_USED;   // address is used in this module
   assign tag_hit             = tag_addr == TAG;        // address is in this block

   generate
      genvar ii;
      for (ii=0; ii<NUM_DATA_WORDS_USED-1; ii=ii+1) begin:gen_wrdata
         assign wr_data[ii*`CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH] = reg_file[ii];
      end
      assign wr_data[DATA_WIDTH-1:(NUM_DATA_WORDS_USED-1)*`CPCI_NF2_DATA_WIDTH] = reg_file[NUM_DATA_WORDS_USED-1];

      for (ii=0; ii<NUM_CMP_WORDS_USED-1; ii=ii+1) begin:gen_wrcmpdmask
         assign wr_cmp_dmask[ii*`CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH] = reg_file[ii+NUM_DATA_WORDS_USED];
      end
      assign wr_cmp_dmask[CMP_WIDTH-1:(NUM_CMP_WORDS_USED-1)*`CPCI_NF2_DATA_WIDTH]
             = reg_file[NUM_CMP_WORDS_USED+NUM_DATA_WORDS_USED-1];

      for (ii=0; ii<NUM_CMP_WORDS_USED-1; ii=ii+1) begin:gen_wrcmpdata
         assign wr_cmp_data[ii*`CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH]
                = reg_file[ii+NUM_CMP_WORDS_USED+NUM_DATA_WORDS_USED];
      end
      assign wr_cmp_data[CMP_WIDTH-1:(NUM_CMP_WORDS_USED-1)*`CPCI_NF2_DATA_WIDTH]
             = reg_file[2*NUM_CMP_WORDS_USED+NUM_DATA_WORDS_USED-1];
   endgenerate

   /* Handle registers */
   always @(posedge clk) begin
      if(reset) begin
         reg_req_out        <= 0;
         reg_ack_out        <= 0;
         reg_rd_wr_L_out    <= 0;
         reg_addr_out       <= 0;
         reg_src_out        <= 0;
         reg_data_out       <= 0;

         rd_req             <= 0;
         wr_req             <= 0;
         reg_state          <= WAIT_FOR_REQUEST;

         wr_addr            <= 0;
         rd_addr            <= 0;

         for (i=0; i<NUM_REGS_USED; i=i+1) begin
            reg_file[i] <= 0;
         end
      end
      else begin
         reg_req_out     <= 1'b0;
         reg_ack_out     <= 1'b0;
         rd_req          <= 0;
         wr_req          <= 0;
         case (reg_state)
            WAIT_FOR_REQUEST: begin
               /* check if we should respond to this address */
               if(addr_good && tag_hit && reg_req_in) begin

                  /* check if this is a write to the read addr register
                   * or the write addr register. */
                  if (!reg_rd_wr_L_in && addr == READ_ADDR) begin
                     /* we need to pull data from the cam/lut */
                     rd_addr                 <= reg_data_in;
                     rd_req                  <= 1;
                     reg_state               <= WAIT_FOR_READ_ACK;
                     reg_file[READ_ADDR]     <= reg_data_in;

                     reg_req_out             <= 1'b0;
                     reg_ack_out             <= 1'b0;
                     reg_rd_wr_L_out         <= reg_rd_wr_L_in;
                     reg_addr_out            <= reg_addr_in;
                     reg_src_out             <= reg_src_in;
                     reg_data_out            <= reg_data_in;
                  end // if (!reg_rd_wr_L_in && addr == READ_ADDR)

                  else if (!reg_rd_wr_L_in && addr == WRITE_ADDR) begin
                     /* we need to write data to the cam/lut */
                     wr_addr            <= reg_data_in;
                     wr_req             <= 1;
                     reg_state          <= WAIT_FOR_WRITE_ACK;

                     reg_req_out        <= 1'b0;
                     reg_ack_out        <= 1'b0;
                     reg_rd_wr_L_out    <= reg_rd_wr_L_in;
                     reg_addr_out       <= reg_addr_in;
                     reg_src_out        <= reg_src_in;
                     reg_data_out       <= reg_data_in;
                  end // if (!reg_rd_wr_L_in && addr == WRITE_ADDR)

                  else begin
                     /* not a write to a special address */
                     reg_req_out        <= reg_req_in;
                     reg_ack_out        <= 1'b1;
                     reg_rd_wr_L_out    <= reg_rd_wr_L_in;
                     reg_addr_out       <= reg_addr_in;
                     reg_src_out        <= reg_src_in;
                     /* if read */
                     if(reg_rd_wr_L_in) begin
                        reg_data_out       <= reg_file[addr];
                     end
                     /* if write */
                     else begin
                        reg_data_out       <= reg_data_in;
                        reg_file[addr]     <= reg_data_in;
                     end
                  end // else: !if(!reg_rd_wr_L_in && addr == WRITE_ADDR)

               end // if (addr_good && tag_hit && reg_req_in)

               /* otherwise just forward anything that comes over */
               else begin
                  reg_req_out        <= reg_req_in;
                  reg_ack_out        <= reg_ack_in;
                  reg_rd_wr_L_out    <= reg_rd_wr_L_in;
                  reg_addr_out       <= reg_addr_in;
                  reg_src_out        <= reg_src_in;
                  reg_data_out       <= reg_data_in;
               end // else: !if(addr_good && tag_hit && reg_req_in)

            end // case: WAIT_FOR_REQUEST

            WAIT_FOR_READ_ACK: begin
               if(rd_ack) begin
                  reg_req_out    <= 1'b1;
                  reg_ack_out    <= 1'b1;
                  reg_state      <= WAIT_FOR_REQUEST;

                  /* put the info in the registers */
                  for (i=0; i<NUM_DATA_WORDS_USED-1; i=i+1) begin
                     reg_file[i] <= rd_data[i*`CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH];
                  end
                  reg_file[NUM_DATA_WORDS_USED-1] <= {{(DATA_WIDTH % `CPCI_NF2_DATA_WIDTH){1'b0}},
                                                      rd_data[DATA_WIDTH-1:(NUM_DATA_WORDS_USED-1)*`CPCI_NF2_DATA_WIDTH]};

                  for (i=0; i<NUM_CMP_WORDS_USED-1; i=i+1) begin
                     reg_file[i+NUM_DATA_WORDS_USED] <= rd_cmp_dmask[i*`CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH];
                  end
                  reg_file[NUM_CMP_WORDS_USED+NUM_DATA_WORDS_USED-1]
                    <= {{(CMP_WIDTH % `CPCI_NF2_DATA_WIDTH){1'b0}},
                        rd_cmp_dmask[CMP_WIDTH-1:(NUM_CMP_WORDS_USED-1)*`CPCI_NF2_DATA_WIDTH]};

                  for (i=0; i<NUM_CMP_WORDS_USED-1; i=i+1) begin
                     reg_file[i+NUM_CMP_WORDS_USED+NUM_DATA_WORDS_USED]
                       <= rd_cmp_data[i*`CPCI_NF2_DATA_WIDTH +: `CPCI_NF2_DATA_WIDTH];
                  end
                  reg_file[2*NUM_CMP_WORDS_USED+NUM_DATA_WORDS_USED-1]
                    <= {{(CMP_WIDTH % `CPCI_NF2_DATA_WIDTH){1'b0}},
                        rd_cmp_data[CMP_WIDTH-1:(NUM_CMP_WORDS_USED-1)*`CPCI_NF2_DATA_WIDTH]};
               end // if (rd_ack)
               else begin
                  rd_req <= 1;
               end // else: !if(rd_ack)
            end

            WAIT_FOR_WRITE_ACK: begin
               if(wr_ack) begin
                  reg_req_out    <= 1'b1;
                  reg_ack_out    <= 1'b1;
                  reg_state      <= WAIT_FOR_REQUEST;
               end
               else begin
                  wr_req <= 1;
               end
            end
         endcase // case(reg_state)
      end // else: !if(reset)
   end // always @ (posedge clk)

   /* encode the match address */
   always @(*) begin
      cam_match_encoded_addr = LUT_DEPTH[LUT_DEPTH_BITS-1:0] - 1'b1;
      for (i = LUT_DEPTH-2; i >= 0; i = i-1) begin
         if (cam_match_unencoded_addr[i]) begin
            cam_match_encoded_addr = i[LUT_DEPTH_BITS-1:0];
         end
      end
   end

   always @(posedge clk) begin

      if(reset) begin
         lookup_latched              <= 0;
         cam_match_found             <= 0;
         cam_lookup_done             <= 0;
         rd_req_latched              <= 0;
         lookup_ack                  <= 0;
         lookup_hit                  <= 0;
         cam_we                      <= 0;
         cam_wr_addr                 <= 0;
         cam_din                     <= 0;
         cam_data_mask               <= 0;
         wr_ack                      <= 0;
         rd_ack                      <= 0;
         state                       <= RESET;
         lookup_address              <= 0;
         reset_count                 <= 0;
         cam_match_unencoded_addr    <= 0;
         cam_match_encoded           <= 0;
         cam_match_found_d1          <= 0;
      end // if (reset)
      else begin

         // defaults
         lookup_latched     <= 0;
         cam_match_found    <= 0;
         cam_lookup_done    <= 0;
         rd_req_latched     <= 0;
         lookup_ack         <= 0;
         lookup_hit         <= 0;
         cam_we             <= 0;
         cam_din            <= 0;
         cam_data_mask      <= 0;
         wr_ack             <= 0;
         rd_ack             <= 0;

         if (state == RESET && !cam_busy) begin
            if(reset_count == LUT_DEPTH) begin
               state  <= READY;
               cam_we <= 1'b0;
            end
            else begin
               reset_count      <= reset_count + 1'b1;
               cam_we           <= 1'b1;
               cam_wr_addr      <= reset_count[LUT_DEPTH_BITS-1:0];
               cam_din          <= RESET_CMP_DATA;
               cam_data_mask    <= RESET_CMP_DMASK;
               lut_wr_data      <= RESET_DATA;
            end
         end

         else if (state == READY) begin
            /* first pipeline stage -- do CAM lookup */
            lookup_latched              <= lookup_req;

            /* second pipeline stage -- CAM result/LUT input*/
            cam_match_found             <= lookup_latched & cam_match;
            cam_lookup_done             <= lookup_latched;
            cam_match_unencoded_addr    <= cam_match_addr;

            /* third pipeline stage -- encode the CAM output */
            cam_match_encoded           <= cam_lookup_done;
            cam_match_found_d1          <= cam_match_found;
            lut_rd_addr                 <= (!cam_match_found && rd_req) ? rd_addr : cam_match_encoded_addr;
            rd_req_latched              <= (!cam_match_found && rd_req);

            /* fourth pipeline stage -- read LUT */
            lookup_ack                  <= cam_match_encoded;
            lookup_hit                  <= cam_match_found_d1;
            lut_rd_data                 <= lut[lut_rd_addr];
            lookup_address              <= lut_rd_addr;
            rd_ack                      <= rd_req_latched;

            /* Handle writes */
            if(wr_req & !cam_busy & !lookup_latched & !cam_match_found & !cam_match_found_d1) begin
               cam_we           <= 1;
               cam_wr_addr      <= wr_addr;
               cam_din          <= wr_cmp_data ;
               cam_data_mask    <= wr_cmp_dmask;
               wr_ack           <= 1;
               lut_wr_data      <= wr_data;
            end
            else begin
               cam_we <= 0;
               wr_ack <= 0;
            end // else: !if(wr_req & !cam_busy & !lookup_latched & !cam_match_found & !cam_match_found_d1)
         end // else: !if(state == RESET)

      end // else: !if(reset)

      // separate this out to allow implementation as BRAM
      if(cam_we) begin
         lut[cam_wr_addr] <= {cam_data_mask, cam_din, lut_wr_data};
      end

   end // always @ (posedge clk)

endmodule // cam_lut_sm

