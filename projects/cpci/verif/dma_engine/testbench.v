///////////////////////////////////////////////////////////////////////////////
// $Id: testbench.v 1887 2007-06-19 21:33:32Z grg $
//
// Testbench: dma_engine
// Project: CPCI (PCI Control FPGA)
// Description: Tests the dma_engine module
//
// Test bench must simulate a series of DMA transfers.
//
// Change history:
//
///////////////////////////////////////////////////////////////////////////////

`timescale 1 ns / 1 ns

module testbench ( );

// ==================================================================
// Constants
// ==================================================================

`define RETRY     1'b1
`define NO_RETRY  1'b0

`define BUF_SIZE  4'h6




parameter Tpclk = 15;
parameter Tnclk = 8;


reg reset, nclk, pclk;


// PCI Signals
reg [`PCI_DATA_WIDTH-1:0] pci_data;      // Data being read from host

wire [`PCI_DATA_WIDTH-1:0] dma_data; // Data being written to host
wire [3:0]   dma_cbe;       // Command/Byte Enables for DMA data

reg          dma_data_vld;  // Indicates data should be captured
reg          dma_src_en;    // The next piece of data should

reg            dma_lat_timeout;  // Latency timer has expired
reg            dma_addr_st;   // Core is in the address state
reg            dma_data_st;   // Core is in the data state

reg            pci_retry;     // Retry signal from CSRs
reg            pci_fatal;     // Fatal error signal from CSRs

// CPCI register interface signals
reg [31:0]   dma_rd_addr;   // Address when performing reads
reg [31:0]   dma_wr_addr;   // Address when performing writes

wire [1:0]   dma_rd_mac;    // Which MAC to read data from
reg [1:0]    dma_wr_mac;    // Which MAC to write data to

wire [31:0]   dma_rd_size;// Packet size when performing reads
reg [31:0]   dma_wr_size;// Packet size when performing reads

reg          dma_rd_owner;  // Who owns read buffer (1 = CPCI)
reg          dma_wr_owner;  // Who owns write buffer (1 = CPCI)

reg [31:0]   dma_time;      // Number of clocks before a DMA transfer times out

reg [7:0]    dma_retries;   // Number of retries before a DMA transfer times out

reg            host_is_le; // Host is little endian

// CNET register interface signals
wire [`CPCI_CNET_DATA_WIDTH-1:0] dma_data_buf; // DMA Data going from the CPCI to the CNET
wire [`CPCI_CNET_ADDR_WIDTH-1:0] dma_addr_buf; // DMA Data going from the CPCI to the CNET

reg          p2n_full;      // Buffer is full

// CNET DMA interface signals
reg [3:0]      dma_pkt_avail; // Packets available in which buffers in CNET
wire [3:0]     dma_pkt_request; // Request packet from buffer X

reg [31:0]     dma_data_frm_cnet; // DMA data to be transfered

reg [3:0]      dma_tx_full;   // Buffer full in the CNET

reg            dma_nearly_empty; // Three words or less left in the buffer
reg            dma_empty;     // Is the buffer empty?
reg            dma_all_in_buf; // All data for the packet is in the buffer

// Miscelaneous signals
reg          cnet_reprog;   // Indicates that the CNET is


integer                             i;

