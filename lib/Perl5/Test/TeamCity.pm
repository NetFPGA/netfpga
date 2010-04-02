#############################################################
# $Id: TeamCity.pm 6067 2010-04-01 22:36:26Z grg $
#
#
# TeamCity library for including output suitable for the
# TeamCity continuous integration software
#
#
# Invoke using: use NF::TeamCity
#
# Revisions:
#
##############################################################

package Test::TeamCity;
use Exporter;
use strict;

use vars qw(@ISA @EXPORT);  # needed cos strict is on

@ISA = ('Exporter');
@EXPORT = qw(
             &tcTestSuiteStarted
             &tcTestSuiteFinished
             &tcTestStarted
             &tcTestFinished
             &tcTestFailed
             &tcTestIgnored
             &tcEnableOutput
             &tcDisableOutput
	     &tcIsEnabled
	     &tcRunMake
	     &tcRunProg
	     &tcSetRoot
	     &tcGetTestSeparator
	     &tcSetTestSeparator
            );

# Output currently enabled
my $oe = 1;

# Root directory for NetFPGA -- used to identify locations of files
my $nf2_root = '';

# Separator to use between tests
my $separator = ' - ';


INIT {
	# Work out the NF_ROOT
	if (defined($ENV{'NF_ROOT'})) {
		$nf2_root = $ENV{'NF_ROOT'};
	}
}

###############################################################
# Name: tcTestSuiteStarted
#
# Print a testSuiteStarted message
#
# Arguments: 	suite		test suite name
#
###############################################################
sub tcTestSuiteStarted {
	my $suite = shift;

	print "##teamcity[testSuiteStarted name='$suite']\n" if $oe;
}


###############################################################
# Name: tcTestSuiteFinished
#
# Print a testSuiteFinished message
#
# Arguments: 	suite		test suite name
#
###############################################################
sub tcTestSuiteFinished {
	my $suite = shift;

	print "##teamcity[testSuiteFinished name='$suite']\n" if $oe;
}


###############################################################
# Name: tcTestStarted
#
# Print a testStarted message
#
# Arguments: 	test		test name
#
###############################################################
sub tcTestStarted {
	my $test = shift;

	print "##teamcity[testStarted name='$test']\n" if $oe;
}


###############################################################
# Name: tcTestFinished
#
# Print a testFinished message
#
# Arguments: 	test		test name
#
###############################################################
sub tcTestFinished {
	my $test = shift;

	print "##teamcity[testFinished name='$test']\n" if $oe;
}


###############################################################
# Name: tcTestFailed
#
# Print a testFailed message
#
# Arguments: 	test		test name
#		msg		message to print
#		details		details (stacktrace, etc)
#
###############################################################
sub tcTestFailed {
	my $test = shift;
	my $msg = shift;
	my $details = shift;

	if ($oe) {
		$msg =~ s/'/|'/g;
		$msg =~ s/\n/|n/g;
		$msg =~ s/\r/|r/g;

		$details =~ s/'/|'/g;
		$details =~ s/\n/|n/g;
		$details =~ s/\r/|r/g;

		$details = $msg if ($details eq '');

		print "##teamcity[testFailed name='$test' message='$msg' details='$details']\n";
	}
}


###############################################################
# Name: tcTestIgnored
#
# Print a testIgnored message
#
# Arguments: 	test		test name
#		msg		message to print
#
###############################################################
sub tcTestIgnored {
	my $test = shift;
	my $msg = shift;

	if ($oe) {
		$msg =~ s/'/|'/g;
		$msg =~ s/\n/|n/g;
		$msg =~ s/\r/|r/g;

		print "##teamcity[testIgnored name='$test' message='$msg']\n";
	}
}


###############################################################
# Name: tcEnableOutput
#
# Enable the TeamCity output
#
###############################################################
sub tcEnableOutput {
	$oe = 1;
}


###############################################################
# Name: tcDisableOutput
#
# Disable the TeamCity output
#
###############################################################
sub tcDisableOutput {
	$oe = 0;
}

###############################################################
# Name: disableTeamCityOutput
#
# Check if TeamCity output is enabled
#
###############################################################
sub tcIsEnabled {
	return $oe;
}

