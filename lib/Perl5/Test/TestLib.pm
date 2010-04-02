#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
# $Id: TestLib.pm 3654 2008-04-24 06:20:21Z jnaous $
#
#
# NetFPGA test library for sending/receiving packets
#
#
# Invoke using: use Test::TestLib
#
# Module provides the ability send and receive packets
#
# Revisions:
#
##############################################################

package Test::TestLib;

use strict;
use Exporter;

use Test::Pcap;
use Test::PacketLib;

use threads;
use threads::shared;
use Net::RawIP;
use Getopt::Long;

use vars qw(@ISA @EXPORT);    # needed cos strict is on

@ISA    = ('Exporter');
@EXPORT = qw(
  &nftest_init
  &nftest_start
  &nftest_restart
  &nftest_send
  &nftest_expect
  &nftest_finish
  &nftest_get_unexpected
  &nftest_get_missing
  &nftest_precreate_pkts
  &nftest_precreate_ip_pkts
  &nftest_print_errors
  &nftest_process_iface_map
  &nftest_get_iface
  &nftest_pkt_cap_start
  &nftest_pkt_cap_finish
  &nftest_get_iface_name_map
  &nftest_get_pkt_hashes

  &nftest_ignore
  &nftest_ignore_ospf
  &nftest_ignore_igmp
  &nftest_ignore_mdns
  &nftest_ignore_arp_request

  &nftest_create_ICMP_echo_reply
  &nftest_start_vhosts
  &nftest_vhost_expect
  &nftest_print_vhost_errors
  &nftest_create_host
  &nftest_register_router
  &nftest_send_IP
  &nftest_create_IP
  &nftest_send_UDP
  &nftest_send_ARP_req
  &nftest_disable_ARP_reply
  &nftest_send_ICMP_echo_req
  &nftest_expect_ARP_exchange
  &nftest_expect_ARP_request
  &nftest_expect_ARP_reply
  &nftest_get_vhost_mac
  &nftest_expect_ICMP_host_unreach
  &nftest_expect_ICMP_port_unreach
  &nftest_expect_ICMP_proto_unreach
  &nftest_expect_ICMP_network_unreach
  &nftest_expect_ICMP_time_exceeded
);

use constant UNEXPECTED => 1;
use constant MISSING    => -1;

use constant ETH_DA_LEN      => 6;
use constant ETH_SA_LEN      => 6;
use constant ETH_TYPE_LEN    => 2;
use constant ETH_MIN_HDR_LEN => ETH_DA_LEN + ETH_SA_LEN + ETH_TYPE_LEN;

use constant MIN_PKT_LEN => 60;
use constant MAX_PKT_LEN => 1514;

use constant MODE_NON_VHOST => 1;
use constant MODE_VHOST     => 1;

my $mode : shared;

# Hash of received/expected packets
#
# Packets are keys
#   - Received packets increment the value
#   - Expected packets decrement the value
my %pktHashes : shared;
my %pktArrays : shared;

# Interface names
my %ifaceNameMap = ();

my @threads;

# Masks used to ignore packets
my %ignoreMasks;

# Header values to match in packets
my %ignoreValues;

my %rawIPs;



# ARP request/reply mask/data
my $arpMask;
my $arpReqPkt;
my $arpReplyPkt;

# IGMP packet
my $igmpMask;
my $igmpPkt;

# MDNS packet
my $mdnsMask;
my $mdnsPkt;

# OSPF hello mask/data
my $ospfMask;
my $ospfPkt;

# ICMP packet
my $icmpMask;
my $icmpPkt;

# ICMP echo
my $icmpEchoMask;
my $icmpEchoReqPkt;
my $icmpEchoReplyPkt;

# Create the masks
&create_masks();

# Virtual hosts
my %vhostsIPiface : shared;
my %vhostsIPmac : shared;
my %vhostsRouterIPs;
my %vhostsKnownIPs;
my %vhostsPendingPkts : shared;
my %vhostsARP : shared;
my %vhostsARPdisable : shared;
my %vhARPReqLog : shared;
my %vhARPRepLog : shared;

###############################################################
# Name: nftest_init
#
# Parses commandline arguments
#
# Arguments: argv_ref           reference to @ARGV
#            active_ports_ref   reference to list of port names
#                               to listen/send on
#
###############################################################
sub nftest_init {
	my ( $argv_ref, $active_ports_ref ) = @_;

	#  my %argv_hash = { @$argv_ref };

	foreach my $iface (@$active_ports_ref) {

		# add the interface with a default name
		$ifaceNameMap{$iface} = $iface;
	}

	#
	# Process arguments
	#

	my $help = '';
	my $mapFile;

	my @ARGV = @$argv_ref;
	unless (
		GetOptions(
			"help"  => \$help,
			"map=s" => \$mapFile
		)
		and ( $help eq '' )
	  )
	{
		usage();
		exit 1;
	}

	#
	# Verify that the mapfile exists
	#
	if ( defined($mapFile) ) {
		nftest_process_iface_map($mapFile);
	}

	# change the mappings according to command line args
	#  while (my ($name, $mapped_to) = each %argv_hash) {
	#    print "nftest_initialize: mapping $name to $mapped_to.\n";
	#    $ifaceNameMap{$name} = $mapped_to;
	#  }
}

###############################################################
# Name: nftest_start
#
# Initializes the receivers on the requested ports.
#
# Arguments: active_ports_ref   reference to list of port names
#                               to listen/send on
#
###############################################################
sub nftest_start {
	my ($active_ports_ref) = @_;

	@threads = ();

	lock($mode);
	$mode = MODE_NON_VHOST;


	foreach my $iface (@$active_ports_ref) {

		# Create the hash to store the received packets
		my $pkts = &share( {} );
		{
			lock %pktHashes;
			$pktHashes{$iface} = $pkts;
		}

		my $ifaceReal = $ifaceNameMap{$iface};

		# Create the capture thread
		push @threads, NF::Pcap::start( $ifaceReal, \&nftest_pkt_arrival, $iface );
	}

	# Sleep 2 seconds before returning to give threads time to launch
	# If you don't do this PCAP misses packets you send
	sleep(2);
}

###############################################################
# Name: nftest_restart
#
# Resets the packet hashes
#
###############################################################
sub nftest_restart {

	lock %pktHashes;

	my @ifaces = keys(%pktHashes);

	foreach my $iface (@ifaces) {

		# Create the hash to store the received packets
		my $pkts = &share( {} );
		{
			$pktHashes{$iface} = $pkts;
		}
	}
}

################################################################
# Name: nftest_pkt_arrival
#
# Callback function called when a packet arrives
#
# Arguments: dev      interface on which packet arrives
#            packet
#
# Return:
################################################################
sub nftest_pkt_arrival {
	my ( $devReal, $packet, $iface ) = @_;

	# Store the packet in the correct hash
	lock %pktHashes;
	if ( !defined( $pktHashes{$iface} ) ) {
		die "Not currently listening on device $iface. Make sure you called nftest_start before.\n";
	}
	my $pkts = $pktHashes{$iface};

	lock %{$pkts};
	if ( !defined( $$pkts{$packet} ) ) {
		$$pkts{$packet} = 1;
	}
	else {
		my $cnt = ++$$pkts{$packet};
		delete( $$pkts{$packet} ) if ( $cnt == 0 );
	}
}

###############################################################
# Name: nftest_send
# Subroutine to send a packet out an interface
# Arguments: ifaceName string
#            frame     (packed string representation of packet)
#            expect    optional parameter specifying whether to
#                      "expect" the packet
#
###############################################################
sub nftest_send {
	my ( $ifaceName, $frame, $expect ) = @_;

	# Set the expect flag if it's not already set
	$expect = 1 if ( !defined($expect) );

	# Check that the interface is valid
	my $iface = getIface($ifaceName);

	# Check the length of the frame
	if ( length($frame) < ETH_MIN_HDR_LEN ) {
		die "Invalid frame data. Must be at least " . ETH_MIN_HDR_LEN . " bytes";
	}

	# Set the DA and SA
	#$iface->ethset(
	#   source =>  substr($frame, ETH_DA_LEN, ETH_SA_LEN),
	#   dest =>    substr($frame, 0, ETH_DA_LEN)
	#);
	$iface->{ethpack} = substr( $frame, 0, ETH_MIN_HDR_LEN );

	# add the packet to the expected queue since it will be caught on the way out
	nftest_expect( $ifaceName, $frame, 1 ) if $expect;

	# Send the packet
	$iface->send_eth_frame(
		substr( $frame, ETH_DA_LEN + ETH_SA_LEN, length($frame) - ETH_DA_LEN + ETH_SA_LEN ),
		0, 1 );
}

