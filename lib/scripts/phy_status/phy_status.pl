#!/usr/bin/perl -w
# vim:set shiftwidth=3 softtabstop=3 expandtab:
# $id:$

#
# Program to read and dump the MII registers
#

use strict;
use NF::RegAccess;
use Getopt::Long;
use Time::HiRes qw (usleep);
require "reg_defines.ph";

# Number of read retries
use constant MDIO_READ_RETRIES => 20;
my $MDIO_PHY_OFFSET = MDIO_PHY_1_CONTROL_REG() - MDIO_PHY_0_CONTROL_REG();

# PHY ID
use constant PHY_ID => 0x002060B0;

use constant NUM_PHYS => 4;

# Parse the command line arguments
my $iface = 'nf2c0';   		# Default device
my $help = '';
my $verbose = 0;
my @phy = (1, 2, 3, 4);

unless ( GetOptions (
		      "iface=s" => \$iface,
		      "help|?" => \$help,
                      "verbose|v" => \$verbose,
                      "phy=s" => \@phy,
		     )
	 and ($help eq '')
       ) { usage(); exit 1 }

# Work out which phys to process
validatePhys(join(',', @phy));

# Begin by verifying the Phy ID
verifyPhyId();

# Step through the phys and print their status
foreach my $phy (@phy) {
   $phy -= 1;
   printf "Phy %d:\n", $phy + 1;
   phyControl($phy);
   phyStatus($phy);
}

exit (0);


#########################################################
# usage
#   print usage information
sub usage {
  (my $cmd = $0) =~ s/.*\///;
  print <<"HERE1";
NAME
   $cmd - Print the status of the PHY(s)

SYNOPSIS
   $cmd [--iface <device>]
        [--verbose|-v]
        [--phy <PHY>]

   $cmd --help  - show detailed help

HERE1

  return unless ($help);
  print <<"HERE";

DESCRIPTION

   Print the status of one or more of the PHYs


OPTIONS
   --iface <device>
     Device to read registers from.

   --verbose|-v
     Print more information

   --phy <PHY>
     Display status for PHY. Can specifiy multiple PHY entries
     or a comma-separated list.
     Valid values are 1, 2, 3 and 4

HERE
}


#
# readMDIOReg - Read an MDIO register.
#
# Return:  < 0 : read failed
#         >= 0 : read result
#
sub readMDIOReg {
   my ($phy, $addr) = @_;

   my $val;
   my $retry;

   # Perform the read
   $retry = MDIO_READ_RETRIES;
   do {
      $val = nf_regread($iface, $phy * $MDIO_PHY_OFFSET + $addr);
      $retry--;
      usleep(1000);
   } while ($retry > 0 && ($val & 0x80000000));

   # Return the result -- either -1 on failure or the low 16 bits of the result
   if ($val & 0x80000000) {
      return -1;
   }
   else {
      return $val & 0xffff;
   }
} # readMDIOReg

#
# Write to an MDIO register
#
sub writeMDIOReg {
   my ($phy, $addr, $val) = @_;

   nf2_regwrite($iface, $phy * $MDIO_PHY_OFFSET + $addr, $val & 0xffff);
}

#
# Verify the Phy ID
#
sub verifyPhyId {
   my $phyid_hi = readMDIOReg(0, MDIO_PHY_0_PHY_ID_0_REG());
   my $phyid_lo = readMDIOReg(0, MDIO_PHY_0_PHY_ID_1_REG());

   my $phyid = ($phyid_hi << 16) | $phyid_lo;

   # Work out whether the phy seems okay
   #printw("     Phy %d:", phy + 1);
   if ($phyid_hi < 0 || $phyid_lo < 0) {
      print "Invalid PHY Id (Read failed)\n";
      exit 1;
   }
   elsif (($phyid & 0xfffffff0) != PHY_ID) { #//Invalid PHY Id: 0x007f60b1   up, 1000Base-TX full
      printf " Invalid PHY Id: 0x%08x\n", $phyid;
      exit 1;
   }
   else {
      printf "Phy ID valid. rev %d\n", $phyid & 0xf;
   }
}

