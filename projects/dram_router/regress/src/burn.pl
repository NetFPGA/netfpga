#!/usr/bin/perl
#/usr/pubsw/bin/perl -w
# Author: Brandon Heller
# Date: 11/21/2007

# BUGS:
# -NUM_WORDS not handled right for some packet sizes - probably not accounting for CRC
#   or wrong word size assumption

# TODO:
# -change file write location to a user-independent one

use strict;
use NF::Base "projects/reference_router/lib/Perl5";
use NF::RegressLib;
use RegressRouterLib;
use NF::PacketLib;
use Getopt::Long;
use File::Copy;
use NF::Base;
use Time::HiRes qw (sleep gettimeofday tv_interval usleep);
use IO::Handle; # added for file autoflush

use reg_defines_dram_router;

#------------------------------------------------------------------------------
# main script params
my $num_ports = 2; # ports to send on
my $internal_loopback = '';
my $print_all_stats = 1;
my $filename = ">>/home/brandonh/burn_log";
my $print_to_console = '1';
my $expect = ''; # control whether expected packets are sent to TestLib.pm
my $run_length = 10; # seconds
my $print_interval = 1; # seconds
my $load_timeout =  1.0; # seconds - may need to be increased for small packets and/or slow system
my $empty_timeout = 1.0; # seconds to empty queues at end
my $len = 1496;
my $desired_q_occ_fraction = .75;
my $packets_to_loop = 255; # forwarding reps
my $ignore_load_timeout = 1;
my $batch_size = 1;

unless ( GetOptions (
			  "num_ports=i" => \$num_ports,
			  "internal_loopback" => \$internal_loopback,
			  "print_all_stats" => \$print_all_stats,
			  "filename=s" => \$filename,
			  "print_to_console!" => \$print_to_console,
			  "expect" => \$expect,
			  "run_length=f" => \$run_length,
			  "print_interval=f" => \$print_interval,
			  "load_timeout=f" => \$load_timeout,
			  "empty_timeout=f" => \$empty_timeout,
			  "len=i" => \$len,
			  "desired_q_occ_fraction=f" => \$desired_q_occ_fraction,
			  "packets_to_loop=i" => \$packets_to_loop,
			  "ignore_load_timeout!" => \$ignore_load_timeout,
			  "batch_size=i" => \$batch_size
		       		)
       )
{
	print "invalid options...exiting\n";
	exit 1;
}

if ($print_to_console) {
	print "printing to console\n";
}
else {
	open(LOGFILE, $filename); #open for write, append
	LOGFILE->autoflush(1);
}

#------------------------------------------------------------------------------
# fixed constants
use constant BUFFER_SIZE_PER_PORT => 512000; # bytes
use constant NUM_2_32 => 4294967296; # 2 ^ 32;use Getopt::Long;

my $routerMAC0 = "00:ca:fe:00:00:01";
my $routerMAC1 = "00:ca:fe:00:00:02";
my $routerMAC2 = "00:ca:fe:00:00:03";
my $routerMAC3 = "00:ca:fe:00:00:04";

sub my_print {
	if ($print_to_console) {
		print @_;
	}
	else {
		print LOGFILE @_;
	}
}

sub my_printf {
	if ($print_to_console) {
		printf @_;
	}
	else {
		printf LOGFILE @_;
	}
}

my $desired_q_occ = (BUFFER_SIZE_PER_PORT) / $len * $desired_q_occ_fraction;

#print "desired q occ: ", $desired_q_occ, "\n";
#my $desired_q_occ = 200; # desired queue occupancy in number of packets

#my_print "run length = ", $run_length, "\n";

my @interfaces = ("nf2c0", "nf2c1", "nf2c2", "nf2c3", "eth1", "eth2");
nftest_init(\@ARGV,\@interfaces,);
#nftest_start(\@interfaces);
#nftest_fpga_reset('nf2c0');

for (my $i = 0; $i < $num_ports; $i++)
{
	nftest_set_router_MAC ("nf2c$i", eval "\$routerMAC$i");
}

# put all ports in internal_loopback mode if specified
if ($internal_loopback) {
	for (my $i = 0; $i < $num_ports; $i++) {
		nftest_phy_loopback("nf2c$i");
	}
	my_print "in internal loopback mode\n";
}

