//////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: net.v 3454 2008-03-25 05:00:58Z grg $
// ---
// This module provides packet source and sink capabilities for the ethernets.
//
// Ingress files are basically in Verilog readmemh format
//
// Egress files are in our own XML-like format
//////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ns


// default filenames
`define INGRESS_FILE_FMT "packet_data/ingress_port_X"
`define INGRESS_FILE_LEN 26
`define INGRESS_FILE_BITS 8*`INGRESS_FILE_LEN
`define INGRESS_SEPARATOR 32'heeeeffff

`define EGRESS_FILE_FMT "packet_data/egress_port_X"
`define EGRESS_FILE_LEN 25
`define EGRESS_FILE_BITS 8*`EGRESS_FILE_LEN

`define CONFIG_FILE_FMT "config.sim"
`define CONFIG_FILE_LEN 10
`define CONFIG_FILE_BITS 8*`CONFIG_FILE_LEN

`define DEFAULT_FINISH_TIME 1000000

`define INGRESS_MAX_WORD 1000000



module net

  (
    input [31:0]       portID,

   // Rx = packets we generate and send to board
    output  reg [3:0] rgmii_rx_d,
    output  reg       rgmii_rx_ctl,
    input             rgmii_rx_clk,

    // Tx = packets we capture FROM the board
    input [3:0] rgmii_tx_d,
    input       rgmii_tx_ctl,
    input       rgmii_tx_clk,

    input [1:0] link_speed,        // 0=10 1=100 2=1000 3=10000
    input       host32_is_active   // reset and PCI config are complete.

    );

   wire [31:0] my_port_number = portID;

   // inter packet gap is 9.6us for 10Mbs Ethernet
   parameter INTER_PKT_GAP_10 = 9600,
	     INTER_PKT_GAP_100 = 960,
	     INTER_PKT_GAP_1000 = 96-8; // -8 for overhead in packet sending


   reg [3:0]   my_rgmii_rx_d;

   parameter PKT_MEM_SZ = 10000;

   reg [7:0] rx_packet_buffer [0:PKT_MEM_SZ]; // data of receive packet.
   reg [7:0] tx_packet_buffer [0:PKT_MEM_SZ];
   reg [7:0] mem_data;
   reg [31:0] ingress_file [0:`INGRESS_MAX_WORD];

   integer    tx_count;
   integer    rx_count;
   integer    packet_length;
   integer    inter_packet_gap;
   integer    i;
   time       finish_time;   // when simulation should end
   time       last_activity; // when we last saw packet on ingress or egress


   reg [`INGRESS_FILE_BITS-1:0] ingress_file_name;
   reg [`EGRESS_FILE_BITS-1:0] 	egress_file_name;
   reg [`CONFIG_FILE_BITS-1:0] 	config_file_name;

   integer 			fd_e; // egress file descriptor



   // Stuff used for CRCs
   reg [31:0] 			crc_table [0:255];

   always @(rgmii_rx_d) my_rgmii_rx_d = rgmii_rx_d;

   always @(link_speed)
     case (link_speed)
       2'b00 : inter_packet_gap = INTER_PKT_GAP_10;
       2'b01 : inter_packet_gap = INTER_PKT_GAP_100;
       2'b11 : begin
	  $display($time, " %m: ERROR link speed 10Gbps not supported.");
	  $finish;
       end
       default: inter_packet_gap = INTER_PKT_GAP_1000;
     endcase // case(link_speed)



   initial
     begin
	rgmii_rx_d = 4'h0;
	rgmii_rx_ctl = 0;
	gen_crc_table;
	finish_time = 0;
	last_activity = 0;
	tx_count = 0;
	rx_count = 0;

	// get info such as finish time from the config.txt file
	read_configuration;
	gen_crc_table;

	#1 initialize_ingress;
	initialize_egress;

	$display("%t %m Info: Waiting for initial configuration to complete.",
		 $time);

	wait (host32_is_active == 1);  // allow for reset

	$display("%t %m Info: Forking ingess, egress and finish jobs.",
		 $time);
	fork
	   handle_ingress;
	   handle_egress;
	   handle_finish;
	join

     end

/////////////////////////////////////////////////////////////

task handle_ingress;

  integer packet_index;       // pointer to next word in ingress memory
  integer words, i;
  reg [31:0] len, tmp, crc;
  time time2send;

begin

   packet_index = 0;

   // send while there are any packets left to send!
   while ((packet_index < `INGRESS_MAX_WORD) && (ingress_file[packet_index] !== 32'hxxxxxxxx))
     begin
	// get next packet and put in rx_packet_buffer
	len = ingress_file[packet_index];

	// time2send is EARLIEST we can send this packet.
	time2send = {ingress_file[packet_index+2],ingress_file[packet_index+3]};

	if (time2send > $time) begin
	   $display("%t %m Info: Waiting until time %t to send packet (length %0d)",
		    $time, time2send, len);

	   #(time2send - $time);
	end

	$display("%t %m Sending next ingress packet (len %0d) to NF2.", $time, len);

	// Build the packet in rx_packet_buffer.
	packet_index = packet_index + 4;	//now points at DA
	words = ((len-1)>>2)+1;                 // number of 32 bit words in pkt
	i = 0;                                  // index into rx_packet_buffer
	while (words) begin
	   tmp = ingress_file[packet_index];
	   rx_packet_buffer[i]   = tmp[31:24];
	   rx_packet_buffer[i+1] = tmp[23:16];
	   rx_packet_buffer[i+2] = tmp[15:8];
	   rx_packet_buffer[i+3] = tmp[7:0];
	   words = words - 1;
	   i = i + 4;
	   packet_index = packet_index + 1;
	end

	// might have gone too far so set byte index to correct position,
	i = len;

	// clear out buffer ready for CRC
	rx_packet_buffer[i]   = 8'h0;
	rx_packet_buffer[i+1] = 8'h0;
	rx_packet_buffer[i+2] = 8'h0;
	rx_packet_buffer[i+3] = 8'h0;

	crc = update_crc(32'hffffffff,len)^32'hffffffff;

	//$display("%t %m Info: CRC is %x", $time, crc);

	rx_packet_buffer[i+3] = crc[31:24];
	rx_packet_buffer[i+2] = crc[23:16];
	rx_packet_buffer[i+1] = crc[15:8];
	rx_packet_buffer[i]   = crc[7:0];

	send_rgmii_rx_pkt(len+4);  // data + CRC

	last_activity = $time;

	#inter_packet_gap;

	if (ingress_file[packet_index] !== `INGRESS_SEPARATOR) begin
	   $display($time," %m Error: expected to point at packet separator %x but saw %x",
		    `INGRESS_SEPARATOR, ingress_file[packet_index]);
	   $fflush; $finish;
	end

	packet_index = packet_index + 1;

     end
end
endtask // handle_ingress


//================================================================
// send_rgmii_rx_pkt - send a packet TO the system
//
// Packet should be in rx_packet_buffer and should have CRC already

   task send_rgmii_rx_pkt;

      input [31:0] pkt_size_w_crc;   // number of bytes to send. (incl CRC)

      integer i;

      begin

         //$display("Sending pkt len %0d (incl crc)", pkt_size_w_crc);
	 // Preamble and SFD: 7 bytes of 0x55 and then 1 byte of 0xD5
	 @(negedge rgmii_rx_clk) #1 rgmii_rx_ctl = 1;
	 rgmii_rx_d = 4'h5;
	 for (i=0 ; i<15 ; i=i+1) @(negedge rgmii_rx_clk or posedge rgmii_rx_clk) begin end
	 #1 rgmii_rx_d = 4'hd;
	 @(negedge rgmii_rx_clk) begin end

	 // send pkt data
	 for (i=0 ; i<pkt_size_w_crc ; i=i+1) begin
	    #1;
	    rgmii_rx_d = rx_packet_buffer[i][3:0];
	    @(posedge rgmii_rx_clk) begin end

	    #1
            rgmii_rx_d = rx_packet_buffer[i][7:4];
	    @(negedge rgmii_rx_clk) begin end
	 end
	 #1 rgmii_rx_ctl = 0;
	 rgmii_rx_d = 'h0;

      end
   endtask // send_rgmii_rx_pkt




////////////////////////////////////////////////////////////
// Deal with egress packets FROM the system

   task handle_egress;

      reg [7:0] data;
      integer   i;
      reg       seeing_data;  // as opposed to preamble

      begin
	 while (1)

	   begin

	      // Wait until we see Transmit Enable go active
              `ifdef RUNNING_ISIM
                 while (rgmii_tx_ctl != 1'b1) begin
                    #1;
                 end
              `else
	         wait (rgmii_tx_ctl == 1'b1);
              `endif

	      seeing_data = 0;
	      i = 0;

	      //$display($time," %m transmit packet started in the serial lines");
	      while (rgmii_tx_ctl)
		begin
		   @(posedge rgmii_tx_clk or negedge rgmii_tx_clk)
		      if (rgmii_tx_clk)
	                 data[3:0] <= rgmii_tx_d;
		      else
		         data[7:4] <= rgmii_tx_d;
		   #1;
		   if (!rgmii_tx_clk)
	           begin
		     if (seeing_data)
		       begin
			  if (rgmii_tx_ctl) begin
			     tx_packet_buffer[i] = data;
			     i = i + 1;
			  end
		       end
		     else begin
		        if (data == 8'hd5) seeing_data = 1;
		        else if (data != 8'h55)
			  $display("%t ERROR %m : expected preamble but saw %2x", $time,data);
		     end
		   end

		end // while (rgmii_tx_en)

	      handle_tx_packet(i);
	      last_activity = $time;

	   end
      end

endtask // handle_egress


///////////////////////////////////////////////////////////////////
// Board just transmitted a packet - we need to write it out to the file.
// Egress packet is in nibbles in tx_packet_buffer[]
// Number of nibbles is in counter.

task handle_tx_packet;

      input [31:0] byte_len;  // includes CRC
      integer i,j;
      integer byte_len_no_crc;
      reg [31:0] tmp, calc_crc,pkt_crc;


      begin

	 tx_count = tx_count + 1;

	 // We're not going to put the transmitted CRC in the packet, but tell the user what
	 // it was in case they need to know. (So put it in an XML comment)

	 pkt_crc = {tx_packet_buffer[byte_len-4],
		    tx_packet_buffer[byte_len-3],
		    tx_packet_buffer[byte_len-2],
		    tx_packet_buffer[byte_len-1]};

	 $fwrite(fd_e,"\n<!-- Time %t Packet # %0d Full length = %0d. CRC was %2x %2x %2x %2x -->\n",
		 $time, tx_count, byte_len,
		 tx_packet_buffer[byte_len-4],
		 tx_packet_buffer[byte_len-3],
		 tx_packet_buffer[byte_len-2],
		 tx_packet_buffer[byte_len-1]);


	 // Now drop the CRC
	 byte_len_no_crc = byte_len - 4;

	 // Now check that the CRC was correct
	 for (i=byte_len_no_crc; i<byte_len; i=i+1) tx_packet_buffer[i] = 'h0;

	 tmp = tx_update_crc(32'hffffffff,byte_len_no_crc)^32'hffffffff;
	 calc_crc = {tmp[7:0],tmp[15:8],tmp[23:16],tmp[31:24]};

	 if (calc_crc !== pkt_crc)
	   $display("%t %m ERROR: Observed CRC was %8x but calculated CRC was %8x",
		    $time, pkt_crc, calc_crc);

	 // OK write the packet out.
	 $fwrite(fd_e,"<PACKET Length=\"%0d\" Port=\"%0d\" Delay=\"%0d\">\n",
		 byte_len_no_crc, my_port_number, $time );

	 for (i=0;i<byte_len_no_crc;i=i+1) begin
	    $fwrite(fd_e,"%2x ", tx_packet_buffer[i]);
	    if ((i % 16 == 15)) $fwrite(fd_e,"\n");
	 end
	 if (byte_len_no_crc % 16 != 0) $fwrite(fd_e,"\n");
	 $fwrite(fd_e,"</PACKET>\n");
	 $fflush;

      end
endtask // handle_tx_packet




////////////////////////////////////////////////////////////////
// Check integrity of ingress file read
//    Format of memory data is:
//   00000040 // len = 60 (not including CRC)
//   00000000 // port= 0
//   00000000 // earliest send time MSB (ns)
//   00000001 // earliest send time LSB
//   aa000000 // packet data starting at DA
//   ...
//   24252627 // end of data
//   eeeeffff // token indicates end of packet
////////////////////////////////////////////////////////////////
task check_integrity;

      integer pkt_count, i, words;
      reg [31:0] len, port;
      time time2send;

begin
   #1 pkt_count = 0; // #1 is done so that time format is set.
   i = 0;
   while ((ingress_file[i] !== 32'hxxxxxxxx) && (ingress_file[i] !== 32'h0))
     begin

	pkt_count = pkt_count + 1;

	len = ingress_file[i];
	if (len <14) $display("%m Warning: packet length %0d is < 14", len);
	if (len >1518) $display("%m Warning: packet length %0d is > 1518", len);

	port = ingress_file[i+1];
	if (port != my_port_number)
	  $display("%m Warning: Packet Port %0d does not match my port %0d", port, my_port_number);

	time2send ={ingress_file[i+2],ingress_file[i+3]};

	//$display("pkt %0d len:%0d  port: %0d  time %t %d",
	//	 pkt_count, len, port, time2send, time2send);
	words = (len-1)/4+1;
	i=i+words+4;
	if (ingress_file[i] !== `INGRESS_SEPARATOR) begin
	   $display("%m Error : expected to see %x at word %0d but saw %x",
		    `INGRESS_SEPARATOR, i, ingress_file[i]);
	end
	i=i+1;
     end
   $display("%t %m Info: There will be %0d ingress packets.",
	    $time, pkt_count);
end
endtask // check_integrity

////////////////////////////////////////////////////////////
// Generate the table used by CRC calculations
task  gen_crc_table;
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

////////////////////////////////////////////////////////////
// CRC generation function. Invert CRC when finished.
function [31:0]  update_crc;
      input [31:0]crc;
      input [31:0] len;
      reg [31:0] c;
      integer i, n;
begin

  c = crc;
  for (n = 0; n < len; n = n + 1) begin
     i = ( c ^ rx_packet_buffer[n] ) & 8'hff;
     c = crc_table[i] ^ (c >> 8);
  end
  update_crc = c;

end
endfunction // update_crc


////////////////////////////////////////////////////////////
// CRC generation function. Invert CRC when finished.
// REPEATED HERE FOR USE ON THE TX BUFFER!!! Gee pointers would be nice....
function [31:0]  tx_update_crc;
      input [31:0] crc;
      input [31:0] len;
      reg [31:0] c;
      integer i, n;
begin

  c = crc;
  for (n = 0; n < len; n = n + 1) begin
     i = ( c ^ tx_packet_buffer[n] ) & 8'hff;
     c = crc_table[i] ^ (c >> 8);
  end
  tx_update_crc = c;

end
endfunction // tx_update_crc


////////////////////////////////////////////////////////////
// Initialize the ingress files
task initialize_ingress;
      integer i;

begin
   // Previously used sformat but this isn't supported by ISIM 10.1
   ingress_file_name = `INGRESS_FILE_FMT;
   ingress_file_name[7:0] = "0" + my_port_number;

   $display("%t %m Info: Reading ingress packet data from file %s",
	    $time, ingress_file_name);

   $readmemh(ingress_file_name, ingress_file);

   check_integrity; // of the data we just read in

   for (i=0;i<PKT_MEM_SZ;i=i+1) rx_packet_buffer[i] = 'h0;

end
endtask // initialize_ingress


////////////////////////////////////////////////////////////
// Initialize the egress files
task initialize_egress;
      integer i;

begin
   // Previously used sformat but this isn't supported by ISIM 10.1
   egress_file_name = `EGRESS_FILE_FMT;
   egress_file_name[7:0] = "0" + my_port_number;

   fd_e = $fopen(egress_file_name, "w");

   if (fd_e == 0)
     begin
	$display("Error: unable to open filename %s for writing.",egress_file_name );
	$finish;
     end

   // Write out XML header info
   $fwrite(fd_e,"<?xml version=\"1.0\" standalone=\"yes\" ?>\n");
   $fwrite(fd_e,"<!-- Egress packet data. Port %0d -->\n", my_port_number);
   $fwrite(fd_e,"<PACKET_STREAM>\n");

end
endtask // initialize_egress




///////////////////////////////////////////////////////////////
// Process a configuration file (config.txt).

  task read_configuration;
      integer fd_c, tmp;
      begin
	 #1;

	 config_file_name = `CONFIG_FILE_FMT;

	 fd_c = $fopen(config_file_name, "r");

	 if (fd_c == 0) begin
	    if (my_port_number == 1)
	      begin
		 $display("Warning: could not read file config.txt");
		 $display("Will use defaults:");
		 $display("    Finish time is %t ",`DEFAULT_FINISH_TIME );
		 $display("");
		 $display("A config.txt file should have the format:");
		 $display("FINISH=<time>");
		 $display("where time is the desired finish time in ns");
	      end
	    finish_time = `DEFAULT_FINISH_TIME;
	 end
	 else begin
	    tmp=$fscanf(fd_c,"FINISH=%d",finish_time);

	    if (my_port_number == 1)
	      begin
		 $display("Read Configuration file %s",config_file_name);
		 $display("    Finish time is %t.", finish_time);
	      end
	 end

	 $fclose(fd_c);

      end
  endtask // read_configuration




///////////////////////////////////////////////////
// Decide when to finish the simulation and clean up
// egress files.
task handle_finish;
      time t;
begin
   // First, figure out when to finish
   if (finish_time == 0) begin
      $display("%m Weird! finish_time should have been set. Will use default.");
      finish_time = `DEFAULT_FINISH_TIME ;
   end

   if (finish_time < $time) begin // Finished already!
      $display($time," Finishing immediately - maybe that's not what you wanted - if so then change config.txt to something larger");
   end
   else begin
      t = finish_time - $time;
      #t;
   end

   // OK, now it's time to finish so clean up
   $fwrite(fd_e,"\n<!-- Simulation terminating at time %0t -->\n",$time);
   $fwrite(fd_e,"</PACKET_STREAM>\n");
   $fclose(fd_e);

   // leave a bit of time for other processes to close
   #100 $display($time," Simulation has reached finish time - ending.");
   $finish;

end
endtask // handle_finish

endmodule
