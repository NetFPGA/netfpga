#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: LibModulesOutput.pm 6035 2010-04-01 00:29:24Z grg $
#
# lib_modules file output
#
#############################################################

package NF::RegSystem::LibModulesOutput;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw(
                genLibModulesOutput
            );

use Carp;
use NF::RegSystem::File;
use NF::Utils;
use NF::RegSystem qw($PROJECTS_DIR $INCLUDE_DIR);
use POSIX;
use Math::BigInt;
use strict;

# Path locations
my $LIB_MODULE_FILE = 'lib_modules.txt';

#
# genLibModulesOutput
#   Generate the lib_modules file corresponding to the project
#
# Params:
#   project     -- Name of project
#   modulePaths -- Paths to modules as defined in the XML
sub genLibModulesOutput {
  my ($project, $modulePaths) = @_;

  # Get a file handle
  my $fh = openRegFile("$PROJECTS_DIR/$project/$INCLUDE_DIR/$LIB_MODULE_FILE");

  # Walk through the modules and print them
  for my $module (@$modulePaths) {
    print $fh "$module\n";
  }

  # Finally close the file
  closeRegFile($fh);
}


1;

__END__
