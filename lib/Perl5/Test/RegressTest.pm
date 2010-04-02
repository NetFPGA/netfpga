#/usr/bin/perl -w

##############################################################################
#
# Script to run regression tests for all projects
# $Id: RegressTest.pm 3864 2008-06-04 07:05:15Z grg $
#
##############################################################################

package Test::RegressTest;

use strict;

use Getopt::Long;
use Test::TeamCity;
use Cwd;
use File::Spec;

use vars qw(@ISA @EXPORT);    # needed cos strict is on

@ISA    = ('Exporter');
@EXPORT = qw(
  &run_regress_test
);

$|++;

# Predeclare my_die
sub my_die;

# Location of project file to test during regressions
my $projectRoot = 'projects';
my $projectFile = 'projects/regress.txt';
my $regressRoot = 'regress';
my $regressFile = 'regress/tests.txt';
my $run         = 'run';
my $commonDir   = 'common';
my $globalDir   = 'global';
my $setup       = 'setup';
my $teardown    = 'teardown';

my $_ROOT_DIR   = '';
my $_IS_NETFPGA = 1;

use constant REQUIRED => 1;
use constant OPTIONAL => 0;

use constant GLOBAL_SETUP    => 'global setup';
use constant GLOBAL_TEARDOWN => 'global teardown';

my $quiet     = 0;
my $svnUpdate = '';
my $help      = '';
my $mapFile;
my @projects;
my $ci             = '';
my $citest         = '';
my $failfast       = 0;
my $rootOverride   = '';
my $commonSetup    = $setup;
my $commonTeardown = $teardown;

sub run_regress_test {

	my ( $int_handler, @ARGV ) = @_;

	#
	# Process arguments
	#

	unless (
		GetOptions(
			"quiet"             => \$quiet,
			"help"              => \$help,
			"map=s"             => \$mapFile,
			"project=s"         => \@projects,
			"ci=s"              => \$ci,
			"citest=s"          => \$citest,
			"failfast"          => \$failfast,
			"root=s"            => \$rootOverride,
			"common-setup=s"    => \$commonSetup,
			"common-teardown=s" => \$commonTeardown,
		)
		and ( $help eq '' )
	  )
	{
		usage();
		exit 1;
	}

	# Catch interupts (SIGINT)
	$SIG{INT} = $int_handler;

	#
	# Check stuff
	#

	# If a root override was specified, set it
	if ( $rootOverride ne '' ) {
		$_ROOT_DIR = $rootOverride;
	}
	else {
		my_die( "Unknown root test directory", 0 );
	}
	print "Root directory is $_ROOT_DIR\n";

#	# Check if this is being run on a NetFPGA
#	if ( $isNetFPGA ne '' && lc($isNetFPGA) eq 'false' ) {
#		$_IS_NETFPGA = 0;
#	}

	# Verify that the continuous integration program is correct if set
	if ( $ci ne '' && $ci ne 'teamcity' ) {
		my_die( "Unknown continuous integration \"$ci\". Supported CI programs: teamcity", 0 );
	}
	if ( $ci ne '' && $citest eq '' ) {
		my_die( "The name of the test was not specified in 'citest'", 0 );
	}
	tcDisableOutput if ( $ci ne 'teamcity' );

	unless ( -w "$_ROOT_DIR/$projectFile" ) {
		my_die("Unable to locate regression test project file $_ROOT_DIR/$projectFile");
	}

	#
	# Verify that the mapfile exists
	#
	if ( defined($mapFile) ) {
		if ( !-f $mapFile ) {
			my_die("Cannot locate map file $mapFile");
		}
		else {
			$mapFile = File::Spec->rel2abs($mapFile);
		}
	}

	#
	# Read in the list of projects to test
	#
	if ( $#projects == -1 ) {
		readProjects();
	}
	verifyProjects();

	#
	# Run the regression tests on each project one-by-one
	#
	my %results;
	my $pass = 1;
	my @failures;

	foreach my $project (@projects) {
		my ( $result, $tests, $results ) = runRegressionSuite($project);
		$pass &= $result;

		push @failures, $project unless $result;
		$results{$project} = $results;

		last if ( $failfast && !$result );
	}

	#
	# Print out any errors if they exist
	#
	if ( $quiet && !$pass ) {
		print "Regression test suite failed\n";
		print "\n";
		print "Projects failing tests:\n";
		print join( " ", @failures ) . "\n";
		print "\n";
		print "Tests failing within each project\n";
		print "=================================\n";
		foreach my $project (@failures) {
			my @results = @{ $results{$project} };

			print "$project: ";
			for ( my $i = 0 ; $i <= $#results ; $i++ ) {
				my @testSummary = @{ $results[$i] };

				if ( !$testSummary[1] ) {
					print "$testSummary[0] ";
				}
			}
			print "\n";

		}
		print "\n";
		print "\n";
		print "Failing test output\n";
		print "===================\n";

		foreach my $project (@failures) {
			my @results = @{ $results{$project} };

			for ( my $i = 0 ; $i <= $#results ; $i++ ) {
				my @testSummary = @{ $results[$i] };

				if ( !$testSummary[1] ) {
					my $test = "Project: $project   Test: $testSummary[0]";
					print $test . "\n" . ( '-' x length($test) ) . "\n";
					print "$testSummary[2]";
				}
			}
			print "\n";

		}
	}

}

