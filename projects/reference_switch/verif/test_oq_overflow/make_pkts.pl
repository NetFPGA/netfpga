#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
#

use NF::PacketGen;
use NF::PacketLib;

use SimLib;
use POSIX qw(ceil floor);

use reg_defines_reference_switch;

$delay = 8000;
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );
nf_add_port_rule(1, 'UNORDERED');
nf_add_port_rule(2, 'UNORDERED');
nf_add_port_rule(3, 'UNORDERED');
nf_add_port_rule(4, 'UNORDERED');

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

my $i;
my $lastTime = 1300000;

my $word_size = 8.0;
my $overhead_per_pkt = 3*$word_size;

my $num_words_to_1 = 0;
my $num_bytes_to_1 = 0;
my $num_pkts_to_1 = 0;
my $num_pkts_from_1 = 0;
my $num_words_from_1 = 0;
my $num_bytes_from_1 = 0;
my $num_pkts_brdcst_from_1 = 0;
my $num_words_brdcst_from_1 = 0;
my $num_bytes_brdcst_from_1 = 0;

my $num_words_to_2 = 0;
my $num_bytes_to_2 = 0;
my $num_pkts_to_2 = 0;
my $num_pkts_from_2 = 0;
my $num_words_from_2 = 0;
my $num_bytes_from_2 = 0;
my $num_pkts_brdcst_from_2 = 0;
my $num_words_brdcst_from_2 = 0;
my $num_bytes_brdcst_from_2 = 0;

my $num_words_to_3 = 0;
my $num_bytes_to_3 = 0;
my $num_pkts_to_3 = 0;
my $num_pkts_from_3 = 0;
my $num_words_from_3 = 0;
my $num_bytes_from_3 = 0;
my $num_pkts_brdcst_from_3 = 0;
my $num_words_brdcst_from_3 = 0;
my $num_bytes_brdcst_from_3 = 0;

my $num_words_to_4 = 0;
my $num_bytes_to_4 = 0;
my $num_pkts_to_4 = 0;
my $num_pkts_from_4 = 0;
my $num_words_from_4 = 0;
my $num_bytes_from_4 = 0;
my $num_pkts_brdcst_from_4 = 0;
my $num_words_brdcst_from_4 = 0;
my $num_bytes_brdcst_from_4 = 0;

my $num_hits = 0;
my $num_misses = 0;

####################################################################
# change the size of the output queues to test wrap-around and drops

nf_PCI_write32('@5us', $batch, OQ_QUEUE_2_ADDR_HI_REG(), (0x20000+2048)); # 8 pkts
nf_PCI_write32('@5us', $batch, OQ_QUEUE_2_CTRL_REG(), 0x03); # Re-initalize and enable queue

####################################################################
# Create a new packet

my $MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:02',
                                     SA => '00:ca:fe:00:00:01',
                                     Ethertype => 0x800
);

# min sized pkt
my $length = 60;

# Make rest of packet (the data)
my $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

my $start_val = $MAC_hdr->length_in_bytes()+1;

$PDU->set_bytes(($start_val..$length));

# Build complete packet data
my $pkt = $MAC_hdr->bytes().$PDU->bytes();

print "Packet is:\n$pkt\n";

nf_packet_in(1, $length,  $delay, $batch,  $pkt);

# We don't know what the addr is so it should go everywhere except the source
nf_expected_packet(2, $length,             $pkt);
nf_expected_packet(3, $length,             $pkt);
nf_expected_packet(4, $length,             $pkt);


$num_words_from_1 = $num_words_from_1 + int(ceil($length/$word_size));
$num_bytes_from_1 = $num_bytes_from_1 + $length;
$num_pkts_from_1  = $num_pkts_from_1  + 1;

$num_words_to_2   = $num_words_to_2   + int(ceil($length/$word_size));
$num_bytes_to_2   = $num_bytes_to_2   + $length;
$num_pkts_to_2    = $num_pkts_to_2    + 1;

$num_words_to_3   = $num_words_to_3   + int(ceil($length/$word_size));
$num_bytes_to_3   = $num_bytes_to_3   + $length;
$num_pkts_to_3    = $num_pkts_to_3    + 1;

$num_words_to_4   = $num_words_to_4   + int(ceil($length/$word_size));
$num_bytes_to_4   = $num_bytes_to_4   + $length;
$num_pkts_to_4    = $num_pkts_to_4    + 1;

$num_words_brdcst_from_1   = $num_words_brdcst_from_1   + int(ceil($length/$word_size));
$num_bytes_brdcst_from_1   = $num_bytes_brdcst_from_1   + $length;
$num_pkts_brdcst_from_1    = $num_pkts_brdcst_from_1    + 1;

$num_misses       = $num_misses       + 1;

$delay = $delay + 3000;

#####################################################################
# Create another

