#!/usr/local/bin/perl -w
# make_pkts.pl
#
#
#

use NF::PacketGen;
use NF::PacketLib;

use SimLib;

$delay = 0;
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay and $batch are declared
use strict;
use vars qw($delay $batch);

########################################

# Check to ensure that all RCP registers default to their correct values
## for (my $i = 0; $i < 4; $i++) {
##   nf_PCI_read32( $delay, $batch, $reg{"UNET_RCP_in_traffic_${i}_reg"}, 0x0);
##   nf_PCI_read32( $delay, $batch, $reg{"UNET_RCP_q_occupancy_${i}_reg"}, 0x0);
##   nf_PCI_read32( $delay, $batch, $reg{"UNET_RCP_timeslot_elapsed_${i}_reg"}, 0x0);
##   nf_PCI_read32( $delay, $batch, $reg{"UNET_RCP_curr_timeslot_${i}_reg"}, $reg{"MIN_RATE_EST_INTERVAL"});
##   nf_PCI_read32( $delay, $batch, $reg{"UNET_RCP_fwd_rate_${i}_reg"}, $reg{"INIT_RATE"});
##
##   nf_PCI_read32( $delay, $batch, $reg{"UNET_RCP_sum_rtt_${i}_reg"}, 0);
##   nf_PCI_read32( $delay, $batch, $reg{"UNET_RCP_in_traffic_rtt_${i}_reg"}, 0);
## }



# *********** Finishing Up - need this in all scripts ! **********************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');