# int handler was here

#########################################################
sub usage {
	( my $cmd = $0 ) =~ s/.*\///;
	print <<"HERE1";
NAME
   $cmd - run regression tests

SYNOPSIS

   $cmd
        [--quiet]
        [--map <mapfile>]
        [--project <project>] [--project <project>] ...
        [--ci <test_tool>] [--citest <test_name>]
        [--failfast]
        [--root <root_test_path>]
        [--common-setup <local common setup file name>]
        [--common-teardown <local common teardown file name>]

   $cmd --help  - show detailed help

HERE1

	return unless ($help);
	print <<"HERE";

DESCRIPTION

   This script runs individual regression tests for each project specified
   in \$ROOT_DIR/projects/regress.txt, unless a list of projects is passed in.
   Within each project, run scripts are executed; each run scripts should
   return 0 for success and non-zero for failure.

OPTIONS

   --quiet
     Run in quiet mode; don't output anything unless there are errors.

   --map <mapfile>
     Remap interfaces per mapfile, which is a list of two interfaces
     per line.

   --project <project> ...
     Run specific project(s) instead of those in regress.txt.

   --ci <test_tool> --citest <test_name>
     Unsupported; will enable the use of continuous testing tools like
     TeamCity.

   --failfast
     Fail fast causes the regression suite to fail as soon as a test
     fails and not to run the teardown scripts.

   --root <dir>
     This option allows the root directory of all projects to be overridden.

   --common-setup <local common setup file name>
     Run a custom setup script for each test.

   --common-teardown <local common teardown file name>]
     Run a custom teardown script for each test.

HERE

}

#########################################################
sub readProjects {
	local $_;

	open PROJFILE, "$_ROOT_DIR/$projectFile"
	  or my_die "Unable to open '$_ROOT_DIR/$projectFile' for reading";

	# Process each line in the project file
	while (<PROJFILE>) {
		chomp;

		# Remove comments and leading white space
		s/#.*//;
		s/^\s\+//;

		# Skip blank lines
		next if /^$/;

		# Push the project into the list of projects
		push @projects, $_;
	}

	close PROJFILE;
}

#########################################################
# verifyProjects
#   Verify that the specified projects exist and that they contain valid
#   regression test files
sub verifyProjects {
	foreach my $project (@projects) {

		# Verify that the project exists
		if ( !-d "$_ROOT_DIR/$projectRoot/$project" ) {
			my_die "Cannot locate project '$project'";
		}

		# Verify that the project has a valid regression test description
		if ( !-f "$_ROOT_DIR/$projectRoot/$project/$regressFile" ) {
			my_die
"Cannot locate regression test file '$_ROOT_DIR/$projectRoot/$project/$regressFile' for project '$project'";
		}
	}
}

