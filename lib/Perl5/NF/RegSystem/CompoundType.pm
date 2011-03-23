#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: CompoundType.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# CompoundType
####################################################################################
package NF::RegSystem::CompoundType;

use NF::RegSystem::Type;

use vars qw(@ISA);
@ISA = qw(NF::RegSystem::Type);

use Carp;
use strict;
use POSIX;
our $AUTOLOAD;

my %fields = (
  fields    => undef,
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
# Get the total width
#
# Note: Rounds all fields up with whole word widths
#
sub width {
  my $self = shift;

  my $width = 0;
  for my $field (@{$self->{fields}}) {
    my $fieldWidth = $field->width();
    $fieldWidth /= NF::RegSystem::Type->wordSize();
    $fieldWidth = ceil($fieldWidth);
    $fieldWidth *= NF::RegSystem::Type->wordSize();

    $width += $fieldWidth;
  }
  return $width;
}

#
# Get the number of fields
#
sub numFields {
  my $self = shift;

  my $fields = $self->{fields};
  if (!defined($fields)) {
    return 0;
  }
  return scalar(@$fields);
}

#
# getRegNames
#   Get an array of register names for this type
#   OVERRIDES the method in the base class
#
# Params:
#   name  -- name to use when giving register names
#
#   In this case, we need to return the entry, rd and wr address registers.
#
sub getRegNames {
  my ($self, $name) = @_;

  my $fields = $self->{fields};

  my @names;

  # Work out whether we have a type or a simple width. If we have a type,
  # delegate to the type.
  for my $field (@$fields) {
    my $entryName = $name . "_" . $field->{name};

    if (!defined($self->{entryType})) {
      my $width = $field->width();
      $width /= NF::RegSystem::Type->wordSize();

      if ($width <= 1) {
        push @names, $entryName;
      }
        elsif ($width <= 2) {
        push @names, ($entryName . "_hi", $entryName . "_lo");
      }
      else {
        my $i = 0;
        push @names, map { $entryName . "_" . $i++ } ((1) x $width);
      }
    }
    else {
      push @names, $self->{entryType}->getRegNames($entryName);
    }
  }

  return @names;
}

1;

__END__