#
# phyControl -- Print the control register
#
sub phyControl {
   my $phy = shift;

   my @msgs = (
      15, "PHY reset", "Active", "Normal operation",
      14, "Internal loopback", "enabled", "disabled",
      12, "Auto-negotiation", "enabled", "disabled",
      11, "Power down", "enabled", "disabled",
      10, "Isolation", "Isolate PHY from RGMII", "Normal",
       9, "Auto-negotiation", "Restarting", "Restart complete",
       8, "Duplex", "Full", "Half",
       7, "Collision test", "enabled", "disabled",
   );

   my $val = readMDIOReg($phy, MDIO_PHY_0_CONTROL_REG());
   if ($val != -1) {
      print "  Control:\n";
      my $speed = (($val & 0x2000) ? 1 : 0) |
                  (($val & 0x0040) ? 2 : 0);
      if ($speed == 3) {
         print "    Speed: Reserved???\n";
      }
      elsif ($speed == 2) {
         print "    Speed: 1000 Mbps\n";
      }
      elsif ($speed == 1) {
         print "    Speed: 100 Mbps\n";
      }
      elsif ($speed == 0) {
         print "    Speed: 10 Mbps\n";
      }
      printRegBits($val, [8], \@msgs);
      if ($verbose) {
         printRegBits($val, [15, 14, 12, 11, 10, 9, 7], \@msgs);
      }
   }
   else {
      print "Can't read status register...\n";
   }
}
#
# phyStatus -- Print the phy status
#
sub phyStatus {
   my $phy = shift;

   my @msgs = (
      6, "Preamble", "can be suppressed", "always required",
      5, "Auto-negotiation", "complete", "in progress",
      4, "Remote fault", "detected", "not detected",
      3, "Auto-negotiation", "capable", "not capable",
      2, "Link", "up", "down",
      1, "Jabber condition", "detected", "not detected",
   );

   my $val = readMDIOReg($phy, MDIO_PHY_0_STATUS_REG());
   if ($val != -1) {
      print "  Status:\n";
      printRegBits($val, [5, 3, 2], \@msgs);
      if ($verbose) {
         print "    Capabilities:";
         print "   100BASE-T4" if ($val & 0x8000);
         print "   100BASE-X Full-Duplex" if ($val & 0x4000);
         print "   100BASE-X Half-Duplex" if ($val & 0x2000);
         print "   10BASE-T Full-Duplex" if ($val & 0x1000);
         print "   10BASE-T Half-Duplex" if ($val & 0x0800);
         print "   10BASE-T2 Full-Duplex" if ($val & 0x0400);
         print "   10BASE-T2 Half-Duplex" if ($val & 0x0200);
         print "\n";
         printRegBits($val, [6, 4, 1], \@msgs);
      }
   }
   else {
      print "Can't read status register...\n";
   }
}

#
# printRegBits -- print register value(s)
#
sub printRegBits {
   my ($val, $bits, $msgs) = @_;

   my $empty = 'EMPTY';

   my %status;
   my $status;

   foreach my $bit (@$bits) {
      for (my $i = 0; $i < scalar(@$msgs); $i += 4) {
         if (@$msgs[$i] == $bit) {
            my $name = @$msgs[$i + 1];
            my $val1 = @$msgs[$i + 2];
            my $val0 = @$msgs[$i + 3];

            # Work out the status
            my $status;
            if ($val & (1 << $bit)) {
               $status = "$val1";
            }
            else {
               $status = "$val0";
            }

            # Update the hash
            if ($status ne '') {
               if ($name ne '' && defined($status{$name})) {

                  $status{$name} .= ", $status";
               }
               elsif ($name ne '') {
                  $status{$name} = $status;
               }
               else {
                  if (defined($status{$empty})) {
                     $status{$empty} .= "$status";
                  }
                  else {
                     $status{$empty} = $status;
                  }
               }
            }
         }
      }
   }

   if (defined($status{$empty})) {
      $status = $status{$empty};
      print "    $status\n";
      delete($status{$empty});
   }
   foreach my $key (sort(keys(%status))) {
      $status = $status{$key};
      print "    $key: $status\n";
   }
}

#
# validatePhys -- process the list of phys passed into the program
#
sub validatePhys {
   my $phyList = shift;
   my @phy = split(/,/, $phyList);

   my $good = 1;
   foreach my $phy (@phy) {
      if ($phy < 1 || $phy > NUM_PHYS) {
         $good = 0;
      }
   }

   if ($good != 1) {
      print "Invalid list of PHYs. Must enter value(s) between 1 and " . NUM_PHYS . "\n";
      usage();
      exit 1;
   }

   return @phy;
}
