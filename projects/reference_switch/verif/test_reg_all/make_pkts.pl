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
my $lastTime = 2000000;

my $word_size = 8.0;
my $overhead_per_pkt = 1*$word_size;

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
# let's blast pkts from two ports to one ports without filling it

$length = 100;
my $range = 196;
my $minimum = 60;

for($i=0; $i<100; $i=$i+1){

  $MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:02',
				    SA => '00:ca:fe:00:00:01',
				    Ethertype => 0x1000+$i
				   );
  $length = int(rand($range)) + $minimum;
#  $length = (60+$i)%256;

  # Make rest of packet (the data)
  $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

  $start_val = $MAC_hdr->length_in_bytes()+1;

  $PDU->set_bytes(($start_val..$length));

  # Build complete packet data
  $pkt = $MAC_hdr->bytes().$PDU->bytes();

  nf_packet_in(1, $length,  $delay, $batch,  $pkt);

  # It's not broadcast so should go to destination port.
  nf_expected_packet(2, $length,             $pkt);

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
#  $length = (60+$i)%256;

  # Make rest of packet (the data)
  $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

  $start_val = $MAC_hdr->length_in_bytes()+1;

  $PDU->set_bytes(($start_val..$length));

  # Build complete packet data
  $pkt = $MAC_hdr->bytes().$PDU->bytes();

  nf_packet_in(3, $length,  $delay, $batch,  $pkt);

  # It's not broadcast so should go to destination port.
  nf_expected_packet(2, $length,             $pkt);

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
#  $length = (60+$i)%256;

  # Make rest of packet (the data)
  $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

  $start_val = $MAC_hdr->length_in_bytes()+1;

  $PDU->set_bytes(($start_val..$length));

  # Build complete packet data
  $pkt = $MAC_hdr->bytes().$PDU->bytes();

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

  $delay = 0;

}

$delay = 50000;

#####################################################################
# let's send more pkts from everone to everyone

$length = 100;
$range = 196;
$minimum = 60;

for($i=0; $i<600; $i=$i+1){

  $MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:02',
				    SA => '00:ca:fe:00:00:01',
				    Ethertype => 0x800
				   );
  $length = int(rand($range)) + $minimum;
#  $length = (60+$i)%256;

  # Make rest of packet (the data)
  $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

  $start_val = $MAC_hdr->length_in_bytes()+1;

  $PDU->set_bytes(($start_val..$length));

  # Build complete packet data
  $pkt = $MAC_hdr->bytes().$PDU->bytes();

  nf_packet_in(1, $length,  $delay, $batch,  $pkt);

  # It's not broadcast so should go to destination port.
  nf_expected_packet(2, $length,             $pkt);

  $num_words_to_2   = $num_words_to_2   + int(ceil($length/$word_size));
  $num_bytes_to_2   = $num_bytes_to_2   + $length;
  $num_pkts_to_2    = $num_pkts_to_2    + 1;

  $num_words_from_1 = $num_words_from_1 + int(ceil($length/$word_size));
  $num_bytes_from_1 = $num_bytes_from_1 + $length;
  $num_pkts_from_1  = $num_pkts_from_1  + 1;

  $num_hits         = $num_hits         + 1;

  $MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:03',
				    SA => '00:ca:fe:00:00:02',
				    Ethertype => 0x800
				   );

  $length = int(rand($range)) + $minimum;
#  $length = (60+$i)%256;

  # Make rest of packet (the data)
  $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

  $start_val = $MAC_hdr->length_in_bytes()+1;

  $PDU->set_bytes(($start_val..$length));

  # Build complete packet data
  $pkt = $MAC_hdr->bytes().$PDU->bytes();

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

  $MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:04',
				    SA => '00:ca:fe:00:00:03',
				    Ethertype => 0x800
				   );

  $length = int(rand($range)) + $minimum;
