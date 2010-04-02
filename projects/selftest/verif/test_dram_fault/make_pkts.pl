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

# read done and fail register
# 5 tests are done respectively for the dram
$delay = 245000;
nf_PCI_read32( $delay, $batch, DRAM_TEST_STATUS_REG(), 0x00001f1f );

# read error cnt. it should be 0
$delay = 0;
nf_PCI_read32( $delay, $batch, DRAM_TEST_ERR_CNT_REG(), 5);

##############################################################
# Read the errors

# read error log register 0
# addr
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 0 + DRAM_TEST_LOG_ADDR_REG(), 0x4);

# read exp data
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 0 + DRAM_TEST_LOG_EXP_DATA_HI_REG(), 0x0);
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 0 + DRAM_TEST_LOG_EXP_DATA_LO_REG(), 0x0);

# read actual data
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 0 + DRAM_TEST_LOG_RD_DATA_HI_REG(),  0x0badbad0);
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 0 + DRAM_TEST_LOG_RD_DATA_LO_REG(), 0x0badbad0);

# read error log register 1
# addr
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 1 + DRAM_TEST_LOG_ADDR_REG(), 0x4);

# read exp data
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 1 + DRAM_TEST_LOG_EXP_DATA_HI_REG(), 0xffffffff);
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 1 + DRAM_TEST_LOG_EXP_DATA_LO_REG(), 0xffffffff);

# read actual data
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 1 + DRAM_TEST_LOG_RD_DATA_HI_REG(),  0x0badbad0);
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 1 + DRAM_TEST_LOG_RD_DATA_LO_REG(), 0x0badbad0);

# read error log register 2
# addr
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 2 + DRAM_TEST_LOG_ADDR_REG(), 0x4);

# read exp data
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 2 + DRAM_TEST_LOG_EXP_DATA_HI_REG(), 0x55555555);
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 2 + DRAM_TEST_LOG_EXP_DATA_LO_REG(), 0x55555555);

# read actual data
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 2 + DRAM_TEST_LOG_RD_DATA_HI_REG(),  0x0badbad0);
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 2 + DRAM_TEST_LOG_RD_DATA_LO_REG(), 0x0badbad0);

# read error log register 3
# addr
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 3 + DRAM_TEST_LOG_ADDR_REG(), 0x4);

# read exp data
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 3 + DRAM_TEST_LOG_EXP_DATA_HI_REG(), 0xaaaaaaaa);
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 3 + DRAM_TEST_LOG_EXP_DATA_LO_REG(), 0xaaaaaaaa);

# read actual data
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 3 + DRAM_TEST_LOG_RD_DATA_HI_REG(),  0x0badbad0);
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 3 + DRAM_TEST_LOG_RD_DATA_LO_REG(), 0x0badbad0);

# read error log register 4
# addr
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 4 + DRAM_TEST_LOG_ADDR_REG(), 0x4);

# read exp data
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 4 + DRAM_TEST_LOG_EXP_DATA_HI_REG(), 0x00000000);
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 4 + DRAM_TEST_LOG_EXP_DATA_LO_REG(), 0x00040004);

# read actual data
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 4 + DRAM_TEST_LOG_RD_DATA_HI_REG(),  0x0badbad0);
nf_PCI_read32( $delay, $batch, DRAM_TEST_LOG_OFFSET() * 4 + DRAM_TEST_LOG_RD_DATA_LO_REG(), 0x0badbad0);

# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


