#!/usr/bin/perl -w
#/usr/pubsw/bin/perl -w
# vim:set shiftwidth=2 softtabstop=2 expandtab:

#################################################################
# Script to launch the simulator to run a test
#
# $Id: nf_run_test.pl 6046 2010-04-01 06:07:04Z grg $
#
# Includes support for TeamCity continuous integration
#  - assumes that a test has been started at the level above
#################################################################

use Getopt::Long;
use File::Copy;
use File::Path;
use NF::Base;
use NF::TeamCity;
use strict;
$|++;

# check vars are set.
check_NF2_vars_set();

my $_NF_ROOT       = getNF2RootDir();
my $_NF_DESIGN_DIR = getNF2ProjDir();
my $_NF_WORK_DIR   = getNF2WorkDir();

#
# Set defaults
#
my $work_verif_dir = $_NF_WORK_DIR.'/verif'; # where sim binary is put
my $empty_test_dir = $_NF_ROOT."/lib/scripts/test_generic_empty/";

#
# Process arguments
#

my $major = '.*';   # major indentifier for tests (regexp)
my $minor = '.*';   # minor identifier for tests (regexp)
my $make_opt = '';  # Options to be passed to make
my $make_file = $_NF_ROOT.'/lib/Makefiles/legacy_sim_makefile';
my $src_verif_dir = $_NF_DESIGN_DIR.'/verif';
my $c_common_dir = $_NF_ROOT.'/lib/C/common';
my $perl_common_dir = $_NF_ROOT.'/lib/Perl5';
my $proj_c_common_dir = $_NF_DESIGN_DIR.'/lib/C';
my $proj_perl_common_dir = $_NF_DESIGN_DIR.'/lib/Perl5';
my $no_compile = '';
my $compile_only = '';
my $run = 'run';    # name of the run script to use
my $global_run = $_NF_ROOT.'/lib/scripts/verif_run/run.pl';  # Global run script if no local run
my $help = '';
my $dump = 0;
my $gui = 0;
my $isim = '';      # Use Xilinx's ISIM if flag is set
my $vcs = '';       # if present, Synopsys's vcs instead of Mentor's vsim will run
my $sim_opt = ''; #  command line option to be passed to HDL simulator
my $ci = '';
my $citest = '';

unless ( GetOptions ( "major=s" => \$major,
		      "minor=s" => \$minor,
		      "work_verif_dir=s" => \$work_verif_dir,
		      "make_opt=s" => \$make_opt,
		      "make_file=s" => \$make_file,
		      "src_verif_dir=s" => \$src_verif_dir,
		      "no_compile" => \$no_compile,
		      "compile_only" => \$compile_only,
		      "run=s" => \$run,
		      "dump" => \$dump,
		      "gui" => \$gui,
		      "help" => \$help,
		      "vcs" => \$vcs,
		      "isim" => \$isim,
		      "sim_opt=s" => \$sim_opt,
		      "ci=s" => \$ci,
		      "citest=s" => \$citest,
		     )
	 and ($help eq '')
       ) { usage(); exit 1 }


#
# Check stuff
#


# Verify that the continuous integration program is correct if set
if ($ci ne '' && $ci ne 'teamcity') {
  my_die ("Unkown continuous integration \"$ci\". Supported CI programs: teamcity", 0);
}
if ($ci ne '' && $citest eq '') {
  my_die ("The name of the test was not specified in 'citest'", 0);
}
tcDisableOutput if ($ci ne 'teamcity');

# Construct the project verif dir
$_NF_DESIGN_DIR =~ /.*\/([^\/]+)/;
my $project = $1;
my $proj_verif_dir = $work_verif_dir . "/$project";

# verif_dir exists (if not then make it)
unless ( -d $proj_verif_dir ) {
  unless ( mkpath $proj_verif_dir, { verbose => 1}) {
    my_die ("Unable to create simulation directory $proj_verif_dir")
  }
}

unless ( -w $proj_verif_dir ) {
  my_die ("Unable to write to simulation directory $proj_verif_dir")
}

