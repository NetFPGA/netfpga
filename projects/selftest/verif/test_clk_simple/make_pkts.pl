#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
#

use NF::PacketGen;
use NF::PacketLib;
use SimLib;

use reg_defines_selftest;

$delay = 0;
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay and $batch are declared
use strict;
use vars qw($delay $batch %reg);

# Attempt to read a word -- don't care about the result
# although at least the MSBs should be zero (the counter shouldn't have
# started to increment the upper bits yet)
$delay = 3000;
nf_PCI_read32_masked ( $delay, $batch, CLOCK_TEST_TICKS_REG(), 0x00000000, 0xffff0000);

# Attempt to read a word -- don't care about the result
# although at least the MSBs should be zero (the counter shouldn't have
# started to increment the upper bits yet)
nf_PCI_read32_masked ( $delay, $batch, CLOCK_TEST_TICKS_REG(), 0x00000000, 0xffff0000);


# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