#####################################################################
# Name: nf2_expect
# Notify the capture module that we're expecting a packet
#
# Arguments: device
#            pkt
#
#####################################################################
sub nftest_expect {
	my ( $dev, $pkt, $noPad ) = @_;

	my $pkts;

	$noPad = 0 if ( !defined($noPad) );

	# Update the packet length if necessary
	my $len = length($pkt);
	if ( $len < MIN_PKT_LEN && !$noPad ) {
		$pkt .= pack( "C*", (0) x ( MIN_PKT_LEN - $len ) );
	}

	# Verify that something is listening on the requested port
	{
		lock %pktHashes;
		if ( !defined( $pktHashes{$dev} ) ) {
			die
			  "Not currently listening on device $dev. Make sure you called nftest_start before.\n";
		}
		$pkts = $pktHashes{$dev};
	}

	# Record the packet
	lock %{$pkts};
	if ( !defined( $$pkts{$pkt} ) ) {
		$$pkts{$pkt} = -1;
	}
	else {
		$$pkts{$pkt}--;
		delete( $$pkts{$pkt} ) if ( $$pkts{$pkt} == 0 );
	}

}

#####################################################################
# Name: nftest_get_unexpected
# Get the unexpected packets that arrived on a given port
#
# Arguments: dev
#####################################################################
sub nftest_get_unexpected {
	my ($dev) = @_;

	return get_pkts( $dev, UNEXPECTED );
}

#####################################################################
# Name: nftest_get_missing
# Get the unexpected packets that arrived on a given port
#
# Arguments: dev
#####################################################################
sub nftest_get_missing {
	my ($dev) = @_;

	return get_pkts( $dev, MISSING );
}

#####################################################################
# Name: get_pkts
# Get the unexpected or missing packets that arrived on a given port
#
# Arguments: dev
#            type: MISSING/UNEXPECTED
#####################################################################
sub get_pkts {
	my ( $dev, $type ) = @_;

	my @pkts;

	# Verify that something is listening on the requested port
	if ( !defined( $pktHashes{$dev} ) ) {
		die "Not currently listening on device $dev. Make sure you called nftest_start before.\n";
	}

	# Work out which packets were unexpected
	my $pkts = $pktHashes{$dev};
	foreach my $pkt ( keys(%$pkts) ) {
		for ( my $i = 0 ; $i < $$pkts{$pkt} * $type ; $i++ ) {
			push @pkts, $pkt;
		}
	}

	return @pkts;
}

###############################################################
# Name: getIface
# Get the Net::RawIP object associated with an interface
# Arguments: iface string
# Return: Net::RawIP object
###############################################################
sub getIface {
	my $ifaceName = shift;

	die "Interface $ifaceName is not active\n" unless defined $ifaceNameMap{$ifaceName};

	# Check if the object already exists
	if ( exists( $rawIPs{$ifaceName} ) ) {
		return $rawIPs{$ifaceName};
	}

	# Convert the values to strings and create the object
	$rawIPs{$ifaceName} = Net::RawIP->new;
	$rawIPs{$ifaceName}->ethnew( $ifaceNameMap{$ifaceName} );
	return $rawIPs{$ifaceName};
}

###############################################################
# Name: nftest_finish
# Stops listening to the interfaces, and returns to the user
# the hash of hashes of unmatched packets so she can check them
# as she wishes.
# Arguments:
# Returns: unmatched_pkts_hashes reference to hash of hashes
###############################################################
sub nftest_finish {

	# signal done
	NF::Pcap::finish();

	foreach my $thread (@threads) {
		$thread->join();
	}

	my $i;
	foreach my $ifaceName ( keys %ignoreMasks ) {
		foreach my $pkt ( keys %{ $pktHashes{$ifaceName} } ) {
			my $ignoreMask  = $ignoreMasks{$ifaceName};
			my $ignoreValue = $ignoreValues{$ifaceName};
			for ( $i = 0 ; $i < scalar(@$ignoreMask) ; $i++ ) {
				if ( ( $pkt & $ignoreMask->[$i] ) eq ( $ignoreValue->[$i] & $ignoreMask->[$i] ) ) {
					delete $pktHashes{$ifaceName}->{$pkt};
				}
			}
		}
	}

	return \%pktHashes;
}

###############################################################
# Name: nftest_ignore
# sets a mask for packets to ignore. The check is done at the
# beginning of packets.
# Arguments: $ifaceName string containing name of interface
#            $mask      packed string specifying bits to match
#            $values    packed string specifying values to match
# Returns:
###############################################################
sub nftest_ignore {
	my $ifaceName = shift;

	die "Couldn't find interface $ifaceName.\n" unless defined $ifaceNameMap{$ifaceName};

	if ( !defined $ignoreMasks{$ifaceName} ) {
		$ignoreMasks{$ifaceName}  = [];
		$ignoreValues{$ifaceName} = [];
	}

	push @{ $ignoreMasks{$ifaceName} },  shift;
	push @{ $ignoreValues{$ifaceName} }, shift;
}

###############################################################
# Name: nftest_precreate_pkts
# creates a list of random sized packets including min and max
# using the predefined given packed headers and a pdu of random
# size.
# Arguments: $num_precreated_pkts int number of packets to precreate
#            $header              packed of headers to add
#            $minlen              minimum pkt len (optional)
#            $maxlen              maximum pkt len (optional)
# Returns: list of packed packets
###############################################################
sub nftest_precreate_pkts {
	my ( $num_precreated, $header, $minlen, $maxlen ) = @_;

	die "Need to supply number of packets to pre-create.\n" if ( !defined $num_precreated );

	$minlen = MIN_PKT_LEN if ( !defined($minlen) );
	$minlen = MIN_PKT_LEN if ( $minlen < MIN_PKT_LEN );

	$maxlen = MAX_PKT_LEN if ( !defined($maxlen) );
	$maxlen = MAX_PKT_LEN if ( $maxlen > MAX_PKT_LEN );

	my @precreated;

	# create packets
	for ( my $i = 0 ; $i < $num_precreated - 2 ; $i++ ) {
		my $len = int( rand( $maxlen - $minlen + 1 ) ) + $minlen;
		push @precreated, gen_random_pkt( $len, $header );
	}

	# precreate min size and max size packets
	push @precreated, gen_random_pkt( $minlen, $header );
	push @precreated, gen_random_pkt( $maxlen, $header );

	return @precreated;

}

###############################################################
# Name: nftest_precreate_ip_pkts
# creates a list of random sized ip packets including min and max
# using the predefined headers and a pdu of random size.
#
# Arguments: $num_precreated_pkts int number of packets to precreate
#            $mac_hdr             MAC header
#            $ip_hdr              IP header
#            $minlen              minimum pkt len (optional)
#            $maxlen              maximum pkt len (optional)
# Returns: list of packed packets
###############################################################
sub nftest_precreate_ip_pkts {
	my ( $num_precreated, $mac_hdr, $ip_hdr, $minlen, $maxlen ) = @_;

	die "Need to supply number of packets to pre-create.\n" if ( !defined $num_precreated );

	$minlen = MIN_PKT_LEN if ( !defined($minlen) );
	$minlen = MIN_PKT_LEN if ( $minlen < MIN_PKT_LEN );

	$maxlen = MAX_PKT_LEN if ( !defined($maxlen) );
	$maxlen = MAX_PKT_LEN if ( $maxlen > MAX_PKT_LEN );

	my @precreated;

	# create packets
	for ( my $i = 0 ; $i < $num_precreated - 2 ; $i++ ) {
		my $len = int( rand( $maxlen - $minlen + 1 ) ) + $minlen;
		my $PDU = NF::PDU->new($len - $mac_hdr->length_in_bytes() - $ip_hdr->length_in_bytes() );
		$ip_hdr->dgram_len($len - $mac_hdr->length_in_bytes() );
		#$PDU->set_bytes(gen_random_payload($len - $mac_hdr->length_in_bytes() - $ip_hdr->length_in_bytes() ) );
		push @precreated, $mac_hdr->packed . $ip_hdr->packed .
			gen_random_payload($len - $mac_hdr->length_in_bytes() - $ip_hdr->length_in_bytes() );
	}

	# precreate min size and max size packets
	my $PDU;
        $PDU = NF::PDU->new($minlen - $mac_hdr->length_in_bytes() - $ip_hdr->length_in_bytes() );
	$ip_hdr->dgram_len($minlen - $mac_hdr->length_in_bytes() );
	push @precreated, $mac_hdr->packed . $ip_hdr->packed .
		gen_random_payload($minlen - $mac_hdr->length_in_bytes() - $ip_hdr->length_in_bytes() );

	$PDU = NF::PDU->new($maxlen - $mac_hdr->length_in_bytes() - $ip_hdr->length_in_bytes() );
	$ip_hdr->dgram_len($maxlen - $mac_hdr->length_in_bytes() );
	push @precreated, $mac_hdr->packed . $ip_hdr->packed .
		gen_random_payload($maxlen - $mac_hdr->length_in_bytes() - $ip_hdr->length_in_bytes() );

	return @precreated;
}

