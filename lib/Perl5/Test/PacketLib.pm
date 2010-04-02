#####################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: PacketLib.pm 3074 2007-12-06 03:01:04Z grg $
#
# This provides functions for manipulating packets.
#
# The goal is to provide functions that make it easy to create and
# manipulate packets, so that we can avoid stupid errors.
#
#####################################

package NF::PDU;

use Carp;
use strict;

# Create a new raw PDU of $len bytes ($len is optional)
sub new {

  my ($class, $len) = @_;

  my $pdu = {
	     'bytes' => []
	    };

  if (defined $len) {
    while ($len--) { push @{$pdu->{'bytes'}},0 }
  }

  bless $pdu, $class;

}

# Return the raw bytes as a single string of hex bytes with trailing space,
# suitable for use as parameter to nf_packet_in() or nf_expected_packet()
sub bytes {
  my ($self) = @_;
  my @bytes =  @{$self->{'bytes'}};
  if (scalar(@bytes) > 0) {
    my @tmp = map {sprintf "%02x",$_} @{$self->{'bytes'}};
    return join(' ',@tmp).' ';
  }
  else {
    return "";
  }
}

# Set the contents of the PDU if given an array of bytes
sub set_bytes {
  my ($self,@data) = @_;
  if (0+@data) {
    @{$self->{'bytes'}} = @data;
  }
  else {
    @{$self->{'bytes'}} = ();
    #print "ERROR: no data passed in array to set_bytes.\n";
    #print "      Call this with something like \$PDU->set_bytes(\@my_data)\n";
    #return 1
  }
  return 0
}

# get a packed representation of the packet
sub packed {
  my ($self) = @_;
  return pack 'C*', @{$self->{'bytes'}};
}

# How long is this object (in bytes)
sub length_in_bytes {
    my ($self) = @_;

    return (0+@{$self->{'bytes'}});
}

=pod

=head1 NAME

NF::PacketLib.pm - A Perl module for manipulating packets for use in
NetFPGA2 perl scripts.

It provides several different object types:

=over

=item *

NF::PDU

=item *

NF::Ethernet_hdr

=item *

NF::VLAN_hdr

=item *

NF::IP_hdr

=back

An IP packet, for example, will consist of an Ethernet_hdr B<or> VLAN_hdr B<plus>
an IP_hdr B<plus> a PDU for the remaining bytes in the packet.

=head1 NF::PDU

This is the base NetFPGA module from which most of the more sophisticated packet
modules inherit.

The methods available are:

=head2 new(length)

Creates a new PDU object. If B<length> is specified then the PDU will have
B<length> bytes all zero.

e.g.
  my $PDU = NF::PDU->new(60);



=head2 bytes()

Returns the contents of the PDU as a single string consisting of pairs
of hex digits, one pair per byte. This string is in the format needed by
the nf_packet_in() and nf_expected_packet() functions defined in NF::PacketGen.pm

e.g.
  nf_packet_in($port, $length,  $delay, $batch,  $PDU->bytes() );


=head2 set_bytes(@array)

Use this to set the raw bytes in the PDU. The array parameter is a list of all
of the bytes in the packets (as numbers). For example to set the bytes in a PDU
to be the bytes 1 through 60 you could use:

 $PDU->set_bytes((1..60));

Usually set_bytes() is used to set the contents of the data portion of the packet,
after the various headers have been created - see later.


=head2 length_in_bytes()

This is used to return the length (in bytes) of the PDU.

e.g.

  $length = $PDU->length_in_bytes();

=head2 packed()

Returns the packet as a packed string that can be used to transmit it over a socket.

=cut


####################################################################
# Check that the parameter looks like a MAC address, and return
# a 6 byte array.

sub get_MAC_address
  {
    my $MAC = shift;

    my @MAC;

    # Look for the different MAC formats

    if ($MAC =~ /(..):(..):(..):(..):(..):(..)/) {
      @MAC=($1,$2,$3,$4,$5,$6)
    }
    elsif ($MAC =~ /(..)-(..)-(..)-(..)-(..)-(..)/) {
      @MAC=($1,$2,$3,$4,$5,$6)
    }
    elsif ($MAC =~ /(..) (..) (..) (..) (..) (..)/) {
      @MAC=($1,$2,$3,$4,$5,$6)
    }
    else {
      die "Bad format for MAC address $MAC. Expected format is e.g. 08:34:dd:cc:45:89\n";
    }

    # check that they are all hex values.

    foreach (@MAC) {
      unless ($_ =~ /[0-9a-f]{2}/i) {
	die "Bad format for MAC address $MAC\n";
      }
      $_ = hex($_)
    }

    return @MAC;
  }


####################################################################################
# Ethernet MAC header functions
####################################################################################

package NF::Ethernet_hdr;

use vars qw(@ISA);
@ISA = qw(NF::PDU);

sub new   # Ethernet_hdr
  {
    my ($class,%arg) = @_;

    my $Ethernet_hdr = $class->NF::PDU::new();

    @{$Ethernet_hdr->{'bytes'}}[0..13] = (
				      0,0,0,0,0,0,   # DA
				      0,0,0,0,0,0,   # SA
				      0,0            # Ethertype
				     );
    bless $Ethernet_hdr, $class;

    $Ethernet_hdr->DA($arg{'DA'}) if (defined $arg{'DA'});
    $Ethernet_hdr->SA($arg{'SA'}) if (defined $arg{'SA'});
    $Ethernet_hdr->Ethertype($arg{'Ethertype'}) if (defined $arg{'Ethertype'});

    $Ethernet_hdr;
  }

sub DA
  {
    my ($self, $val) = @_;
    if (defined $val) {
      @{$self->{'bytes'}}[0..5] = NF::PDU::get_MAC_address($val);
    }
    return (sprintf("%02x:%02x:%02x:%02x:%02x:%02x",@{$self->{'bytes'}}[0..5] ));
  }

sub SA
  {
    my ($self, $val) = @_;
    if (defined $val) {
      @{$self->{'bytes'}}[6..11] = NF::PDU::get_MAC_address($val);
    }
    return (sprintf("%02x:%02x:%02x:%02x:%02x:%02x",@{$self->{'bytes'}}[6..11] ));
  }

sub Ethertype
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Ethertype is %d (0x%04x) but it must be >= 0x600 (1536 decimal) and <= 0xffff", $val,$val;
      if (($val < 0x600) or ($val > 0xffff)) { die "$err" }

      @{$self->{'bytes'}}[12] = int ($val/256);
      @{$self->{'bytes'}}[13] = int ($val%256);
    }
    return (256*@{$self->{'bytes'}}[12] + @{$self->{'bytes'}}[13]);
  }

=pod

=head1 NF::Ethernet_hdr

This module provides functions for creating and manipulating regular
Ethernet headers (not IEEE 802.3 format).

=head2 new(DA, SA, Ethertype)

This creates a new Ethernet header of 14 bytes.

The optional parameters can be used to set the DA, SA or Ethertype fields
within the header. If these parameters are missing then the fields default
to zero.

e.g. This creates an Ehhernet header with an ethertype indicating an IP packet (0x800)

  my $MAC_hdr = NF::Ethernet_hdr->new(DA => $DA,
                                       SA => $SA,
                                       Ethertype => 0x800
                                      );

The format for the DA and SA is a string of six hex pairs separated by colons:

e.g.

  my $DA = '00:55:55:23:45:67';

The Ethertype parameter must be a number in 0x600..0xffff.

=head2 DA(DA)

This returns the current MAC DA (destination address) for this
header. If the optional argument is present then it will set the
DA field to the argument.

e.g.
 $MAC_hdr->DA('00:55:55:23:45:67');

=head2 SA(SA)

This returns the current MAC SA (source address) for this
header. If the optional argument is present then it will set the
SA field to the argument.

e.g.
 $MAC_hdr->SA('00:55:55:23:45:67');

=head2 Ethertype(Ethertype)

This returns the current MAC Ethertype for this
header. If the optional argument is present then it will set the
Ethertype field to the argument.

e.g.
 $MAC_hdr->Ethertype(0x0800);


=cut


####################################################################################
# VLAN (802.1Q) MAC header functions
# These are a superset of the basic Ethernet packet functions.
####################################################################################

package NF::VLAN_hdr;

use vars qw(@ISA);
@ISA = qw(NF::Ethernet_hdr);


sub new   # VLAN_hdr
  {
    my ($class,%arg) = @_;

    my $VLAN_hdr = $class->NF::PDU::new();

    @{$VLAN_hdr->{'bytes'}}[0..17] = (
				      0,0,0,0,0,0,   # DA
				      0,0,0,0,0,0,   # SA
				      0x81, 0, 0,0,  # VLAN (IEEE 802.1Q) header
				      0,0            # Ethertype
				     );
    bless $VLAN_hdr, $class;

    $VLAN_hdr->NF::Ethernet_hdr::DA($arg{'DA'}) if (defined $arg{'DA'});
    $VLAN_hdr->NF::Ethernet_hdr::SA($arg{'SA'}) if (defined $arg{'SA'});
    $VLAN_hdr->Ethertype($arg{'Ethertype'}) if (defined $arg{'Ethertype'});
    $VLAN_hdr->VLAN_ID($arg{'VLAN_ID'}) if (defined $arg{'VLAN_ID'});

    $VLAN_hdr;
  }

