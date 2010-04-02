//////////////////////////////////////////////////////////////////////////////
// $Id: tasks.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: tasks.v
// Project: u_board verification
// Description: Tasks used in u_board testbench
//
///////////////////////////////////////////////////////////////////////////////


// THIS WILL BE `include 'd by the verilog that uses it.






reg [7:0] packet_memory[0:1522];
reg [7:0] e_packet_memory[0:1522];  // egress pkts

integer   max_inter_packet_time;
initial begin max_inter_packet_time = 20000; end

reg [31:0]  exp_egr_seq_num [0:3];


// ==================================================================
// Set up the table used to calculate CRCs

reg [31:0] crc_table [0:255];

task gen_crc_table;
      reg [31:0] c;
      integer n, k;
      begin
	 for (n = 0; n < 256; n = n + 1) begin
	    c = n;
	    for (k = 0; k < 8; k = k + 1) begin
	       if (c & 1)
		 c = 32'hedb88320 ^ (c >> 1);
	       else
		 c = c >> 1;
	    end
	    crc_table[n] = c;
	 end
      end
endtask // gen_crc_table

// ==================================================================
// CRC generation function.
// You should invert CRC when finished.
// e.g.:  crc = update_crc(32'hffffffff,len)^32'hffffffff;

function [31:0]  update_crc;
      input [31:0]crc;
      input [31:0] len;
      reg [31:0] c;
      integer i, n;
      begin
	 c = crc;
	 for (n = 0; n < len; n = n + 1) begin
	    i = ( c ^ packet_memory[n] ) & 8'hff;
	    c = crc_table[i] ^ (c >> 8);
	 end
	 update_crc = c;
      end
endfunction // update_crc

