#!/usr/bin/perl
# Author: Sara Bolouki
# Date: 11/09/2007


use strict;
use NF::Base "projects/reference_router/lib/Perl5";
use NF::RegressLib;
use NF::PacketLib;
use RegressRouterLib;
use Time::HiRes qw (sleep gettimeofday tv_interval usleep);
use Switch;

use reg_defines_dram_router;

#-----------------------------------------------------------------------------
# main script params
my $internal_loopback = 0;
my $print_all_stats = 0;
my $run_length = 100; # seconds
my $print_interval = 1; # seconds
my $load_timeout = 5.0; # seconds - may need to be increased for small packets and/or slow system
my $expect = 0; # control whether expected packets are sent to TestLib.pm

my $NUM_PORTS = 4; # ports to send on
my $BUFFER_SIZE_PER_PORT = 512000; # bytes
my $len = 128;
my $desired_q_occ_fraction = .5;
my $desired_q_occ = $BUFFER_SIZE_PER_PORT / $len * $desired_q_occ_fraction;
print "desired q occ: ", $desired_q_occ, "\n";
#my $desired_q_occ = 200; # desired queue occupancy in number of packets
my $packets_to_loop = 255; # forwarding reps

my $num_2_32 = 4294967296; # 2 ^ 32;
#my $i = 0;
#my $routerMAC0 = "00:ca:fe:00:00:01";

my $total_errors = 0;

#-----------------------------------------------------------------------------
my @interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2");
nftest_init(\@ARGV,\@interfaces,);
nftest_start(\@interfaces);

nftest_fpga_reset('nf2c0');

sub get_dest_MAC {
	my $i = shift;
	my $i_plus_1 = $i + 1;
	if ($internal_loopback == 1) {
		return "00:ca:fe:00:00:0$i_plus_1";
	}
	else
	{
		if ($i == 0) { return "00:ca:fe:00:00:02"; }
		if ($i == 1) { return "00:ca:fe:00:00:01"; }
		if ($i == 2) { return "00:ca:fe:00:00:04"; }
		if ($i == 3) { return "00:ca:fe:00:00:03"; }
	}
}

sub get_q_num_pkts_reg {
	my $i = shift;
	if ($i == 0) { return OQ_QUEUE_0_NUM_PKTS_IN_Q(); }
	if ($i == 1) { return OQ_QUEUE_2_NUM_PKTS_IN_Q(); }
	if ($i == 2) { return OQ_QUEUE_4_NUM_PKTS_IN_Q(); }
	if ($i == 3) { return OQ_QUEUE_6_NUM_PKTS_IN_Q(); }
}

my $routerMAC0 = "00:ca:fe:00:00:01";
my $routerMAC1 = "00:ca:fe:00:00:02";
my $routerMAC2 = "00:ca:fe:00:00:03";
my $routerMAC3 = "00:ca:fe:00:00:04";

my $routerIP0 = "192.168.0.40";
my $routerIP1 = "192.168.1.40";
my $routerIP2 = "192.168.2.40";
my $routerIP3 = "192.168.3.40";

my $ALLSPFRouters = "224.0.0.5";

nftest_set_router_MAC ('nf2c0', $routerMAC0);
nftest_set_router_MAC ('nf2c1', $routerMAC1);
nftest_set_router_MAC ('nf2c2', $routerMAC2);
nftest_set_router_MAC ('nf2c3', $routerMAC3);

nftest_add_dst_ip_filter_entry ('nf2c0', 0, $routerIP0);
nftest_add_dst_ip_filter_entry ('nf2c0', 1, $routerIP1);
nftest_add_dst_ip_filter_entry ('nf2c0', 2, $routerIP2);
nftest_add_dst_ip_filter_entry ('nf2c0', 3, $routerIP3);
nftest_add_dst_ip_filter_entry ('nf2c0', 4, $ALLSPFRouters);


my $check_value;
# router mac0
$check_value = nftest_regread("nf2c0",  ROUTER_OP_LUT_MAC_0_HI_REG());
if ($check_value != 0xca) {$total_errors = $total_errors + 1;}
$check_value = nftest_regread("nf2c0", ROUTER_OP_LUT_MAC_0_LO_REG());
if ($check_value != 0xfe000001) {$total_errors = $total_errors + 1;}

