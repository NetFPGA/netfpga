#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: File.pm 6067 2010-04-01 22:36:26Z grg $
#
# Base file-handling functions
#
#############################################################

package NF::RegSystem::File;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw(
                openRegFile
                closeRegFile
                stripNF2Root
            );

use Carp;
use File::Basename;
use File::Path;
use File::Temp qw/tempfile/;
use File::Copy;
use Digest::file qw/digest_file/;
use NF::RegSystem qw($_NF_ROOT);
use strict;

my %files;

#
# openRegFile
#   Function to open a file for writing -- actually opens a temporary file to
#   allow copying when the file is closed but only if the file changes
#
# Params:
#   name    -- filename
#
# Return:
#   File handle reference
#
sub openRegFile {
  my $name = shift;

  my $dirname = dirname($name);

  # Verify that the directory exists and create if necessary
  if ($dirname ne '') {
    if (! -d "$_NF_ROOT/$dirname") {
      print "WARNING: Directory '$dirname' does not exist. Creating...\n";
      mkpath("$_NF_ROOT/$dirname");
    }
  }

  # Create the temporary file
  my ($fh, $tempName) = tempfile();

  # Store the temporary file and original file
  $files{$fh} = {
      origFile  => "$_NF_ROOT/$name",
      tempFile  => $tempName,
  };

  return $fh;
}

#
# closeRegFile
#   Close a temporary file and copy it over the original file if the contents
#   differ.
#
# Params:
#   handle  -- file handle to close
#
sub closeRegFile {
  my $fh = shift;

  return if (!defined($files{$fh}));

  close $fh;

  my $origFile = $files{$fh}->{origFile};
  my $tempFile = $files{$fh}->{tempFile};
  delete($files{$fh});

  # Work out whether the file has changed
  if (-f $origFile) {
    # Get the MD5 sums
    my $origSum = digest_file($origFile, 'MD5');
    my $tempSum = digest_file($tempFile, 'MD5');

    if ($origSum eq $tempSum) {
      unlink $tempFile;
      return;
    }
  }

  # Move the temp file onto the new file
  move($tempFile, $origFile);
}

#
# stripNF2Root
#   Strip the NetFPGA root from a path
#
# Params:
#   path    -- path to strip
#
# Return:
#   Path without NF_ROOT
#
sub stripNF2Root {
  my $path = shift;

  $path =~ s/^$_NF_ROOT\///;
  return $path;
}

1;

__END__
