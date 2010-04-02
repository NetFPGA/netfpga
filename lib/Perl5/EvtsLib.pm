#####################################
#
# $Id: EvtsLib.pm 6036 2010-04-01 00:30:59Z grg $
#
# This provides functions for use in
# tests of the UNET-SWITCH4-with_buffer_sizing system.
#
#
#####################################

package EvtsLib;

use NF::PacketGen;
use NF::PacketLib;
use Exporter;
use POSIX;

@ISA = ('Exporter');

@EXPORT = qw( &nf_expected_event
                  &parse_evt_pkts
                  &compare_rcvd_evts
                );

use constant NUM_EVT_TYPES => (3*8+1); # (st+dr+rm)*num_queues + ts
my $eventTypeMask  = 0xc0000000;
my $eventTypeShift = 30;
my $eventQMask     = 0x38000000;
my $eventQShift    = 27;
my $lenMask        = 0x07f80000;
my $lenShift       = 19;
my $timeMask       = 0x0007FFFF;

my @eventTypes = (
                  "Timestamp event",
                  "Store  Q 0     ",
                  "Remove Q 0     ",
                  "Drop   Q 0     ",
                  "Store  Q 1     ",
                  "Remove Q 1     ",
                  "Drop   Q 1     ",
                  "Store  Q 2     ",
                  "Remove Q 2     ",
                  "Drop   Q 2     ",
                  "Store  Q 3     ",
                  "Remove Q 3     ",
                  "Drop   Q 3     ",
                  "Store  Q 4     ",
                  "Remove Q 4     ",
                  "Drop   Q 4     ",
                  "Store  Q 5     ",
                  "Remove Q 5     ",
                  "Drop   Q 5     ",
                  "Store  Q 6     ",
                  "Remove Q 6     ",
                  "Drop   Q 6     ",
                  "Store  Q 7     ",
                  "Remove Q 7     ",
                  "Drop   Q 7     ");

my @expectedEvents;

use Carp;
use strict;

sub nf_expected_event {

  if (@_ < 3) {
    die "Expecting 3 arguments: Queue, type ('st', 'dr', 'rm'), length\n";
  }

  my $queue=shift;
  my $type=shift;
  my $len=shift;

  my $type_num;

  if ($queue > 7 || $queue < 0) {
    die "Queue number should be between 0 and 7\n";
  }
  if ($type ne 'st' && $type ne 'dr' && $type ne 'rm') {
    die "Type should be one of st/rm/dr\n";
  }
  if ($len > 2048 || $len < 60) {
    die "Length should be between 2048 and 60\n";
  }

  my $i;

  # if there are no rows in the events list
  if (@expectedEvents==0) {
    my @row;
    # create the two dimensional array
    for ($i=0; $i<NUM_EVT_TYPES; $i=$i+1) {
      push @expectedEvents,[ @row ];
    }
  }

  if ($type eq 'st') {
    $type_num = 1;
  } elsif ($type eq 'rm') {
    $type_num = 2;
  } elsif ($type eq 'dr') {
    $type_num = 3;
  }

  $len = ceil($len/8.0) + 1; # include overhead size
  push @{ $expectedEvents[$type_num+$queue*3] },$len;
}


#####################################################
# Take a list of 32 bit words and
# return an events list

sub parse_events {
  my @pkt_data = @_;

  my @evt_bins;
  my @row;
  my $evt;

  my $evt_type;
  my $evt_q;
  my $i;

  for ($i=0; $i<NUM_EVT_TYPES; $i=$i+1) {
    push @evt_bins, [ @row ];
  }

  while (@pkt_data) {
    $evt = shift @pkt_data;
    $evt_type = ($evt >> $eventTypeShift);
    if ($evt_type == 0) {
      $evt_q = 0;
    }
    else {
      $evt_q = (($evt & $eventQMask) >> $eventQShift);
    }
    push @{ $evt_bins[$evt_type + $evt_q*3] },(($evt & $lenMask) >> $lenShift);
  }

  return @evt_bins;

}


#####################################################
# Read the evt packets and parse them

