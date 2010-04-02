#!/usr/bin/perl -w
# vim:set shiftwidth=3 softtabstop=3 expandtab:
# $id:$

#
# Program to read the contents of SRAM and print out the contents
#
# Includes the option to dump as a sequence of packets
#

use strict;
use NF::RegAccess;
use Getopt::Long;
require "reg_defines.ph";

# Memory size in words
my $MEM_SIZE = 0x80000;

# Headers
my $LEN_SRC_DEST_HDR = 0xff;

# Max queues
my $MAX_QUEUES = 16;

# Invalid register value
my $INVALID_REG = 0xdeadbeef;

# Packet printing variables
my $hdrTitle = 0;
my $inPkt = 0;
my $pos = 0;
my $pktNum = 1;

# Parse the command line arguments
my $iface = 'nf2c0';   		# Default device
my $help = '';
my $startStr = '';
my $endStr = '';
my $qloStr = 0;
my $qhiStr = $MEM_SIZE - 1;
my $pkts = 0;
my $queue = '';

unless ( GetOptions (
		      "iface=s" => \$iface,
		      "help|?" => \$help,
		      "start=s" => \$startStr,
		      "end=s" => \$endStr,
		      "qlo=s" => \$qloStr,
		      "qhi=s" => \$qhiStr,
		      "pkts" => \$pkts,
                      "q=i" => \$queue
		     )
	 and ($help eq '')
       ) { usage(); exit 1 }

# Attempt to convert addresses to numeric values
my $qlo = convertHex($qloStr);
my $qhi = convertHex($qhiStr);
my $start = convertHex($startStr);
my $end = convertHex($endStr);

$start = $qlo if ($startStr eq '');
$end = $qhi if ($endStr eq '');

# Verify that the addresses are valid
validateArgs();

# Process the queue argument
processQ() if ($queue ne '');

# Walk through the desired memory addresses and dump
printHeader();
my $addr = $start;
$end = incAddr($end, $qlo, $qhi);
do {
   my ($ctrl, @data) = readWord($addr);

   if ($pkts) {
      printPktWord($addr, $ctrl, @data);
   }
   else {
      printWord($addr, $ctrl, @data);
   }

   $addr = incAddr($addr, $qlo, $qhi);
} until ($addr == $end);

# Clean up the output a little before exiting
if ($pkts && ($pos % 16) != 0) {
   print "\n";
   print "\n";
}
elsif (!$pkts) {
   print "\n";
}

exit (0);


#########################################################
# usage
#   print usage information
sub usage {
  (my $cmd = $0) =~ s/.*\///;
  print <<"HERE1";
NAME
   $cmd - Dump the contents of SRAM

SYNOPSIS
   $cmd [--iface <device>]
        [--pkts]
        [--q <queue number>]
        [--start <start address>] [--end <end address>]
        [--qlo <qlo address>] [--qhi <qhi address>]

   $cmd --help  - show detailed help

HERE1

  return unless ($help);
  print <<"HERE";

DESCRIPTION

   Read and dump the contents of SRAM


OPTIONS
   --iface <device>
     Device to read registers from.

   --pkts
     Dump the contents of SRAM as packets

   --queue <queue number>
     Attempt to identify the start/end and qlo/qhi addresses
     for a particular queue

   --start <start address>
     Starting address for dumping

   --end <start address>
     Ending address for dumping
     (Note: if end < start then the dumping process will wrap)

   --qlo <qlo address>
     Low address for the queue -- used when wrapping

   --qhi <qhi address>
     High address for the queue -- used when wrapping

HERE
}


#
# convertHex -- convert a hexadecimal value to decimal
#
sub convertHex {
   my $str = shift;

   if ($str =~ /^\d+$/) {
      return $str;
   }
   elsif ($str =~ /^0x[0-9a-fA-F]+$/) {
      return hex($str);
   }
   else {
      return undef;
   }
}

#
# readWord -- read a word from SRAM
#
sub readWord {
   my $addr = shift;

   my ($ctrl, @data);
   $ctrl = nf_regread($iface, SRAM_BASE_ADDR_REG() + $addr * 16 + 0x4);
   $data[0] = nf_regread($iface, SRAM_BASE_ADDR_REG() + $addr * 16 + 0x8);
   $data[1] = nf_regread($iface, SRAM_BASE_ADDR_REG() + $addr * 16 + 0xc);

   my @bytes;
   foreach my $word (@data) {
      for (my $i = 0; $i < 4; $i++) {
         push @bytes, $word >> ((3-$i) * 8) & 0xff;
      }
   }

   return ($ctrl, @bytes);
}

