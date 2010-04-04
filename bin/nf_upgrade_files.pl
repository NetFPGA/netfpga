#!/usr/bin/perl -W

#
# Perl script to rename functions/variables in files
#

use strict;
use NF::Base;
use File::Basename;
use File::Copy;

my $extra = "-name '[Cc][Hh][Aa][Nn][Gg][Ee]*' -prune -o -name '.git' -prune -o -name '.svn' -prune -o";

my @updates = ();

# List of updates to apply
push @updates, ['use NF2::', 'use NF::'];
push @updates, ['NF2_ROOT', 'NF_ROOT'];
push @updates, ['NF2_DESIGN_DIR', 'NF_DESIGN_DIR'];
push @updates, ['NF2_WORK_DIR', 'NF_WORK_DIR'];
push @updates, ['nf2_download', 'nf_download'];

my $dev_id_file = "dev_id.v";

# Work out the name of this script... don't do any replacements here
my $self = basename($0);

# Walk through the updates and apply them one by one
foreach my $update (@updates) {
	my ($old, $new, $files) = @$update;
	doReplace($old, $new, $files);
}

# Merge the device ID info of any projects into the project.xml
mergeDevID();

exit 0;

#####################################################################
# Subroutines
#####################################################################

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

#
# mergeDevID
#   Merge the dev_id.v file info into the project.xml
#
sub mergeDevID {
	# Begin by finding all of the project.xml files
	my $cmd = "find $ENV{NF_ROOT} $extra -name '$self' -prune -o -name project.xml -print";
	print $cmd . "\n";
	my $xmls = `$cmd`;

	# Walk through the projects
	foreach my $xml (split('\n', $xmls)) {
		my $dir = dirname($xml);
		if (-f "$dir/$dev_id_file") {
			print "Updating project XML for '$xml'";

			my $dev_id = 0;
			my $dev_rev = 0;
			my $dev_str = "";

			# Attempt to read the file contents
			open DEV_ID, "$dir/$dev_id_file";
			while (<DEV_ID>) {
				chomp;
				if (/DEVICE_ID (\d+)/) {
					$dev_id = $1;
				}
				if (/DEVICE_REVISION (\d+)/) {
					$dev_rev = $1;
				}
				if (/DEVICE_STR "(.*)"/) {
					$dev_str = $1;
				}
			}
			close DEV_ID;

			# Open the project.xml for reading/writing
			my $seen_desc = 0;
			my $seen_use_modules = 0;
			my $projXML = "";
			my $indent = "";
			open PROJ_XML, "$xml";
			while (<PROJ_XML>) {
				chomp;
				if (/nf:description/) {
					$seen_desc = 1;
				}
				if (!$seen_use_modules) {
					if (/nf:use_modules/) {
						$seen_use_modules = 1;

						$indent = $_;
						$indent =~ s/^(\s*).*/$1/;
						if (!$seen_desc) {
							$projXML .= "${indent}<nf:description>$dev_str</nf:description>\n";
						}
						$projXML .= "${indent}<nf:version_major>0</nf:version_major>\n";
						$projXML .= "${indent}<nf:version_minor>$dev_rev</nf:version_minor>\n";
						$projXML .= "${indent}<nf:version_revision>0</nf:version_revision>\n";
						$projXML .= "${indent}<nf:dev_id>0<!--$dev_id--></nf:dev_id>\n";
					}
				}
				$projXML .= $_ . "\n";
			}
			close PROJ_XML;

			# Write the new file
			move($xml, "$xml.orig");
			open PROJ_XML, ">$xml";
			print PROJ_XML $projXML;
			close PROJ_XML;

			# Move the device id file to something else
			move("$dir/$dev_id_file", "$dir/$dev_id_file.orig");
		}
	}
}
