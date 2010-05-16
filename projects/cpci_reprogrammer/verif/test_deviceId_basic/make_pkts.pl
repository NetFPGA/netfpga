#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
#

use NF::Base ('projects/cpci/lib/Perl5');
use NF::PacketGen;
use NF::PacketLib;
use reg_defines_cpci_reprogrammer;
use reg_defines_cpci ();

$delay = 2000;
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

my $delay = 1000;



nf_PCI_read32($delay, 0, DEV_ID_MD5_0_REG(), DEV_ID_MD5_VALUE_V2_0());
$delay = 0;
nf_PCI_read32($delay, 0, DEV_ID_MD5_1_REG(), DEV_ID_MD5_VALUE_V2_1());
nf_PCI_read32($delay, 0, DEV_ID_MD5_2_REG(), DEV_ID_MD5_VALUE_V2_2());
nf_PCI_read32($delay, 0, DEV_ID_MD5_3_REG(), DEV_ID_MD5_VALUE_V2_3());
nf_PCI_read32($delay, 0, DEV_ID_DEVICE_ID_REG(), DEVICE_ID());
nf_PCI_read32($delay, 0, DEV_ID_VERSION_REG(),
	(DEVICE_MAJOR() << 16) | (DEVICE_MINOR() << 8) | (DEVICE_REVISION() << 0));
nf_PCI_read32($delay, 0, DEV_ID_CPCI_ID_REG(),
	(reg_defines_cpci::CPCI_REVISION_ID() << 24) |
	reg_defines_cpci::CPCI_VERSION_ID());

readStr(DEV_ID_PROJ_DIR_0_REG(), DEV_ID_PROJ_DIR_WORD_LEN(), DEVICE_PROJ_DIR());
readStr(DEV_ID_PROJ_NAME_0_REG(), DEV_ID_PROJ_NAME_WORD_LEN(), DEVICE_PROJ_NAME());
readStr(DEV_ID_PROJ_DESC_0_REG(), DEV_ID_PROJ_DESC_WORD_LEN(), DEVICE_PROJ_DESC());

# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');



#
# readStr
#   Read a string from a register address
#   Note: String will be null-padded to the right
#
# Params:
#   addr -- Address to read from
#   len  -- Number of words to read
#   str  -- String to expect
#
sub readStr {
	my ($addr, $len, $str) = @_;

	for (my $i = 0; $i < $len; $i++) {
		my $substr = '';
		if ($i * 4 < length($str)) {
			$substr = substr($str, $i * 4, 4);
		}
		my $val = 0;
		for (my $j = 0; $j < 4; $j++) {
			$val <<= 8;
			$val |= ord(substr($substr, $j, 1)) if length($substr) > $j;
		}
		nf_PCI_read32($delay, 0, $addr + $i * 4, $val);
	}
}