sub parse_evt_pkts {
  my $filename = shift;
  my $ethertype = shift;

  my $outputString="";
  my @tempHexBytes;
  my $pkt="";
  my @packetData=(1,2,3);

  my $i;
  my $j;

  my $event;
  my $lastTime = 0;

  my @counts;
  for ($i=0; $i<NUM_EVT_TYPES; $i=$i+1){
    push @counts,0;
  }

  if (! -r $filename) {
    die "Can't read input $filename\n";
  }
  if (! -f $filename) {
    die "Input $filename is not a plain file\n";
  }

  open(INPUT,"<$filename") ||
    die "Can't input $filename $!";

  while (<INPUT>) {
    chomp;
    # wait for start of packet
    if ($_ =~ '<PACKET ') {
      # read the full packet
      my $line;
      $pkt = "";
      do {
        $line = <INPUT>;
        chomp $line;
        if( !($line =~ '</PACKET>')) {
          $pkt = $pkt.$line;
        }
      } until ($line =~ '</PACKET>') || eof;

      # parse it
      @tempHexBytes=split(/ /,$pkt);
      my $temp = hex($tempHexBytes[12].$tempHexBytes[13]);
      if ($temp eq $ethertype) {
	# check the ip checksum
	my $IP_hdr = NF::IP_hdr->new(ttl => hex($tempHexBytes[22]),
				      tos => hex($tempHexBytes[15]),
				      dgram_len => hex($tempHexBytes[38].$tempHexBytes[39]),
				      dgram_id => hex($tempHexBytes[18].$tempHexBytes[19]),
				      frag => hex($tempHexBytes[20].$tempHexBytes[21]),
				      proto => hex($tempHexBytes[23]),
				      src_ip => hex($tempHexBytes[26].$tempHexBytes[27].$tempHexBytes[28].$tempHexBytes[29]),
				      dst_ip => hex($tempHexBytes[30].$tempHexBytes[31].$tempHexBytes[32].$tempHexBytes[33])
				     );
	$IP_hdr->checksum(0);  # make sure its zero before we calculate it.
	my $calc_checksum = $IP_hdr->calc_checksum;
	my $pkt_checksum = hex($tempHexBytes[24].$tempHexBytes[25]);
	if($calc_checksum != $pkt_checksum){
	  print "Error: bad checksum. Expected $calc_checksum but got $pkt_checksum\n";
	}

        $outputString=$outputString . "\n\nMAC dst address            : @tempHexBytes[0..5]\n";
        $outputString=$outputString . "MAC src address            : @tempHexBytes[6..11]\n";
        $outputString=$outputString . "Ethertype                  : @tempHexBytes[12..13]\n";
        $outputString=$outputString . "IP version + hdr length    : $tempHexBytes[14]\n";
        $outputString=$outputString . "IP TOS                     : $tempHexBytes[15]\n";
        $outputString=$outputString . "IP Total length            : @tempHexBytes[16..17]\n";
        $outputString=$outputString . "IP ID                      : @tempHexBytes[18..19]\n";
        $outputString=$outputString . "IP Flags+offset            : @tempHexBytes[20..21]\n";
        $outputString=$outputString . "IP TTL                     : $tempHexBytes[22]\n";
        $outputString=$outputString . "IP Protocol                : $tempHexBytes[23]\n";
        $outputString=$outputString . "IP checksum                : @tempHexBytes[24..25]\n";
        $outputString=$outputString . "IP src addr                : @tempHexBytes[26..29]\n";
        $outputString=$outputString . "IP dst addr                : @tempHexBytes[30..33]\n";
        $outputString=$outputString . "UDP source port            : @tempHexBytes[34..35]\n";
        $outputString=$outputString . "UDP dst port               : @tempHexBytes[36..37]\n";
        $outputString=$outputString . "UDP length                 : @tempHexBytes[38..39]\n";
        $outputString=$outputString . "UDP checksum               : @tempHexBytes[40..41]\n";

        # Add event header
        $outputString=$outputString . "Events version             : $tempHexBytes[42]\n";
        $outputString=$outputString . "Number of monitored events : $tempHexBytes[43]\n";
        $outputString=$outputString . "Event pkt seq num          : @tempHexBytes[44..47]\n";

        # get the events
        for ($i=48; $i<=$#tempHexBytes; $i=$i+4) {
          $packetData[($i-48)/4]=hex($tempHexBytes[$i].$tempHexBytes[$i+1].$tempHexBytes[$i+2].$tempHexBytes[$i+3]);
        }

        # Parse the queue sizes
        for ($i=0; $i<8; $i=$i+1) {
          $event = shift @packetData;
          $outputString=$outputString . "Queue $i size (pkts)    : $event\n";
          $event = shift @packetData;
          $outputString=$outputString . "Queue $i size (bytes)   : $event\n";
        }

        print "parsing events\n";
	my $evt_type;
	my $evt_q;
        while (@packetData) {
          $event = shift @packetData;
	  $outputString=$outputString . sprintf("%08x :: ", $event);
	  $evt_type = ($event >> $eventTypeShift);
	  if ($evt_type == 0) {
	    $evt_q = 0;
	  }
	  else {
	    $evt_q = (($event & $eventQMask) >> $eventQShift);
	  }
	  $i = $evt_type + $evt_q*3;
          $outputString = $outputString . "$eventTypes[$i] ";
          $counts[$i] = $counts[$i] + 1;

          # if it's a timestamp event
          if($i==0) {
            # check that the second part of the timestamp exists
            if(@packetData==0) {
              print $outputString;
              print "\n";
              die "ERROR: second half of timestamp event missing!\n";
            }
            else {
              $lastTime = (($event & (~$eventTypeMask)) << 32) + (shift @packetData);
              $outputString=$outputString . " :: $lastTime\n";
            }
          }
          else {
            # advance the time
            $lastTime += ($event&$timeMask);
            $outputString=$outputString . sprintf(" :: Time diff: %05d, Length: %03d, Absolute Time: %016d\n", ($event & $timeMask), (($event & $lenMask) >> $lenShift), $lastTime);
          }
        }
        print "done parsing events\n";
      }
    }
  }

  $outputString = $outputString . "\n\nEvent counts:\n";
  for($i=0; $i<NUM_EVT_TYPES; $i=$i+1){
    $outputString = $outputString . $eventTypes[$i];
    $outputString = $outputString . " :: ";
    $outputString = $outputString . $counts[$i];
    $outputString = $outputString . "\n";
  }

  close INPUT;

  return $outputString;
}

