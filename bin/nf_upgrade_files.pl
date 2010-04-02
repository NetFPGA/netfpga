#!/usr/bin/perl -W

#
# Perl script to rename functions/variables in files
#

use strict;
use NF::Base;
use File::Basename;

my $extra = "-name '[Cc][Hh][Aa][Nn][Gg][Ee]*' -prune -o -name '.git' -prune -o -name '.svn' -prune -o";

my @updates = ();

# List of updates to apply
push @updates, ['use NF2::', 'use NF::'];
push @updates, ['NF2_ROOT', 'NF_ROOT'];
push @updates, ['NF2_DESIGN_DIR', 'NF_DESIGN_DIR'];
push @updates, ['NF2_WORK_DIR', 'NF_WORK_DIR'];
push @updates, ['nf2_download', 'nf_download'];

# Work out the name of this script... don't do any replacements here
my $self = basename($0);

# Walk through the updates and apply them one by one
foreach my $update (@updates) {
	my ($old, $new, $files) = @$update;
	doReplace($old, $new, $files);
}

#
# doReplace
#   Perform a replacement on a set of files
#
sub doReplace {
	my ($old, $new, $files) = @_;

	my $name = "";
	if (defined($files) and $files ne "") {
		$name = "-name '$files'";
	}
	else {
		$name = "-type f";
	}

	my $cmd = "find $ENV{NF_ROOT} $extra -name '$self' -prune -o $name -print | xargs sed -i 's/$old/$new/g'";
	print $cmd . "\n";
	system($cmd);
}
