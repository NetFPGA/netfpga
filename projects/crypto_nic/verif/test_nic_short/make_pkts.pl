#!/usr/local/bin/perl -w
# make_pkts.pl
#

use NF::PacketGen;
use NF::PacketLib;
use SimLib;

use reg_defines_crypto_nic;

$delay = '@4us';
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

my $length = 100;
my $DA;
my $SA;
my $pkt;

# send and receive 1 via port 1
$delay = '@5us';
$length = 60;
$DA = "00:11:11:11:11:11";
$SA = "00:22:22:22:22:22";

$pkt = make_IP_pkt($length, $DA, $SA, 64, '192.168.0.1', '192.168.0.2');
nf_packet_in(1, $length, $delay, $batch,  $pkt);
nf_expected_dma_data(1, $length, $pkt);

$DA = "00:33:33:33:33:33";
$SA = "00:44:44:44:44:44";
$pkt = make_IP_pkt($length, $DA, $SA, 64, '192.168.0.3', '192.168.0.4');
nf_dma_data_in($length, $delay, 1, $pkt);
nf_expected_packet(1, $length, $pkt);

# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
