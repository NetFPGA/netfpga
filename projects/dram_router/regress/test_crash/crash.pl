#!/usr/bin/perl
#/usr/pubsw/bin/perl -w
# Author: Brandon Heller
# Test to see if rawIP.pm can handle multiple sequential packet sends.
# On nf-test13, it crashes around 97-98 sequential sends.

# params:
#   --len [bytes]
#   --pkts [num]

use strict;
use NF::TestLib;
use NF::PacketLib;
use Getopt::Long;
use File::Copy;
use NF::Base;
use Time::HiRes qw (sleep gettimeofday tv_interval usleep);

my $len = 1496;
my $pkts_to_send = 10;

unless ( GetOptions (
			  "len=i" => \$len,
			  "pkts=i" => \$pkts_to_send,
		       		)
       )
{
	print "invalid options...exiting\n";
	exit 1;
}

my $routerMAC0 = "00:ca:fe:00:00:01";

my @interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2");
nftest_init(\@ARGV,\@interfaces,);
#nftest_start(\@interfaces);

nftest_set_router_MAC ("nf2c0", $routerMAC0);

nftest_phy_loopback("nf2c0");

my $sent_pkt;

# set parameters
my $DA = $routerMAC0;
my $SA = "aa:bb:cc:dd:ee:ff";
my $TTL = 1;
my $DST_IP = "192.168.1.1";
my $SRC_IP = "192.168.0.1";
my $nextHopMAC = $routerMAC0;

# create MAC header
my $MAC_hdr = NF::Ethernet_hdr->new(DA => $DA,
					     SA => $SA,
					     Ethertype => 0x800
			    		);
# create IP header
my $IP_hdr = NF::IP_hdr->new(ttl => $TTL,
				      src_ip => $SRC_IP,
				      dst_ip => $DST_IP,
				      dgram_len => $len - $MAC_hdr->length_in_bytes()
		    		 );

$IP_hdr->checksum(0);  # make sure its zero before we calculate it
$IP_hdr->checksum($IP_hdr->calc_checksum);

# create packet filling.... (IP PDU)
my $PDU = NF::PDU->new($len - $MAC_hdr->length_in_bytes() - $IP_hdr->length_in_bytes() );

# get packed packet string
my $sent_pkt = $MAC_hdr->packed . $IP_hdr->packed . $PDU->packed;

print "start time: ", scalar localtime, "\n";

my @start_time = gettimeofday();
for (my $j = 0; $j < $pkts_to_send; $j++) {
	nftest_send("nf2c0", $sent_pkt, 0);
}
my $sending_time = tv_interval(\@start_time);

print "completed in $sending_time seconds\n";

exit 1;

