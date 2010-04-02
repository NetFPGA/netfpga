#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: MemAlloc.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# Memory allocation block
#
# Represents a block of memory allocated to a module
####################################################################################
package NF::RegSystem::MemAlloc;

use Carp;
use strict;
our $AUTOLOAD;

my %fields = (
  name      => undef,
  module    => undef,
  start     => undef,
  len       => undef,
  tag       => undef,
);

#
# Create a new memory allocation block
#
# Params:
#   args  -- list of fields to set
#
sub new {
  my ($class, %args) = @_;

  my $self = {
    _permitted  => \%fields,
    %fields,
  };
  for my $arg (keys(%args)) {
    if (exists($fields{$arg})) {
      $self->{$arg} = $args{$arg};
    }
    else {
      croak "ERROR: unregocnized field '$arg'";
    }
  }

  bless $self, $class;

  return $self;
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