wire [3:0] buf_size = `BUF_SIZE;

reg expect_timeout;

reg dma_request_d1;

integer pci_term_cnt;

reg wr_in_prog;
integer term_cnt;
integer num_read;
integer tran_size;


// ==================================================================
// Generate a clock signal
// ==================================================================

always
begin
   pclk <= 1'b1;
   #Tpclk;
   pclk <= 1'b0;
   #Tpclk;
end

always
begin
   nclk <= 1'b1;
   #Tnclk;
   nclk <= 1'b0;
   #Tnclk;
end


// ==================================================================
// Instantiate the module under test
// ==================================================================

dma_engine dma_engine(
            .pci_data (pci_data),
            .dma_data (dma_data),
            .dma_cbe (dma_cbe),
            .dma_wrdn (dma_wrdn),
            .dma_request (dma_request),
            .dma_complete (dma_complete),
            .dma_data_vld (dma_data_vld),
            .dma_src_en (dma_src_en),
            .dma_lat_timeout (dma_lat_timeout),
            .dma_addr_st (dma_addr_st),
            .dma_data_st (dma_data_st),
            .dma_rd_intr (dma_rd_intr),
            .dma_wr_intr (dma_wr_intr),
            .pci_retry (pci_retry),
            .pci_fatal (pci_fatal),
            .dma_rd_addr (dma_rd_addr),
            .dma_wr_addr (dma_wr_addr),
            .dma_rd_mac (dma_rd_mac),
            .dma_wr_mac (dma_wr_mac),
            .dma_rd_size (dma_rd_size),
            .dma_wr_size (dma_wr_size),
            .dma_rd_owner (dma_rd_owner),
            .dma_wr_owner (dma_wr_owner),
            .dma_rd_done (dma_rd_done),
            .dma_wr_done (dma_wr_done),
            .dma_time (dma_time),
            .dma_timeout (dma_timeout),
            .dma_retries (dma_retries),
            .dma_retry_expire (dma_retry_expire),
            .dma_rd_size_err (dma_rd_size_err),
            .dma_wr_size_err (dma_wr_size_err),
            .dma_rd_addr_err (dma_rd_addr_err),
            .dma_wr_addr_err (dma_wr_addr_err),
            .dma_rd_mac_err (dma_rd_mac_err),
            .dma_wr_mac_err (dma_wr_mac_err),
            .dma_in_progress (dma_in_progress),
            .host_is_le (host_is_le),
            .dma_data_buf (dma_data_buf),
            .dma_addr_buf (dma_addr_buf),
            .dma_req (dma_req),
            .p2n_full (p2n_full),
            .dma_pkt_avail (dma_pkt_avail),
            .dma_pkt_request (dma_pkt_request),
            .dma_data_frm_cnet (dma_data_frm_cnet),
            .dma_rd_en (dma_rd_en),
            .dma_tx_full (dma_tx_full),
            .dma_nearly_empty (dma_nearly_empty),
            .dma_empty (dma_empty),
            .dma_all_in_buf (dma_all_in_buf),
            .cnet_reprog (cnet_reprog),
            .reset (reset),
            .clk (pclk)
         );


// ==================================================================
// Test structures
// ==================================================================


// Simulate the pci userapp
task pci_request;
   integer waits, cnt;
   reg [31:0] data;

   reg dma_src_en_d1, dma_src_en_d2;

   begin
      pci_term_cnt = - 'h1;

      // Wait a few cycles
      waits = {$random} % 10 + 1;
      while (waits > 0) begin
         @(posedge pclk);
         waits = waits - 1;
      end

      // Request the address
      @(negedge pclk)
         dma_addr_st <= 1'b1;

      // Work out if we're doing a read or a write
      @(posedge pclk)
         $display($time, " New %s transaction at address 0x%h  Command: 0x%h", dma_wrdn ? "write" : "read", dma_data, dma_cbe);

      @(negedge pclk) begin
         dma_addr_st <= 1'b0;
         dma_data_st <= 1'b1;
      end

      // Work out if we're reading or writing
      if (dma_wrdn) begin
         // Generate a retry sometimes
         if ({$random} % 10 == 0) begin
            @(negedge pclk) begin
               dma_data_st <= 1'b0;
               pci_retry <= 1'b1;
            end
            @(posedge pclk);
            @(negedge pclk)
               pci_retry <= 1'b0;
            @(posedge pclk) #1;

            disable pci_request;
         end


         dma_src_en_d1 = 0;
         dma_src_en_d2 = 0;
         // Check if we should terminate in 2 cycles
         while (!dma_complete || !dma_src_en_d1) begin
            @(negedge pclk) begin
               dma_src_en <= 1'b1;
               dma_data_vld <= dma_src_en_d2;
            end
            @(posedge pclk) begin
               dma_src_en_d1 <= dma_src_en;
               dma_src_en_d2 <= dma_src_en_d1;
            end
            $display($time, " Written 0x%h on PCI bus,  CBE=%b", dma_data, dma_cbe);
         end

         // End the transaction
         while (dma_data_st) begin
            @(negedge pclk) begin
               dma_src_en <= 1'b0;
               dma_data_vld <= dma_src_en_d2;
               dma_data_st <= dma_src_en_d2;
               dma_data_vld <= dma_src_en_d2;
            end
            @(posedge pclk) begin
               dma_src_en_d1 <= dma_src_en;
               dma_src_en_d2 <= dma_src_en_d1;
            end
         end

         #1;
      end
      else begin
         // Wait a few cycles
         waits = {$random} % 3 + 1;
         while (waits > 0) begin
            @(posedge pclk);
            waits = waits - 1;
         end

         // Check if we're in a write
         if (!wr_in_prog) begin
            cnt = 'd0;
            data = 'h00010203;
         end
         else begin
            cnt = 'd4;
            data = 'h10111213;
         end

         for (i = 0; (i < 4 && !wr_in_prog) || (cnt < dma_engine.xfer_cnt_start && wr_in_prog); i = i + 1) begin
            @(negedge pclk) begin
               pci_data <= data;
               dma_data_vld <= 1'b1;
               cnt <= cnt + 1;
               data[7:0]   = data[7:0] + 'h4;
               data[15:8]  = data[15:8] + 'h4;
               data[23:16] = data[23:16] + 'h4;
               data[31:24] = data[31:24] + 'h4;
            end
            @(posedge pclk);
            $display($time, " Read 0x%h on PCI bus,  CBE=%b", pci_data, dma_cbe);
         end

         $display($time, " Checking: %x  %x", cnt + 1, dma_engine.xfer_cnt_start);
         if (cnt >= dma_engine.xfer_cnt_start)
            wr_in_prog = 1'b0;
         else
            wr_in_prog = 1'b1;

         // End the transaction
         @(negedge pclk) begin
            dma_data_vld <= 1'b0;
            dma_data_st <= 1'b0;
            pci_data <= - 'h1;
         end
         @(posedge pclk) #1;
      end
   end
endtask


// Perform a read operation
task do_read;
   input [31:0] addr;
   input [15:0] size;
   input le;

   begin
      dma_rd_addr = addr;
      tran_size = size;
      host_is_le = le;
      $display(" ");
      $display(" ");
      $display($time, " Should see a 'read' of %1d from %8x (%s-endian)", tran_size, dma_rd_addr, host_is_le ? "little" : "big");
      $display(" ");
      dma_rd_owner = 1'b1;
      wait (dma_rd_done);
   end
endtask



always @(posedge pclk)
begin
   if (dma_request_d1 && dma_request)
      $display($time, " ERROR: dma_request was asserted for multiple clock cycles");
   else if (dma_request)
      pci_request;
   dma_request_d1 <= dma_request;
end


// Simulate the DMA buffer
task pkt_request;
   integer waits, cnt;
   integer fill_cnt;

   begin
      // Reset the read counter
      num_read = -1;

      // Wait a few cycles
      waits = {$random} % 10 + 1;
      while (waits > 0) begin
         @(posedge pclk) #1;
         waits = waits - 1;
      end

      // Work out the size of the transaction
      term_cnt = tran_size / 4 + ((tran_size % 4 > 0) ? 1 : 0);
      cnt = term_cnt;

      // Simulate the filling of the buffer
      while (cnt > 0) begin
         @(negedge pclk) begin
            dma_empty <= term_cnt - cnt - num_read == 0;
            if (term_cnt - cnt - num_read >= 5)
               dma_nearly_empty <= 1'b0;
            else if (term_cnt - cnt - num_read < 4)
               dma_nearly_empty <= 1'b1;
         end

         @(posedge pclk);

         // Wait a while every now and again
         if (cnt % 4 == 0 && {$random} % 20 == 0)
            #(Tpclk * 40);

         // The following weird count math is to simulate multiple words being
         // added to the buffer in a single pclk, since nclk > pclk
         cnt = cnt - {$random} % 3 - 1;
      end

      @(negedge pclk)
         dma_all_in_buf <= 1'b1;

      // Wait until the buffer is empty
      while (num_read != term_cnt) begin
         wait (!pclk)
         if (term_cnt - cnt - num_read >= 5)
            dma_nearly_empty <= 1'b0;
         else if (term_cnt - cnt - num_read < 4)
            dma_nearly_empty <= 1'b1;

         @(posedge pclk);
      end

      @(negedge pclk)
         dma_empty = 1'b1;

      @(posedge pclk);
   end
endtask

always @(posedge pclk)
begin
   /*if (num_read == -1)
      dma_data_frm_cnet = #1 tran_size;
   else
      dma_data_frm_cnet = #1 num_read;*/
   if (dma_rd_en) begin
      num_read = num_read + 1;
      if (num_read == term_cnt)
         @(negedge pclk)
            dma_empty <= 1'b1;
   end
end

always @(negedge pclk)
begin
   if (num_read == -1)
      dma_data_frm_cnet <= - 'h1;
   if (num_read == 0)
      dma_data_frm_cnet <= tran_size;
   else begin
      //dma_data_frm_cnet <= num_read - 1 + 'haabbcc00;
      dma_data_frm_cnet[31:24] <= (num_read - 1) * 4 + 'h3;
      dma_data_frm_cnet[23:16] <= (num_read - 1) * 4 + 'h2;
      dma_data_frm_cnet[15:8]  <= (num_read - 1) * 4 + 'h1;
      dma_data_frm_cnet[7:0]   <= (num_read - 1) * 4 + 'h0;
   end
end

reg [3:0] dma_pkt_request_d1;
always @(posedge pclk)
begin
   if (|(dma_pkt_request) && ~|(dma_pkt_request_d1)) begin
      pkt_request;
   end
   dma_pkt_request_d1 <= dma_pkt_request;
end


// Watch dma_rd_done and dma_wr_done
always @(posedge pclk)
begin
   if (dma_rd_done) begin
      $display($time, " Done with DMA read. MAC = %1d  Size = %d", dma_rd_mac, dma_rd_size);
      dma_rd_owner = 1'b0;
   end
   else if (dma_wr_done) begin
      $display($time, " Done with DMA write.");
      dma_wr_owner = 1'b0;
   end
end

// Watch for errors
always @(posedge pclk)
begin
   if (dma_timeout)
      $display($time, " ERROR: DMA timeout");
   if (dma_retry_expire)
      $display($time, " ERROR: Retry counter expired");
   if (dma_rd_size_err)
      $display($time, " ERROR: DMA read size error.");
   if (dma_wr_size_err)
      $display($time, " ERROR: DMA write size error. Size = %d", dma_wr_size);
   if (dma_rd_addr_err)
      $display($time, " ERROR: DMA read address errror. Addr = 0x%h", dma_rd_addr);
   if (dma_wr_addr_err)
      $display($time, " ERROR: DMA write address errror. Addr = 0x%h", dma_wr_addr);
   if (dma_rd_mac_err)
      $display($time, " ERROR: DMA read MAC errror.");
   if (dma_wr_mac_err)
      $display($time, " ERROR: DMA write MAC errror.");
end

// Watch for writes to the CNET registers
always @(posedge pclk)
begin
   if (dma_req)
      if (dma_addr_buf[`CPCI_CNET_ADDR_WIDTH - 1 : `CPCI_CNET_ADDR_WIDTH - 1 - 3] !== `CNET_Tx_FIFO_select)
         //$display($time, " Write to CNET reg 0x%h (Last word: %b  MAC: %1d  Num bytes: %1d)  Data: 0x%h", dma_addr_buf, dma_addr_buf[7], dma_addr_buf[5:4], dma_addr_buf[3:2] + 1, dma_data_buf);
      //else
         $display($time, " Write to CNET reg 0x%h  Data: 0x%h", dma_addr_buf, dma_data_buf);
