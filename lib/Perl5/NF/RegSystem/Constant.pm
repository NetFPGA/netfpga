#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: Constant.pm 6035 2010-04-01 00:29:24Z grg $
#
# Class for representing a register constant
#
#############################################################

####################################################################################
# Constants
####################################################################################
package NF::RegSystem::Constant;

use Carp;
use strict;
our $AUTOLOAD;

use constant {
  DEFAULT_WIDTH => 32
};

my %fields = (
  name      => undef,
  desc      => undef,
  width     => DEFAULT_WIDTH,
  value     => undef,
  wantHex   => 0,
  file      => undef
);

#
# Create a new register
#
# Params:
#   name
#   value
#
sub new {
  my ($class, $name, $value) = @_;

  my $self = {
    _permitted  => \%fields,
    %fields,
  };
  $self->{name} = $name;
  $self->{value} = $value;

  bless $self, $class;

  return $self;
}

#
# Get the width of the object
#
sub width {
  my $self = shift;
  if (@_) {
    $self->{width} = shift;
    if (!defined($self->{width})) {
      $self->{width} = DEFAULT_WIDTH;
    }
  }
  return $self->{width};
}

#
# Autoload method to access fields
# (see perltoot for more information)
#
sub AUTOLOAD {
  my $self = shift;
  my $type = ref($self)
    or croak "$self is not an object";

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  unless (exists $self->{_permitted}->{$name} ) {
    croak "Can't access `$name' field in class $type";
  }

  if (@_) {
    return $self->{$name} = shift;
  } else {
    return $self->{$name};
  }
}

#
# Destroy method
#
sub DESTROY {}


1;

__END__