# router mac1
$check_value = nftest_regread("nf2c0", ROUTER_OP_LUT_MAC_1_HI_REG());
if ($check_value != 0xca) {$total_errors = $total_errors + 1;}
$check_value = nftest_regread("nf2c0", ROUTER_OP_LUT_MAC_1_LO_REG());
if ($check_value != 0xfe000002) {$total_errors = $total_errors + 1;}

# router mac2
$check_value = nftest_regread("nf2c0", ROUTER_OP_LUT_MAC_2_HI_REG());
if ($check_value != 0xca) {$total_errors = $total_errors + 1;}
$check_value = nftest_regread("nf2c0", ROUTER_OP_LUT_MAC_2_LO_REG());
if ($check_value != 0xfe000003) {$total_errors = $total_errors + 1;}

# router mac3
$check_value = nftest_regread("nf2c0", ROUTER_OP_LUT_MAC_3_HI_REG());
if ($check_value != 0xca) {$total_errors = $total_errors + 1;}
$check_value = nftest_regread("nf2c0", ROUTER_OP_LUT_MAC_3_LO_REG());
if ($check_value != 0xfe000004) {$total_errors = $total_errors + 1;}

print "$total_errors\n";
# put all ports in internal_loopback mode if specified
if ($internal_loopback == 1) {
	nftest_phy_loopback('nf2c0');
	nftest_phy_loopback('nf2c1');
	nftest_phy_loopback('nf2c2');
	nftest_phy_loopback('nf2c3');
}

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

print "\n";
my $total_errors = 0;
# add LPM and ARP entries for each port
for (my $i = 0; $i < $NUM_PORTS; $i++) {

	my $i_plus_1 = $i + 1;
	my $subnetIP = "192.168.$i_plus_1.1";
	my $subnetMask = "255.255.255.225";
	my $nextHopIP = "192.168.5.$i_plus_1";
	my $outPort = 1 << (2 * $i);
	my $nextHopMAC = get_dest_MAC($i);

#	print "subnetIP:", $subnetIP, "\n";
#	print "nextHopIP:", $nextHopIP, "\n";
#	print "nextHopMAC:", $nextHopMAC, "\n";
#	print "outPort:", $outPort, "\n";

	# add an entry in the routing table
	nftest_add_LPM_table_entry ('nf2c0',
			    $i,
			    $subnetIP,
			    $subnetMask,
			    $nextHopIP,
			    $outPort);

	# add an entry in the ARP table
	nftest_add_ARP_table_entry('nf2c0',
			   $i,
			   $nextHopIP,
			   $nextHopMAC);
}
print "$total_errors\n";
# ARP table
for (my $i = 0; $i < 31; $i++){
        nftest_regwrite("nf2c0", ROUTER_OP_LUT_ARP_TABLE_RD_ADDR_REG(), $i);

        # ARP mac
        my $mac_hi = nftest_regread("nf2c0", ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG());
        my $mac_lo = nftest_regread("nf2c0", ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG());
        printf "arp row:%d arp mac:(%x%x)", $i, $mac_hi,$mac_lo;

	my $router_ip = nftest_regread("nf2c0", ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG());
        printf "  router_ip:(%x)\n", $router_ip;
	switch($i){
	case 0 	{if ($mac_hi!=0xca) {$total_errors = $total_errors + 1;}
		if ($mac_lo!=0xfe000002) {$total_errors = $total_errors + 1;}
		if ($router_ip!=0xc0a80501) {$total_errors = $total_errors + 1;}
		}
	case 1  {if ($mac_hi!=0xca) {$total_errors = $total_errors + 1;}
                if ($mac_lo!=0xfe000001) {$total_errors = $total_errors + 1;}
                if ($router_ip!=0xc0a80502) {$total_errors = $total_errors + 1;}
		}
	case 2  {if ($mac_hi!=0xca) {$total_errors = $total_errors + 1;}
                if ($mac_lo!=0xfe000004) {$total_errors = $total_errors + 1;}
                if ($router_ip!=0xc0a80503) {$total_errors = $total_errors + 1;}
	}
        case 3  {if ($mac_hi!=0xca) {$total_errors = $total_errors + 1;}
                if ($mac_lo!=0xfe000003) {$total_errors = $total_errors + 1;}
                if ($router_ip!=0xc0a80504) {$total_errors = $total_errors + 1;}
	}
        else    {if ($mac_hi!=0) {$total_errors = $total_errors + 1;}
                if ($mac_lo!=0) {$total_errors = $total_errors + 1;}
                if ($router_ip!=0) {$total_errors = $total_errors + 1;}
        }

	}


}