# clear LPM table
for (my $i = 0; $i < 32; $i++)
{
  nftest_invalidate_LPM_table_entry('nf2c0', $i);
}

# clear ARP table
for (my $i = 0; $i < 32; $i++)
{
  nftest_invalidate_ARP_table_entry('nf2c0', $i);
}

#print "\n";

# add LPM and ARP entries for each port
for (my $i = 0; $i < $num_ports; $i++) {

	my $i_plus_1 = $i + 1;
	my $subnetIP = "192.168.$i_plus_1.1";
	my $subnetMask = "255.255.255.255";
	my $nextHopIP = "192.168.5.$i_plus_1";
	my $outPort = 1 << (2 * $i);
	my $nextHopMAC = get_dest_MAC($i);

#	print "subnetIP:", $subnetIP, "\n";
#	print "nextHopIP:", $nextHopIP, "\n";
#	print "nextHopMAC:", $nextHopMAC, "\n";my $outPort = 1 << (2 * $i);
#	print "outPort:", $outPort, "\n";

	# add an entry in the routing table
	nftest_add_LPM_table_entry ('nf2c0',
			    $i,
			    $subnetIP,
			    $subnetMask,
			    $nextHopIP,
			    $outPort);

	# add an entry in the ARP table
	nftest_add_ARP_table_entry('nf2c0',
			   $i_plus_1,
			   $nextHopIP,
			   $nextHopMAC);
}

# reset counters
my @counters_to_clear = (
	'MAC_GRP_X_RX_QUEUE_NUM_PKTS_STORED_REG()',
	'MAC_GRP_X_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG()',
	'MAC_GRP_X_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG()',
	'MAC_GRP_X_RX_QUEUE_NUM_WORDS_PUSHED_REG()',
	'MAC_GRP_X_RX_QUEUE_NUM_BYTES_PUSHED_REG()',
	'MAC_GRP_X_RX_QUEUE_NUM_PKTS_DEQUEUED_REG()',
	'MAC_GRP_X_RX_QUEUE_NUM_PKTS_IN_QUEUE_REG()',
	'MAC_GRP_X_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG()',
	'MAC_GRP_X_TX_QUEUE_NUM_PKTS_SENT_REG()',
	'MAC_GRP_X_TX_QUEUE_NUM_WORDS_PUSHED_REG()',
	'MAC_GRP_X_TX_QUEUE_NUM_BYTES_PUSHED_REG()',
	'MAC_GRP_X_TX_QUEUE_NUM_PKTS_ENQUEUED_REG()'
);

for (my $i = 0; $i < $num_ports; $i++) {
	foreach my $reg (@counters_to_clear) {
		# replace _X_ in regname with port number
		my $regcopy = $reg;
		$regcopy =~ s/_X_/_${i}_/;
		nftest_regwrite("nf2c0", eval $regcopy, 0);
		#my_print "$regcopy\n";
	}
}

nftest_regwrite("nf2c0", ROUTER_OP_LUT_NUM_CPU_PKTS_SENT_REG(), 0);
nftest_regwrite("nf2c0", ROUTER_OP_LUT_NUM_PKTS_FORWARDED_REG(), 0);

my_print "reset counters\n";

