#!/usr/bin/perl -w

#
# Fetch the memory models used by NetFPGA
#
# Hopefully the output will be in a format that TeamCity can parse
#

use strict;
use Cwd;
use NF::TeamCity;
use File::Path;

# Location of work and config directories
# - relative to NF_ROOT
# - if NF_ROOT is the work dir then use '.' -- don't leave blank
my $workDir = 'builders/work';

# Memory models
my $ddrURL = "http://download.micron.com/downloads/models/verilog/sdram/ddr2/256Mb_ddr2.zip";
my $ddrFile = "256Mb_ddr2.zip";
my %ddrTargets = (
	"ddr2_parameters.vh" => "ddr2_parameters.vh",
	"ddr2.v" => "ddr2.v"
);
my $ddrSrcPrefix = '.';

my $sramURL = "http://www.cypress.com/?docID=25033";
my $sramFile = "cy7c1370d_verilog_10.zip";
my %sramTargets = (
	"cy7c1370d.v" => "cy7c1370.v"
);
my $sramSrcPrefix = 'CY7C1370D/1370';

# Destination directory for memory models
my $destDir = 'lib/verilog/core/common/src';

# Test suite name
my $suite = 'fetch.mem.models';

# Work out the NF_ROOT
if (!defined($ENV{'NF_ROOT'})) {
	die "NF_ROOT not set";
}
elsif (! -d $ENV{'NF_ROOT'}) {
	die "NF_ROOT ('$ENV{'NF_ROOT'}') is not a valid directory";
}

chdir $ENV{'NF_ROOT'};

&tcTestSuiteStarted($suite);

# Create the work directory if necessary
#&createWorkDir;
mkpath($workDir);

# Get the RAM models
&getModel('ddr', $ddrURL, $ddrFile, $ddrSrcPrefix, \%ddrTargets);
&getModel('sram', $sramURL, $sramFile, $sramSrcPrefix, \%sramTargets);

&tcTestSuiteFinished($suite);

exit;

##############################################################################
#   Functions
##############################################################################

########################################
#
# Get a memory model
#
########################################
sub getModel {
	my $memType = shift;
	my $URL = shift;
	my $file = shift;
	my $srcPrefix = shift;
	my %targets = %{$_[0]};

	my $ok = 1;
	my $test;

	&tcTestStarted($suite . tcGetTestSeparator . $memType);

	# Check to see if the files need to be fetched
	my $needFetch = 0;
	foreach my $dest (values(%targets)) {
		$needFetch = 1 if (! -f "$destDir/$dest");
	}

	if ($needFetch) {
		# Perform the wget
		if ($ok) {
			$test = $suite . tcGetTestSeparator . $memType . tcGetTestSeparator . 'wget';
			&tcTestStarted($test);

			my $wgetResult = `wget -O $workDir/$file $URL 2>&1`;
			if ($? != 0) {
				$ok = 0;
				&tcTestFailed($test, "Unable to fetch $memType memory model", "URL: $URL");
			}
			&tcTestFinished($test);
		}

		# Extract the source
		if ($ok) {
			$test = $suite . tcGetTestSeparator . $memType . tcGetTestSeparator . 'extract';
			&tcTestStarted($test);

			chdir $workDir;
			if ($file =~ /\.tgz$/ || $file =~ /\.tar\.gz$/) {
				system("tar -xzf $file");
			}
			elsif ($file =~ /\.zip$/) {
				system("unzip $file");
			}
			chdir $ENV{'NF_ROOT'};

			if ($? != 0) {
				$ok = 0;
				&tcTestFailed($test, "Error extracting files from archive", "Source: $file");

			}

			&tcTestFinished($test);
		}

		# Copy the relevant targets
		if ($ok) {
			$test = $suite . tcGetTestSeparator . $memType . tcGetTestSeparator . 'copy';
			&tcTestStarted($test);

			foreach my $src (keys(%targets)) {
				my $dest = $targets{$src};

				system("cp $workDir/$srcPrefix/$src $destDir/$dest");

				if ($? != 0) {
					$ok = 0;
					&tcTestFailed($test, "Error copying file", "Source: $workDir/$srcPrefix/$src   Dest: $destDir/$dest");
				}
			}

			&tcTestFinished($test);
		}

		&tcTestFinished($suite . tcGetTestSeparator . '$memType');
	}
	else {
		&tcTestIgnored($memType, 'Memory models already exist');
		&tcTestFinished($suite . tcGetTestSeparator . '$memType');
	}
}


#
# Create the work directory if it doesn't already exist
#
sub createWorkDir {
	if (! -d $workDir) {
		my @path = split(/\//, $workDir);

		my $pathSoFar = '';
		foreach my $dir (@path) {
			mkdir "${pathSoFar}${dir}" if (! -d "${pathSoFar}${dir}");
			$pathSoFar .= "$dir/";
		}
	}
}
