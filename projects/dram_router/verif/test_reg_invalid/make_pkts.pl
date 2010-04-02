#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
#

use NF::Base "projects/reference_router/lib/Perl5";
use NF::PacketGen;
use NF::PacketLib;
use SimLib;
use RouterLib;

use reg_defines_dram_router;
#require "reg_defines.ph";

$delay = 2000;
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

my $ROUTER_PORT_1_MAC = '00:ca:fe:00:00:01';
my $ROUTER_PORT_2_MAC = '00:ca:fe:00:00:02';
my $ROUTER_PORT_3_MAC = '00:ca:fe:00:00:03';
my $ROUTER_PORT_4_MAC = '00:ca:fe:00:00:04';

my $ROUTER_PORT_1_IP = '192.168.1.1';
my $ROUTER_PORT_2_IP = '192.168.2.1';
my $ROUTER_PORT_3_IP = '192.168.3.1';
my $ROUTER_PORT_4_IP = '192.168.4.1';


$delay = 0;

# Perform reads to "invalid" addresses

nf_PCI_read32($delay, 0, 0x0480000, 0xdeadbeef);
nf_PCI_read32($delay, 0, 0x0480004, 0xdeadbeef);
nf_PCI_read32($delay, 0, 0x0800000, 0xdeadbeef);
nf_PCI_read32($delay, 0, 0x0800004, 0xdeadbeef);
nf_PCI_read32($delay, 0, 0x3000000, 0xdeadbeef);
nf_PCI_read32($delay, 0, 0x3000004, 0xdeadbeef);

# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