print "$total_errors\n";
# Routing table
for (my $i = 0; $i < 31; $i++){
	nftest_regwrite("nf2c0", ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG(), $i);

	# Router IP
	my $router_ip = nftest_regread("nf2c0", ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG());
	printf "  router_ip:(%x)", $router_ip;

	my $arp_port = nftest_regread("nf2c0", ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG());
        printf "output port:(%d)", $arp_port;

	my $next_hop_ip = nftest_regread("nf2c0", ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG());
        printf "  next hop ip:(%x)", $next_hop_ip;

	# Router subnet mask
	my $subnet_mask = nftest_regread("nf2c0" , ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG());
	printf "  subnet_mask:(%x)\n", $subnet_mask;
	#printf " port: (%d)\n",  1 << (2 * $i);
	#if ($arp_port !=  1 << (2 * $i) ) {$total_errors = $total_errors +1;}

	switch($i){
	case 0 {if ($router_ip!= 0xc0a80101) {$total_errors = $total_errors +1;}
                if ($subnet_mask != 0xffffffe1) {$total_errors = $total_errors +1;}
		if ($arp_port !=  1  ) {$total_errors = $total_errors +1;}
		if ($next_hop_ip != 0xc0a80501) {$total_errors = $total_errors +1;}
		}
	 case 1 {if ($router_ip!= 0xc0a80201) {$total_errors = $total_errors +1;}
                if ($subnet_mask != 0xffffffe1) {$total_errors = $total_errors +1;}
                if ($arp_port !=  4  ) {$total_errors = $total_errors +1;}
                if ($next_hop_ip != 0xc0a80502) {$total_errors = $total_errors +1;}
                }
	case 2 {if ($router_ip!= 0xc0a80301) {$total_errors = $total_errors +1;}
                if ($subnet_mask != 0xffffffe1) {$total_errors = $total_errors +1;}
                if ($next_hop_ip != 0xc0a80503) {$total_errors = $total_errors +1;}
                #if ($arp_port !=  16  ) {$total_errors = $total_errors +1;}

                }
        case 3 {if ($router_ip!= 0xc0a80401) {$total_errors = $total_errors +1;}
                if ($subnet_mask != 0xffffffe1) {$total_errors = $total_errors +1;}
                if ($next_hop_ip != 0xc0a80504) {$total_errors = $total_errors +1;}
                #if ($arp_port !=  64  ) {$total_errors = $total_errors +1;}

                }
        else {if ($router_ip!= 0) {$total_errors = $total_errors +1;}
                if ($subnet_mask != 0xffffffff) {$total_errors = $total_errors +1;}
                if ($next_hop_ip != 0) {$total_errors = $total_errors +1;}
                #if ($arp_port !=  0 ) {$total_errors = $total_errors +1;}
                }
	}
}
# IP filter
print "$total_errors\n";
for (my $i=0; $i<31; $i++){
	nftest_regwrite("nf2c0", ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR_REG(), $i);
	my $filter = nftest_regread("nf2c0", ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG());
	switch($i){
	  case 0{if ($filter !=0xc0a80028) {$total_errors = $total_errors +1;}}
	  case 1{if ($filter !=0xc0a80128) {$total_errors = $total_errors +1;}}
	  case 2{if ($filter !=0xc0a80228) {$total_errors = $total_errors +1;}}
	  case 3{if ($filter !=0xc0a80328) {$total_errors = $total_errors +1;}}
	  case 4{if ($filter !=0xe0000005) {$total_errors = $total_errors +1;}}
	    else {if ($filter !=0) {$total_errors = $total_errors +1;}}
	}
	printf "row:$i filter (%x)\n", $filter;
}



if ($total_errors==0) {
  print "SUCCESS!\n";
	exit 0;	my $TTL = 64;
}
else {
  print "FAIL: $total_errors errors\n";
	exit 1;
}
