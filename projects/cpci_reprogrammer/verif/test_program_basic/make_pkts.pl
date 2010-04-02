#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
#

use NF::PacketGen;
use NF::PacketLib;
#use NF21RouterLib;
$delay = 2000;
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

my $PROGRAM_CTRL_addr = 0x0440000;
my $PROGRAM_RAM_BASE_addr = 0x0480000;


my $delay = 1000;
for (my $i = 0; $i < 4; $i++) {
   nf_PCI_write32($delay, 0, $PROGRAM_RAM_BASE_addr + $i * 4,
	   (($i * 4) << 24) |
	   (($i * 4 + 1) << 16) |
	   (($i * 4 + 2) << 8) |
	   (($i * 4 + 3)));
   $delay = 0;
}

nf_PCI_write32($delay, 0, $PROGRAM_CTRL_addr, 0x00000001);


# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
