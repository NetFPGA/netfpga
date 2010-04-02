#############################################################
# $Id: Base.pm 6067 2010-04-01 22:36:26Z grg $
#
# Module provides basic functions for use by NetFPGA Perl scripts.
#
# Revisions:
#
##############################################################

package Test::Base;
use Exporter;
@ISA = ('Exporter');
@EXPORT = qw( &check_NF2_vars_set
            );

##############################################################
#
# Define a my_die function if it doesn't already exist
#
##############################################################

if (!defined(&my_die)) {
	eval('
	  sub my_die {
	  my $mess = shift @_;
	  (my $cmd = $0) =~ s/.*\///;
	  print STDERR "\n$cmd: $mess\n";
	  exit 1;
	}
	');
}

# Always end library in 1
1;
