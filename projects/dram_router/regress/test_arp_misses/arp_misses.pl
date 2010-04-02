#!/usr/bin/perl

use strict;
use NF::Base "projects/reference_router/lib/Perl5";
use NF::RegressLib;
use NF::PacketLib;
use RegressRouterLib;

use reg_defines_dram_router;

my @interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2");
nftest_init(\@ARGV,\@interfaces,);
nftest_start(\@interfaces);

my $routerMAC0 = "00:ca:fe:00:00:01";
my $routerMAC1 = "00:ca:fe:00:00:02";
my $routerMAC2 = "00:ca:fe:00:00:03";
my $routerMAC3 = "00:ca:fe:00:00:04";

my $routerIP0 = "192.168.0.40";
my $routerIP1 = "192.168.1.40";
my $routerIP2 = "192.168.2.40";
my $routerIP3 = "192.168.3.40";

# Write the mac and IP addresses
nftest_add_dst_ip_filter_entry ('nf2c0', 0, $routerIP0);
nftest_add_dst_ip_filter_entry ('nf2c1', 1, $routerIP1);
nftest_add_dst_ip_filter_entry ('nf2c2', 2, $routerIP2);
nftest_add_dst_ip_filter_entry ('nf2c3', 3, $routerIP3);

nftest_set_router_MAC ('nf2c0', $routerMAC0);
nftest_set_router_MAC ('nf2c1', $routerMAC1);
nftest_set_router_MAC ('nf2c2', $routerMAC2);
nftest_set_router_MAC ('nf2c3', $routerMAC3);

# clear LPM table
for (my $i = 0; $i < 32; $i++)
{
	nftest_invalidate_LPM_table_entry('nf2c0', $i);
}

# clear ARP table
for (my $i = 0; $i < 32; $i++)
{
	nftest_invalidate_ARP_table_entry('nf2c0', $i);
}

# clear counter
nftest_regwrite('nf2c0', ROUTER_OP_LUT_ARP_NUM_MISSES_REG, 0); #'x12C');

# add an entry in the routing table:
my $index = 0;
my $subnetIP = "192.168.1.0";
my $subnetMask = "255.255.255.0";
my $nextHopIP = "192.168.1.54";
my $outPort = 0x4;              # output on MAC1
my $nextHopMAC = "dd:55:dd:66:dd:77";

nftest_add_LPM_table_entry ('nf2c0',
                            $index,
                            $subnetIP,
                            $subnetMask,
                            $nextHopIP,
                            $outPort);

# add an entry in the ARP table
#nftest_add_ARP_table_entry('nf2c0',
#                          $index,
#                          $nextHopIP,
#                          $nextHopMAC);

# clear counter
nftest_regwrite('nf2c0', ROUTER_OP_LUT_ARP_NUM_MISSES_REG, 0);

my $total_errors = 0;

my $DA = $routerMAC0;
my $SA = "aa:bb:cc:dd:ee:ff";
my $TTL = 64;
my $DST_IP = "192.168.1.1";   #not in the lpm table
my $SRC_IP = "192.168.0.1";;
my $len = 100;
my $nextHopMAC = "dd:55:dd:66:dd:77";

# create mac header
my $MAC_hdr = NF::Ethernet_hdr->new(DA => $DA,
				     SA => $SA,
				     Ethertype => 0x800
				    );

#create IP header
my $IP_hdr = NF::IP_hdr->new(ttl => $TTL,
			      src_ip => $SRC_IP,
			      dst_ip => $DST_IP
			     );

# precreate random packets
my @portPkts = nftest_precreate_pkts(30, $MAC_hdr->packed . $IP_hdr->packed);

# loop for 30 packets sending LPM miss packet
for (my $i = 0; $i < 30; $i++) {
  # get packed packet string
  my $sent_pkt = $portPkts[int(rand(30))];

  # send packet out of eth1->nf2c0
  nftest_send('eth1', $sent_pkt);
  nftest_expect('nf2c0', $sent_pkt);
	`usleep 500`;
}

sleep 1;

my $temp_error_val = 0;

my $unmatched_hoh = nftest_finish();
$total_errors += nftest_print_errors($unmatched_hoh);

#read number of ARP misses
$temp_error_val = nftest_regread_expect('nf2c0', ROUTER_OP_LUT_ARP_NUM_MISSES_REG, 30); #'x12C');
if ($temp_error_val != 30) {
  print "Expected 30 ARP Misses. Received $temp_error_val\n";
  $total_errors++;
}

if ($total_errors==0) {
  print "SUCCESS!\n";
  exit 0;
} else {
  print "FAIL: $total_errors errors\n";
  exit 1;
}