$MAC_hdr = NF::Ethernet_hdr->new(DA => 'FF:FF:FF:FF:FF:FF',
                                     SA => '00:ca:fe:00:00:02',
                                     Ethertype => 0x800
);

$length = 60;

# Make rest of packet (the data)
$PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

$start_val = $MAC_hdr->length_in_bytes()+1;

$PDU->set_bytes(($start_val..$length));

# Build complete packet data
$pkt = $MAC_hdr->bytes().$PDU->bytes();

print "Packet is:\n$pkt\n";

nf_packet_in(2, $length,  $delay, $batch,  $pkt);

# It's a broadcast so should go everywhere except source.
nf_expected_packet(1, $length,             $pkt);
nf_expected_packet(3, $length,             $pkt);
nf_expected_packet(4, $length,             $pkt);

$num_words_to_1   = $num_words_to_1   + int(ceil($length/$word_size));
$num_bytes_to_1   = $num_bytes_to_1   + $length;
$num_pkts_to_1    = $num_pkts_to_1    + 1;

$num_words_from_2 = $num_words_from_2 + int(ceil($length/$word_size));
$num_bytes_from_2 = $num_bytes_from_2 + $length;
$num_pkts_from_2  = $num_pkts_from_2  + 1;

$num_words_to_3   = $num_words_to_3   + int(ceil($length/$word_size));
$num_bytes_to_3   = $num_bytes_to_3   + $length;
$num_pkts_to_3    = $num_pkts_to_3    + 1;

$num_words_to_4   = $num_words_to_4   + int(ceil($length/$word_size));
$num_bytes_to_4   = $num_bytes_to_4   + $length;
$num_pkts_to_4    = $num_pkts_to_4    + 1;

$num_words_brdcst_from_2   = $num_words_brdcst_from_2   + int(ceil($length/$word_size));
$num_bytes_brdcst_from_2   = $num_bytes_brdcst_from_2   + $length;
$num_pkts_brdcst_from_2    = $num_pkts_brdcst_from_2    + 1;

$num_hits         = $num_hits         + 1;

$delay = $delay + 3000;

#####################################################################
# Create a rd pkt. Unicast from 3 -> 1 (which was just learned)

$MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:01',
                                  SA => '00:ca:fe:00:00:03',
                                  Ethertype => 0x800
);

$length = 100;

# Make rest of packet (the data)
$PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

$start_val = $MAC_hdr->length_in_bytes()+1;

$PDU->set_bytes(($start_val..$length));

# Build complete packet data
$pkt = $MAC_hdr->bytes().$PDU->bytes();

print "Packet is:\n$pkt\n";

nf_packet_in(3, $length,  $delay, $batch,  $pkt);

# It's not broadcast so should go to destination port.
nf_expected_packet(1, $length,             $pkt);

$num_words_to_1   = $num_words_to_1   + int(ceil($length/$word_size));
$num_bytes_to_1   = $num_bytes_to_1   + $length;
$num_pkts_to_1    = $num_pkts_to_1    + 1;

$num_words_from_3 = $num_words_from_3 + int(ceil($length/$word_size));
$num_bytes_from_3 = $num_bytes_from_3 + $length;
$num_pkts_from_3  = $num_pkts_from_3  + 1;

$num_hits         = $num_hits         + 1;

$delay = $delay + 3000;

#####################################################################
# Create a rd pkt. Unicast from 4 -> 2 (which was just learned)

$MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:02',
                                  SA => '00:ca:fe:00:00:04',
                                  Ethertype => 0x800
);

$length = 100;

# Make rest of packet (the data)
$PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

$start_val = $MAC_hdr->length_in_bytes()+1;

$PDU->set_bytes(($start_val..$length));

# Build complete packet data
$pkt = $MAC_hdr->bytes().$PDU->bytes();

print "Packet is:\n$pkt\n";

nf_packet_in(4, $length,  $delay, $batch,  $pkt);

# It's not broadcast so should go to destination port.
nf_expected_packet(2, $length,             $pkt);

$num_words_to_2   = $num_words_to_2   + int(ceil($length/$word_size));
$num_bytes_to_2   = $num_bytes_to_2   + $length;
$num_pkts_to_2    = $num_pkts_to_2    + 1;

$num_words_from_4 = $num_words_from_4 + int(ceil($length/$word_size));
$num_bytes_from_4 = $num_bytes_from_4 + $length;
$num_pkts_from_4  = $num_pkts_from_4  + 1;

$num_hits         = $num_hits         + 1;

$delay = $delay + 3000;

#####################################################################
# let's blast pkts from two ports to one port to overflow it

$length = 100;
my $range = 196;
my $minimum = 60;

for($i=0; $i<400; $i=$i+1){

  $MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:02',
				    SA => '00:ca:fe:00:00:01',
				    Ethertype => 0x1000+$i
				   );
  $length = int(rand($range)) + $minimum;
