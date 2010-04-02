#####################################
#
# $Id$
#
# This provides functions for use in tests of the NF_2.1_selftest system.
#
# NOTE: Many of these functions are hardware specific (e.g. LPM  and ARP table
# configuration), so beware if you use them in another system!
#
# NOTE: requires $batch and $delay and %reg to be defined in the main script.
#
# e.g.
#     use UnetRouter4Lib;
#     $delay = 0;
#     $batch = 0;
#     %reg = get_register_addresses();
#
#     # use strict AFTER the $delay, $batch and %reg are declared
#     use strict;
#     # Must add this so that global vars are visible after the 'use strict'
#     use vars qw($delay $batch %reg);
#
# To use this library in your Perl make_pkts.pl, just add the path to this
# library to your PERL5LIB environment variable, and then "use" it, as shown
# above.
#
#####################################

package NF21selftestLib   ;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw( &cpu_rxfifo_rd_pkt

	      &PCI_send_pkt
	      &PCI_send_pkt_no_length
	      &PCI_create_and_send_pkt

	      &make_IP_pkt
	      &make_RCP_pkt

	      &add_LPM_table_entry
	      &invalidate_LPM_table_entry
	      &LPM_entry_2_byte_addr

	      &add_ARP_table_entry
	      &invalidate_ARP_table_entry
	      &check_ARP_table_entry
	      &ARP_entry_2_byte_addr

	      &dotted
	      &get_register_addresses

	    );

use NF::PacketGen ('nf_PCI_read32' , 'nf_PCI_write32', 'nf_expected_packet');

use Carp;
use strict;


##############################################################################################
#
# CPU RxFIFO
#
##############################################################################################

# Get the CPU to read the specified packet from the CPU RxFIFO.
#
sub cpu_rxfifo_rd_pkt {  # src port, length, $bad, $pkt_string

  my $src_port = shift;
  die "cpu_rxfifo_rd_pkt(): src port must be in 1-4 not $src_port" unless (($src_port >0) &&($src_port<5));
  my $length = shift;
  die "cpu_rxfifo_rd_pkt(): length must be in 60-1518 not $length" unless (($length >=60) &&($length<=1518));
  my $bad = shift;
  die "cpu_rxfifo_rd_pkt(): bad must be 0 or 1 not $bad" unless (($bad ==0) or ($bad == 1));
  my $pkt = shift;

  my @pkt = split ' ',$pkt;
  die "Length param ($length) not same as actaul length of pkt data ".(@pkt+0) unless
    ($length == (@pkt+0));

  # make pkt a multiple of 4 bytes
  push @pkt,'00' while ((@pkt+0)%4 != 0);

  # First read length
  my $exp_data = ($bad << 31) | ($src_port << 16) | $length;

  nf_PCI_read32( 0, $main::batch, $main::reg{'UNET_CPU_RxFIFO_length_reg'},$exp_data);

  # now read data

  while (@pkt) {
    my $exp_data = hex(shift @pkt) & 0xff;
    $exp_data |= (hex(shift @pkt) & 0xff) << 8;
    $exp_data |= (hex(shift @pkt) & 0xff) << 16;
    $exp_data |= (hex(shift @pkt) & 0xff) << 24;
    nf_PCI_read32( 0, $main::batch, $main::reg{'UNET_CPU_RxFIFO_data_reg'},$exp_data);
    # printf "expected data was %08x\n",$exp_data;
  }

}


################################################################
#
# Send a packet via the PCI bus (CPU TXFIFO)
#
################################################################

# Send a packet via the CPU TxFIFO. Create the packet and then write the
# length field (which causes it to be sent).

