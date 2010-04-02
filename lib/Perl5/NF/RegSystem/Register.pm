#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: Register.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# Registers
####################################################################################
package NF::RegSystem::Register;

use Carp;
use strict;
use POSIX;
use NF::RegSystem::Type;
our $AUTOLOAD;

use constant {
  DEFAULT_WIDTH => 32
};

my %fields = (
  name      => undef,
  desc      => undef,
  width     => DEFAULT_WIDTH,
  type      => undef,
  file      => undef,
  addr      => undef,
);

#
# Create a new register
#
# Params:
#   name
#
sub new {
  my ($class, $name) = @_;

  my $self = {
    _permitted  => \%fields,
    %fields,
  };
  $self->{name} = $name;

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
    $self->{type} = undef;
  }
  if (defined($self->{width})) {
    return $self->{width};
  }
  elsif (defined($self->{type})) {
    return $self->{type}->width();
  }
}

#
# Get/set the type of the object
# (Clear the width if setting the type)
#
sub type {
  my $self = shift;
  if (@_) {
    $self->{type} = shift;
    $self->{width} = undef;
  }
  return $self->{type};
}

#
# widthInWords
#   Get the width in words
#
sub widthInWords {
  my $self = shift;

  my $width = $self->width();
  $width /= NF::RegSystem::Type->wordSize();
  $width = ceil($width);

  return $width;
}

#
# getRegNames
#   Get an array of register names for this register
#
#   A "register" object can represent multiple registers if the register is
#   wider than the word width. In this case, the register will be split into
#   multiple registers. For simple types, registers are split as follows:
#
#   Length (words)    Suffixes on registers
#     1                   --- (none)
#     2                   _HI, _LO
#     3 +                 _0, _1, _2, ...
#
sub getRegNames {
  my $self = shift;

  my $name = $self->{name};
  # Work out whether we have a type or a simple width. If we have a type,
  # delegate to the type.
  if (!defined($self->{type})) {
    my $width = $self->widthInWords();

    if ($width <= 1) {
      return ($name);
    }
    elsif ($width == 2) {
      return ($name . "_hi", $name . "_lo");
    }
    else {
      my $i = 0;
      return map { $name . "_" . $i++ } ((1) x $width);
    }
  }
  else {
    return $self->{type}->getRegNames($name);
  }
}

#
# getRegDump
#   Get an array of register names, addresses, and register objects
#
# Returns:
#   Reference to array of the following format:
#     [ {name => str, addr => int} ]
#
# DISREGARD THE FOLLING
# XXX    [ {name => str, addr => int, register => regObj/undef} ]
#
# XXX  This is an array of hashes. Each element in the hash defines a name,
# XXX  address and register object. The register object may be undefined.
#
# XXX  For the register object:
# XXX    - undefined -- this register is part of the previous register
# XXX    - reg obj   -- this register is a new register and not part of
# XXX                   the previous one
#
sub getRegDump {
  my $self = shift;

  my @regNames = $self->getRegNames();

  my $ret = [];
  my $pos = 0;
  if (defined($self->{addr})) {
    $pos = $self->{addr};
  }
  for my $reg (@regNames) {
    push @$ret, {name => $reg, addr => $pos};
    $pos += 4;
  }

  return $ret;
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
