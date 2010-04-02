#!/usr/bin/perl

use strict;
use NF::RegressLib;
use NF::PacketLib;

use reg_defines_reference_nic;

use constant NUM_PKTS => 3000;

my @interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3");
nftest_init(\@ARGV,\@interfaces,);
nftest_start(\@interfaces);

# Put ports into loopback mode
nftest_phy_loopback('nf2c0');
nftest_phy_loopback('nf2c1');
nftest_phy_loopback('nf2c2');
nftest_phy_loopback('nf2c3');

nftest_regread_expect('nf2c0', MDIO_PHY_0_CONTROL_REG(), 0x5140);
nftest_regread_expect('nf2c0', MDIO_PHY_1_CONTROL_REG(), 0x5140);
nftest_regread_expect('nf2c0', MDIO_PHY_2_CONTROL_REG(), 0x5140);
nftest_regread_expect('nf2c0', MDIO_PHY_3_CONTROL_REG(), 0x5140);

`sleep 2`;

nftest_fpga_reset('nf2c0');

# set parameters
my $DA = "00:ca:fe:00:00:01";
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
$MAC_hdr->DA("00:ca:fe:00:00:01");
my @precreated0 = nftest_precreate_ip_pkts($num_precreated, $MAC_hdr, $IP_hdr);
$MAC_hdr->DA("00:ca:fe:00:00:02");
my @precreated1 = nftest_precreate_ip_pkts($num_precreated, $MAC_hdr, $IP_hdr);
$MAC_hdr->DA("00:ca:fe:00:00:03");
my @precreated2 = nftest_precreate_ip_pkts($num_precreated, $MAC_hdr, $IP_hdr);
$MAC_hdr->DA("00:ca:fe:00:00:04");
my @precreated3 = nftest_precreate_ip_pkts($num_precreated, $MAC_hdr, $IP_hdr);

print "Sending now: \n";
my $pkt;
my @totalPktLengths = (0, 0, 0, 0);
# send NUM_PKTS packets from ports nf2c0...nf2c3
for(my $i=0; $i<NUM_PKTS; $i++){
  print "$i \r";
  $pkt = $precreated0[int(rand($num_precreated))];
  $totalPktLengths[0] += length($pkt);
  nftest_send('nf2c0', $pkt);
  nftest_expect('nf2c0', $pkt);

  $pkt = $precreated1[int(rand($num_precreated))];
  $totalPktLengths[1] += length($pkt);
  nftest_send('nf2c1', $pkt);
  nftest_expect('nf2c1', $pkt);

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

`sleep 2`;

my $unmatched_hoh = nftest_finish();
nftest_reset_phy();

my $total_errors = 0;

print "Checking pkt errors\n";
$total_errors += nftest_print_errors($unmatched_hoh);

# check counter values
for (my $i = 0; $i < 4; $i++) {
        my $reg_data = 0;
        $reg_data = nftest_regread_expect("nf2c0", MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG() + $i * 0x40000, NUM_PKTS);

        if ($reg_data != NUM_PKTS) {
                $total_errors++;
                print "ERROR: MAC Queue $i counters are wrong\n";
                print "   Rx pkts stored: $reg_data     expected: " . NUM_PKTS . "\n";
        }

        $reg_data = nftest_regread_expect("nf2c0", MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG() + $i * 0x40000, NUM_PKTS);

        if ($reg_data != NUM_PKTS) {
                $total_errors++;
                print "ERROR: MAC Queue $i counters are wrong\n";
                print "   Tx pkts sent: $reg_data       expected: " . NUM_PKTS . "\n";
        }

        $reg_data = nftest_regread_expect("nf2c0", MAC_GRP_0_RX_QUEUE_NUM_BYTES_PUSHED_REG() + $i * 0x40000, $totalPktLengths[$i]);

        if ($reg_data != $totalPktLengths[$i]) {
                $total_errors++;
                print "ERROR: MAC Queue $i counters are wrong\n";
                print "   Rx bytes pushed: $reg_data    expected: " . $totalPktLengths[$i] . "\n";
        }

        $reg_data = nftest_regread_expect("nf2c0", MAC_GRP_0_TX_QUEUE_NUM_BYTES_PUSHED_REG() + $i * 0x40000, $totalPktLengths[$i]);

        if ($reg_data != $totalPktLengths[$i]) {
                $total_errors++;
                print "ERROR: MAC Queue $i counters are wrong\n";
                print "   Tx bytes pushed: $reg_data    expected: " . $totalPktLengths[$i] . "\n";
        }

}

if ($total_errors==0) {
  print "Test PASSES\n";
  exit 0;
}
else {
  print "Test FAILED: $total_errors errors\n";
  exit 1;
}