#  $length = (60+$i)%256;

  # Make rest of packet (the data)
  $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

  $start_val = $MAC_hdr->length_in_bytes()+1;

  $PDU->set_bytes(($start_val..$length));

  # Build complete packet data
  $pkt = $MAC_hdr->bytes().$PDU->bytes();

  nf_packet_in(3, $length,  $delay, $batch,  $pkt);

  # It's not broadcast so should go to destination port.
  nf_expected_packet(4, $length,             $pkt);

  $num_words_to_4   = $num_words_to_4   + int(ceil($length/$word_size));
  $num_bytes_to_4   = $num_bytes_to_4   + $length;
  $num_pkts_to_4    = $num_pkts_to_4    + 1;

  $num_words_from_3 = $num_words_from_3 + int(ceil($length/$word_size));
  $num_bytes_from_3 = $num_bytes_from_3 + $length;
  $num_pkts_from_3  = $num_pkts_from_3  + 1;

  $num_hits         = $num_hits         + 1;

  $MAC_hdr = NF::Ethernet_hdr->new(DA => '00:ca:fe:00:00:01',
				    SA => '00:ca:fe:00:00:04',
				    Ethertype => 0x800
				   );

  $length = int(rand($range)) + $minimum;
#  $length = (60+$i)%256;

  # Make rest of packet (the data)
  $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

  $start_val = $MAC_hdr->length_in_bytes()+1;

  $PDU->set_bytes(($start_val..$length));

  # Build complete packet data
  $pkt = $MAC_hdr->bytes().$PDU->bytes();

  nf_packet_in(4, $length,  $delay, $batch,  $pkt);

  # It's not broadcast so should go to destination port.
  nf_expected_packet(1, $length,             $pkt);

  $num_words_to_1   = $num_words_to_1   + int(ceil($length/$word_size));
  $num_bytes_to_1   = $num_bytes_to_1   + $length;
  $num_pkts_to_1    = $num_pkts_to_1    + 1;

  $num_words_from_4 = $num_words_from_4 + int(ceil($length/$word_size));
  $num_bytes_from_4 = $num_bytes_from_4 + $length;
  $num_pkts_from_4  = $num_pkts_from_4  + 1;

  $num_hits         = $num_hits         + 1;

  $delay = 0;

}



$delay = $delay + 1000;

##############################################################################
# Check the registers

print "num_words_to_1:      $num_words_to_1\n";
print "num_bytes_to_1:      $num_bytes_to_1\n";
print "num_pkts_to_1:       $num_pkts_to_1\n";
print "num_pkts_from_1:     $num_pkts_from_1\n";
print "num_words_from_1:    $num_words_from_1\n";
print "num_bytes_from_1:    $num_bytes_from_1\n";

print "num_words_to_2:      $num_words_to_2\n";
print "num_bytes_to_2:      $num_bytes_to_2\n";
print "num_pkts_to_2:       $num_pkts_to_2\n";
print "num_pkts_from_2:     $num_pkts_from_2\n";
print "num_words_from_2:    $num_words_from_2\n";
print "num_bytes_from_2:    $num_bytes_from_2\n";

print "num_words_to_3:      $num_words_to_3\n";
print "num_bytes_to_3:      $num_bytes_to_3\n";
print "num_pkts_to_3:       $num_pkts_to_3\n";
print "num_pkts_from_3:     $num_pkts_from_3\n";
print "num_words_from_3:    $num_words_from_3\n";
print "num_bytes_from_3:    $num_bytes_from_3\n";

print "num_words_to_4:      $num_words_to_4\n";
print "num_bytes_to_4:      $num_bytes_to_4\n";
print "num_pkts_to_4:       $num_pkts_to_4\n";
print "num_pkts_from_4:     $num_pkts_from_4\n";
print "num_words_from_4:    $num_words_from_4\n";
print "num_bytes_from_4:    $num_bytes_from_4\n"  ;

