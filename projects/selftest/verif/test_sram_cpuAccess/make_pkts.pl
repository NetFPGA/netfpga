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

# write 0xA to s1_wr_data_msb
nf_PCI_write32($delay, $batch, SRAM_MSB_SRAM1_WR_REG(), 0xA);

# write 0x5 to s2_wr_data_msb
nf_PCI_write32($delay, $batch, SRAM_MSB_SRAM2_WR_REG(), 0x5);

# write 0x12345678 to sram1 word 0
nf_PCI_write32($delay, $batch, SRAM_BASE_ADDR(), 0x12345678);

# write 0x87654321 to sram2 word (512K -1)
nf_PCI_write32($delay, $batch, SRAM_BASE_ADDR() * 1.5  + 2*0x100000 - 4, 0x87654321);

# read out 0x12345678 from sram1 word 0
nf_PCI_read32($delay, $batch, SRAM_BASE_ADDR(), 0x12345678);

# read out 0x87654321 from sram2 word (512K -1)
nf_PCI_read32($delay, $batch, SRAM_BASE_ADDR() * 1.5  + 2*0x100000 - 4, 0x87654321);

# read out 0xA from s1_rd_data_msb
nf_PCI_read32($delay, $batch, SRAM_MSB_SRAM1_RD_REG(), 0xA);

# read out 0x5 from s2_rd_data_msb
nf_PCI_read32($delay, $batch, SRAM_MSB_SRAM2_RD_REG(), 0x5);



# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


