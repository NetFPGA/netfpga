#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: Base.pm 6067 2010-04-01 22:36:26Z grg $
#
# Module provides basic functions for use by NetFPGA Perl scripts.
#
# Revisions:
#
##############################################################

use Test::Base;

package NF::Base;
use Exporter;
@ISA = ('Exporter');
@EXPORT = qw(
              &check_NF2_vars_set
              &getNF2Project
              &getNF2RootDir
              &getNF2ProjDir
              &getNF2WorkDir
              &isQuiet
            );

use Carp;
use strict;
use Cwd;
use Getopt::Long;
use File::Spec;
use File::Path;
use File::Basename;

use constant {
  PROJECT_DIR   => 'projects',
};

my $rootDir;
my $projDir;
my $project;
my @projects;
my $projRoot;
my $workDir;
my $quiet;


#
# printEnv
#   Print the active environment identified by the script
#
sub printEnv {
  if (!defined($quiet)) {
    print "\n";
    print "NetFPGA environment:\n";
    print "  Root dir:       $rootDir\n";
    print "  Project name:   $project\n";
    print "  Project dir:    $projDir\n";
    print "  Work dir:       $workDir\n";
    print "\n";
  }
}


#
# identifyRoot
#   Identify the root
#
sub identifyRoot {
  # Verify that NF_ROOT has been set and exists
  croak "Please set the environment variable 'NF_ROOT' to point to the local NetFPGA source"
    unless (defined($ENV{'NF_ROOT'}));

  $rootDir = File::Spec->canonpath($ENV{'NF_ROOT'});
  $projRoot = $rootDir . '/' . PROJECT_DIR;

  if (! -d $rootDir) {
    croak "NetFPGA directory '$rootDir' as referenced by environment variable 'NF_ROOT' does not exist";
  }

  # Set the environment variable for this process (and subprocesses)
  $ENV{'NF_ROOT'} = $rootDir;
}


#
# identifyProject
#   Identify the project
#
sub identifyProject {
  if (scalar(@projects)) {
    $projDir = $rootDir . '/' . PROJECT_DIR . '/' . $projects[0];
    $project = $projects[0];
  }
  else {
    if (defined($ENV{'NF_DESIGN_DIR'})) {
      $projDir = File::Spec->canonpath($ENV{'NF_DESIGN_DIR'});
      $project = basename($projDir);
    }
    else {
      # Attempt to guess the project based on the current directory
      my $currDir = getcwd();

      if ($currDir =~ /^$projRoot\//) {
        $currDir =~ s/$projRoot\///;
        $currDir =~ s/\/.*//;

        $project = $currDir;
        $projDir = $rootDir . '/' . PROJECT_DIR . '/' . $project;
      }
      else {
        croak "Unable to identify the project. Specify a project with one of:\n" .
              "  specify --project <proj_name> on the command line\n" .
              "  set the environment variable 'NF_DESIGN_DIR, or,\n" .
              "  run this script from within the project directory\n" .
              "Exiting";
      }
    }
  }

  # Verify that the project exists
  if (! -d $projDir) {
    croak "Cannot locate project directory '$projDir'";
  }

  # Set the environment variable for this process (and subprocesses)
  $ENV{'NF_DESIGN_DIR'} = $projDir;
}


#
# identifyWorkDir
#   Identify the work directory
#
sub identifyWorkDir {
  # Finally, identify the working directory for simulations
  if (defined($ENV{'NF_WORK_DIR'})) {
    $workDir = File::Spec->canonpath($ENV{'NF_WORK_DIR'});
  }
  else {
    my $login = getlogin() || getpwuid($<) || "anon";
    $workDir = File::Spec->tmpdir() . "/$login";
  }

  # Verify that the work directory exists
  if (! -d $workDir) {
    if (!mkpath($workDir)) {
      croak "Cannot create work directory '$workDir'";
    }
  }

  # Set the environment variable for this process (and subprocesses)
  $ENV{'NF_WORK_DIR'} = $workDir;
}


#
# parseCmdLine
#   Parse the command line arguments
#
sub parseCmdLine {
  # Attempt to identify the project
  #
  # Note: This removes the '--project <prj>' argument from ARGV
  Getopt::Long::Configure('pass_through');
  GetOptions(
    'project=s' => \@projects,
    'quiet'     => \$quiet
  );
  Getopt::Long::Configure('no_pass_through');

  # Stuff the arguments back in
  # FIXME: Remove this code eventually
  if (scalar(@projects) != 0) {
    unshift(@ARGV, (map { ('--project', $_); } @projects));
  }
}


#
# BEGIN
#   Function that is called as the module is loaded. This allows us to verify
#   that the environment is set up correctly.
#
BEGIN {
  parseCmdLine();
  identifyRoot();
  identifyProject();
  identifyWorkDir();
  printEnv();

  # Make the various directories available at the top level file
  eval <<EVAL;
package main;
use constant ROOT_DIR => '$rootDir';
use constant PROJ_DIR => '$projDir';
use constant WORK_DIR => '$workDir';
package Test1;
EVAL

}

#
# import
#   Function that is called when this module is used
#   Sets up the imports by using the 'lib' module.
#
sub import {
    my $package = shift;

    # Export any necessary functions
    NF::Base->export_to_level(1, $package, @NF::Base::EXPORT);

    # Update the list of imported directories
    my %names;
    my @dirs = map { "'$rootDir/$_'" } @_;
    unshift(@dirs, "'$projDir/lib/Perl5'");
    eval("use lib " . join(', ', @dirs) . ";");

    return;
}

#
# check_NF2_vars_set
#   Check that the user has set up their environment correctly.
#
#   Note: This function is now empty as it has been replaced by the BEGIN block
#   above that automatically checks/updates the enviroment when the module is
#   used.
#
sub check_NF2_vars_set {
}


#
# getNF2Project
#   Get the name of the project
#
# Return:
#   Name of project
#
sub getNF2Project {
  return $project;
}


#
# getNF2RootDir
#   Get the NetFPGA root directory
#
# Return:
#   NetFPGA root directory
#
sub getNF2RootDir {
  return $rootDir;
}


#
# getNF2ProjDir
#   Get the project directory
#
# Return:
#   Project directory
#
sub getNF2ProjDir {
  return $projDir;
}


#
# getNF2WorkDir
#   Get the work directory for the project
#
# Return:
#   Work directory
#
sub getNF2WorkDir {
  return $workDir;
}


#
# isQuiet
#   Check the status of the quiet variable
#
# Return:
#   Work directory
#
sub isQuiet {
  return $quiet;
}


# Always end library in 1
1;