print "num_words_brdcst_from_1: $num_words_brdcst_from_1\n";
print "num_bytes_brdcst_from_1: $num_bytes_brdcst_from_1\n";
print "num_pkts_brdcst_from_1:  $num_pkts_brdcst_from_1\n";

print "num_words_brdcst_from_2: $num_words_brdcst_from_2\n";
print "num_bytes_brdcst_from_2: $num_bytes_brdcst_from_2\n";
print "num_pkts_brdcst_from_2:  $num_pkts_brdcst_from_2\n";

print "num_words_brdcst_from_3: $num_words_brdcst_from_3\n";
print "num_bytes_brdcst_from_3: $num_bytes_brdcst_from_3\n";
print "num_pkts_brdcst_from_3:  $num_pkts_brdcst_from_3\n";

print "num_words_brdcst_from_4: $num_words_brdcst_from_4\n";
print "num_bytes_brdcst_from_4: $num_bytes_brdcst_from_4\n";
print "num_pkts_brdcst_from_4:  $num_pkts_brdcst_from_4\n";

print "num_hits:            $num_hits\n";
print "num_misses:          $num_misses\n";

my $batch = 0;
nf_PCI_read32($lastTime, $batch, MAC_GRP_0_CONTROL_REG(), 0x0);
nf_PCI_read32(0    , $batch, MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG(), $num_pkts_from_1);
nf_PCI_read32(0    , $batch, MAC_GRP_0_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_0_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_0_RX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_from_1);
nf_PCI_read32(0    , $batch, MAC_GRP_0_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG(), $num_pkts_to_1);
nf_PCI_read32(0    , $batch, MAC_GRP_0_TX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_to_1);
nf_PCI_read32(0    , $batch, MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG(), $num_bytes_from_1);
nf_PCI_read32(0    , $batch, MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG(), $num_bytes_to_1);
# check writing
nf_PCI_write32(0   , $batch, MAC_GRP_0_RX_QUEUE_NUM_WORDS_PUSHED_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_0_RX_QUEUE_NUM_WORDS_PUSHED_REG(), 0);
nf_PCI_write32(0   , $batch, MAC_GRP_0_RX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_from_1);
nf_PCI_read32(0    , $batch, MAC_GRP_0_RX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_from_1);

nf_PCI_read32(0    , $batch, MAC_GRP_1_CONTROL_REG(), 0x0);
nf_PCI_read32(0    , $batch, MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED_REG(), $num_pkts_from_2);
nf_PCI_read32(0    , $batch, MAC_GRP_1_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_1_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_1_RX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_from_2);
nf_PCI_read32(0    , $batch, MAC_GRP_1_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG(), $num_pkts_to_2);
nf_PCI_read32(0    , $batch, MAC_GRP_1_TX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_to_2);
nf_PCI_read32(0    , $batch, MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED_REG(), $num_bytes_to_2);
nf_PCI_read32(0    , $batch, MAC_GRP_1_RX_QUEUE_NUM_BYTES_PUSHED_REG(), $num_bytes_from_2);

# check writing
nf_PCI_write32(0   , $batch, MAC_GRP_1_RX_QUEUE_NUM_WORDS_PUSHED_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_1_RX_QUEUE_NUM_WORDS_PUSHED_REG(), 0);
nf_PCI_write32(0   , $batch, MAC_GRP_1_RX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_from_2);
nf_PCI_read32(0    , $batch, MAC_GRP_1_RX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_from_2);

nf_PCI_read32(0    , $batch, MAC_GRP_2_CONTROL_REG(), 0x0);
nf_PCI_read32(0    , $batch, MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED_REG(), $num_pkts_from_3);
nf_PCI_read32(0    , $batch, MAC_GRP_2_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_2_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_2_RX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_from_3);
nf_PCI_read32(0    , $batch, MAC_GRP_2_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG(), $num_pkts_to_3);
nf_PCI_read32(0    , $batch, MAC_GRP_2_TX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_to_3);
nf_PCI_read32(0    , $batch, MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED_REG(), $num_bytes_to_3);
nf_PCI_read32(0    , $batch, MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED_REG(), $num_bytes_from_3);

