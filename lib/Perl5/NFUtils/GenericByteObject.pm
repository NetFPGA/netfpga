#####################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: GenericByteObject.pm 6036 2010-04-01 00:30:59Z grg $
# author: Jad Naous jnaous@stanford.edu
# This library provides a generic data object that can be
# used to provide ways to transform from
# fields to byte arrays, words, packed
# arrays, ...
#
# Fields are stored in network byte-order or big endian. That is,
# the most significant byte will be stored in byte 0.
# This makes manipulating the byte array much simpler.
#####################################

package ByteArrayUtils;

use strict;
use POSIX;
use Carp;

sub log2 {
  my $n = shift;
  return log($n)/log(2);
}

sub mask {
  return (floor(2**shift)-1);
}

# adds a delimiter to a string every n bytes starting
# from the right to the left.
sub add_delimiter {
  my $string = shift;      # String to add delimiters to
  my $num_chars = shift;   # group size
  my $delimiter = shift;   # delimiter to use

  $string = reverse $string;
  $string =~ s/(.{$num_chars})/$1${delimiter}/g;
  # take out the last delimiter if one was added at the end
  $string =~ s/$delimiter$//g;
  $string = reverse $string;

  return $string;
}

# Converts a numerical value to an array of bytes
# with specified width in bytes.
sub int_to_bytes {
  my $width = shift;   # number of bytes to use
  my $value = shift;   # value to convert

  if($value > 0 && ByteArrayUtils::log2($value) > $width*8) {
    confess "Error: $value is too large. It has to fit in $width bytes\n";
  }

  my $width_in_nibbles = $width*2;
#  my @hex = reverse(split / /,add_delimiter(sprintf("%0${width_in_nibbles}x", $value), 2, ' '));
  my @hex = split / /,add_delimiter(sprintf("%0${width_in_nibbles}x", $value), 2, ' ');
  return map (hex, @hex);
}

# Converts a list of bytes to a numerical value
sub bytes_to_int {
  my $width = shift;          # number of bytes to use
  my @byte_list = @_;     # list of bytes to convert

  confess "Error: Too many elements in the list of bytes to convert to int. Should be $width, found @byte_list.\n" unless ((scalar @byte_list) == $width);

#  my @hex = reverse (map (sprintf("%02x", $_), @byte_list));
  my @hex = map (sprintf("%02x", $_), @byte_list);
  return hex(join '',@hex);
}

# Converts a numerical value to an array of bytes
# with specified width in bytes. Converts int to Big Endian
sub int_to_bytes_net {
  my $width = shift;   # number of bytes to use
  my $value = shift;   # value to convert

  if($value > 0 && ByteArrayUtils::log2($value) > $width*8) {
    confess "Error: $value is too large. It has to fit in $width bytes\n";
  }

  my $width_in_nibbles = $width*2;
#  my @hex = reverse(split / /,add_delimiter(sprintf("%0${width_in_nibbles}x", $value), 2, ' '));
  my @hex = split / /,add_delimiter(sprintf("%0${width_in_nibbles}x", $value), 2, ' ');
  return map (hex, @hex);
}

# Converts a list of bytes to a numerical value
# list of bytes is in big endian
sub bytes_to_int_net {
  my $width = shift;          # number of bytes to use
  my @byte_list = @_;     # list of bytes to convert

  confess "Error: Too many elements in the list of bytes to convert to int. Should be $width, found @byte_list.\n" unless ((scalar @byte_list) == $width);

#  my @hex = reverse (map (sprintf("%02x", $_), @byte_list));
  my @hex = map (sprintf("%02x", $_), @byte_list);
  return hex(join '',@hex);
}

# Converts a dotted ip address to a list of bytes
sub ip_to_bytes {
  my $width = shift;         # width of ip address - should be 4 (4 bytes)
  my $ip = shift;            # dotted ip address string

  my ($ip_val, $good) = NF::IP_hdr::getIP($ip);
  confess "Error: bad IP address $ip\n" unless ($good == 1);

  return int_to_bytes($width, $ip_val);
}

# Converts a dotted ip address to a list of bytes
sub bytes_to_ip {
  my $width = shift;         # width of ip address - should be 4.
  my @ip_bytes = @_;      # ip address as list of bytes

#  return join ('.', reverse(@ip_bytes));
  return join ('.', @ip_bytes);
}

# Convert a MAC address hex string to list of bytes
sub mac_to_bytes {
  my $width = shift;          # width of a MAC address - should be 6.
  my $mac = shift;            # MAC address as a string

  confess "MAC address should be specified as xx:xx:xx:xx:xx:xx found $mac.\n" unless ($mac =~ m/^..:..:..:..:..:..$/);
#  return reverse(map (hex, split(":", $mac)));
  return map(hex, split(":", $mac));
}

# Convert a list of bytes to a MAC address hex string
sub bytes_to_mac {
  my $width = shift;         # width of a MAC address - should be 6.
  my @mac_bytes = @_;    # MAC address as list of bytes

#  my @hex = map (sprintf("%02x", $_), reverse(@mac_bytes));
  my @hex = map (sprintf("%02x", $_), @mac_bytes);
  return join (':',@hex);
}

# Convert a MAC address hex string to list of bytes
sub mac_to_bytes_rev {
  my $width = shift;          # width of a MAC address - should be 6.
  my $mac = shift;            # MAC address as a string

  confess "MAC address should be specified as xx:xx:xx:xx:xx:xx found $mac.\n" unless ($mac =~ m/^..:..:..:..:..:..$/);
#  return reverse(map (hex, split(":", $mac)));
  return map(hex, split(":", $mac));
}

