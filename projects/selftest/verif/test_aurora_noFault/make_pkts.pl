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
# read status register, channels should be up, test running
nf_PCI_read32( $delay, $batch, SERIAL_TEST_STATUS_0_REG(),  3);
$delay = 0;
nf_PCI_read32( $delay, $batch, SERIAL_TEST_STATUS_1_REG(),  3);
nf_PCI_read32_masked( $delay, $batch, SERIAL_TEST_STATUS_REG(),  5, 0x7);

# read regs after we are done
$delay = 8000;
nf_PCI_read32( $delay, $batch, SERIAL_TEST_STATUS_0_REG(),  3);
$delay = 0;
nf_PCI_read32( $delay, $batch, SERIAL_TEST_STATUS_1_REG(),  3);
nf_PCI_read32_masked( $delay, $batch, SERIAL_TEST_STATUS_REG(),  3, 0x7);

#num pkts sent/rcvd
nf_PCI_read32( $delay, $batch, SERIAL_TEST_NUM_FRAMES_SENT_0_LO_REG(),  0x15);
nf_PCI_read32( $delay, $batch, SERIAL_TEST_NUM_FRAMES_RCVD_0_LO_REG(),  0x15);
nf_PCI_read32( $delay, $batch, SERIAL_TEST_NUM_FRAMES_SENT_1_LO_REG(),  0x15);
nf_PCI_read32( $delay, $batch, SERIAL_TEST_NUM_FRAMES_RCVD_1_LO_REG(),  0x15);

# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


