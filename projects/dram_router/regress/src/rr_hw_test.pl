#!/usr/bin/perl

use strict;
use NF::Base "projects/reference_router/lib/Perl5";
use NF::RegressLib;
use NF::PacketLib;
use RegressRouterLib;
use reg_defines_dram_router;

my $test_id = $ARGV[0];
my $NUM_PORTS = $ARGV[1];
my $NUM_PKTS = $ARGV[2];
if (($test_id == 2) || ($test_id == 3) || ($test_id == 4) || ($test_id == 5) || ($test_id == 8)) {
  print "Running test 2.1.$test_id for $NUM_PORTS ports with number of packets $NUM_PKTS \n";
} else {
  print "ERROR it is NOT my test \n";
  exit 1;
}
sleep 4;

my @interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2");
nftest_init(\@ARGV,\@interfaces,);
nftest_start(\@interfaces);

nftest_fpga_reset('nf2c0');

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

my $total_errors = 0;
my $temp_val = 0;

for (my $portid = 0; $portid < $NUM_PORTS ; $portid++) {
  # Clear the counters
  nftest_regwrite("nf2c0", ROUTER_OP_LUT_NUM_WRONG_DEST_REG(), 0);
  nftest_regwrite("nf2c0", ROUTER_OP_LUT_NUM_NON_IP_RCVD_REG(), 0);
  nftest_regwrite("nf2c0", ROUTER_OP_LUT_NUM_BAD_OPTS_VER_REG(), 0);
  nftest_regwrite("nf2c0", ROUTER_OP_LUT_NUM_BAD_TTLS_REG(), 0);
  nftest_regwrite("nf2c0", ROUTER_OP_LUT_NUM_BAD_CHKSUMS_REG(), 0);

  nftest_regwrite("nf2c0", ROUTER_OP_LUT_NUM_CPU_PKTS_SENT_REG(), 0);

  # set parameters
  my $DA = ($portid == 0) ? $routerMAC0 : $routerMAC1;
  my $SA = "aa:bb:cc:dd:ee:ff";
  my $EtherType = 0x800;
  my $TTL = 64;
  my $DST_IP = "192.168.2.1";	#not in the lpm table
  my $SRC_IP = "192.168.0.1";;
  my $VERSION = 0x4;
  my $nextHopMAC = "dd:55:dd:66:dd:77";

  # Wrong mac destination, test_id = 2
  if ($test_id == 2) {
    $DA = "00:ca:fe:00:00:11";
  }
  # Non IP packets, test_id = 3
  if ($test_id == 3) {
    $EtherType = 0x802;
  }
  # Non IP option or ip_ver not 4, test_id = 4
  if ($test_id == 4) {
    $VERSION = 5;
  }
  # IP packet with ttl <= 1, test_id = 5
  if ($test_id == 5) {
    $TTL = 0;
  }


  # create mac header
  my $MAC_hdr = NF::Ethernet_hdr->new(DA => $DA,
				       SA => $SA,
				       Ethertype => $EtherType
				      );

  #create IP header
  my $IP_hdr = NF::IP_hdr->new(ttl => $TTL,
				version => $VERSION,
				src_ip => $SRC_IP,
				dst_ip => $DST_IP
			       );

  # IP packet with back packet checksum, test_id = 8
  if ($test_id == 8) {
    $IP_hdr->checksum(0);
  }

  # precreate random packets
  my @portPkts = nftest_precreate_pkts($NUM_PKTS, $MAC_hdr->packed . $IP_hdr->packed);

  # loop for 300 packets
  for (my $i = 0; $i < $NUM_PKTS ; $i++) {
    # get packed packet string
    my $sent_pkt = $portPkts[int(rand($NUM_PKTS))];

    if ($portid == 0) {
      # send packet out of eth1->nf2c0
      nftest_send('eth1', $sent_pkt);
      if (($test_id == 3) || ($test_id == 4) || ($test_id == 5)) {
        nftest_expect('nf2c0', $sent_pkt);
      }
    } elsif ($portid == 1) {
      # send packet out of eth2->nf2c1
      nftest_send('eth2', $sent_pkt);
      if (($test_id == 3) || ($test_id == 4) || ($test_id == 5)) {
        nftest_expect('nf2c1', $sent_pkt);
      }
    } else {
      print "ERROR: Not a valid port \n";
    }
  }
  sleep 4;

  # Read the counters

  # Wrong mac destination, test_id = 2
  if ($test_id == 2) {
    $temp_val = nftest_regread_expect('nf2c0', ROUTER_OP_LUT_NUM_WRONG_DEST_REG(), $NUM_PKTS);
    # print "20 $temp_error_val \n";
    if ($temp_val != $NUM_PKTS) {
      print "Expected $NUM_PKTS Wrong mac destination packet. Received $temp_val\n";
      $total_errors++;
    }
  }

  # Non IP packets, test_id = 3
  if ($test_id == 3) {
    $temp_val = nftest_regread_expect('nf2c0', ROUTER_OP_LUT_NUM_NON_IP_RCVD_REG(), $NUM_PKTS);
    # print "0 $temp_error_val \n";
    if ($temp_val != $NUM_PKTS) {
      print "Expected $NUM_PKTS non IP Packets. Received $temp_val\n";
      $total_errors++;
    }
  }

  # Non IP option or ip_ver not 4, test_id = 4
  if ($test_id == 4) {
    $temp_val = nftest_regread_expect('nf2c0', ROUTER_OP_LUT_NUM_BAD_OPTS_VER_REG(), $NUM_PKTS);
    if ($temp_val != $NUM_PKTS) {
      print "Expected $NUM_PKTS non IP option Packets. Received $temp_val\n";
      $total_errors++;
    }
  }

  # IP packet with ttl <= 1, test_id = 5
  if ($test_id == 5) {
    $temp_val = nftest_regread_expect('nf2c0', ROUTER_OP_LUT_NUM_BAD_TTLS_REG(), $NUM_PKTS);
    if ($temp_val != $NUM_PKTS) {
      print "Expected $NUM_PKTS TTL < 1 Packets. Received $temp_val\n";
      $total_errors++;
    }
  }

  # IP packet with back packet checksum, test_id = 8
  if ($test_id == 8) {
    $temp_val = nftest_regread_expect('nf2c0', ROUTER_OP_LUT_NUM_BAD_CHKSUMS_REG(), $NUM_PKTS);
    if ($temp_val != $NUM_PKTS) {
      print "Expected $NUM_PKTS Bad IP Checksum Packets. Received $temp_val\n";
      $total_errors++;
    }

  }

}

#-------------------
my $unmatched_hoh = nftest_finish();
$total_errors += nftest_print_errors($unmatched_hoh);

# -------------

if ($total_errors==0) {
  print "SUCCESS!\n";
  exit 0;
} else {
  print "FAIL: $total_errors errors\n";
  exit 1;
}

