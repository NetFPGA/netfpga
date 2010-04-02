#!/usr/bin/perl -w
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

# start the test

#write and read a single value
nf_PCI_write32(0, $batch, REG_FILE_BASE_ADDR() + 0x400, 0xFFFFFFFF);

nf_PCI_read32(0, $batch, REG_FILE_BASE_ADDR() + 0x400, 0xFFFFFFFF);


# write multiple values and read them back
nf_PCI_write32(0, $batch, REG_FILE_BASE_ADDR() + 0x408, 0x55555555);
nf_PCI_write32(0, $batch, REG_FILE_BASE_ADDR() + 0x404, 0xAAAAAAAA);

nf_PCI_read32(0, $batch, REG_FILE_BASE_ADDR() + 0x404, 0xAAAAAAAA);
nf_PCI_read32(0, $batch, REG_FILE_BASE_ADDR() + 0x408, 0x55555555);


# interleave reads and writes
nf_PCI_write32(0, $batch, REG_FILE_BASE_ADDR() + 0x424, 0xCCCCCCCC);
nf_PCI_read32(0, $batch, REG_FILE_BASE_ADDR() + 0x424, 0xCCCCCCCC);

nf_PCI_write32(0, $batch, REG_FILE_BASE_ADDR() + 0x450, 0xBBBBBBBB);
nf_PCI_read32(0, $batch, REG_FILE_BASE_ADDR() + 0x450, 0xBBBBBBBB);



# read everything back one last time

nf_PCI_read32(0, $batch, REG_FILE_BASE_ADDR() + 0x400, 0xFFFFFFFF);
nf_PCI_read32(0, $batch, REG_FILE_BASE_ADDR() + 0x404, 0xAAAAAAAA);
nf_PCI_read32(0, $batch, REG_FILE_BASE_ADDR() + 0x408, 0x55555555);
nf_PCI_read32(0, $batch, REG_FILE_BASE_ADDR() + 0x424, 0xCCCCCCCC);
nf_PCI_read32(0, $batch, REG_FILE_BASE_ADDR() + 0x450, 0xBBBBBBBB);


# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


