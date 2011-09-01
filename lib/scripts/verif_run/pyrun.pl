#!/usr/bin/perl -w

#
# Common run script that runs simulations and processes the output
#
# $Id: run.pl 6040 2010-04-01 05:58:00Z grg $
#

use strict;
use NF::TeamCity;
use NF::Base;
use Getopt::Long;
use Cwd;
use File::Copy;
use File::Temp qw/ tempfile /;

# Local variables that should be overridden by the local config script
my %config = (
	'test_desc' => '',
	'test_num' => 1,
	'opts' => '',
	'extra_files' => '',
	'extra_checks' => '',
	'log' => 'my_sim.log',
	'finish' => '', #1000000,
);

# Configuration file
my $configFile = 'config.txt';

# Finish time file
my $finishFile = 'config.sim';

# Name of the script to create packets
my $makePkts = 'run.py'; # changed to accomodate new file naming

# Location of PCI simulation data file
my $pciSimDataFile = 'packet_data/pci_sim_data';

# Location of modelsim.ini file
my $modelsimIni = '../vsim_beh/modelsim.ini';

# Files to remove before running the simulation
my @rmFiles = ('PASS', 'FAIL', 'GUI');

# Work out the test name
my $dir = cwd;
$dir =~ s/^.*\///;
my $test = "sim.$dir";

# Check that the correct environment variables are set
check_NF2_vars_set();

# Test directory
$ENV{'NF_DESIGN_DIR'} =~ /.*\/([^\/]+)/;
my $testDir = $ENV{'NF_WORK_DIR'} . "/test/$1";

# Program to perform packet comparison
my $compare = $ENV{'NF_ROOT'} . '/bin/nf_compare.pl';



# Parse the command line arguments
my $sim = '';   	# Which simulator to use
my $dump = 0; 		# Dump the output
my $gui = 0;		# Run the GUI
my $ci = '';		# Continuous integration program
my $citest = '';	# Continuous integration test name

unless ( GetOptions ( "dump" => \$dump,
		      "gui" => \$gui,
		      "sim=s" => \$sim,
		      "ci=s" => \$ci,
		      "citest=s" => \$citest,
		     )
       ) { usage(); exit 1; }



# Verify that a simulator has been set
if ($sim eq '' || ($sim ne 'vsim' && $sim ne 'vcs' && $sim ne 'isim')) {
	print "Unkown simulator \"$sim\". Supported simulators: vcs vsim isim\n";
	exit 1;
}

# Verify that the continuous integration program is correct if set
if ($ci ne '' && $ci ne 'teamcity') {
	print "Unkown continuous integration \"$ci\". Supported CI programs: teamcity\n";
	exit 1;
}
if ($ci ne '' && $citest eq '') {
	print "The name of the test was not specified in 'citest'\n";
	exit 1;
}
tcDisableOutput if ($ci ne 'teamcity');
if ($ci eq 'teamcity') {
	$test = $citest . tcGetTestSeparator . $test;
}

# -------  Print a test started message  -------
# After this point CI messages should be printed
tcTestStarted($test);

my $good = 1;

# Verify that the verilog files have been compiled
$good &= &checkSimCompiled if $good;

# Read the configuration
$good &= &readConfig if $good;

# Attempt to run the actual test
if ($good) {
	print "--- Running test.\n";
	print "$config{'test_desc'}\n";
}

# Generate the packets
if ($good) {
	print "--- Generating packets...\n";

	# Run the script
	my $makePktsOut;
	$makePktsOut = `./$makePkts 2>&1`;
	print $makePktsOut;

	# Verify the return code
	if ($? != 0) {
		print "--- Test failed ($dir) - $makePkts broke!.\n";
		tcTestFailed($test, '$makePkts broke', $makePktsOut);
		$good = 0;
	}
}

# Create the finish time file
#
# Note: always run the simulation but only run it for 1 time step if
# things are not good since the reg_defines.h is generated from it
#$config{'finish'} = 1 if (!$good);
$good &= &createFinishFile if $good;

# Run the simulation (again, always try to run since
# the reg_defines.h file is generated from the output)
$good &= &runSim($good) if $good;

# Validate the output
$good &= &validateOutput if $good;

# Write a success/fail file and return an exit code as appropriate
tcTestFinished($test);
if ($gui) {
	system('touch GUI');
	exit 99;
}
elsif ($good) {
	system('touch PASS');
	exit 0;
}
else {
	system('touch FAIL');
	exit 1;
}

########################################