# sub DA in Ethernet_hdr
# sub SA in Ethernet_hdr

sub VLAN_ID
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "VLAN ID is %d (0x%04x) but it must be >= 0 and <= 0xffff", $val,$val;
      if (($val < 0) or ($val > 0xffff)) { die "$err" }

      @{$self->{'bytes'}}[14] = int ($val/256);
      @{$self->{'bytes'}}[15] = int ($val%256);
    }
    return (256*@{$self->{'bytes'}}[14] + @{$self->{'bytes'}}[15]);
  }

sub Ethertype
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Ethertype is %d (0x%04x) but it must be >= 0x600 (1536 decimal) and <= 0xffff", $val,$val;
      if (($val < 0x600) or ($val > 0xffff)) { die "$err" }

      @{$self->{'bytes'}}[16] = int ($val/256);
      @{$self->{'bytes'}}[17] = int ($val%256);
    }
    return (256*@{$self->{'bytes'}}[16] + @{$self->{'bytes'}}[17]);
  }
=pod

=head1 NF::VLAN_hdr

This module provides functions for creating and manipulating Ethernet
headers which use the standard IEEE 802.1Q encapsulation in which an additional
VLAN (virtual LAN) field of 4 bytes is inserted between the MAC SA and the
regular Ethertype.

So a non-VLAN ethernet header looks like:

 <-- 6 bytes --><-- 6 bytes --><-- 2 bytes -->
 +-------------------------------------------+
 |    DA       ||    SA       || Ethertype   |
 +-------------------------------------------+

whereas a VLAN header looks like:

 <-- 6 bytes --><-- 6 bytes --><-- 2 bytes --><-- 2 bytes --><-- 2 bytes -->
 +-------------------------------------------------------------------------+
 |    DA       ||    SA       || 0x8100      || VLAN ID     || Ethertype   |
 +-------------------------------------------------------------------------+

The Ethertype 0x8100 is reserved to indicate that this is a VLAN packet
and therefore contains a VLAN ID field before the 'real' Ethertype.

The VLAN ID field is a 16 bit field:

 15:13 = PRIORITY
 12    = CFI (Canonical Format Indicator)
 11:0  = VID (VLAN identifier)

Of these, priority and CFI are usually 0. NetFPGA uses the VID field to indicate the
logical port on which the packet arrived/departed.

The VLAN_hdr object inherits from MAC_hdr and so has the same
DA, SA and Ethertype accessor methods.

The new/different methods on the VLAN_hdr object are:

=head2 new(DA, SA, Ethertype, VLAN_ID)

This creates a new VLAN header of 18 bytes. If no arguments are provided then
all bytes are zero except for the actual Ethertype field (bytes 13,14) which will
be 0x8100 to indicate a VLAN header.

The optional parameters can be used to set the DA, SA or 'real' Ethertype fields
within the header.

e.g. This creates a VLAN header with an Ethertype indicating an IP packet (0x800)

  my $VLAN_hdr = NF::VLAN_hdr->new( DA => $DA,
                                     SA => $SA,
                                     Ethertype => 0x800,
                                     VLAN_ID => 3
                                    );

The format for the DA and SA is a string of six hex pairs separated by colons:

e.g.

  my $DA = '00:55:55:23:45:67';

The Ethertype parameter must be a number in 0x600..0xffff.
The VLAN_ID parameter must be a number in 0..0xffff.


=head2 VLAN_ID(VLAN_ID)

This returns the current VLAN_ID field for this
header. If the optional argument is present then it will set the
VLAN_ID field to the argument.

e.g.
 $MAC_hdr->VLAN_ID(3);

The VLAN_ID parameter must be a number in 0..0xffff.

=cut

####################################################################################
# IP header functions
####################################################################################

package NF::IP_hdr;

use Socket;

use vars qw(@ISA);
@ISA = qw(NF::PDU);

sub new   # IP_hdr
  {
    my ($class,%arg) = @_;

    my $IP_hdr = {
		  'bytes' => [0x45,    # IPv4,  hdr len = 5 32-bit words
			      0x0,     # TOS = 0
			      0,40,    # Total IP Datagram length (default to 40)
			      0,0,     # ID (this datagram)
			      0,0,     # Frag bits and offset
			      0,       # ttl
			      0,       # protocol (TCP/UDP, etc)
			      0,0,     # checksum
			      0,0,0,0, # SRC IP
			      0,0,0,0, # DST IP
			     ]
		 };

    bless $IP_hdr, $class;

    $IP_hdr->version($arg{'version'}) if (defined $arg{'version'});
    $IP_hdr->ip_hdr_len($arg{'ip_hdr_len'}) if (defined $arg{'ip_hdr_len'});
    $IP_hdr->tos($arg{'tos'}) if (defined $arg{'tos'});
    $IP_hdr->dgram_len($arg{'dgram_len'}) if (defined $arg{'dgram_len'});
    $IP_hdr->dgram_id($arg{'dgram_id'}) if (defined $arg{'dgram_id'});
    $IP_hdr->frag($arg{'frag'}) if (defined $arg{'frag'});
    $IP_hdr->ttl($arg{'ttl'}) if (defined $arg{'ttl'});
    $IP_hdr->proto($arg{'proto'}) if (defined $arg{'proto'});
    $IP_hdr->src_ip($arg{'src_ip'}) if (defined $arg{'src_ip'});
    $IP_hdr->dst_ip($arg{'dst_ip'}) if (defined $arg{'dst_ip'});
    $IP_hdr->options($arg{'ip_options'}) if (defined $arg{'ip_options'});
    $IP_hdr->checksum($arg{'checksum'}) if (defined $arg{'checksum'});

    $IP_hdr;
  }

sub version
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "IP Version is %d (0x%01x) but it must be >= 0 and <= 15", $val,$val;
      if (($val < 0) or ($val > 0xf)) { die "$err" }
      @{$self->{'bytes'}}[0] = ($val << 4) | (@{$self->{'bytes'}}[0] & 0xf);
      $self->checksum(0);
      $self->checksum($self->calc_checksum);
    }
    return (@{$self->{'bytes'}}[0] & 0xf0) >> 4;
  }

sub ip_hdr_len
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "IP Hdr Len is %d (0x%01x) but it must be >= 0 and <= 15", $val,$val;
      if (($val < 0) or ($val > 0xf)) { die "$err" }
      @{$self->{'bytes'}}[0] = ($val | (@{$self->{'bytes'}}[0] & 0xf0));
      $self->checksum(0);
      $self->checksum($self->calc_checksum);
    }
    return @{$self->{'bytes'}}[0] & 0xf;
  }

sub tos
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "IP TOS is %d (0x%01x) but it must be >= 0 and <= 0xff", $val,$val;
      if (($val < 0) or ($val > 0xff)) { die "$err" }
      @{$self->{'bytes'}}[1] = $val;
      $self->checksum(0);
      $self->checksum($self->calc_checksum);
    }
    return @{$self->{'bytes'}}[1];
  }

sub dgram_len
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Datagram Length is %d (0x%04x) but it must be >= 0 and <= 0xffff", $val,$val;
      if (($val < 0x0) or ($val > 0xffff)) { die "$err" }

      @{$self->{'bytes'}}[2] = int ($val/256);
      @{$self->{'bytes'}}[3] = int ($val%256);
      $self->checksum(0);
      $self->checksum($self->calc_checksum);
    }
    return (256*@{$self->{'bytes'}}[2] + @{$self->{'bytes'}}[3]);
  }

sub dgram_id
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Datagram ID is %d (0x%04x) but it must be >= 0 and <= 0xffff", $val,$val;
      if (($val < 0x0) or ($val > 0xffff)) { die "$err" }

      @{$self->{'bytes'}}[4] = int ($val/256);
      @{$self->{'bytes'}}[5] = int ($val%256);
      $self->checksum(0);
      $self->checksum($self->calc_checksum);
    }
    return (256*@{$self->{'bytes'}}[4] + @{$self->{'bytes'}}[5]);
  }

sub frag
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Datagram Frag Flags and Offset is %d (0x%04x) but it must be >= 0 and <= 0xffff", $val,$val;
      if (($val < 0x0) or ($val > 0xffff)) { die "$err" }

      @{$self->{'bytes'}}[6] = int ($val/256);
      @{$self->{'bytes'}}[7] = int ($val%256);
      $self->checksum(0);
      $self->checksum($self->calc_checksum);
    }
    return (256*@{$self->{'bytes'}}[6] + @{$self->{'bytes'}}[7]);
  }

sub ttl
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "IP TTL is %d (0x%01x) but it must be >= 0 and <= 0xff", $val,$val;
      if (($val < 0) or ($val > 0xff)) { die "$err" }
      @{$self->{'bytes'}}[8] = $val;
      $self->checksum(0);
      $self->checksum($self->calc_checksum);
    }
    return @{$self->{'bytes'}}[8];
  }

