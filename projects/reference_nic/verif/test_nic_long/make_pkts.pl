#!/usr/local/bin/perl -w
# make_pkts.pl
#

use NF::PacketGen;
use NF::PacketLib;
use SimLib;

require reg_defines_reference_nic;

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
my $DA_sub = ':dd:dd:dd:dd';
my $SA_sub = ':55:55:55:55';
my $DA;
my $SA;
my $pkt;
my $in_port;
my $out_port;
my $i = 0;
my $temp;

$delay = '@7us';
my $range = 1454;
my $minimum = 60;

for($i=0; $i<50; $i=$i+1){
  $length = int(rand($range)) + $minimum;
  $temp = sprintf("%02x:%02x", ($i>>8)&0xff, $i&0xff);
  $DA = $temp . $DA_sub;
  $SA = $temp . $SA_sub;
  $in_port = (int(rand(100))%4) + 1;
  $pkt = make_IP_pkt($length, $DA, $SA, 64, '192.168.0.1', '192.168.0.2');
  nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
  cpu_rxfifo_rd_pkt($in_port, $length, 0, $pkt);
  PCI_create_and_send_pkt($in_port, $length);
}

# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