sub PCI_send_pkt {
  my $port = shift;
  my $pkt = shift;   # string of hex

  die "Bad port $port : must be in 1..4" if (($port < 1) or ($port > 4));

  my @data = split ' ',$pkt;
  my $length = @data+0;
  my $word = '';
  while ((@data+0)>0) {
    my $byte = shift @data;
    $word = $byte.$word;
    if ((length($word)==8) or ((@data+0)==0)) {
      nf_PCI_write32( 0, $main::batch, $main::reg{'UNET_CPU_TxFIFO_data_reg'},hex($word));
      $word ='';
    }
  }
  $word = $length | ($port << 16);
  # printf "length $length   port $port  word 0x%x \n",$word;
  nf_PCI_write32( 0, $main::batch, $main::reg{'UNET_CPU_TxFIFO_length_reg'},$word);

}

# PCI_send_pkt_no_length: same as PCI_send_pkt except that we
# dont write the length value at the end - this lets us set up several
# packets in the TxFIFO and then write the length field of each them.

sub PCI_send_pkt_no_length {
  my $port = shift;
  my $pkt = shift;   # string of hex

  die "Bad port $port : must be in 1..4" if (($port < 1) or ($port > 4));

  my @data = split ' ',$pkt;
  my $length = @data+0;
  my $word = '';
  while ((@data+0)>0) {
    my $byte = shift @data;
    $word = $byte.$word;
    if ((length($word)==8) or ((@data+0)==0)) {
      nf_PCI_write32( 0, $main::batch, $main::reg{'UNET_CPU_TxFIFO_data_reg'},hex($word));
      $word ='';
    }
  }

}


# Create and send a packet.

sub PCI_create_and_send_pkt {
  my $port = shift;
  my $length = shift;

  die "Bad port $port : must be in 1..4" if (($port < 1) or ($port > 4));
  die "Bad length $length : must be in 60..1514" if (($length < 60) or ($length > 1514));


  my $pkt = NF::PDU->new($length);
  my @tmp = (1..$length);
  for (@tmp) { $_ %= 256 }
  $pkt->set_bytes(@tmp);

  PCI_send_pkt(2, $pkt->bytes());

  nf_expected_packet(2,  $length,  $pkt->bytes());

}






################################################################
#
# IP packet stuff
#
################################################################

# Build an IP packet with the given arguments
# Data is just sequential numbers.

sub make_RCP_pkt { # len, DA, SA, TTL, DST_IP, SRC_IP, @RCP

  my ($len, $DA, $SA, $TTL, $DST_IP, $SRC_IP, @RCP) = @_;
  my ($fwd, $rev, $rtt, $proto) = @RCP;

  my $RCP_hdr = NF::RCP_hdr->new(	fwd => $fwd,
					rev => $rev,
					rtt => $rtt,
					proto => $proto
				);
  my $MAC_hdr = NF::Ethernet_hdr->new(DA => $DA,
                                       SA => $SA,
                                       Ethertype => 0x800
                                      );
  my $IP_hdr = NF::IP_hdr->new(ttl => $TTL,
                                src_ip => $SRC_IP,
                                dst_ip => $DST_IP,
				proto => 0xfe
                               );
  $IP_hdr->checksum(0);  # make sure its zero before we calculate it.
  $IP_hdr->checksum($IP_hdr->calc_checksum);

  # create packet filling.... (IP PDU)
  my $PDU = NF::PDU->new($len - $MAC_hdr->length_in_bytes() - $IP_hdr->length_in_bytes() - $RCP_hdr->length_in_bytes());
  my $start_val = $MAC_hdr->length_in_bytes() + $IP_hdr->length_in_bytes() + $RCP_hdr->length_in_bytes()+1;
  my @data = ($start_val..$len);
  for (@data) {$_ %= 100}
  $PDU->set_bytes(@data);

  # Return complete packet data
  $MAC_hdr->bytes().$IP_hdr->bytes().$RCP_hdr->bytes().$PDU->bytes();
}

