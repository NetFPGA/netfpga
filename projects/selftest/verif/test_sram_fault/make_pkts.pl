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

$delay = 8000;
# read sram_en register
nf_PCI_read32( $delay, $batch, SRAM_TEST_EN_REG(), 0x0003001F );

$delay = 0;
# read done and fail register
# 5 tests are done for sram_0 and sram_1. all tests failed.
nf_PCI_read32( $delay, $batch, SRAM_TEST_STATUS_REG(), 0x1F1F1F1F );

# read error cnt. it should be 10
nf_PCI_read32( $delay, $batch, SRAM_TEST_ERR_CNT_REG(), 10);

##############################################################
# the first 5 error logs are errors from sram_0

# read error log register 0
read_log_regs( $delay, $batch, 0, 0x1, 0x0, 0x0, 0x1, 0x23456789);
read_log_regs( $delay, $batch, 1, 0x1, 0xF, 0xFFFFFFFF, 0x1, 0x23456789);
read_log_regs( $delay, $batch, 2, 0x1, 0x5, 0x55555555, 0x1, 0x23456789);
read_log_regs( $delay, $batch, 3, 0x1, 0xA, 0xAAAAAAAA, 0x1, 0x23456789);
read_log_regs( $delay, $batch, 4, 0x1, 0x0, 0x1, 0x1, 0x23456789);


###########################################################
# the 2nd 5 error logs are errors from sram_1

read_log_regs( $delay, $batch, 5, 0x80003, 0x0, 0x0, 0x9, 0x87654321);
read_log_regs( $delay, $batch, 6, 0x80003, 0xF, 0xFFFFFFFF, 0x9, 0x87654321);
read_log_regs( $delay, $batch, 7, 0x80003, 0x5, 0x55555555, 0x9, 0x87654321);
read_log_regs( $delay, $batch, 8, 0x80003, 0xA, 0xAAAAAAAA, 0x9, 0x87654321);
read_log_regs( $delay, $batch, 9, 0x80003, 0x0, 0x4, 0x9, 0x87654321);



# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');

exit 0;

# =============== Subroutines ========================
sub read_log_regs {
   my $delay = shift;
   my $batch = shift;

   # Which log location should we read from
   my $log_no = shift;

   # Address, expected and read data
   my $addr = shift;
   my $exp_data_hi = shift;
   my $exp_data_lo = shift;
   my $rd_data_hi = shift;
   my $rd_data_lo = shift;

   # Perform the reads
   # Addr
   nf_PCI_read32( $delay, $batch, SRAM_TEST_LOG_ADDR_REG() + $log_no * SRAM_TEST_LOG_OFFSET(), $addr);

   # read exp data
   nf_PCI_read32( 0, $batch, SRAM_TEST_LOG_EXP_DATA_HI_REG() + $log_no * SRAM_TEST_LOG_OFFSET(), $exp_data_hi);
   nf_PCI_read32( 0, $batch, SRAM_TEST_LOG_EXP_DATA_LO_REG() + $log_no * SRAM_TEST_LOG_OFFSET(), $exp_data_lo);

   # read actual data
   nf_PCI_read32( 0, $batch, SRAM_TEST_LOG_RD_DATA_HI_REG() + $log_no * SRAM_TEST_LOG_OFFSET(), $rd_data_hi);
   nf_PCI_read32( 0, $batch, SRAM_TEST_LOG_RD_DATA_LO_REG() + $log_no * SRAM_TEST_LOG_OFFSET(), $rd_data_lo);
}
