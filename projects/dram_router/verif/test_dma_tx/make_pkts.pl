#!/usr/local/bin/perl -w
# make_pkts.pl

use NF::Base "projects/reference_router/lib/Perl5";
use NF::PacketGen;
use NF::PacketLib;
use SimLib;
use RouterLib;
use CPCI_Lib;

use reg_defines_dram_router;

$delay = 2000;
$batch = 0;

nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

# write 0 to CPCI_INTERRUPT_MASK_REG()
#nf_PCI_write32(0, $batch, CPCI_INTERRUPT_MASK_REG(), 0);

my $ROUTER_PORT_1_MAC = '00:ca:fe:00:00:01';
my $ROUTER_PORT_2_MAC = '00:ca:fe:00:00:02';
my $ROUTER_PORT_3_MAC = '00:ca:fe:00:00:03';
my $ROUTER_PORT_4_MAC = '00:ca:fe:00:00:04';

my $ROUTER_PORT_1_IP = '192.168.1.1';
my $ROUTER_PORT_2_IP = '192.168.2.1';
my $ROUTER_PORT_3_IP = '192.168.3.1';
my $ROUTER_PORT_4_IP = '192.168.4.1';

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

# Write the ip addresses and mac addresses, routing table and ARP entries
set_router_MAC(1, $ROUTER_PORT_1_MAC);
$delay = 0;
set_router_MAC(2, $ROUTER_PORT_2_MAC);
set_router_MAC(3, $ROUTER_PORT_3_MAC);
set_router_MAC(4, $ROUTER_PORT_4_MAC);

my $length = 100;
my $TTL = 30;
my $DA = 0;
my $SA = 0;
my $dst_ip = 0;
my $src_ip = 0;
my $pkt;
my $cpudelay = 1000;
my $queue;

#
################
#

print "\n 1. cpu sends out a packet from port 1 (start from 1) ...\n";

$length = 44;

my $length_plus_pad = 60;

my $pkt_runt = "ff ff ff ff ff ff 00 4e 46 32 43 01 08 06 00 01 08 00 06 04 00 01 00 4e 46 32 43 03 c0 a8 0d 01 00 00 00 00 00 00 c0 a8 0d 02 00 00";

$pkt = $pkt_runt . " 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00";

$queue = 1;
for (my $i = 0; $i < 20; $i++) {
	nf_dma_data_in($length, 0, $queue, $pkt_runt);

	nf_expected_packet(1, $length_plus_pad, $pkt);

	print "\n $i. cpu sends out a packet from port 1 (start from 1) ...\n";
}

print "\n";

# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