# create 'sent' and 'expected' packets for each port
my @expected_pkts;
my @sent_pkts;
for (my $i = 0; $i < $num_ports; $i++) {

	my $i_plus_1 = $i + 1;

	# set parameters
	my $DA = get_dest_MAC($i);
	my $SA = "aa:bb:cc:dd:ee:ff";
	my $TTL = $packets_to_loop;
	my $DST_IP = "192.168.$i_plus_1.1";
	my $SRC_IP = "192.168.0.1";
	my $nextHopMAC = get_dest_MAC($i);

	# create MAC header
	my $MAC_hdr = NF::Ethernet_hdr->new(DA => $DA,
						     SA => $SA,
						     Ethertype => 0x800
				    		);

	#create IP header
	my $IP_hdr = NF::IP_hdr->new(ttl => $TTL,
					      src_ip => $SRC_IP,
					      dst_ip => $DST_IP,
					      dgram_len => $len - $MAC_hdr->length_in_bytes()
			    		 );

	$IP_hdr->checksum(0);  # make sure its zero before we calculate it
	$IP_hdr->checksum($IP_hdr->calc_checksum);

	# create packet filling.... (IP PDU)
	my $PDU = NF::PDU->new($len - $MAC_hdr->length_in_bytes() - $IP_hdr->length_in_bytes() );
	my $start_val = $MAC_hdr->length_in_bytes() + $IP_hdr->length_in_bytes()+1;
#	my @data = ($start_val..$len);
#	for (@data) {$_ %= 100}
#	$PDU->set_bytes(@data);

	# get packed packet string
	my $sent_pkt = $MAC_hdr->packed . $IP_hdr->packed . $PDU->packed;

	# create the expected packet
	my $MAC_hdr2 = NF::Ethernet_hdr->new(DA => get_dest_MAC(0),
						     SA => get_dest_MAC(0),
						     Ethertype => 0x800
				    		);

	$IP_hdr->ttl(1); # TTL is 1 when packet is kicked up to Linux
	$IP_hdr->checksum(0);  # make sure its zero before we calculate it
	$IP_hdr->checksum($IP_hdr->calc_checksum);

	my $expected_pkt = $MAC_hdr2->packed . $IP_hdr->packed . $PDU->packed;

	push @sent_pkts, $sent_pkt;
	push @expected_pkts, $expected_pkt;
}

my_print "start time: ", scalar localtime, "\n";
for (my $i = 0; $i < $num_ports; $i++)
{
	my_print nftest_regread("nf2c0", get_q_num_pkts_reg($i)), " ";
}
my_print "\n";

my @packets_sent = 0;

# fill queues up to desired occupancy
my $q_size = 0;
my @load_time_start = gettimeofday();
my $queues_all_filled = 0;
while (($queues_all_filled == 0) and (tv_interval(\@load_time_start) < $load_timeout)) {

	$queues_all_filled = 1;
	for (my $i = 0; $i < $num_ports; $i++) {
		my $q_size = nftest_regread("nf2c0", get_q_num_pkts_reg($i));
		my $queue_filled = ($q_size > $desired_q_occ) ? 1 : 0;
		# send packet if queue not filled
		if ($queue_filled == 0) {
			nftest_send("nf2c$i", $sent_pkts[$i], 0);
			if ($expect) { nftest_expect("nf2c$i", $expected_pkts[$i]); }
			$packets_sent[$i]++;
		}
		$queues_all_filled &= $queue_filled;
	}
}

my $load_time = tv_interval(\@load_time_start);

my @post_load_queues;
my_print "q after:\n";
for (my $i = 0; $i < $num_ports; $i++)
{
	$post_load_queues[$i] = nftest_regread("nf2c0", get_q_num_pkts_reg($i));
	my_print $post_load_queues[$i], " ";
}
my_print "\n";

my @load_pkts_sent;
my_print "pkts sent while loading queues\n";
for (my $i = 0; $i < $num_ports; $i++)
{
	$load_pkts_sent[$i] = $packets_sent[$i];
	my_print $load_pkts_sent[$i], " ";
}
my_print "\n";

if (($load_time > $load_timeout) and !$ignore_load_timeout){
	my_print "ERROR: loading queues timed out after ", $load_time, " seconds \n";
	for (my $i = 0; $i < $num_ports; $i++) {
		my_print nftest_regread("nf2c0", get_q_num_pkts_reg($i)), " ";
	}
	my_print "\n";
	#exit 1;
}
elsif (($load_time > $load_timeout) and $ignore_load_timeout) {
	my_print "seconds tried to fill queues = ", $load_time, ", but continuing anyway\n";
}
else {
	my_print "seconds to fill queues = ", $load_time, "\n";
}

my @min_q_sizes;
my @max_q_sizes;
for (my $i = 0; $i < $num_ports; $i++) { $min_q_sizes[$i] = 1000000; $max_q_sizes[$i] = 0; }
my @avg_q_sizes;
my @q_size_totals;
my @q_size_samples;

my $min_q_size = 1000000;
my $max_q_size = 0;
my $avg_q_size = 0;
my $q_size_total = 0;
my $q_size_sample = 0;

