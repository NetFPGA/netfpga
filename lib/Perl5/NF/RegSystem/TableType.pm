#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: TableType.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# TableType
####################################################################################
package NF::RegSystem::TableType;

use NF::RegSystem::Type;

use vars qw(@ISA);
@ISA = qw(NF::RegSystem::Type);

use Carp;
use strict;
our $AUTOLOAD;

my %fields = (
  depth       => undef,
  entryType   => undef,
  entryWidth  => undef,
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
# Get the total width of the object
#
# This should be the entry width + 2 words
# (1 register for rd addr, 1 reg for wr addr)
#
sub width {
  my $self = shift;

  my $width = 0;
  if (defined($self->{entryWidth})) {
    $width = $self->{entryWidth};
  }
  elsif (defined($self->{entryType})) {
    if (ref($self->{entryType}) ne '') {
      $width = $self->{entryType}->width();
    }
  }

  my $wordSize = NF::RegSystem::Type->wordSize();
  if ($width % $wordSize != 0) {
    $width += $wordSize - $width % $wordSize;
  }

  return $width + 2 * $wordSize;
}

#
# Get/set the type of the object
# (Clear the width if setting the type)
#
sub entryWidth {
  my $self = shift;
  if (@_) {
    $self->{entryWidth} = shift;
    $self->{entryType} = undef;
  }
  return $self->{entryWidth};
}

#
# Get/set the type of the object
# (Clear the width if setting the type)
#
sub entryType {
  my $self = shift;
  if (@_) {
    $self->{entryType} = shift;
    $self->{entryWidth} = undef;
  }
  return $self->{entryType};
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

  my $entryName = $name . "_entry";
  my @names;

  # Work out whether we have a type or a simple width. If we have a type,
  # delegate to the type.
  if (!defined($self->{entryType})) {
    my $width = $self->widthInWords() - 2;

    if ($width <= 1) {
      push @names, $entryName;
    }
    elsif ($width == 2) {
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

  push @names, ($name . "_rd_addr", $name . "_wr_addr");

  return @names;
}
1;

__END__
