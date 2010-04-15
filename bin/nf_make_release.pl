#!/usr/bin/perl -W

#
# Perl script to generate a release
# $Id: nf_make_release.pl 6067 2010-04-01 22:36:26Z grg $
#

use File::Basename;
use XML::Simple;
use Getopt::Long;
use strict;

# Base NetFPGA directory
my $netfpgaBase = 'netfpga';

# Base projects directory inside NetFPGA directory
my $projectBase = 'projects';

# Bitfile directory
my $bitfiles = 'bitfiles';

# Base of tar file
my $tarBase = "netfpga";

# Get the NF_ROOT directory
my $nf2_root = $ENV{'NF_ROOT'};
if (!defined($nf2_root)) {
	die "NF_ROOT environment variable is not set";
}

# Verilog libraries to import
my $verilogLibBase = 'lib/verilog';
my @verilogLibs = ('core/utils', 'core/common', 'core/testbench');

# Project file location (within each project)
my $projectFile = 'include/project.xml';

# Regression test project file
my $regressFile = 'projects/regress.txt';

# Specifies whether the package will be pulled from an svn repository or not
my $no_svn = 0;

# Specifies whether the package is a NetFPGA base package or not
my $base_pkg = 0;

# Print detailed help
my $help;

# Parse the command line options
my $buildFile = parseArgs();

# Open the XML file
my $build;
if (-f $buildFile) {
	$build = XMLin($buildFile, forcearray => 1);
}
else {
	print "Error: Cannot find release file: '$build'\n";
	usage();
	exit;
}

# Verify that the NetFPGA directory doesn't exist
if (-d "$netfpgaBase") {
	die "Directory '$netfpgaBase' already exists. Please remove directory before proceeding.";
}

# Files/directories to include by default
my @base = getBase();

# Get the list of releases
my @releases = getReleases();

