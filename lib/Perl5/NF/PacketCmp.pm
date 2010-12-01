###############################################################
# PacketCmp Library for NetFPGA
#
# $Id: PacketCmp.pm 6035 2010-04-01 00:29:24Z grg $
#
# Invoke using: use NF::PacketCmp
#
# This is the library of functions that users can invoke in order
# to compare packets that have been received (via simulation or
# on the actual hardware) with those that were expected.
#
#
###############################################################

=head1 The NF::PacketCmp library


This library is for use with Perl programs that want to compare
expected packets with packets that were actually received. It is
used in the nf2_compare.pl program, but can be used by other programs.

To include this in your program make sure that your PERL5LIB shell
variable includes the NetFPGA/lib/Perl directory and then add the
following line to your Perl script:

C<< use NF::PacketCmp >>

=cut

package NF::PacketCmp;

#BEGIN {
  # following is a hack so that nf2_compare.pl can run on the csl cluster
  # as well as the solaris machines. For some reason the dynaloader gets
  # the wrong VERSION when bootstrapping Expat (from Parser.pm)

#  if ( -r "/usr/lib/perl5/vendor_perl/5.6.1/i386-linux/XML/Parser.pm" )
#   { use lib "/usr/lib/perl5/vendor_perl/5.6.1/i386-linux" }
#  require XML::Parser;
#}

require XML::Simple;
use strict;
use Exporter;
use vars qw(@ISA @EXPORT);  # needed cos strict is on
# Data::Dumper for debug only
use Data::Dumper;

@ISA = ('Exporter');
@EXPORT = qw( &nf_read_hardware_file
	      &nf_parse_xml_file
	      &compare_2_pkts
	    );

my $pkts ;    # anon array of packets
# array of array of $pkts, ordered by port num
my @hardware_pkts = ([],[],[],[],[],[],[],[]);
my $rules ;  # anon array of rules (that apply to ALL packets)
my $in_packet ;   # set to 1 after we see <PACKET> and 0 after </PACKET>
my $in_rule ;     # set to 1 after we see <RULE> and 0 after </RULE>
my $new_pkt;   # stores new packet info
my $pkt_number;
my $fname;
my $port;
my $char_string;
my $required; # Count of number of packets required

# for hardware files
my %endian_type = ("BIG_ENDIAN"    => '0',
		   "LITTLE_ENDIAN" => '1'
		  );