###############################################################
# Name: gen_random_pkt
# Generate a random pkt
# Arguments: $length    length of packet data
#            $header    optional header to include with packet
# Returns: random packet data as a packed string
###############################################################
sub gen_random_pkt {
	my ( $length, $header ) = @_;

	$header = "" if ( !defined($header) );

	# Set the Ethertype to something somewhat reasonable
	if ( length($header) < ETH_MIN_HDR_LEN ) {
		my $pkt = $header . gen_random_payload( $length - length($header) );
		$pkt =
		    substr( $pkt, 0, ETH_DA_LEN + ETH_SA_LEN )
		  . pack( 'H*', 'FFFF' )
		  . substr( $pkt, ETH_MIN_HDR_LEN, $length - ETH_MIN_HDR_LEN );
		return $pkt;
	}
	else {
		return $header . gen_random_payload( $length - length($header) );
	}
}

###############################################################
# Name: gen_random_payload
# Generate a random payload
# Note: If the length is < 0 it returns an empty array
# Arguments: $length    length of packet data
# Returns: random payload data as a packed string
###############################################################
sub gen_random_payload {
	my $length = shift;

	if ( $length > 0 ) {
		return join( '', ( map { chr( int( rand(256) ) ) } ( 1 .. $length ) ) );
	}
	else {
		return ();
	}
}

###############################################################
# Name: nftest_print_errors
# Print the errors (unexpected/missing packets)
# Arguments: $errors    Hash of erroneous packets
# Returns: total number of errors
###############################################################
sub nftest_print_errors {
	my $errors = shift;

	my $total_errors = 0;

	# Print out the unmatched packets
	while ( my ( $ifacename, $ref ) = each(%$errors) ) {

		# See if we actually have errors
		my $ifaceTotal = scalar( keys(%$ref) );
		if ( $ifaceTotal > 0 ) {
			print "Errors seen on $ifacename:\n";
		}

		my $ifaceCnt    = 0;
		my $ifaceErrors = 0;
		while ( my ( $pkt, $count ) = each(%$ref) ) {
			$ifaceCnt++;

			use bytes;
			my $packet_len = length($pkt);
			no bytes;

			my $unpacked_pkt = unpack( 'H*', $pkt );

			if ( $count < 0 ) {
				$count = -$count;
				print "Missing packet len: $packet_len with count $count:\n$unpacked_pkt\n"
				  if ( $ifaceCnt < 4 );
			}
			else {
				print "Unexpected packets len: $packet_len with count $count:\n$unpacked_pkt\n"
				  if ( $ifaceCnt < 4 );
			}
			print "Skipping remaining errors on $ifacename...\n" if ( $ifaceCnt == 4 );
			$ifaceErrors  += $count;
			$total_errors += $count;
		}
		print "Total: $ifaceErrors on $ifacename\n\n" if ( $ifaceTotal > 0 );
	}

	return $total_errors;
}



###############################################################
# Name: nftest_ignore_ospf
# Ignore OSPF packets in given interfaces
# Arguments: @interfaces  List of interfaces to ignore OSPF packets
# Returns:
###############################################################
sub nftest_ignore_ospf {
	my (@interfaces) = @_;

	foreach my $iface (@interfaces) {
		nftest_ignore( $iface, $ospfMask, $ospfPkt );
	}
}

###############################################################
# Name: nftest_ignore_mdns
# Ignore MDNS packets in given interfaces
# Arguments: @interfaces  List of interfaces to ignore MDNS packets
# Returns:
###############################################################
sub nftest_ignore_mdns {
	my (@interfaces) = @_;

	foreach my $iface (@interfaces) {
		nftest_ignore( $iface, $mdnsMask, $mdnsPkt );
	}
}

###############################################################
# Name: nftest_ignore_igmp
# Ignore IGMP packets in given interfaces
# Arguments: @interfaces  List of interfaces to ignore IGMP packets
# Returns:
###############################################################
sub nftest_ignore_igmp {
	my (@interfaces) = @_;

	foreach my $iface (@interfaces) {
		nftest_ignore( $iface, $igmpMask, $igmpPkt );
	}
}

###############################################################
# Name: nftest_ignore_arp_request
# Ignore ARP request packets in given interfaces
# Arguments: @interfaces  List of interfaces to ignore ARP request packets
# Returns:
###############################################################
sub nftest_ignore_arp_request {
	my (@interfaces) = @_;

	foreach my $iface (@interfaces) {
		nftest_ignore( $iface, $arpMask, $arpReqPkt );
	}
}

###############################################################
# Name: validateIP
# Validate an IP address
# Arguments: ip     Host's IP address
# Returns: value indicating success
###############################################################
sub validateIP {
	my $mac = shift;

	if ( !( $mac =~ /^(\d+).(\d+).(\d+).(\d+)$/ ) ) {
		return 0;
	}

	foreach my $val ( $1, $2, $3, $4 ) {
		return 0 if ( $val < 0 || $val > 255 );
	}

	return 1;
}

###############################################################
# Name: validateMAC
# Validate a MAC address
# Arguments: mac     Host's MAC address
# Returns: value indicating success
###############################################################
sub validateMAC {
	my $mac = shift;

	return ( $mac =~ /^(([0-9a-f]){2}:){5}([0-9a-f]){2}$/i );
}



###############################################################
# Name: isOspfHello
# Check if a packet is an OSPF hello
# Arguments: pkt     Packet
# Returns: 1 = OSPF hello
###############################################################
sub isOspfHello {
	my $pkt = shift;

	return ( ( $pkt & $ospfMask ) eq ( $ospfPkt & $ospfMask ) );
}

###############################################################
# Name: isArpReq
# Check if a packet is an ARP request
# Arguments: pkt     Packet
# Returns: 1 = ARP request
###############################################################
sub isArpReq {
	my $pkt = shift;

	return ( ( $pkt & $arpMask ) eq ( $arpReqPkt & $arpMask ) );
}

###############################################################
# Name: isArpReply
# Check if a packet is an ARP reply
# Arguments: pkt     Packet
# Returns: 1 = ARP reply
###############################################################
sub isArpReply {
	my $pkt = shift;

	return ( ( $pkt & $arpMask ) eq ( $arpReplyPkt & $arpMask ) );
}

###############################################################
# Name: isICMP
# Check if a packet is an ICMP packet
# Arguments: pkt     Packet
# Returns: 1 = ICMP packet
###############################################################
sub isICMP {
	my $pkt = shift;

	return ( ( $pkt & $icmpMask ) eq ( $icmpPkt & $icmpMask ) );
}


