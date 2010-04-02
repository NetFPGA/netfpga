///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: prog_ctrl.v 1912 2007-07-10 22:34:11Z grg $
//
// Module: prog_ctrl.v
// Project: NetFPGA
// Description: Reprogramming control
//
///////////////////////////////////////////////////////////////////////////////

module prog_ctrl
   #(
      parameter REG_ADDR_WIDTH = 5,
      parameter RAM_ADDR_WIDTH = 16,
      parameter RAM_DATA_WIDTH = 32
   )
   (
      // Programming ROM interface signals
      output reg [RAM_ADDR_WIDTH - 1:0]   ram_addr,
      input [RAM_DATA_WIDTH - 1 : 0]      ram_data,

      // Reprogramming signals
      input                      cpci_rp_done,
      input                      cpci_rp_init_b,
      input                      cpci_rp_cclk,

      output reg                 cpci_rp_en,
      output reg                 cpci_rp_prog_b,
      output reg                 cpci_rp_din,

      // Control signals
      input                      start,

      //
      input             clk,
      input             reset
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


// ==============================================
// State machine states

localparam IDLE            = 3'd0;
localparam PROG_B          = 3'd1;
localparam WAIT_FOR_INIT   = 3'd2;
localparam PROGRAM         = 3'd3;
localparam DONE            = 3'd4;

// Bitstream size in bits
localparam BITSTREAM_SIZE  = 'd1335840;

// Need to hold PROG_B for at least 300ns which is
// 37.5 x 8ns clocks
localparam PROG_B_CNT_START = 'd40;


reg [2:0] state;
reg [20:0] bit_counter;

reg [5:0] prog_b_cnt;

reg [RAM_DATA_WIDTH - 1 : 0] curr_word;

reg cclk_sync1;
reg cclk_sync2;
reg cclk_sync2_d1;

reg cclk_posedge;


// ==============================================
// Main state machine

always @(posedge clk)
begin
   if (reset) begin
      cpci_rp_en <= 1'b0;
      cpci_rp_prog_b <= 1'b1;

      state <= IDLE;

      prog_b_cnt <= PROG_B_CNT_START;
   end
   else begin
      case (state)
         IDLE : begin
            if (start) begin
               cpci_rp_en <= 1'b1;
               cpci_rp_prog_b <= 1'b0;

               prog_b_cnt <= PROG_B_CNT_START;

               state <= PROG_B;
            end
         end

         PROG_B : begin
            // Wait until 300ns have elapsed
            if (prog_b_cnt == 'h1) begin
               cpci_rp_prog_b <= 1'b1;

               state <= WAIT_FOR_INIT;
            end

            prog_b_cnt <= prog_b_cnt - 'h1;
         end

         WAIT_FOR_INIT : begin
            if (cpci_rp_init_b) begin
               state <= PROGRAM;
            end
         end

         PROGRAM : begin
            /*if (download_done) begin
               state <= DONE;
            end*/
            if (cpci_rp_done) begin
               cpci_rp_en <= 1'b0;
               cpci_rp_prog_b <= 1'b1;

               state <= IDLE;
               //addr <= 'h0;

               prog_b_cnt <= PROG_B_CNT_START;
            end
         end

         DONE : begin
            if (cpci_rp_done) begin
               cpci_rp_en <= 1'b0;
               cpci_rp_prog_b <= 1'b1;

               state <= IDLE;
               //addr <= 'h0;

               prog_b_cnt <= PROG_B_CNT_START;
            end
         end

         default : begin
            // synthesis translate_off
            $display($time, " %m: Main state machine in invalid state: %x", state);
            // synthesis translate_on
         end
      endcase
   end
end



// ==============================================
// Data word state machine

always @(posedge clk)
begin
   if (reset || state == IDLE || state == PROG_B) begin
      cpci_rp_din <= 1'b1;

      curr_word <= ram_data;
      ram_addr <= 'h0;

      bit_counter <= BITSTREAM_SIZE - 'h1;
      //download_done <= 1'b0;
   end
   else if (state == WAIT_FOR_INIT) begin
      ram_addr <= 'h1;
   end
   else if (state == PROGRAM) begin
      // Only perform actions when the configuration clock rises
      if (cclk_posedge) begin
         bit_counter <= bit_counter - 'h1;

         cpci_rp_din <= curr_word[RAM_DATA_WIDTH - 1];

         // Fetch the next word if we have finished processing this one
         if (bit_counter[log2(RAM_DATA_WIDTH) - 1 : 0] == 'h0) begin
            curr_word <= ram_data;
            ram_addr <= ram_addr + 'h1;
         end
         else begin
            curr_word <= {curr_word[RAM_DATA_WIDTH - 2:0], 1'b0};
         end

         //if (bit_counter == 'h0) begin
            //download_done <= 1'b1;
         //end
      end
   end
   else if (state == PROG_B) begin
      // Move to the next state when we enter the prog_b state to make sure
      // the next word is ready.
      ram_addr <= 'h1;
   end
end



// ==============================================
// Generate cclk pulses

always @(posedge clk)
begin
   cclk_sync1 <= cpci_rp_cclk;
   cclk_sync2 <= cclk_sync1;
   cclk_sync2_d1 <= cclk_sync2;

   cclk_posedge <= cclk_sync2 && !cclk_sync2_d1;
end


endmodule // prog_ctrl
