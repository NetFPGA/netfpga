///////////////////////////////////////////////////////////////////////////////
// $Id: sram_arbiter.v 4253 2008-07-09 17:52:05Z jnaous $
//
// Module: sram_arbiter.v
// Project: Generic Lookups
// Description: SRAM controller
// Author: Jad Naous <jnaous@stanford.edu>
//
///////////////////////////////////////////////////////////////////////////////

`timescale  1ns /  10ps

module sram_arbiter  #(parameter SRAM_ADDR_WIDTH = 19,
		       parameter DATA_WIDTH = 64,
                       parameter SRAM_DATA_WIDTH = 72)

   (// register interface
    input                            sram_reg_req,
    input                            sram_reg_rd_wr_L,    // 1 = read, 0 = write
    input [`SRAM_REG_ADDR_WIDTH-1:0] sram_reg_addr,
    input [`CPCI_NF2_DATA_WIDTH-1:0] sram_reg_wr_data,

    output reg                             sram_reg_ack,
    output reg [`CPCI_NF2_DATA_WIDTH -1:0] sram_reg_rd_data,

    // --- Requesters (read and/or write)
    input                            wr_0_req,
    input      [SRAM_ADDR_WIDTH-1:0] wr_0_addr,
    input      [SRAM_DATA_WIDTH-1:0] wr_0_data,
    output reg                       wr_0_ack,

    input                            rd_0_req,
    input      [SRAM_ADDR_WIDTH-1:0] rd_0_addr,
    output reg [SRAM_DATA_WIDTH-1:0] rd_0_data,
    output reg                       rd_0_ack,
    output reg                       rd_0_vld,

    // --- SRAM signals (pins and control)
    output reg [SRAM_ADDR_WIDTH-1:0]   sram_addr,
    output reg                         sram_we,
    output reg [SRAM_DATA_WIDTH/9-1:0] sram_bw,
    output reg [SRAM_DATA_WIDTH-1:0]   sram_wr_data,
    input      [SRAM_DATA_WIDTH-1:0]   sram_rd_data,
    output reg                         sram_tri_en,

    // --- Misc

    input reset,
    input clk

    );

   `CEILDIV_FUNC
   `LOG2_FUNC

   //-------------------- Internal Parameters ------------------------
   localparam NUM_RULE_WORDS       = ceildiv(`SRAM_ENTRY_NUM_RULE_BYTES*8, DATA_WIDTH);
   localparam NUM_DATA_WORDS       = ceildiv(`SRAM_ENTRY_NUM_DATA_BYTES*8, DATA_WIDTH);

   // calculate number of memory locations an entry uses + 1 word for counters
   localparam ENTRY_IDX_WIDTH  = log2(NUM_RULE_WORDS+NUM_DATA_WORDS+1);

   // reset the counters after reading them
   localparam RESET_ON_READ    = 0;

   //------------------ Registers/Wires -----------------
   reg                       rd_0_vld_early2, rd_0_vld_early1, rd_0_vld_early3;
   reg [SRAM_DATA_WIDTH-1:0] sram_wr_data_early2, sram_wr_data_early1;
   reg                       sram_tri_en_early2, sram_tri_en_early1;
   reg                       sram_reg_ack_early3, sram_reg_ack_early2, sram_reg_ack_early1;

   reg                       sram_reg_addr_is_high, sram_reg_addr_is_high_d1, sram_reg_addr_is_high_d2;
   reg                       sram_reg_cntr_read;

   wire [SRAM_DATA_WIDTH-1:0] sram_wr_data_early1_shuffled;
   wire [SRAM_DATA_WIDTH-1:0] sram_rd_data_shuffled;

   reg                        do_reset;

   reg                        sram_reg_req_d1;

   //----------------------- Logic ----------------------
   /* The SRAM considers each byte to be 9bits. So
    * in order to use the sram_bw signals correctly
    * we need to shuffled bits around to match our internal
    * view in the User Data Path that the extra bits
    * are all collected at the MSB of the sram data lines */
   generate
      genvar i;
      for (i=0; i<8; i=i+1) begin:gen_sram_data
         assign sram_wr_data_early1_shuffled[i*9 + 8 : i*9] = {sram_wr_data_early1[64 + i], sram_wr_data_early1[i*8 + 7 : i*8]};
         assign {sram_rd_data_shuffled[64 + i], sram_rd_data_shuffled[i*8 + 7 : i*8]} = sram_rd_data[i*9 + 8 : i*9];
      end
   endgenerate

   always @(posedge clk) begin
      if(reset) begin
         {sram_we, sram_bw}    <= 9'h1ff;           // active low
         sram_addr             <= 0;
         sram_reg_req_d1       <= 0;
         do_reset              <= 1'b1;
         // synthesis translate_off
         do_reset              <= 0;
         // synthesis translate_on
      end

      else begin
         sram_reg_req_d1 <= sram_reg_req;

         /* first pipeline stage -- initiate request */
         sram_reg_addr_is_high    <= sram_reg_addr[0];
         // first word after the rule has the counters
         sram_reg_cntr_read       <= ((sram_reg_addr[ENTRY_IDX_WIDTH:1] == NUM_RULE_WORDS[ENTRY_IDX_WIDTH-1:0])
                                      && sram_reg_rd_wr_L
                                      && sram_reg_req);

         // Clear the SRAM. This is not executed in simulation
         if(do_reset) begin
            if(sram_addr == {SRAM_ADDR_WIDTH{1'b1}}) begin
               do_reset               <= 0;
               rd_0_vld_early3        <= 1'b0;
               {sram_we, sram_bw}     <= 9'h1ff;           // active low
               sram_tri_en_early2     <= 1'b0;
               sram_wr_data_early2    <= sram_wr_data_early2;
               sram_reg_ack_early3    <= 1'b0;
               rd_0_ack               <= 1'b0;
               wr_0_ack               <= 1'b0;
            end
            else begin
               sram_addr              <= sram_addr + 1'b1;
               {sram_we, sram_bw}     <= 0;
               sram_wr_data_early2    <= 0;
               sram_tri_en_early2     <= 1;
            end // else: !if(sram_addr == {SRAM_ADDR_WIDTH{1'b1}})
         end // if (do_reset)

         else begin
            // register access
            if(sram_reg_req && !sram_reg_req_d1) begin
               // since the SRAM is doing 64-bit words at a time while the registers are
               // doing 32-bit words at a time, we use the last bit of the register
               // address to decide whether we are accessing the high 32-bit SRAM word
               // or the low.
               sram_addr              <= sram_reg_addr[SRAM_ADDR_WIDTH:1];
               if (!sram_reg_rd_wr_L) begin
                  sram_we    <= 0; // active low
                  sram_bw    <= sram_reg_addr[0] ? 8'h0f : 8'hf0; // active low
               end
               else begin
                  sram_we    <= 1;
                  sram_bw    <= 8'hff;
               end
               sram_wr_data_early2    <= sram_reg_addr[0] ? {8'h0, sram_reg_wr_data, 32'h0} : {40'h0, sram_reg_wr_data};
               sram_tri_en_early2     <= !sram_reg_rd_wr_L;
               sram_reg_ack_early3    <= 1'b1;
               rd_0_vld_early3        <= 1'b0;
               rd_0_ack               <= 1'b0;
               wr_0_ack               <= 1'b0;
            end

            // reset counters if counter read and reset-on-read enabled
            else if(sram_reg_cntr_read && RESET_ON_READ) begin
               sram_addr              <= sram_addr;           // keep the same reg addr
               sram_we                <= 0; // active low
               sram_bw                <= sram_reg_addr_is_high ? 8'h0f : 8'hf8; // don't reset the timestamp
               sram_wr_data_early2    <= 0;
               sram_tri_en_early2     <= sram_reg_cntr_read;
               rd_0_vld_early3        <= 1'b0;
               sram_reg_ack_early3    <= 1'b0;
               rd_0_ack               <= 1'b0;
               wr_0_ack               <= 1'b0;
            end

            // writes
            else if(wr_0_req) begin
               sram_addr              <= wr_0_addr;
               {sram_we, sram_bw}     <= 0; // active low
               sram_wr_data_early2    <= wr_0_data;
               sram_tri_en_early2     <= 1'b1;
               wr_0_ack               <= 1'b1;
               rd_0_vld_early3        <= 1'b0;
               sram_reg_ack_early3    <= 1'b0;
               rd_0_ack               <= 1'b0;
            end

            // reads
            else begin
               sram_addr              <= rd_0_addr;
               rd_0_vld_early3        <= rd_0_req;
               {sram_we, sram_bw}     <= 9'h1ff;           // active low
               sram_tri_en_early2     <= 1'b0;
               sram_wr_data_early2    <= sram_wr_data_early2;
               sram_reg_ack_early3    <= 1'b0;
               rd_0_ack               <= rd_0_req;
               wr_0_ack               <= 1'b0;
            end
         end // else: !if(do_reset)

         /* second pipeline stage -- do nothing */
         rd_0_vld_early2             <= rd_0_vld_early3;
         sram_wr_data_early1         <= sram_wr_data_early2;
         sram_tri_en_early1          <= sram_tri_en_early2;
         sram_reg_ack_early2         <= sram_reg_ack_early3;
         sram_reg_addr_is_high_d1    <= sram_reg_addr_is_high;

         /* third pipeline stage -- place write data */
         sram_wr_data   <=
                          // synthesis translate_off
                          #2
                          // synthesis translate_on
                          sram_wr_data_early1_shuffled;

         sram_tri_en    <=
                          // synthesis translate_off
                          #2
                          // synthesis translate_on
                          sram_tri_en_early1;
         sram_reg_ack_early1         <= sram_reg_ack_early2;
         rd_0_vld_early1             <= rd_0_vld_early2;
         sram_reg_addr_is_high_d2    <= sram_reg_addr_is_high_d1;

         /* fourth pipeline stage -- signal rd valid and latch read data */
         rd_0_data                   <= sram_rd_data_shuffled;
         sram_reg_rd_data            <= sram_reg_addr_is_high_d2 ? sram_rd_data_shuffled[63:32] : sram_rd_data_shuffled[31:0];
         sram_reg_ack                <= sram_reg_ack_early1;
         rd_0_vld                    <= rd_0_vld_early1;

      end // else: !if(reset)
   end // always @ (posedge clk)

/************************** Debugging *************************/
   // synthesis translate_off

   // Synthesis code to set the we flag to 0 on startup to remove the annoying
   // "Cypress SRAM stores 'h xxxxxxxxx at addr 'h xxxxx" messages at the
   // beginning of the log file until the clock starts running.
   initial
   begin
      {sram_we, sram_bw} = 9'h1ff;
   end

   // Detect when we write sequential addresses using reg iface, and we skip one
   reg [2:0] seq_state;
   reg [SRAM_ADDR_WIDTH-1:0] prev_addr;
   always @(posedge clk) begin
      if(reset) begin
         seq_state <= 0;
      end
      else begin
         case (seq_state)
            // check when we start a new write
            0: begin
               if(sram_reg_req && !sram_reg_rd_wr_L) begin
                  prev_addr <= sram_reg_addr;
                  seq_state <= 1;
               end
            end

            // wait till req goes low
            1: begin
               if(!sram_reg_req) begin
                  seq_state <= 2;
               end
            end

            // wait for new addr, check if sequential
            2: begin
               if(sram_reg_req && !sram_reg_rd_wr_L) begin
                  // if it is not sequential then we check if we have moved to the next
                  // sequence or if this is a mistake
                  if(sram_reg_addr == prev_addr + 2) begin
                     // Oh oh, we've skipped an address
                     $display("%t %m WARNING: SRAM reg write request skipped an address: %05x.", $time, prev_addr + 1'b1);
                     $stop;
                  end
                  seq_state <= 1;
                  prev_addr <= sram_reg_addr;
               end // if (sram_reg_req && !sram_reg_rd_wr_L)
            end // case: 2
         endcase // case(seq_state)
      end // else: !if(reset)
   end // always @ (posedge clk)

   // synthesis translate_on

endmodule // sram_arbiter