###############################################################
# Name: create_masks
# Create the various masks
# Arguments:
# Returns:
###############################################################
sub create_masks {

	# ARP request/reply mask/data
	$arpMask = NF::ARP_pkt->new(
		force     => 1,
		Ethertype => 0xffff,
		Op        => NF::ARP->ARP_OP_MASK
	)->packed();

	$arpReqPkt = NF::ARP_pkt->new( Op => NF::ARP->ARP_REQUEST )->packed();

	$arpReplyPkt = NF::ARP_pkt->new( Op => NF::ARP->ARP_REPLY )->packed();

	#MDNS Mask
	$mdnsMask = NF::IP_pkt->new(
		force      => 1,
		DA         => "00:00:00:00:00:00",
		dst_ip     => "255.255.255.255",
		Ethertype  => 0xffff,
		version    => 0x0,
		ip_hdr_len => 0x0,
		proto      => 0x00,
		dgram_len  => 0x0,
		checksum   => 0x0,
	)->packed();

	$mdnsPkt = NF::IP_pkt->new(
		dst_ip    => "224.0.0.251",
		Ethertype => 0x0800,
	)->packed();

	#IGMP Mask
	$igmpMask = NF::IP_pkt->new(
		force      => 1,
		DA         => "00:00:00:00:00:00",
		dst_ip     => "255.255.255.255",
		Ethertype  => 0xffff,
		version    => 0x0,
		ip_hdr_len => 0x0,
		proto      => 0x00,
		dgram_len  => 0x0,
		checksum   => 0x0,
	)->packed();

	$igmpPkt = NF::IP_pkt->new(
		dst_ip    => "224.0.0.22",
		Ethertype => 0x0800,
	)->packed();

	# OSPF hello mask/data
	$ospfMask = NF::IP_pkt->new(
		force      => 1,
		DA         => "ff:ff:ff:ff:ff:ff",
		dst_ip     => "255.255.255.255",
		Ethertype  => 0xffff,
		version    => 0xf,
		ip_hdr_len => 0x0,
		proto      => 0xFF,
		dgram_len  => 0x0,
		checksum   => 0x0,
	)->packed();

	$ospfPkt = NF::IP_pkt->new(
		DA     => "ff:ff:ff:ff:ff:ff",
		dst_ip => "224.0.0.5",
		proto  => 0x59,
	)->packed();

	# ICMP packet
	$icmpMask = NF::IP_pkt->new(
		force      => 1,
		Ethertype  => 0xffff,
		version    => 0xf,
		ip_hdr_len => 0x0,
		proto      => 0xFF,
		dgram_len  => 0x0,
		ttl        => 0x0,
		checksum   => 0x0,
	)->packed();

	$icmpPkt = NF::IP_pkt->new( proto => 0x01, )->packed();

	# ICMP echo request
	$icmpEchoMask = NF::ICMP_pkt->new(
		force         => 1,
		Ethertype     => 0xffff,
		version       => 0xf,
		ip_hdr_len    => 0x0,
		proto         => 0xFF,
		dgram_len     => 0x0,
		ttl           => 0x0,
		checksum      => 0x0,
		ICMP_checksum => 0x0,
		Type          => 0xff,
	);

	$icmpEchoReqPkt = NF::ICMP_pkt->new( Type => NF::ICMP->ECHO_REQ, )->packed();

	$icmpEchoReplyPkt = NF::ICMP_pkt->new( Type => NF::ICMP->ECHO_REP, )->packed();
}

###############################################################
# Name: nftest_create_ICMP_echo_reply
# Generate an ICMP echo reply message
# Arguments: req      ICMP echo request
# Returns: ICMP echo reply message
###############################################################
sub nftest_create_ICMP_echo_reply {
	my $req = shift;

	return NF::ICMP_pkt->new_echo_reply( Request => $req );
}



###############################################################
# Name: nftest_process_iface_map
#
# Read a map file that maps interfaces
#
###############################################################
sub nftest_process_iface_map {
	my $mapFile = shift;

	# Verify the precence of the mapfile
	if ( !-f $mapFile ) {
		die("Cannot locate interface map file $mapFile");
	}

	open MAPFILE, $mapFile;
	while (<MAPFILE>) {
		chomp;

		# Remove comments and leading white space
		s/#.*//;
		s/^\s\+//;

		# Skip blank lines
		next if /^$/;

		# Work out if we've got something that looks like a mapping
		if (/^(\w+):\s*(\w+)$/) {
			$ifaceNameMap{$1} = $2;
		}
	}
	close MAPFILE;
}

###############################################################
# Name: nftest_get_iface
#
# Get an interface (may be mapped)
#
###############################################################
sub nftest_get_iface {
	my $iface = shift;

	if ( defined( $ifaceNameMap{$iface} ) ) {
		return $ifaceNameMap{$iface};
	}
	else {
		return $iface;
	}
}

###############################################################
# Name: nftest_pkt_cap_start
#
# Initializes the receivers on the requested ports.
#
# Arguments: active_ports_ref   reference to list of port names
#                               to listen/send on
#
###############################################################
sub nftest_pkt_cap_start {
  my ($active_ports_ref) = @_;

  @threads = ();

  lock($mode);
  $mode = MODE_NON_VHOST;

  foreach my $iface (@$active_ports_ref) {
    # Create the hash to store the received packets
    my $pkts = &share( [] );
    {
      lock %pktArrays;
      $pktArrays{$iface} = $pkts;
    }

    my $ifaceReal = $ifaceNameMap{$iface};

    # Create the capture thread
    push @threads, NF::Pcap::start($ifaceReal, \&nftest_pkt_cap_arrival, $iface);
  }

  # Sleep 2 seconds before returning to give threads time to launch
  # If you don't do this PCAP misses packets you send
  sleep(2);
}

################################################################
# Name: nftest_pkt_cap_arrival
#
# Callback function called when a packet arrives
#
# Arguments: dev      interface on which packet arrives
#            packet
#
# Return:
################################################################
sub nftest_pkt_cap_arrival {
  my ($devReal, $packet, $iface) = @_;

  # Store the packet in the correct hash
  lock %pktArrays;
  if (!defined($pktArrays{$iface})) {
    die "Not currently listening on device $iface. Make sure you called nftest_start before.\n";
  }

  push @{ $pktArrays{$iface} }, $packet;

  #print "after\n";
  #my @temp = @{ $pktArrays{"eth1"} };
  #print @temp;
  #print "\n";
}

###############################################################
# Name: nftest_pkt_cap_finish
# Stops listening to the interfaces, and returns to the user
# the hash of hashes of unmatched packets so she can check them
# as she wishes.
# Arguments:
# Returns: unmatched_pkts_hashes reference to hash of hashes
###############################################################
sub nftest_pkt_cap_finish {
  # signal done
  NF::Pcap::finish();

  foreach my $thread (@threads) {
    $thread->join();
  }

  #for my $intface ( keys %pktArrays ) {
  #  print "$intface: @{ $pktArrays{$intface} }\n";
  #}

  return %pktArrays;
}

###############################################################
# Name: nftest_get_iface_name_map
#
# Get copy of iface_name_map hash
#
#############################################################
sub nftest_get_iface_name_map {
	return %ifaceNameMap;
}

###############################################################
# Name: nftest_get_iface_name_map
#
# Get copy of pktHashes hash
#
#############################################################
sub nftest_get_pkt_hashes {
	return %pktHashes;
}

#***********************

###############################################################
# Name: nftest_start_vhosts
#
# Initializes the receivers on the requested ports for a virtual
# host setup
#
# Arguments: active_ports_ref   reference to list of port names
#                               to listen/send on
#
###############################################################
sub nftest_start_vhosts {
	my ($active_ports_ref) = @_;

	@threads = ();

	lock($mode);
	$mode = MODE_VHOST;

	foreach my $iface (@$active_ports_ref) {

		# Create the hash to store the received packets
		my $pkts = &share( {} );
		{
			lock %pktHashes;
			$pktHashes{$iface} = $pkts;
		}

	    my %ifaceNameMap = nftest_get_iface_name_map();
		my $ifaceReal = $ifaceNameMap{$iface};

		# Create the capture thread
		push @threads, NF::Pcap::start( $ifaceReal, \&nftest_vhost_pkt_arrival, $iface );
	}

	# Sleep 2 seconds before returning to give threads time to launch
	# If you don't do this PCAP misses packets you send
	sleep(2);
}