sub proto
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "IP PROTO is %d (0x%01x) but it must be >= 0 and <= 0xff", $val,$val;
      if (($val < 0) or ($val > 0xff)) { die "$err" }
      @{$self->{'bytes'}}[9] = $val;
      $self->checksum(0);
      $self->checksum($self->calc_checksum);
    }
    return @{$self->{'bytes'}}[9];
  }

sub options
  {
    my ($self) = shift;
    my $len = scalar(@_);

    if ($len > 0) {
      my @data;
      if ($len == 1) {
        # Work out if we're dealing with a reference or not
        if (ref($_[0])) {
          @data = @{$_[0]};
        }
        else {
          @data = unpack('C*', shift);
        }
      }
      else {
        @data = @_;
      }

      if (0+@data) {
        @{$self->{'bytes'}} = (@{$self->{'bytes'}}[0..19] , @data);
      }
      else {
        @{$self->{'bytes'}} = @{$self->{'bytes'}}[0..19];
      }

      # Recalculate the checksum
      $self->checksum(0x0);
      $self->checksum($self->calc_checksum);
    }
    else {
      $len = scalar(@{$self->{'bytes'}});
    }

    if ($len >= 20 ) {
      return (@{$self->{'bytes'}}[20..(scalar(@{$self->{'bytes'}}) - 1)]);
    }
    else {
      return ();
    }
  }

sub checksum    # Set or retrieve checksum, NOT calulctae it - see below for generation
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Datagram Checksum is %d (0x%04x) but it must be >= 0 and <= 0xffff", $val,$val;
      if (($val < 0x0) or ($val > 0xffff)) { die "$err" }

      @{$self->{'bytes'}}[10] = int ($val/256);
      @{$self->{'bytes'}}[11] = int ($val%256);
    }
    return (256*@{$self->{'bytes'}}[10] + @{$self->{'bytes'}}[11]);
  }


############################################
# calculate the checksum over the IP header
# including the actual checksum field.
# Returns the checksum.

sub calc_checksum

  {
    my ($self) = @_;

    if ($self->ip_hdr_len == 0) {
      return 0;
    }

    #check consistency of length field
    #if ($self->length_in_bytes != 4*$self->ip_hdr_len) {
    #  die "ERROR: calc_checksum: IP header len field is ".$self->ip_hdr_len.
    #    " 32 bit words but actual IP header length appears to be ".$self->length_in_bytes." bytes.\n"
    #  }

    my $checksum = 0;
    my $word;

    for my $i (0..(2*$self->ip_hdr_len - 1)) {
      $word = ( @{$self->{'bytes'}}[2*$i] << 8 ) | @{$self->{'bytes'}}[2*$i+1] ;
      $checksum += $word;
      if ($checksum & 0xffff0000) {
	$checksum = ($checksum & 0xffff) + ($checksum >> 16);
      }
    }
    return $checksum ^ 0xffff;
  }




# IP address is either a 32 bit int or dotted decimal string.
sub src_ip
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $ok;
      ($val,$ok) = getIP($val);
      #print "src ip is $val\n";
      @{$self->{'bytes'}}[12] = ($val & 0xff000000) >> 24;
      @{$self->{'bytes'}}[13] = ($val & 0x00ff0000) >> 16;
      @{$self->{'bytes'}}[14] = ($val & 0x0000ff00) >> 8;
      @{$self->{'bytes'}}[15] = ($val & 0xff);
      $self->checksum(0);
      $self->checksum($self->calc_checksum);
    }
    return Socket::inet_ntoa(pack('N',
             (@{$self->{'bytes'}}[12]<<24 |
              @{$self->{'bytes'}}[13]<<16 |
              @{$self->{'bytes'}}[14]<<8 |
              @{$self->{'bytes'}}[15]
              )
            ));
  }

sub dst_ip
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $ok;
      ($val,$ok) = getIP($val);
      @{$self->{'bytes'}}[16] = ($val & 0xff000000) >> 24;
      @{$self->{'bytes'}}[17] = ($val & 0x00ff0000) >> 16;
      @{$self->{'bytes'}}[18] = ($val & 0x0000ff00) >> 8;
      @{$self->{'bytes'}}[19] = ($val & 0xff);
      $self->checksum(0);
      $self->checksum($self->calc_checksum);
    }
    return Socket::inet_ntoa(pack('N',
             (@{$self->{'bytes'}}[16]<<24 |
              @{$self->{'bytes'}}[17]<<16 |
              @{$self->{'bytes'}}[18]<<8 |
              @{$self->{'bytes'}}[19]
              )
            ));
  }

# input is either a 32 bit integer or else a dotted decimal IP address
# return it as integer folowed by flag 0=bad 1=good.
sub getIP {
  my $ip = shift;
  if ($ip =~ m/^(\d+)\.(\d+)\.(\d+)\.(\d+)$/) {
    my $newip = $1<<24 | $2<<16 | $3<<8 | $4;
    return ($newip,1);
  }
  unless ($ip =~ m/^\d+$/) {
    print "Bad IP address: $ip" ;
    return (0,0);
  }
  return ($ip,1);
}

package NF::RCP_hdr;

use vars qw(@ISA);
@ISA = qw(NF::PDU);

sub new   # RCP_hdr
  {
    my ($class,%arg) = @_;

    my $RCP_hdr = {
		  'bytes' => [
			      0,0,0,0, # fwd
			      0,0,0,0, # rev
			      0,0,0,0  # rtt (16b), proto (8b), unused (8b)
			     ]
		 };

    bless $RCP_hdr, $class;

    $RCP_hdr->fwd($arg{'fwd'}) if (defined $arg{'fwd'});
    $RCP_hdr->rev($arg{'rev'}) if (defined $arg{'rev'});
    $RCP_hdr->rtt($arg{'rtt'}) if (defined $arg{'rtt'});
    $RCP_hdr->proto($arg{'proto'}) if (defined $arg{'proto'});

    $RCP_hdr;
  }

sub fwd
  {
    my ($self, $val) = @_;

    if (defined $val) {
      @{$self->{'bytes'}}[0] = ($val & 0xff000000) >> 24;
      @{$self->{'bytes'}}[1] = ($val & 0x00ff0000) >> 16;
      @{$self->{'bytes'}}[2] = ($val & 0x0000ff00) >> 8;
      @{$self->{'bytes'}}[3] = ($val & 0xff);
    }
    return (@{$self->{'bytes'}}[0]<<24 |
	    @{$self->{'bytes'}}[1]<<16 |
	    @{$self->{'bytes'}}[2]<<8 |
	    @{$self->{'bytes'}}[3]
	    );
  }

sub rev
  {
    my ($self, $val) = @_;

    if (defined $val) {
      @{$self->{'bytes'}}[4] = ($val & 0xff000000) >> 24;
      @{$self->{'bytes'}}[5] = ($val & 0x00ff0000) >> 16;
      @{$self->{'bytes'}}[6] = ($val & 0x0000ff00) >> 8;
      @{$self->{'bytes'}}[7] = ($val & 0xff);
    }
    return (@{$self->{'bytes'}}[4]<<24 |
	    @{$self->{'bytes'}}[5]<<16 |
	    @{$self->{'bytes'}}[6]<<8 |
	    @{$self->{'bytes'}}[7]
	    );
  }

sub rtt
  {
    my ($self, $val) = @_;

    if (defined $val) {
      @{$self->{'bytes'}}[8] = ($val & 0x0000ff00) >> 8;
      @{$self->{'bytes'}}[9] = ($val & 0xff);
    }
    return (@{$self->{'bytes'}}[8]<<8 |
	    @{$self->{'bytes'}}[9]
	    );
  }

sub proto
  {
    my ($self, $val) = @_;

    if (defined $val) {
      @{$self->{'bytes'}}[10] = ($val & 0xff);
    }
    return (@{$self->{'bytes'}}[10]
	    );
  }

####################################################################################
# ICMP payload functions
####################################################################################
package NF::ICMP;

use vars qw(@ISA);
@ISA = qw(NF::PDU);

sub ECHO_REQ      {8};
sub ECHO_REP      {0};
sub TIME_EXCEEDED {11};
sub TTL_ZERO      {0};
sub DEST_UNREACH  {3};
sub DEST_NET_UNREACH    {0};
sub DEST_HOST_UNREACH   {1};
sub DEST_PROTO_UNREACH  {2};
sub DEST_PORT_UNREACH   {3};
sub DGRAM_TO_BIG        {4};

sub NEXT_HOP_DEFAULT_MTU  {1500};

sub new   # ICMP
  {
    my ($class,%arg) = @_;

    my $icmp = $class->NF::PDU::new();

    @{$icmp->{'bytes'}}[0..7] = (0x08,          # Type
                                 0x00,          # Code
				 0x00, 0x00,    # Header checksum
				 0x00, 0x00,    # Identifier
				 0x00, 0x00,    # Sequence number
				 );
    bless $icmp, $class;

    $icmp->Type($arg{'Type'}) if (defined $arg{'Type'});
    $icmp->Code($arg{'Code'}) if (defined $arg{'Code'});
    $icmp->Identifier($arg{'Identifier'}) if (defined $arg{'Identifier'});
    $icmp->SeqNo($arg{'SeqNo'}) if (defined $arg{'SeqNo'});
    $icmp->Data($arg{'Data'}) if (defined $arg{'Data'});
    $icmp->Checksum($arg{'ICMP_checksum'}) if (defined($arg{'ICMP_checksum'}));
    # Note: if the checksum is not specified it will be automatically calculated
    # as each field is set.

    $icmp;
  }