###############################################################
# Name: nf_read_hardware_file
# Author: Harn Hua Ng, harnhua@stanford.edu
# Subroutine to read hardware egress packet file and extract
# packet information.
# Arguments: filename
#            endian-ness - "BIG_ENDIAN" or "LITTLE ENDIAN"
###############################################################
sub nf_read_hardware_file {

  ## constants
  my $TCPDUMP_MAGIC = 0xa1b2c3d4;
  my $HARDWARE_FILEHDR_LEN = 24;
  my $HARDWARE_PKTHDR_LEN = 16;
  my $MAC_ADDR_LEN = 6;
  my $ETHER_TYPE_LEN = 2;
  my $VLAN_LEN = 4;
  my $CRC_LEN = 4;

  ## arguments
  my $fname = shift;
  my $endian_type = shift;

  ## variables
  my ($format_str, $buff, $pkt_number);
  my ($magic, $version_major, $version_minor, $thiszone, $sigfigs);
  my ($snaplen, $linktype);
  # hardware packet header
  my ($ts_1, $ts_2, $bytes_in_file, $bytes_in_packet);
  # actual ethernet packet
  my ($vlan, $data_len, $data);

  open(F, "$fname") or die "Unable to open $fname\n";

  ## determine endian-ness
  if (defined $endian_type{$endian_type}) {
    if ($endian_type{$endian_type}) { # little endian
      $format_str = "VvvVVVV";
    }
    else { # big endian
      $format_str = "NnnNNNN";
    }
  } else {
    die "Internal error: NETFPGA::PacketGen invalid endian_type $endian_type";
  }

  ## file header
  read(F, $buff, $HARDWARE_FILEHDR_LEN);
  # extract bytes
  ($magic, $version_major, $version_minor, $thiszone, $sigfigs,
   $snaplen, $linktype) = unpack $format_str, $buff;
  #printf "Magic: %x", $magic;
  unless ($magic == $TCPDUMP_MAGIC) {
    die " -BAD: expected %x, saw %x\n", $TCPDUMP_MAGIC, $magic;
  }
  #printf "Version Major:Minor = %d.%d\n", $version_major,$version_minor;
  #printf "Thiszone: $thiszone   sigfigs: $sigfigs  snaplen: $snaplen   linktype: $linktype\n";

  $pkt_number = 0;
  ## read each packet
  # tcpdump/pcap packet header
  # note: timestamp can be a 32- or 64-bit value
  # in our case, it is 64 bits
  while (read(F, $buff, $HARDWARE_PKTHDR_LEN) == $HARDWARE_PKTHDR_LEN) {

    if ($endian_type{$endian_type}) { # little endian
      $format_str = "VVVV";
    }
    else { # big endian
      $format_str = "NNNN";
    }
    ($ts_1, $ts_2, $bytes_in_file, $bytes_in_packet) = unpack $format_str, $buff;
    #printf "Timestamp: %x.%x   bytes in file: %d   packet size %d\n", $ts_1, $ts_2, $bytes_in_file, $bytes_in_packet;

    ## actual packet
    push @{$data}, @{getHexString(\*F, $MAC_ADDR_LEN)}; # DA
    push @{$data}, @{getHexString(\*F, $MAC_ADDR_LEN)}; # SA
    $vlan = getHexString(\*F, $VLAN_LEN); # need this for the port number
    #push @{$data}, @{$vlan}; # vlan tag
    push @{$data}, @{getHexString(\*F, $ETHER_TYPE_LEN)}; # ether type
    # data
    $data_len = $bytes_in_file - 2*$MAC_ADDR_LEN - $VLAN_LEN - $ETHER_TYPE_LEN;

    push @{$data}, @{getHexString(\*F, $data_len)};

    $new_pkt = { 'length' => 0,
		 'port' => 0,
		 'delay' => 0,
		 'rules' => [],
		 'data' => []
	       };
    $new_pkt->{'length'} = $bytes_in_file - $CRC_LEN; #DA+SA+type+data
    $new_pkt->{'port'} = ${$vlan}[3]; # egress port
    $new_pkt->{'delay'} = $ts_2; # clarify with greg
    $new_pkt->{'data'} = $data;


    #printf ("Packet length %d bytes  Port number %d  Delay %x\n", $new_pkt->{'length'}, $new_pkt->{'port'}, $new_pkt->{'delay'});

    # add to packet hash
    push @{$hardware_pkts[$new_pkt->{'port'}]}, $new_pkt;
    $pkt_number++;

    ## reset references
    $vlan = undef;
    $data = undef;
    $new_pkt = undef;

  }

  close(F);
  print "nf_read_hardware_file(): Found $pkt_number hardware packets\n";

  #showHardwarePackets(\@hardware_pkts);

  return \@hardware_pkts;

}

#############################################################
# Name: getHexString
# Author: Harn Hua Ng
# Subroutine to extract pairs of hex chars (w/o 0x) from a
# pcap file and concatenate into a string.
# Returns the string.
# Arguments: file handle
#            number of chars to extract
#############################################################
sub getHexString {

  my $fh = shift; # file handle
  my $length = shift; # number of hex byte strings
  my ($buff, $ch);
  my @result = ();

  for (1..$length) {
    read($fh, $buff, 1);
    $ch = unpack("C", $buff);
    push @result, uc(sprintf("%.2x",$ch));
  }

  return \@result;

}