# check Makefile is present
unless ( -r $make_file ) {
  my_die("Unable to read make file $make_file.");
}

copy("$make_file", "$proj_verif_dir/Makefile") or
  my_die("Error: cannot copy makefile to $proj_verif_dir/Makefile");

print "=== Work directory is $proj_verif_dir.\n";


#
# OK, do the compile
#

my $cmd;
my $status;

unless ($no_compile) {

  my $dumpfile = $dump ? 'dump.v' : '';

  if ($isim) {
    $make_opt = $make_opt . " isim_top"
  }
  elsif ($vcs) {
    $make_opt = $make_opt . " vcs_top"
  } else {
    $make_opt = $make_opt . " vsim_top"
  }

  $cmd = "cd $proj_verif_dir; rm -rf my_sim; make -f Makefile DUMP_CTRL=$dumpfile SIM_OPT=$sim_opt $make_opt";

  print "=== Calling make to build simulation binary with\n$cmd\n";

  # Invoke make through the appropriate ci program
  if (tcIsEnabled) {
    if (tcRunMake('', $citest . tcGetTestSeparator() . 'make', '.', $cmd) != 0) {
      exit 1;
    }
  }
  else {
    $status = system($cmd);
    my_die("Error: $!") if ($status > 255);
  }

  print "=== Simulation compiled.\n";
}

exit 0 if ($compile_only) ;

#
# Now set up the test directories where we will actually run the tests.
#

my @src_test_dirs = ();

if ($#ARGV >= 0) {  # If we have a filename then it should list the tests to run

  while(<>) {
    chomp;
    if (/\S+/) {
      push @src_test_dirs, $_;
    }
  }
}

else {

  # create regexp string we want to match against
  my $test_name = 'test_'.$major.'_'.$minor;

  for my $td (`ls -1 $src_verif_dir`) {
    chomp $td;
    $td =~ s/.*\///;  # remove leading directory info
    if ($td =~ m/$test_name/) {
      push @src_test_dirs, $td;
    }
  }
}

my @pass = ();
my @fail = ();
my @gui = ();

