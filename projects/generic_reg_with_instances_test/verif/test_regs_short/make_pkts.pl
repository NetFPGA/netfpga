#!/usr/local/bin/perl -w
# make_pkts.pl
#

use NF::PacketGen;
use NF::PacketLib;
use SimLib;

use reg_defines_generic_reg_with_instances_test;

$delay = '@4us';
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

nf_PCI_read32('@12us', 0, REG_TEST_DISABLE_REG(), 0x1);
nf_PCI_read32(0, 0, REG_TEST_GRP_0_COUNT_A_REG(), 0x1);
nf_PCI_read32(0, 0, REG_TEST_GRP_0_COUNT_B_REG(), 0x2);
nf_PCI_read32(0, 0, REG_TEST_GRP_0_COUNT_C_REG(), 0x3);
nf_PCI_read32(0, 0, REG_TEST_GRP_1_COUNT_A_REG(), 0x4);
nf_PCI_read32(0, 0, REG_TEST_GRP_1_COUNT_B_REG(), 0x5);
nf_PCI_read32(0, 0, REG_TEST_GRP_1_COUNT_C_REG(), 0x6);
nf_PCI_read32(0, 0, REG_TEST_GRP_2_COUNT_A_REG(), 0x7);
nf_PCI_read32(0, 0, REG_TEST_GRP_2_COUNT_B_REG(), 0x8);
nf_PCI_read32(0, 0, REG_TEST_GRP_2_COUNT_C_REG(), 0x9);
nf_PCI_read32(0, 0, REG_TEST_GRP_3_COUNT_A_REG(), 0xa);
nf_PCI_read32(0, 0, REG_TEST_GRP_3_COUNT_B_REG(), 0xb);
nf_PCI_read32(0, 0, REG_TEST_GRP_3_COUNT_C_REG(), 0xc);
nf_PCI_read32(0, 0, REG_TEST_GRP_4_COUNT_A_REG(), 0xd);
nf_PCI_read32(0, 0, REG_TEST_GRP_4_COUNT_B_REG(), 0xe);
nf_PCI_read32(0, 0, REG_TEST_GRP_4_COUNT_C_REG(), 0xf);
nf_PCI_read32(0, 0, REG_TEST_GRP_5_COUNT_A_REG(), 0x10);
nf_PCI_read32(0, 0, REG_TEST_GRP_5_COUNT_B_REG(), 0x11);
nf_PCI_read32(0, 0, REG_TEST_GRP_5_COUNT_C_REG(), 0x12);
nf_PCI_read32(0, 0, REG_TEST_GRP_6_COUNT_A_REG(), 0x13);
nf_PCI_read32(0, 0, REG_TEST_GRP_6_COUNT_B_REG(), 0x14);
nf_PCI_read32(0, 0, REG_TEST_GRP_6_COUNT_C_REG(), 0x15);
nf_PCI_read32(0, 0, REG_TEST_GRP_7_COUNT_A_REG(), 0x16);
nf_PCI_read32(0, 0, REG_TEST_GRP_7_COUNT_B_REG(), 0x17);
nf_PCI_read32(0, 0, REG_TEST_GRP_7_COUNT_C_REG(), 0x18);

nf_PCI_read32(0, 0, REG_TEST_GRP_0_SW_A_REG(), 0x0);
nf_PCI_read32(0, 0, REG_TEST_GRP_1_SW_A_REG(), 0x1);
nf_PCI_read32(0, 0, REG_TEST_GRP_2_SW_A_REG(), 0x2);
nf_PCI_read32(0, 0, REG_TEST_GRP_3_SW_A_REG(), 0x3);
nf_PCI_read32(0, 0, REG_TEST_GRP_4_SW_A_REG(), 0x4);
nf_PCI_read32(0, 0, REG_TEST_GRP_5_SW_A_REG(), 0x5);
nf_PCI_read32(0, 0, REG_TEST_GRP_6_SW_A_REG(), 0x6);
nf_PCI_read32(0, 0, REG_TEST_GRP_7_SW_A_REG(), 0x7);


# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
