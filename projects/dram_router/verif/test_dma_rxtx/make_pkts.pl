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
my $cpudelay = 25000;
my $queue;

#
###############################
#
print "\n 1. cpu should receive a packet from port 1 (start from 0)....\n";

# a pkt (no VLAN) destined for us on port 1 (IP matches)
$delay = 20000;
$length = 64;
$DA = $ROUTER_PORT_2_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_1_IP;
$src_ip = '171.64.9.1';
$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
nf_packet_in(2, $length, $delay, $batch,  $pkt);

$queue = 2;
nf_expected_dma_data($queue, $length, $pkt);

#
###############################
#

print "\n 2. cpu should receive a packet from port 2 (start from 0)....\n";

# a pkt (no VLAN) destined for us on port 2 (IP matches)
$delay = 21000;
$length = 97;
$DA = $ROUTER_PORT_3_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_2_IP;
$src_ip = '171.64.9.1';
$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
nf_packet_in(3, $length, $delay, $batch,  $pkt);

$queue = 3;
nf_expected_dma_data($queue, $length, $pkt);

#
###############################
#

print "\n 3. cpu should receive a packet from port 3 (start from 0)....\n";

# a pkt (no VLAN) destined for us on port 3 (IP matches)
$delay = 22000;
$length = 1026;
$DA = $ROUTER_PORT_4_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_3_IP;
$src_ip = '171.64.9.1';
$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
nf_packet_in(4, $length, $delay, $batch,  $pkt);

$queue = 4;
nf_expected_dma_data($queue, $length, $pkt);

#
#####################
#

print "\n 4. cpu should receive a packet from port 0 (start from 0)....\n";

# a pkt (no VLAN) destined for us on port 4 (IP matches)
$delay = 23000;
$length = 1511;
$DA = $ROUTER_PORT_1_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_4_IP;
$src_ip = '171.64.9.1';
$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
nf_packet_in(1, $length, $delay, $batch,  $pkt);

$queue = 1;
nf_expected_dma_data($queue, $length, $pkt);

#
###############################
#


print "\n 5. cpu should receive a packet from port 1 (start from 0)....\n";

# a pkt (no VLAN) destined for us on port 1 (IP matches)
$delay = 0;
$length = 1511;
$DA = $ROUTER_PORT_2_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_1_IP;
$src_ip = '171.64.9.1';
$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
nf_packet_in(2, $length, $delay, $batch,  $pkt);

$queue = 2;
nf_expected_dma_data($queue, $length, $pkt);

#
###############################
#

print "\n 6. cpu should receive a packet from port 2 (start from 0)....\n";

# a pkt (no VLAN) destined for us on port 2 (IP matches)
$delay = 0;
$length = 1026;
$DA = $ROUTER_PORT_3_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_2_IP;
$src_ip = '171.64.9.1';
$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
nf_packet_in(3, $length, $delay, $batch,  $pkt);

$queue = 3;
nf_expected_dma_data($queue, $length, $pkt);

#
###############################
#

print "\n 7. cpu should receive a packet from port 3 (start from 0)....\n";

# a pkt (no VLAN) destined for us on port 3 (IP matches)
$delay = 0;
$length = 97;
$DA = $ROUTER_PORT_4_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_3_IP;
$src_ip = '171.64.9.1';
$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
nf_packet_in(4, $length, $delay, $batch,  $pkt);

$queue = 4;
nf_expected_dma_data($queue, $length, $pkt);

#
#####################
#

print "\n 8. cpu should receive a packet from port 0 (start from 0)....\n";

# a pkt (no VLAN) destined for us on port 4 (IP matches)
$delay = 0;
$length = 64;
$DA = $ROUTER_PORT_1_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_4_IP;
$src_ip = '171.64.9.1';
$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
nf_packet_in(1, $length, $delay, $batch,  $pkt);

$queue = 1;
nf_expected_dma_data($queue, $length, $pkt);

#
#####################
#

print "\n 8A. cpu should receive a packet from port 0 (start from 0)....\n";