sub Type
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Type is %d (0x%02x) but it must be >= 0 and <= 255",
      $val, $val;
      if (($val < 0x0) or ($val > 0xff)) { die "$err" }
      @{$self->{'bytes'}}[0] = int ($val%256);

      # Recalculate the checksum
      $self->Checksum(0x0);
      $self->Checksum($self->calc_checksum);
    }
    return ( @{$self->{'bytes'}}[0] );
  }

sub Code
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Code is %d (0x%02x) but it must be >= 0 and <= 255",
      $val, $val;
      if (($val < 0x0) or ($val > 0xff)) { die "$err" }
      @{$self->{'bytes'}}[1] = int ($val%256);

      # Recalculate the checksum
      $self->Checksum(0x0);
      $self->Checksum($self->calc_checksum);
    }
    return ( @{$self->{'bytes'}}[1] );
  }

sub Identifier
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Identifier is %d (0x%04x) but it must be >= 0 and <= 0xffff",
      $val, $val;
      if (($val < 0x0) or ($val > 0xffff)) { die "$err" }
      @{$self->{'bytes'}}[4] = int ($val/256);
      @{$self->{'bytes'}}[5] = int ($val%256);

      # Recalculate the checksum
      $self->Checksum(0x0);
      $self->Checksum($self->calc_checksum);
    }
    return (256*@{$self->{'bytes'}}[4] + @{$self->{'bytes'}}[5]);
  }

sub SeqNo
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "SeqNo is %d (0x%04x) but it must be >= 0 and <= 0xffff",
      $val, $val;
      if (($val < 0x0) or ($val > 0xffff)) { die "$err" }
      @{$self->{'bytes'}}[6] = int ($val/256);
      @{$self->{'bytes'}}[7] = int ($val%256);

      # Recalculate the checksum
      $self->Checksum(0x0);
      $self->Checksum($self->calc_checksum);
    }
    return (256*@{$self->{'bytes'}}[6] + @{$self->{'bytes'}}[7]);
  }

sub Data
  {
    my ($self) = shift;
    my $len = scalar(@_);

    if ($len > 0) {
      my @data;
      if ($len == 1) {
        # Work out if we're dealing with a reference or not
        if (ref($_[0])) {
          @data = @{$_[0]};
        }
        else {
          @data = unpack('C*', shift);
        }
      }
      else {
        @data = @_;
      }

      if (0+@data) {
        @{$self->{'bytes'}} = (@{$self->{'bytes'}}[0..7] , @data);
      }
      else {
        @{$self->{'bytes'}} = @{$self->{'bytes'}}[0..7];
      }

      # Recalculate the checksum
      $self->Checksum(0x0);
      $self->Checksum($self->calc_checksum);
    }
    else {
      $len = scalar(@{$self->{'bytes'}});
    }

    if ($len >= 8 ) {
      return (@{$self->{'bytes'}}[8..(scalar(@{$self->{'bytes'}}) - 1)]);
    }
    else {
      return ();
    }
  }

sub Checksum    # Set or retrieve checksum, NOT calulctae it - see below for generation
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "ICMP Checksum is %d (0x%04x) but it must be >= 0 and <= 0xffff", $val,$val;
      if (($val < 0x0) or ($val > 0xffff)) { die "$err" }

      @{$self->{'bytes'}}[2] = int ($val/256);
      @{$self->{'bytes'}}[3] = int ($val%256);
    }
    return (256*@{$self->{'bytes'}}[2] + @{$self->{'bytes'}}[3]);
  }


############################################
# calculate the checksum over the ICMP PDU
# including the actual checksum field.
# Returns the checksum.

sub calc_checksum

  {
    my ($self) = @_;

    # Calculate the length of the ICMP PDU
    my $len = scalar(@{$self->{'bytes'}});

    if ($len % 2 == 1) {
      die "ERROR: calc_checksum: ICMP PDU length is " . $len .
	" bytes. Must be a multiple of 2 bytes.\n"
      }

    my $checksum = 0;
    my $word;

    for my $i (0..($len / 2 - 1)) {
      $word = ( @{$self->{'bytes'}}[2*$i] << 8 ) | @{$self->{'bytes'}}[2*$i+1] ;
      $checksum += $word;
      if ($checksum & 0xffff0000) {
	$checksum = ($checksum & 0xffff) + ($checksum >> 16);
      }
    }
    return $checksum ^ 0xffff;
  }

####################################################################################
# UDP payload functions
####################################################################################
package NF::UDP;

use vars qw(@ISA);
@ISA = qw(NF::PDU);

sub new   # UDP
  {
    my ($class,%arg) = @_;

    my $udp = $class->NF::PDU::new();

    @{$udp->{'bytes'}}[0..7] = (0x00, 0x00,    # Source port
                                0x00, 0x00,    # Dest port
				0x00, 0x00,    # Length
				0x00, 0x00,    # Checksum
				);
    bless $udp, $class;

    $udp->SrcPort($arg{'src_port'}) if (defined $arg{'src_port'});
    $udp->DstPort($arg{'dst_port'}) if (defined $arg{'dst_port'});
    $udp->Length($arg{'udp_len'}) if (defined $arg{'udp_len'});
    $udp->Checksum($arg{'udp_checksum'}) if (defined($arg{'udp_checksum'}));
    $udp->Data($arg{'data'}) if (defined($arg{'data'}));
    $udp->IP_hdr($arg{'ip_hdr'}) if (defined($arg{'ip_hdr'}));
    # Note: if the checksum is not specified it will be automatically calculated
    # as each field is set.

    $udp;
  }

sub SrcPort
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Source port is %d (0x%02x) but it must be >= 0 and <= 0xffff",
      $val, $val;
      if (($val < 0x0) or ($val > 0xffff)) { die "$err" }
      @{$self->{'bytes'}}[0] = int ($val/256);
      @{$self->{'bytes'}}[1] = int ($val%256);

      # Recalculate the checksum
      $self->Checksum(0x0);
      $self->Checksum($self->calc_checksum);
    }
    return (256*@{$self->{'bytes'}}[0] + @{$self->{'bytes'}}[1]);
  }

sub DstPort
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Destination port is %d (0x%02x) but it must be >= 0 and <= 0xffff",
      $val, $val;
      if (($val < 0x0) or ($val > 0xffff)) { die "$err" }
      @{$self->{'bytes'}}[2] = int ($val/256);
      @{$self->{'bytes'}}[3] = int ($val%256);

      # Recalculate the checksum
      $self->Checksum(0x0);
      $self->Checksum($self->calc_checksum);
    }
    return (256*@{$self->{'bytes'}}[2] + @{$self->{'bytes'}}[3]);
  }

sub Length
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Length is %d (0x%02x) but it must be >= 0 and <= 0xffff",
      $val, $val;
      if (($val < 0x0) or ($val > 0xffff)) { die "$err" }
      @{$self->{'bytes'}}[4] = int ($val/256);
      @{$self->{'bytes'}}[5] = int ($val%256);

      # Recalculate the checksum
      $self->Checksum(0x0);
      $self->Checksum($self->calc_checksum);
    }
    return (256*@{$self->{'bytes'}}[4] + @{$self->{'bytes'}}[5]);
  }

sub Data
  {
    my ($self) = shift;
    my $len = scalar(@_);

    if ($len > 0) {
      my @data;
      if ($len == 1) {
        # Work out if we're dealing with a reference or not
        if (ref($_[0])) {
          @data = @{$_[0]};
        }
        else {
          @data = unpack('C*', shift);
        }
      }
      else {
        @data = @_;
      }

      if (0+@data) {
        @{$self->{'bytes'}} = (@{$self->{'bytes'}}[0..7] , @data);
      }
      else {
        @{$self->{'bytes'}} = @{$self->{'bytes'}}[0..7];
      }

      # Recalculate the checksum
      $self->Checksum(0x0);
      $self->Checksum($self->calc_checksum);
    }
    else {
      $len = scalar(@{$self->{'bytes'}});
    }

    if ($len >= 8 ) {
      return (@{$self->{'bytes'}}[8..(scalar(@{$self->{'bytes'}}) - 1)]);
    }
    else {
      return ();
    }
  }

sub Checksum    # Set or retrieve checksum, NOT calulctae it - see below for generation
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "UDP Checksum is %d (0x%04x) but it must be >= 0 and <= 0xffff", $val,$val;
      if (($val < 0x0) or ($val > 0xffff)) { die "$err" }

      @{$self->{'bytes'}}[6] = int ($val/256);
      @{$self->{'bytes'}}[7] = int ($val%256);
    }
    return (256*@{$self->{'bytes'}}[6] + @{$self->{'bytes'}}[7]);
  }