# maintain the desired queue occupancy by sending packets as necessary
my $elapsed_time = 0;
my @start_time = gettimeofday();
my @last_print = @start_time;
my $print_count = 0;
while ($elapsed_time < $run_length)
{
	my @q_sizes;
	$queues_all_filled = 1;

	for (my $i = 0; $i < $num_ports; $i++) {
		my $q_size = nftest_regread("nf2c0", get_q_num_pkts_reg($i));
		my $queue_filled = ($q_size > $desired_q_occ) ? 1 : 0;
		# send packet if queue not filled
		if ($queue_filled == 0) {
			for (my $j = 0; $j < $batch_size; $j++) {
				nftest_send("nf2c$i", $sent_pkts[$i], 0);
				if ($expect) { nftest_expect("nf2c$i", $expected_pkts[$i]); }
				$packets_sent[$i]++;
			}
		}
		$queues_all_filled &= $queue_filled;

		# update stats
		$q_size_samples[$i]++;
		$q_size_totals[$i] += $q_size;
		if ($q_size < $min_q_sizes[$i]) { $min_q_sizes[$i] = $q_size; }
		if ($q_size > $max_q_sizes[$i]) { $max_q_sizes[$i] = $q_size; }
		$q_sizes[$i] = $q_size;
	}

	my @now = gettimeofday();
	$elapsed_time = tv_interval(\@start_time, \@now);

	if (tv_interval(\@last_print, \@now) > $print_interval) {
		$print_count++;
		my_print "$print_count ";
		for (my $i = 0; $i < $num_ports; $i++) { my_print "$q_sizes[$i] "; }
		my_print "\n";
		@last_print = @now;
	}
}
my $sending_time = tv_interval(\@start_time);

# wait until all queues empty, with timeout
$elapsed_time = 0;
my @empty_start_time = gettimeofday();
my $queues_all_empty = 0;
while (($queues_all_empty == 0) and (tv_interval(\@empty_start_time) < $empty_timeout))
{
	$queues_all_empty = 1;
	for (my $i = 0; $i < $num_ports; $i++) {
		my $q_size = nftest_regread("nf2c0", get_q_num_pkts_reg($i));
		my $queue_empty = ($q_size == 0) ? 1 : 0;
		$queues_all_empty &= $queue_empty;
	}
}
my $empty_time = tv_interval(\@empty_start_time);

if ($empty_time > $empty_timeout) {
	my_print "ERROR: emptying queues timed out after ", $empty_time, " seconds\n";
	for (my $i = 0; $i < $num_ports; $i++) {
		my_print nftest_regread("nf2c0", get_q_num_pkts_reg($i)), " ";
	}
	my_print "\n";
	#exit 1;
}
else {
	my_print "seconds to empty queues = ", $empty_time, "\n";
}

# sleep because packets with a nonzero TTL have have been circulating
# when we say all queues equal zero, up to $packets_to_loop times
# I've seen at most 3 packets "in flight"
# so we sleep 3 * 255 * ~12us (for 1500B packet) = 9180us
sleep .2;

my_print "finished\n";

# print unmatched packets
my $unmatched_hoh = nftest_finish();
# no need to print errors - at high speeds, app-level drops will occur,
# plus when 'expect' is not set the packets are not reported to testLib anyway.
#$total_errors += nftest_print_errors($unmatched_hoh);

# print statistics
my_print "finish time: ", scalar localtime, "\n";
my_print "sending interval: ", $sending_time, "\n";
my_print "seconds to fill queue = ", $load_time, "\n";
my_print "seconds to empty queue = ", $empty_time, "\n";