foreach my $release (@releases) {
	print "Building release '$release'...\n";

	my @projVerilogLibs;

	if ($base_pkg == 1) {
		@projVerilogLibs = @verilogLibs;
	}

	my @projVerilogDirs;

	# Get the version info
	my $version = getVersion($release);
	$version =~ s/\./_/;

	# Work out the tar filename
	my $tarFile = "$tarBase.$release";
	$tarFile .= ".$version" if (defined($version) && $version ne "");

	# Work out what projects to export
	my @projects = getProjects($release);
	my @excludes = getExcludes($release);

	# Work out what projects to compile
	my @exportBitfiles  = getBitfiles($release, @projects);

	# Work out what software sources to compile
	my @exportBinaries  = getBinaries($release);

	my $excludedLibs = importVerilogExcludeLibs(@excludes);

	# Verify that the projects exists and import the list of modules
	foreach (@projects) {
		my $project = "$nf2_root/$projectBase/$_";
		if (! -d $project) {
			die "Cannot locate project named '$_' (in directory '$project')";
		}
		elsif (wantVerilog($release, $_) && !wantPrjVerilogOnly($release, $_)) {
			push @projVerilogLibs, importVerilogLibs($_, $excludedLibs);
		}
		else {
			my ($libs, $dirs) = importVerilogLibsXML($_, $excludedLibs);
			push @projVerilogLibs, @$libs;
			push @projVerilogDirs, @$dirs;
		}
	}

	# Get the extra verilog libraries
	push @projVerilogLibs, getExtraVerilogLibs($release);

	# Get the list of files to copy
	my @copyList = getCopyList($release);

	# Creating an NetFPGA directory
	mkdir $netfpgaBase or die "Unable to create directory '$netfpgaBase'";

	# Compile each of the projects
	print "Compiling projects...\n";
	foreach (@exportBitfiles) {
		if (-d "$nf2_root/$projectBase/$_/synth") {
			print "Project $_...\n";
			my $project = "$nf2_root/$projectBase/$_/synth";

			#system("cd $project && make");
			system("cd $project && make") if ($_ ne "selftest");
		}
	}

	# Compile each of the projects
	print "Compiling software binaries...\n";
	foreach (@exportBinaries) {
		my ($binFile, $proj) = split(':', $_);

		print "$nf2_root/$projectBase/$proj/sw\n";

		if (-d "$nf2_root/$projectBase/$proj/sw") {
			print "Project $_...\n";
			my $project = "$nf2_root/$projectBase/$proj/sw";

			system("cd $project && make $binFile");
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

	if ($projVerilogLibs[0] ne "") { #if not empty
 		# Export the projects
	 	print "Exporting Verilog libraries files...\n";
		foreach (@projVerilogLibs) {
			svnExport("$verilogLibBase/$_");
		}
	}

	if ($projVerilogLibs[0] ne "") { #if not empty
		# Export the projects
		print "Exporting Verilog libraries files...\n";
		foreach (@projVerilogDirs) {
			`mkdir -p $netfpgaBase/$verilogLibBase/$_`;
		}
	}

	# Remove the hardware source
	print "Removing hardware/software source from within specified projects...\n";
	foreach (@projects) {
		if (!wantVerilog($release, $_)) {
			foreach my $dir ('src', 'verif', 'synth') {
				my $workDir = "$netfpgaBase/$projectBase/$_/$dir";

				if (-d $workDir) {
					system("rm -rf $workDir");
				}
			}
		}

		if (!wantSoftware($release, $_)) {
			my $swDir = "$netfpgaBase/$projectBase/$_/sw";

			if (-d $swDir) {
				system("rm -rf $swDir");
			}
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

	# Copy the relevant bitfiles
	print "Copying binaries...\n";
	foreach (@exportBinaries) {
		my ($binFile, $proj) = split(':', $_);

		my $srcBinary = "$nf2_root/$projectBase/$proj/sw/$binFile";

		my $destDir = "$netfpgaBase/$projectBase/$proj/sw";
		my $destBinary = "$destDir/$binFile";


		if (! -d $destDir) {
			system("mkdir -p $destDir") == 0
				or die "Unable to create directory '$destDir'";
		}

		if (-f $srcBinary) {
			system("cp $srcBinary $destBinary 1>/dev/null") == 0
				or die "Unable to copy binary '$srcBinary'";
		}
	}

	# Copy the copy files
	print "Copying other files...\n";
	foreach (@copyList) {
		my $src = "$nf2_root/$_";
		my $dest = "$netfpgaBase/$_";

		if (-f $src) {
			# Verify that the dest directory exists
			my $destDir = dirname($dest);
			if (! -d $destDir) {
				system("mkdir -p $destDir") == 0
					or die "Unable to create directory '$destDir'";
			}

			system("cp $src $dest 1>/dev/null") == 0
				or die "Unable to copy file '$_'";
		}
	}

	if ($base_pkg == 1) {
		# Update the regress.txt file
		print "Updating list of projects to run in regression test...\n";
		updateRegressProjects(@projects);
	}

	# Now tar up the project
	print "Creating compressed tar file...\n";
	## my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) =
	## 						localtime(time);
	## my $datestr = sprintf("%02d%02d%02d", $year % 100, $mon + 1, $mday);
	## system("tar -cvzf $tarFile.$datestr.tgz $netfpgaBase 1>/dev/null") == 0
	## 	or die "Unable to execute 'tar -cvzf $tarFile.$datestr.tgz $netfpgaBase'";
	system("tar -cvzf $tarFile.tar.gz $netfpgaBase 1>/dev/null") == 0
		or die "Unable to execute 'tar -cvzf $tarFile.tar.gz $netfpgaBase'";

	# Remove the NetFPGA directory
	system("rm -rf $netfpgaBase") == 0
		or die "Unable to remove directory '$netfpgaBase'";

	print "\n\n";
}

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
		elsif ($no_svn == 0) {
			my @args = ("svn", "export", "$nf2_root/$fileOrDir", "$netfpgaBase/$fileOrDir", "1>/dev/null");
			system(join(' ', @args)) == 0
				or die "system @args failed: $?";
		}
		else {
			my @args = ("cp", "-r", "$nf2_root/$fileOrDir", "$netfpgaBase/$fileOrDir", "1>/dev/null");
			system(join(' ', @args)) == 0
 				or die "system @args failed: $?";
		}
	}
}

#
# Import the Verilog libraries XML associated with a particular project
#
sub importVerilogLibsXML {
	local $_;

	my ($project, $excludes) = @_;
	my @extraVerilogLibs;
	my @extraVerilogDirs;

	# Check if there is an project file
	my $projectXML = "$nf2_root/$projectBase/$project/$projectFile";
	if (-f $projectXML ) {

		my $include = `$nf2_root/bin/nf_register_gen.pl --project $project --list-modules --list-shared --simple-error --quiet`;
		my @lines = split /\n/, $include;
		# Process the lines in the file
		foreach my $line (@lines) {
			chomp $line;

			# Skip blank lines
			next if ($line =~ /^\s*$/);

			# Verify that the location exists
			if (! -d "$nf2_root/$verilogLibBase/$line") {
				die "Unable to locate module '$line' referenced in '$projectXML'";
			}
			elsif (!exists($excludes->{$line})) {
				# If there is an xml directory include it
				if (-d "$nf2_root/$verilogLibBase/$line/xml") {
 					push(@extraVerilogLibs, "$line/xml");
				}
				else {
					push(@extraVerilogDirs, "$line");
				}
			}
		}

	}

	return \@extraVerilogLibs, \@extraVerilogDirs;
}

#
# Import the Verilog libraries associated with a excluded projects
#
sub importVerilogExcludeLibs {
	local $_;

	my @projects = @_;
	my $project;

	my %excludedVerilogLibs;

	foreach $project (@projects) {
		# Check if there is an project file
		my $projectXML = "$nf2_root/$projectBase/$project/$projectFile";
		if (-f $projectXML ) {
			my $include = `$nf2_root/bin/nf_register_gen.pl --project $project --list-modules --simple-error --quiet`;
			my @lines = split /\n/, $include;
			# Process the lines in the file
			foreach my $line (@lines) {
				chomp $line;

				# Skip blank lines
				next if ($line =~ /^\s*$/);

				# Verify that the location exists
				if (! -d "$nf2_root/$verilogLibBase/$line") {
					die "Unable to locate module '$line' referenced in '$projectXML'";
				}
				else {
					$excludedVerilogLibs { $line } = $line;
				}
			}
		}
	}

	return \%excludedVerilogLibs;
}


#
# Import the Verilog libraries associated with a particular project
#
sub importVerilogLibs {
	local $_;
	my ($project, $excludes) = @_;

	my @extraVerilogLibs;

	# Check if there is an project file
	my $projectXML = "$nf2_root/$projectBase/$project/$projectFile";
	if (-f $projectXML ) {

		my $include = `$nf2_root/bin/nf_register_gen.pl --project $project --list-modules --simple-error --quiet`;
		my @lines = split /\n/, $include;
		# Process the lines in the file
		foreach my $line (@lines) {
			chomp $line;

			# Skip blank lines
			next if ($line =~ /^\s*$/);

			# Verify that the location exists
			if (! -d "$nf2_root/$verilogLibBase/$line") {
				die "Unable to locate module '$line' referenced in '$projectXML'";
			}
			elsif (!exists($excludes->{$line})) {
				push(@extraVerilogLibs, $line);
			}
		}
	}

	return @extraVerilogLibs;
}

#
# Update the list of projects to include in the regression test suite
#
sub updateRegressProjects {
	local $_;

	my @projects = @_;

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
			my $line = $_;

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

#
# getBase
#   Return the base set of directories
#
sub getBase {
	# Find the release
	my $base = $build->{'base'};
	return keys(%$base);
}

#
# getReleases
#   Return a list of releases from the build hash
#
sub getReleases {
	my $relName = shift;

	# Find the release
	my $releases = $build->{'release'};
	return keys(%$releases);

	if (defined($releases->{$relName})) {
		my $release = $releases->{$relName};

		# Return the projects
		if (defined($release->{'project'})) {
			return keys(%{$release->{'project'}});
		}

		# return the excludes
		if (defined($release->{'exclude'})) {
			return keys(%{$release->{'exclude'}});
		}
	}
}

#
# getProjects
#   Return a list of projects from the build hash
#
sub getProjects {
	my $relName = shift;

	# Find the release
	my $releases = $build->{'release'};
	if (defined($releases->{$relName})) {
		my $release = $releases->{$relName};

		# Return the projects
		if (defined($release->{'project'})) {
			return keys(%{$release->{'project'}});
		}
	}
}

#
# getExcludes
#   Return a list of excludes from the build hash
#
sub getExcludes {
	my $relName = shift;

	# Find the release
	my $releases = $build->{'release'};
	if (defined($releases->{$relName})) {
		my $release = $releases->{$relName};

		# Return the excludes
		if (defined($release->{'exclude'})) {
			return keys(%{$release->{'exclude'}});
		}
	}
}

#
# getCopyList
#   Return a list of files to copy from the build hash
#
sub getCopyList {
	my $relName = shift;

	# Find the release
	my $releases = $build->{'release'};
	if (defined($releases->{$relName})) {
		my $release = $releases->{$relName};

		# Return the projects
		if (defined($release->{'copy'})) {
			return @{$release->{'copy'}};
		}
	}
}

#
# getExtraVerilogLibs
#   Return a list of extra Verilog libs from the build hash
#
sub getExtraVerilogLibs {
	my $relName = shift;

	# Find the release
	my $releases = $build->{'release'};
	if (defined($releases->{$relName})) {
		my $release = $releases->{$relName};

		# Return the projects
		if (defined($release->{'verlibinclude'})) {
			return keys(%{$release->{'verlibinclude'}});
		}
	}
}

#
# getVersion
#   Return the version for the current project
#
sub getVersion {
	my $relName = shift;

	# Find the release
	my $releases = $build->{'release'};
	if (defined($releases->{$relName})) {
		my $release = $releases->{$relName};

		# Return the projects
		if (defined($release->{'version'})) {
			return $release->{'version'};
		}
	}

	return "";
}

#
# getBitfiles
#   Return a list of bitfiles from the build hash
#
sub getBitfiles {
	my $relName = shift;
	my @projects = @_;

	my %bitfiles;

	# Find the release
	my $releases = $build->{'release'};
	if (defined($releases->{$relName})) {
		my $release = $releases->{$relName};

		# Return the bitfiles
		if (defined($release->{'bitfile'})) {
			foreach my $bitfile (keys(%{$release->{'bitfile'}})) {
				$bitfiles{$bitfile} = 1;
			}
		}
	}

	# Add the bitfiles corresponding to the projects
	foreach (@projects) {
		my $project = "$nf2_root/$projectBase/$_/synth";
		if (-d $project) {
			$bitfiles{$_} = 1;
		}
	}

	return keys(%bitfiles);
}

#
# getBinaries
#   Return a list of software binaries from the build hash
#
sub getBinaries {
	my $relName = shift;

	my @binaries;

	# Find the release
	my $releases = $build->{'release'};
	if (defined($releases->{$relName})) {
		my $release = $releases->{$relName};

		# Return the bitfiles
		if (defined($release->{'binary'})) {
			foreach my $binName (keys(%{$release->{'binary'}})) {
				my $res = "$binName:";

				my $binary = $release->{'binary'}->{$binName};
				if (defined($binary->{'project'})) {
					$res .= "$binary->{'project'}";

				}

				push @binaries, $res;
			}
		}
	}

	return @binaries;
}

#
# parseArgs
#   Parse the command line arguments
#
sub parseArgs {
	unless (GetOptions(
			"no_svn"          => \$no_svn,
			"base_pkg"        => \$base_pkg,
			"help"            => \$help,
		) and (!defined($help))) {
		usage();
		exit 1;
	}
	if (scalar(@ARGV) != 1) {
		usage();
		exit 1;
	}

	return $ARGV[0];
}

#
# usage
#   Print out the usage information
#
sub usage {
	my $prog = $0;

	print <<EOF;
Usage:
  $0 [--no_svn] <build file>

where
  [--no_svn]   -- specifies that the package does not come from an svn repository
  <build file> -- XML build file specify release(s) to build

EOF
}

#
# wantVerilog
#   Check whether to include verilog sources for a particular project
#
sub wantVerilog {
	my ($relName, $projName) = @_;

	# Find the release
	my $releases = $build->{'release'};
	if (defined($releases->{$relName})) {
		my $release = $releases->{$relName};

		# Find the project
		my $projects = $release->{'project'};
		if (defined($projects->{$projName})) {
			my $project = $projects->{$projName};

			return !defined($project->{'noverilog'});
		}
	}

	return 1;
}

#
# wantPrjVerilogOnly
#   Check whether to include verilog sources for a particular project
#
sub wantPrjVerilogOnly {
	my ($relName, $projName) = @_;

	# Find the release
	my $releases = $build->{'release'};
	if (defined($releases->{$relName})) {
		my $release = $releases->{$relName};

		# Find the project
		my $projects = $release->{'project'};
		if (defined($projects->{$projName})) {
			my $project = $projects->{$projName};

			return defined($project->{'project_verilog_only'});
		}
	}

	return 1;
}

#
# wantSoftware
#   Check whether to include verilog sources for a particular project
#
sub wantSoftware {
	my ($relName, $projName) = @_;

	# Find the release
	my $releases = $build->{'release'};
	if (defined($releases->{$relName})) {
		my $release = $releases->{$relName};

		# Find the project
		my $projects = $release->{'project'};
		if (defined($projects->{$projName})) {
			my $project = $projects->{$projName};

			return !defined($project->{'nosrc'});
		}
	}

	return 1;
}

