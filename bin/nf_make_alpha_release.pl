#!/usr/bin/perl -W

#
# Perl script to generate an alpha release
# $Id: nf_make_alpha_release.pl 6067 2010-04-01 22:36:26Z grg $
#

use File::Basename;

# Files/directories to include by default
my @base = (
	'bin',
	'lib/C',
	'lib/Makefiles',
	'lib/Perl5',
	'lib/scripts',
	'README',
	'bitfiles',
	'LICENSE',
	'bashrc_addon',
	'Makefile',
	'lib/Makefile',
	'lib/java',
	'lib/python',
);

# Base NetFPGA directory
my $netfpgaBase = 'netfpga';

# Base projects directory inside NetFPGA directory
my $projectBase = 'projects';

# Bitfile directory
my $bitfiles = 'bitfiles';

# Name of tar file
my $tarFile = "netfpga.alpha";

# Get the NF_ROOT directory
my $nf2_root = $ENV{'NF_ROOT'};
if (!defined($nf2_root)) {
	die "NF_ROOT environment variable is not set";
}

# Verilog libraries to import
my $verilogLibBase = 'lib/verilog';
my @verilogLibs = ('utils', 'common', 'testbench');

# Include file location (within each project)
my $includeFile = 'include/lib_modules.txt';

# Work out what projects to export
#my @projects = ('cpci', 'driver', @ARGV);
my @projects = ('driver', 'selftest', @ARGV);

# Work out what projects to compile
my @exportBitfiles  = ('cpci', 'cpci_reprogrammer', 'selftest', @ARGV);

# Regression test project file
my $regressFile = 'projects/regress.txt';

# Verify that the projects exists and import the list of modules
foreach (@projects) {
	my $project = "$nf2_root/$projectBase/$_";
	if (! -d $project) {
		die "Cannot locate project named '$_' (in directory '$project')";
	}
	else {
		importVerilogLibs($project);
	}
}

# Creating an NetFPGA directory
mkdir $netfpgaBase or die "Unable to create directory '$netfpgaBase'";

# Compile each of the projects
print "Compiling projects...\n";
foreach (@exportBitfiles) {
	if (-d "$nf2_root/$projectBase/$_/synth") {
		print "Project $_...\n";
		my $project = "$nf2_root/$projectBase/$_/synth";

		system("cd $project && make");
	}
}

# Export the various files in base
print "Exporting base files...\n";
foreach (@base) {
	svnExport($_);
}

# Export the projects
print "Exporting project files...\n";
foreach (@projects) {
	svnExport("$projectBase/$_");
}

# Export the projects
print "Exporting Verilog libraries files...\n";
foreach (@verilogLibs) {
	svnExport("$verilogLibBase/$_");
}

## # Remove the verify directories
## print "Removing verif directories from within projects...\n";
## foreach (@projects) {
## 	my $verifDir = "$netfpgaBase/$projectBase/$_/verif";
##
## 	if (-d $verifDir) {
## 		system("rm -rf $verifDir");
## 	}
## }

# Remove the selftest source directory
print "Removing selftest hardware directories...\n";
foreach ( ("include", "src", "synth", "verif") ) {
	my $selftestDir = "$netfpgaBase/$projectBase/selftest/$_";

	if (-d $selftestDir ) {
		system("rm -rf $selftestDir");
	}
}

# Copy the relevant bitfiles
print "Copying bitfiles...\n";
foreach (@exportBitfiles) {
	my $srcBitfile = "$nf2_root/$bitfiles/$_.bit";
	my $destBitfile = "$netfpgaBase/$bitfiles/$_.bit";

	if (-f $srcBitfile) {
		system("cp $srcBitfile $destBitfile 1>/dev/null") == 0
			or die "Unable to copy bitfile '$_.bit'";
	}
}

# Update the regress.txt file
print "Updating list of projects to run in regression test...\n";
updateRegressProjects();

# Now tar up the project
print "Creating compressed tar file...\n";
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
                                                localtime(time);
my $datestr = sprintf("%02d%02d%02d", $year % 100, $mon + 1, $mday);
system("tar -cvzf $tarFile.$datestr.tgz $netfpgaBase 1>/dev/null") == 0
	or die "Unable to execute 'tar -cvzf $tarFile.$datestr.tgz $netfpgaBase'";

# Done
print "\nDone\n";
exit 0;



#####################################################################
# Functions
#


#
# Export the various directories
#
sub svnExport {
	local $_;

	my $fileOrDir = shift;

	# Create any proceeding directories if necessary
	my $dirname = dirname($fileOrDir);
	if ($dirname ne '.') {
		my $pathSoFar = $netfpgaBase;
		foreach (split('/', $dirname)) {
			if (! -d "$pathSoFar/$_") {
				mkdir "$pathSoFar/$_" or die "Unable to create directory '$pathSoFar/$_'";
			}
			$pathSoFar .= "/$_";
		}
	}

	# Perform the subversion export
	if (! -e "$netfpgaBase/$fileOrDir") {
		if (! -d "$nf2_root/$fileOrDir") {
			my @args = ("cp", "$nf2_root/$fileOrDir", "$netfpgaBase/$fileOrDir", "1>/dev/null");
			system(join(' ', @args)) == 0
				or die "system @args failed: $?";
		}
		else {
			my @args = ("svn", "export", "$nf2_root/$fileOrDir", "$netfpgaBase/$fileOrDir", "1>/dev/null");
			system(join(' ', @args)) == 0
				or die "system @args failed: $?";
		}
	}
}


#
# Import the Verilog libraries associated with a particular project
#
sub importVerilogLibs {
	local $_;

	my $project = shift;

	# Check if there is an include file
	my $include = "$project/$includeFile";
	if (-f $include ) {
		open INCLUDE, "$include"
			or die "Error opening project include file '$include'";

		# Process the lines in the file
		while (<INCLUDE>) {
			chomp;

			# Skip blank lines
			next if (/^\s*$/);

			# Verify that the location exists
			if (! -d "$nf2_root/$verilogLibBase/$_") {
				die "Unable to locate module '$_' referenced in '$include'";
			}
			else {
				push(@verilogLibs, $_);
			}
		}

		# Close the file
		close INCLUDE;
	}
}


#
# Update the list of projects to include in the regression test suite
#
sub updateRegressProjects {
	local $_;

	# Check if there is an include file
	my $src = "$nf2_root/$regressFile";
	my $dest = "$netfpgaBase/$regressFile";

	if (-f $src ) {
		# Create a hash of the projects
		my %projects;
		foreach my $proj (@projects) {
			$projects{$proj} = 1;
		}

		# Open the files
		open SRC, "$src"
			or die "Error opening source regression test file '$src'";

		open DEST, ">$dest"
			or die "Error opening destination regression test file '$dest'";

		# Process the lines in the file
		while (<SRC>) {
			# Make a copy of the line
			$line = $_;

			chomp;

			# Remove comments
			s/#.*//;

			# Copy blank lines and more into the output
			if (/^\s*$/) {
				print DEST $line;
				next;
			}

			# Check that we're processing the current project
			if (exists($projects{$_})) {
				print DEST $line;
			}
			else {
				print DEST "#$line";
			}
		}

		# Close the files
		close SRC;
		close DEST;
	}
}
