#!/usr/local/bin/perl -w
# make_pkts.pl
#
# set the size of the output queues to 4kB
# We should accept one packet from the CPU
# and drop the rest.

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

my $ROUTER_PORT_1_MAC = '00:ca:fe:00:00:01';
my $ROUTER_PORT_2_MAC = '00:ca:fe:00:00:02';
my $ROUTER_PORT_3_MAC = '00:ca:fe:00:00:03';
my $ROUTER_PORT_4_MAC = '00:ca:fe:00:00:04';

my $ROUTER_PORT_1_IP = '192.168.1.1';
my $ROUTER_PORT_2_IP = '192.168.2.1';
my $ROUTER_PORT_3_IP = '192.168.3.1';
my $ROUTER_PORT_4_IP = '192.168.4.1';

my $next_hop_1_DA = '00:fe:ed:01:d0:65';
my $next_hop_2_DA = '00:fe:ed:02:d0:65';

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

add_LPM_table_entry(0,'171.64.2.0', '255.255.255.0', '171.64.2.1', 0x04);
add_LPM_table_entry(15, '0.0.0.0', '0.0.0.0', '171.64.1.1', 0x01);

# Add the ARP table entries
add_ARP_table_entry(0, '171.64.1.1', $next_hop_1_DA);
add_ARP_table_entry(1, '171.64.2.1', $next_hop_2_DA);

my $length = 100;
my $TTL = 30;
my $DA = 0;
my $SA = 0;
my $dst_ip = 0;
my $src_ip = 0;
my $pkt;

#
###############################
#

# set the size of the output queues
$delay = '@5us';
nf_PCI_write32($delay, $batch, OQ_QUEUE_2_ADDR_HI_REG(), 0x2ff);
nf_PCI_write32($delay, $batch, OQ_QUEUE_2_ADDR_LO_REG(), 0x200);
nf_PCI_write32($delay, $batch, OQ_QUEUE_2_CTRL_REG(), 1<<OQ_INITIALIZE_OQ_BIT_NUM());


nf_PCI_write32($delay, $batch, OQ_QUEUE_4_ADDR_HI_REG(), 0x4ff);
nf_PCI_write32($delay, $batch, OQ_QUEUE_4_ADDR_LO_REG(), 0x400);
nf_PCI_write32($delay, $batch, OQ_QUEUE_4_CTRL_REG(), 1<<OQ_INITIALIZE_OQ_BIT_NUM());

$delay = '@10us';
nf_PCI_write32($delay, $batch, OQ_QUEUE_0_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_1_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_2_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_3_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_4_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_5_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_6_SHORTCUT_DISABLE_REG(), 1);
nf_PCI_write32($delay, $batch, OQ_QUEUE_7_SHORTCUT_DISABLE_REG(), 1);

$delay = '@20us';
nf_PCI_write32($delay, $batch, OQ_QUEUE_2_CTRL_REG(), 0<<OQ_INITIALIZE_OQ_BIT_NUM());
nf_PCI_write32($delay, $batch, OQ_QUEUE_4_CTRL_REG(), 0<<OQ_INITIALIZE_OQ_BIT_NUM());

# send 4 packets
$delay = '@50us';
$length = 1500;
my $num_pkts = 5;
my $i=0;
for ($i=0; $i<$num_pkts; $i++) {
   PCI_create_and_send_pkt(2, $length);
   PCI_create_and_send_pkt(3, $length);
}

nf_PCI_write32($delay, $batch, OQ_QUEUE_0_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_1_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_2_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_3_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_4_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_5_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_6_SHORTCUT_DISABLE_REG(), 0);
nf_PCI_write32($delay, $batch, OQ_QUEUE_7_SHORTCUT_DISABLE_REG(), 0);
$delay = '@200us';
nf_PCI_read32($delay, $batch, OQ_QUEUE_2_NUM_PKTS_STORED_REG (), $num_pkts);
nf_PCI_read32($delay, $batch, OQ_QUEUE_2_NUM_PKTS_REMOVED_REG (), $num_pkts);
nf_PCI_read32($delay, $batch, OQ_QUEUE_4_NUM_PKTS_STORED_REG (), $num_pkts);
nf_PCI_read32($delay, $batch, OQ_QUEUE_4_NUM_PKTS_REMOVED_REG (), $num_pkts);

################################
# Reset the netfpga and check that the ip/arp/dest_ip_filter tables are all cleared



# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
