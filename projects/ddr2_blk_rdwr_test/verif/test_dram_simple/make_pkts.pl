#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
#

use NF::PacketGen;
use NF::PacketLib;

my $total_success_reg_addr = 0x040_0000;
my $total_failure_reg_addr = 0x040_0004;

$delay = 0;
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

$delay = 500000 - 5000; # time required for wrt followed by rd over 50 blocks

# read total_success register
nf_PCI_read32($delay, $batch, $total_success_reg_addr, 0x3);

$delay = 0;
# read total_failure register
nf_PCI_read32($delay, $batch, $total_failure_reg_addr, 0x0);


# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


