#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: SimpleType.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# SimpleType
####################################################################################
package NF::RegSystem::SimpleType;

use NF::RegSystem::Type;

use vars qw(@ISA);
@ISA = qw(NF::RegSystem::Type);

use Carp;
use strict;
our $AUTOLOAD;

my %fields = (
  width     => undef,
  bitmasks  => undef,
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


1;

__END__
