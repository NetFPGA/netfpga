#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: Field.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# Fields
####################################################################################
package NF::RegSystem::Field;

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
  type      => undef,
  file      => undef
);

#
# Create a new register
#
# Params:
#   name
#   desc
#
sub new {
  my ($class, $name, $value) = @_;

  my $self = {
    _permitted  => \%fields,
    %fields,
  };
  $self->{name} = $name;
  $self->{desc} = $value;

  bless $self, $class;

  return $self;
}

#
# Get/set the width of the object
# (Clear the type if setting the width)
#
sub width {
  my $self = shift;
  if (@_) {
    $self->{width} = shift;
    $self->{type} = undef;
    if (!defined($self->{width})) {
      $self->{width} = DEFAULT_WIDTH;
    }
  }
  if (defined($self->{width})) {
    return $self->{width};
  }
  elsif (defined($self->{type})) {
    if (ref($self->{type}) ne '') {
      return $self->{type}->width();
    }
  }
  return $self->{width};
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