if (@src_test_dirs == 0) {
  print "=== Error: No tests match regexp test_${major}_${minor} - exiting.\n";
}
elsif ($gui && scalar(@src_test_dirs) != 1) {
  print "=== Error: GUI mode specified but more than one test matches the set of tests to run.\n";
  print "           Restrict the set of tests with the --major and --minor flags.\n\n";
  print "           Matching set of tests:\n";
  my $str = '              ';
  for (@src_test_dirs) {
    $str .= $_.' ';
    if (length($str) > 50) { print "$str\n"; $str = '              '; }
  }
  if ($str){ print "$str\n" }
}
else {
  print "=== Will run the following tests:\n";
  my $str ='';
  for (@src_test_dirs) {
    $str .= $_.' ';
    if (length($str) > 50) { print "$str\n"; $str = ''; }
  }
  if ($str){ print "$str\n" }

  # Remove the failed tests file
  unlink($_NF_DESIGN_DIR."/FAILED_TESTS");

  for my $td (@src_test_dirs) {
    my $src_dir = $src_verif_dir.'/'.$td;
    my $dst_dir = $proj_verif_dir.'/'.$td;


    # check source executable

    unless ( -x "${src_dir}/$run" || -x "$global_run") {
      print("=== Warning: Ignoring test $td - did not find executable \"$run\" or \"$global_run\" \n");
      next;
    }

    # check dest dir is there else build it
    print "\n\n=== Setting up simulation in $dst_dir...\n";

    unless ( -d $dst_dir ) {
      unless ( mkdir $dst_dir ) {
	my_die ("Error: Unable to create simulation directory $dst_dir")
      }
    }
    unless ( -w $dst_dir ) {
      my_die ("Error: Unable to write to simulation directory $dst_dir")
    }

    # copy files to destination directory

    print "=== Copying files to test directory $dst_dir.\n";
    $cmd = "cp -r -p $src_dir".'/* '."$dst_dir";
    $status = system($cmd);


    my $which_run;
    if (-x "${dst_dir}/$run") {
	    $which_run = "./$run";
    }
    else {
	    $which_run = $global_run;
    }

    if ($isim) {
	$cmd = "cd $dst_dir; $which_run --sim isim";
    }
    elsif ($vcs) {
	$cmd = "cd $dst_dir; $which_run --sim vcs";
    }
    else {
	$cmd = "cd $dst_dir; $which_run --sim vsim";
    }
    # Add optional dump keyword to the run file.
    if ($dump) { $cmd .= ' --dump' }

    # Add optional gui keyword to the run file.
    if ($gui) { $cmd .= ' --gui' }

    # Add optional ci keyword and parameter
    if ($ci ne '') { $cmd .= " --ci $ci --citest '$citest'" }

    print "=== Running test $dst_dir/$td ...\n";
    $status = system($cmd);
    if ($status > 255) { # test failed or ran in GUI mode
      $status >>= 8;
      if ($status == 99) {
        print "Test $td ran in GUI mode. Unable to identify pass/failure\n";
        push @gui, $td;
      }
      else {
        print "Error: test $td failed!\n";
        push @fail, $td;
      }
    }
    else {
      print "Test $td passed!\n";
      push @pass, $td;
    }

  }

  # Print out a summary
  my $summary;
  $summary = "------------SUMMARY---------------\n";

  $summary .= "PASSING TESTS: \n";
  if (scalar(@pass) != 0) {
    for (@pass) { $summary .= "\t\t$_\n" }
  } else {
    $summary .= "\t\tNone\n";
  }

  $summary .= "FAILING TESTS: \n";
  if (scalar(@fail) != 0) {
    for (@fail) { $summary .= "\t\t$_\n" }
  } else {
    $summary .= "\t\tNone\n";
  }

  if (scalar(@gui) != 0) {
    $summary .= "GUI TESTS: \n";
  } else {
    $summary .= "\t\tNone\n";
  }
  for (@gui) { $summary .= "\t\t$_\n" }

  $summary .= "TOTAL: " . scalar(@src_test_dirs) . "   PASS: " . scalar(@pass) .
    "   FAIL: " . scalar(@fail) . "   GUI: " . scalar(@gui) . "\n";

  print $summary;
  if ($#fail >= 0) {
    tcTestFailed($citest, 'One or more simulations failed', $summary)
  }

  if (scalar(@fail)) { # one or more failures - save them to file
    open(F,'>'.$_NF_DESIGN_DIR."/FAILED_TESTS") or my_die ("Cannot write list of failed tests to FAILED_TESTS");
    for (@fail) { print F "$_\n"; }
    close F;
  }
}

# Exit with a non-zero exit code if there were any failing tests
exit (scalar(@fail) > 0);