end

// Watch for dma write transactions and make sure they're correct
reg[7:0] next_byte;
integer xfer_cnt_bytes;
integer xfer_cnt_words;
always @(posedge dma_wr_owner)
begin
   next_byte = dma_wr_addr[7:0];
   xfer_cnt_bytes = dma_wr_size;
   xfer_cnt_words = dma_wr_size / 4 + ((dma_wr_size[1:0] == 0) ? 0 : 1);
   $display($time, " DMA Write transaction started (to CPCI): Words: %d", xfer_cnt_words);
end

integer xfer_i;
reg [7:0] dma_data_buf_byte;
always @(posedge pclk)
begin
   if (dma_req && dma_addr_buf[`CPCI_CNET_ADDR_WIDTH - 1 : `CPCI_CNET_ADDR_WIDTH - 1 - 3] == `CNET_Tx_FIFO_select)
   begin
      if (xfer_cnt_words == 0)
      begin
         $display($time, " Error: Unexpected write to CNET reg 0x%h (Last word: %b  MAC: %1d  Num bytes: %1d)  Data: 0x%h", dma_addr_buf, dma_addr_buf[7], dma_addr_buf[5:4], dma_addr_buf[3:2] + 1, dma_data_buf);
      end
      else
      begin
         xfer_cnt_words = xfer_cnt_words - 1;
         for (xfer_i = 0; xfer_i < 4 && xfer_i < xfer_cnt_bytes; xfer_i = xfer_i + 1)
         begin
            case (xfer_i)
               0 : dma_data_buf_byte = dma_data_buf[07:00];
               1 : dma_data_buf_byte = dma_data_buf[15:08];
               2 : dma_data_buf_byte = dma_data_buf[23:16];
               3 : dma_data_buf_byte = dma_data_buf[31:24];
            endcase
            if (dma_data_buf_byte != next_byte)
               $display($time, " Error: Unexpected write to CNET reg 0x%h in byte %d  Data: 0x%h  Expected: 0x%h", dma_addr_buf, 3 - xfer_i, dma_data_buf, next_byte);
            next_byte = next_byte + 'h1;
         end
         xfer_cnt_bytes = xfer_cnt_bytes - 4;
      end
   end
end

always @(posedge dma_wr_done)
begin
   if (xfer_cnt_words != 0)
      $display($time, " Error: dma_wr_done asserted unexpectedly");
end

always @(posedge pclk)
begin
   if (pci_retry)
      $display($time, " PCI Retry");
   if (pci_fatal)
      $display($time, " PCI Fatal Error");
end

initial
begin
   tran_size = 0;
   num_read = 0;
   wr_in_prog = 0;

   pci_data = 32'hffff_ffff;

   dma_data_vld = 1'b0;
   dma_src_en = 1'b0;
   dma_lat_timeout = 1'b0;
   dma_addr_st = 1'b0;
   dma_data_st = 1'b0;
   pci_retry = 1'b0;
   pci_fatal = 1'b0;

   dma_rd_addr = 'h1111_0000;
   dma_wr_addr = 'hfeed_0000;
   dma_wr_mac = 'h0;
   dma_wr_size = 'd32;

   dma_rd_owner = 1'b0;
   dma_wr_owner = 1'b0;

   dma_time = - 'h1;
   dma_retries = - 'h1;

   p2n_full = 1'b0;

   dma_pkt_avail = 4'b1111;
   dma_tx_full = 4'b0000;

   dma_nearly_empty = 1'b1;
   dma_empty = 1'b1;
   dma_all_in_buf = 1'b0;

   cnet_reprog = 1'b0;

   host_is_le = 1'b0;

   pclk = 0;
   reset = 1;

   #1000  reset = 0;

   // Do a DMA write
   $display(" ");
   $display(" ");
   $display($time, " Read of %d bytes from %x", dma_wr_size, dma_wr_addr);
   $display(" ");
   dma_wr_owner = 1'b1;
   wait (dma_wr_done);

   #100;
   // Try a 'misaligned' write - ie. a write where the first byte comes from
   // a non-word-boundary
   dma_wr_addr = 'hfeed_0001;
   $display(" ");
   $display(" ");
   $display($time, " Read of %d bytes from %x", dma_wr_size, dma_wr_addr);
   $display(" ");
   dma_wr_owner = 1'b1;
   wait (dma_wr_done);

   #100;
   // 2nd misaligned write
   dma_wr_addr = 'hfeed_0002;
   $display(" ");
   $display(" ");
   $display($time, " Read of %d bytes from %x", dma_wr_size, dma_wr_addr);
   $display(" ");
   dma_wr_owner = 1'b1;
   wait (dma_wr_done);

   #100;
   // 3rd misaligned write
   dma_wr_addr = 'hfeed_0003;
   $display(" ");
   $display(" ");
   $display($time, " Read of %d bytes from %x", dma_wr_size, dma_wr_addr);
   $display(" ");
   dma_wr_owner = 1'b1;
   wait (dma_wr_done);

   #100;
   // Try a 'misaligned' write with a non-integer number of words
   dma_wr_size = 'd33;
   dma_wr_addr = 'hfeed_0001;
   $display(" ");
   $display(" ");
   $display($time, " Read of %d bytes from %x", dma_wr_size, dma_wr_addr);
   $display(" ");
   dma_wr_owner = 1'b1;
   wait (dma_wr_done);

   #100;
   // Try a 'misaligned' write with a non-integer number of words
   dma_wr_size = 'd34;
   dma_wr_addr = 'hfeed_0001;
   $display(" ");
   $display(" ");
   $display($time, " Read of %d bytes from %x", dma_wr_size, dma_wr_addr);
   $display(" ");
   dma_wr_owner = 1'b1;
   wait (dma_wr_done);

   #100;
   // Try a 'misaligned' write with a non-integer number of words
   dma_wr_size = 'd35;
   dma_wr_addr = 'hfeed_0001;
   $display(" ");
   $display(" ");
   $display($time, " Read of %d bytes from %x", dma_wr_size, dma_wr_addr);
   $display(" ");
   dma_wr_owner = 1'b1;
   wait (dma_wr_done);

   #100;
   // Try a 'misaligned' write with a non-integer number of words
   dma_wr_size = 'd35;
   dma_wr_addr = 'hfeed_0003;
   $display(" ");
   $display(" ");
   $display($time, " Read of %d bytes from %x", dma_wr_size, dma_wr_addr);
   $display(" ");
   dma_wr_owner = 1'b1;
   wait (dma_wr_done);

   // Do a DMA read
   #100 do_read('h1111_0000, 10, 1);
   #100 do_read('h1111_0000, 10, 0);

   // Do a DMA misaligned read
   #100 do_read('h1111_0001, 10, 1);
   #100 do_read('h1111_0001, 10, 0);

   // Do a DMA misaligned read
   #100 do_read('h1111_0002, 10, 1);
   #100 do_read('h1111_0002, 10, 0);

   // Do a DMA misaligned read
   #100 do_read('h1111_0003, 10, 1);
   #100 do_read('h1111_0003, 10, 0);

   // Do a DMA misaligned read
   #100 do_read('h1111_0001, 12, 1);
   #100 do_read('h1111_0001, 12, 0);

   // Do a DMA misaligned read
   #100 do_read('h1111_0001, 13, 1);
   #100 do_read('h1111_0001, 13, 0);

   // Do a DMA read
   #100 do_read('h1111_0000, 6, 1);

   // Do a DMA read
   #100 do_read('h1111_0000, {$random} % 64 + 4, 1);

   // Do a DMA read
   #100 do_read('h1111_0000, {$random} % 64 + 4, 1);

   // Do a DMA read
   #100 do_read('h1111_0000, {$random} % 64 + 4, 1);

   // Do a DMA read
   #100 do_read('h1111_0000, {$random} % 64 + 4, 1);

   // Do a DMA read
   #100 do_read('h1111_0000, {$random} % 64 + 4, 1);

   // Do a DMA read
   #100 do_read('h1111_0000, {$random} % 64 + 4, 1);

   // Do a DMA read
   #100 do_read('h1111_0000, {$random} % 64 + 4, 1);


   #100
   $display($time," finishing...");
   $finish;

end

initial
begin
   #50000 $finish;
end

endmodule // testbench

/* vim:set shiftwidth=3 softtabstop=3 expandtab: */