#########################################################
# usage
#   print usage information
sub usage {
  my $cmd = $0;
  $cmd =~ s/.*\///;
  print <<"HERE1";
NAME
   $cmd - Run a simulation. (Should be invoked by the nf21_run_test.pl command.)

SYNOPSIS
   $cmd
        [--sim <vsim|vcs|isim>]
	[--ci <teamcity>]
        [--gui]
        [--dump]

   $cmd --help  - show detailed help

HERE1

##  return unless ($help);
##  print < < "HERE";
##sub usage {

}


#########################################################
# readConfig
#   read the configuration file
sub readConfig {
	my $ok = 1;

	print "--- Reading configuration file\n";

	# Verify that the config file exists
	if (! -f $configFile) {
		# Open and read the configuration file
		if (open CONFIG, $configFile) {
			while (<CONFIG>) {
				chomp;

				# Remove comments
				s/#.*//;

				# Kill as much white space as possible at beginning
				s/^\s*//;

				# Skip blanks
				next if /^$/;

				# Work out the components
				/^(\w+)\s*=\s*((\S.*)?\S)?\s*/;
				my ($key, $val) = ($1, $2);
				$val = '' if (!defined($val));

				# Set the value in the hash
				$config{$key} = $val;

				print "Seen: $key => $val\n";
			}
			close CONFIG;
		}
	}

	# Verify that all necessary variables have been set
	foreach my $key (keys %config) {
		if (!defined($config{$key})) {
			&printError("'$key' not defined in configuration file");
			$ok = 0;
		}
	}

	return $ok;
}


