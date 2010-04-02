##############################################################
# vim:set shiftwidth=3 softtabstop=3 expandtab:
# $Id: Tester.pm 2751 2007-11-01 21:52:11Z grg $
#
#
# library to maintain test state and provide communication
# between test threads
#
# First create a Tester object, then call expectPkt, sendPkt,
# and expectAndSendPkt as needed on this object.
#
# Revisions:
#
##############################################################

package Test::Tester;
use Carp;
use strict;
use warnings;
use Net::Pcap;
use NF::TestLib;
use threads;
use threads::shared;

###############################################################
# Name: new
# initialize a new Tester and return it
# Arguments: %ifaceNames mapping of interface names
# returns new instance
###############################################################
sub new {
  my $pkg = shift;

  # get hash of the interface names for error checking
  my $ifaceNames = { @_ };

  # hashes of packets that have not been matched by send/rcv
  # The packets themselves are used as keys, and the values stored
  # are a packed string of type and numPkts
  our %unmatched_pkts_hashes : shared;

  # hashes of packets to match and send a response pkt for
  our %response_pkts_hashes : shared;

  # hash of mappings from iface names to pcap
  our %pcap_hash : shared;

  our $pcap : shared;
  # initialize the receiving threads
  my @rcvrThreads;
  my @pcap_list;
  for my $ifaceName ( keys %$ifaceNames ) {
    # initialize a shared hash for this interface
    our $ifaceHash = &share({});
    $ifaceHash->{'hello'}= $ifaceName;
    $unmatched_pkts_hashes{$ifaceName} = $ifaceHash;

    # wait for the the thread to initialize the mapping from pcap
    # to ifacename
    lock(%pcap_hash);
    my $rcvr = threads->new(\&Receiver::run,
			    ifaceName => $ifaceName,
			    unmatched_pkts_hash => $ifaceHash,
			    pcap_hash => \%pcap_hash,
			   );
    cond_wait(%pcap_hash);

    push @rcvrThreads, $rcvr;
  }

  my $self = { ifaceNames   => $ifaceNames,
	       rcvrThreads  => \@rcvrThreads,
	       pcap_hash    => \%pcap_hash,
	       unmatched_pkts_hashes => \%unmatched_pkts_hashes,
	       response_pkts_hashes => \%response_pkts_hashes,
	     };

  return bless($self, $pkg);
}

###############################################################
# Name: expectPkt
# Subroutine to indicate that a packet should be seen at the
# given port. This checks if a packet is in the
# unmatchedPktsHashes for the given interface
# Arguments: ifaceName  string
#            frame      packed string
#
###############################################################
sub expectPkt {

  my ($self, $ifaceName, $frame) = @_;

  die "Interface not found $ifaceName\n"
    unless exists $self->{'ifaceNames'}->{$ifaceName};

  # get exclusive access
  lock %{$self->{ 'unmatched_pkts_hashes' }->{ $ifaceName }};

  # increment the count for the packet
  $self->{ 'unmatched_pkts_hashes' }->{ $ifaceName }->{ $frame }++;

  # if the number is now zero, then remove the entry
  if($self->{ 'unmatched_pkts_hashes' }->{ $ifaceName }->{ $frame } == 0) {
    delete $self->{ 'unmatched_pkts_hashes' }->{ $ifaceName };
  }
}

###############################################################
# Name: sendPkt
# Subroutine to send a packet. Automatically adds the packet
# to the expected list since the packet will be seen on the
# sending interface.
# Arguments: ifaceName  string
#            frame      packed string
#
###############################################################
sub sendPkt {

  my ($self, $ifaceName, $frame) = @_;

  die "Interface not found $ifaceName\n"
    unless exists $self->{ 'ifaceNames' }->{ $ifaceName };

  # packet will be seen leaving
  $self->expectPkt($ifaceName, $frame);

  # send the packet
  NF::TestLib::nf2_send($ifaceName, $frame);
}


###############################################################
# Name: finish
# Stops listening to the interfaces, and returns to the user
# the hash of hashes of unmatched packets so she can check them
# as she wishes.
# Arguments:
# Returns: unmatched_pkts_hashes reference to hash of hashes
###############################################################
sub finish {
  my $self = shift;

  foreach my $ifaceName (keys %{$self->{ 'ifaceNames' }}) {
    my $pcap = $self->{pcap_hash}->{$ifaceName};
    print("Breakloop: $pcap $pcap\n");
    Net::Pcap::breakloop($pcap);
  }

  foreach my $rcvr (@{$self->{ 'rcvrThreads' }}) {
    $rcvr->join;
  }

  return $self->{'unmatched_pkts_hashes'};
}

#---------------------------------------------------------------

package Receiver;
use Carp;
use strict;
use warnings;
use NF::TestLib;
use Net::Pcap;
use threads;
use threads::shared;

###############################################################
# Name: new
# initializes a new receiver
# Arguments: ifaceName  string
# Returns: new instance
###############################################################
sub new {
  my $pkg = shift;

  my $self = { @_,
	     };

  return bless($self, $pkg);
}

###############################################################
# Name: run
# Starts receiving packets on the interface given in ifaceName
# Arguments: ifaceName  string
# Returns:
###############################################################
sub run {
  my $args  = {@_};

  print "In run: ";
  print %{$args};
  print "\n";

  # open port
  my $err="";
  my $pcap = Net::Pcap::open_live($args->{ifaceName}, 1514, 1, 0, \$err)
      or die "Can't open device $args->{ifaceName}: $err\n";

  {
    lock(%{$args->{pcap_hash}});
    $args->{pcap_hash}->{$args->{ifaceName}} = &share($pcap);
    cond_broadcast(%{$args->{pcap_hash}});
  }

  print "Starting capture on $args->{ifaceName}\n";
  print("Startloop: $pcap $args->{pcap_hash}->{$args->{ifaceName}}\n");

  # loop over forever (until breakloop is called)
  my $retval = Net::Pcap::loop($pcap, -1, \&process_packet, $args);

  print "Capture done on $args->{ifaceName} because of $retval\n";

  # close the device
  Net::Pcap::close($pcap);
}

###############################################################
# Name: process_packet
# Does the opposite of expectPkt
# Arguments:
# Returns:
###############################################################
sub process_packet {
  my ($args, $header, $frame) = @_;

  my $pkt = unpack("H*", $frame);
  print "In process: ";
  print %{$args};
  print "\n";
  print "Received pkt on iface $args->{ifaceName}\n$pkt\n";

  # obtain exclusive access to the hash
  lock %{$args->{'unmatched_pkts_hash'}};

  # increment the count for the packet
  $args->{'unmatched_pkts_hash'}->{ $frame }--;

  # if the number is now zero, then remove the entry
  if($args->{'unmatched_pkts_hash'}->{ $frame } == 0) {
    delete $args->{'unmatched_pkts_hash'}->{ $frame };
  }
}


# Always end library in 1
1;