#########################################################
sub usage {
  (my $cmd = $0) =~ s/.*\///;
  print <<"HERE1";
NAME
   $cmd - compile the source verilog and then run a number of tests.

SYNOPSIS
   $cmd [--major <string>] [--minor <string>]
        [--work_verif_dir <dir>] [src_verif_dir <dir>]
        [--make_opt <string>] [--make_file <file>]
        [--no_compile] [--compile_only]
        [--run <run_script>]
        [--dump]
        [--gui]
        [--vcs]
        [--isim]
        [--sim_opt <string>]
        [--ci <test_tool>]
        [--citest <test name>]
        [<file of tests>]

   $cmd --help  - show detailed help

HERE1

  return unless ($help);
  print <<"HERE";

DESCRIPTION

   This script compiles the top level simulation and puts the
   compiled binary, called my_sim, in a specified directory. It then
   looks at all test directories that match in major and minor
   specifications. For each matching test directory that contains an
   executable script called 'run' it copies the contents of the
   source test directory to a work directory and runs that test.
   If no 'run' script is found, it uses a default script. In most cases
   this is what is needed and what should be used.

   If you specify a filename then that file should contain a list
   of tests that you want to run. In this case the --major and --minor
   options are ignored. The tests in the file should be only the name
   of the test (without preceding directory information).

   The source verification directory is assumed to contain a directory
   for each test. The name of each test directory is of the form
   test_<major>_<minor> e.g. test_OQM_simple.

   The run script will be invoked with 1 or more: the first argument
   is always the simulator to be used: 'vcs' if Synopsys VCS is used,
   or 'vsim' if Mentor ModelSim is used.
   Additional arguments are:
     'dump' if the --dump option is used
     'gui' if the --gui option is used

   The run script should return 0 for success and non-zero for failure.

   Upon completion the script will put the failing tests into a file
   called FAILED_TESTS (if there are any) placed in the \$NF_DESIGN_DIR/verif
   directory. This FAILED_TESTS file can be fed back into the command later
   to re-run just those failed tests. To do this just give then name
   FAILED_TESTS as the last argument to the $cmd command.

OPTIONS
   --major <string>
     Specify the string to match on the first part of the test
     directory name. This is a perl regular expression.
     Default is to match all major tests.

   --minor <string>
     Specify the string to match on the last part of the test
     directory name. This is a perl regular expression.
     Default is to match all minor tests

   --work_verif_dir <dir>
     Specify the directory where the compiled binary should be placed.
     Each test will have its own directory created beneath this directory.
     Default is \$NF_WORK_DIR/verif.

   --src_verif_dir <dir>
     Specify the directory where the test dirctories are located.
     Each directory should be named test_<major>_<minor> and should contain
     an executable script called 'run' that will perform the actual
     simulation and check the results if necessary.
     Default is \$NF_DESIGN_DIR/verif.

   --make_file <makefile>
     Specify the makefile to be used to compile the simulation binary.
     By default this is $_NF_ROOT/lib/Makefiles/sim_makefile

   --make_opt <option_string>
     Specify a single string to be passed to make (e.g. to invoke a different
     make rule).
     Make is invoked by $cmd using: 'make -f <makefile> <option_string>'

   --no_compile
     Specify this if you dont want make to be invoked, but rather just go
     to running the tests. (e.g. you have changed a test but not any verilog)

   --compile_only
     Specify this if you dont want to run any tests, but do want to perform the
     compilation of the verilog simulation.

   --run <run_script>
     The default name for the run script is 'run'. Use this option if you
     want to use a different name for your script.

   --dump
     Normally the simulation will not produce a VCD file. If you want a
     VCD file then place a file 'dump.v' in your src directory and specify
     this option. Then dump.v will be compiled as a top level module.
     dump.v should be something like this:


      module dump;

      initial
      begin
         #0
            \$dumpfile("testdump.vcd");
            //
            //\$dumpvars;
            \$dumpvars(4,testbench.u_board.unet_top);
            \$dumpon;
            \$display(\$time, " VCD dumping turned on.");

          #4000000 \$finish;

      end

      endmodule

   --gui
     This will run the simulator in an interactive mode (usually with a GUI).

   --vcs
     If this option is present, vcs will run. Otherwise vsim will run.

   --isim
     If this option is present, ISIM will run. Otherwise vsim will run.

   --sim_opt <string>
     This option allows the string to be passed to the HDL simulator.
     For example, a macro definition which is checked by the HDL testbench,
     a post-processing option, or a simulation delay model option.

   --ci <test_tool>
     For use when using a continuous integration tool. Instructs the system to
     print out extra debugging information used by the CI tool.
     Currently recognized tools: teamcity

   --citest <test_name>
     The name of the top-level test to print in error messages when using
     the 'ci' option.

ENVIRONMENT

  The standard NetFPGA2 variables should be set:

  \$NF_ROOT       - where the root of the NetFPGA2 tree is located
  \$NF_DESIGN_DIR - where your project is (with your source
                     files, tests etc)
  \$NF_WORK_DIR   - a working directory (preferably local disk for speed);


EXAMPLE

   Assume that under \$NF_DESIGN_DIR/verif are three test directories:

   test_a_1
   test_a_2
   test_b_1

   % $cmd

   will first compile the simulation binary (my_sim) and place it in
   \$NF_WORK_DIR/project_name/verif.

   It will then create subdirectories test_a_1, test_a_2 and
   test_b_1 under test_dir.

   For each of these new directories it will copy all files and
   directories from the source test to the new directory. It will
   then cd to the new directory and call the local run script.

   So, for test_a_1 it will:
   1. create the directory \$NF_WORK_DIR/project_name/test_dir/test_a_1
   2. copy all files and directories from the verif/test_a_1 directory
   3. cd to \$NF_WORK_DIR/project_name/test_dir/test_a_1
   4. run the script \$NF_WORK_DIR/project_name/test_dir/test_a_1/run.

   Assuming tests test_a_2 and test_b_1 failed then they would be
   written to the file FAILED_TESTS. You could then re-run just those
   tests (once you have fixed the problem) by:

   $cmd FAILED_TESTS


SECOND EXAMPLE

   If instead the command was

   % $cmd --major a

   then only the tests test_a_1 and test_a_2 would be run.

   A sample run script is shown below:
HERE

  print <<'HERE2';


#!/bin/bash

# This runs the test in this directory.
# Arguments to this script might be:
# 'vsim' or 'vcs' - to specify which simulator to use.
# 'dump' if VCD dumping is to be on.

# Process arguments.

sim='vcs'
dump=''

for arg in "$@"; do
   case $arg in
      vsim ) sim='vsim' ;;
      vcs )  sim='vcs' ;;
      dump ) dump='dump' ;;
      * ) echo "Unknown argument $arg passed to run script - exiting";
         exit 1 ;;
   esac
