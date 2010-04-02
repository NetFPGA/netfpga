#!/usr/bin/perl -w

use strict;
use NF::Base "projects/reference_router/lib/Perl5";
use NF::RegressLib;
use NF::PacketLib;
use RegressRouterLib;

use reg_defines_dram_router;

use constant NUM_PKTS => 100;

my @interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2");
nftest_init(\@ARGV,\@interfaces,);
nftest_start(\@interfaces,);

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

my $routerMAC0 = "00:ca:fe:00:00:01";
my $routerMAC1 = "00:ca:fe:00:00:02";
my $routerMAC2 = "00:ca:fe:00:00:03";
my $routerMAC3 = "00:ca:fe:00:00:04";

my $routerIP0 = "192.168.0.40";
my $routerIP1 = "192.168.1.40";
my $routerIP2 = "192.168.2.40";
my $routerIP3 = "192.168.3.40";

my $ALLSPFRouters = "224.0.0.5";

my $check_value;
my $total_errors = 0;
######### You should skip this section for tests with router SCONE
# Write the mac and IP addresses doesn't matter which of the nf2c0..3 you write to.
nftest_add_dst_ip_filter_entry ('nf2c0', 0, $routerIP0);
nftest_add_dst_ip_filter_entry ('nf2c0', 1, $routerIP1);
nftest_add_dst_ip_filter_entry ('nf2c0', 2, $routerIP2);
nftest_add_dst_ip_filter_entry ('nf2c0', 3, $routerIP3);
nftest_add_dst_ip_filter_entry ('nf2c0', 4, $ALLSPFRouters);

# For these it does matter which interface you write to
nftest_set_router_MAC ('nf2c0', $routerMAC0);
nftest_set_router_MAC ('nf2c1', $routerMAC1);
nftest_set_router_MAC ('nf2c2', $routerMAC2);
nftest_set_router_MAC ('nf2c3', $routerMAC3);
#########

# Put the two ports in loopback mode. Pkts going out will come back in on
# the same port
nftest_phy_loopback('nf2c2');
nftest_phy_loopback('nf2c3');

nftest_regread_expect('nf2c0', MDIO_PHY_0_CONTROL_REG(), 0x1140);
nftest_regread_expect('nf2c0', MDIO_PHY_1_CONTROL_REG(), 0x1140);
nftest_regread_expect('nf2c0', MDIO_PHY_2_CONTROL_REG(), 0x5140);
nftest_regread_expect('nf2c0', MDIO_PHY_3_CONTROL_REG(), 0x5140);

# set parameters
my $DA = $routerMAC0;
my $SA = "aa:bb:cc:dd:ee:ff";
my $TTL = 64;
my $DST_IP = "192.168.1.1";
my $SRC_IP = "192.168.0.1";;
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

my $num_precreated = 1000;
my $start_val = $MAC_hdr->length_in_bytes() + $IP_hdr->length_in_bytes()+1;

# precreate random sized packets
$MAC_hdr->DA($routerMAC0);
my @precreated0 = nftest_precreate_pkts($num_precreated,
                                        $MAC_hdr->packed . $IP_hdr->packed);
$MAC_hdr->DA($routerMAC1);
my @precreated1 = nftest_precreate_pkts($num_precreated,
                                        $MAC_hdr->packed . $IP_hdr->packed);
$MAC_hdr->DA($routerMAC2);
my @precreated2 = nftest_precreate_pkts($num_precreated,
                                        $MAC_hdr->packed . $IP_hdr->packed);
$MAC_hdr->DA($routerMAC3);
my @precreated3 = nftest_precreate_pkts($num_precreated,
                                        $MAC_hdr->packed . $IP_hdr->packed);

# reset counters
nftest_regwrite("nf2c0", MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG(), 0);

nftest_regwrite("nf2c0", MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_1_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED_REG(), 0);

nftest_regwrite("nf2c0", MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED_REG(), 0);

nftest_regwrite("nf2c0", MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0);
nftest_regwrite("nf2c0", MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED_REG(), 0);

nftest_regwrite("nf2c0", ROUTER_OP_LUT_NUM_CPU_PKTS_SENT_REG(), 0);
nftest_regwrite("nf2c0", ROUTER_OP_LUT_NUM_PKTS_FORWARDED_REG(), 0);

print "Sending now: \n";
my $pkt;
my @totalPktLengths = (0, 0, 0, 0);
# send 1 packets from ports nf2c0...nf2c3
for(my $i=0; $i<NUM_PKTS; $i++){
  print "$i \r";
  $pkt = $precreated0[int(rand($num_precreated))];
  $totalPktLengths[0] += length($pkt);
  nftest_send('nf2c0', $pkt);
  nftest_expect('eth1', $pkt);

  $pkt = $precreated1[int(rand($num_precreated))];
  $totalPktLengths[1] += length($pkt);
  nftest_send('nf2c1', $pkt);
  nftest_expect('eth2', $pkt);

  # packets are looped back and will be sent to the CPU due to an LPM miss
  $pkt = $precreated2[int(rand($num_precreated))];
  $totalPktLengths[2] += length($pkt);
  nftest_send('nf2c2', $pkt);
  nftest_expect('nf2c2', $pkt);

  $pkt = $precreated3[int(rand($num_precreated))];
  $totalPktLengths[3] += length($pkt);
  nftest_send('nf2c3', $pkt);
  nftest_expect('nf2c3', $pkt);
}

