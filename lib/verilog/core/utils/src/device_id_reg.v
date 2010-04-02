///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: device_id_reg.v 5935 2010-02-19 17:30:51Z grg $
//
// Module: device_id_reg.v
// Project: NetFPGA
// Description: Reprogramming RAM access registers
//
// Allows reading/writing to ram via registers
//
///////////////////////////////////////////////////////////////////////////////

module device_id_reg #(
      parameter DEVICE_ID = 0,
      parameter MAJOR = 0,
      parameter MINOR = 0,
      parameter REVISION = 0,
      parameter PROJ_DIR = "undefined",
      parameter PROJ_NAME = "undefined",
      parameter PROJ_DESC = "undefined"
   )
   (
      // Register interface signals
      input                                     reg_req,
      output reg                                reg_ack,
      input                                     reg_rd_wr_L,

      input [(`CORE_REG_ADDR_WIDTH - 2 - 4) - 1:0] reg_addr,

      output reg [`CPCI_NF2_DATA_WIDTH - 1:0]   reg_rd_data,
      input [`CPCI_NF2_DATA_WIDTH - 1:0]        reg_wr_data,

      //
      input             clk,
      input             reset
   );

localparam NUM_REGS           = `DEV_ID_NUM_REGS;
localparam NON_STR_REGS       = `DEV_ID_NON_STR_REGS;
localparam PROJ_DIR_WORD_LEN  = `DEV_ID_PROJ_DIR_WORD_LEN;
localparam PROJ_DIR_BYTE_LEN  = `DEV_ID_PROJ_DIR_BYTE_LEN;
localparam PROJ_NAME_WORD_LEN = `DEV_ID_PROJ_NAME_WORD_LEN;
localparam PROJ_NAME_BYTE_LEN = `DEV_ID_PROJ_NAME_BYTE_LEN;
localparam PROJ_DESC_WORD_LEN = `DEV_ID_PROJ_DESC_WORD_LEN;
localparam PROJ_DESC_BYTE_LEN = `DEV_ID_PROJ_DESC_BYTE_LEN;
localparam WORD_WIDTH         = `CPCI_NF2_DATA_WIDTH / 8;
localparam MAX_STR_LEN        = max(max(PROJ_DIR_BYTE_LEN, PROJ_NAME_BYTE_LEN), PROJ_DESC_BYTE_LEN);

// Extract a substring of a string
//
// Note: This assumes that CPCI_NF2_DATA_WIDTH is 32 bits
// Attempted to make this generic but it generated an XST error to
// do with array accesses (worked fine in ModelSim).
function [`CPCI_NF2_DATA_WIDTH - 1:0] substr;
   input reg [MAX_STR_LEN  *  8 - 1:0] str;
   input integer word;
   input integer maxlen;
   reg [7:0] result_1;
   reg [7:0] result_2;
   reg [7:0] result_3;
   reg [7:0] result_4;
   integer length;
   integer pos;
   integer i;
   begin
      // Calculate the length
      length = 0;
      //pos = MAX_STR_LEN * 8 - 1;
      pos = 0;
      while (pos <= MAX_STR_LEN * 8 - 1 && str[pos +: 8] != 8'h0) begin
         length = length + 1;
         pos = pos + 8;
      end

      // Jump to the location that we are trying to copy data from
      pos = (length - word * WORD_WIDTH) * 8 - 1;

      // Copy the data
      result_1 = (pos < 0) ? 8'b0 : str[pos -: 8];
      pos = pos - 8;

      result_2 = (pos < 0) ? 8'b0 : str[pos -: 8];
      pos = pos - 8;

      result_3 = (pos < 0) ? 8'b0 : str[pos -: 8];
      pos = pos - 8;

      result_4 = (pos < 0) ? 8'b0 : str[pos -: 8];

      if (word == maxlen - 1)
         result_4 = 0;

      substr = {result_1, result_2, result_3, result_4};
   end
endfunction // substr

// Maximum of two numbers
//
// Return the maximum of two numbers.
function integer max;
   input integer a;
   input integer b;
   begin
      if (a > b)
         max = a;
      else
         max = b;
   end
endfunction // max

reg req_acked;

wire [`CPCI_NF2_DATA_WIDTH-1:0] device_id[0:NUM_REGS - 1];

genvar i;

assign device_id[`DEV_ID_MD5_0]      = `DEV_ID_MD5_VALUE_V2_0;
assign device_id[`DEV_ID_MD5_1]      = `DEV_ID_MD5_VALUE_V2_1;
assign device_id[`DEV_ID_MD5_2]      = `DEV_ID_MD5_VALUE_V2_2;
assign device_id[`DEV_ID_MD5_3]      = `DEV_ID_MD5_VALUE_V2_3;
assign device_id[`DEV_ID_DEVICE_ID]  = DEVICE_ID;
assign device_id[`DEV_ID_VERSION]    = {8'b0, MAJOR[7:0], MINOR[7:0], REVISION[7:0]};
assign device_id[`DEV_ID_CPCI_ID]    = {`CPCI_REVISION_ID, `CPCI_VERSION_ID};
generate
   for (i = 0 ; i < PROJ_DIR_WORD_LEN; i = i + 1) begin: proj_dir_gen
      assign device_id[i + NON_STR_REGS] = substr(PROJ_DIR, i, PROJ_DIR_WORD_LEN);
   end
   for (i = 0 ; i < PROJ_NAME_WORD_LEN; i = i + 1) begin: proj_name_gen
      assign device_id[i + NON_STR_REGS + PROJ_DIR_WORD_LEN] = substr(PROJ_NAME, i, PROJ_NAME_WORD_LEN);
   end
   for (i = 0 ; i < PROJ_DESC_WORD_LEN; i = i + 1) begin: proj_desc_gen
      assign device_id[i + NON_STR_REGS + PROJ_DIR_WORD_LEN + PROJ_NAME_WORD_LEN] = substr(PROJ_DESC, i, PROJ_DESC_WORD_LEN);
   end
endgenerate


// ==============================================
// Main state machine

always @(posedge clk)
begin
   if (reset) begin
      reg_ack        <= 1'b0;
      reg_rd_data    <= 'h 0;

      req_acked      <= 1'b0;
   end
   else begin
      if (reg_req) begin
         // Only process the request if it's new
         if (!req_acked) begin
            reg_ack      <= 1'b1;
            req_acked    <= 1'b1;

            // Verify that the address actually corresponds to the RAM
            if (reg_addr < NUM_REGS) begin
               reg_rd_data <= device_id[reg_addr];
            end
            else begin
               reg_rd_data <= 'h dead_beef;
            end
         end
         else begin
            reg_ack <= 1'b0;
         end
      end // if (reg_req)
      else begin
         reg_ack      <= 1'b0;
         req_acked    <= 1'b0;
      end // if (reg_req) else
   end
end

endmodule // device_id_reg