# $length = (60+$i)%256;

  # Make rest of packet (the data)
  $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

  $start_val = $MAC_hdr->length_in_bytes()+1;

  $PDU->set_bytes(($start_val..$length));

  # Build complete packet data
  $pkt = $MAC_hdr->bytes().$PDU->bytes();

#  print "Packet is:\n$pkt\n";

  nf_packet_in(1, $length,  $delay, $batch,  $pkt);

  # It's not broadcast so should go to destination port.
  nf_optional_packet(2, $length,             $pkt);

  $num_words_to_2   = $num_words_to_2   + int(ceil($length/$word_size));
  $num_bytes_to_2   = $num_bytes_to_2   + $length;
  $num_pkts_to_2    = $num_pkts_to_2    + 1;

  $num_words_from_1 = $num_words_from_1 + int(ceil($length/$word_size));
  $num_bytes_from_1 = $num_bytes_from_1 + $length;
  $num_pkts_from_1  = $num_pkts_from_1  + 1;

  $num_hits         = $num_hits         + 1;

  $MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:03',
				    SA => '00:ca:fe:00:00:02',
				    Ethertype => 0x2000+$i
				   );

  $length = int(rand($range)) + $minimum;
#  $length = (60+$i)%256;

  # Make rest of packet (the data)
  $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

  $start_val = $MAC_hdr->length_in_bytes()+1;

  $PDU->set_bytes(($start_val..$length));

  # Build complete packet data
  $pkt = $MAC_hdr->bytes().$PDU->bytes();

#  print "Packet is:\n$pkt\n";

  nf_packet_in(2, $length,  $delay, $batch,  $pkt);

  # It's not broadcast so should go to destination port.
  nf_expected_packet(3, $length,             $pkt);

  $num_words_to_3   = $num_words_to_3   + int(ceil($length/$word_size));
  $num_bytes_to_3   = $num_bytes_to_3   + $length;
  $num_pkts_to_3    = $num_pkts_to_3    + 1;

  $num_words_from_2 = $num_words_from_2 + int(ceil($length/$word_size));
  $num_bytes_from_2 = $num_bytes_from_2 + $length;
  $num_pkts_from_2  = $num_pkts_from_2  + 1;

  $num_hits         = $num_hits         + 1;

  $MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:02',
				    SA => '00:ca:fe:00:00:03',
				    Ethertype => 0x3000+$i
				   );

  $length = int(rand($range)) + $minimum;
# $length = (60+$i)%256;

  # Make rest of packet (the data)
  $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

  $start_val = $MAC_hdr->length_in_bytes()+1;

  $PDU->set_bytes(($start_val..$length));

  # Build complete packet data
  $pkt = $MAC_hdr->bytes().$PDU->bytes();

#  print "Packet is:\n$pkt\n";

  nf_packet_in(3, $length,  $delay, $batch,  $pkt);

  # It's not broadcast so should go to destination port.
  nf_optional_packet(2, $length,             $pkt);

  $num_words_to_2   = $num_words_to_2   + int(ceil($length/$word_size));
  $num_bytes_to_2   = $num_bytes_to_2   + $length;
  $num_pkts_to_2    = $num_pkts_to_2    + 1;

  $num_words_from_3 = $num_words_from_3 + int(ceil($length/$word_size));
  $num_bytes_from_3 = $num_bytes_from_3 + $length;
  $num_pkts_from_3  = $num_pkts_from_3  + 1;

  $num_hits         = $num_hits         + 1;

  $MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:02',
				    SA => '00:ca:fe:00:00:04',
				    Ethertype => 0x4000+$i
				   );
  $length = int(rand($range)) + $minimum;
# $length = (60+$i)%256;

  # Make rest of packet (the data)
  $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

  $start_val = $MAC_hdr->length_in_bytes()+1;

  $PDU->set_bytes(($start_val..$length));

  # Build complete packet data
  $pkt = $MAC_hdr->bytes().$PDU->bytes();

#  print "Packet is:\n$pkt\n";

  nf_packet_in(4, $length,  $delay, $batch,  $pkt);

  # It's not broadcast so should go to destination port.
  nf_optional_packet(2, $length,             $pkt);

  $num_words_to_2   = $num_words_to_2   + int(ceil($length/$word_size));
  $num_bytes_to_2   = $num_bytes_to_2   + $length;
  $num_pkts_to_2    = $num_pkts_to_2    + 1;

  $num_words_from_4 = $num_words_from_4 + int(ceil($length/$word_size));
  $num_bytes_from_4 = $num_bytes_from_4 + $length;
  $num_pkts_from_4  = $num_pkts_from_4  + 1;

  $num_hits         = $num_hits         + 1;

  $delay = 0;

  print "Done iteration $i \n";
}

# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


