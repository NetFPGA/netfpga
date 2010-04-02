#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: Utils.pm 6035 2010-04-01 00:29:24Z grg $
#
# Register utils
#
#############################################################

package NF::Utils;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw(
                log2
                log2ceil
            );

use Carp;
use Math::BigFloat;
use strict;

#
# log2
#   Log base 2 function
#
sub log2 {
  my $n = shift;

  my $ret;
  eval { $ret = log($n) / log(2); };
  if ($@ ne '') {
    my $err = $@;
    chomp($err);
    $err =~ s/ at [^\s]+ line \d+\.$//;
    croak $err;
  }

  if (ref($ret) eq 'Math::BigFloat') {
    $ret = $ret->as_number();
  }
  return $ret;
}

#
# log2ceil
#   Log base 2 function with ceiling afterwards
#
sub log2ceil {
  my $n = shift;

  if ($n <= 0) {
    croak "Cannot take log2 of a negative or zero value";
  }

  my $ret = 0;
  while (2 ** $ret < $n) {
    $ret++;
  }
  return $ret;
}

#
# verifyAndTrimModules
#   Verify that all necessary modules are defined and trim any that aren't used
#
# Params:
#   modules     -- List of modules by name
#   usedModules -- List of used modules
#
sub verifyAndTrimModules {
  my ($modules, $usedModules) = @_;

  my %used;
  for my $m (@$usedModules) {
    if (!defined($modules->{$m})) {
      croak "Definition for module '$m' not loaded";
    }
    $used{$m} = $m;
  }

  for my $key (keys(%$modules)) {
    if (!defined($used{$key})) {
      delete($modules->{$key});
    }
  }
}

1;

__END__