done

# Check that we have compiled  binary 'my_sim' in verif work dir.

testDir=${NF_WORK_DIR}/verif

if [ $sim = "vcs" ]
then
   if [ ! -x ${testDir}/my_sim  ]
   then
      echo "Cannot find executable my_sim at $testDir"
      exit 1
   fi
else
   if [ ! -x ${testDir}/vsim_beh ]
     then
       echo "Cannot find directory vsim_beh at $testDir"
       exit 1
   fi
fi


testDesc="Check different cases for the OQM (Queue Manager)."

echo "--- Running test."
echo $testDesc

echo "--- Generating packets..."
if ! perl make_pkts.pl
then
        echo "--- Test $testNum Failed - make_pkts broke!."
        touch FAIL
        exit 1
fi


if [ ! -r config.txt ]
then
   echo "Didn't find a config.txt file to specify finish time!!!"
else
   echo "--- Finish time specified in config.txt:"
   cat config.txt
fi

log="my_sim.log"

echo "--- Running the simulation (takes a while). Logging to ${log}"
rm -f $log PASS FAIL 2> /dev/null

if [ $sim = "vcs" ]
then
   echo "--- Running my_sim"

   if ! ${testDir}/my_sim > $log 2>&1
   then
        echo "--- Test Failed."
        touch FAIL
        exit 1
   fi
else
   echo "--- Running vsim"
   cp ../vsim_beh/modelsim.ini .

# default finish time is 1000000ns.
# the config.txt overrides the finish time.
   vsim -c -l ${log} +define+VSIM_COMPILE testbench glbl ${dump} -do "run  1000000ns"
fi


echo "--- Simulation is complete. Validating the output."

if grep -i error $log
then
   echo "--- Test failed - see $log for errors."
   touch FAIL
   exit 1
fi


if ! nf_compare.pl
then
        echo "--- Test Failed."
        touch FAIL
        exit 1
fi

echo "--- Test $testNum PASSED"
rm -f test.dump 2> /dev/null
touch PASS
exit 0

HERE2
}

#########################################################
sub my_die {
  my $mess = shift @_;
  my $details = shift @_;
  my $enableTC = shift @_;

  $details = '' if (!defined($details));
  $enableTC = 1 if (!defined($enableTC));

  (my $cmd = $0) =~ s/.*\///;
  print STDERR "\n$cmd: $mess\n";
  tcTestFailed($citest, $mess, $details);
  exit 1;
}
