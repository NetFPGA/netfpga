#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
#

use NF::PacketGen;
use NF::PacketLib;
use SimLib;

use reg_defines_reference_switch;

$delay = 4000;
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

####################################################################
# Create a new packet

my $MAC_hdr = NF::Ethernet_hdr->new(DA => 'FF:FF:FF:FF:FF:FF',
                                     SA => '00:ca:fe:00:00:01',
                                     Ethertype => 0x800
);

my $length = 60;

# Make rest of packet (the data)
my $PDU = NF::PDU->new($length - $MAC_hdr->length_in_bytes() );

my $start_val = $MAC_hdr->length_in_bytes()+1;

$PDU->set_bytes(($start_val..$length));

# Build complete packet data
my $pkt = $MAC_hdr->bytes().$PDU->bytes();

print "Packet is:\n$pkt\n";

nf_packet_in(1, $length,  $delay, $batch,  $pkt);

# It's a broadcast so should go everywhere except source (1)
nf_expected_packet(2, $length,             $pkt);
nf_expected_packet(3, $length,             $pkt);
nf_expected_packet(4, $length,             $pkt);

$delay = $delay + 1000;

#####################################################################
# Create a 2nd bcast packet

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

$delay = $delay + 1000;

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


# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