sub IP_hdr
  {
    my ($self, $hdr) = @_;

    if (defined $hdr) {
      $self->{'ip_hdr'} = $hdr;

      # Recalculate the checksum
      $self->Checksum(0x0);
      $self->Checksum($self->calc_checksum);
    }
    if (defined($self->{'ip_hdr'})) {
      return $self->{'ip_hdr'};
    }
  }


############################################
# calculate the checksum over the ICMP PDU
# including the actual checksum field.
# Returns the checksum.

sub calc_checksum

  {
    my ($self) = @_;

    # Calculate the length of the ICMP PDU
    my $len = scalar(@{$self->{'bytes'}});

    # Generate the pseudo packet
    my @bytes;
    if (defined($self->{'ip_hdr'})) {
      my $iphdr = $self->{'ip_hdr'};

      push @bytes, unpack('C*', Socket::inet_aton($$iphdr->src_ip()));
      push @bytes, unpack('C*', Socket::inet_aton($$iphdr->dst_ip()));
      push @bytes, (0, $$iphdr->proto());
      push @bytes, (int($len / 256), $len % 256);
    }
    else {
      @bytes = ( 0 ) x 12;
    }

    push (@bytes, @{$self->{'bytes'}});

    # Pad to a multiple of 2 bytes
    if ($len % 2 == 1) {
      $len++;
      push (@bytes, (0));
    }

    # Include the pseudo-header in the length
    $len += 12;

    my $checksum = 0;
    my $word;

    for my $i (0..($len / 2 - 1)) {
      $word = ( @bytes[2*$i] << 8 ) | @bytes[2*$i+1] ;
      $checksum += $word;
      if ($checksum & 0xffff0000) {
	$checksum = ($checksum & 0xffff) + ($checksum >> 16);
      }
    }
    return $checksum ^ 0xffff;
  }

####################################################################################
# ARP pkt functions
####################################################################################
package NF::ARP;

use vars qw(@ISA);
@ISA = qw(NF::PDU);

sub ARP_REQUEST { 1};
sub ARP_REPLY {2};
sub ARP_OP_MASK {-1};

sub new   # ARP
  {
    my ($class,%arg) = @_;

    my $Arp = $class->NF::PDU::new();

    @{$Arp->{'bytes'}}[0..27] = (0x00, 0x01,    # HardType (fixed)
				 0x08, 0x00,    # ProtType (fixed)
				 0x06,          # HardSize (fixed)
				 0x04,          # ProtSize (fixed)
				 0x00, 0x00,    # Op       (1: req; 2: rply)
				 0,0,0,0,0,0,   # SenderEthAddr
				 0,0,0,0,       # SenderIpAddr
				 0,0,0,0,0,0,   # TargetEthAddr
				 0,0,0,0        # TargerIpAddr
				 );
    bless $Arp, $class;

    $Arp->Op($arg{'Op'}) if (defined $arg{'Op'});
    $Arp->SenderEthAddr($arg{'SenderEthAddr'}) if (defined $arg{'SenderEthAddr'});
    $Arp->SenderIpAddr($arg{'SenderIpAddr'}) if (defined $arg{'SenderIpAddr'});
    $Arp->TargetEthAddr($arg{'TargetEthAddr'}) if (defined $arg{'TargetEthAddr'});
    $Arp->TargetIpAddr($arg{'TargetIpAddr'}) if (defined $arg{'TargetIpAddr'});

    $Arp;
  }

sub Op
  {
    my ($self, $val) = @_;

    if (defined $val) {
      my $err = sprintf "Op is %d (0x%04x) but it must be either 1 or 2 or ARP_OP_MASK",
      $val, $val;
      if (($val != ARP_REQUEST) && ($val != ARP_REPLY) && ($val != ARP_OP_MASK)) { die "$err" }

      if ($val == ARP_OP_MASK) {
        $val = 0xff;
      }
      @{$self->{'bytes'}}[7] = int ($val%256);
    }
    return ( @{$self->{'bytes'}}[7] );
  }

sub SenderEthAddr
  {
    my ($self, $val) = @_;

    if (defined $val) {
      @{$self->{'bytes'}}[8..13] = NF::PDU::get_MAC_address($val);
    }
    return (sprintf("%02x:%02x:%02x:%02x:%02x:%02x",@{$self->{'bytes'}}[8..13] ))
;
  }

# MAC addr format:
#                 ..:..:..
#                 ..-..-..
#                 .. .. ..
sub TargetEthAddr
  {
    my ($self, $val) = @_;

    if (defined $val) {
      @{$self->{'bytes'}}[18..23] = NF::PDU::get_MAC_address($val);
    }
    return (sprintf("%02x:%02x:%02x:%02x:%02x:%02x",@{$self->{'bytes'}}[18..23] ))
;
  }

# IP address is either a 32 bit int or dotted decimal string.
sub SenderIpAddr
  {
      my ($self, $val) = @_;

      if (defined $val) {
	  my $ok;
	  ($val,$ok) = NF::IP_hdr::getIP($val);
	  #print "sender ip is $val\n";
	  @{$self->{'bytes'}}[14] = ($val & 0xff000000) >> 24;
	  @{$self->{'bytes'}}[15] = ($val & 0x00ff0000) >> 16;
	  @{$self->{'bytes'}}[16] = ($val & 0x0000ff00) >> 8;
	  @{$self->{'bytes'}}[17] = ($val & 0xff);
      }
      return Socket::inet_ntoa(pack('N',
               (@{$self->{'bytes'}}[14]<<24 |
                @{$self->{'bytes'}}[15]<<16 |
                @{$self->{'bytes'}}[16]<<8 |
                @{$self->{'bytes'}}[17]
                )
              ));

  }

sub TargetIpAddr
  {
      my ($self, $val) = @_;

      if (defined $val) {
	  my $ok;
	  ($val,$ok) = NF::IP_hdr::getIP($val);
	  #print "sender ip is $val\n";
	  @{$self->{'bytes'}}[24] = ($val & 0xff000000) >> 24;
	  @{$self->{'bytes'}}[25] = ($val & 0x00ff0000) >> 16;
	  @{$self->{'bytes'}}[26] = ($val & 0x0000ff00) >> 8;
	  @{$self->{'bytes'}}[27] = ($val & 0xff);
      }
      return Socket::inet_ntoa(pack('N',
               (@{$self->{'bytes'}}[24]<<24 |
                @{$self->{'bytes'}}[25]<<16 |
                @{$self->{'bytes'}}[26]<<8 |
                @{$self->{'bytes'}}[27]
                )
              ));

  }


####################################################################################
# IP packet
####################################################################################

package NF::IP_pkt;

use Carp;
use strict;

use constant IP_Ethertype => 0x0800;
use constant ETH_HDR_LEN => 6 + 6 + 2;
use constant IP_HDR_LEN => 5 * 4;
#use constant MIN_LEN => ETH_HDR_LEN + IP_HDR_LEN;
use constant PROTO_RESERVED => 255;

sub MIN_LEN {ETH_HDR_LEN + IP_HDR_LEN;}

sub new   # Ethernet_hdr
  {
    my ($class, %arg) = @_;

    my $force = defined($arg{'force'}) && $arg{'force'};

    $arg{'Ethertype'} = IP_Ethertype if (!$force || !defined($arg{'Ethertype'}));
    $arg{'len'} = MIN_LEN if (!defined($arg{'len'}));
    $arg{'dgram_len'} = $arg{'len'} - ETH_HDR_LEN if (!$force || !defined($arg{'dgram_len'}));
    if ($arg{'dgram_len'} < IP_HDR_LEN && !$force) {
      die "IP packet length $arg{'dgram_len'} is too small. Must be at least " . MIN_LEN . " bytes\n";
    }
    my $payloadLen = $arg{'dgram_len'} - IP_HDR_LEN;
    $payloadLen = 0 if $payloadLen < 0;
    $arg{'proto'} = PROTO_RESERVED if (!defined($arg{'proto'}));

    # Create the various PDUs
    my $Ethernet_hdr = new NF::Ethernet_hdr(%arg);
    my $IP_hdr = new NF::IP_hdr(%arg);
    my $payload = new NF::PDU($payloadLen);
    $payload->set_bytes(map {int(rand(256))} (0..($payloadLen - 1)) );

    # Create the parts list that says what PDUs are inside the packet
    my @parts = ('Ethernet_hdr', 'IP_hdr', 'payload');

    # Create the object
    my $self = {
      Parts         => \@parts,
      Ethernet_hdr  => \$Ethernet_hdr,
      IP_hdr        => \$IP_hdr,
      payload       => \$payload,
    };

    return bless ($self, $class);
  }

# Return the raw bytes as a single string of hex bytes with trailing space,
# suitable for use as parameter to nf_packet_in() or nf_expected_packet()
sub bytes {
  my ($self) = @_;

  # Work out the parts in the packet
  my $parts = $self->{Parts};

  # Get the bytes for each section and concatenate them
  my $bytes = "";
  foreach my $partName (@$parts) {
    my $part = $self->{$partName};
    $bytes .= $$part->bytes();
  }

  return $bytes;
}

