#!/usr/bin/perl

# This script parses wireshark/tethereal ascii dumps obtained
# by using tethereal -i ethX -x -s 1518 -l | filename
#
# The parsed file is split into packets and the all packets
# should have duplicates. This is used for phy looback testing.
#

my $filename = shift;
open (IN, $filename) || die("Could not open $filename\n");

# Read paragraphs
$/="";

# put the pkt dumps in a hash table. Since the hash
# table matches automatically, the counts are the values
# of the hash table.
my %hash_table=();

my $num_pkts=0;
foreach $paragraph (<IN>) {
  if($paragraph =~ /^0000/){
    $num_pkts++;
    $hash_table{$paragraph}++;
  }
}
close (IN);

# now check the counts of each pkt
my $num_errors=0;

my %seuenced_pkts=();
while (($pkt, $count) = each(%hash_table)){
  # if the packet has not been matched with a duplicate
  # then get the sequence number and put the packet in a bin
  if($count!=2) {
    print "ERROR: Packet below was captured $count times!\n$pkt";
    $num_errors++;
  }
}

# count the dropped packets
my $num_dropped=0;
while (($seq_num, $count) = each(%sequenced_pkts)){
  if($count==1){
    $num_dropped++;
  }
}

print "Processed $num_pkts pkts. Found $num_errors errors. Didn't capture $num_dropped pkts.\n";

1;
