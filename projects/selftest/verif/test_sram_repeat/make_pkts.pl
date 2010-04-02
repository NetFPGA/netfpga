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
use vars qw($delay $batch);

# Attempt to start the self test in repeat mode
$delay = 0;
nf_PCI_write32( $delay, $batch, SRAM_TEST_CTRL_REG(), 0x00000002 );

# Disable auto-repeat
$delay = 5000;
nf_PCI_write32( $delay, $batch, SRAM_TEST_CTRL_REG(), 0x00000000 );

$delay = 3000;
# read sram_en register
nf_PCI_read32( $delay, $batch, SRAM_TEST_EN_REG(), 0x0003001F );

$delay = 0;
# read done and fail register
# 5 tests are done respectively for sram_0 and sram_1. all tests succeeded.
nf_PCI_read32( $delay, $batch, SRAM_TEST_STATUS_REG(), 0x001F001F );
nf_PCI_read32( $delay, $batch, SRAM_TEST_ITER_NUM_REG(), 0x00000005 );
nf_PCI_read32( $delay, $batch, SRAM_TEST_GOOD_RUNS_REG(), 0x00000005 );
nf_PCI_read32( $delay, $batch, SRAM_TEST_BAD_RUNS_REG(), 0x00000000 );

# read error cnt. it should be 0
nf_PCI_read32( $delay, $batch, SRAM_TEST_ERR_CNT_REG(), 0);


# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