# a pkt (no VLAN) destined for us on port 4 (IP matches)
$delay = 0;
$length = 1511;
$DA = $ROUTER_PORT_1_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_4_IP;
$src_ip = '171.64.9.1';
$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);
nf_packet_in(1, $length, $delay, $batch,  $pkt);

$queue = 1;
nf_expected_dma_data($queue, $length, $pkt);

#
################
#

print "\n 9. cpu sends out a packet from port 0 (start from 0) ...\n";

# Writing DMA Host Buffer Address
#nf_PCI_write32(0, $batch, $cpci_regs{CPCI_DMA_Addr_E_reg}, 0xc0000000);

# Setting up transfer size 60 bytes
#nf_PCI_write32(0, $batch, $cpci_regs{CPCI_DMA_Size_E_reg}, 0x0000003c);

# Setting memory owner and starting transfer
# DMA tx to port 0 (start from 0)
#nf_PCI_write32(0, $batch, $cpci_regs{CPCI_DMA_Ctrl_E_reg}, 0x00000001);

$length = 60;
$DA = $ROUTER_PORT_1_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_4_IP;
$src_ip = '171.64.9.1';

$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);

$queue=1;
#nf_dma_data_in(1, $length, $pkt);
nf_dma_data_in($length, 0, $queue, $pkt);
nf_expected_packet(1, $length, $pkt);

#
################
#

print "\n 10. cpu sends out a packet from port 1 (start from 0) ...\n";

$length = 97;
$DA = $ROUTER_PORT_1_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_4_IP;
$src_ip = '171.64.9.1';

$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);

$queue = 2;
#nf_dma_data_in(2, $length, $pkt);
nf_dma_data_in($length, 0, $queue, $pkt);
nf_expected_packet(2, $length, $pkt);

#
################
#

print "\n 11. cpu sends out a packet from port 2 (start from 0) ...\n";

$length = 1022;
$DA = $ROUTER_PORT_1_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_4_IP;
$src_ip = '171.64.9.1';

$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);

$queue = 3;
#nf_dma_data_in(3, $length, $pkt);
nf_dma_data_in($length, 0, $queue, $pkt);
nf_expected_packet(3, $length, $pkt);

#
################
#

print "\n 12. cpu sends out a packet from port 3 (start from 0) ...\n";

$length = 1511;
$DA = $ROUTER_PORT_1_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_4_IP;
$src_ip = '171.64.9.1';

$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);

$queue = 4;
#nf_dma_data_in(4, $length, $pkt);
nf_dma_data_in($length, 0, $queue, $pkt);
nf_expected_packet(4, $length, $pkt);

#
################
#

print "\n 13. cpu sends out a packet from port 0 (start from 0) ...\n";

$length = 1511;
$DA = $ROUTER_PORT_1_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_4_IP;
$src_ip = '171.64.9.1';

$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);

$queue = 1;
nf_dma_data_in($length, 0, $queue, $pkt);
nf_expected_packet(1, $length, $pkt);

#
################
#

print "\n 14. cpu sends out a packet from port 1 (start from 0) ...\n";

$length = 1022;
$DA = $ROUTER_PORT_1_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_4_IP;
$src_ip = '171.64.9.1';

$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);

$queue = 2;
nf_dma_data_in($length, 0, $queue, $pkt);
nf_expected_packet(2, $length, $pkt);

#
################
#

print "\n 15. cpu sends out a packet from port 2 (start from 0) ...\n";

$length = 97;
$DA = $ROUTER_PORT_1_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_4_IP;
$src_ip = '171.64.9.1';

$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);

$queue = 3;
nf_dma_data_in($length, 0, $queue, $pkt);
nf_expected_packet(3, $length, $pkt);

#
################
#

print "\n 16. cpu sends out a packet from port 3 (start from 0) ...\n";

$length = 60;
$DA = $ROUTER_PORT_1_MAC;
$SA = '02:55:55:55:55:55';
$dst_ip = $ROUTER_PORT_4_IP;
$src_ip = '171.64.9.1';

$pkt = make_IP_pkt($length, $DA, $SA, $TTL, $dst_ip, $src_ip);

$queue = 4;
nf_dma_data_in($length, 0, $queue, $pkt);
nf_expected_packet(4, $length, $pkt);

################################
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