my $packets_sent_avg;
my @interface_bws;
my $interface_bw;
for (my $i = 0; $i < $num_ports; $i++) {

	$avg_q_sizes[$i] = $q_size_totals[$i] / $q_size_samples[$i];
	$avg_q_size += $avg_q_sizes[$i];
	if ($min_q_sizes[$i] < $min_q_size ) { $min_q_size = $min_q_sizes[$i]; }
	if ($max_q_sizes[$i] > $max_q_size ) { $max_q_size = $max_q_sizes[$i]; }
	$packets_sent_avg += $packets_sent[$i];
	# interface bw in Mbps
	$interface_bws[$i] = (($packets_sent[$i] - $load_pkts_sent[$i]) * $packets_to_loop * $len * 8) / ($sending_time * 1000000);
	$interface_bw += $interface_bws[$i];

	if ($print_all_stats == 1) {
		my_print "stats for interface nf2c$i:\n";
		my_print "\tmin q size: ", $min_q_sizes[$i], "\n";
		my_print "\tmax q size: ", $max_q_sizes[$i], "\n";
		my_printf "\tavg q size: %.2f\n", $avg_q_sizes[$i];
		my_print "\tpackets sent from cpu: ", $packets_sent[$i], "\n";
		my_print "\tbytes sent from cpu: ", $packets_sent[$i] * $len, "\n";
		my_print "\tpackets forwarded via loopback: ", $packets_sent[$i] * $packets_to_loop, "\n";
		my_print "\tbytes forwarded via loopback: ", $packets_sent[$i] * $len * $packets_to_loop, "\n";
		my_printf "\tinterface bw: %04f Mbps\n", $interface_bws[$i];
	}
}

$avg_q_size /= $num_ports;
$packets_sent_avg /= $num_ports;
$interface_bw /= $num_ports;

my_print "stats for all interfaces (averaged):\n";
my_print "\tmin q size: ", $min_q_size, "\n";
my_print "\tmax q size: ", $max_q_size, "\n";
my_printf "\tavg q size: %.2f\n", $avg_q_size;
my_print "\tpackets sent from cpu: ", $packets_sent_avg, "\n";
my_print "\tbytes sent from cpu: ", $packets_sent_avg * $len, "\n";
my_print "\tpackets forwarded via loopback: ", $packets_sent_avg * $packets_to_loop, "\n";
my_print "\tbytes forwarded via loopback: ", $packets_sent_avg * $len * $packets_to_loop, "\n";
my_printf "\tinterface bw: %04f Mbps\n", $interface_bw;

# compare packet and byte counters
# note: need to be careful here with 32-bit wraparound, hence mod 2^32
my_print "comparing counters...\n";
my $total_errors = 0;
my %reg_expected_hash = (
	'"MAC_GRP_${i}_RX_QUEUE_NUM_PKTS_STORED_REG()"' =>
		'"($packets_to_loop * $packets_sent[$p]) % NUM_2_32"',
	'"MAC_GRP_${i}_RX_QUEUE_NUM_PKTS_DROPPED_FULL_REG()"' =>
		'"0"',
	'"MAC_GRP_${i}_RX_QUEUE_NUM_PKTS_DROPPED_BAD_REG()"' =>
		'"0"',
	'"MAC_GRP_${i}_RX_QUEUE_NUM_WORDS_PUSHED_REG()"' =>
		'"($packets_to_loop * $packets_sent[$p] * (($len >> 3) << 3) / 8) % NUM_2_32"',
	'"MAC_GRP_${i}_RX_QUEUE_NUM_BYTES_PUSHED_REG()"' =>
		'"($packets_to_loop * $packets_sent[$p] * $len) % NUM_2_32"',
	'"MAC_GRP_${i}_RX_QUEUE_NUM_PKTS_DEQUEUED_REG()"' =>
		'"($packets_to_loop * $packets_sent[$p]) % NUM_2_32"',
	'"MAC_GRP_${i}_RX_QUEUE_NUM_PKTS_IN_QUEUE_REG()"' =>
		'"0"',
	'"MAC_GRP_${i}_TX_QUEUE_NUM_PKTS_IN_QUEUE_REG()"' =>
		'"0"',
	'"MAC_GRP_${i}_TX_QUEUE_NUM_PKTS_SENT_REG()"' =>
		'"($packets_to_loop * $packets_sent[$i]) % NUM_2_32"',
	'"MAC_GRP_${i}_TX_QUEUE_NUM_WORDS_PUSHED_REG()"' =>
		'"($packets_to_loop * $packets_sent[$i] * (($len >> 3) << 3) / 8) % NUM_2_32"',
	'"MAC_GRP_${i}_TX_QUEUE_NUM_BYTES_PUSHED_REG()"' =>
		'"($packets_to_loop * $packets_sent[$i] * $len) % NUM_2_32"',
	'"MAC_GRP_${i}_TX_QUEUE_NUM_PKTS_ENQUEUED_REG()"' =>
		'"($packets_to_loop * $packets_sent[$i]) % NUM_2_32"'
);

