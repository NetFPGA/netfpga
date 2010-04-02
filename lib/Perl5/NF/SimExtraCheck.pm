#############################################################
# $Id: SimExtraCheck.pm 6035 2010-04-01 00:29:24Z grg $
#
#
# Simulation library for "extra checks" -- ie. checks beyond
# simply looking for the word "error" in the output.
#
#
# Invoke using: use NF::SimExtraCheck
#
# Revisions:
#
##############################################################

package NF::SimExtraCheck;

use strict;
use Getopt::Long;
use Carp;

use vars qw(@ISA @EXPORT);  # needed cos strict is on

@ISA = ('Exporter');
@EXPORT = qw(
             $log
            );

# Name of the log file
our $log = '';


###############################################################
# Name: INIT
#
# INIT block that process command line arguments
#
###############################################################
INIT {
	my $cmd = $0;
	$cmd =~ s/.*\///;

	# Parse the command line arguments
	unless ( GetOptions (
			      "log=s" => \$log,
			     )
	       ) { exit 1; }

	# Verify we have a log file
	if ($log eq '') {
		confess "Must provide a log file name to $cmd with '--log <logfile>'";
	}
}

# Always end library in 1
1;