# Convert a list of bytes to a MAC address hex string
sub bytes_to_mac_rev {
  my $width = shift;         # width of a MAC address - should be 6.
  my @mac_bytes = @_;    # MAC address as list of bytes

#  my @hex = map (sprintf("%02x", $_), reverse(@mac_bytes));
  my @hex = map (sprintf("%02x", $_), @mac_bytes);
  return join (':',@hex);
}

# Convert a byte list reference to a byte array
sub bytesRef_to_bytes {
  my $width = shift;
  my $ref = shift;
  return @{$ref};
}

# Convert a byte array to a byte array reference
sub bytes_to_bytesRef {
  my $width = shift;
  my @bytes = @_;
  return \@bytes;
}

################################################################################

package NFUtils::GenericByteObject;
use strict;
use POSIX;

# Create an entry that the hardware would match against
# The function accepts a reference to hash as argument which is used
# to set the way the module works.
sub new {
  my ($class, %args) = @_;

  die "Need to define a format for the object.\n" unless defined $args{'format'};

  my $format = $args{'format'};

  my $Entry = {
               'bytes'=>[],
	       'format' => $format
              };

  my $size = 0;
  while (my ($field, $val) = each %{$format}) {
    $size += $val->{'width'};
  }

  foreach my $i (1..$size){
    push @{$Entry->{'bytes'}}, 0;
  }

  # add any additional arguments to set the fields
  if(defined $args{'fields'}) {
    while (my ($field, $val) = each %{$args{'fields'}}) {
      set($Entry, $field, $val);
    }
  }

  bless $Entry, $class;
}

# returns a field
sub get {
  my ($self, $field) = @_;

  die "Error: Field $field is unknown.\n" unless (defined $self->{'format'}->{$field});

  my $fields = $self->{'format'};
  my $pos = $fields->{$field}->{'pos'};
  my $width = $fields->{$field}->{'width'};
  my $from_bytes = $fields->{$field}->{'from_bytes'};

  my @bytes = $self->bytes();
  @bytes = @bytes[$pos..($width+$pos-1)];

  return $from_bytes->($width, @bytes);
}

# sets a field
sub set {
  my ($self, $field, $val) = @_;

  die "GenericByteObject: need to call set method with (field, val) as parameters.\n"
    unless defined $self && defined $field && defined $val;

  my $fields = $self->{'format'};

#  print "GenericByteObject: Setting $field to $val.\n";

  # Check if this field exists
#  die "Error: Field $field is unknown.\n" unless (defined $fields->{$field});
  return unless (defined $fields->{$field});

  my $pos = $fields->{$field}->{'pos'};
  my $width = $fields->{$field}->{'width'};
  my $to_bytes = $fields->{$field}->{'to_bytes'};

  my @bytes = $to_bytes->($width, $val);

#  print "GenericByteObject: setting $field at $pos with width $width to $val in bytes:";
#  map (printf("%02x ", $_), @bytes);
#  print "\n";
  for my $i ($pos..$width+$pos-1) {
    $self->{'bytes'}->[$i] = $bytes[$i-$pos];
  }
}

# Gets the entry as a list of words in big endian format
sub bigEndianWords {
  my $self = shift;

  # get all bytes in hex. Reverse so that we chop words starting with
  # the most significant word first
  my @hex = reverse(map (sprintf ("%02x",$_), $self->bytes()));

  # divide string into groups of 8 nibbles = 1 word and change into int
  my @hexWords = split / /,ByteArrayUtils::add_delimiter(join("", @hex), 8, ' ');

  # reverse again so that the most significant word is in position 0
  return reverse map (hex, @hexWords);
}

# Gets the entry as a list of words in little endian format
# Use this to write to NetFPGA
sub littleEndianWords {
  my $self = shift;

  # get all bytes in hex
  my @hex = map (sprintf ("%02x",$_), $self->bytes());

  # divide string into groups of 8 nibbles = 1 word and change into int
  my @hexWords = split / /,ByteArrayUtils::add_delimiter(join("", @hex), 8, ' ');

  # reverse so that the least significant word is in position 0
  return reverse map (hex, @hexWords);
}

# returns the object as a list of bytes
sub bytes {
  my $self = shift;
  return @{$self->{'bytes'}};
}

# Return the raw bytes as a single string of hex bytes with trailing space,
# suitable for use as parameter to nf_packet_in() or nf_expected_packet()
sub hexBytes {
  my $self = shift;

  my @bytes =  $self->bytes();
  if (scalar(@bytes) > 0) {
    my @tmp = map (sprintf ("%02x",$_), @bytes);
    return join(' ',@tmp).' ';
  }
  else {
    return "";
  }
}

# get a packed representation of the object suitable for pcap and raw sockets
sub packed {
  my ($self) = @_;
  return pack 'C*', @{$self->{'bytes'}};
}

# turn each byte to hex and return as one big word
sub hexString {
  my $self = shift;
#  return join "", map (sprintf("%02x", $_), reverse @{$self->{'bytes'}});
  return join "", map (sprintf("%02x", $_), @{$self->{'bytes'}});
}

# returns length in bytes
sub size {
  my $self = shift;
  return scalar $self->bytes();
}

# adds all the format items from the parameter
# to this object and basically concatenates
# the byte arrays
sub append {
  my $self = shift;
  my $other = shift; # the other object whose bytes we should add

  my $old_size = $self->size();
  push @{$self->{bytes}}, @{$other->{bytes}};
  foreach my $field (keys %{$other->{format}}) {
    $self->{format}->{$field} = $other->{format}->{$field};
    $self->{format}->{$field}->{pos} += $old_size;
  }
}

# returns true if the field exists in the format
sub contains {
  my ($self, $field) = @_;
  return 1 if defined ($self->{format}->{$field});
  return 0;
}

1;