#########################################################
# runRegressionSuite
#   Run the regression suite for a particular project
sub runRegressionSuite {
	my $project = shift;
	my @tests;

	# Set the correct env variables for the project
	$ENV{'NF_DESIGN_DIR'} = "$_ROOT_DIR/$projectRoot/$project/";
	$ENV{'PERL5LIB'} = "$_ROOT_DIR/lib/Perl5:$_ROOT_DIR/$projectRoot/$project/lib/Perl5";

	local $_;

	my @results;

	#my $msg = "Running tests on project '$project'...\n";
	#print (("=" x length($msg)) . "\n" . $msg) unless $quiet;
	print "Running tests on project '$project'...\n" unless $quiet;

	# Read the tests
	open REGRESSFILE, "$_ROOT_DIR/$projectRoot/$project/$regressFile"
	  or my_die "Unable to open '$_ROOT_DIR/$projectRoot/$project/$regressFile' for reading";

	while (<REGRESSFILE>) {
		chomp;

		# Remove comments and leading/trailing white space
		s/#.*//;
		s/^\s+//;
		s/\s+$//;

		# Skip blank lines
		next if /^$/;

		# Store the test
		push @tests, $_;
	}

	close REGRESSFILE;

	# Run the tests one by one
	my %testResults;
	my $pass       = 1;
	my $commonPass = 1;
	my $test;

	$test = $citest . tcGetTestSeparator . 'global.setup';
	tcTestStarted($test);
	print "  Running global setup... " unless $quiet;
	my ( $gsResult, $output ) = runGlobalSetup($project);
	if ( !$gsResult ) {
		$pass = 0;

		# Store the test results for later
		$testResults{GLOBAL_SETUP} = $gsResult;
		my @test_result = ( GLOBAL_SETUP, $gsResult, $output );
		push @results, \@test_result;
	}
	printScriptOutput( $gsResult, $output );
	tcTestFailed( $test, 'Test failed', $output ) if ( !$gsResult );
	tcTestFinished($test);

	if ($gsResult) {
		foreach $test (@tests) {
			my $testStr = $citest . tcGetTestSeparator . $test;
			tcTestStarted($testStr);
			print "  Running test '$test'... " unless $quiet;

			# Common setup
			my ( $csResult, $lsResult, $testResult, $ltResult, $ctResult ) = ( 1, 1, 1, 1, 1 );
			my ( $csOutput, $lsOutput, $testOutput, $ltOutput, $ctOutput );
			( $csResult, $csOutput ) = runCommonSetup($project);
			$testResults{$test} = $csResult;
			$pass       &= $csResult;
			$commonPass &= $csResult;

			# Local setup -- only run if common setup passed
			if ($csResult) {
				( $lsResult, $lsOutput ) = runLocalSetup( $project, $test );
				$testResults{$test} = $lsResult;
				$pass &= $lsResult;
			}

			# Actual test -- only run if both setups succeed
			if ( $csResult && $lsResult ) {
				( $testResult, $testOutput ) = runTest( $project, $test );
				$testResults{$test} = $testResult;
				$pass &= $testResult;
			}

			# Local teardown -- only run if the local setup succeeded
			if ( $csResult && $lsResult ) {
				( $ltResult, $ltOutput ) = runLocalTeardown( $project, $test );
				$testResults{$test} = $ltResult;
				$pass &= $ltResult;
			}

			# Common teardown -- only run if the common setup succeeded
			if ($csResult) {
				( $ctResult, $ctOutput ) = runCommonTeardown($project);
				$testResults{$test} = $ctResult;
				$pass       &= $ctResult;
				$commonPass &= $ctResult;
			}

			# Store the test results for later
			$testResult &= $csResult & $lsResult & $ltResult & $ctResult;

			my $output = '';
			$output .= $csOutput   if ( !$csResult );
			$output .= $lsOutput   if ( !$lsResult );
			$output .= $testOutput if ( !$testResult );
			$output .= $ltOutput   if ( !$ltResult );
			$output .= $ctOutput   if ( !$ctResult );

			$output = $testOutput if ($testResult);

			my @test_result = ( $test, $testResult, $output );
			push @results, \@test_result;

			printScriptOutput( $testResult, $output );
			tcTestFailed( $testStr, 'Test failed', $output ) if ( !$testResult );
			tcTestFinished($testStr);

			# Break the tests if the test failed during common setup/teardown
			last if ( !$commonPass );

			# Break the tests if the test failed and we're in failfast mode
			last if ( $failfast && !$testResult );
		}
	}

	# Run the teardown if the global setup passed and
	# the tests passed or we're not doing a failfast
	if ( $gsResult && ( !$failfast || $pass ) ) {
		$test = $citest . tcGetTestSeparator . 'global.teardown';
		tcTestStarted($test);
		print "  Running global teardown... " unless $quiet;
		my ( $result, $output ) = runGlobalTeardown($project);
		if ( !$result ) {
			$pass = 0;

			# Store the test results for later
			$testResults{GLOBAL_TEARDOWN} = $result;
			my @test_result = ( GLOBAL_TEARDOWN, $result, $output );
			push @results, \@test_result;
		}
		printScriptOutput( $result, $output );
		tcTestFailed( $test, 'Test failed', $output ) if ( !$result );
		tcTestFinished($test);
	}

	print "\n\n" unless $quiet;

	# Return the status of the test, plus the various results
	return ( $pass, \@tests, \@results );
}

