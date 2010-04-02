#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: Type.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# Types
####################################################################################
package NF::RegSystem::Type;

use Carp;
use strict;
use Math::BigFloat;
our $AUTOLOAD;

use constant {
  WORD_SIZE   => 32,
};

my %fields = (
  name      => undef,
  desc      => undef,
  file      => undef
);

#
# Create a new type
#
# Params:
#   name
#   desc
#
sub new {
  my ($class, $name, $desc) = @_;

  my $self = {
    _permitted  => \%fields,
    %fields,
  };
  $self->{name} = $name;
  $self->{desc} = $desc;

  bless $self, $class;

  return $self;
}

#
# widthInWords
#   Get the width in words
#
sub widthInWords {
  my $self = shift;

  my $width = Math::BigFloat->new($self->width());
  $width /= NF::RegSystem::Type->wordSize();
  $width = $width->bceil();

  return $width->as_number();
}

#
# getRegNames
#   Get an array of register names for this type
#
# Params:
#   name  -- name to use when giving register names
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
  my ($self, $name) = @_;

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

#
# Class method to get the word size
#
sub wordSize {
  my ($class) = @_;

  return WORD_SIZE;
}


1;

__END__