################################################################
# Name: nftest_vhost_pkt_arrival
#
# Callback function called when a packet arrives
#
# Arguments: dev      interface on which packet arrives
#            packet
#
# Return:
################################################################
sub nftest_vhost_pkt_arrival {
	my ( $devReal, $packet, $iface ) = @_;

	# Work out if what sort of packet we're dealing with
	if ( isArpReq($packet) ) {

		#print "Arp req: " . unpack('H*', substr($packet, 0, 32)) . "\n";
		processArpRequest( $iface, $packet );
	}
	elsif ( isArpReply($packet) ) {

		#print "Arp reply: " . unpack('H*', substr($packet, 0, 32)) . "\n";
		processArpReply( $iface, $packet );
	}
	elsif ( isOspfHello($packet) ) {

		#print "OSPF Hello: " . unpack('H*', substr($packet, 0, 32)) . "\n";
		#processArpReply($iface, $packet);
	}

	#elsif (isICMP($packet)) {
	#  print "ICMP: " . unpack('H*', substr($packet, 0, 32)) . "\n";
	#  #processArpReply($iface, $packet);
	#}
	else {

		#print "Unknown packet: " . unpack('H*', substr($packet, 0, 32)) . "\n";

		# Store the packet in the correct hash
		lock %pktHashes;
		if ( !defined( $pktHashes{$iface} ) ) {
			die
"Not currently listening on device $iface. Make sure you called nftest_start_vhosts before.\n";
		}
		my $pkts = $pktHashes{$iface};

		lock %{$pkts};
		if ( !defined( $$pkts{$packet} ) ) {
			$$pkts{$packet} = 1;
		}
		else {
			my $cnt = ++$$pkts{$packet};
			delete( $$pkts{$packet} ) if ( $cnt == 0 );
		}
	}
}