print "\n";
print "nf2c0 numBytes sent--->", $totalPktLengths[0], "\n";
print "nf2c1 numBytes sent--->", $totalPktLengths[1], "\n";
print "nf2c2 numBytes sent--->", $totalPktLengths[2], "\n";
print "nf2c3 numBytes sent--->", $totalPktLengths[3], "\n";


sleep 2;

my $unmatched_hoh = nftest_finish();
nftest_reset_phy();

#control registers
my $control_reg0 = nftest_regread("nf2c0", MAC_GRP_0_CONTROL_REG);
if ($control_reg0 !=0 ) {$total_errors= $total_errors + 1;}

my $control_reg1 = nftest_regread("nf2c0", MAC_GRP_1_CONTROL_REG);
if ($control_reg0 !=0 ) {$total_errors= $total_errors + 1;}

my $control_reg2 = nftest_regread("nf2c0", MAC_GRP_2_CONTROL_REG);
if ($control_reg0 !=0 ) {$total_errors= $total_errors + 1;}

my $control_reg3 = nftest_regread("nf2c0", MAC_GRP_3_CONTROL_REG);
if ($control_reg0 !=0 ) {$total_errors= $total_errors + 1};

###### QUEUE 0
$check_value = nftest_regread("nf2c0", MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG());
if ($check_value != NUM_PKTS ) {$total_errors= $total_errors + 1;print "MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT --> $check_value, Expecting--> NUM_PKTS\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG());
if ($check_value != 0 ) {$total_errors= $total_errors + 1; print "MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED --> $check_value, Expecting -->0\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG());
if ($check_value != $totalPktLengths[0]) {$total_errors= $total_errors + 1;print "MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED--> $check_value, Expecting--> $totalPktLengths[0]\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG());
if ($check_value != 0 ) {$total_errors= $total_errors + 1;print "MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED --> $check_value, Expecting --> 0\n"};

##### QUEUE 1
$check_value = nftest_regread("nf2c0", MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG());
if ($check_value != NUM_PKTS ) {$total_errors= $total_errors + 1;print "MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT --> $check_value, Expecting--> NUM_PKTS\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED_REG());
if ($check_value != 0 ) {$total_errors= $total_errors + 1; print "MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED --> $check_value, Expecting -->0\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED_REG());
if ($check_value != $totalPktLengths[1]) {$total_errors= $total_errors + 1;print " MAC_GRP_1_TX_QUEUE_NUM_BYTES_PUSHED--> $check_value, Expecting--> $totalPktLengths[0]\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_1_RX_QUEUE_NUM_BYTES_PUSHED_REG());
if ($check_value != 0 ) {$total_errors= $total_errors + 1;print "MAC_GRP_1_RX_QUEUE_NUM_BYTES_PUSHED --> $check_value, Expecting --> 0\n"};

##### QUEUE 2
$check_value = nftest_regread("nf2c0", MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG());
if ($check_value != NUM_PKTS ) {$total_errors= $total_errors + 1;print "MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT --> $check_value, Expecting--> NUM_PKTS\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED_REG());
if ($check_value != NUM_PKTS ) {$total_errors= $total_errors + 1; print "MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED --> $check_value, Expecting -->0\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED_REG());
if ($check_value != $totalPktLengths[2]) {$total_errors= $total_errors + 1;print " MAC_GRP_2_TX_QUEUE_NUM_BYTES_PUSHED--> $check_value, Expecting--> $totalPktLengths[2]\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED_REG());
if ($check_value != $totalPktLengths[2]) {$total_errors= $total_errors + 1;print "MAC_GRP_2_RX_QUEUE_NUM_BYTES_PUSHED --> $check_value, Expecting --> 0\n"};

##### QUEUE 3
$check_value = nftest_regread("nf2c0", MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG());
if ($check_value != NUM_PKTS ) {$total_errors= $total_errors + 1;print "MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT --> $check_value, Expecting--> NUM_PKTS\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED_REG());
if ($check_value != NUM_PKTS ) {$total_errors= $total_errors + 1; print "MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED --> $check_value, Expecting -->0\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED_REG());
if ($check_value != $totalPktLengths[3]) {$total_errors= $total_errors + 1;print " MAC_GRP_3_TX_QUEUE_NUM_BYTES_PUSHED--> $check_value, Expecting--> $totalPktLengths[0]\n"};

$check_value = nftest_regread("nf2c0", MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED_REG());
if ($check_value != $totalPktLengths[3]) {$total_errors= $total_errors + 1;print "MAC_GRP_3_RX_QUEUE_NUM_BYTES_PUSHED --> $check_value, Expecting --> 0\n"};




if ($total_errors==0) {
  print "Test PASSES\n";
  exit 0;
}
else {
  print "Test FAILED: $total_errors errors\n";
  exit 1;
}
