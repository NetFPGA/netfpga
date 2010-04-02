#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: RegisterGroup.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# RegisterGroup
####################################################################################
package NF::RegSystem::RegisterGroup;

use Carp;
use strict;
use POSIX;
use NF::RegSystem::Type;
use NF::Utils;
our $AUTOLOAD;

my %fields = (
  name      => undef,
  instances => undef,
  instSize => undef,
  registers => undef,
  offset    => undef,
);

#
# Create a new register group
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
# addRegister
#   Add a register object to the list of registers
#
sub addRegister {
  my ($self, $reg) = @_;

  push @{$self->{registers}}, $reg;
}

#
# updateRegAddrs
#   Update the register addresses
#
sub updateRegAddrs {
  my $self = shift;

  my $nextAddr = 0;
  for my $reg (@{$self->{registers}}) {
    if (!defined($reg->addr())) {
      $reg->addr($nextAddr);
      $nextAddr += $reg->widthInWords() * 4;
    }
    else {
      my $addr = $reg->addr();
      my $modName = $self->name();
      my $regName = $reg->name();
      if ($addr < $nextAddr) {
        croak "Error: Address '$addr' specified in '$modName:$regName' overlaps with allocated addresses";
      }

      $nextAddr = $addr + $reg->widthInWords() * 4
    }
  }
}

#
# getRegNames
#   Get a list of all registers
#
sub getRegNames {
  my $self = shift;

  my @regs = $self->getSingleInstanceRegNames();

  my @ret;
  my $name = $self->name();
  for (my $i = 0; $i < $self->instances(); $i++) {
    push @ret, (map { "${name}_${i}_" . $_ } @regs);
  }
  return @ret;
}

#
# getSingleInstanceRegNames
#   Get a list of all registers
#
sub getSingleInstanceRegNames {
  my $self = shift;

  my @regs;
  for my $reg (@{$self->{registers}}) {
    push @regs, $reg->getRegNames();
  }

  return @regs;
}

#
# getSingleInstanceWidthInWords
#   Get a list of all registers
#
sub getSingleInstanceWidthInWords {
  my $self = shift;

  my $width = 0;
  for my $reg (@{$self->{registers}}) {
    $width += $reg->widthInWords();
  }
  return $width;
}
#
# instSize
#   Get the group size. Enforce power of 2 boundaries.
#
sub instSize {
  my $self = shift;
  if (@_) {
    $self->{instSize} = shift;
  }

  my $instSize = $self->{instSize};
  if (!defined($instSize)) {
    my $widthInWords = $self->getSingleInstanceWidthInWords();
    if ($widthInWords > 0) {
      $instSize = 2 ** log2ceil($widthInWords);
    }
    else {
      $instSize = 0;
    }
  }
  return $instSize;
}

#
# getSingleInstanceRegDump
#   Get an array of register names, addresses, and register objects for a
#   single instance
#
# Returns:
#   Reference to array of the following format:
#     [ {name => str, addr => int} ]
#
sub getSingleInstanceRegDump {
  my $self = shift;

  my $regs = [];
  for my $reg (@{$self->{registers}}) {
    my $regDump = $reg->getRegDump();

    for my $reg (@$regDump) {
      my $name = $reg->{name};
      my $addr = $reg->{addr};

      push @$regs, {name => $name, addr => $addr};
    }
  }

  return $regs;
}

#
# getRegDump
#   Get an array of register names, addresses, and register objects
#
# Returns:
#   Reference to array of the following format:
#     [ {name => str, addr => int} ]
#
sub getRegDump {
  my $self = shift;

  my $regs = $self->getSingleInstanceRegDump();

  my $ret = [];
  my $name = $self->name();
  my $instSize = $self->instSize();
  my $offset = $self->offset();
  for (my $i = 0; $i < $self->{instances}; $i++) {
    my $base = $i * $instSize + $offset;
    for my $reg (@$regs) {
      my $regName = $reg->{name};
      my $regAddr = $reg->{addr};
      push @$ret, {name => "${name}_${i}_" . $regName, addr => $base + $regAddr};
    }
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
