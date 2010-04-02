#!/usr/bin/perl -w
# vim:set shiftwidth=3 softtabstop=3 expandtab:
# $id:$

# Perl equivalent of the C regwrite function

use strict;
use NF::RegAccess;
use Getopt::Long;

# Parse the command line arguments
my $iface = 'nf2c0';   		# Default device
my $help = '';

unless ( GetOptions (
		      "iface|i=s" => \$iface,
		      "help|h|?" => \$help,
		     )
	 and ($help eq '') and ($#ARGV > -1) and ($#ARGV % 2 == 1)
       ) { usage(); exit 1 }

# Process each register
for (my $i = 0; $i <= $#ARGV; $i += 2) {
   my $addrStr = $ARGV[$i];
   my $valStr = $ARGV[$i];

   my $addr = 0;
   my $val = 0;

   # Work out what sort of argument this is
   if ($addrStr =~ /^\d+$/) {
      $addr = $addrStr;
   }
   elsif ($addrStr =~ /^0x[0-9a-fA-F]+$/) {
      $addr = hex($addrStr);
   }
   else {
      warn "Cannot identify register named '$addrStr'";
      next;
   }

   # Work out what sort of argument this is
   if ($valStr =~ /^\d+$/) {
      $val = $valStr;
   }
   elsif ($valStr =~ /^0x[0-9a-fA-F]+$/) {
      $val = hex($valStr);
   }
   else {
      warn "Cannot identify value named '$valStr'";
      next;
   }

   # Perform the write
   nf_regwrite($iface, $addr, $val);
   printf("Write: Reg 0x%08x (%u):   0x%08x (%u)\n", $addr, $addr, $val, $val);
}

exit (0);


#########################################################
# usage
#   print usage information
sub usage {
  (my $cmd = $0) =~ s/.*\///;
  print <<"HERE1";
NAME
   $cmd - Writes registers to a NetFPGA device

SYNOPSIS
   $cmd [--iface <device>] [-i <device>]
        [[register] [value]] [[register] [value]]...

   $cmd --help  - show detailed help

HERE1

  return unless ($help);
  print <<"HERE";

DESCRIPTION

   This script writes one or more registers


OPTIONS
   -i <device>
   --iface <device>
     Device in which to write registers.


EXAMPLE

   To read register 0x0:

   % $cmd 0x0

HERE
}