# get a packed representation of the packet
sub packed {
  my ($self) = @_;

  # Work out the parts in the packet
  my $parts = $self->{Parts};

  # Get the bytes for each section and concatenate them
  my $packed = "";
  foreach my $partName (@$parts) {
    my $part = $self->{$partName};
    $packed .= $$part->packed();
  }

  return $packed;
}

# How long is this object (in bytes)
sub length_in_bytes {
  my ($self) = @_;

  # Work out the parts in the packet
  my $parts = $self->{Parts};

  # Get the bytes for each section and concatenate them
  my $length = 0;
  foreach my $partName (@$parts) {
    my $part = $self->{$partName};
    $length += $$part->length_in_bytes();
  }

  return $length;
}

# Change both headers
sub set {
  my ($self, %arg) = @_;

  my $force = defined($arg{'force'}) && $arg{'force'};

  # Change the DA or SA (but not the Ethertype since this is IP)
  ${$self->{Ethernet_hdr}}->DA($arg{'DA'}) if (defined $arg{'DA'});
  ${$self->{Ethernet_hdr}}->SA($arg{'SA'}) if (defined $arg{'SA'});
  ${$self->{Ethernet_hdr}}->Ethertype($arg{'Ethertype'}) if (defined $arg{'Ethertype'} && $force);

  # Change the IP header if appropriate options are set
  if (defined($arg{'len'}) || defined($arg{'dgram_len'})) {
    $arg{'len'} = $arg{'dgram_len'} + ETH_HDR_LEN if (!defined($arg{'len'}));
    $arg{'dgram_len'} = $arg{'len'} - ETH_HDR_LEN if (!$force && !defined($arg{'dgram_len'}));
    if ($arg{'dgram_len'} < IP_HDR_LEN && !$force) {
      die "IP packet length $arg{'length'} is too small. Must be at least " . MIN_LEN . " bytes\n";
    }
    my $payloadLen = $arg{'dgram_len'} - IP_HDR_LEN;
    $payloadLen = 0 if ($payloadLen < 0);

    if (defined($self->{payload})) {
      ${$self->{payload}}->set_bytes(map {int(rand(256))} (0..($payloadLen - 1)) );
    }
  }

  # Change allowable IP header options
  ${$self->{IP_hdr}}->version($arg{'version'}) if (defined $arg{'version'});
  ${$self->{IP_hdr}}->ip_hdr_len($arg{'ip_hdr_len'}) if (defined $arg{'ip_hdr_len'});
  ${$self->{IP_hdr}}->tos($arg{'tos'}) if (defined $arg{'tos'});
  ${$self->{IP_hdr}}->dgram_len($arg{'dgram_len'}) if (defined $arg{'dgram_len'});
  ${$self->{IP_hdr}}->dgram_id($arg{'dgram_id'}) if (defined $arg{'dgram_id'});
  ${$self->{IP_hdr}}->frag($arg{'frag'}) if (defined $arg{'frag'});
  ${$self->{IP_hdr}}->ttl($arg{'ttl'}) if (defined $arg{'ttl'});
  ${$self->{IP_hdr}}->proto($arg{'proto'}) if (defined $arg{'proto'});
  ${$self->{IP_hdr}}->src_ip($arg{'src_ip'}) if (defined $arg{'src_ip'});
  ${$self->{IP_hdr}}->dst_ip($arg{'dst_ip'}) if (defined $arg{'dst_ip'});
  ${$self->{IP_hdr}}->checksum($arg{'checksum'}) if (defined $arg{'checksum'});
}

# Get values from the various headers
sub get {
  my ($self, $field) = @_;

  # Ethernet header fields
  return ${$self->{Ethernet_hdr}}->DA if ($field eq "DA");
  return ${$self->{Ethernet_hdr}}->SA if ($field eq "SA");
  return ${$self->{Ethernet_hdr}}->Ethertype if ($field eq "Ethertype");

  # IP header fields
  return ${$self->{IP_hdr}}->version if ($field eq'version');
  return ${$self->{IP_hdr}}->ip_hdr_len if ($field eq'ip_hdr_len');
  return ${$self->{IP_hdr}}->tos if ($field eq'tos');
  return ${$self->{IP_hdr}}->dgram_len if ($field eq'dgram_len');
  return ${$self->{IP_hdr}}->dgram_id if ($field eq'dgram_id');
  return ${$self->{IP_hdr}}->frag if ($field eq'frag');
  return ${$self->{IP_hdr}}->ttl if ($field eq'ttl');
  return ${$self->{IP_hdr}}->proto if ($field eq'proto');
  return ${$self->{IP_hdr}}->src_ip if ($field eq'src_ip');
  return ${$self->{IP_hdr}}->dst_ip if ($field eq'dst_ip');
  return ${$self->{IP_hdr}}->checksum if ($field eq'checksum');
}

# Change the Ethernet header
sub set_eth_hdr {
  my ($self, %arg) = @_;

  $self->set(%arg);
}


# Change the IP header
sub set_ip_hdr {
  my ($self, %arg) = @_;

  $self->set(%arg);
}

# Decrement the TTL
sub decrement_ttl {
  my ($self, %arg) = @_;

  ${$self->{IP_hdr}}->ttl(${$self->{IP_hdr}}->ttl - 1);
}

####################################################################################
# ARP packet
####################################################################################

package NF::ARP_pkt;

use Carp;
use strict;

use constant ARP_Ethertype => 0x0806;
use constant ETH_HDR_LEN => 6 + 6 + 2;
use constant ARP_HDR_LEN => 6 * 4;
use constant MIN_LEN => ETH_HDR_LEN + ARP_HDR_LEN;


sub new   # Ethernet_hdr
  {
    my ($class, %arg) = @_;

    my $force = defined($arg{'force'}) && $arg{'force'};

    $arg{'Ethertype'} = ARP_Ethertype if (!$force || !defined($arg{'Ethertype'}));
    $arg{'len'} = MIN_LEN if (!defined($arg{'len'}));
    if ($arg{'len'} < MIN_LEN && !$force) {
      die "ARP packet length $arg{'len'} is too small. Must be at least " . MIN_LEN . " bytes\n";
    }
    my $payloadLen = $arg{'len'} - MIN_LEN;
    $payloadLen = 0 if $payloadLen < 0;

    # Create the various PDUs
    my $Ethernet_hdr = new NF::Ethernet_hdr(%arg);
    my $ARP_hdr = new NF::ARP(%arg);
    my $payload = new NF::PDU($payloadLen);

    # Create the parts list that says what PDUs are inside the packet
    my @parts = ('Ethernet_hdr', 'ARP_hdr', 'payload');

    # Create the object
    my $self = {
      Parts         => \@parts,
      Ethernet_hdr  => \$Ethernet_hdr,
      ARP_hdr       => \$ARP_hdr,
      payload       => \$payload,
    };

    return bless ($self, $class);
  }

sub new_request   # Ethernet_hdr
  {
    my ($class, %arg) = @_;

    $arg{'Op'} = NF::ARP->ARP_REQUEST;
    $arg{'SenderEthAddr'} = $arg{'SA'};
    $arg{'DA'} = 'ff:ff:ff:ff:ff:ff';
    $arg{'TargetEthAddr'} = '00:00:00:00:00:00';

    return $class->new(%arg);
  }

sub new_reply   # Ethernet_hdr
  {
    my ($class, %arg) = @_;

    $arg{'Op'} = NF::ARP->ARP_REPLY;
    $arg{'SenderEthAddr'} = $arg{'SA'};
    $arg{'TargetEthAddr'} = $arg{'DA'};

    return $class->new(%arg);
  }

sub new_packed   # Ethernet_hdr
  {
    my ($class, %arg) = @_;

    # Create an ARP_pkt
    my $self = $class->new();

    # Populate each header
    my $start = 0;
    foreach my $name (@{$self->{'Parts'}}) {
      my $part = $self->{$name};
      my $len = ${$part}->length_in_bytes();

      # Get the data
      my $data = substr($arg{'Data'}, $start, $len);

      # Set the bytes
      ${$part}->set_bytes(map {unpack 'C', $_} split('', $data));

      # Update the start
      $start += $len;
    }

    return $self;
  }

# Return the raw bytes as a single string of hex bytes with trailing space,
# suitable for use as parameter to nf_packet_in() or nf_expected_packet()
sub bytes {
  my ($self) = @_;

  # Work out the parts in the packet
  my $parts = $self->{Parts};

  # Get the bytes for each section and concatenate them
  my $bytes = "";
  foreach my $partName (@$parts) {
    my $part = $self->{$partName};
    $bytes .= $$part->bytes();
  }

  return $bytes;
}

# get a packed representation of the packet
sub packed {
  my ($self) = @_;

  # Work out the parts in the packet
  my $parts = $self->{Parts};

  # Get the bytes for each section and concatenate them
  my $packed = "";
  foreach my $partName (@$parts) {
    my $part = $self->{$partName};
    $packed .= $$part->packed();
  }

  return $packed;
}

# How long is this object (in bytes)
sub length_in_bytes {
  my ($self) = @_;

  # Work out the parts in the packet
  my $parts = $self->{Parts};

  # Get the bytes for each section and concatenate them
  my $length = 0;
  foreach my $partName (@$parts) {
    my $part = $self->{$partName};
    $length += $$part->length_in_bytes();
  }

  return $length;
}