#
# printHeader -- print a standard header
#
sub printHeader {
   if (!$pkts) {
      print "Addr     Ctrl  Data\n";
      print "-------  ----  " . "---" x 7 . "--\n";
   }
}

#
# printWord -- print a word
#
sub printWord {
   my ($addr, $ctrl, @data) = @_;

   printf "%06x:  ", $addr;
   printf "%04x ", $ctrl;
   for (my $i = 0; $i < scalar(@data); $i++) {
      printf " %02x", $data[$i];
   }
   print "\n";
}

#
# printPktWord -- print a word -- interpreting it as belonging to a packet
#
sub printPktWord {
   my ($addr, $ctrl, @data) = @_;

   # Check to see if this is the start of a packet
   if (!$inPkt && $ctrl == 0x0) {
      print "\nData:\n";
      print "Addr   (PktPos)    Data\n";
      print "------ ---------   " . "---" x 16 . "--\n";

      $inPkt = 1;
   }

   if ($inPkt) {
      if ($pos % 16 == 0) {
         printf "%06x (%06x):  ", $addr, $pos;
      }

      my $last = 8;
      if ($ctrl != 0) {
         my $match = 0x80;
         $last = 1;
         while ($match != $ctrl) {
            $match = $match >> 1;
            $last++;
         }
      }
      for (my $i = 0; $i < $last; $i++) {
         printf " %02x", $data[$i];
      }

      $pos += 8;

      if ($pos % 16 == 0 || $ctrl != 0) {
         print "\n";
      }
      else {
         print "   ";
      }

      if ($ctrl != 0) {
         print "\n";
         $inPkt = 0;
         $pos = 0;
         $hdrTitle = 0;
         $pktNum++;
      }
   }
   else {
      # Print a header title if necessary
      if (!$hdrTitle) {
         my $str = sprintf("Packet %d", $pktNum);
         print "\n" if ($pktNum > 1);
         print "$str\n";
         print "=" x length($str), "\n";
         print "Header(s):\n";
         print "Addr     Ctrl   Data\n";
         print '-' x 7 . "  " . '-' x 4 . "   " . "---" x 7 . "--\n";
         $hdrTitle = 1;
      }

      printf "%06x:  ", $addr;
      printf "%04x  ", $ctrl;
      for (my $i = 0; $i < scalar(@data); $i++) {
         printf " %02x", $data[$i];
      }

      if ($ctrl == $LEN_SRC_DEST_HDR) {
         printLenSrcDestHdr($ctrl, @data);
      }

      print "\n";
   }
}

#
# printLenSrcDestHdr -- print the length/src/dest header
#
sub printLenSrcDestHdr {
   my ($ctrl, @data) = @_;

   return if ($ctrl != $LEN_SRC_DEST_HDR);

   print "     \n";
   print "\t\t\tLength/Src/Dest:";
   printf "\n\t\t\t\tLen (data/words): %d/%d", ($data[6] << 8 | $data[7]), ($data[2] << 8 | $data[3]);
   printf "\n\t\t\t\tSrc: %d", ($data[4] << 8 | $data[5]);
   printf "\n\t\t\t\tDest: 0x%04x", ($data[0] << 8 | $data[1]);
}

# Verify that the addresses are valid
sub validateArgs {
   if (!defined($qlo)) {
      print STDERR "Unable to interpret qlo value \"$qloStr\" as either a decimal or hexadecimal value\n";
      usage();
      exit 1;
   }

   if (!defined($qhi)) {
      print STDERR "Unable to interpret qhi value \"$qhiStr\" as either a decimal or hexadecimal value\n";
      usage();
      exit 1;
   }

   if (!defined($start)) {
      print STDERR "Unable to interpret start value \"$startStr\" as either a decimal or hexadecimal value\n";
      usage();
      exit 1;
   }

   if (!defined($end)) {
      print STDERR "Unable to interpret end value \"$endStr\" as either a decimal or hexadecimal value\n";
      usage();
      exit 1;
   }

   if ($qlo < 0 || $qlo >= $MEM_SIZE) {
      print STDERR "Invalid qloi address. Address must between 0 and " . $MEM_SIZE - 1 . " inclusive\n";
      print STDERR "Entered value: $qloStr\n";
      usage();
      exit 1;
   }

   if ($qhi < 0 || $qhi >= $MEM_SIZE) {
      print STDERR "Invalid qhi address. Address must between 0 and " . $MEM_SIZE - 1 . " inclusive\n";
      print STDERR "Entered value: $qhiStr\n";
      usage();
      exit 1;
   }

   if ($qlo > $qhi) {
      print STDERR "Invalid qlo/qhi address. qlo must be <= qhi.\n";
      print STDERR "Entered values: qlo = $qloStr   qhi = $qhiStr\n";
      usage();
      exit 1;
   }

   if ($start < $qlo || $start > $qhi) {
      print STDERR "Invalid start address. Addresses must between qlo (" . $qloStr . ") and\n";
      print STDERR "qhi (" . $qhiStr . "). Entered value: $startStr\n";
      usage();
      exit 1;
   }

   if ($end < $qlo || $end > $qhi) {
      print STDERR "Invalid end address. Addresses must between qlo (" . $qloStr . ") and\n";
      print STDERR "qhi (" . $qhiStr . "). Entered value: $endStr\n";
      usage();
      exit 1;
   }
}

