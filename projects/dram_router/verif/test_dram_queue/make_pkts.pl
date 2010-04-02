#!/usr/local/bin/perl -w
# make_pkts.pl
#


use NF::Base "projects/reference_router/lib/Perl5";
use NF::PacketGen;
use NF::PacketLib;
use SimLib;
use RouterLib;

use reg_defines_dram_router;

$delay = '@4us';
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

my $ROUTER_PORT_1_MAC = '00:ca:fe:00:00:01';
my $ROUTER_PORT_2_MAC = '00:ca:fe:00:00:02';
my $ROUTER_PORT_3_MAC = '00:ca:fe:00:00:03';
my $ROUTER_PORT_4_MAC = '00:ca:fe:00:00:04';

my $ROUTER_PORT_1_IP = '192.168.1.1';
my $ROUTER_PORT_2_IP = '192.168.2.1';
my $ROUTER_PORT_3_IP = '192.168.3.1';
my $ROUTER_PORT_4_IP = '192.168.4.1';

my $DEST_IP_1 = '192.168.1.5';
my $DEST_IP_2 = '192.168.2.5';
my $DEST_IP_3 = '192.168.3.5';
my $DEST_IP_4 = '192.168.4.5';
my $DEST_IP_4a = '192.168.4.128';
my $DEST_IP_4b = '192.168.4.129';

my $NEXT_IP_1 = '192.168.1.2';
my $NEXT_IP_2 = '192.168.2.2';
my $NEXT_IP_3 = '192.168.3.2';
my $NEXT_IP_4 = '192.168.4.2';

my $next_hop_1_DA = '00:fe:ed:01:d0:65';
my $next_hop_2_DA = '00:fe:ed:02:d0:65';
my $next_hop_3_DA = '00:fe:ed:03:d0:65';
my $next_hop_4_DA = '00:fe:ed:04:d0:65';

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

# Write the ip addresses and mac addresses, routing table and ARP entries
set_router_MAC(1, $ROUTER_PORT_1_MAC);
$delay = 0;
set_router_MAC(2, $ROUTER_PORT_2_MAC);
set_router_MAC(3, $ROUTER_PORT_3_MAC);
set_router_MAC(4, $ROUTER_PORT_4_MAC);

# write the IP addresses to ip 1
add_dst_ip_filter_entry(0,$ROUTER_PORT_1_IP);
add_dst_ip_filter_entry(1,$ROUTER_PORT_2_IP);
add_dst_ip_filter_entry(2,$ROUTER_PORT_3_IP);
add_dst_ip_filter_entry(3,$ROUTER_PORT_4_IP);

$delay = '@10us';
nf_PCI_write32($delay, $batch, OQ_QUEUE_0_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_1_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_2_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_3_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_4_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_5_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_6_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_7_SHORTCUT_DISABLE_REG(), 1);

my $length = 100;
my $TTL = 30;
my $DA = 0;
my $SA = 0;
my $dst_ip = 0;
my $src_ip = 0;
my $pkt;
my $in_port;
my $out_port;
my $i = 0;
my $pkt_num;

# Add LPM entries
$delay = '@20us';
add_LPM_table_entry(0,'192.168.1.0', '255.255.255.0', $NEXT_IP_1, 0x1);
$delay = 0;
add_LPM_table_entry(1,'192.168.2.0', '255.255.255.0', $NEXT_IP_2, 0x4);
add_LPM_table_entry(2,'192.168.3.0', '255.255.255.0', $NEXT_IP_3, 0x10);
add_LPM_table_entry(3,'192.168.4.129', '255.255.255.255', $NEXT_IP_3, 0x10);
add_LPM_table_entry(4,'192.168.4.128', '255.255.255.128', $NEXT_IP_1, 0x1);
add_LPM_table_entry(5,'192.168.4.0', '255.255.255.0', $NEXT_IP_4, 0x40);

# Add ARP entries
add_ARP_table_entry(0, $NEXT_IP_1, $next_hop_1_DA);
add_ARP_table_entry(1, $NEXT_IP_2, $next_hop_2_DA);
add_ARP_table_entry(2, $NEXT_IP_3, $next_hop_3_DA);
add_ARP_table_entry(3, $NEXT_IP_4, $next_hop_4_DA);

# flood the router with random packets

for($pkt_num=0; $pkt_num<5; $pkt_num+=1){
  $delay = '@30us';
  $length = 1500;
  $DA = $ROUTER_PORT_1_MAC;
  $SA = '11:55:55:55:55:55';
  $in_port = 1;
  $pkt = make_ethernet_pkt($length, $DA, $SA, 0x806);
  nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
  nf_expected_dma_data($in_port, $length, $pkt);

  $length = 1500;
  $DA = $ROUTER_PORT_2_MAC;
  $SA = '11:55:55:55:55:55';
  $in_port = 2;
  $pkt = make_ethernet_pkt($length, $DA, $SA, 0x806);
  nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
  nf_expected_dma_data($in_port, $length, $pkt);

  $length = 1500;
  $DA = $ROUTER_PORT_3_MAC;
  $SA = '11:55:55:55:55:55';
  $in_port = 3;
  $pkt = make_ethernet_pkt($length, $DA, $SA, 0x806);
  nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
  nf_expected_dma_data($in_port, $length, $pkt);

  $length = 1500;
  $DA = $ROUTER_PORT_4_MAC;
  $SA = '11:55:55:55:55:55';
  $in_port = 4;
  $pkt = make_ethernet_pkt($length, $DA, $SA, 0x806);
  nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
  nf_expected_dma_data($in_port, $length, $pkt);
}

# flood the router with random packets

for($pkt_num=0; $pkt_num<5; $pkt_num+=1){
  $delay = '@40us';
  $length = 1200;
  $DA = $ROUTER_PORT_3_MAC;
  $SA = '0f:55:55:55:55:55';
  $dst_ip = $DEST_IP_2;
  $src_ip = '171.64.8.1';
  $in_port = 3;
  $out_port = 2;
  $pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
  nf_packet_in($in_port, $length, $delay, $batch,  $pkt);

  $DA = $next_hop_2_DA;
  $SA = $ROUTER_PORT_2_MAC;
  $pkt = make_IP_pkt($length, $DA, $SA, $TTL-1, $dst_ip, $src_ip);
  nf_expected_packet($out_port, $length, $pkt);

  $length = 1200;
  $DA = $ROUTER_PORT_3_MAC;
  $SA = '0f:55:55:55:55:55';
  $dst_ip = $DEST_IP_1;
  $src_ip = '171.64.8.1';
  $in_port = 3;
  $out_port = 1;
  $pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
  nf_packet_in($in_port, $length, $delay, $batch,  $pkt);

  $DA = $next_hop_1_DA;
  $SA = $ROUTER_PORT_1_MAC;
  $pkt = make_IP_pkt($length, $DA, $SA, $TTL-1, $dst_ip, $src_ip);
  nf_expected_packet($out_port, $length, $pkt);

  $length = 1200;
  $DA = $ROUTER_PORT_3_MAC;
  $SA = '0f:55:55:55:55:55';
  $dst_ip = $DEST_IP_3;
  $src_ip = '171.64.8.1';
  $in_port = 3;
  $out_port = 3;
  $pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
  nf_packet_in($in_port, $length, $delay, $batch,  $pkt);

  $DA = $next_hop_3_DA;
  $SA = $ROUTER_PORT_3_MAC;
  $pkt = make_IP_pkt($length, $DA, $SA, $TTL-1, $dst_ip, $src_ip);
  nf_expected_packet($out_port, $length, $pkt);
}

$delay = '@200us';
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
