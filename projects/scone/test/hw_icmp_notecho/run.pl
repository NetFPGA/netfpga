#!/usr/bin/perl
# Author: Sara Bolouki
# Date: 11/06/2007

# Objective:
# Ensure that ICMP packets that are echo request/reply are dropped


use Error qw(:try);
use IO::Socket;
use NF::RegressLib;
use NF::PacketLib;
use strict;

# Move to SCONE's root directory
chdir $ENV{'NF_DESIGN_DIR'}.'/sw' or die "Can't cd: $!\n";

my $pid;

# Fork off a process for SCONE
if ( !( $pid = fork ) ) {
  # Run SCONE from this process
  exec "./scone", "-r", "rtable.netfpga";
  die "Failed to launch SCONE: $!";
} else {
  my $exitCode = 1;
  try {
    # Run control from this process

    # Wait for router to initialize
    sleep(1);

    # launch PCAP listenting to eth1, eth2
    my @interfaces = ( "eth1", "eth2" );
    nftest_init( \@ARGV, \@interfaces );
    nftest_start( \@interfaces );

    my $nf2c0_mac = "00:00:00:00:00:01";
    my $nf2c1_mac = "00:00:00:00:00:02";
    my $bogus_mac0 = "aa:bb:cc:dd:ee:f0";
    my $bogus_mac1 = "ca:fe:f0:0d:00:00";

    my $nf2c0_ip = "192.168.0.2";
    my $nf2c1_ip = "192.168.1.2";
    my $bogus_ip0 = "192.168.0.100";
    my $bogus_ip1 = "192.168.1.100";
    my $ttl = 40;

    my $ETHTYPE_IP = 0x0800;
    my $ETHTYPE_ARP = 0x0806;

    my $MAC_hdr;
    my $IP_hdr;
    my $version;
    my $ip_hdr_len;
    my $pdu;
    my $ttl = 0x40;
    my $len = 100;
    my $start_val;
    my @data;
    my $sent_pkt;

    # Send an icmp packet that is NOT echo request/reply from eth1
    for (my $i = 0; $i < 256; $i++)
      {
	if (($i != 0) && ($i!=8)) # No echo request/reply
	  {
	    $MAC_hdr = NF::Ethernet_hdr->new(DA => $nf2c0_mac,
					      SA => $bogus_mac0,
					      Ethertype => $ETHTYPE_IP
					     );
	    # build IP header
	    $IP_hdr = NF::IP_hdr->new(ttl => $ttl,
				       proto => 0x01, # ICMP
				       src_ip => $bogus_ip1,
				       dst_ip => $nf2c0_ip
				      );
	    $IP_hdr->checksum(0);  # make sure its zero before we calculate it.
	    $IP_hdr->checksum($IP_hdr->calc_checksum);

	    # create packet filling.... (IP PDU)
	    $pdu = NF::PDU->new($len - $MAC_hdr->length_in_bytes() - $IP_hdr->
				 length_in_bytes() );
	    $start_val = $MAC_hdr->length_in_bytes() + $IP_hdr->length_in_bytes();
	    @data = (1..($len-$start_val));

	    for (@data) {$_ %= 100}
	    $data[0] = $i;   #Set ICMP type
	    $data[1] = 0x00; #Set ICMP code
	    $data[2] = 0x00;
	    $data[3] = 0x00;
	    # calculate checksum
	    my $checksum = 0;
	    my $word;
	    for my $j (0..(($len-$start_val)/2)-1) {
	      $word = ( $data[2*$j] << 8 ) | $data[2*$j+1] ;
	      $checksum += $word;
	      if ($checksum & 0xffff0000) {
		$checksum = ($checksum & 0xffff) + ($checksum >> 16);
	      }
	    }
	    $checksum = $checksum ^ 0xffff;
	    $data[2] = $checksum >> 8;
	    $data[3] = $checksum & 0xff;

	    $pdu->set_bytes(@data);

	    # get packed packet string
	    $sent_pkt = $MAC_hdr->packed . $IP_hdr->packed . $pdu->packed;

	    # send pkt eth1->nf2c0
	    nftest_send('eth1', $sent_pkt);
	  }
      }


    # Send an ARP reply
    my $pkt = NF::ARP_pkt->new_reply(
				      SA => $bogus_mac0,
				      DA => $nf2c1_mac,
				      SenderIpAddr => $bogus_ip0,
				      TargetIpAddr => $nf2c0_ip
				     );
    nftest_send( 'eth2', $pkt->packed);
    sleep(1);

    # Ignore OSPF Packets and ARP Requests
    nftest_ignore_ospf("eth1","eth2");
    nftest_ignore_arp_request("eth2");

    # Finish and print errors, if any
    my $total_errors = nftest_print_errors(nftest_finish());

    if ( $total_errors == 0 ) {
      print "SUCCESS!\n";
      $exitCode = 0;
    } else {
      print "FAIL: $total_errors errors\n";
      $exitCode = 1;
    }
  } catch Error with {
    # Catch and print any errors that occurred during control processing
    my $ex = shift;
    if ($ex) {
      print $ex->stringify();
    }
  } finally {
    # Ensure SCONE is killed even if we have an error
    kill 9, $pid;
    # Exit with the resulting exit code
    exit($exitCode);
  };
}