#
# processQ -- process the q argument and get the relevant addresses
#
sub processQ {
   if ($queue < 0 || $queue >= $MAX_QUEUES) {
      print STDERR "Invalid queue. Queue must between 0 and " . $MAX_QUEUES - 1 . " inclusive\n";
      print STDERR "Entered value: $queue\n";
      usage();
      exit 1;
   }

   my $qOffset = OQ_NUM_WORDS_LEFT_REG_1() - OQ_NUM_WORDS_LEFT_REG_0();

   $qlo = nf_regread($iface, OQ_ADDRESS_LO_REG_0() + $queue * $qOffset);
   $qhi = nf_regread($iface, OQ_ADDRESS_HI_REG_0() + $queue * $qOffset);

   $end = nf_regread($iface, OQ_WR_ADDRESS_REG_0() + $queue * $qOffset);
   $start = nf_regread($iface, OQ_WR_ADDRESS_REG_0() + $queue * $qOffset);

   # Verify that the queue "seems" to exist
   if ($qhi == $INVALID_REG && $qlo == $INVALID_REG) {
      print STDERR "Queue $queue appears not to exist.\n";
      usage();
      exit 1;
   }

   # Find the beginning of the oldest packet
   my $newPkt = 1;
   my $inPkt = 0;
   my $foundPkt = 0;
   my $good = 1;

   while ($good) {
      $start = decAddr($start, $qlo, $qhi);
      my $ctrl = nf_regread($iface, SRAM_BASE_ADDR_REG() + $start * 16 + 0x4);

      # Process the ctrl word based upon where we are
      if ($newPkt) {
         # If we're expecting a new packet then we should see an EOP control
         # word. If we don't see the ctrl word advance forward until the start
         # of thepreviously seen packet or we reach the end pointer
         if (!isEOP($ctrl)) {
            while ($ctrl != $LEN_SRC_DEST_HDR && $start != $end) {
               $start = incAddr($start, $qlo, $qhi);
               $ctrl = nf_regread($iface, SRAM_BASE_ADDR_REG() + $start * 16 + 0x4);
            }
            $good = 0;
         }
         # Otherwise we saw the ctrl word so we're in a packet
         else {
            $inPkt = 1;
            $newPkt = 0;
         }
      }
      elsif ($inPkt) {
         # Check for headers at the beginning of the packet
         if ($ctrl != 0) {
            $inPkt = 0;
         }
      }

      # Check to see if we've seen the first header
      if (!$inPkt && !$newPkt) {
         if ($ctrl == $LEN_SRC_DEST_HDR) {
            $newPkt = 1;
            $foundPkt = 1;
         }
      }

      # Check to see if we managed to wrap
      if ($start == $end && $good) {
         while ($ctrl != $LEN_SRC_DEST_HDR && $start != $end) {
            $start = incAddr($start, $qlo, $qhi);
            $ctrl = nf_regread($iface, SRAM_BASE_ADDR_REG() + $start * 16 + 0x4);
         };
         $good = 0;
      }
   }

   if (!$foundPkt) {
      print STDERR "Unable to identify packets in queue $queue.\n";
      exit 1;
   }
   $end = decAddr($end, $qlo, $qhi);
}

#
# isEOP -- is the control word an EOP word?
#
sub isEOP {
   my $ctrl = shift;

   return $ctrl == 0x01 || $ctrl == 0x02 || $ctrl == 0x04 || $ctrl == 0x08  ||
          $ctrl == 0x10 || $ctrl == 0x20 || $ctrl == 0x40 || $ctrl == 0x80;
}

#
# decAddr -- decrement an address staying within the lo/hi boundaries
#
sub decAddr {
   my ($addr, $lo, $hi) = @_;

   $addr = $addr - 1;
   if ($addr < $lo) {
      $addr = $hi;
   }

   return $addr;
}

#
# incAddr -- increment an address staying within the lo/hi boundaries
#
sub incAddr {
   my ($addr, $lo, $hi) = @_;

   $addr = $addr + 1;
   if ($addr > $hi) {
      $addr = $lo;
   }

   return $addr;
}