# Change both headers
sub set {
  my ($self, %arg) = @_;

  my $force = defined($arg{'force'}) && $arg{'force'};

  # Change the DA or SA (but not the Ethertype since this is IP)
  ${$self->{Ethernet_hdr}}->DA($arg{'DA'}) if (defined $arg{'DA'});
  ${$self->{Ethernet_hdr}}->SA($arg{'SA'}) if (defined $arg{'SA'});
  ${$self->{Ethernet_hdr}}->Ethertype($arg{'Ethertype'}) if (defined $arg{'Ethertype'} && $force);

  # Change the ARP header if appropriate options are set
  if (defined($arg{'len'})) {
    if ($arg{'len'} < MIN_LEN && !$force) {
      die "ARP packet length $arg{'len'} is too small. Must be at least " . MIN_LEN . " bytes\n";
    }
    my $payloadLen = $arg{'len'} - MIN_LEN;
    $payloadLen = 0 if ($payloadLen < 0);

    ${$self->{payload}}->set_bytes((0) x $payloadLen);
  }

  # Change allowable IP header options
  ${$self->{ARP_hdr}}->Op($arg{'Op'}) if (defined $arg{'Op'});
  ${$self->{ARP_hdr}}->SenderEthAddr($arg{'SenderEthAddr'}) if (defined $arg{'SenderEthAddr'});
  ${$self->{ARP_hdr}}->SenderIpAddr($arg{'SenderIpAddr'}) if (defined $arg{'SenderIpAddr'});
  ${$self->{ARP_hdr}}->TargetEthAddr($arg{'TargetEthAddr'}) if (defined $arg{'TargetEthAddr'});
  ${$self->{ARP_hdr}}->TargetIpAddr($arg{'TargetIpAddr'}) if (defined $arg{'TargetIpAddr'});
}

# Get values from the various headers
sub get {
  my ($self, $field) = @_;

  # Ethernet header fields
  return ${$self->{Ethernet_hdr}}->DA if ($field eq "DA");
  return ${$self->{Ethernet_hdr}}->SA if ($field eq "SA");
  return ${$self->{Ethernet_hdr}}->Ethertype if ($field eq "Ethertype");

  # ARP header fields
  return ${$self->{ARP_hdr}}->Op if ($field eq "Op");
  return ${$self->{ARP_hdr}}->SenderEthAddr if ($field eq "SenderEthAddr");
  return ${$self->{ARP_hdr}}->SenderIpAddr if ($field eq "SenderIpAddr");
  return ${$self->{ARP_hdr}}->TargetEthAddr if ($field eq "TargetEthAddr");
  return ${$self->{ARP_hdr}}->TargetIpAddr if ($field eq "TargetIpAddr");
}

####################################################################################
# ICMP packet
####################################################################################

package NF::ICMP_pkt;

use Carp;
use strict;
use vars qw(@ISA);
@ISA = qw(NF::IP_pkt);

use constant PROTO_ICMP => 1;
use constant DEFAULT_DATA_LEN => 56;
use constant DEST_UNREACH_DATA_LEN => NF::IP_pkt::IP_HDR_LEN + 8;


sub new   # Ethernet_hdr
  {
    my ($class, %arg) = @_;

    my $force = defined($arg{'force'}) && $arg{'force'};

    # Set various arguments
    $arg{'proto'} = PROTO_ICMP if (!$force || !defined($arg{'proto'}));

    # Create the ICMP PDU
    my $ICMP_pdu = new NF::ICMP(%arg);

    # Calculate the length of the packet
    $arg{'len'} = NF::IP_pkt::MIN_LEN() + $ICMP_pdu->length_in_bytes() if
        (!$force || !defined($arg{'len'}));
    $arg{'frag'} = 0x4000 if (!$force && !defined($arg{'frag'}));
    $arg{'ttl'} = 64 if (!$force || !defined($arg{'ttl'}));

    # Create the packet
    my $Pkt = $class->NF::IP_pkt::new(%arg);

    # Create the parts list that says what PDUs are inside the packet
    my @parts = ('Ethernet_hdr', 'IP_hdr', 'ICMP_pdu');

    # Replace the parts array and stuff the new PDU
    $Pkt->{'ICMP_pdu'} = \$ICMP_pdu;
    $Pkt->{'Parts'} = \@parts;
    delete($Pkt->{'payload'});

    return $Pkt;
  }

# Create a new echo request
sub new_echo_request
  {
    my ($class, %arg) = @_;

    $arg{'Type'} = NF::ICMP->ECHO_REQ;
    $arg{'Code'} = 0;

    $arg{'Data'} = [map {$_ % 256} (1..DEFAULT_DATA_LEN)] if (!defined($arg{'Data'}));

    return $class->new(%arg);
  }

# Create a new echo reply
sub new_echo_reply
  {
    my ($class, %arg) = @_;

    $arg{'Type'} = NF::ICMP->ECHO_REP;
    $arg{'Code'} = 0;

    if (defined($arg{'Request'})) {
      my $req = $arg{'Request'};

      $arg{'SA'} = $req->get('DA');
      $arg{'DA'} = $req->get('SA');
      $arg{'src_ip'} = $req->get('dst_ip');
      $arg{'dst_ip'} = $req->get('src_ip');
      $arg{'Identifier'} = $req->get('Identifier');
      $arg{'SeqNo'} = $req->get('SeqNo');
      my @data = $req->get('Data');
      $arg{'Data'} = \@data;
    }
    else {
      $arg{'Data'} = map {int(rand(256))} (1..DEFAULT_DATA_LEN) if (!defined($arg{'Data'}));
    }

    return $class->new(%arg);
  }

# Create a new destination unreachable message
sub new_dest_unreach
  {
    my ($class, %arg) = @_;

    $arg{'Type'} = NF::ICMP->DEST_UNREACH;
    if (defined($arg{'Reason'})) {
      $arg{'Code'} = $arg{'Reason'};
    }
    else {
      $arg{'Code'} = NF::ICMP::DEST_HOST_UNREACH;
    }

    if (defined($arg{'Packet'})) {
      my $req = $arg{'Packet'};

      # Get the data that should be part of the reply
      my $data = $req->packed();
      $data = substr($data, NF::IP_pkt::ETH_HDR_LEN, DEST_UNREACH_DATA_LEN);

      my @data = ( unpack('C*', $data) , ( 0 ) x (DEST_UNREACH_DATA_LEN - length($data)));
      $arg{'SA'} = $req->get('DA');
      $arg{'DA'} = $req->get('SA');
      $arg{'dst_ip'} = $req->get('src_ip');
      $arg{'Identifier'} = 0; # Unused
      if (!defined($arg{'SeqNo'})) {
        if ($arg{'Code'} == NF::ICMP::DGRAM_TO_BIG) {
          $arg{'SeqNo'} = NF::ICMP::NEXT_HOP_DEFAULT_MTU; # Next-Hop MTU
        }
        else {
          $arg{'SeqNo'} = 0;
        }
      }
      $arg{'Data'} = \@data;
    }
    else {
      $arg{'Data'} = map {0} (1..DEST_UNREACH_DATA_LEN) if (!defined($arg{'Data'}));
    }

    return $class->new(%arg);
  }

# Create a new time exceeded message
sub new_time_exceeded
  {
    my ($class, %arg) = @_;

    $arg{'Type'} = NF::ICMP->TIME_EXCEEDED;
    if (defined($arg{'Reason'})) {
      $arg{'Code'} = $arg{'Reason'};
    }
    else {
      $arg{'Code'} = NF::ICMP::TTL_ZERO;
    }
    $arg{'Identifier'} = 0; # Unused
    $arg{'SeqNo'} = 0;

    if (defined($arg{'Packet'})) {
      my $req = $arg{'Packet'};

      # Get the data that should be part of the reply
      my $data = $req->packed();
      $data = substr($data, NF::IP_pkt::ETH_HDR_LEN, DEST_UNREACH_DATA_LEN);

      my @data = ( unpack('C*', $data) , ( 0 ) x (DEST_UNREACH_DATA_LEN - length($data)));
      $arg{'SA'} = $req->get('DA');
      $arg{'DA'} = $req->get('SA');
      $arg{'dst_ip'} = $req->get('src_ip');
      $arg{'Data'} = \@data;
    }
    else {
      $arg{'Data'} = map {0} (1..DEST_UNREACH_DATA_LEN) if (!defined($arg{'Data'}));
    }

    return $class->new(%arg);
  }