# check writing
nf_PCI_write32(0   , $batch, MAC_GRP_2_RX_QUEUE_NUM_WORDS_PUSHED_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_2_RX_QUEUE_NUM_WORDS_PUSHED_REG(), 0);
nf_PCI_write32(0   , $batch, MAC_GRP_2_RX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_from_3);
nf_PCI_read32(0    , $batch, MAC_GRP_2_RX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_from_3);

nf_PCI_read32(0    , $batch, MAC_GRP_3_CONTROL_REG(), 0x0);
nf_PCI_read32(0    , $batch, MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED_REG(), $num_pkts_from_4);
nf_PCI_read32(0    , $batch, MAC_GRP_3_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_3_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_3_RX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_from_4);
nf_PCI_read32(0    , $batch, MAC_GRP_3_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0);
nf_PCI_read32(0    , $batch, MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG(), $num_pkts_to_4);
nf_PCI_read32(0    , $batch, MAC_GRP_3_TX_QUEUE_NUM_WORDS_PUSHED_REG(), $num_words_to_4);
nf_PCI_read32(0    , $batch, MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED_REG(), $num_bytes_to_4);
nf_PCI_read32(0    , $batch, MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED_REG(), $num_bytes_from_4);

# input arbiter stats
nf_PCI_read32(0    , $batch, IN_ARB_NUM_PKTS_SENT_REG(), $num_pkts_from_4 + $num_pkts_from_3 + $num_pkts_from_2 + $num_pkts_from_1);


# output port lookup stats
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_NUM_HITS_REG(), $num_hits);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_NUM_MISSES_REG(), $num_misses);
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_NUM_HITS_REG(), 0);
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_NUM_MISSES_REG(), 0);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_NUM_HITS_REG(), 0);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_NUM_MISSES_REG(), 0);

# read the mac table
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_MAC_LUT_RD_ADDR_REG(), 0);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_PORTS_MAC_HI_REG(), 0x000100ca);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_MAC_LO_REG(), 0xfe000001);
# read the mac table
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_MAC_LUT_RD_ADDR_REG(), 1);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_PORTS_MAC_HI_REG(), 0x000400ca);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_MAC_LO_REG(), 0xfe000002);
# read the mac table
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_MAC_LUT_RD_ADDR_REG(), 2);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_PORTS_MAC_HI_REG(), 0x001000ca);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_MAC_LO_REG(), 0xfe000003);
# read the mac table
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_MAC_LUT_RD_ADDR_REG(), 3);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_PORTS_MAC_HI_REG(), 0x004000ca);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_MAC_LO_REG(), 0xfe000004);
# read the mac table
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_MAC_LUT_RD_ADDR_REG(), 4);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_PORTS_MAC_HI_REG(), 0x00000000);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_MAC_LO_REG(), 0x00000000);
# read the mac table
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_MAC_LUT_RD_ADDR_REG(), 5);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_PORTS_MAC_HI_REG(), 0x00000000);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_MAC_LO_REG(), 0x00000000);
# read the mac table's broadcast address
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_MAC_LUT_RD_ADDR_REG(), 15);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_PORTS_MAC_HI_REG(), 0x8055ffff);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_MAC_LO_REG(), 0xffffffff);

# write an entry and then read it back
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_PORTS_MAC_HI_REG(), 0x800500ca); # write protected
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_MAC_LO_REG(), 0xfe000005);
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_MAC_LUT_WR_ADDR_REG(), 5);
nf_PCI_write32(0   , $batch, SWITCH_OP_LUT_MAC_LUT_RD_ADDR_REG(), 5);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_PORTS_MAC_HI_REG(), 0x800500ca);
nf_PCI_read32(0    , $batch, SWITCH_OP_LUT_MAC_LO_REG(), 0xfe000005);