#########################################################
# runTest
#   Run an individual test from a regression suite
sub runTest {
	my $project = shift;
	my $test    = shift;

	if ( -d "$_ROOT_DIR/$projectRoot/$project/$regressRoot/$test" ) {
		return runScript( $project, $test, $run, REQUIRED );
	}
	else {
		if ( $test =~ /(.*)\/([^\/]*)/ ) {
			my $dir      = $1;
			my $fileName = $2;
			return runScript( $project, $dir, $fileName, REQUIRED );
		}
		my_die "Error finding test file: $test\n";
	}
}

#########################################################
# runGlobalSetup
#   Run the global setup for a regression suite
sub runGlobalSetup {
	my $project = shift;

	return runScript( $project, $globalDir, $setup, OPTIONAL );
}

#########################################################
# runGlobalTeardown
#   Run the global setup for a regression suite
sub runGlobalTeardown {
	my $project = shift;

	return runScript( $project, $globalDir, $teardown, OPTIONAL );
}

#########################################################
# runCommonSetup
#   Run the common setup for a regression suite
sub runCommonSetup {
	my $project = shift;

	return runScript( $project, $commonDir, $commonSetup, OPTIONAL );
}

#########################################################
# runCommonTeardown
#   Run the common setup for a regression suite
sub runCommonTeardown {
	my $project = shift;

	return runScript( $project, $commonDir, $commonTeardown, OPTIONAL );
}

#########################################################
# runLocalSetup
#   Run the local setup for a test within the regression suite
sub runLocalSetup {
	my $project = shift;
	my $test    = shift;

	if ( $test =~ /(.*)\/([^\/]*)/ ) {
		my $dir = $1;
		return runScript( $project, $dir, $setup, OPTIONAL );
	}
	else {
		return runScript( $project, $test, $setup, OPTIONAL );
	}
}

#########################################################
# runLocalTeardown
#   Run the local teardown for a test within the regression suite
sub runLocalTeardown {
	my $project = shift;
	my $test    = shift;

	if ( $test =~ /(.*)\/([^\/]*)/ ) {
		my $dir = $1;
		return runScript( $project, $dir, $teardown, OPTIONAL );
	}
	else {
		return runScript( $project, $test, $teardown, OPTIONAL );
	}
}

#########################################################
# runScript
#   Run a test/setup/teardown script rom a regression suite
sub runScript {
	my $project  = shift;
	my $dir      = shift;
	my $script   = shift;
	my $required = shift;

	my $args = '';

	# Verify that the test exists
	unless ( -x "$_ROOT_DIR/$projectRoot/$project/$regressRoot/$dir/$script" ) {
		if ( $required == REQUIRED ) {
			my_die "Unable to run test '$dir' for project '$project'";
		}
		else {
			return ( 1, "" );
		}
	}

	# Construct the arguments
	#
	# Map file if it exists
	if ( defined($mapFile) ) {
		$args .= "--map $mapFile ";
	}

	# Change to the test directory
	my $origDir = getcwd;
	my $testDir = "$_ROOT_DIR/$projectRoot/$project/$regressRoot/$dir";
	chdir($testDir)
	  or my_die "Unable to change directory to '$regressRoot/$dir'";

	# Run the test
	my $output = `$testDir/$script $args 2>&1`;

	# Change back to the original directory
	chdir($origDir)
	  or my_die "Unable to change directory to '$origDir'";

	if ( $? != 0 ) {
		$output .= "\n\n";
		$output .= "$dir/$script received signal " . ( $? & 127 ) . "\n" if ( $? & 127 );
		$output .= "$dir/$script dumped core\n" if ( $? & 128 );
		$output .= "$dir/$script exited with value " . ( $? >> 8 ) . "\n" if ( $? >> 8 );
	}

	# Return 0 to indicate failure
	return ( $? == 0, $output );
}

#########################################################
# printScriptOutput
#   Print the result of a test script
sub printScriptOutput {
	my ( $result, $output ) = @_;

	if ( !$quiet ) {
		if ($result) {
			print "PASS\n";
		}
		else {
			print "FAIL\n";
			print "Output was:\n";
			print $output;
			print "\n";
		}
	}
}

#########################################################
sub my_die {
	my $mess     = shift @_;
	my $details  = shift @_;
	my $enableTC = shift @_;

	$details  = '' if ( !defined($details) );
	$enableTC = 1  if ( !defined($enableTC) );

	( my $cmd = $0 ) =~ s/.*\///;
	print STDERR "\n$cmd: $mess\n";
	tcTestFailed( $citest, $mess, $details );
	exit 1;
}
