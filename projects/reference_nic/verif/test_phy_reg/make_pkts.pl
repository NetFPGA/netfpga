#!/usr/local/bin/perl -w
# make_pkts.pl
#

use NF::PacketGen;
use NF::PacketLib;
use SimLib;

use reg_defines_reference_nic;

$delay = '@6us';
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

# read and write some data to PHY using MDIO regs
nf_PCI_write32($delay, $batch, MDIO_PHY_0_CONTROL_REG(), 0xabcd);
nf_PCI_read32($delay, $batch, MDIO_PHY_0_CONTROL_REG(), 0x0000abcd);
nf_PCI_write32($delay, $batch, MDIO_PHY_1_CONTROL_REG(), 0xab12);
nf_PCI_read32($delay, $batch, MDIO_PHY_1_CONTROL_REG(), 0xab12);
nf_PCI_write32($delay, $batch, MDIO_PHY_0_AUTONEGOTIATION_ADVERT_REG(), 0x34ce);
nf_PCI_read32($delay, $batch, MDIO_PHY_0_AUTONEGOTIATION_ADVERT_REG(), 0x34ce);

# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
