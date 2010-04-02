#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: BitmaskType.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# BitmaskType
####################################################################################
package NF::RegSystem::BitmaskType;

use NF::RegSystem::Type;

use vars qw(@ISA);
@ISA = qw(NF::RegSystem::Type);

use Carp;
use strict;
our $AUTOLOAD;

my %fields = (
  posLo     => undef,
  posHi     => undef,
);
my %permitted = %fields;
my $initialized = 0;

#
# Create a new type
#
# Params:
#   name
#   desc
#
sub new {
  my ($class, $name, $desc) = @_;

  my $self  = $class->SUPER::new($name, $desc);

  # Initialize the class if necessary
  if (!$initialized) {
    my %superPermitted = %{$self->{_permitted}};
    @{\%permitted}{keys %superPermitted} = values %superPermitted;
    $initialized = 1;
  }

  $self->{_permitted} = \%permitted;
  @{$self}{keys %fields} = values %fields;

  bless $self, $class;

  return $self;
}

#
# Get/Set position
#
# Params:
#   pos
#
sub pos {
  my $self = shift;

  if (@_) {
    $self->{posLo} = $self->{posHi} = shift;
  }

  if ($self->{posLo} eq $self->{posHi}) {
    return $self->{posLo};
  } else {
    return -1;
  }
}

#
# Get the width
#
sub width {
  my $self = shift;

  if ($self->{posLo} <= $self->{posHi}) {
    return $self->{posHi} - $self->{posLo} + 1;
  } else {
    return -1;
  }
}

1;

__END__
