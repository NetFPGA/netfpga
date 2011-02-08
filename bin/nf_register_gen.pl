#!/usr/bin/perl -w
# vim:set shiftwidth=2 softtabstop=2 expandtab:

#################################################################
# Process the NetFPGA registers for a project
#
# $Id: nf_register_gen.pl 6046 2010-04-01 06:07:04Z grg $
#
#################################################################

use NF::Base;
use XML::Simple;
use File::Basename;
use Getopt::Long;
use Carp;
use Switch;
use bignum;
use Math::BigInt;
use NF::RegSystem::XMLProcess;
use NF::RegSystem::VerilogOutput;
use NF::RegSystem::LibModulesOutput;
use NF::RegSystem::COutput;
use NF::RegSystem::PerlOutput;
use NF::RegSystem::PythonOutput;

use strict;

# Valid output targets
#
# Key is the target name, value indicates whether to generate the output by default
my %validTargets = (
  'lib_modules' => 0,
  'verilog'     => 1,
  'c'           => 1,
  'perl'        => 1,
  'python'      => 1,
);

my $help = '';
my $projectName;
my @output;
my $listModules;
my $listShared;
my $simpleError;

# Identify which project we are processing
parseCmdLine();

if ($listModules) {
  my $modulePaths = getModulesXMLProject($projectName, $simpleError, $listShared);

  for my $module (@$modulePaths) {
    print "$module\n";
  }
  exit 0;
}

# Read and process the XML files
my ($project, $layout, $modulePaths, $usedModules, $constsHash, $constsArr, $typesHash, $typesArr) =
      processXMLProject($projectName);

# Perform the layout
$layout->doAlloc();

# Produce the output files
for my $output (@output) {
  switch ($output) {
    case 'lib_modules'
    {
      genLibModulesOutput($projectName, $modulePaths);
    }
    case 'verilog'
    {
      genVerilogOutput($project, $layout,
        $usedModules, $constsHash, $constsArr, $typesHash, $typesArr);
    }
    case 'c'
    {
      genCOutput($project, $layout, $usedModules,
        $constsHash, $constsArr, $typesHash, $typesArr);
    }
    case 'perl'
    {
      genPerlOutput($project, $layout, $usedModules,
        $constsHash, $constsArr, $typesHash, $typesArr);
    }
    case 'python'
    {
      genPythonOutput($project, $layout, $usedModules,
        $constsHash, $constsArr, $typesHash, $typesArr);
    }
  }
}

exit 0;

############################################################

#
# parseCmdLine
#   Parse command line arguments
#
sub parseCmdLine {
  my ( $int_handler, @ARGV ) = @_;

  #
  # Process arguments
  #
  unless (
    GetOptions(
        "help"          => \$help,
        "project=s"     => \$projectName,
        "output=s"      => \@output,
        "list-modules"  => \$listModules,
        "list-shared"   => \$listShared,
        "simple-error"  => \$simpleError,
    )
    and ( $help eq '' )
    )
  {
    usage();
    exit 1;
  }

  $projectName = getNF2Project();
  if ($projectName eq '') {
    print "ERROR: Project name not specified\n\n";
    usage();
    exit 1;
  }

  if ($listShared && !$listModules) {
    $listModules = 1;
  }

  if ($simpleError && !$listModules) {
    print "ERROR: '--simple-error' can only be specified in conjunction with '--list-modules' or '--list-modules-and-includes'\n\n";
    usage();
    exit 1;
  }

  # Process the output array
  validateOutputTargets();
}

#
# usage
#   Print usage information
#
sub usage {
  ( my $cmd = $0 ) =~ s/.*\///;

  print <<"HERE1";
NAME
   $cmd - run regression tests

SYNOPSIS

   $cmd
        [--project <project>]
        [--output <target>] [--output <target>] ...
        [--list-modules] [--list-shared]
        [--simple-error]

   $cmd --help  - show detailed help

HERE1

	return unless ($help);
	print <<"HERE";

DESCRIPTION

   This script processes the XML register definitions for a project and
   produces one or more output files. The output files currently supported are:
     - lib_modules.txt
     - Verilog defines
     - C include file
     - Perl module
     - Python module

OPTIONS

   --project <project> ...
     Process the specified project

   --output <target> ...
     Produce the output for the specified target(s)

     Currently supported targets are:
        lib_modules   -- lib_modules.txt file
        verilog       -- Verilog defines
        c             -- C header file
        perl          -- Perl module
        python        -- Python module

   --list-modules
     Don't produce any output -- just list the modules. Used by the makefiles
     to work out which modules to include.

   --list-shared
     List modules containing shared files as well as the modules used in the project.
     Used by the package building scripts to work out which modules to include.

   --simple-error
     Print the word "ERROR" if an error is encountered. This can *only* be used
     in conjunction with --list-modules

HERE

}

#
# validateOutputTargets
#   Validate the output targets
#
sub validateOutputTargets {
  my $output = join(',', @output);
  $output =~ s/\s+//g;
  $output = lc($output);
  @output = split(',', $output);

  for $output (@output) {
    if (!defined($validTargets{$output})) {
      die "ERROR: Unknown output target '$output'\n";
    }
  }

  if (scalar(@output) == 0) {
    while (my ($target, $default) = each(%validTargets)) {
      push @output, $target if ($default);
    }
  }
}
