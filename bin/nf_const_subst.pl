#!/usr/bin/perl -W

#####################################################################
#
# Substitute `constants in Verilog code for the constants defined in
# the `define. This is currently necessary to get ISim 10.1 to
# simulate the reference designs.
#
#####################################################################

use strict;
use warnings;
use Getopt::Long;

my $suffix = "subst";

my @defFiles;
my %defines;

parseArgs();
readDefines();
constSubst();

exit 0;

###########################################################
# Subroutines

#
# parseArgs
#   Parse the command line parameters
#
sub parseArgs {
	GetOptions(
		"define=s" => \@defFiles,
	);
}

#
# readDefines()
#   Read the defines files
#
sub readDefines {
	foreach my $file (@defFiles) {
		die "Can't find defines file '$file'" if (! -f $file);

		open DEF, $file;
		while (<DEF>) {
			chomp;

			# Remove space
			s/^\s+//;
			s/\s\+$//;

			# Remove comments
			s/\/\/.*//;

			# Skip blanks
			next if /^$/;

			# Work out if this is a define
			if (/^`define\s+(.*)/) {
				my $line = $1;
				my ($def, $val);
				if ($line =~ /\(/) {
					die "Unable to deal with parameterizable defines: '$_'";
					#my $parenDepth = 0;
					#my $spacePos = -1;
					#for (my $i = 0; $i < length($line); $i++ ) {
					#	my $chr = substr($line, $i, 1);
					#	if ($chr eq ' ' || $chr eq "\t") {
					#		if ($parenDepth == 0) {
					#			$spacePos = $i;
					#			last;
					#		}
					#	}
					#	elsif ($chr eq '(') {
					#		$parenDepth++;
					#	}
					#	elsif ($chr eq ')') {
					#		$parenDepth--;
					#	}
					#}
					#if ($spacePos >= 0) {
					#	$def = substr($line, 0, $spacePos);
					#	$val = substr($line, $spacePos + 1);
					#	$val =~ s/^\s+//;
					#}
				}
				else {
					$line =~ /(\w+)\s+(.+)/;
					$def = $1;
					$val = $2;

					# Replace hex values with decimal...
					# and drop any leading digits... (ISim
					# is annoying)
					$val =~ s/^\d+'/'/;
					if ($val =~ /^'h(\w+)/) {
						$val = hex($1);
					}
				}
				$defines{$def} = $val;
			}

		}
		close DEF;
	}
}

#
# constSubst
#   Substitute constants in source files
#
sub constSubst {
	for my $file (@ARGV) {
		die "Can't find source file '$file'" if (! -f $file);

		# Read in the file
		my $src = '';
		open SRC, $file;
		while (<SRC>) {
			$src .= $_;
		}
		close SRC;

		# Substitute each constant
		for my $def (keys(%defines)) {
			my $val = $defines{$def};
			$src =~ s/`$def/$val/g;
		}

		# Write the file to a new file
		my $file_new = "$file.$suffix";
		open SRC_NEW, "> $file_new";
		print SRC_NEW $src;
		close SRC_NEW;
	}
}
