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

$delay = 5500;
# read status register, channels should not up, test not running, but successful (i.e. no errors)
nf_PCI_read32_masked( $delay, $batch, SERIAL_TEST_STATUS_0_REG(), 0, 0xf);
$delay = 0;
nf_PCI_read32_masked( $delay, $batch, SERIAL_TEST_STATUS_1_REG(), 0, 0xf);
nf_PCI_read32( $delay, $batch, SERIAL_TEST_STATUS_REG(),  1);

# run the test in nonstop mode
nf_PCI_write32( $delay, $batch, SERIAL_TEST_CTRL_REG(), 2);
$delay = 16000;
nf_PCI_read32_masked( $delay, $batch, SERIAL_TEST_STATUS_0_REG(), 0, 0xf);
$delay = 0;
nf_PCI_read32_masked( $delay, $batch, SERIAL_TEST_STATUS_1_REG(), 0, 0xf);
nf_PCI_read32( $delay, $batch, SERIAL_TEST_STATUS_REG(),  1);

# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


