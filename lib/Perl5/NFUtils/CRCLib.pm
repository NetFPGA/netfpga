#####################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: CRCLib.pm 4513 2008-10-02 18:24:35Z jnaous $
# author: Jad Naous jnaous@stanford.edu
# This provides functions for creating CRCs
#
#####################################


package CRC32Lib;
use strict;

use constant ETH_CRC_POLY => 0x04C11DB7;
use constant OTHER_CRC_POLY => 0x1EDC6F41;

# Creates a new crc object that can be used
# to calculate CRCs.
# Takes as input fields:
#   polynomial => integer representing polynomial.
sub new {
  my ($class, %arg) = @_;

  $arg{polynomial} = ETH_CRC_POLY unless (defined $arg{polynomial});

  my $self = {};

  bless $self, $class;

  $self->init_table($arg{polynomial});
  return $self;
}

# initializes the crc table for calculations
sub init_table {
  my $self = shift;
  my $polynomial = shift;

  die "init_table in package CRC32Lib requires one argument: polynomial.\n" unless defined $polynomial;

  my $i;
  $self->{polynomial} = $polynomial;
  my $table = [(0) x 256];

  for ($i = 0; $i < 256; $i++) {
    my $reg = $i << 24;
    my $j;
    for ($j = 0; $j < 8; $j++) {
      my $topBit = (($reg & 0x80000000) != 0);
      $reg <<= 1;
      if ($topBit) {
	$reg ^= $polynomial;
      }
    }
    $table->[$i] = $reg;
  }

  $self->{table} = $table;
}

# calculates the crc of a list of bytes
sub calculate {
  my $self = shift;
  my @data = @_;

  my $result = 0;
  foreach (@data) {
    die "ERROR: Data given to calculate crc for should be between 0 and 255.\n" unless ($_<256 && $_>=0);
    my $top = $result >> 24;
    $top ^= $_;
    $result = ($result << 8) ^ $self->{table}->[$top];
  }
  return $result;
}

1;