# verify counters for each port
for (my $i = 0; $i < $num_ports; $i++) {
	my $regname;
	my $expected;
	my $result;
	my $p = get_transmitting_port($i);
	my_print "checking port $i with transmitting port $p\n";
	while (($regname, $expected) = each(%reg_expected_hash))
	{
	     verify_reg( eval $regname, eval eval $expected, \$total_errors);
	}
}

for (my $i = 0; $i < $num_ports; $i++) {
	# note that with wraparound we may get wild differences
	my $p = get_transmitting_port($i);
	my $reg = eval "MAC_GRP_${i}_RX_QUEUE_NUM_PKTS_STORED_REG()";
	my $stored = nftest_regread("nf2c0", $reg);
	my $expected = ($packets_to_loop * $packets_sent[$p]) % NUM_2_32;
	my $pkts_missed = $stored - $expected;
	my $pkts_missed_div = $pkts_missed / $packets_to_loop;
	my $multiple = (($pkts_missed % $packets_to_loop) == 0) ? 1 : 0;
	if ($pkts_missed != 0) {
		my_print "ERROR: *Port $i rx received $pkts_missed extra\n";
		if ($multiple == 1) {
			my_print "\t packets are even multiple of packets_to_loop: $pkts_missed_div\n";
		}
		else {
			my_print "\t packets NOT even multiple of packets_to_loop: $pkts_missed_div\n";
		}
	}
}

if ($internal_loopback) {
	nftest_reset_phy();
}



my_print "*****************************************************\n";

if ($total_errors == 0) {
 	print "SUCCESS!\n";
	exit 0;
}
else {
 	print "FAIL: $total_errors errors\n";
	exit 1;
}

#-----------------------------------------------------------------------------
sub get_dest_MAC {
	my $i = shift;
	my $i_plus_1 = $i + 1;
	if ($internal_loopback) {
		return "00:ca:fe:00:00:0$i_plus_1";
	}
	else
	{
		if ($i == 0) { return "00:ca:fe:00:00:02"; }
		if ($i == 1) { return "00:ca:fe:00:00:01"; }
		if ($i == 2) { return "00:ca:fe:00:00:04"; }
		if ($i == 3) { return "00:ca:fe:00:00:03"; }
	}
}

sub get_q_num_pkts_reg {
	my $i = shift;
	if ($i == 0) { return OQ_QUEUE_0_NUM_PKTS_IN_Q_REG(); }
	if ($i == 1) { return OQ_QUEUE_2_NUM_PKTS_IN_Q_REG(); }
	if ($i == 2) { return OQ_QUEUE_4_NUM_PKTS_IN_Q_REG(); }
	if ($i == 3) { return OQ_QUEUE_6_NUM_PKTS_IN_Q_REG(); }
}

sub verify_reg {
	my $regname = shift;
	my $expected = shift;
	my $total_errors = shift;

	my $reg = eval $regname;
	my $result = my_nftest_regread_expect("nf2c0", $reg, $expected);
	if ($result != $expected)
	{
		${$total_errors}++;
		my_print "\t regname = ", $regname, "\n";
	}
}

sub my_nftest_regread_expect {
	my $device = shift;
	my $addr = shift;
	my $exp = shift;

	my $val = nftest_regread($device, $addr);

	if ($val != $exp){
		my_printf "ERROR: Register read expected $exp (0x%08x) ", $exp;
		my_printf "but found $val (0x%08x) at address 0x%08x\n", $val, $addr;
	}
	return $val;
}

# get transmitting port: expect pkts rx'ed to equal pkts tx'ed
# xor last bit with 1 to toggle if physically looped back
sub get_transmitting_port {
	my $i = shift;
	if ($internal_loopback) {
		return $i;
	}
	else {
		return ($i & 0xfe) | (($i & 1) ^ 1);
	}
}