# Output queues stats
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG(), $num_bytes_to_1 + $num_bytes_brdcst_from_1);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_NUM_OVERHEAD_BYTES_STORED_REG(), ($num_pkts_to_1+ $num_pkts_brdcst_from_1)*$overhead_per_pkt);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_NUM_PKTS_STORED_REG(), $num_pkts_to_1 + $num_pkts_brdcst_from_1);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_NUM_PKTS_DROPPED_REG(), 0);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG(), $num_bytes_to_1 + $num_bytes_brdcst_from_1);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_NUM_OVERHEAD_BYTES_REMOVED_REG(), ($num_pkts_to_1 + $num_pkts_brdcst_from_1)*$overhead_per_pkt);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_NUM_PKTS_REMOVED_REG(), $num_pkts_to_1 + $num_pkts_brdcst_from_1);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_ADDR_LO_REG(), 0);

#try changing the size of the queue
nf_PCI_write32(0   , $batch, OQ_QUEUE_0_ADDR_LO_REG(), 50);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_ADDR_LO_REG(), 50);
nf_PCI_write32(0   , $batch, OQ_QUEUE_0_ADDR_HI_REG(), 100);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_ADDR_HI_REG(), 100);
nf_PCI_write32(0   , $batch, OQ_QUEUE_0_CTRL_REG(), 1 << OQ_INITIALIZE_OQ_BIT_NUM());
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_CTRL_REG(), 0);
nf_PCI_write32(0   , $batch, OQ_QUEUE_0_CTRL_REG(), 0);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_CTRL_REG(), 0);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_NUM_WORDS_LEFT_REG(), 50);

nf_PCI_write32(0   , $batch, OQ_QUEUE_0_ADDR_LO_REG(), 0);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_ADDR_LO_REG(), 0);
nf_PCI_write32(0   , $batch, OQ_QUEUE_0_ADDR_HI_REG(), 10000);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_ADDR_HI_REG(), 10000);
nf_PCI_write32(0   , $batch, OQ_QUEUE_0_CTRL_REG(), 1 << OQ_INITIALIZE_OQ_BIT_NUM());
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_CTRL_REG(), 0);
nf_PCI_write32(0   , $batch, OQ_QUEUE_0_CTRL_REG(), 0);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_CTRL_REG(), 0);
nf_PCI_read32(0    , $batch, OQ_QUEUE_0_NUM_WORDS_LEFT_REG(), 10000);

# read the other output queues stats, remove broadcast bytes and pkts
nf_PCI_read32(0    , $batch, OQ_QUEUE_2_NUM_PKT_BYTES_STORED_REG(), $num_bytes_to_2 - $num_bytes_brdcst_from_1 - $num_bytes_brdcst_from_4 - $num_bytes_brdcst_from_3);
nf_PCI_read32(0    , $batch, OQ_QUEUE_2_NUM_OVERHEAD_BYTES_STORED_REG(), ($num_pkts_to_2 - $num_pkts_brdcst_from_1 - $num_pkts_brdcst_from_3 - $num_pkts_brdcst_from_4)*$overhead_per_pkt);
nf_PCI_read32(0    , $batch, OQ_QUEUE_2_NUM_PKTS_STORED_REG(), $num_pkts_to_2 - $num_pkts_brdcst_from_1 - $num_pkts_brdcst_from_3 - $num_pkts_brdcst_from_4);
nf_PCI_read32(0    , $batch, OQ_QUEUE_2_NUM_PKTS_DROPPED_REG(), 0);
nf_PCI_read32(0    , $batch, OQ_QUEUE_2_NUM_PKT_BYTES_REMOVED_REG(), $num_bytes_to_2 - $num_bytes_brdcst_from_1 - $num_bytes_brdcst_from_3 - $num_bytes_brdcst_from_4);
nf_PCI_read32(0    , $batch, OQ_QUEUE_2_NUM_OVERHEAD_BYTES_REMOVED_REG(), ($num_pkts_to_2 - $num_pkts_brdcst_from_1 - $num_pkts_brdcst_from_3 - $num_pkts_brdcst_from_4)*$overhead_per_pkt);
nf_PCI_read32(0    , $batch, OQ_QUEUE_2_NUM_PKTS_REMOVED_REG(), $num_pkts_to_2 - $num_pkts_brdcst_from_1 - $num_pkts_brdcst_from_3 - $num_pkts_brdcst_from_4);