sub make_IP_pkt { # len, DA, SA, TTL, DST_IP, SRC_IP

  my ($len, $DA, $SA, $TTL, $DST_IP, $SRC_IP) = @_;

  my $MAC_hdr = NF::Ethernet_hdr->new(DA => $DA,
                                       SA => $SA,
                                       Ethertype => 0x800
                                      );
  my $IP_hdr = NF::IP_hdr->new(ttl => $TTL,
                                src_ip => $SRC_IP,
                                dst_ip => $DST_IP
                               );
  $IP_hdr->checksum(0);  # make sure its zero before we calculate it.
  $IP_hdr->checksum($IP_hdr->calc_checksum);

  # create packet filling.... (IP PDU)
  my $PDU = NF::PDU->new($len - $MAC_hdr->length_in_bytes() - $IP_hdr->length_in_bytes() );
  my $start_val = $MAC_hdr->length_in_bytes() + $IP_hdr->length_in_bytes()+1;
  my @data = ($start_val..$len);
  for (@data) {$_ %= 100}
  $PDU->set_bytes(@data);

  # Return complete packet data
  $MAC_hdr->bytes().$IP_hdr->bytes().$PDU->bytes();
}


################################################################
#
# LPM table stuff
#
################################################################

sub add_LPM_table_entry {  # index, IP_subnet, MASK, NEXT_hop_IP, port
  my $index = shift;
  my $IP = shift;
  my $mask = shift;
  my $next_IP = shift;
  my $next_port = shift;

  die "Bad data" if (($index < 0) or ($index > 15) or ($next_port < 1) or ($next_port > 4));

  if ($IP =~ m/(\d+)\./) { $IP = dotted($IP) }
  if ($mask =~ m/(\d+)\./) { $mask = dotted($mask) }
  if ($next_IP =~ m/(\d+)\./) { $next_IP = dotted($next_IP) }

  my $addr = LPM_entry_2_byte_addr($index, 0);
  nf_PCI_write32( $main::delay, $main::batch, $addr, $IP);

  $addr = LPM_entry_2_byte_addr($index, 1);
  nf_PCI_write32( $main::delay, $main::batch, $addr, $mask);

  $addr = LPM_entry_2_byte_addr($index, 2);
  nf_PCI_write32( $main::delay, $main::batch, $addr, $next_IP);

  $addr = LPM_entry_2_byte_addr($index, 3);
  nf_PCI_write32( $main::delay, $main::batch, $addr, (0x80000000 | $next_port));
}


sub invalidate_LPM_table_entry { #table index to invalidate
  my $index = shift;
  die "Bad data" if (($index < 0) or ($index > 15));
  my $addr = LPM_entry_2_byte_addr($index, 3);
  nf_PCI_write32( $main::delay, $main::batch, $addr, 0);
}

sub LPM_entry_2_byte_addr {  # args: entry (0..15),  tbl (0..3).  returns byte addr
  # tbl 0 = IP subnet for this route
  # tbl 1 = mask
  # tbl 2 = ip address of next hop
  # tbl 3 = valid (1 bit) and next hop interface/port (3 bits)
  my $entry = shift;
  my $tbl = shift;
  die "Bad entry $entry" if (($entry < 0) or ($entry > 15));
  die "Bad tbl $tbl" if (($tbl < 0) or ($tbl > 3));

  return (0x401000 + ($entry << 4) + ($tbl << 2));
}



################################################################
#
# ARP stuff
#
################################################################
sub add_ARP_table_entry {  # index, IP, MAC,
  my $index = shift;
  my $IP = shift;
  my $mac = shift;


  die "add_ARP_table_entry: Bad data" if (($index < 0) or ($index > 15));

  if ($IP =~ m/(\d+)\./) { $IP = dotted($IP) }

  my @MAC = NF::PDU::get_MAC_address($mac);

  my $mac_hi = $MAC[0]<<24 | $MAC[1]<<16 | $MAC[2]<<8 | $MAC[3];
  my $mac_lo = $MAC[4]<<24 | $MAC[5]<<16 | 1; # the plus 1 is for the valid bit

  my $addr = ARP_entry_2_byte_addr($index, 0);
  nf_PCI_write32( $main::delay, $main::batch, $addr, $IP);

  $addr = ARP_entry_2_byte_addr($index, 1);
  nf_PCI_write32( $main::delay, $main::batch, $addr, $mac_hi);

  $addr = ARP_entry_2_byte_addr($index, 2);
  nf_PCI_write32( $main::delay, $main::batch, $addr, $mac_lo);

}