#########################################################
# validateOutput
#   validate the output of the tests
sub validateOutput {
	if (!$gui) {
		print "--- Simulation is complete. Validating the output.\n";

		# Check the log for errors
		my @logErrors = `grep -i error $config{'log'} | grep -v -i ERROR_DETECT`;
		my $barrier;
		foreach(@logErrors) {
			print "$_";
			if($_ =~ /data (.*) but expected (.*) \(/) {
				if(hex($2)-hex($1) eq 1) {
					# grep goes back 10 lines; max observed in both_wrong_destMAC was 5 to be safe
					my $barrier = `grep -B 10 "$_" -- $config{'log'} | grep -i -c barrier`;
					if($barrier > 0) {
						print "WARNING: Register read expected and seen differed by 1 after a barrier\n";
						print "Register reads are not always delayed appropriately by a barrier, try adding a delay\n\n";
					}
				}
			}
		}
		if ($#logErrors + 1 != 0) {
			print "--- Test failed ($dir) - see $config{'log'} for errors.\n";
			tcTestFailed($test, 'Errors seen in simulation output', @logErrors);
			return 0;
		}

		# Check that the correct number of reads were done
		#
		# The number of expected reads is equal to the explict reads
		# (ie. reads explicitly listed in the PCI Sim Data file) plus
		# the automatic reads performed when interrupts are signalled.
		my $explicitReads = `grep -c READ: $pciSimDataFile`;
		my $actualReads = `grep -c 'Host read.*cmd 0x6:.*Disconnect with Data' $config{'log'}`;
		my $intStatusReads = `grep -c 'Info: Interrupt signaled' $config{'log'}`;
		my $iDMADoneInt = `grep -c 'Info: DMA ingress transfer complete.' $config{'log'}`;
		my $eDMADoneInt = `grep -c 'Info: DMA egress transfer complete.' $config{'log'}`;
		my $phyInt = `grep -c 'Seen Phy Interrupt.' $config{'log'}`;
		my $dmaQStatusInt = `grep -c 'CPCI Interrupt:.*DMA queue status change' $config{'log'}`;
		my $pktAvailInt = `grep -c 'Packet available. Starting' $config{'log'}`;
		my $cnetRdTimeoutInt = `grep -c 'Seen CNET Read' $config{'log'}`;
		my $dmaStarts = `grep -c 'Info: Starting DMA transfer' $config{'log'}`;
		my $expectedReads = $explicitReads +
			$intStatusReads +
			$iDMADoneInt * 3 +
			$eDMADoneInt * 1 +
			$phyInt * 1 +
			$dmaQStatusInt * 1 +
			$pktAvailInt * 1 +
			$cnetRdTimeoutInt * 0 +
			$dmaStarts * 1;
		if ($expectedReads != $actualReads) {
			print "--- Test failed ($dir) - incorrect number of reads seen. (Saw: $actualReads   Expected: $expectedReads)\n";
			tcTestFailed($test, 'Incorrect number of reads seen in simulation', @logErrors);
			return 0;
		}


		# Run any additional tests on the output
		if ($config{'extra_checks'} ne '') {
			my $logErrors = `$config{'extra_checks'} --log $config{'log'}`;
			print $logErrors;

			if ($?) {
				print "--- Test failed ($dir) - see $config{'log'} for errors.\n";
				tcTestFailed($test, 'Errors seen in simulation output', $logErrors);
				return 0;
			}
		}


		# Compare the simulation output with the expected output
		my $compareOutput = `$compare`;
		print $compareOutput;
		if ($?) {
			print "--- Test failed ($dir) - expected and seen data differs.\n";
			tcTestFailed($test, 'Expected and seen data differs', $compareOutput);
			return 0;
		}

		print "--- Test PASSED ($dir) \n";
		unlink('test.dump');
	}
	else {
		print "--- Simulation is complete. Cannot evaluate correctness due to GUI mode.\n";
	}

	return 1;
}


#########################################################
# runSim
#   run the simulation
sub runSim {
	my $good = shift;

	return $good if !$good;

	my $ok = 1;

	print "--- Running the simulation (takes a while). Logging to $config{'log'}\n";
	unlink($config{'log'}, @rmFiles);

	if ($sim eq 'isim') {
		print "--- Running nf2_top_isim\n";

		my $cwd = getcwd();

		# Create a temporary file with the run command
		my ($fh, $fname) = tempfile();
		print $fh "cd $cwd\n";
		print $fh "run all\n";
		close $fh;

		if (system("cd $testDir && $testDir/nf2_top_isim -tclbatch $fname | tee $dir/$config{'log'}") != 0) {
			if ($good) {
				print "--- Test Failed.\n";
				tcTestFailed($test, 'Error when running simulator', '');
			}
			$ok = 0;
		}

		# Remove the temporary file
		unlink($fname);
	}
	elsif ($sim eq 'vcs') {
		print "--- Running my_sim\n";

		if (system("$testDir/my_sim > $config{'log'} 2>&1") != 0) {
			if ($good) {
				print "--- Test Failed.\n";
				tcTestFailed($test, 'Error when running simulator', '');
			}
			$ok = 0;
		}
	}
	elsif ($sim eq 'vsim') {
		print "--- Running vsim\n";

		# Work out if there are any extra files to process
		if ($dump) {
			$config{'extra_files'} .= ' dump';
		}

		# Check if we should invoke the gui
		my $cmd;
		if ($gui) {
			$config{'opts'} .= "";
			$cmd = 'view object; view wave;';
		}
		else {
			# default finish time is 1000000ns.
			# the config.txt overrides the finish time.
			$config{'opts'} .= " -c -l $config{'log'}";
			$cmd = "run -all";
		}

		# Check if we need to disable the DRAM debug information
		if (defined($ENV{'NF2_NO_DRAM_DEBUG'})) {
			$config{'opts'} .= " -g/testbench/u_board/dram1/DEBUG=0 -g/testbench/u_board/dram2/DEBUG=0";
		}

		# Set the modelsim environment variable if the modelsim.ini file exists
		if (-f $modelsimIni) {
			$ENV{'MODELSIM'} = $modelsimIni;
		}

		if (system("vsim $config{'opts'} -voptargs=\"+acc\" testbench glbl $config{'extra_files'} -do \"${cmd}\"") != 0) {
			if ($good) {
				print "--- Test Failed.\n";
				tcTestFailed($test, 'Error when running simulator', '');
			}
			$ok = 0;
		}
	}

	return $ok;
}


#########################################################
# checkSimCompiled
#   check that the simulator has been compiled
sub checkSimCompiled {
	if ($sim eq 'isim') {
		if ( ! -x "$testDir/nf2_top_isim" ) {

			&printError("Cannot find executable nf2_top_isim at $testDir");
			return 0;
		}
	}
	elsif ($sim eq 'vcs') {
		if ( ! -x "$testDir/my_sim" ) {

			&printError("Cannot find executable my_sim at $testDir");
			return 0;
		}
	}
	else {
		if ( ! -d "${testDir}/vsim_beh" ) {
			&printError("Cannot find directory vsim_beh at $testDir");
			return 0;
		}
	}

	# Everything is good
	return 1;
}


#########################################################
# printError
#   prints an error including through all of the defined CIs
sub printError {
	my $err = shift;

	warn "Error: $err\n";
	tcTestFailed($test, $err, '');
}


#########################################################
# createFinishFile
#   create the file that instructs the simulator when to finish
sub createFinishFile {
	if ( $config{'finish'} ne '' ) {
		if (open FINISH, ">$finishFile") {
			print FINISH "FINISH=$config{'finish'}\n";
			close FINISH;
		}
		else {
			&printError("Unable to open finish time file '$finishFile' for writing");
			return 0;
		}
	}
	return 1;
}
