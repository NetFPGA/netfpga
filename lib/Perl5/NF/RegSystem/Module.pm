#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: Module.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# Module
####################################################################################
package NF::RegSystem::Module;

use Carp;
use strict;
our $AUTOLOAD;

use constant {
  DEFAULT_WIDTH => 32
};

use NF::Utils;

my %fields = (
  name        => undef,
  prefix      => undef,
  desc        => undef,
  location    => undef,
  blockSize   => undef,
  prefBase    => undef,
  forceBase   => undef,
  file        => undef,
  registers   => undef,
  tagWidth    => undef,
  addrWidth   => undef,
);

#
# Create a new module
#
# Params:
#   name
#   prefix
#   location
#
sub new {
  my ($class, $name, $prefix, $location) = @_;

  my $self = {
    _permitted  => \%fields,
    %fields,
  };
  $self->{name}       = $name;
  $self->{prefix}     = $prefix;
  $self->{location}   = $location;
  $self->{registers}  = [];

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
    # Call update reg addrs on register groups
    if (ref($reg) eq 'NF::RegSystem::RegisterGroup') {
      $reg->updateRegAddrs();
    }
    else {
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
}

#
# getRegNames
#   Get a list of all registers
#
sub getRegNames {
  my $self = shift;

  my @regs;
  for my $reg (@{$self->{registers}}) {
    push @regs, $reg->getRegNames();
  }

  return @regs;
}

#
# getRegDump
#   Get a dump of all registers with addresses
#
sub getRegDump {
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
# getRegDumpNonGroup
#   Get a dump of all registers with addresses for non-group registers
#
sub getRegDumpNonGroup {
  my $self = shift;

  my $regs = [];
  for my $reg (@{$self->{registers}}) {
    next if (ref($reg) eq 'NF::RegSystem::RegisterGroup');

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
# getRegGrpMaxSize
#   Get the maximum size for a register group
#   This is calculated based on the number of non-regsiter-group registers in
#   the module. It is assumed that the register group will be aligned on a
#   power of 2 boundary.
#
sub getRegGrpMaxSize {
  my $self = shift;


  # Work out the number of registers
  my @regs = $self->getRegNames();
  my $numRegs = scalar(@regs);

  my $blockSize = $self->{blockSize};
  if ($blockSize == 1 || $blockSize == $numRegs) {
    return 0;
  }
  elsif ($numRegs == 0) {
    return $blockSize;
  }

  # Calculate the maximum register group size
  my $bits = log2ceil($blockSize);
  my $maxRegGrpSize = 2 ** ($bits - 1);
  my $regSize = $maxRegGrpSize;
  while ($regSize < $blockSize - 1 && $regSize < ($numRegs * 4)) {
    $regSize = $maxRegGrpSize + ($regSize >> 1);
  }
  return $blockSize - $regSize;
}

#
# hasRegisterGroup
#   Check if this module has a register group
#
sub hasRegisterGroup {
  my $self = shift;

  for my $reg (@{$self->{registers}}) {
    if (ref($reg) eq 'NF::RegSystem::RegisterGroup') {
      return 1;
    }
  }

  return 0;
}

#
# getRegGroup
#   Get the register group
#
sub getRegGroup {
  my $self = shift;

  for my $reg (@{$self->{registers}}) {
    if (ref($reg) eq 'NF::RegSystem::RegisterGroup') {
      return $reg;
    }
  }

  # If we make it here we've got a problem
  croak "ERROR: getRegisterGroup called on '" . $self->name() . "' which doesn't contain a valid register group";
}

#
# checkRegistersFit
#   Check if the registers fit within the block size
#
sub checkRegistersFit {
  my $self = shift;

  # Get the registers
  my $regDump = $self->getRegDump();
  my $max = 0;
  for my $reg (@$regDump) {
    my $addr = $reg->{addr};
    if ($addr > $max) {
      $max = $addr + 4;
    }
  }

  return $max <= $self->blockSize();
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
