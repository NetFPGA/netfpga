#!/usr/bin/perl
# vim:set shiftwidth=2 softtabstop=2 expandtab:

#############################################################
# $Id: run 4297 2008-07-18 03:42:50Z g9coving $
#
# Test to verify that packets are correctly dropped at the output
# queues when the queues overflow.
#
# Revisions:
#
##############################################################

use strict;
use NF::RegressLib;
use NF::PacketLib;

use reg_defines_reference_nic;

use constant NUM_PKTS_PER_PORT => 500;
use constant PKT_SIZE =>          1514;

my @interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3");
nftest_init(\@ARGV, \@interfaces);

# Reset the NetFPGA
nftest_fpga_reset('nf2c0');

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

# Disable all output queues
nftest_regwrite('nf2c0', OQ_QUEUE_0_CTRL_REG(), 0x0);
nftest_regwrite('nf2c0', OQ_QUEUE_2_CTRL_REG(), 0x0);
nftest_regwrite('nf2c0', OQ_QUEUE_4_CTRL_REG(), 0x0);
nftest_regwrite('nf2c0', OQ_QUEUE_6_CTRL_REG(), 0x0);

my $total_errors = 0;

# Generate NUM_PKTS_PER_PORT packets to fill up the output queues
my @pkts;
for (my $i = 0; $i < 4; $i++) {
  print "Generating packets for nf2c$i...\n";
  my @portPkts = nftest_precreate_pkts(NUM_PKTS_PER_PORT, "", PKT_SIZE, PKT_SIZE);
  @pkts[$i] = \@portPkts;
}

# Send in the packets
print "Sending packets while output queues disabled...\n";
nftest_start(\@interfaces);
for (my $i = 0; $i < 4; $i++) {
  my $portPkts = $pkts[$i];
  foreach my $pkt (@$portPkts) {
    nftest_send("nf2c$i", $pkt);
    `usleep 250`;
  }
}

# Wait for a while
`sleep 2`;

# Verify that the correct number of packets have been received
for (my $i = 0; $i < 4; $i++) {
  my $pktsStored = nftest_regread('nf2c0',  OQ_QUEUE_0_NUM_PKTS_STORED_REG() + $i * 0x400);
  my $pktsDropped = nftest_regread('nf2c0', OQ_QUEUE_0_NUM_PKTS_DROPPED_REG() + $i * 0x400);
  my $pktsRemoved = nftest_regread('nf2c0', OQ_QUEUE_0_NUM_PKTS_REMOVED_REG() + $i * 0x400);

  my $bytesStored = nftest_regread('nf2c0',  OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG() + $i * 0x400);
  my $bytesRemoved = nftest_regread('nf2c0', OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG() + $i * 0x400);

  if ($pktsStored + $pktsDropped != NUM_PKTS_PER_PORT) {
    print "Error: packets stored plus dropped not equal to number sent\n";
    print "Packets Stored: $pktsStored   Dropped: $pktsDropped   Total:   " . $pktsStored + $pktsDropped . "\n";
    print "Expected: " . NUM_PKTS_PER_PORT . "\n";
    $total_errors++;
  }

  if ($pktsRemoved != 0) {
    print "Error: packets removed should be zero\n";
    print "Removed: $pktsRemoved\n";
    $total_errors++;
  }

  if ($pktsStored * PKT_SIZE != $bytesStored) {
    print "Error: bytes stored not equal to number expected\n";
    print "Bytes Stored: $bytesStored   Expected: " . $pktsStored * PKT_SIZE . "\n";
    $total_errors++;
  }

  # # Expect the packets (as they should come out after the queues are reenabled
  # if ($i < 2) {
  #   my $portPkts = $pkts[$i];
  #   for (my $j = 0; $j < $pktsStored; $j++) {
  #     my $pkt = $$portPkts[$j];
  #     nftest_expect("eth" . ($i + 1), $pkt);
  #   }
  # }
}

# Reenable output queues
print "Enabling output queues and verifying that queued packets are sent...\n";
nftest_regwrite('nf2c0', OQ_QUEUE_0_CTRL_REG(), 1 << OQ_ENABLE_SEND_BIT_NUM);
`sleep 1`;
nftest_regwrite('nf2c0', OQ_QUEUE_2_CTRL_REG(), 1 << OQ_ENABLE_SEND_BIT_NUM);
`sleep 1`;
nftest_regwrite('nf2c0', OQ_QUEUE_4_CTRL_REG(), 1 << OQ_ENABLE_SEND_BIT_NUM);
nftest_regwrite('nf2c0', OQ_QUEUE_6_CTRL_REG(), 1 << OQ_ENABLE_SEND_BIT_NUM);

# Wait a few seconds for the packets to drain
sleep 2;

# Verify that the correct number of packets have been received
for (my $i = 0; $i < 4; $i++) {
  my $pktsStored = nftest_regread('nf2c0', OQ_QUEUE_0_NUM_PKTS_STORED_REG() + $i * 0x400);
  my $pktsRemoved = nftest_regread('nf2c0', OQ_QUEUE_0_NUM_PKTS_REMOVED_REG() + $i * 0x400);

  my $bytesStored = nftest_regread('nf2c0', OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG() + $i * 0x400);
  my $bytesRemoved = nftest_regread('nf2c0', OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG() + $i * 0x400);

  if ($pktsStored != $pktsRemoved) {
    print "Error: packets stored not equal to packets removed\n";
    print "Packets Stored: $pktsStored   Removed: $pktsRemoved\n";
    $total_errors++;
  }

  if ($bytesStored != $bytesRemoved) {
    print "Error: bytes stored not equal to bytes removed\n";
    print "Bytes Stored: $bytesStored   Removed: $bytesRemoved\n";
    $total_errors++;
  }
}

# Send more packets to make sure that the queues are functioning
print "Sending additional packets to verify that they are transmitted...\n";
nftest_restart;
for (my $i = 0; $i < 2; $i++) {
  my $portPkts = $pkts[$i];
  foreach my $pkt (@$portPkts) {
    nftest_send("nf2c$i", $pkt);
    nftest_expect("nf2c$i", $pkt);
    `usleep 250`;
  }
}

# Wait a few seconds for transmit/receive to complete
`sleep 2`;

nftest_reset_phy();

# Finish the test and check how many packets are unmatched
my $unmatched_hoh = nftest_finish();
$total_errors += nftest_print_errors($unmatched_hoh);

# Print success/failure
if ($total_errors==0) {
  print "SUCCESS!\n";
	exit 0;
}
else {
  print "FAIL: $total_errors errors\n";
	exit 1;
}