# Change both headers
sub set {
  my ($self, %arg) = @_;

  # Update the various ICMP fields if appropriate
  ${$self->{ICMP_pdu}}->Type($arg{'Type'}) if (defined $arg{'Type'});
  ${$self->{ICMP_pdu}}->Code($arg{'Code'}) if (defined $arg{'Code'});
  ${$self->{ICMP_pdu}}->Identifier($arg{'Identifier'}) if (defined $arg{'Identifier'});
  ${$self->{ICMP_pdu}}->SeqNo($arg{'SeqNo'}) if (defined $arg{'SeqNo'});
  ${$self->{ICMP_pdu}}->Data($arg{'Data'}) if (defined $arg{'Data'});
  ${$self->{ICMP_pdu}}->Checksum($arg{'ICMP_Checksum'}) if (defined($arg{'ICMP_Checksum'}));

  # Change the DA or SA (but not the Ethertype since this is IP)
  ${$self->{Ethernet_hdr}}->DA($arg{'DA'}) if (defined $arg{'DA'});
  ${$self->{Ethernet_hdr}}->SA($arg{'SA'}) if (defined $arg{'SA'});

  # Update the length if the data has changed
  if (defined $arg{'Data'}) {
    # Calculate the length of the packet
    $arg{'len'} = NF::IP_pkt::MIN_LEN() + ${$self->{ICMP_pdu}}->length_in_bytes();
    $arg{'dgram_len'} = $arg{'len'} - NF::IP_pkt::ETH_HDR_LEN;
  }

  # Change allowable IP header options
  ${$self->{IP_hdr}}->tos($arg{'tos'}) if (defined $arg{'tos'});
  ${$self->{IP_hdr}}->dgram_len($arg{'dgram_len'}) if (defined $arg{'dgram_len'});
  ${$self->{IP_hdr}}->dgram_id($arg{'dgram_id'}) if (defined $arg{'dgram_id'});
  ${$self->{IP_hdr}}->frag($arg{'frag'}) if (defined $arg{'frag'});
  ${$self->{IP_hdr}}->ttl($arg{'ttl'}) if (defined $arg{'ttl'});
  ${$self->{IP_hdr}}->src_ip($arg{'src_ip'}) if (defined $arg{'src_ip'});
  ${$self->{IP_hdr}}->dst_ip($arg{'dst_ip'}) if (defined $arg{'dst_ip'});
  ${$self->{IP_hdr}}->checksum($arg{'checksum'}) if (defined $arg{'checksum'});
}

# Get values from the various headers
sub get {
  my ($self, $field) = @_;

  # ICMP header fields
  return ${$self->{ICMP_pdu}}->Type if ($field eq'Type');
  return ${$self->{ICMP_pdu}}->Code if ($field eq'Code');
  return ${$self->{ICMP_pdu}}->Identifier if ($field eq'Identifier');
  return ${$self->{ICMP_pdu}}->SeqNo if ($field eq'SeqNo');
  return ${$self->{ICMP_pdu}}->Data if ($field eq'Data');
  return ${$self->{ICMP_pdu}}->Checksum if ($field eq 'ICMP_Checksum');

  # If we get to here then we must be dealing with an IP packet field (hopefully)
  return $self->NF::IP_pkt::get($field);
}

# Decrement the TTL
sub decrement_ttl {
  my ($self, %arg) = @_;

  ${$self->{IP_hdr}}->ttl(${$self->{IP_hdr}}->ttl - 1);
}

####################################################################################
# UDP packet
####################################################################################

package NF::UDP_pkt;

use Carp;
use strict;
use vars qw(@ISA);
@ISA = qw(NF::IP_pkt);

use constant PROTO_UDP => 17;
use constant DEFAULT_DATA_LEN => 20;
use constant UDP_HDR_LEN => 8;


sub new   # Ethernet_hdr
  {
    my ($class, %arg) = @_;

    my $force = defined($arg{'force'}) && $arg{'force'};

    # Set various arguments
    $arg{'proto'} = PROTO_UDP if (!$force || !defined($arg{'proto'}));

    # Create either payload or the udp_len if the other is defined
    if (!defined($arg{'udp_len'}) && !defined($arg{'data'}) && defined($arg{'len'})) {
      $arg{'udp_len'} = $arg{'len'} - NF::IP_pkt::MIN_LEN();
    }

    if (defined($arg{'udp_len'}) && $arg{'udp_len'} < UDP_HDR_LEN) {
      $arg{'udp_len'} = UDP_HDR_LEN;
    }
    if (defined($arg{'udp_len'}) && !defined($arg{'data'}) &&
        $arg{'udp_len'} > UDP_HDR_LEN) {
      $arg{'data'} = [ map {int(rand(256))} (1..($arg{'udp_len'} - UDP_HDR_LEN)) ];
    }

    # Create the UDP PDU
    my $UDP_pdu = new NF::UDP(%arg);

    # Update the UDP length if necessary
    if (!defined($arg{'udp_len'})) {
      $UDP_pdu->Length($UDP_pdu->length_in_bytes());
    }

    # Calculate the length of the packet
    $arg{'len'} = NF::IP_pkt::MIN_LEN() + $UDP_pdu->length_in_bytes() if
        (!$force || !defined($arg{'len'}));

    $arg{'frag'} = 0x4000 if (!$force && !defined($arg{'frag'}));
    $arg{'ttl'} = 64 if (!$force || !defined($arg{'ttl'}));

    # Create the packet
    my $Pkt = $class->NF::IP_pkt::new(%arg);

    # Create the parts list that says what PDUs are inside the packet
    my @parts = ('Ethernet_hdr', 'IP_hdr', 'UDP_pdu');

    # Replace the parts array and stuff the new PDU
    $Pkt->{'UDP_pdu'} = \$UDP_pdu;
    $Pkt->{'Parts'} = \@parts;
    delete($Pkt->{'payload'});

    # Update the IP_hdr in the UDP PDU
    $UDP_pdu->IP_hdr($Pkt->{'IP_hdr'});
    $UDP_pdu->Checksum($arg{'udp_checksum'}) if (defined($arg{'udp_checksum'}));

    return $Pkt;
  }

# Change both headers
sub set {
  my ($self, %arg) = @_;

  # Update the various UDP fields if appropriate
  ${$self->{UDP_pdu}}->SrcPort($arg{'src_port'}) if (defined $arg{'src_port'});
  ${$self->{UDP_pdu}}->DstPort($arg{'dst_port'}) if (defined $arg{'dst_port'});
  ${$self->{UDP_pdu}}->Length($arg{'udp_len'}) if (defined $arg{'udp_len'});
  ${$self->{UDP_pdu}}->Data($arg{'data'}) if (defined $arg{'data'});
  # Update the UDP length if necessary
  if (!defined($arg{'udp_len'}) && defined($arg{'data'})) {
    ${$self->{UDP_pdu}}->Length(${$self->{UDP_pdu}}->length_in_bytes());
  }
  ${$self->{UDP_pdu}}->IP_hdr($arg{'ip_hdr'}) if (defined $arg{'ip_hdr'});
  ${$self->{UDP_pdu}}->Checksum($arg{'udp_checksum'}) if (defined($arg{'udp_checksum'}));

  # Change the DA or SA (but not the Ethertype since this is IP)
  ${$self->{Ethernet_hdr}}->DA($arg{'DA'}) if (defined $arg{'DA'});
  ${$self->{Ethernet_hdr}}->SA($arg{'SA'}) if (defined $arg{'SA'});

  # Update the length if the data has changed
  if (defined $arg{'data'}) {
    # Calculate the length of the packet
    $arg{'len'} = NF::IP_pkt::MIN_LEN() + ${$self->{UDP_pdu}}->length_in_bytes();
    $arg{'dgram_len'} = $arg{'len'} - NF::IP_pkt::ETH_HDR_LEN;
  }

  # Change allowable IP header options
  ${$self->{IP_hdr}}->tos($arg{'tos'}) if (defined $arg{'tos'});
  ${$self->{IP_hdr}}->dgram_len($arg{'dgram_len'}) if (defined $arg{'dgram_len'});
  ${$self->{IP_hdr}}->dgram_id($arg{'dgram_id'}) if (defined $arg{'dgram_id'});
  ${$self->{IP_hdr}}->frag($arg{'frag'}) if (defined $arg{'frag'});
  ${$self->{IP_hdr}}->ttl($arg{'ttl'}) if (defined $arg{'ttl'});
  ${$self->{IP_hdr}}->src_ip($arg{'src_ip'}) if (defined $arg{'src_ip'});
  ${$self->{IP_hdr}}->dst_ip($arg{'dst_ip'}) if (defined $arg{'dst_ip'});
  ${$self->{IP_hdr}}->checksum($arg{'checksum'}) if (defined $arg{'checksum'});
}

# Get values from the various headers
sub get {
  my ($self, $field) = @_;

  # UDP header fields
  return ${$self->{UDP_pdu}}->SrcPort if ($field eq'src_port');
  return ${$self->{UDP_pdu}}->DstPort if ($field eq'dst_port');
  return ${$self->{UDP_pdu}}->Length if ($field eq'udp_len');
  return ${$self->{UDP_pdu}}->Data if ($field eq'data');
  return ${$self->{UDP_pdu}}->IP_hdr if ($field eq'ip_hdr');
  return ${$self->{UDP_pdu}}->Checksum if ($field eq 'udp_checksum');

  # If we get to here then we must be dealing with an IP packet field (hopefully)
  return $self->NF::IP_pkt::get($field);
}

# Decrement the TTL
sub decrement_ttl {
  my ($self, %arg) = @_;

  ${$self->{IP_hdr}}->ttl(${$self->{IP_hdr}}->ttl - 1);
}

1;

__END__



-