sub invalidate_ARP_table_entry { #table index to invalidate
  my $index = shift;
  die "Bad data" if (($index < 0) or ($index > 15));
  my $addr = ARP_entry_2_byte_addr($index, 2);
  nf_PCI_write32( $main::delay, $main::batch, $addr, 0);
}

sub check_ARP_table_entry {  # index, IP, MAC,
  my $index = shift;
  my $IP = shift;
  my $mac = shift;

  die "check_ARP_table_entry: Bad data" if (($index < 0) or ($index > 15));

  if ($IP =~ m/(\d+)\./) { $IP = dotted($IP) }

  my @MAC = NF::PDU::get_MAC_address($mac);

  my $mac_hi = $MAC[0]<<24 | $MAC[1]<<16 | $MAC[2]<<8 | $MAC[3];
  my $mac_lo = $MAC[4]<<24 | $MAC[5]<<16 | 1; # the plus 1 is for the valid bit

  my $addr = ARP_entry_2_byte_addr($index, 0);
  nf_PCI_read32( $main::delay, $main::batch, $addr, $IP);

  $addr = ARP_entry_2_byte_addr($index, 1);
  nf_PCI_read32( $main::delay, $main::batch, $addr, $mac_hi);

  $addr = ARP_entry_2_byte_addr($index, 2);
  nf_PCI_read32( $main::delay, $main::batch, $addr, $mac_lo);

}

sub ARP_entry_2_byte_addr {  # args: entry (0..15),  tbl (0..2).  returns byte addr
  # tbl 0 = IP
  # tbl 1 = MAC hi
  # tbl 2 = MAC lo (31:16) and valid (bit 0)
  my $entry = shift;
  my $tbl = shift;
  die "Bad entry $entry" if (($entry < 0) or ($entry > 15));
  die "Bad tbl $tbl" if (($tbl < 0) or ($tbl > 2));

  return (0x402000 + ($entry << 4) + ($tbl << 2));
}


################################################################
#
# Misc routines
#
################################################################

sub dotted { # convert dotted decimal to 32 bit integer
  my $dot = shift;
  if ($dot =~ m/^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/) {
    my $newip = $1<<24 | $2<<16 | $3<<8 | $4;
    return $newip
  }
  else {
    die "Bad format - expected dotted decimal: $dot"
  }
}

################################################################


# GO and parse the src/unet_defines.v file to find the address of
# registers and other constants.
#
# This lets the perl script use the Verilog symbol names instead of duplicating
# a load of constants.
#
# e.g.
#  `define UNET_IP_ADDR_port1_reg  20'h080
# would map UNET_IP_ADDR_port1_reg to address 0x40080
#
#  `define UNET_User_Send_Packet_sm 32'h1
# would map UNET_User_Send_Packet_sm to 0x1

sub get_register_addresses {

  my $filename = $ENV{'NF_DESIGN_DIR'}.'/src/unet_defines.v';

  my %reg = ();

  open F,"<$filename" or
    die "ERROR: register_addresses(): Unable to read file $filename to extract reg addresses";

  while (<F>) {

    if (/`define\s+(\S+)\s+20\'h\s*([0-9a-fA-F]+)/) {
      my $addr = 0x400000 | hex($2);
      # printf "map $1 -> 0x%06x\n",$addr;
      $reg{$1} = $addr;
      next
    }
    if (/`define\s+(\S+)\s+\d+\'h\s*([0-9a-fA-F]+)/) {
      my $addr = hex($2);
      # printf "map $1 -> 0x%06x\n",$addr;
      $reg{$1} = $addr;
      next
    }
  }
  close F;

  return %reg;

}



1;

