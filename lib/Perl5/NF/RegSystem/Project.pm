#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: Project.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# Project summary
####################################################################################
package NF::RegSystem::Project;

use Carp;
use Switch;
use NF::Utils;
use strict;
our $AUTOLOAD;

my %fields = (
  dir         => undef,
  name        => undef,
  desc        => undef,
  verMajor    => undef,
  verMinor    => undef,
  verRevision => undef,
  devId => undef,
);

#
# Create a new project
#
# Params:
#
sub new {
  my ($class, $dir, $name, $desc, $major, $minor, $revision, $devId) = @_;

  my $self = {
    _permitted  => \%fields,
    %fields,
  };
  $self->{dir}         = $dir;
  $self->{name}        = $name;
  $self->{desc}        = $desc;
  $self->{verMajor}    = $major;
  $self->{verMinor}    = $minor;
  $self->{verRevision} = $revision;
  $self->{devId}       = $devId;

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