#####################################################
# Read the evt packets and compare them to
# the expected events

sub compare_rcvd_evts {
  my $filename = shift;
  my $ethertype = shift;
  my $eventQueue = shift;
  my $allowed_num_errors = shift;

  my @tempHexBytes;
  my $pkt="";
  my @packetData;

  my $i;
  my $j;

  if (! -r $filename) {
    die "Can't read input $filename\n";
  }
  if (! -f $filename) {
    die "Input $filename is not a plain file\n";
  }

  if ($eventQueue > 7 || $eventQueue < 0) {
    die "Event queue number should be between 0 and 7, not $eventQueue\n";
  }

  print "\nExpected events:\n";
  for $i (0..$#expectedEvents) {
    print $eventTypes[$i]." :: ";
    print @{ $expectedEvents[$i] };
    print "\n";
  }

  open(INPUT,"<$filename") ||
    die "Can't input $filename $!";

  my $error=0;
  while (<INPUT>) {
    chomp;
    # wait for start of packet
    if ($_ =~ '<PACKET ') {
      # read the full packet
      my $line;
      $pkt = "";
      do {
        $line = <INPUT>;
        chomp $line;
        if( !($line =~ '</PACKET>')) {
          $pkt = $pkt.$line;
        }
      } until ($line =~ '</PACKET>') || eof;

      # parse it
      @tempHexBytes=split(/ /,$pkt);
      my $temp = hex($tempHexBytes[12].$tempHexBytes[13]);
      if ($temp eq $ethertype) {

        # get the events
        for ($i=64; $i<=$#tempHexBytes; $i=$i+4) {
          push @packetData,hex($tempHexBytes[$i].$tempHexBytes[$i+1].$tempHexBytes[$i+2].$tempHexBytes[$i+3]);
        }
      }
    }
  }
  close INPUT;


  my @foundEvents;
  print "parsing events\n";
  @foundEvents = parse_events(@packetData);
  print "done parsing events\n";

  print "\nFound events:\n";
  for $i ( 0..$#foundEvents ) {
    print $eventTypes[$i]." :: ";
    print @{$foundEvents[$i]};
    print "\n";
  }

  print "\nComparing events";
  my $eventType;
  my $done;
  my @foundEventList;
  my $foundEventLen;
  my $expectedEventIndex;
  my @numUnexpectedEvents;
  push @numUnexpectedEvents,0;
  # Loop over the event types, skip timestamps
  for $eventType ( 1..$#foundEvents ) {

    push @numUnexpectedEvents,0;
    @foundEventList = @{$foundEvents[$eventType]};
    # for each event found in event packets, find an event with the same length
    # in the expected events list and zero it out

    foreach $foundEventLen (@foundEventList) {
      $done = 0;

      for $expectedEventIndex (0..$#{$expectedEvents[$eventType]}) {
	if ($done==0 && $foundEventLen==$expectedEvents[$eventType][$expectedEventIndex]) {
	  $expectedEvents[$eventType][$expectedEventIndex] = 0;
	  $done = 1;
	} # if
      }	# for

      # only count as error if this is not the event output queue
      if ($done==0 && (($eventType > 3*($eventQueue+1)) || ($eventType < 3*$eventQueue+1))) {
	print "WARNING: Didn't expect event len $foundEventLen of type ".$eventTypes[$eventType]."\n";
	$numUnexpectedEvents[$eventType]+=1;
      }

    } # foreach
  } #for

  # find nonzero entries
  my @numUnaccountedEvents;
  my $num=0;
  push @numUnaccountedEvents,0 ; # don't count timestamps
  for $eventType ( 1..$#expectedEvents ) {
    $num=0;
    for $expectedEventIndex (0..$#{$expectedEvents[$eventType]}) {
      if ($expectedEvents[$eventType][$expectedEventIndex]!=0) {
	$num++;
	print "WARNING: Expected event length $expectedEvents[$eventType][$expectedEventIndex], type ".$eventTypes[$eventType]." did not occur.\n";
      }
    }
    push @numUnaccountedEvents,$num ;
  }

  $error=0;
  print "Number of expected events that didn't occur:\n";
  for $expectedEventIndex (0..$#expectedEvents) {
    print $eventTypes[$expectedEventIndex]." :: ".$numUnaccountedEvents[$expectedEventIndex]."\n";
    $error += $numUnaccountedEvents[$expectedEventIndex];
  }

  print "\nNumber of unexpected events that occurred:\n";
  for $expectedEventIndex (0..$#expectedEvents) {
    print $eventTypes[$expectedEventIndex]." :: ".$numUnexpectedEvents[$expectedEventIndex]."\n";
    $error += $numUnaccountedEvents[$expectedEventIndex];
  }

  if($error>$allowed_num_errors) {
    return 1;
  }
  else {
    return 0;
  }

}

1;