#####################################################################
# Name: nftest_vhost_expect
# Notify the capture module that we're expecting a packet
#
# Arguments: host
#            pkt
#
#####################################################################
sub nftest_vhost_expect {
	my ( $host, $pkt ) = @_;

	# Ensure all params look valid
	if ( !validateIP($host) ) {
		die "Invalid host IP address '$host'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);

	# Verify that both IPs are known
	if ( !defined( $vhostsIPiface{$host} ) ) {
		die "Unknown host IP address '$host'";
	}

	# Get the iface
	my $iface = $vhostsIPiface{$host};

	# Call the other expect function
	nftest_expect( $iface, $pkt, 1 );
}

###############################################################
# Name: nftest_print_vhost_errors
# Print the errors (unexpected/missing packets)
# Arguments: $errors    Hash of erroneous packets
# Returns: total number of errors
###############################################################
sub nftest_print_vhost_errors {
	my $total_errors = 0;

	# Print out the unmatched packets
	while ( my ( $ifacename, $ref ) = each(%pktHashes) ) {

		# See if we actually have errors
		my $ifaceTotal = scalar( keys(%$ref) );
		if ( $ifaceTotal > 0 ) {
			print "Errors seen on $ifacename:\n";
		}

		my $ifaceCnt    = 0;
		my $ifaceErrors = 0;
		while ( my ( $pkt, $count ) = each(%$ref) ) {
			$ifaceCnt++;

			my $unpacked_pkt = unpack( 'H*', $pkt );
			if ( length($unpacked_pkt) > 32 ) {
				$unpacked_pkt = substr( $unpacked_pkt, 0, 32 ) . "...";
			}
			if ( $count < 0 ) {
				$count = -$count;
				print "Missing packet with count $count    : $unpacked_pkt\n" if ( $ifaceCnt < 4 );
			}
			else {
				print "Unexpected packets with count $count: $unpacked_pkt\n" if ( $ifaceCnt < 4 );
			}
			print "Skipping remaining errors on $ifacename...\n" if ( $ifaceCnt == 4 );
			$ifaceErrors  += $count;
			$total_errors += $count;
		}
		print "Total: $ifaceErrors on $ifacename\n\n" if ( $ifaceTotal > 0 );
	}

	# Print out ARP errors
	foreach my $pair ( sort( keys(%vhARPReqLog) ) ) {

		# ARP errors indicated when the cnt does not have a .5 at the end
		my $cnt = $vhARPReqLog{$pair};
		if ( int($cnt) == $cnt || $cnt < 1 ) {

			# Work out the source and dest
			my ( $src, $dst ) = split( /:/, $pair );

			# Get the interface
			my $iface = $vhostsIPiface{$src};
			$iface =~ s/:rtr//;

			# Check if there's a corresponding error in the reply table
			my $rep      = defined( $vhARPRepLog{"$dst:$src"} );
			my $repError = 0;
			if ($rep) {
				my $repCnt = $vhARPRepLog{"$dst:$src"};
				$repError = ( int($repCnt) == $repCnt || $repCnt < 1 );
				delete( $vhARPRepLog{"$dst:$src"} );
			}

			# Work out the error
			my $errorStr = $cnt < 1 ? "Missing" : "Unexpected";

			# Print the error
			if ($repError) {
				print "$errorStr ARP request/reply pair from $src to $dst on $iface\n";
			}
			else {
				print "$errorStr ARP request from $src to $dst on $iface\n";
			}

			$total_errors++;
		}
	}

	# Print out ARP errors
	foreach my $pair ( sort( keys(%vhARPRepLog) ) ) {

		# ARP errors indicated when the cnt does not have a .5 at the end
		my $cnt = $vhARPRepLog{$pair};
		if ( int($cnt) == $cnt || $cnt < 1 ) {

			# Work out the source and dest
			my ( $src, $dst ) = split( /:/, $pair );

			# Get the interface
			my $iface = $vhostsIPiface{$src};
			$iface =~ s/:rtr//;

			# Work out the error
			my $errorStr = $cnt < 1 ? "Missing" : "Unexpected";

			# Print the error
			print "$errorStr ARP reply from $src to $dst on $iface\n";

			$total_errors++;
		}
	}

	return $total_errors;
}

###############################################################
# Name: nftest_create_host
# Create a "virtual" host on the test network
# Arguments: iface  Interface on which the host lives
#            mac    Host's MAC address
#            ip     Host's IP address
# Returns:
###############################################################
sub nftest_create_host {
	my ( $iface, $mac, $ip ) = @_;

	# Ensure all params look valid
	my %ifaceNameMap = nftest_get_iface_name_map();
	if ( !defined( $ifaceNameMap{$iface} ) ) {
		die "Interface $iface is not known";
	}
	if ( !( $mac =~ /^(([0-9a-f]){2}:){5}([0-9a-f]){2}$/i ) ) {
		die "Invalid MAC address '$mac'. Should look like '00:ca:fe:00:01:01'";
	}
	if ( !validateIP($ip) ) {
		die "Invalid IP address '$ip'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);
	lock(%vhostsIPmac);

	# Verify that the host doesn't already exist
	if ( defined( $vhostsIPiface{$ip} ) ) {
		die "Virtual host with IP address '$ip' already exists";
	}

	# Insert the virtual host in the table
	$vhostsIPiface{$ip} = $iface;
	$vhostsIPmac{$ip}   = $mac;
}

###############################################################
# Name: nftest_register_router
# Register the IP for a given interface
# Arguments: iface  Interface on which hosts live
#            ip     IP address of the router
# Returns:
###############################################################
sub nftest_register_router {
	my ( $iface, $mac, $ip ) = @_;

	# Ensure all params look valid
	my %ifaceNameMap = nftest_get_iface_name_map();
	if ( !defined( $ifaceNameMap{$iface} ) ) {
		die "Interface $iface is not known";
	}
	if ( !validateIP($ip) ) {
		die "Invalid IP address '$ip'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);
	lock(%vhostsIPmac);

	# Verify that the host doesn't already exist
	if ( defined( $vhostsIPiface{$ip} ) ) {
		die "Virtual host with IP address '$ip' already exists";
	}

	# Insert the virtual host in the table
	$vhostsRouterIPs{$iface} = $ip;
	$vhostsIPiface{$ip}      = "$iface:rtr";
	$vhostsIPmac{$ip}        = "$mac";
}

###############################################################
# Name: nftest_send_IP
# Send an IP packet between two virtual hosts
# Arguments: src    IP address of source
#            dst    IP address of destination
#            arg    optional hash of parameters to pass into
#                   the IP packet creation function
# Returns:
###############################################################
sub nftest_send_IP {
	my ( $src, $dst, %arg ) = @_;

	# Ensure all params look valid
	if ( !validateIP($src) ) {
		die "Invalid source IP address '$src'. Should look like '192.168.0.1'";
	}
	if ( !validateIP($dst) ) {
		die "Invalid dest IP address '$dst'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);
	lock(%vhostsIPmac);
	lock(%vhostsARP);

	# Verify that both IPs are known
	if ( !defined( $vhostsIPiface{$src} ) ) {
		die "Unknown source IP address '$src'";
	}
	if ( !defined( $vhostsIPiface{$dst} ) ) {
		die "Unknown dest IP address '$dst'";
	}

	# Get the MAC of the source
	my $srcMac = $vhostsIPmac{$src};

	# Get the ifaces of both IPs
	my $srcIface = $vhostsIPiface{$src};
	my $dstIface = $vhostsIPiface{$dst};

	# Verify that they are on different interfaces
	return if ( $srcIface eq $dstIface );

	# Get the IP of the router node for the src
	my $nextHop = $vhostsRouterIPs{$srcIface};

	# Construct the ARP table string
	my $arpStr = "$src:$nextHop";

	# Check if we know the next hop's MAC address
	my $macKnown = defined( $vhostsARP{$arpStr} );

	# Get the MAC address of the next hop (Note: this may not actually
	# be known at this stage by the virtual host. We'll fill it in now
	# but maybe send later.)
	my $nextHopMac = $vhostsIPmac{$nextHop};

	# Construct the IP packet
	$arg{DA}     = $nextHopMac;
	$arg{SA}     = $srcMac;
	$arg{src_ip} = $src;
	$arg{dst_ip} = $dst;
	$arg{ttl}    = 64 if ( !defined( $arg{ttl} ) );
	$arg{len}    = 60 if ( !defined( $arg{len} ) );

	my $ippkt = new NF::IP_pkt(%arg);

	# Send or store the packet
	if ($macKnown) {
		nftest_send( $srcIface, $ippkt->packed() );
	}
	else {
		lock(%vhostsPendingPkts);

		# Store the ip packet
		my $pkts;
		if ( defined( $vhostsPendingPkts{$arpStr} ) ) {
			$pkts = $vhostsPendingPkts{$arpStr};
		}
		else {
			$pkts = &share( [] );
			$vhostsPendingPkts{$arpStr} = $pkts;

			# Generate an ARP packet
			my $arppkt = NF::ARP_pkt->new_request(
				SA           => $srcMac,
				SenderIpAddr => $src,
				TargetIpAddr => $nextHop,
			);
			nftest_send( $srcIface, $arppkt->packed(), 0 );
		}

		lock($pkts);
		push @$pkts, $ippkt->packed;

		# Record the pending packet
		nftest_expect( $srcIface, $ippkt->packed, 1 );
	}

	return $ippkt;
}

###############################################################
# Name: nftest_create_IP
# Create an IP packet to send between two virtual hosts (but don't
# actually send)
# Arguments: src    IP address of source
#            dst    IP address of destination
#            arg    optional hash of parameters to pass into
#                   the IP packet creation function
# Returns:
###############################################################
sub nftest_create_IP {
	my ( $src, $dst, %arg ) = @_;

	# Ensure all params look valid
	if ( !validateIP($src) ) {
		die "Invalid source IP address '$src'. Should look like '192.168.0.1'";
	}
	if ( !validateIP($dst) ) {
		die "Invalid dest IP address '$dst'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);
	lock(%vhostsIPmac);
	lock(%vhostsARP);

	# Verify that both IPs are known
	if ( !defined( $vhostsIPiface{$src} ) ) {
		die "Unknown source IP address '$src'";
	}
	if ( !defined( $vhostsIPiface{$dst} ) ) {
		die "Unknown dest IP address '$dst'";
	}

	# Get the MAC of the source
	my $srcMac = $vhostsIPmac{$src};

	# Get the ifaces of both IPs
	my $srcIface = $vhostsIPiface{$src};
	my $dstIface = $vhostsIPiface{$dst};

	# Check to see if the two devices are on different interfaces
	my $nextHopMac = $vhostsIPmac{$dst};
	if ( $srcIface ne $dstIface ) {

		# Get the IP of the router node for the src
		my $nextHop = $vhostsRouterIPs{$srcIface};

		# Get the MAC address of the next hop (Note: this may not actually
		# be known at this stage by the virtual host. We'll fill it in now
		# but maybe send later.)
		$nextHopMac = $vhostsIPmac{$nextHop};
	}

	# Construct the IP packet
	$arg{DA}     = $nextHopMac;
	$arg{SA}     = $srcMac;
	$arg{src_ip} = $src;
	$arg{dst_ip} = $dst;
	$arg{ttl}    = 64 if ( !defined( $arg{ttl} ) );
	$arg{len}    = 60 if ( !defined( $arg{len} ) );

	my $ippkt = new NF::IP_pkt(%arg);

	return $ippkt;
}

###############################################################
# Name: nftest_send_UDP
# Send an UDP packet between two virtual hosts
# Arguments: src    IP address of source
#            dst    IP address of destination
#            arg    optional hash of parameters to pass into
#                   the UDP packet creation function
# Returns:
###############################################################
sub nftest_send_UDP {
	my ( $src, $dst, %arg ) = @_;

	# Ensure all params look valid
	if ( !validateIP($src) ) {
		die "Invalid source IP address '$src'. Should look like '192.168.0.1'";
	}
	if ( !validateIP($dst) ) {
		die "Invalid dest IP address '$dst'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);
	lock(%vhostsIPmac);
	lock(%vhostsARP);

	# Verify that both IPs are known
	if ( !defined( $vhostsIPiface{$src} ) ) {
		die "Unknown source IP address '$src'";
	}
	if ( !defined( $vhostsIPiface{$dst} ) ) {
		die "Unknown dest IP address '$dst'";
	}

	# Get the MAC of the source
	my $srcMac = $vhostsIPmac{$src};

	# Get the ifaces of both IPs
	my $srcIface = $vhostsIPiface{$src};
	my $dstIface = $vhostsIPiface{$dst};

	# Verify that they are on different interfaces
	return if ( $srcIface eq $dstIface );

	# Get the IP of the router node for the src
	my $nextHop = $vhostsRouterIPs{$srcIface};

	# Construct the ARP table string
	my $arpStr = "$src:$nextHop";

	# Check if we know the next hop's MAC address
	my $macKnown = defined( $vhostsARP{$arpStr} );

	# Get the MAC address of the next hop (Note: this may not actually
	# be known at this stage by the virtual host. We'll fill it in now
	# but maybe send later.)
	my $nextHopMac = $vhostsIPmac{$nextHop};

	# Construct the IP packet
	$arg{DA}     = $nextHopMac;
	$arg{SA}     = $srcMac;
	$arg{src_ip} = $src;
	$arg{dst_ip} = $dst;
	$arg{ttl}    = 64 if ( !defined( $arg{ttl} ) );
	$arg{len}    = 60 if ( !defined( $arg{len} ) );

	my $udppkt = new NF::UDP_pkt(%arg);

	# Send or store the packet
	if ($macKnown) {
		nftest_send( $srcIface, $udppkt->packed() );
	}
	else {
		lock(%vhostsPendingPkts);

		# Store the ip packet
		my $pkts;
		if ( defined( $vhostsPendingPkts{$arpStr} ) ) {
			$pkts = $vhostsPendingPkts{$arpStr};
		}
		else {
			$pkts = &share( [] );
			$vhostsPendingPkts{$arpStr} = $pkts;

			# Generate an ARP packet
			my $arppkt = NF::ARP_pkt->new_request(
				SA           => $srcMac,
				SenderIpAddr => $src,
				TargetIpAddr => $nextHop,
			);
			nftest_send( $srcIface, $arppkt->packed(), 0 );
		}

		lock($pkts);
		push @$pkts, $udppkt->packed;

		# Record the pending packet
		nftest_expect( $srcIface, $udppkt->packed, 1 );
	}

	return $udppkt;
}

###############################################################
# Name: nftest_send_ARP_req
# Send an ARP packet between two virtual hosts
# Arguments: src    IP address of source
#            dst    IP address of destination
#            arg    optional hash of parameters to pass into
#                   the IP packet creation function
# Returns:
###############################################################
sub nftest_send_ARP_req {
	my ( $src, $dst, %arg ) = @_;

	# Ensure all params look valid
	if ( !validateIP($src) ) {
		die "Invalid source IP address '$src'. Should look like '192.168.0.1'";
	}
	if ( !validateIP($dst) ) {
		die "Invalid dest IP address '$dst'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);
	lock(%vhostsIPmac);
	lock(%vhostsARP);

	# Verify that both IPs are known
	if ( !defined( $vhostsIPiface{$src} ) ) {
		die "Unknown source IP address '$src'";
	}
	if ( !defined( $vhostsIPiface{$dst} ) ) {
		die "Unknown dest IP address '$dst'";
	}

	# Get the MAC of the source
	my $srcMac = $vhostsIPmac{$src};

	# Get the ifaces of both IPs
	my $srcIface = $vhostsIPiface{$src};
	my $dstIface = $vhostsIPiface{$dst};

	# Verify that they are on different interfaces (one hopefully has rtr as a postfix)
	return if ( $srcIface eq $dstIface );

	# Drop the rtr postfix
	$srcIface =~ s/:rtr//;
	$dstIface =~ s/:rtr//;

	# Verify that they are actually connected
	return if ( $srcIface ne $dstIface );

	# Generate an ARP packet
	my $arppkt = NF::ARP_pkt->new_request(
		SA           => $srcMac,
		SenderIpAddr => $src,
		TargetIpAddr => $dst,
	);
	nftest_send( $srcIface, $arppkt->packed(), 0 );

	# Return the ARP packet
	return $arppkt;
}

###############################################################
# Name: nftest_disable_ARP_reply
# Disable ARP replies for a virtual host
# Arguments: host   IP address of host
# Returns:
###############################################################
sub nftest_disable_ARP_reply {
	my ($host) = @_;

	# Ensure all params look valid
	if ( !validateIP($host) ) {
		die "Invalid IP address '$host'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);
	lock(%vhostsARPdisable);

	# Verify that the IP is known
	if ( !defined( $vhostsIPiface{$host} ) ) {
		die "Unknown IP address '$host'";
	}

	# Record that the host should be disabled from sending ARP replies
	$vhostsARPdisable{$host} = 1;
}

###############################################################
# Name: nftest_send_ICMP_echo_req
# Send an ICMP packet between two virtual hosts
# Arguments: src    IP address of source
#            dst    IP address of destination
#            arg    optional hash of parameters to pass into
#                   the ICMP packet creation function
# Returns:
###############################################################
sub nftest_send_ICMP_echo_req {
	my ( $src, $dst, %arg ) = @_;

	# Ensure all params look valid
	if ( !validateIP($src) ) {
		die "Invalid source IP address '$src'. Should look like '192.168.0.1'";
	}
	if ( !validateIP($dst) ) {
		die "Invalid dest IP address '$dst'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);
	lock(%vhostsIPmac);
	lock(%vhostsARP);

	# Verify that both IPs are known
	if ( !defined( $vhostsIPiface{$src} ) ) {
		die "Unknown source IP address '$src'";
	}
	if ( !defined( $vhostsIPiface{$dst} ) ) {
		die "Unknown dest IP address '$dst'";
	}

	# Get the MAC of the source
	my $srcMac = $vhostsIPmac{$src};

	# Get the ifaces of both IPs
	my $srcIface = $vhostsIPiface{$src};
	my $dstIface = $vhostsIPiface{$dst};

	# Verify that they are on different interfaces
	return if ( $srcIface eq $dstIface );

	# Get the IP of the router node for the src
	my $nextHop = $vhostsRouterIPs{$srcIface};

	# Construct the ARP table string
	my $arpStr = "$src:$nextHop";

	# Check if we know the next hop's MAC address
	my $macKnown = defined( $vhostsARP{$arpStr} );

	# Get the MAC address of the next hop (Note: this may not actually
	# be known at this stage by the virtual host. We'll fill it in now
	# but maybe send later.)
	my $nextHopMac = $vhostsIPmac{$nextHop};

	# Construct the IP packet
	$arg{DA}     = $nextHopMac;
	$arg{SA}     = $srcMac;
	$arg{src_ip} = $src;
	$arg{dst_ip} = $dst;

	my $icmppkt = NF::ICMP_pkt->new_echo_request(%arg);

	# Send or store the packet
	if ($macKnown) {
		nftest_send( $srcIface, $icmppkt->packed() );
	}
	else {
		lock(%vhostsPendingPkts);

		# Store the ip packet
		my $pkts;
		if ( defined( $vhostsPendingPkts{$arpStr} ) ) {
			$pkts = $vhostsPendingPkts{$arpStr};
		}
		else {
			$pkts = &share( [] );
			$vhostsPendingPkts{$arpStr} = $pkts;

			# Generate an ARP packet
			my $arppkt = NF::ARP_pkt->new_request(
				SA           => $srcMac,
				SenderIpAddr => $src,
				TargetIpAddr => $nextHop,
			);
			nftest_send( $srcIface, $arppkt->packed(), 0 );
		}

		lock($pkts);
		push @$pkts, $icmppkt->packed;

		# Record the pending packet
		nftest_expect( $srcIface, $icmppkt->packed, 1 );
	}

	return $icmppkt;
}


###############################################################
# Name: processArpRequest
# Process an ARP request packet
# Arguments: iface  interface
#            pkt    packet
# Returns:
###############################################################
sub processArpRequest {
	my ( $iface, $pkt ) = @_;

	# Convert the ARP request to an ARP_pkt
	my $arppkt = NF::ARP_pkt->new_packed( Data => $pkt );

	# Get the sender IP, sender MAC and target IP
	my $src    = $arppkt->get('SenderIpAddr');
	my $srcMac = $arppkt->get('SenderEthAddr');
	my $dst    = $arppkt->get('TargetIpAddr');

	# Lock the appropriate data elements
	lock(%vhostsIPiface);

	# Record that we've seen an arp request for the src/dst pair
	{
		lock(%vhARPReqLog);

		if ( !defined( $vhARPReqLog{"$src:$dst"} ) ) {
			$vhARPReqLog{"$src:$dst"} = 1;
		}
		else {
			$vhARPReqLog{"$src:$dst"} += 1;
		}
	}

	# Verify that we should in fact be sending an ARP reply
	{
		lock(%vhostsARPdisable);

		if ( defined( $vhostsARPdisable{$dst} ) ) {
			return;
		}
	}

	# Check to see if we know the dst and if it's on the correct interface
	if ( defined( $vhostsIPiface{$dst} ) ) {
		if ( $vhostsIPiface{$dst} eq $iface ) {
			lock(%vhostsIPmac);
			my $dstMac = $vhostsIPmac{$dst};

			# Generate an ARP reply
			my $arpreply = NF::ARP_pkt->new_reply(
				SA           => $dstMac,
				DA           => $srcMac,
				SenderIpAddr => $dst,
				TargetIpAddr => $src,
			);

			# Send the packet
			nftest_send( $iface, $arpreply->packed, 0 );
		}
	}
}

###############################################################
# Name: processArpReply
# Process an ARP request packet
# Arguments: iface  interface
#            pkt    packet
# Returns:
###############################################################
sub processArpReply {
	my ( $iface, $pkt ) = @_;

	# Convert the ARP reply to an ARP_pkt
	my $arppkt = NF::ARP_pkt->new_packed( Data => $pkt );

	# Get the sender and target IP and MAC
	my $src    = $arppkt->get('SenderIpAddr');
	my $srcMac = $arppkt->get('SenderEthAddr');
	my $dst    = $arppkt->get('TargetIpAddr');
	my $dstMac = $arppkt->get('TargetEthAddr');

	# Lock the appropriate data elements
	lock(%vhostsIPiface);

	# Record that we've seen an arp reply for the src/dst pair
	{
		lock(%vhARPRepLog);

		if ( !defined( $vhARPRepLog{"$src:$dst"} ) ) {
			$vhARPRepLog{"$src:$dst"} = 1;
		}
		else {
			$vhARPRepLog{"$src:$dst"} += 1;
		}
	}

	# Check to see if we know the dst and if it's on the correct interface
	if ( defined( $vhostsIPiface{$dst} ) ) {
		lock(%vhostsIPmac);
		if ( $vhostsIPiface{$dst} eq $iface && $vhostsIPmac{$dst} eq $dstMac ) {

			# Store the response in the ARP table
			my $arpStr = "$dst:$src";
			lock(%vhostsARP);
			lock(%vhostsPendingPkts);
			$vhostsARP{$arpStr} = $srcMac;

			# Process any pending packets
			if ( defined( $vhostsPendingPkts{$arpStr} ) ) {
				my $pkts = $vhostsPendingPkts{$arpStr};
				foreach my $pkt (@$pkts) {

					# Send the packet (without expect, we've already expected it)
					nftest_send( $iface, $pkt, 0 );
				}

				# Delete the list of packets from the hash
				delete( $vhostsPendingPkts{$arpStr} );
			}
		}
	}
}

###############################################################
# Name: nftest_expect_ARP_exchange
# Expect an ARP exchange between two hosts
# Arguments: src  ARP sender
#            dst  ARP receiver
# Returns:
###############################################################
sub nftest_expect_ARP_exchange {
	my ( $src, $dst ) = @_;

	expect_ARP_message( $src, $dst, \%vhARPReqLog );
	expect_ARP_message( $dst, $src, \%vhARPRepLog );
}

###############################################################
# Name: nftest_expect_ARP_request
# Expect an ARP exchange between two hosts
# Arguments: src  ARP sender
#            dst  ARP receiver
# Returns:
###############################################################
sub nftest_expect_ARP_request {
	my ( $src, $dst ) = @_;

	expect_ARP_message( $src, $dst, \%vhARPReqLog );
}

###############################################################
# Name: nftest_expect_ARP_reply
# Expect an ARP exchange between two hosts
# Arguments: src  ARP sender
#            dst  ARP receiver
# Returns:
###############################################################
sub nftest_expect_ARP_reply {
	my ( $src, $dst ) = @_;

	expect_ARP_message( $src, $dst, \%vhARPRepLog );
}

###############################################################
# Name: expect_ARP_message
# Expect an ARP message between two hosts
# Arguments: src      ARP sender
#            dst      ARP receiver
#            msgHash  Hash reference into which to store the expected
#                     message
# Returns:
###############################################################
sub expect_ARP_message {
	my ( $src, $dst, $msgHash ) = @_;

	# Ensure all params look valid
	if ( !validateIP($src) ) {
		die "Invalid source IP address '$src'. Should look like '192.168.0.1'";
	}
	if ( !validateIP($dst) ) {
		die "Invalid dest IP address '$dst'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);
	lock(%vhostsIPmac);

	# Verify that both IPs are known
	if ( !defined( $vhostsIPiface{$src} ) ) {
		die "Unknown source IP address '$src'";
	}
	if ( !defined( $vhostsIPiface{$dst} ) ) {
		die "Unknown dest IP address '$dst'";
	}

	# Get the MAC of the source and dest
	my $srcMac = $vhostsIPmac{$src};
	my $dstMac = $vhostsIPmac{$dst};

	# Get the ifaces of both IPs
	my $srcIface = $vhostsIPiface{$src};
	my $dstIface = $vhostsIPiface{$dst};

	# Ensure that the two hosts are on the same interface
	if ( ( $srcIface ne "$dstIface:rtr" ) && ( "$srcIface:rtr" ne $dstIface ) ) {
		die "Source and destination not on same interface";
	}

	# Record the expected message
	#
	# Note: expected packets are denoted in this instance by a 0.5. This allows for the
	# case of multiple requests etc arriving
	{
		lock(%$msgHash);

		if ( !defined( $$msgHash{"$src:$dst"} ) ) {
			$$msgHash{"$src:$dst"} = 0.5;
		}
		else {
			$$msgHash{"$src:$dst"} = int( $$msgHash{"$src:$dst"} ) + 0.5;
		}
	}
}

###############################################################
# Name: nftest_get_vhost_mac
# Get the MAC address of a virtual host
# Arguments: ip     Host's IP address
# Returns: MAC address of host
###############################################################
sub nftest_get_vhost_mac {
	my ($ip) = @_;

	# Ensure all params look valid
	if ( !validateIP($ip) ) {
		die "Invalid IP address '$ip'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPmac);

	# Verify that the host doesn't already exist
	if ( !defined( $vhostsIPmac{$ip} ) ) {
		die "Virtual host with IP address '$ip' does not exist";
	}

	# Insert the virtual host in the table
	return $vhostsIPmac{$ip};
}


###############################################################
# Name: nftest_expect_ICMP_host_unreach
# Expect an ICMP host unreachable message
# Arguments: dst    Host receiving ICMP packet
#            src    Host sending ICMP packet
#            pkt    Rejected packet
# Returns: The expected IMCP packet
###############################################################
sub nftest_expect_ICMP_host_unreach {
	my ( $dst, $src, $pkt ) = @_;

	return expect_ICMP_dest_unreach( $dst, $src, NF::ICMP::DEST_HOST_UNREACH, $pkt );
}

###############################################################
# Name: nftest_expect_ICMP_port_unreach
# Expect an ICMP port unreachable message
# Arguments: dst    Host receiving ICMP packet
#            src    Host sending ICMP packet
#            pkt    Rejected packet
# Returns: The expected IMCP packet
###############################################################
sub nftest_expect_ICMP_port_unreach {
	my ( $dst, $src, $pkt ) = @_;

	return expect_ICMP_dest_unreach( $dst, $src, NF::ICMP::DEST_PORT_UNREACH, $pkt );
}

###############################################################
# Name: nftest_expect_ICMP_proto_unreach
# Expect an ICMP proto unreachable message
# Arguments: dst    Host receiving ICMP packet
#            src    Host sending ICMP packet
#            pkt    Rejected packet
# Returns: The expected IMCP packet
###############################################################
sub nftest_expect_ICMP_proto_unreach {
	my ( $dst, $src, $pkt ) = @_;

	return expect_ICMP_dest_unreach( $dst, $src, NF::ICMP::DEST_PROTO_UNREACH, $pkt );
}

###############################################################
# Name: nftest_expect_ICMP_network_unreach
# Expect an ICMP network unreachable message
# Arguments: dst    Host receiving ICMP packet
#            src    Host sending ICMP packet
#            pkt    Rejected packet
# Returns: The expected IMCP packet
###############################################################
sub nftest_expect_ICMP_network_unreach {
	my ( $dst, $src, $pkt ) = @_;

	return expect_ICMP_dest_unreach( $dst, $src, NF::ICMP::DEST_NET_UNREACH, $pkt );
}

###############################################################
# Name: nftest_expect_ICMP_time_exceeded
# Expect an ICMP time exceeded message
# Arguments: dst    Host receiving ICMP packet
#            src    Host sending ICMP packet
#            reason Why is the packet rejected
#            pkt    Rejected packet
# Returns: The expected IMCP packet
###############################################################
sub nftest_expect_ICMP_time_exceeded {
	my ( $dst, $src, $pkt ) = @_;

	# Ensure all params look valid
	if ( !validateIP($src) ) {
		die "Invalid source IP address '$src'. Should look like '192.168.0.1'";
	}
	if ( !validateIP($dst) ) {
		die "Invalid dest IP address '$dst'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);

	# Verify that both IPs are known
	if ( !defined( $vhostsIPiface{$src} ) ) {
		die "Unknown source IP address '$src'";
	}
	if ( !defined( $vhostsIPiface{$dst} ) ) {
		die "Unknown dest IP address '$dst'";
	}

	# Get the iface
	my $iface = $vhostsIPiface{$dst};

	# Create the actual ICMP packet
	my $icmppkt = NF::ICMP_pkt->new_time_exceeded(
		Packet => $pkt,
		src_ip => $src,
	);

	# Call the other expect function
	nftest_expect( $iface, $icmppkt->packed(), 1 );

	# Return the packet
	return $icmppkt;
}

###############################################################
# Name: expect_ICMP_dest_unreach
# Expect an ICMP destination unreachable message
# Arguments: dst    Host receiving ICMP packet
#            src    Host sending ICMP packet
#            reason Why is the packet rejected
#            pkt    Rejected packet
# Returns: The expected IMCP packet
###############################################################
sub expect_ICMP_dest_unreach {
	my ( $dst, $src, $reason, $pkt ) = @_;

	# Ensure all params look valid
	if ( !validateIP($src) ) {
		die "Invalid source IP address '$src'. Should look like '192.168.0.1'";
	}
	if ( !validateIP($dst) ) {
		die "Invalid dest IP address '$dst'. Should look like '192.168.0.1'";
	}

	# Lock the appropriate data elements
	lock(%vhostsIPiface);

	# Verify that both IPs are known
	if ( !defined( $vhostsIPiface{$src} ) ) {
		die "Unknown source IP address '$src'";
	}
	if ( !defined( $vhostsIPiface{$dst} ) ) {
		die "Unknown dest IP address '$dst'";
	}

	# Get the iface
	my $iface = $vhostsIPiface{$dst};

	# Create the actual ICMP packet
	my $icmppkt = NF::ICMP_pkt->new_dest_unreach(
		Reason => $reason,
		Packet => $pkt,
		src_ip => $src,
	);

	# Call the other expect function
	nftest_expect( $iface, $icmppkt->packed(), 1 );

	# Return the packet
	return $icmppkt;
}


# Always end library in 1
1;