// ==================================================================
// Generate an ingress packet. Put it in a global chunk of memory
// from where it should then be immediately copied to a local memory
// before use.
task gen_pkt;
   input [31:0] pkt_size;   // number of bytes to send.(excl CRC)
   input [15:0] pkt_num;
   input bad_frame;         // set to 1 if you want a bad frame

   integer i;
   reg [31:0] crc;

   begin
      if (crc_table[1] !== 32'h77073096) begin
	 $display("%t Building CRC table.", $time);
	 gen_crc_table;
      end
      if (pkt_size > 1518) begin
	 $display("%t ERROR: %m: Packet size requested was %0d but max is 1518 (excl CRC)",
		  $time, pkt_size);
	 #100 $finish;
      end

      // Bytes 1:0 are length (in bytes, excl CRC)
      packet_memory[0] = pkt_size[7:0];
      packet_memory[1] = pkt_size[15:8];
      // Bytes 3:2 are seq num provided
      packet_memory[2] = pkt_num[7:0];
      packet_memory[3] = pkt_num[15:8];
      // the rest is just data
      for (i=4;i<pkt_size;i=i+1) begin
	 packet_memory[i] = ((i[7:0]+1) ^  pkt_num[7:0]);
      end

      // BUT!!! we need to put in a valid Ethertype
      packet_memory[12] = 8'h81;
      packet_memory[13] = 8'h00;
      packet_memory[16] = 8'h08;
      packet_memory[17] = 8'h00;

      // clear bytes for CRC
      for (i=pkt_size;i<(pkt_size+4);i=i+1) begin
	 packet_memory[i] = 8'h0;
      end
      crc = update_crc(32'hffffffff,pkt_size)^32'hffffffff;

      $display("%t CRC for seq num %0d was %0x ", $time, pkt_num, crc);

      // corrupt CRC if requested.
      if (bad_frame)
	if (crc != 'h0bad0bad) crc = 'h0bad0bad;
	else  crc = 'h1bad1bad;
      // insert CRC
      packet_memory[pkt_size]   = crc[7:0];
      packet_memory[pkt_size+1] = crc[15:8];
      packet_memory[pkt_size+2] = crc[23:16];
      packet_memory[pkt_size+3] = crc[31:24];
   end
endtask // gen_pkt

// ==================================================================
// Generate an egress packet. Put it in a global chunk of memory
// (e_packet_memory) from where it should be IMMEDIATELY copied
// to a local memory before use.
// Do not need to calculate CRC - that is done by the hardware

task gen_egress_pkt;
   input [31:0] pkt_size;   // number of bytes to send.(excl CRC)
   input [15:0] pkt_num;

   integer i;

   begin
      if (pkt_size > 1518) begin
	 $display("%t ERROR: %m: Packet size requested was %0d but max is 1518 (excl CRC)",
		  $time, pkt_size);
	 #100 $finish;
      end

      // Bytes 1:0 are length (in bytes, excl CRC)
      e_packet_memory[0] = pkt_size[7:0];
      e_packet_memory[1] = pkt_size[15:8];
      // Bytes 3:2 are seq num provided
      e_packet_memory[2] = pkt_num[7:0];
      e_packet_memory[3] = pkt_num[15:8];
      // the rest is just data
      for (i=4;i<pkt_size;i=i+1) begin
	 e_packet_memory[i] = ((i[7:0]+1) ^  pkt_num[7:0]);
      end

      // BUT!!! we need to put in a valid Ethertype
      e_packet_memory[12] = 8'h81;
      e_packet_memory[13] = 8'h00;
      e_packet_memory[16] = 8'h08;
      e_packet_memory[17] = 8'h00;

      for (i=pkt_size;i<(pkt_size+4);i=i+1) begin
	 e_packet_memory[i] = 8'h0;
      end
   end
endtask // gen_egress_pkt




   // ==================================================================
   // Generate an ingress packet
   task ingress_pkt;

      input [31:0] pkt_size;   // number of bytes to send. (excl CRC)
      input [15:0] pkt_num;
      input bad_frame;         // set to 1 if you want a bad frame

      reg [7:0] pkt[0:1522];
      integer i;
      begin
	 $display("%t Create ingress packet of %0d bytes, seq %d  arriving at MAC %0d",
		  $time, pkt_size, pkt_num, 0);

	 //create the pkt and copy it to a local buffer
	 gen_pkt(pkt_size, pkt_num, bad_frame);
	 for (i=0 ; i<(pkt_size+4) ; i=i+1) pkt[i] = packet_memory[i];

         //$display("Sending pkt len %0d", pkt_size);
	 // Preamble and SFD: 7 bytes of 0x55 and then 1 byte of 0xD5
	 @(negedge gmii_0_rx_clk) gmii_0_rx_dv = 1;
	 gmii_0_rx_d = 8'h55;
	 for (i=0 ; i<7 ; i=i+1) #1 @(negedge gmii_0_rx_clk) begin end
	 gmii_0_rx_d = 8'hd5;
	 #1 @(negedge gmii_0_rx_clk) begin end

	 // send pkt data

	 for (i=0 ; i<(pkt_size+4) ; i=i+1) begin
	    gmii_0_rx_d = pkt[i];
	    #1 @(negedge gmii_0_rx_clk) begin end
	 end
	 #1 gmii_0_rx_dv = 0;
	 gmii_0_rx_d = 0;

         //$display("Sent pkt len %0d", pkt_size);

	 #100 @(negedge gmii_0_rx_clk) begin end

      end
   endtask // ingress_pkt





   // ==================================================================
   // Keep sending ingress packets. Wait random times between packets
   // If the packet is received in the ingress FIFO then we increment
   // the ingress_pkt_number_X for this mac.

`ifdef GATE_SIM
   wire 	good_pkt_rcvd_0 = 1'b1;
   wire 	bad_pkt_rcvd_0  = 1'b0;
`else
   wire 	good_pkt_rcvd_0 = u_board.nf2_top.unet_mac_grp.cnet_rxfifo_sm.good_pkt_rcvd;
   wire 	bad_pkt_rcvd_0  = u_board.nf2_top.unet_mac_grp.cnet_rxfifo_sm.bad_pkt_rcvd;
`endif

   reg [15:0] 	ingress_pkt_number_0;

   task send_ingress_pkts;

      input [31:0] num_to_send;
      input [31:0] min_size, max_size;   // packet size range

      integer length;
      time delay;
      integer pkts_left_to_send;

      begin

	 pkts_left_to_send = num_to_send;
         ingress_pkt_number_0 = 0;

	 while (pkts_left_to_send > 0) begin

	    // decide on pkt characteristics
	    length = $dist_uniform(seed,min_size, max_size);

	    fork
	       ingress_pkt(length, ingress_pkt_number_0, 1'b0);

	       begin
		  // wait until we see if packet was accepted OK or discarded.
		  wait (good_pkt_rcvd_0 || bad_pkt_rcvd_0);

		  // If good then it will eventually get placed into the SRAM.
		  if (good_pkt_rcvd_0) begin
		     // Put it in the queue
		     $display("%t MAC %0d ingress FIFO accepted pkt number %0d (length %0d)",
			      $time, 0, ingress_pkt_number_0, length);
		     #1 ingress_pkt_number_0 = ingress_pkt_number_0 + 1;
		     pkts_left_to_send = pkts_left_to_send - 1;
		  end
		  else begin
		     $display("%t MAC %0d ingress FIFO dropped pkt number %0d (length %0d)",
			      $time, 0, ingress_pkt_number_0, length);
		  end // else: !if(good_pkt_rcvd_0)
	       end

	    join

	    // wait until packet finished
	    while (good_pkt_rcvd_0 || bad_pkt_rcvd_0) @(posedge gmii_0_rx_clk) begin end

	    // now wait a while
	    delay = $dist_uniform(seed,100,max_inter_packet_time);
	    #(delay) begin  end


	 end // while (pkts_left_to_send)
      end

   endtask // send_ingress_pkts




   //=========================================================
   // TX MAC process accepting packets from UNET for transmission
   // This assumes DA and SA ARE flipped.

   task tx_mac;
      reg [7:0] data;

      reg [7:0] pkt [0:2047];
      reg [31:0] actual_crc,c;

      integer actual_seq_num;
      integer i,n;
      reg seeing_data;
      integer len, exp_len;
      reg [7:0] exp_byte;

      begin
	 exp_egr_seq_num[0] = 0;

	 #100 while(1) begin

	    // wait for start of packet
	    wait (gmii_0_tx_en);
	    seeing_data = 0;
	    i = 0;

	    while (gmii_0_tx_en) begin
	       @(posedge gmii_0_tx_clk) data <= gmii_0_tx_d;
	       #7 begin end
	       //$display("Egress port %1d data 0x%2x", 0, data);
	       if (seeing_data) begin
		  pkt[i] = data;
		  i = i + 1;
	       end
	       else begin
		  if (data == 8'hd5) seeing_data = 1;
		  else if (data != 8'h55)
		    $display("%t ERROR %m : expected preamble but saw %2x", $time,data);
	       end

	    end // while (gmii_0_tx_en)

	    // save actual crc
	    actual_crc = {pkt[i-1],pkt[i-2],pkt[i-3],pkt[i-4]};
	    // set len to length minus CRC
	    len = i - 4;
	    // clear out the CRC in memory.
	    for (i=len;i<len+8;i=i+1) pkt[i] = 0;

	    // length check
	    exp_len = {16'h0, pkt[7],pkt[6]};

	    if (exp_len != len)
	      $display("%t ERROR %m : expected length %4d but saw length %4d",
		       $time, exp_len, len);
	    else
	      $display("%t Tx Port %1d transmitted pkt length %4d (as expected)",$time, 0, len);

	    // seq num check
	    actual_seq_num = {16'h0, pkt[9], pkt[8]};
	    if (exp_egr_seq_num[0] != actual_seq_num)
	      $display("%t ERROR %m : expected seq num was %4d but saw seq num %4d.",
		       $time, exp_egr_seq_num[0], actual_seq_num);

            else exp_egr_seq_num[0] = exp_egr_seq_num[0] + 1;

	    // check data
	    for (i=12;i<len;i=i+1) begin
	       exp_byte = (i[7:0]+1) ^ actual_seq_num[7:0];
	       if (i==12) exp_byte = 8'h81; // valid vlan ethertype
	       if (i==13) exp_byte = 8'h0;
	       if (i==16) exp_byte = 8'h8; // valid ethertype
	       if (i==17) exp_byte = 8'h0;

	       if (pkt[i] != exp_byte)
		 $display("%t ERROR %m : packet byte %d: exp byte was 0x%2x but saw byte 0x%2x",
			  $time,  i, exp_byte, pkt[i]);
	    end // for (i=4;i<pkt_len;i++)


	    if (crc_table[1] !== 32'h77073096) begin
	       $display("%t Building CRC table.", $time);
	       gen_crc_table;
	    end

	    // check crc.
	    c = 32'hffffffff;
	    for (n = 0; n < len; n = n + 1) begin
	       i = ( c ^ pkt[n] ) & 8'hff;
	       c = crc_table[i] ^ (c >> 8);
	    end
	    c = c ^ 32'hffffffff;

	    if (c != actual_crc)
	      $display("%t ERROR %m : expected CRC was 0x%8x but actual CRC was 0x%8x",
		       $time,  c, actual_crc);
	    //else   $display("good crc %x   actual: %x",c, actual_crc);



	    #20 begin end
	 end

      end
   endtask // tx_mac_0




   //=========================================================
   // TX MAC process accepting packets from UNET for transmission
   // This assumes Da and SA are NOT flipped.

   task tx_mac_no_DASA_flip;
      reg [7:0] data;

      reg [7:0] pkt [0:2047];
      reg [31:0] actual_crc,c;

      integer actual_seq_num;
      integer i,n;
      reg seeing_data;
      integer len, exp_len;
      reg [7:0] exp_byte;

      begin
	 exp_egr_seq_num[0] = 0;

	 #100 while(1) begin

	    // wait for start of packet
	    wait (gmii_0_tx_en);
	    seeing_data = 0;
	    i = 0;

	    while (gmii_0_tx_en) begin
	       @(posedge gmii_0_tx_clk) data <= gmii_0_tx_d;
	       #7 begin end
	       //$display("Egress port %1d data 0x%2x", 0, data);
	       if (seeing_data) begin
		  pkt[i] = data;
		  i = i + 1;
	       end
	       else begin
		  if (data == 8'hd5) seeing_data = 1;
		  else if (data != 8'h55)
		    $display("%t ERROR %m : expected preamble but saw %2x", $time,data);
	       end

	    end // while (gmii_0_tx_en)

	    // save actual crc
	    actual_crc = {pkt[i-1],pkt[i-2],pkt[i-3],pkt[i-4]};
	    // set len to length minus CRC
	    len = i - 4;
	    // clear out the CRC in memory.
	    for (i=len;i<len+8;i=i+1) pkt[i] = 0;

	    // length check
	    exp_len = {16'h0, pkt[1],pkt[0]};

	    if (exp_len != len)
	      $display("%t ERROR %m : expected length %4d but saw length %4d",
		       $time, exp_len, len);
	    else
	      $display("%t Tx Port %1d transmitted pkt length %4d (as expected)",$time, 0, len);

	    // seq num check
	    actual_seq_num = {16'h0, pkt[3], pkt[2]};
	    if (exp_egr_seq_num[0] != actual_seq_num)
	      $display("%t ERROR %m : expected seq num was %4d but saw seq num %4d.",
		       $time, exp_egr_seq_num[0], actual_seq_num);

            else exp_egr_seq_num[0] = exp_egr_seq_num[0] + 1;

	    // check data
	    for (i=4;i<len;i=i+1) begin
	       exp_byte = (i[7:0]+1) ^ actual_seq_num[7:0];
	       if (i==12) exp_byte = 8'h81; // valid vlan ethertype
	       if (i==13) exp_byte = 8'h0;
	       if (i==16) exp_byte = 8'h8; // valid ethertype
	       if (i==17) exp_byte = 8'h0;

	       if (pkt[i] != exp_byte)
		 $display("%t ERROR %m : packet byte %d: exp byte was 0x%2x but saw byte 0x%2x",
			  $time,  i, exp_byte, pkt[i]);
	    end // for (i=4;i<pkt_len;i++)


	    if (crc_table[1] !== 32'h77073096) begin
	       $display("%t Building CRC table.", $time);
	       gen_crc_table;
	    end

	    // check crc.
	    c = 32'hffffffff;
	    for (n = 0; n < len; n = n + 1) begin
	       i = ( c ^ pkt[n] ) & 8'hff;
	       c = crc_table[i] ^ (c >> 8);
	    end
	    c = c ^ 32'hffffffff;

	    if (c != actual_crc)
	      $display("%t ERROR %m : expected CRC was 0x%8x but actual CRC was 0x%8x",
		       $time,  c, actual_crc);
	    //else   $display("good crc %x   actual: %x",c, actual_crc);



	    #20 begin end
	 end

      end
   endtask // tx_mac_0




   // ---------------------------------------
   // ---
   // Provide mutex to control access to PCI bus.

   reg 		      pci_mutex;
   initial begin pci_mutex = 0; end

`define GET_PCI_MUTEX      wait(pci_mutex===1'b0);pci_mutex=1;$display($time,"%m has mutex");
`define RELEASE_PCI_MUTEX  pci_mutex=0;$display($time,"%m released mutex");

   // ----
   // ---------------------------------------

  //=============================================================

   reg [15:0] expected_dma_ingress_seq_num [3:0];

   reg [31:0] ingress_rcvd [0:3];  // number received

   reg 	      ingress_dma_done;
   reg 	      egress_dma_done;


  //=============================================================
  // Process interrupts and assert either ingress_dma_done
  // or egress_dma_done
  //=============================================================
   task do_interrupt_handler;
      reg [`PCI_DATA_WIDTH - 1:0] returned;
      reg 			  success;
      begin

	 ingress_dma_done = 0;
	 egress_dma_done = 0;

	 while (1) begin

	    wait(~INTR_A);
	    $display("%t Interrupt handler saw interrupt - will get MUTEX: ",$time);

	    `GET_PCI_MUTEX

            host32.PCI_DW_RD(`CPCI_Interrupt_Status_reg, 4'h6, returned, success);
	    host32.DECODE_INTR(returned);

	    `RELEASE_PCI_MUTEX

	    #5 begin end
	    if (returned[31] == 1'b1) ingress_dma_done = 1;
	    if (returned[30] == 1'b1) egress_dma_done = 1;

	    #500 begin end
	 end

      end
   endtask // do_interrupt_handler




   //=====================================================================
   // Stop sim and check the packets received and transmitted, based on the
   // current expected sequence numbers for each port.

   task stop_at;
      input [63:0] stop_time;
      input [31:0]  exp_ingr_0;
      input [31:0]  exp_egr_0;

      begin
	 $display("Will terminate sim at time %t", (stop_time+$time));
	 #(stop_time) $display("%m: FINISHING AT %t",$time);
	 // check rcvd packets
	 $display("============================================");
	 $display("Checking packets received and transmitted...");
	 $display("============================================");


	 if (exp_egr_0 == exp_egr_seq_num[0])
	   $display("Good: Port %1d saw %4d egress packets ",
		    0, exp_egr_0);
         else
	   $display("ERROR: Port %1d: At end of sim expected to see %d egress packets but saw %d",
		    0, exp_egr_0, exp_egr_seq_num[0]);


	 $display("Checking packets completed.");


	 $finish;
      end
   endtask // stop_at