###############################################################
# Name: tcRunMake
#
# Run a make file and process the output
#
###############################################################
sub tcRunMake {
	my $suite = shift;
	my $top = shift;
	my $base = shift;
	my $cmd = shift;

	$cmd = 'make' if (!defined($cmd));;

	$top = $suite . &tcGetTestSeparator . $top if (defined($suite) && ($suite ne ''));

	# Verify that the base dir exists
	die "Cannot find directory '$base'" if (! -d $base);

	# Fork the program to run make in one and process the output in the other
	if (open(FROM, "-|")) {
		&tcTestSuiteStarted($suite) if (defined($suite) && ($suite ne ''));
		&tcTestStarted($top);

		my $level = 0;
		my @components;
		my @paths;
		my $extraLevels = 0;
		my @extraLevels;
		my $seenError = 0;
		my $prevLines = '';
		my @prevLineArray;
		my $prevTest = $top;
		my @prevTests;

		# Process the output from the other thread
		while (<FROM>) {
			my $skipPrevLine = 0;

			chomp;

			# Print the line so that it appears in the output logs
			print "$_\n";

			# Don't bother processing this line further if it's blank
			next if /^$/;

			# Look to identify output from submakes
			if (/^make(\[(\d+)\])?: (.+)/) {
				my ($newlevel, $info) = ($2, $3);

				# Attempt to identify the type of message
				#
				# First -- entering/leaving a directory
				if ($info =~ /(\w+) directory `(.+)'/ ) {
					my ($dirn, $dir) = ($1, $2);

					# Strip out the NF_ROOT
					if ($dir =~ s/^$nf2_root//) {
						$dir =~ s/^\///;
					}

					# Attempt to strip out the path of previous components
					my $prevPath;
					if ($#paths >= 0) {
						$prevPath = $paths[$#paths] . '/';
					}
					else {
						$prevPath = '';
					}

					my $test = $dir;
					$test =~ s/^$prevPath//;
					$test = $prevTest . &tcGetTestSeparator . $test;

					# Work out if this is an enter or leave event
					if ($dirn eq 'Entering') {
						push @components, $test;
						push @prevTests, $prevTest;
						push @paths, $dir;
						push @prevLineArray, $prevLines;
						push @extraLevels, $extraLevels;

						$prevLines = '';
						$extraLevels = 0;
						$skipPrevLine = 1;

						$prevTest = $test;

						&tcTestStarted($test);
					}
					elsif ($dirn eq 'Leaving') {
						while ($extraLevels >= 0) {
							$test = pop @components;
							$prevTest = pop @prevTests;
							$prevLines = pop @prevLineArray;

							&tcTestFinished($test);

							$extraLevels--;
						}

						$extraLevels = pop @extraLevels;

						$skipPrevLine = 1;

						pop @paths;
					}

					# Record the level change
					$level = $newlevel;
				}
				# Identify Error messages
				elsif ($info =~ /\*\*\* \[([^\]]+)\] Error (\d+)/ ) {
					my ($comp, $val) = ($1, $2);
					my $test;
					if ($#components >= 0) {
						$test = $components[$#components];
					}
					else {
						$test = $top;
					}

					# Work out whether to display any details
					my $details = '';
					$details = $prevLines if (!$seenError);

					#print "##teamcity[testStdOut name='$testName' out='']\n";
					#print "##teamcity[testStdErr name='$testName' out='']\n";
					&tcTestFailed($test, "Failing component: $comp", $details);

					# Record that we've seen an error
					$seenError++;
				}
				# Identify "No rule to make" error messages
				elsif ($info =~ /\*\*\* No rule to make target `([^']+)', needed by `([^']+)'./ ) {
					my ($file, $target) = ($1, $2);
					my $test;
					if ($#components >= 0) {
						$test = $components[$#components];
					}
					else {
						$test = $top;
					}

					# Work out whether to display any details
					my $details = '';
					$details = $prevLines if (!$seenError);

					#print "##teamcity[testStdOut name='$testName' out='']\n";
					#print "##teamcity[testStdErr name='$testName' out='']\n";
					&tcTestFailed($test, "Missing '$file' needed to build '$target'", $details);

					# Record that we've seen an error
					$seenError++;
				}
				# Identify nothing to be done message
				elsif ($info =~ /^Nothing to be done/) {
				}
				# Unknown message
				else {
					print "---$_\n";
				}
			}
			# Look for special test start/finish messages
			elsif (/^\+\+\+testStarted:(.+)/) {
				my $test = $1;
				$test = $prevTest . &tcGetTestSeparator . $test;

				# Update the various arrays
				push @components, $test;
				push @prevTests, $prevTest;
				push @prevLineArray, $prevLines;

				# Record that we're processing an extra level
				$extraLevels++;

				$skipPrevLine = 1;
				$prevLines = '';

				$prevTest = $test;

				&tcTestStarted($test);
			}
			elsif (/^\+\+\+testFinished:(.+)/) {
				if ($extraLevels > 0) {
					my $test = pop @components;
					$prevTest = pop @prevTests;
					$prevLines = pop @prevLineArray;

					$extraLevels--;

					&tcTestFinished($test);
				}
				$skipPrevLine = 1;
			}

			# Identify calls to make (although I'm just going to ignore these)
			if (/make\s+-C\s+(\w+)/) {
			}

			# Record the previous line
			$prevLines .= "\n" if ($prevLines ne '' && !$skipPrevLine);
			$prevLines .= $_ if (!$skipPrevLine);
		}
		wait;

		# Record the child status and then close the handle to the child process
		my $childStatus = $?;
		my $errno = $!;
		close FROM;

		# Process any top-level extraLevels data
		while ($extraLevels > 0) {
			my $test = pop @components;
			my $prevLines = pop @prevLineArray;

			&tcTestFinished($test);

			$extraLevels--;
		}

		# Evaluate the child status
		if ($childStatus == -1) {
			print "failed to execute: $errno\n";
		}
		elsif ($childStatus & 127) {
			printf "child died with signal %d, %s coredump\n",
			    ($childStatus & 127),  ($childStatus & 128) ? 'with' : 'without';
		}
		else {
			printf "child exited with value %d\n", $childStatus >> 8;
		}
		&tcTestFinished($top);
		&tcTestSuiteFinished($suite) if (defined($suite) && ($suite ne ''));

		return ($childStatus >> 8) | ($childStatus != 0);
	}
	else {
		# This is the child thread that runs make
		# STDERR should be redirected to STDERR
		#
		# All output from this thread goes to the parent
		chdir $base;
		open STDERR, ">&STDOUT";
		exec ($cmd) || die "can't exec make: $!";
	}
}

###############################################################
# Name: tcRunProg
#
# Run a program -- hopefully the output of the program
# already contains TeamCity mark-up
#
###############################################################
sub tcRunProg {
	my $base = shift;
	my $cmd = shift;

	# Verify that the base dir exists
	die "Cannot find directory '$base'" if (! -d $base);

	# Fork the program to run make in one and process the output in the other
	if (open(FROM, "-|")) {
		while (<FROM>) {
			print "$_";
		}
		wait;

		# Record the child status and then close the handle to the child process
		my $childStatus = $?;
		my $errno = $!;
		close FROM;

		# Evaluate the child status
		if ($childStatus == -1) {
			print "failed to execute: $errno\n";
		}
		elsif ($childStatus & 127) {
			printf "child died with signal %d, %s coredump\n",
			    ($childStatus & 127),  ($childStatus & 128) ? 'with' : 'without';
		}
		else {
			printf "child exited with value %d\n", $childStatus >> 8;
		}

		return ($childStatus >> 8) | ($childStatus != 0);
	}
	else {
		# This is the child thread that runs make
		# STDERR should be redirected to STDERR
		#
		# All output from this thread goes to the parent
		chdir $base;
		open STDERR, ">&STDOUT";
		exec ($cmd) || die "can't exec '$cmd': $!";
	}
}

###############################################################
# Name: tcSetRoot
#
# Set the root directory
#
###############################################################
sub tcSetRoot {
	my $root = shift;

	$nf2_root = $root if (defined($root));
}

###############################################################
# Name: tcGetTestSeparator
#
# Get the test separator
#
###############################################################
sub tcGetTestSeparator {
	return $separator;
}

###############################################################
# Name: tcSetTestSeparator
#
# Set the test separator
#
###############################################################
sub tcSetTestSeparator {
	$separator = shift;
}

# Always end library in 1
1;