###############################################################
#
# This is the new version of nf_parse_xml_file using XML::Simple
#
# Parse the specified file which should contain XML specifying
# expected/received packets.
# See NetFPGA/docs/Developer/file_formats.txt for format
#
# Params: port, filename
#
# Returns: Reference to list of packets (see below)
#          Reference to list of Rules that apply to all packets.
#
# Each packet is an anonymous hash:
# pkt {
#      'length' => scalar indicating length in bytes in Data field.
#      'port' => scalar indicating port this packet came out on.
#      'delay' => scalar indicating egress time in ns (may be 0)
#      'rules' => anon array of rules (not sure of format yet)
#      'data' => anon array of pairs of hex chars. No leading 0x.
#     }
#
###############################################################
sub nf_parse_xml_file {

  if ($#_ < 1) { die "nf_parse_xml_file(): Need params: port, filename." }

  $port = shift;
  $fname = shift;

  unless ( -r $fname )        {  die ("nf_parse_xml_file(): cannot open $fname.") }

  $pkts = [];
  $rules = [];
  $required = 0;

  #print "\n--- Processing file $fname\n";

  my $p1 = XML::Simple::XMLin($fname);  # parse it into hash structure

  #print Dumper($p1);

  # Check to make sure we don't have a mixture of packets and dma packets
  if (defined $p1->{'PACKET'} && defined $p1->{'DMA_PACKET'}) {
    die ("nf_parse_xml_file(): $fname contains both PACKET and DMA_PACKET.");
  }

  if (defined $p1->{'PACKET'}) {  # then we got at least one packet
    if (ref $p1->{'PACKET'} eq 'HASH') { # just one packet
      $pkts = [$p1->{'PACKET'}];
    }
    else { # already a list
      $pkts = $p1->{'PACKET'};
    }

    #print Dumper($pkts);

    # Now go through each packet and fix up the names
    for my $pref (@$pkts) {
      if (defined $pref->{'Length'}) { $pref->{'length'} = $pref->{'Length'} }
      if (defined $pref->{'Port'})   { $pref->{'port'}   = $pref->{'Port'} }
      if (defined $pref->{'Delay'})  { $pref->{'delay'}  = $pref->{'Delay'} }
      if (defined $pref->{'Rules'})  { $pref->{'rules'}  = $pref->{'Rules'} }
      if (defined $pref->{'Optional'}) { $pref->{'optional'}  = $pref->{'Optional'} }
      if (!defined $pref->{'optional'} || $pref->{'optional'} == 0) { $required++};
      if (defined $pref->{'content'}) {
	my $data = $pref->{'content'};
	$data =~ s/^\s*//;
	$data =~ s/\s*$//;
	$data =~ tr/\n//;
	$data =~ s/\s+/ /g;
	# print "data is $data\n";
	my @bytes = split(' ',$data);
	$pref->{'data'} = \@bytes;
      }
    }
  }  # PACKET

  if (defined $p1->{'RULE'}) {  # then we got at least one packet
    my $r = $p1->{'RULE'};
    $r =~ s/^\s*//;
    $r =~ s/\s*$//;
    $r =~ tr/\n//;
    $r =~ s/\s+/ /g;
    $rules = [split(' ',$r)];
    #print Dumper($rules);
  }

  if (defined $p1->{'DMA_PACKET'}) {  # then we got at least one packet
    if (ref $p1->{'DMA_PACKET'} eq 'HASH') { # just one packet
      $pkts = [$p1->{'DMA_PACKET'}];
    }
    else { # already a list
      $pkts = $p1->{'DMA_PACKET'};
    }

    #print Dumper($pkts);

    # Now go through each packet and fix up the names
    for my $pref (@$pkts) {
      if (defined $pref->{'Length'}) { $pref->{'length'} = $pref->{'Length'} }
      if (defined $pref->{'Port'})   { $pref->{'port'}   = $pref->{'Port'} }
      if (defined $pref->{'Delay'})  { $pref->{'delay'}  = $pref->{'Delay'} }
      if (defined $pref->{'Rules'})  { $pref->{'rules'}  = $pref->{'Rules'} }
      if (defined $pref->{'Optional'}) { $pref->{'optional'}  = $pref->{'Optional'} }
      if (!defined $pref->{'optional'} || $pref->{'optional'} == 0) { $required++};
      if (defined $pref->{'content'}) {
	my $data = $pref->{'content'};
	$data =~ s/^\s*//;
	$data =~ s/\s*$//;
	$data =~ tr/\n//;
	$data =~ s/\s+/ /g;
	# print "data is $data\n";
	my @bytes = split(' ',$data);
	$pref->{'data'} = \@bytes;
      }
    }
  }  # PACKET


  return ($pkts,$rules,$required);

}


###############################################################
#
# This is the original version, using XML::Parser and expat.
#
# Dropped it because it is a pain keeping expat and XML::Parser::expat
# in sync.
#
# Parse the specified file which should contain XML specifying
# expected/received packets.
# See NetFPGA/docs/Developer/file_formats.txt for format
#
# Params: port, filename
#
# Returns: Reference to list of packets (see below)
#          Reference to list of Rules that apply to all packets.
#
# Each packet is an anonymous hash:
# pkt {
#      'length' => scalar indicating length in bytes in Data field.
#      'port' => scalar indicating port this packet came out on.
#      'delay' => scalar indicating egress time in ns (may be 0)
#      'rules' => anon array of rules (not sure of format yet)
#      'data' => anon array of pairs of hex chars. No leading 0x.
#     }
#
###############################################################
sub nf1_parse_xml_file {

  if ($#_ < 1) { die "nf_parse_xml_file(): Need params: port, filename." }

  $port = shift;
  $fname = shift;

  unless ( -r $fname )        {  die ("nf_parse_xml_file() :cannot open $fname.") }

  $in_packet = 0;
  $in_rule = 0;
  $pkt_number = 1;
  $pkts = [];
  $rules = [];

  my $p1 = new XML::Parser(Handlers => {
				     Start => \&handle_start,
				     End   => \&handle_end,
				     Final => \&handle_final,
				     Default => \&handle_default,
				     Comment => \&handle_comment,
				     Char  => \&handle_char
				    });
  # We use some vars to track where we are in the file:

  $p1->parsefile($fname);

  return ($pkts,$rules);
}


###############################################################
#
# Following are the subroutines used by the XML parser
#
###############################################################

sub handle_start {  # start tag
  my $e = shift;
  my $tag = shift;
  my @rest = @_;
  my ($attr, $value);

  if ($tag eq 'PACKET') {
    $in_packet = 1;
    $new_pkt = { 'length' => 0,
		 'port' => 0,
		 'delay' => 0,
		 'rules' => [],
		 'data' => []
	       };

    while ($#rest >= 0) {
      $attr = shift @rest;
      if ($#rest < 0) { $value = '' }
      else { $value = shift @rest }
      $new_pkt->{lc($attr)} = $value;
    }
    if ($port != $new_pkt->{'port'}) {
      print "WARNING: file $fname packet # $pkt_number : Expected port attribute\n".
	" to be $port but saw ".$new_pkt->{'port'}.".\n";
    }
  }
  elsif ($tag eq 'RULE') {
    $in_rule = 1;
  }
  else {}

  $char_string = '';
}

sub handle_end {  # closing tag. Previous char data is in $char_string
  my $e = shift;
  my $tag = shift;

  $char_string =~ s/^\s*//;
  $char_string =~ s/\s*$//;
  $char_string =~ s/\s+/ /g;

  if ($tag eq 'PACKET') {
    $in_packet = 0;
    $char_string = uc($char_string);

    push @{$new_pkt->{'data'}}, split ' ',$char_string;

    # check stated length against observed length

    if ($new_pkt->{'length'} != scalar(@{$new_pkt->{'data'}}) ) {
      print "WARNING: file $fname packet # $pkt_number :  Stated packet length attribute was ".$new_pkt->{'length'}.
	" but observed data length is ".scalar(@{$new_pkt->{'data'}}).
	  "\nPacket data: <".(join '><',@{$new_pkt->{'data'}}).">\n";
      exit 1;
    }

    push @$pkts, $new_pkt;
    $pkt_number++;
    $new_pkt = undef;
  }
  elsif ($tag eq 'RULE') {
    if ($in_packet) { push @{$new_pkt->{'rules'}},$char_string }
    else {
      # a rule that applies to all packets
      push @{$rules},$char_string;
    }

    $in_rule = 0;
  }
  else {}

  $char_string = '';
}

sub handle_char {
  my $e = shift;
  my $string = shift;
  my @new_data;

  # Accumulate the string until matching end. This is because
  # the XML Parser seems to split chars at weird places.

  chomp $string;
  $char_string .= $string;
}

sub handle_default {
  my $e = shift;
  my $string = shift;
}

sub handle_comment{
  my $e = shift;
  my $string = shift;
}

sub handle_final {
  my $e = shift;
}

###############################################################
#
# Compare two packets to see if they match.
# Return an error string if there is a mismatch.
#
# Params: ref to pkt 1,
#         ref to pkt 2,
#         ref to list of global rules.
#
# Returns: 0 if OK
#          Error string if not OK
#
# Each packet is an anonymous hash:
# pkt {
#      'length' => scalar indicating length in bytes in Data field.
#      'port' => scalar indicating port this packet came out on.
#      'delay' => scalar indicating egress time in ns (may be 0)
#      'rules' => anon array of rules (not sure of format yet)
#      'data' => anon array of pairs of hex chars. No leading 0x.
#     }
#
###############################################################
sub compare_2_pkts {

  if ($#_ < 2) { die "compare_2_pkts: Expected 3 parameters." }

  my $p1 = shift;
  my $p2 = shift;
  my $rules = shift;
  my $byte;
  my $res;
  my $d1 = $p1->{'data'};
  my $d2 = $p2->{'data'};

  if (scalar(@{$d1}) != scalar(@{$d2})) {
    #print (@{$d2});
    return (sprintf "Packet lengths do not match, expecting %d, saw %d\n",
	    scalar(@{$d1}), scalar(@{$d2}));
  }

  for ($byte=0;$byte<scalar(@{$d1}); $byte++) {

    # look for dont-cares and set mask appropriately
    if ($res = compare_bytes ($d1->[$byte], $d2->[$byte])) {
      return "byte $byte (starting from 0) not equivalent (EXP: $d1->[$byte], ACTUAL: $d2->[$byte])"
    }
  }

  return 0
} # compare_2_pkts

################################################################
# Compare two 2-char strings. An X means dont-care
# Params: string 1,
#         string 2
#
# Return: 0 on match
#         1 on failure
################################################################
sub compare_bytes {
  my $s1 = shift;
  my $s2 = shift;

  # first do common case: they match

  return 0 if ($s1 eq $s2);

  # otherwise look for dont-cares.

  if (index ($s1,'X') != 0) {
    if (substr ($s1,0,1) ne substr($s2,0,1)) { return 1 }
  }
  if (index ($s1,'X',1) != 1) {
    if (substr ($s1,1,1) ne substr($s2,1,1)) { return 1 }
  }

  return 0
}


################################################################
# Print Da, Sa, ETh type plus a few more bytes
# Param: ref to array of bytes.
################################################################
sub showDASAtype {
  my $data = shift;  # ref to array of bytes
  my $DA = join ':',@{$data}[0..5];
  my $SA = join ':',@{$data}[6..11];
  return 'Len:'.scalar($data)." DA: $DA SA: $SA [${$data}[12]${$data}[13]] ".join (' ',@{$data}[14..19]).'...';
}


################################################################
# Print all hardware packets that have been read by
# nf_read_hardware_file()
# Argument: reference to array of array of $new_pkt
################################################################
sub showHardwarePackets {
  my $hw_pkts = shift;
  my $data;
  for my $t_port (0..7) {
    for my $t_pkt (@{${$hw_pkts}[$t_port]}) {
      $data = $t_pkt->{'data'};
      printf "Length %d  Port %d  ", $t_pkt->{'length'}, $t_pkt->{'port'};
      print @{$data}[0..19];
      print "...\n";
    }
  }
}

1; # Must be here for library to load properly



