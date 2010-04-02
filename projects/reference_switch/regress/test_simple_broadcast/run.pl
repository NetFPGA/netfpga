#!/usr/bin/perl

use strict;
use NF::RegressLib;
use NF::PacketLib;

use reg_defines_reference_switch;

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

nftest_fpga_reset('nf2c0');

my $num_broadcast = 20;

# loop for $num_broadcast packets from eth1 (broadcast)
for (my $i = 0; $i < $num_broadcast; $i++)
{
	# set parameters
	my $DA = $routerMAC0;
	my $SA = "aa:bb:cc:dd:ee:ff";
	my $TTL = 64;
	my $DST_IP = "192.168.1.1";
	my $SRC_IP = "192.168.0.1";
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

	$IP_hdr->checksum(0);  # make sure its zero before we calculate it.
	$IP_hdr->checksum($IP_hdr->calc_checksum);

	# create packet filling.... (IP PDU)
	my $PDU = NF::PDU->new($len - $MAC_hdr->length_in_bytes() - $IP_hdr->length_in_bytes() );
	my $start_val = $MAC_hdr->length_in_bytes() + $IP_hdr->length_in_bytes()+1;
	my @data = ($start_val..$len);
	for (@data) {$_ %= 100}
	$PDU->set_bytes(@data);

	# get packed packet string
	my $sent_pkt = $MAC_hdr->packed . $IP_hdr->packed . $PDU->packed;

	# send packet out of eth1->nf2c0
	nftest_send('eth1', $sent_pkt);
	nftest_expect('eth2', $sent_pkt);
  `usleep 500`;
}

my $total_errors = 0;
my $temp_error_val = 0;

sleep 1;
my $unmatched_hoh = nftest_finish();
$total_errors += nftest_print_errors($unmatched_hoh);

$temp_error_val = nftest_regread_expect('nf2c0', MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG(), $num_broadcast);

if ($temp_error_val != $num_broadcast) {
  print "ERROR: Num pkts sent from MAC 1 Tx Queue is $temp_error_val not $num_broadcast\n";
  $total_errors++;
}

$temp_error_val = nftest_regread_expect('nf2c0', MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG(), $num_broadcast);

if ($temp_error_val != $num_broadcast) {
  print "ERROR: Num pkts sent from MAC 2 Tx Queue is $temp_error_val not $num_broadcast\n";
  $total_errors++;
}

$temp_error_val = nftest_regread_expect('nf2c0', MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG(), $num_broadcast);

if ($temp_error_val != $num_broadcast) {
  print "ERROR: Num pkts sent from MAC 3 Tx Queue is $temp_error_val not $num_broadcast\n";
  $total_errors++;
}

$temp_error_val = nftest_regread_expect('nf2c0', SWITCH_OP_LUT_NUM_MISSES_REG(), $num_broadcast);

if ($temp_error_val != $num_broadcast) {
  print "ERROR: Num Switch LUT misses is $temp_error_val not $num_broadcast\n";
  $total_errors++;
}

if ($total_errors == 0) {
  print "SUCCESS!\n";
	exit 0;
}
else {
	print "Failed: $total_errors errors\n";
	exit 1;
}

