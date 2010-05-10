#!/usr/local/bin/perl -w
# make_pkts.pl
#

use NF::PacketGen;
use NF::PacketLib;
use SimLib;

use reg_defines_reference_nic;

$delay = '@4us';
$batch = 0;
nf_set_environment( { PORT_MODE => 'PHYSICAL', MAX_PORTS => 4 } );

# use strict AFTER the $delay, $batch and %reg are declared
use strict;
use vars qw($delay $batch %reg);

# Prepare the DMA and enable interrupts
prepare_DMA('@3.9us');
enable_interrupts(0);

my $length = 100;
my $DA_sub = ':dd:dd:dd:dd:dd';
my $SA_sub = ':55:55:55:55:55';
my $DA;
my $SA;
my $pkt;
my $in_port;
my $out_port;
my $i = 0;
my $temp;

# Send a packet in via DMA
$delay = '@10us';
$length = 60;
$in_port = 1;
PCI_create_and_send_pkt($in_port, $length);

# check counter values
$delay='@15us';
nf_PCI_read32($delay, $batch, DMA_CTRL_REG(), 0x0);
nf_PCI_read32($delay, $batch, DMA_NUM_INGRESS_PKTS_REG(), 0x1);
nf_PCI_read32($delay, $batch, DMA_NUM_INGRESS_BYTES_REG(), 0x3c);
nf_PCI_read32($delay, $batch, DMA_NUM_EGRESS_PKTS_REG(), 0x0);
nf_PCI_read32($delay, $batch, DMA_NUM_EGRESS_BYTES_REG(), 0x0);
nf_PCI_read32($delay, $batch, DMA_NUM_TIMEOUTS_REG(), 0x0);

nf_PCI_read32($delay, $batch, CPU_QUEUE_0_CONTROL_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_ENQUEUED_REG(), 0x1);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_DEQUEUED_REG(), 0x1);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_UNDERRUNS_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_OVERRUNS_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_WORDS_PUSHED_REG(), 0x8);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0x3c);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_PKTS_ENQUEUED_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_PKTS_DEQUEUED_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_UNDERRUNS_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_OVERRUNS_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_WORDS_PUSHED_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_BYTES_PUSHED_REG(), 0x0);

# Send a packet in an ethernet port and expect via DMA
$delay = '@35us';
$DA = '00' . $DA_sub;
$SA = '00' . $SA_sub;
$pkt = make_IP_pkt($length, $DA, $SA, 64, '192.168.0.1', '192.168.0.2');
nf_packet_in($in_port, $length, $delay, $batch,  $pkt);
nf_expected_dma_data($in_port, $length, $pkt);

# check counter values
$delay='@40us';
nf_PCI_read32($delay, $batch, DMA_CTRL_REG(), 0x0);
nf_PCI_read32($delay, $batch, DMA_NUM_INGRESS_PKTS_REG(), 0x1);
nf_PCI_read32($delay, $batch, DMA_NUM_INGRESS_BYTES_REG(), 0x3c);
nf_PCI_read32($delay, $batch, DMA_NUM_EGRESS_PKTS_REG(), 0x1);
nf_PCI_read32($delay, $batch, DMA_NUM_EGRESS_BYTES_REG(), 0x3c);
nf_PCI_read32($delay, $batch, DMA_NUM_TIMEOUTS_REG(), 0x0);

nf_PCI_read32($delay, $batch, CPU_QUEUE_0_CONTROL_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_ENQUEUED_REG(), 0x1);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_PKTS_DEQUEUED_REG(), 0x1);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_UNDERRUNS_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_OVERRUNS_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_WORDS_PUSHED_REG(), 0x8);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_RX_QUEUE_NUM_BYTES_PUSHED_REG(), 0x3c);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_PKTS_ENQUEUED_REG(), 0x1);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_PKTS_DEQUEUED_REG(), 0x1);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_UNDERRUNS_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_OVERRUNS_REG(), 0x0);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_WORDS_PUSHED_REG(), 0x8);
nf_PCI_read32($delay, $batch, CPU_QUEUE_0_TX_QUEUE_NUM_BYTES_PUSHED_REG(), 0x3c);

# *********** Finishing Up - need this in all scripts ! ****************************
my $t = nf_write_sim_files();
print  "--- make_pkts.pl: Generated all configuration packets.\n";
printf "--- make_pkts.pl: Last packet enters system at approx %0d microseconds.\n",($t/1000);
if (nf_write_expected_files()) {
  die "Unable to write expected files\n";
}

nf_create_hardware_file('LITTLE_ENDIAN');
nf_write_hardware_file('LITTLE_ENDIAN');
