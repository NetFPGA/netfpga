#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
#

use NF::Base "projects/reference_router/lib/Perl5";
use NF::PacketGen;
use NF::PacketLib;
use SimLib;
use RouterLib;

use reg_defines_dram_router;

$delay = 2000;
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

my $ROUTER_PORT_1_MAC = '00:00:00:00:09:01';
my $ROUTER_PORT_2_MAC = '00:00:00:00:09:02';
my $ROUTER_PORT_3_MAC = '00:00:00:00:09:03';
my $ROUTER_PORT_4_MAC = '00:00:00:00:09:04';

my $ROUTER_PORT_1_IP = '192.168.26.2';
my $ROUTER_PORT_2_IP = '192.168.25.2';
my $ROUTER_PORT_3_IP = '192.168.27.1';
my $ROUTER_PORT_4_IP = '192.168.24.2';
my $OSPF_IP = '224.0.0.5';

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

# Write the ip addresses and mac addresses, routing table, filter, ARP entries
$delay = '@4us';
set_router_MAC(1, $ROUTER_PORT_1_MAC);
$delay = 0;
set_router_MAC(2, $ROUTER_PORT_2_MAC);
set_router_MAC(3, $ROUTER_PORT_3_MAC);
set_router_MAC(4, $ROUTER_PORT_4_MAC);

add_dst_ip_filter_entry(0,$ROUTER_PORT_1_IP);
add_dst_ip_filter_entry(1,$ROUTER_PORT_2_IP);
add_dst_ip_filter_entry(2,$ROUTER_PORT_3_IP);
add_dst_ip_filter_entry(3,$ROUTER_PORT_4_IP);
add_dst_ip_filter_entry(4,$OSPF_IP);

add_LPM_table_entry(0,'192.168.27.0', '255.255.255.0', '0.0.0.0', 0x10);
add_LPM_table_entry(1,'192.168.26.0', '255.255.255.0', '0.0.0.0', 0x01);
add_LPM_table_entry(2,'192.168.25.0', '255.255.255.0', '0.0.0.0', 0x04);
add_LPM_table_entry(3,'192.168.24.0', '255.255.255.0', '0.0.0.0', 0x40);

# Add the ARP table entries
add_ARP_table_entry(0, '192.168.25.1', '01:50:17:15:56:1c');
add_ARP_table_entry(1, '192.168.26.1', '01:50:17:20:fd:81');

$delay = '@10us';
nf_PCI_write32($delay, $batch, OQ_QUEUE_0_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_1_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_2_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_3_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_4_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_5_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_6_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_7_SHORTCUT_DISABLE_REG(), 1);

my $length = 98;
my $TTL = 30;
my $DA = 0;
my $SA = 0;
my $dst_ip = 0;
my $src_ip = 0;
my $pkt;

#
###############################
#

print "\nconstructing 1st packet....\n";

# 1st pkt (no VLAN)
for (my $i=0; $i<100; $i++){
	$delay = '@50us';
	$length = 98;
	$DA = $ROUTER_PORT_1_MAC;
	$SA = '01:55:55:55:55:55';
	$dst_ip = '192.168.25.1';
	$src_ip = '192.168.26.1';
	$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);

	nf_packet_in(1, $length, $delay, $batch,  $pkt);

	$DA = '01:50:17:15:56:1c';
	$SA = $ROUTER_PORT_2_MAC;

	$pkt = make_IP_pkt($length, $DA, $SA, $TTL-1, $dst_ip, $src_ip);
	nf_expected_packet(2, $length, $pkt);
}


# 1st pkt (no VLAN)
#$delay = '20us';
$length = 98;
$DA = $ROUTER_PORT_1_MAC;
$SA = '01:55:55:55:55:55';
$dst_ip = '192.168.25.1';
$src_ip = '192.168.26.1';
$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
nf_packet_in(1, $length, $delay, $batch,  $pkt);

$DA = '01:50:17:15:56:1c';
$SA = $ROUTER_PORT_2_MAC;
$pkt = make_IP_pkt($length, $DA, $SA, $TTL-1, $dst_ip, $src_ip);
nf_expected_packet(2, $length, $pkt);

$delay = '@100us';
nf_PCI_write32($delay, $batch, OQ_QUEUE_0_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_1_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_2_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_3_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_4_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_5_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_6_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_7_SHORTCUT_DISABLE_REG(), 0);

# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