my $num_pkts_broadcast = $num_pkts_brdcst_from_1 + $num_pkts_brdcst_from_2 + $num_pkts_brdcst_from_4;
my $num_bytes_broadcast = $num_bytes_brdcst_from_1 + $num_bytes_brdcst_from_2 + $num_bytes_brdcst_from_4;
nf_PCI_read32(0    , $batch, OQ_QUEUE_4_NUM_PKT_BYTES_STORED_REG(), $num_bytes_to_3 - $num_bytes_broadcast);
nf_PCI_read32(0    , $batch, OQ_QUEUE_4_NUM_OVERHEAD_BYTES_STORED_REG(), ($num_pkts_to_3-$num_pkts_broadcast)*$overhead_per_pkt);
nf_PCI_read32(0    , $batch, OQ_QUEUE_4_NUM_PKTS_STORED_REG(), $num_pkts_to_3-$num_pkts_broadcast);
nf_PCI_read32(0    , $batch, OQ_QUEUE_4_NUM_PKTS_DROPPED_REG(), 0);
nf_PCI_read32(0    , $batch, OQ_QUEUE_4_NUM_PKT_BYTES_REMOVED_REG(), $num_bytes_to_3 - $num_bytes_broadcast);
nf_PCI_read32(0    , $batch, OQ_QUEUE_4_NUM_OVERHEAD_BYTES_REMOVED_REG(), ($num_pkts_to_3-$num_pkts_broadcast)*$overhead_per_pkt);
nf_PCI_read32(0    , $batch, OQ_QUEUE_4_NUM_PKTS_REMOVED_REG(), $num_pkts_to_3 - $num_pkts_broadcast);

$num_pkts_broadcast = $num_pkts_brdcst_from_1 + $num_pkts_brdcst_from_2 + $num_pkts_brdcst_from_3;
$num_bytes_broadcast = $num_bytes_brdcst_from_1 + $num_bytes_brdcst_from_2 + $num_bytes_brdcst_from_3;
nf_PCI_read32(0    , $batch, OQ_QUEUE_6_NUM_PKT_BYTES_STORED_REG(), $num_bytes_to_4 - $num_bytes_broadcast);
nf_PCI_read32(0    , $batch, OQ_QUEUE_6_NUM_OVERHEAD_BYTES_STORED_REG(), ($num_pkts_to_4-$num_pkts_broadcast)*$overhead_per_pkt);
nf_PCI_read32(0    , $batch, OQ_QUEUE_6_NUM_PKTS_STORED_REG(), $num_pkts_to_4-$num_pkts_broadcast);
nf_PCI_read32(0    , $batch, OQ_QUEUE_6_NUM_PKTS_DROPPED_REG(), 0);
nf_PCI_read32(0    , $batch, OQ_QUEUE_6_NUM_PKT_BYTES_REMOVED_REG(), $num_bytes_to_4 - $num_bytes_broadcast);
nf_PCI_read32(0    , $batch, OQ_QUEUE_6_NUM_OVERHEAD_BYTES_REMOVED_REG(), ($num_pkts_to_4-$num_pkts_broadcast)*$overhead_per_pkt);
nf_PCI_read32(0    , $batch, OQ_QUEUE_6_NUM_PKTS_REMOVED_REG(), $num_pkts_to_4 - $num_pkts_broadcast);

# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


