#!/usr/bin/perl -w
# print_pkt_data.pl

use EvtsLib;

my $ethertype = 0x9999;

my $filename = '/nobackup/jnaous/verif/test_evts_full/packet_data/egress_port_1';
print "\n\n".$filename."\n";
print parse_evt_pkts($filename, $ethertype);

