###############################################################
# PacketGen Library for NetFPGA2
#
# $Id: PacketGen.pm 6067 2010-04-01 22:36:26Z grg $
#
# Invoke using: use NF::PacketGen;
#
# This is the library of functions that users would invoke in order
# to generate packet data files for use in either simulations
# or to send to the actual hardware.
# It also generates the files of 'expected' packets that should
# be received from either the simulation or the hardware.
#
# It also handles PCI reads/writes
#
# Modified Sep 6 2005 to use ports starting from 1.
#                     Also, supports either VLAN or PHYSICAL mode.
#
#          Sep 29 2005 (greg) Took out the insertion of VLANs from the
#                             nf_write_hardware_file() function as this
#                             should no longer be needed for NetFPGA.
#
###############################################################

package NF::PacketGen;
use Exporter;
use Carp;

@ISA = ('Exporter');

@EXPORT = qw( &nf_packet_in
	      &nf_write_sim_files
	      &nf_set_directory
	      &nf_set_ingress_hardware_filename
	      &nf_set_environment
	      &nf_create_hardware_file
	      &nf_write_hardware_file
	      &nf_write_expected_files
	      &nf_expected_packet
	      &nf_optional_packet
	      &nf_add_port_rule
	      &nf_get_next_packet_time_us
	      &nf_PCI_read32 &nf_PCI_read32_masked
	      &nf_PCI_write32
	      &nf_get_sim_reg_access
	      &nf_dma_data_in
	      &nf_expected_dma_data
	      &nf_optional_dma_data
	    );

# Specify the port mode.
my $NF2_PORT_MODE = 'VLAN';  # VLAN or PHYSICAL

# specify number of logical or physical ports
my $NF2_MAX_PORTS = 4;

# specify number of physical ports (if $NF2_PORT_MODE = 'VLAN' then this is 1)
my $NF2_PHYS_PORTS = 1;

# number of dma queues
my $NF2_DMA_QUEUES = 4;

# @ingress_pkts is a list of anonymous lists (array) of ingress packets per port.
#
# Each packet in the list is an anon hash:
# pkt {'delay' => scalar integer.  Delay in ns.
#      'batch' => scalar integer. Batch for this pkt.
#      'time_in' => scalar real. Approx time for first byte to be transmitted in microsecs.
#      'data' => anon array of pairs of hex chars. No leading 0x.
#      'port' => scalar integer. Not strictly needed but makes life easier.
#     }
#

my @ingress_pkts = ();

# @PCI_accesses is an array of PCI access anon hashes:
# access{ 'type'    => READ, WRITE or DMA
#         'delay'   => timeOrDelay string
#         'batch'   => scalar integer. Batch for this access
#         'address' => 27 bit byte address into board's PCI address space
#         'data'    => integer. Write data for writes. Expected read data for reads
#         'mask'    => integer. 0 for writes. Mask for reads (1 = check the bit.)
my @PCI_accesses = ();

# @DMA_ingress_pkts is an array of DMA ingress packets hashes:
# dma_pkt {
#          'data' => anon array of pairs of hex chars. No leading 0x.
#         }
my @DMA_ingress_pkts = ();

# This is the minimum turnaround time that the register pipeline needs
use constant MIN_PCI_CYCLE_TIME => 260;

my $PCI_CYCLE_TIME = 810;    # approx time for a PCI access (ns)

my $RESET_DONE = 3500;   # This should be when the 'System appears to be up.'
# message appears.

# @next_pkt_in keeps track of when next packet can be transmitted in for each port.
#              in nanosecs
my @next_pkt_in = ();


# @egress_pkts is a list of anonymous lists (array) of expected
#              egress packets per port.
#
# Each packet in the list is an anon hash:
# pkt {'rules' => anon array of rules (not sure of format yet)
#      'data' => anon array of pairs of hex chars. No leading 0x.
#     }
#
my @egress_pkts = ();

# @DMA_egress_pkts is a list of anonymous lists (array) of expected
#              egress packets per port.
#
# Each packet in the list is an anon hash:
# pkt {'rules' => anon array of rules (not sure of format yet)
#      'data' => anon array of pairs of hex chars. No leading 0x.
#     }
#
my @DMA_egress_pkts = ();

# @rules is a list of anonynous lists of rule strings.
# These are rules that apply to all packets on the port.
#
my @rules = ();

# @rule_list is the list of acceptable rule keywords.
#
my @rule_list = qw(UNORDERED);

# Filenames
my $sim_files_dir = 'packet_data';   # directory where port files will reside
my $sim_files = 'ingress_port_'; # with port number appended
my $exp_files = 'expected_port_'; # with port number appended
my $hardware_file = 'ingress_hardware'; # packets in pcap format
my $pci_sim_file = 'pci_sim_data';   # PCI info for sim only
my $dma_sim_file = 'ingress_dma';   # DMA info for sim only
my $dma_exp_files = 'expected_dma_';   # DMA info for sim only

# for hardware files
my %endian_type = ("BIG_ENDIAN"    => '0',
		   "LITTLE_ENDIAN" => '1'
		  );

my %batches = ();  # track the batch numbers seen


nf_initialize();

###############################################################
#
# Specify an ingress packet
# Params: port
#         length  (# bytes in the data param)
#         delay   (in ns) Use 0 if no delay required.
#         batch   (for hardware test) integer indicating group
#                 of packet(s) to be sent at a time.
#         data    as hex byte stream
# Returns: 0 for success
#          1 for error
#
###############################################################

sub nf_packet_in {
  if ($#_ < 4) { confess "nf_packet_in(): Need args: port, length,timeOrDelay,batch,data." }
  my $port = shift;
  my $u_len = shift;
  my $timeOrDelay = shift;
  my $batch = shift;
  my @data = @_;
  my ($data, $len);

  my $time64 = process_timeOrDelay($timeOrDelay);
  unless ($time64) {
    confess "nf_packet_in(): bad timeOrDelay parameter: $timeOrDelay "
  }

  unless (($port > 0) && ($port <= $NF2_MAX_PORTS)) {
    confess "nf_packet_in(): port param must be 1..$NF2_MAX_PORTS. (saw \"$port\")"
  }

  unless ($batch =~ m/^\d+$/) {
    confess "nf_packet_in(): batch param must be digits only. (saw \"$batch\")"
  }

  # The actual data is now in @data. May be many strings.
  $data = join ' ',@data;
  @data = split ' ',$data;
  $len = $#data + 1;
  if (($len < 60) or ($len > 10000)) {
    confess "nf_packet_in(): Saw length $len. Must be [60..10000]"
  }
  if ($len != $u_len) {
    confess "nf_packet_in(): packet length mismatch: user specified length $u_len but saw length $len.\n"
  }

  foreach (@data) {
    unless (/^[0-9a-fA-F]{1,2}$/) {
      confess "nf_packet_in(): expected only pairs of hex digits in packet. Saw $_\n"
    }
    if (length($_)==1) { $_ = '0'.$_ }
  }

  # If we are in VLAN mode then we need to use physical port 1 and put the
  # port number in the VLAN ID
  if ($NF2_PORT_MODE eq 'VLAN') {
    # see if VLAN already there. (eth type = 81 00)
    if (($data[12] ne '81') or ($data[13] ne '00')) {
      # print "data was    @data[0..19] ...\n";
      my @tmp =  @data[12..$#data];
      @data = (@data[0..11],'81','00','00', (sprintf "%02x",$port), @tmp);
      $port = 1;
      $len += 4;

      # print "data is now @data[0..19] ...\n";

    }
  }

  # figure out the EARLIEST time this packet will arrive at NetFPGA
  my $time_in;
  if ($time64 =~ m/^([01]):(\d+)$/) {
    if ($1 == 1) { $time_in = $2 }               # absolute time
    else { $time_in = $next_pkt_in[$port] + $2 } # relative time
  }
  else {
    confess "Bad format for \$time64: should be [01]:{digits} but saw $time64. "
  }

  # Add the packet to the relevant port list.

  push @{$ingress_pkts[$port]},
    {
     'delay' => $time64,
     'batch' => $batch,
     'data' => \@data,
     'time_in' => $time_in,
     'port' => $port
    };

  # update the time when the NEXT packet can go in
  # Effective len = len + 8 byte preamble + 4 byte CRC.
  # IPG is 9600 (9.6usecs) @ 10Mbps 960ns @ 100Mbps and 96ns @ 1Gbps
  $next_pkt_in[$port] = $time_in + ($len+12)*8 + 96;

  $batches{$batch} = 1; # we only care about the key, not value.

  return 0
}

###############################################################
#
# Specify an expected (egress) packet.
#
# It is assumed that packets will egress in the order specified,
# unless additional rules are added.
#
# Params: port
#         length  (# bytes in the data param)
#         data    as hex byte stream. May contain x or X for dont-care.
#
# Returns: handle (reference) to this expected packet. (to allow addition
#          of rules)
#
###############################################################
sub nf_expected_packet {
  if ($#_ < 2) { confess "nf_expected_packet(): Need args port, length, data." }
  my $port = shift;
  my $u_len = shift;
  my @data = @_;
  my ($data, $len, $pkt);

  unless (($port > 0) && ($port <= $NF2_MAX_PORTS)) {
    confess "nf_expected_packet(): port param must be 1..$NF2_MAX_PORTS. (saw \"$port\")"
  }

  # The actual data is now in @data. May be many strings.
  $data = join ' ',@data;
  @data = split ' ',$data;
  $len = $#data + 1;
  if (($len < 60) or ($len > 10000)) {
    confess "nf_expected_packet(): Saw length $len. Must be [60..10000]"
  }
  if ($len != $u_len) {
    confess "nf_expected_packet(): user specified length $u_len but saw length $len.\n"
  }

  foreach (@data) {
    unless (/^[0-9a-fA-FxX]{1,2}$/) {
      confess "nf_expected_packet(): expected only pairs of hex digits in packet. Saw $_\n"
    }
    if (length($_)==1) { $_ = '0'.$_ }
  }

  # If we are in VLAN mode then we need to use physical port 1 and put the
  # port number in the VLAN ID
  if ($NF2_PORT_MODE eq 'VLAN') {
    # see if VLAN already there. (eth type = 81 00)
    if (($data[12] ne '81') or ($data[13] ne '00')) {
      my @tmp =  @data[12..$#data];
      @data = (@data[0..11],'81','00','00', (sprintf "%02x",$port), @tmp);
      $port = 1;
    }
  }

  # Add the packet to the relevant port list.

  $pkt = {
	  'rules' => [],
	  'data' => \@data
	 };

  push @{$egress_pkts[$port]},$pkt;

  return $pkt;
}                                         # nf_expected_packet

###############################################################
#
# Specify an optional (egress) packet.
#
# It is assumed that packets will egress in the order specified,
# unless additional rules are added.
#
# Params: port
#         length  (# bytes in the data param)
#         data    as hex byte stream. May contain x or X for dont-care.
#
# Returns: handle (reference) to this optional packet. (to allow addition
#          of rules)
#
###############################################################
sub nf_optional_packet {
  if ($#_ < 2) { die "nf_optional_packet(): Need args port, length, data." }
  my $port = shift;
  my $u_len = shift;
  my @data = @_;
  my ($data, $len, $pkt);

  unless (($port > 0) && ($port <= $NF2_MAX_PORTS)) {
    die "nf_optional_packet(): port param must be 1..$NF2_MAX_PORTS. (saw \"$port\")"
  }

  # The actual data is now in @data. May be many strings.
  $data = join ' ',@data;
  @data = split ' ',$data;
  $len = $#data + 1;
  if (($len < 60) or ($len > 10000)) {
    die "nf_optional_packet(): Saw length $len. Must be [60..10000]"
  }
  if ($len != $u_len) {
    die "nf_optional_packet(): user specified length $u_len but saw length $len.\n"
  }

  foreach (@data) {
    unless (/^[0-9a-fA-FxX]{1,2}$/) {
      die "nf_optional_packet(): expected only pairs of hex digits in packet. Saw $_\n"
    }
    if (length($_)==1) { $_ = '0'.$_ }
  }

  # If we are in VLAN mode then we need to use physical port 1 and put the
  # port number in the VLAN ID
  if ($NF2_PORT_MODE eq 'VLAN') {
    # see if VLAN already there. (eth type = 81 00)
    if (($data[12] ne '81') or ($data[13] ne '00')) {
      my @tmp =  @data[12..$#data];
      @data = (@data[0..11],'81','00','00', (sprintf "%02x",$port), @tmp);
      $port = 1;
    }
  }

  # Add the packet to the relevant port list.

  $pkt = {
	  'rules' => [],
	  'data' => \@data,
	  'optional' => 1,
	 };

  push @{$egress_pkts[$port]},$pkt;

  return $pkt;
}                                         # nf_optional_packet

###############################################################
#
# Specify a PCI 32 bit read with expected return value
#
# Params:
#         timeOrDelay (in ns unless spec'd) Use 0 if no delay required. (Sim only)
#         batch      (for hardware test) integer indicating group
#                    of PCI accesses to be done at a time.
#         address    of register (24 bit address)
#         exp_data   Expected data to be returned
#
# Returns: 0 if OK
#          1 if error
################################################################
sub nf_PCI_read32 {

  if ($#_ != 3 && $#_ != 1) { confess "nf_PCI_read32() : requires params: timeOrDelay, batch, addr, exp_data." }

  if($#_ == 3) {
    $timeOrDelay = shift;
    $batch = shift;
  }
  else {
    $timeOrDelay = $main::delay;
    $batch = 0;
  }
  $address = shift;
  $exp_data = shift;

  unless (defined $address) {
    confess "nf_PCI_read32(): address not defined."
  }
  unless (defined $exp_data) {
    confess "nf_PCI_read32(): exp_data not defined."
  }

  nf_PCI_read32_masked ( $timeOrDelay, $batch, $address, $exp_data, 0xffffffff);

  return 0

} # nf_PCI_read32

###############################################################
#
# Specify a PCI 32 bit read with expected return value and mask
#
# Params:
#         timeOrDelay (in ns unless spec'd) Use 0 if no delay required. (Sim only)
#         batch      (for hardware test) integer indicating group
#                    of PCI accesses to be done at a time.
#         address    of register (24 bit address)
#         exp_data   Expected data to be returned
#         mask       32-bit mask for the expected data. 1 = check 0 = dont check this bit.
#
# Returns: 0 if OK
#          1 if error
################################################################
sub nf_PCI_read32_masked {

  if ($#_ != 4 && $#_ != 2) { confess "nf_PCI_read32_masked() : requires params: timeOrDelay, batch, addr, exp_data, mask" }

  if($#_ == 4) {
    $timeOrDelay = shift;
    $batch = shift;
  }
  else {
    $timeOrDelay = $main::delay;
    $batch = 0;
  }
  $address = shift;
  $exp_data = shift;
  $mask = shift;

  my $time64 = process_timeOrDelay($timeOrDelay);
  unless ($time64) {
    confess "Error in call nf_PCI_read32_masked( $timeOrDelay, $batch, $address, $exp_data, $mask )."
  }

  unless ($batch =~ m/^\d+$/) {
    confess "nf_PCI_read32_masked(): batch param must be digits only. (saw \"$batch\")"
  }

  unless (defined $address) {
    confess "nf_PCI_read32_masked(): address not defined."
  }

  unless (($address & 0x7ffffff) == $address) {
    confess "nf_PCI_read32_masked(): illegal address $address : must be 0x0 - 0x7FFFFFF"
  }

  push @PCI_accesses, {'type'    => 'READ',
		       'delay'   => $time64,
		       'batch'   => $batch,
		       'address' => $address,
		       'data'    => $exp_data,
		       'mask'    => $mask
		      };
  return 0

} # nf_PCI_read32_masked

###############################################################
#
# Specify a PCI 32 bit write
#
# Params:
#         timeOrDelay (in ns unless spec'd) Use 0 if no delay required. (Sim only)
#         batch      (for hardware test) integer indicating group
#                    of PCI accesses to be done at a time.
#         address    of register (24 bit address)
#         data       Write data
#
# Returns: 0 if OK
#          1 if error
################################################################
sub nf_PCI_write32 {

  if ($#_ != 1 && $#_ != 3) { confess "nf_PCI_write32() : requires params: timeOrDelay, batch, addr, data" }

  if($#_ == 3) {
    $timeOrDelay = shift;
    $batch = shift;
  }
  else {
    $timeOrDelay = $main::delay;
    $batch = 0;
  }
  my $address = shift;
  my $data = shift;
  my $mask = 0;

  my $time64 = process_timeOrDelay($timeOrDelay);
  unless ($time64) {
    print "Error in call to nf_PCI_write32( $timeOrDelay, $batch, $address, $data ).";
    return 1;
  }

  unless ($batch =~ m/^\d+$/) {
    print "nf_PCI_write32(): batch param must be digits only. (saw \"$batch\")";
    return 1;
  }

  unless (defined $address) {
    confess "nf_PCI_write32(): address not defined."
  }
  unless (defined $data) {
    confess "nf_PCI_write32(): data not defined."
  }

  unless (($address & 0x7ffffff) == $address) {
    print "nf_PCI_write32(): illegal address $address : must be 0x0 - 0x7FFFFFF";
    return 1
  }

  push @PCI_accesses, {'type'    => 'WRITE',
		       'delay'   => $time64,
		       'batch'   => $batch,
		       'address' => $address,
		       'data'    => $data,
		       'mask'    => $mask
		      };
  return 0

} # nf_PCI_write32


###############################################################
#
# Specify a rule that applies to all packets on this port
# Params: port   [1..$NF2_MAX_PORTS]
#         rule   string
#
# Returns: 0 if OK, 1 if error
################################################################
sub nf_add_port_rule {

  if ($#_ < 1) { confess "nf_add_port_rule: Error: expected params port, rule.\n" }

  my $port = shift;
  my $rule = uc(shift);
  my $rule_ok = 0;

  unless (($port > 0) and ($port <= $NF2_MAX_PORTS+$NF2_DMA_QUEUES)) {
    confess "nf_add_port_rule(): port must be 1..".($NF2_MAX_PORTS+$NF2_DMA_QUEUES)." (saw \"$port\")"
  }

  foreach (@rule_list) { $rule_ok = 1 if ($rule eq $_) }
  unless ($rule_ok) {
    confess "nf_add_port_rule: Bad rule \"$rule\".  Rule specifiers are ".
      (join ' ',@rule_list)."\n";
  }

  push @{$rules[$port]},$rule;

  return 0

} # nf_add_port_rule


###############################################################
#
# Specify DMA ingress data to load
# Params: length  (# bytes in the data param)
#         delay   (in ns) Use 0 if no delay required.
#         queue   DMA queue to send the data to
#         data    as hex byte stream
# Returns: 0 for success
#          1 for error
#
###############################################################

sub nf_dma_data_in {
  if ($#_ < 3) { confess "nf_dma_data_in(): Need args: length,timeOrDelay,queue, data." }
  my $u_len = shift;
  my $timeOrDelay = shift;
  my $queue = shift;
  my @data = @_;
  my ($data, $len);

  my $time64 = process_timeOrDelay($timeOrDelay);
  unless ($time64) {
    confess "nf_dma_data_in(): bad timeOrDelay parameter: $timeOrDelay "
  }

  # The actual data is now in @data. May be many strings.
  $data = join ' ',@data;
  @data = split ' ',$data;
  $len = $#data + 1;
  if (($len < 1) or ($len > 4095)) {
    confess "nf_dma_data_in(): Saw length $len. Must be [1..4095]"
  }
  if ($len != $u_len) {
    confess "nf_dma_data_in(): packet length mismatch: user specified length $u_len but saw length $len.\n"
  }

  foreach (@data) {
    unless (/^[0-9a-fA-F]{1,2}$/) {
      confess "nf_dma_data_in(): expected only pairs of hex digits in packet. Saw $_\n"
    }
    if (length($_)==1) { $_ = '0'.$_ }
  }

  # Add the packet to the DMA packet list
  push @DMA_ingress_pkts,
    {
     'data' => \@data
    };

  # Add the DMA write to the PCI transaction list
  push @PCI_accesses, {'type'    => 'DMA',
		       'delay'   => $time64,
		       'batch'   => $batch,
		       'address' => $queue,
		       'data'    => $len,
		       'mask'    => 0
		      };

  return 0
}


###############################################################
#
# Specify expected (egress) DMA data.
#
# It is assumed that packets will egress in the order specified,
# unless additional rules are added.
#
# Params: queue   DMA queue to send data to
#         length  (# bytes in the data param)
#         data    as hex byte stream. May contain x or X for dont-care.
#
# Returns: handle (reference) to this expected packet. (to allow addition
#          of rules)
#
###############################################################
sub nf_expected_dma_data {
  if ($#_ < 2) { confess "nf_expected_dma_data(): Need args queue, length, data." }
  my $queue = shift;
  my $u_len = shift;
  my @data = @_;
  my ($data, $len, $pkt);

  # The actual data is now in @data. May be many strings.
  $data = join ' ',@data;
  @data = split ' ',$data;
  $len = $#data + 1;
  if (($len < 1) or ($len > 4095)) {
    confess "nf_expected_dma_data(): Saw length $len. Must be [1..4095]"
  }
  if ($len != $u_len) {
    confess "nf_expected_dma_data(): user specified length $u_len but saw length $len.\n"
  }

  foreach (@data) {
    unless (/^[0-9a-fA-FxX]{1,2}$/) {
      confess "nf_expected_dma_data(): expected only pairs of hex digits in packet. Saw $_\n"
    }
    if (length($_)==1) { $_ = '0'.$_ }
  }

  # Add the packet to the relevant port list.
  $pkt = {
	  'rules' => [],
	  'data' => \@data
	 };

  push @{$DMA_egress_pkts[$queue]}, $pkt;

  return $pkt;
}                                         # nf_expected_dma_data


###############################################################
#
# Specify optional (egress) DMA data.
#
# It is assumed that packets will egress in the order specified,
# unless additional rules are added.
#
# Params: queue   DMA queue to send data to
#         length  (# bytes in the data param)
#         data    as hex byte stream. May contain x or X for dont-care.
#
# Returns: handle (reference) to this optional packet. (to allow addition
#          of rules)
#
###############################################################
sub nf_optional_dma_data {
  if ($#_ < 2) { die "nf_optional_dma_data(): Need args queue, length, data." }
  my $queue = shift;
  my $u_len = shift;
  my @data = @_;
  my ($data, $len, $pkt);

  # The actual data is now in @data. May be many strings.
  $data = join ' ',@data;
  @data = split ' ',$data;
  $len = $#data + 1;
  if (($len < 1) or ($len > 4095)) {
    die "nf_optional_dma_data(): Saw length $len. Must be [1..4095]"
  }
  if ($len != $u_len) {
    die "nf_optional_dma_data(): user specified length $u_len but saw length $len.\n"
  }

  foreach (@data) {
    unless (/^[0-9a-fA-FxX]{1,2}$/) {
      die "nf_optional_dma_data(): expected only pairs of hex digits in packet. Saw $_\n"
    }
    if (length($_)==1) { $_ = '0'.$_ }
  }

  # Add the packet to the relevant port list.
  $pkt = {
	  'rules' => [],
	  'data' => \@data
	 };

  push @{$DMA_egress_pkts[$queue]}, $pkt;

  return $pkt;
}                                         # nf_optional_dma_data


###############################################################
#
# Write out the simulation files (for VCS to load via readmemh)
# See netfpga/doc/file_formats.txt for format
# Params: none
# Returns: approx time needed to send all packets (in nanoseconds.)
#
# These are ingress packets only.
###############################################################
sub nf_write_sim_files {

  my ($port, $len);
  my $fname;
  my $count;
  my $time = localtime;
  my $data;
  my @data;
  my $max_ns = 0;

  mkdir $sim_files_dir unless ( -d $sim_files_dir );


  for $port (1..$NF2_PHYS_PORTS) {

    $count  = 1;

    #nf_show_packets($port);

    $fname = $sim_files_dir.'/'.$sim_files.$port;
    open (F,">$fname")                   or confess ("nf_write_sim_files() :cant write to $fname");

    print F "// File $fname created $time\n";
    print F "//\n//This is a data file intended to be read in by a Verilog simulation.\n";
    print F"//\n//\n";

    # iterate over each packet in list
    for $pkt (@{$ingress_pkts[$port]}) {
      printf F "// Packet $count of %0d\n", $#{$ingress_pkts[$port]}+1;
      print F "// ".showDASAtype($pkt->{'data'})."\n";
      @data = @{$pkt->{'data'}};  # must copy
      $len = $#data+1;

      printf F "%08X // Length $len without CRC\n",$len;
      printf F "%08X // Port $port\n",$port;
      printf F "%08X // Earliest send time (MSB)\n",0;
      printf F "%08X // Earliest send time (LSB) %0d ns\n",
	$pkt->{'time_in'},$pkt->{'time_in'};

      while ((($#data+1) % 4) != 0) { push @data,'00' }

      while ($#data >= 0) {
	printf F "%2s%2s%2s%2s\n",shift @data, shift @data,
	  shift @data, shift @data;
      }

      print F "eeeeffff  // End of pkt marker for pkt $count (this is not sent).\n";
      $count++;

    }

    close(F);

  }

  my $last_pci_access_ns = write_pci_sim_file();
  write_dma_sim_file();


  # now figure out when last packet will have entered NetFPGA

  for (@next_pkt_in) { $max_ns = ($max_ns < $_) ? $_ : $max_ns }
  return ($max_ns > $last_pci_access_ns) ? $max_ns : $last_pci_access_ns;
}

###############################################################
#
# Write out the simulation file for PCI accesses.
# See netfpga/doc/file_formats.txt for format.
# Params: none
# Returns: time (in ns) of last PCI access.
#
###############################################################

sub write_pci_sim_file {

  my $timeOfDay = localtime;

  my $time =  $RESET_DONE;  # earliest we can start doing stuff

  mkdir $sim_files_dir unless ( -d $sim_files_dir );

  my $fname = $sim_files_dir.'/'.$pci_sim_file;

  open (F,">$fname") or confess ("Error: write_pci_sim_file() : cannot write to $fname. ");

  print F "// File $fname created $timeOfDay\n";
  print F "//\n// This is a data file intended to be read in by a Verilog simulation.\n";
  print F "// It describes the PCI accesses that are supposed to occur during a test\n";
  print F"//\n//\n";

  for $h (@PCI_accesses) {

    my ($abs, $time_ns);
    if ($h->{'delay'} =~ m/^([01]):(\d+)$/) {
      ($abs, $time_ns) = ($1,$2);
    } else {
      confess "write_pci_sim_file(): Bad timeOrDelay format: \'".$h->{'delay'}."\'";
    }

    # if it's an absolute time then use that else it's relative so add it on.
    if ($abs) {
      # allow enough time between write so we don't overwhelm the
      # register system. This is a temp workaround for a bug.
      if($time_ns > $time + MIN_PCI_CYCLE_TIME) {
	$time = $time_ns;
      }
    }
    else {
      $time += $time_ns;
    }

    # Type of access

    if ($h->{'type'} eq 'READ') {
      printf F "// READ:  Time: %0d ns  ADDR: 0x%0x  EXP_DATA: 0x%0x  MASK: 0x%0x\n",
	$time, $h->{'address'}, $h->{'data'}, $h->{'mask'};
      printf F "%08X // READ\n",1;
    }
    elsif ($h->{'type'} eq 'WRITE') {
      printf F "// WRITE:  Time: %0d ns  ADDR: 0x%0x  DATA: 0x%0x \n",
	$time, $h->{'address'}, $h->{'data'};
      printf F "%08X // WRITE\n",2;
    }
    elsif ($h->{'type'} eq 'DMA') {
      printf F "// DMA:  Time: %0d ns  QUEUE: 0x%0x  LENGTH: 0x%0x \n",
	$time, $h->{'address'}, $h->{'data'};
      printf F "%08X // DMA\n",3;
    }
    else { confess "write_pci_sim_file(): bad PCI access type: ".$h->{'type'} }

    # delay

    printf F "%08X // Time MSB\n", 0;
    printf F "%08X // Time LSB (%0d ns) (%0d us)\n", $time, $time, int($time/1000);
    if ($h->{'type'} eq 'DMA') {
        printf F "%08X // Queue (%0d)\n", $h->{'address'},$h->{'address'};
        printf F "%08X // Length (%0d)\n", $h->{'data'}, $h->{'data'};
    }
    else {
        printf F "%08X // Address (0x%0x)\n", $h->{'address'},$h->{'address'};
        printf F "%08X // Data (%0d)\n", $h->{'data'}, $h->{'data'};
    }
    printf F "%08X // Mask (%0d)\n", $h->{'mask'}, $h->{'mask'};

    $time += MIN_PCI_CYCLE_TIME;
  }

  print F "// End of file.\n";

  close F;

  return $time;
}



###############################################################
#
# Write out the simulation file for DMA ingress data
# See netfpga/doc/file_formats.txt for format.
# Params: none
# Returns: time (in ns) of last DMA ingress packet
#
###############################################################

sub write_dma_sim_file {

  my $timeOfDay = localtime;

  mkdir $sim_files_dir unless ( -d $sim_files_dir );

  my $fname = $sim_files_dir.'/'.$dma_sim_file;

  open (F,">$fname") or confess ("Error: write_dma_sim_file() : cannot write to $fname. ");

  print F "// File $fname created $timeOfDay\n";
  print F "//\n// This is a data file intended to be read in by a Verilog simulation.\n";
  print F "// It describes the DMA ingress data that is supposed to be provided during a test\n";
  print F"//\n//\n";

  $count  = 1;

  for $h (@DMA_ingress_pkts) {

    @data = @{$h->{'data'}};  # must copy
    $len = $#data+1;

    printf F "// Packet $count of %0d\n", $#DMA_ingress_pkts+1;
    printf F "%08X // Length $len\n",$len;

    while ((($#data+1) % 4) != 0) { push @data,'00' }

    while ($#data >= 0) {
      printf F "%2s%2s%2s%2s\n",shift @data, shift @data,
        shift @data, shift @data;
    }

    print F "eeeeffff  // End of pkt marker for pkt $count (this is not sent).\n";
    $count++;
  }

  print F "// End of file.\n";

  close F;
}



#############################################################################
#
# Name: nf_set_directory_
#
# Subroutine to specify the directory used for files
#
# Argument(s): directory name
#
# Returns 0 for success, 1 for failure
#############################################################################
sub nf_set_directory {

  my $num_args = $#_ + 1;

  return 1 if ($num_args != 1);

  $sim_files_dir = $_[0];

  $sim_files_dir =~ s|/$||;  # remove trailing /

  return 0
}

#############################################################################
#
# Name: nf_set_ingress_hardware_filename_
#
# Subroutine to specify the filename for hardware ingress pkts
#
# Argument(s): file name
#
# Returns 0 for success, 1 for failure
#############################################################################
sub nf_set_ingress_hardware_filename {

  my $num_args = $#_ + 1;

  return 1 if ($num_args != 1);

  $hardware_file = $_[0];

  return 0
}


#############################################################################
#
# Name: nf_create_hardware_file
# Author: Harn Hua Ng, harnhua@stanford.edu
#
# Subroutine to create a tcpdump/pcap format file.
#
# Argument(s): endian-ness of output - "BIG_ENDIAN" or "LITTLE_ENDIAN"
#
#############################################################################
sub nf_create_hardware_file {

  ###########################################################################
  # pcap header format:
  # 1) 4-byte magic num - TCPDUMP_MAGIC, in "savefile.c", i.e. 0xa1b2c3d4.
  # 2) 2-byte major version num - PCAP_VERSION_MAJOR, as in "pcap.h", i.e. 2
  # 3) 2-byte minor version num - PCAP_VERSION_MINOR, as in "pcap.h", i.e. 4
  # 4) 4-byte offset from local time to UTC, in sec at the location where
  # the packet was captured
  # 5) 4-byte time stamp accuracy, but "libpcap" always writes it out as 0,
  # so you can do the same
  # 6) 4-byte "snapshot length" - 8kB by default
  # 7) 4-byte data link type - 10MB Ethernet = 1
  # ALL fields in the header are written in the byte order of the machine
  # writing them out - reader needs to check whether the magic number is
  # normal or byte-swapped and, if byte-swapped, needs to swap the header
  # fields.
  ###########################################################################

  # constants
  my $TCPDUMP_MAGIC = 0xa1b2c3d4; # default
  my $VERSION_MAJOR = 2; # default
  my $VERSION_MINOR = 4; # default
  my $LOCAL_TIME_OFFSET = 0; # meaningless
  my $TIMESTAMP_ACCURACY = 0; # meaningless
  my $SNAP_LENGTH = 8192; # default
  my $LINK_TYPE = 1; # 10Mb ethernet

  ## prepare output file
  mkdir $sim_files_dir unless ( -d $sim_files_dir );
  my $fname = $sim_files_dir.'/'.$hardware_file;
  open (F,">$fname") or confess ("nf_write_hardware_file() : Can't write to $fname");

  # get arguments filehandle, endian-ness, DA, SA, ethernet type, data
  my $num_args = $#_ + 1;
  my $endian_type = $_[0];
  my $format_str;
  if (defined $endian_type{$endian_type}) {
    if ($endian_type{$endian_type}) { # little endian
      $format_str = "VvvVVVV";
    }
    else { # big endian
      $format_str = "NnnNNNN";
    }
  } else {
    confess "Internal error: NETFPGA::PacketGen invalid endian_type $endian_type";
  }

  # create tcpdump/pcap format file header
  my $binary_data = pack $format_str, $TCPDUMP_MAGIC, $VERSION_MAJOR,
    $VERSION_MINOR, $LOCAL_TIME_OFFSET, $TIMESTAMP_ACCURACY,
      $SNAP_LENGTH, $LINK_TYPE;
  print F $binary_data;
  #print "Created tcpdump/pcap file header\n";

  ## close output file
  close(F);

}

#######################################################################
#
# Name: nf_write_hardware_file
# Author: Harn Hua Ng, harnhua@stanford.edu
#
# Write out the hardware ingress files (libpcap format)
# This is ingress packets only.
# This is a single stream of packets and time is
# represented by the "batch" field.
#
# The VLAN field is NO LONGER added as it should already be
# added to those packets that need it.
#
# Argument(s): endian-ness - "BIG_ENDIAN" or "LITTLE_ENDIAN"
#
#######################################################################
sub nf_write_hardware_file {

  ## constants
  my $MAC_ADDR_LEN = 6;
  my $ETHER_TYPE_LEN = 2;
  my $VLAN_LEN = 4;
  my @vlan = ("81", "00", "00"); # most significant 3 bytes

  ## declare variables
  # pcap pkt header
  my ($ts_1, $ts_2, $data_len, $bytes_in_file, $bytes_in_pkt);
  # actual pkt
  my ($DA, $SA, $ether_type, $vlan, $port, $data);
  my $data_byte;
  # book-keeping
  my ($i, $count, $fname);
  $count = 1;

  ## prepare output file
  mkdir $sim_files_dir unless ( -d $sim_files_dir );
  $fname = $sim_files_dir.'/'.$hardware_file;
  open (F,">>$fname") or confess ("nf_write_hardware_file() : Can't write to $fname");

  ## gather info from arguments
  my $num_args = $#_ + 1;
  my $endian_type = $_[0];
  my $format_str;
  if (defined $endian_type{$endian_type}) {
    if ($endian_type{$endian_type}) { # little endian
      $format_str = "VVVV";
    }
    else { # big endian
      $format_str = "NNNN";
    }
  } else {
    confess "Internal error: NETFPGA::PacketGen nf_write_hardware_file() : invalid endian_type $endian_type";
  }

  # Now go through and order the packets in terms of batch and then
  # order each batch in terms of transmit time.

  # Step through batch numbers in numerical order
  for $batch ( sort { $a <=> $b } keys %batches ) {

    my @batch = ();

    # iterate over all ports
    for $port (1..$NF2_MAX_PORTS) {

      # Find all packets that match the batch:
      push @batch, grep {$_->{'batch'} == $batch } @{$ingress_pkts[$port]};

    }

    # sort them by ingress time.

    my @sorted_batch = sort { $a->{'time_in'} <=> $b->{'time_in'} } @batch;

    $count = 1;

    # now iterate over each packet in sorted list
    for $pkt (@sorted_batch) {
      $data = $pkt->{'data'};
      $port = $pkt->{'port'};
      $data_len = $#{$data} + 1; #DA+SA+type+data

      # printf "Debug: Batch $batch Packet $count of %0d. Port $port. Time in: %0d\n",
      #	   scalar(@sorted_batch), int($pkt->{'time_in'});
      # print " ".showDASAtype($pkt->{'data'})."\n";

      ###########################################################################
      # The packet header - "pcap_pkthdr" structure in "pcap.h"
      # 1) a "struct timeval", time when file was captured - this format may
      # depend on the platform, with fields of that "struct timeval" being 32
      # bits or 64 bits
      # 2) a 32-bit number - how many bytes of packet data were written to the
      # file (raw packet data; doesn't include length of packet header)
      # 3) a 32-bit number - how many bytes were in the packet, which may be
      # greater than the number of bytes written to the file if, as above, the
      # packets were cut off at the "snapshot length".
      ###########################################################################

      ## construct tcpdump/pcap packet header
      $ts_1 = 0;
      $ts_2 = $pkt->{'batch'}; # batch

      # $bytes_in_file = $data_len + $VLAN_LEN; # includes vlan tag
      $bytes_in_file = $data_len; # no longer includes vlan tag

      # should be equal, since it's not a pkt captured from the network
      $bytes_in_pkt = $bytes_in_file;
      # write pcap packet header
      print F pack $format_str, $ts_1, $ts_2, $bytes_in_file, $bytes_in_pkt;

      ## construct ethernet packet
      # SA followed by DA
      for (1..$MAC_ADDR_LEN) { print F pack("C", hex(shift(@{$data}) )); }
      for (1..$MAC_ADDR_LEN) { print F pack("C", hex(shift(@{$data}) )); }

      # VLANs no longer needed to be inserted here.
      # VLAN tag with destination port info
      # push (@vlan, $port);
      # foreach (@vlan) { print F pack("C", hex($_)); }
      # @vlan = ("81", "00", "00"); # most significant 3 bytes

      # ethernet type
      for (1..$ETHER_TYPE_LEN) { print F pack("C", hex(shift(@{$data}) )); }
      # data
      $data_len = $data_len - 2*$MAC_ADDR_LEN - $ETHER_TYPE_LEN;
      #print "Data of length $data_len : @{$data}\n";

      for (1..$data_len) { print F pack("C", hex(shift(@{$data})) ); } # new line

#      for (1..$data_len) { print F pack("C", shift(@{$data}) ); } # original line

      #print " -- Added $bytes_in_pkt"."-byte packet in batch $ts_2 for port $port --\n";

      $count++;
    }
  }

  ## close output file
  close(F);

}

###############################################################
#
# Write out the expected files (in XML format)
# See NetFPGA/docs/Developer/file_formats.txt for format
#
# Params: none
#
# Returns: 0
###############################################################
sub nf_write_expected_files {
  my ($port, $len);
  my $fname;
  my $count;
  my $time = localtime;
  my ($data, $rules, $optional);

  mkdir $sim_files_dir unless ( -d $sim_files_dir );

  for $port (1..$NF2_PHYS_PORTS) {

    $count  = 1;

    # nf_show_packets($port);

    $fname = $sim_files_dir.'/'.$exp_files.$port;
    open (F,">$fname")                   or confess ("nf_write_sim_files() :cant write to $fname");

    # Header

    print F "<?xml version=\"1.0\" standalone=\"yes\" ?>\n";
    print F "<!-- File $fname created $time -->\n";
    print F "<!-- PHYS_PORTS = $NF2_PHYS_PORTS MAX_PORTS = $NF2_MAX_PORTS -->\n";
    print F "<PACKET_STREAM>\n";
    print F "\n";

    # write out global rules

    if (scalar(@{$rules[$port]}) > 0) {
      foreach (@{$rules[$port]}) {
	print F "<RULE> $_ </RULE>\n";
      }
    }

    # iterate over each packet in list
    for $pkt (@{$egress_pkts[$port]}) {

      printf F "\n<!-- Packet $count of %0d -->\n", $#{$egress_pkts[$port]}+1;
      print F "<!-- ".showDASAtype($pkt->{'data'})." -->\n";

      # First show any rules for this packet

      $rules = $pkt->{'rules'};  # ref to array of ?????
      if ($#{$rules} >= 0) {
	for (@{$rules}) {
	  print F "<RULE> $_ </RULE>\n";
	}
      }

      # Second show the data

      $data = $pkt->{'data'};  # ref to array of bytes
      $len = $#{$data}+1;
      if (defined($pkt->{'optional'}) && $pkt->{'optional'} != 0) {
        printf F "<PACKET Length=\"$len\" Port=\"$port\" Delay=\"0\" Optional=\"1\"> <!-- Length w/o CRC -->\n";
      } else {
        printf F "<PACKET Length=\"$len\" Port=\"$port\" Delay=\"0\"> <!-- Length w/o CRC -->\n";
      }

      for (0..$#{$data}) {
	printf F "%2s ", $data->[$_];
	if ($_ % 16 == 15) { print F "\n" }
      }
      print F "\n</PACKET> <!-- pkt $count -->\n";
      $count++;
    }

    # Trailer
    print F "</PACKET_STREAM>\n";

    close(F);
  }

  # Write out the DMA expected files
  nf_write_expected_dma_files();

  return 0;
}


###############################################################
#
# Write out the expected DMA egress data (in XML format)
# See NetFPGA/docs/Developer/file_formats.txt for format
#
# Params: none
#
# Returns: 0
###############################################################
sub nf_write_expected_dma_files {
  my ($port, $len);
  my $fname;
  my $count;
  my $time = localtime;
  my ($data, $rules);

  mkdir $sim_files_dir unless ( -d $sim_files_dir );

  for $port (1..$NF2_DMA_QUEUES) {

     $count  = 1;

     # nf_show_packets($port);

     $fname = $sim_files_dir.'/'.$dma_exp_files.$port;
     open (F,">$fname")                   or confess ("nf_write_expected_dma_files() :cant write to $fname");

     # Header

     print F "<?xml version=\"1.0\" standalone=\"yes\" ?>\n";
     print F "<!-- File $fname created $time -->\n";
     print F "<!-- DMA_QUEUES = $NF2_DMA_QUEUES -->\n";
     print F "<DMA_PACKET_STREAM>\n";
     print F "\n";

     # write out global rules

     if (scalar(@{$rules[$port+$NF2_MAX_PORTS]}) > 0) {
       foreach (@{$rules[$port+$NF2_MAX_PORTS]}) {
         print F "<RULE> $_ </RULE>\n";
       }
     }

     # iterate over each packet in list
     for $pkt (@{$DMA_egress_pkts[$port]}) {

       printf F "\n<!-- Packet $count of %0d -->\n", $#{$DMA_egress_pkts[$port]}+1;
       print F "<!-- ".showDASAtype($pkt->{'data'})." -->\n";

       # First show any rules for this packet

       $rules = $pkt->{'rules'};  # ref to array of ?????
       if ($#{$rules} >= 0) {
         for (@{$rules}) {
           print F "<RULE> $_ </RULE>\n";
         }
       }

       # Second show the data

       $data = $pkt->{'data'};  # ref to array of bytes
       $len = $#{$data}+1;
       printf F "<DMA_PACKET Length=\"$len\" Port=\"$port\" Delay=\"0\"> \n";

       for (0..$#{$data}) {
         printf F "%2s ", $data->[$_];
         if ($_ % 16 == 15) { print F "\n" }
       }
       print F "\n</DMA_PACKET> <!-- pkt $count -->\n";
       $count++;
     }

     # Trailer
     print F "</DMA_PACKET_STREAM>\n";

     close(F);
  }

  return 0;
}


###############################################################
#
# Debug. Print packets we have on a given port.
# Param: port you want to see.
#
# Currently only shows ingress packets.
###############################################################
sub nf_show_packets {
  $port = shift;

  my $list = $ingress_pkts[$port];
  my $num_p = $#{$list}+1;
  my $pkt;
  my $count  = 0;

  print "Saw $num_p packets\n";
  for $pkt (@$list) {  # $pkt is ref to anon hash
    print 'Pkt '.$count++." : Delay: $pkt->{'delay'}   Pkt: ".showDASAtype($pkt->{'data'})."\n";
  }

}

################################################################
# Print Da, Sa, ETh type plus a few more bytes
# Param: ref to array of bytes.
sub showDASAtype {
  my $data = shift;  # ref to array of bytes
  my $DA = join ':',@{$data}[0..5];
  my $SA = join ':',@{$data}[6..11];
  return 'Len:'.($#{$data}+1)." DA: $DA SA: $SA [${$data}[12]${$data}[13]] ".
    join (' ',@{$data}[14..19]).'...';
}

################################################################
# Check that a string is only hex digits
# Param: string of hex bytes like 'aa 12 67 5f e4'
#        expected length (optional)
# Returns: 0 if ok
#          1 if failure
################################################################
sub check_hex_string {
  my $s = shift;
  my $len = 0;

  if ($#_ == 0) {$len = shift}  # length specifier is optional

  my @s = split ' ',$s;
  for (@s) {
    unless (/^[0-9a-fA-F]{1,2}$/) { return 1 }
  }

  # check length if we got a length param

  if ($len and (scalar(@s) != $len)) { print "\nERROR: length mismatch\n"; return 1 }

  return 0
}

################################################################
# Convert an integer to a 4 byte hex string
#
# Param: integer   (or string preceded by letter H indicating hex digits)
#
# Returns: string (format "XX XX XX XX")
#
################################################################
sub int32_to_hex_string {
  my $i = shift;

  if ($i =~ m/^H([0-9a-fA-F]+)/) {
    $i = hex($1);
  }

  my $s = sprintf "%02x %02x %02x %02x",
    (($i & 0xff000000)>>24),(($i & 0x00ff0000)>>16),
      (($i & 0x0000ff00)>>8), ($i & 0xff);

  return $s
}

################################################################
# Convert an integer to a 2 byte hex string
# Param: integer
#
# Returns: string (format "XX XX")
#
################################################################
sub int16_to_hex_string {
  my $i = shift;

  my $s = sprintf "%02x %02x", (($i & 0x0000ff00)>>8), ($i & 0xff);

  return $s
}

################################################################
# Convert a THING to a 4 byte hex string
# Param: THING (integer, sequence of digits, sequence of hex ....)
#        disallow_X  Disallow don't care states (default: False)
#
# Returns: string (format: "XX XX XX XX")
#
################################################################
sub any_to_hex_string {
  my $i = shift;
  my $disallow_X = shift;

  # Check if the thing contains any X's if they're disallowed
  if (defined($disallow_X) && $disallow_X) {
     if ($i =~ m/[xX]/) {
       confess "Bad format : sequence is not allowed to contain don't cares (X) but saw \'$i\'."
     }
  }


  $i =~ s/^\s*//;
  $i =~ s/\s*$//;
  $i =~ s/\s+/ /;

  # see if a plain old integer

  if ($i =~ m/^-?\d+$/) { return int32_to_hex_string($i) }

  # OK, is it already in form 'ZZ ZZ ZZ ZZ' where Z is hex char or x|X?

  if ($i =~ m/^([0-9a-fA-FxX]{1,2}\s+){3,3}[0-9a-fA-FxX]{1,2}$/) {
    return $i;
  }

  # Might have leading 'H' to indicate it's a hex number.
  $i =~ s/^H//;

  # Maybe just a stream of hex chars (or X) without spaces
  # e.g. 7Fxx6

  unless ($i =~ m/^[0-9a-fA-FxX]{1,8}$/) {
    confess "Bad format : expected integer or sequence of hex pairs (or X) but saw \'$i\'."
  }

  while (length($i) < 8) { $i = '0'.$i }
  my $s = substr($i,0,2).' '.substr($i,2,2).' '.substr($i,4,2).' '.substr($i,6,2);
  return $s
}


###############################################################
#
# Return the time when the NEXT packet can start to be transmitted
# to the specified port
# Params:
#         port    [1..$NF2_MAX_PORTS]
# Returns: 0 for error
#          else time in microseconds
#
###############################################################

sub nf_get_next_packet_time_us {

  my $port = shift;

  confess "nf_get_next_packet_time_us: port must be in [1..$NF2_MAX_PORTS]" unless
    (($port >= 1) && ($port <= $NF2_MAX_PORTS));

  if (defined $next_pkt_in[$port]) {
    return $next_pkt_in[$port]
  }
  else {
    return 0
  }

}


###############################################################
#
# Process a timeOrDelay parameter and return the 64 bit time
# it represents.
#
# Params: time    (if absolute then preced by @, else relative)
#                 default is ns unless appended by us or ms
#
# Returns: 0 for error
#          else time in nanoseconds in format ABS:time where
#          ABS = 1 if it's an absolute time or 0 if relative.
#          e.g. 1:1024 = 1024ns absolate time
#
###############################################################

sub process_timeOrDelay {

  if ($#_ != 0) { confess "process_timeOrDelay() : expected parameter" }

  my $time = shift;
  my $orig_time = $time;

  # See if its absolute
  my $abs = 0;

  if ($time =~ m/^@(.*)/) {
    $abs = 1;
    $time = $1;
  }

  # check scale
  my $scale = 1;  # ns

  if ($time =~ m/(.*)([umn])s$/) {
    $time = $1;
    $scale = 1000 if ($2 eq 'u');    # microsecs
    $scale = 1000000 if ($2 eq 'm'); #millisecs
  }

  unless ($time =~ m/^\d+(\.\d+)?$/) {
    print "Error: timeOrDelay \'$orig_time\' illegal - must be in format [@]<digits>[{ns,us,ms}].\n";
    return 0;
  }

  return "$abs:".($time*$scale);
}


###############################################################
#
# Set the environment for sims and hardware
#
# Params: reference to hash of key => value mappings
#         key: PORT_MODE or MAX_PORTS
#
# Returns: nothing
#
################################################################

sub nf_set_environment {

  if ($#_ != 0) { confess "nf_set_environment() : expected parameter (reference to anon hash)" }

  my $args = $_[0];

  #print "ARGS is ",(%{$args})," \n";

  for my $key (keys %{$args}) {
    my $val = $args->{$key};

    if ($key eq 'PORT_MODE')
      {

	confess "nf_set_environment(): parameter must be \'VLAN\' or \'PHYSICAL\' !" unless
	  (($val eq 'VLAN') or ($val eq 'PHYSICAL'));

	$NF2_PORT_MODE = $val;

	if ($NF2_PORT_MODE eq 'PHYSICAL') {$NF2_PHYS_PORTS = $NF2_MAX_PORTS}
	if ($NF2_PORT_MODE eq 'VLAN')     {$NF2_PHYS_PORTS = 1 }

	next;
      }

    if ($key eq 'MAX_PORTS')
      {
	if (($val <1) or ($val > 255)) {
	  confess "nf_set_environment(): MAX_PORTS value must be in range 1..255";
	}
	$NF2_MAX_PORTS = $val;

	if ($NF2_PORT_MODE eq 'PHYSICAL') {$NF2_PHYS_PORTS = $NF2_MAX_PORTS}
	if ($NF2_PORT_MODE eq 'VLAN')     {$NF2_PHYS_PORTS = 1 }

	nf_initialize();

	next;
      }

    confess "nf_set_environment(): Unknown key \"$key\" ";
  }
}


###############################################################
#
# Set up arrays based on MAX_PORTS. Gets called at beginning
# and also if MAX_PORTS gets changed by the user.
#
# Params: none
#
# Returns: none:
#
################################################################

sub nf_initialize {

  for (0..$NF2_MAX_PORTS) {
    push @ingress_pkts,[];
    push @next_pkt_in, $RESET_DONE;
    push @egress_pkts,[];
    push @rules,[];
  }

}

####################################################################
# returns:
# (&\nf_PCI_write32, 0, &\nf_PCI_read32, $main::delay, $main::batch)
####################################################################

sub nf_get_sim_reg_access {
  return (\&nf_PCI_write32, 0, \&nf_PCI_read32, $main::delay, $main::batch)
}

1;

__END__


=head1 NAME

NF::PacketGen - A Perl module for generating files of packets

=head1 DESCRIPTION

This library is for use with Perl programs that want to generate
packets for use in Verilog simulations or for use on the NetFPGA hardware
itself.

To include this in your program make sure that your PERL5LIB shell
variable includes the netfpga/lib/Perl5 directory and then add the
following line to your Perl script:

 use NF::PacketGen;

A typical script will typically have two stages:

- specify the various packets (data and control) that form the actual test.
You specify both the ingress packets as well as the expected egress packets.
All register read/writes are performed via a control packet.

- invoke the appropriate library routine to create the desired files for use
in either simulation of for sending to the actual NetFPGA hardware.

=head1 LIBRARY ROUTINES

=head2 nf_get_sim_reg_access

returns a list of functions to be used when accessing generic function. This
list returns (&\nf_PCI_write32, 0, &\nf_PCI_read32, $main::delay, $main::batch).


=head2 nf_packet_in( port, length, timeOrDelay, batch, data...)

Specifies an ingress packet. Returns 0 for success, 1 for error.

B<port> is the port the packet should enter on.

B<length> is the length (in bytes) of the data provided in the B<data> argument(s).
This is I<always> the length of the packet starting at the first byte of the
MAC Destination Address and ending at the last byte I<before> the CRC. So the actual
packet, when transmitted, will be 4 bytes longer when it has a CRC added. B<length>
can be in the range 60..10000 inclusive

So if you want a minimum sized Ethernet packet (64 bytes) then you would use a length
of 60 when specifying the packet to C<nf_packet_in()>.

B<timeOrDelay> is the B<earliest> time that this packet should arrive at the NetFPGA
in the simulation only (use the batch parameter for hardware tests).
Times are specified as digits with an optional timescale. The timescale can be one
of B<ns> (nanoseconds), B<us> (microseconds) or B<ms> (milliseconds). The default
scale is nanoseconds.
If you want to specify an absolute time (in the simulation) when the packet should
start to arrive then precede the number by B<@>.
e.g.

 @15us   means at the absolute time 15,000ns into the simulation.

 100     means 100ns from the end of the last packet (relative).

B<Note:> the B<timeOrDelay> parameter is the B<earliest> the event will happen
but it does not guarantee that the event weill happen at that time.

e.g. the current time in the simulation is 10,000 ns. The next event is
specified by @5,000ns. Clearly the time 5,000 ns has already passed, and so the
event will happen immediatley (at 10,000 ns).

If the current time is 10,000 ns and the event is specified as @15000ns
then the simulation will not start the event until the time 15,000 ns occurs.

B<batch> is an integer. It can be used to group a number of packets into
a single logical 'batch' which will be transmitted to NetFPGA in sequence.
The batch number is I<only> used during actual hardware tests and is ignored
in simulation.
The NetFPGA server will pause between batches, waiting
until no more packets are received from the NetFPGA system for a few seconds
before transmitting the next batch of packets.

Batch numbering starts from 0, and the order in which you
add each packet for each batch does not have to be in sequence. E.g. you
can add a packet for batch 0, then one for batch 1, and then another for
batch 0.

B<data> can be one or more values. Each value must be a string of pairs of hex digits
separated by a space. The combined number of hex pairs in all of the B<data> values
should be exactly the same as the B<length> parameter. You are allowed to pass
multiple values to improve readability - often it is easier to pass in separate
values for the DA, SA, Ethertype field, etc, rather than one long string.

e.g.

 nf_packet_in(1, 60, 0, 0, "AA 23 44 55 2D 11",
                           "08 00 33 12 94 66",
                           "34 56",
                           '00 'x46
             );

uses 4 B<data> values, whereas

 $data = "AA 23 44 55 2D 11 08 00 33 12 94 66 34 56". '00 'x46;
 nf_packet_in(1, 60,0,0,$data);

creates the same packet but uses just one data value. Note the use of the
string replicator function C<x> to replicate packet
data bytes - just don't forget to put the space after the value.


=head2 nf_expected_packet(port, length, data)

Specifies an expected egress packet. Returns a handle to the packet.

B<port> is the port the packet should exit on.

B<length> is length of packet (without CRC). See nf_packet_in()

B<data> is the packet data in pairs of hex digits (see nf_packet_in() ). In
addition to hex values, you may specify dont-care using x or X. Thus any nibble
in the data can be specified as a dont-care quantity.

The function returns a handle to the packet. This is for future use, to enable
users to specify individual packet rules.

=head2 nf_dma_data_in( length, timeOrDelay, data...)

Specifies ingress DMA data. Returns 0 for success, 1 for error.

B<length> is the length (in bytes) of the data provided in the B<data> argument(s).

B<timeOrDelay> is the B<earliest> time that this packet should arrive at the NetFPGA
in the simulation only. See nf_packet_in() for more details.

B<data> can be one or more values. Each value must be a string of pairs of hex digits
separated by a space. The combined number of hex pairs in all of the B<data> values
should be exactly the same as the B<length> parameter.
See nf_packet_in() for more details.

=head2 nf_expected_dma_data(queue, length, data)

Specifies an expected egress packet. Returns a handle to the packet.

B<queue> is the DMA queue. See nf_packet_in()

B<length> is length of packet. See nf_packet_in()

B<data> is the packet data in pairs of hex digits (see nf_packet_in() ). In
addition to hex values, you may specify dont-care using x or X. Thus any nibble
in the data can be specified as a dont-care quantity.

The function returns a handle to the packet. This is for future use, to enable
users to specify individual packet rules.

=head2 nf_PCI_read32(timeOrDelay, batch, address27, expected_data)

Specifies the time at which a PCI read should be performed, and the
expected data that should be read.
Returns 0 for success or 1 if an error occurred.

B<timeOrDelay> is the absolute time or delay (in ns) that the PCI read
should occur in simulation. See nf_packet_in() for more details.

B<batch> is the batch number when this PCI read should occur.
See nf_packet_in() for more details.

B<address27> is the address of the register that should
be read. Specify this as a Perl integer.

B<expected_data> is the 32 bit data that should be returned from the read.
Specify this as a Perl integer.

e.g.

 my $UNET_Scratch32_reg     = 0x400014;
 nf_PCI_read32(0,  $batch, $UNET_Scratch32_reg, 0x12345678);

=head2 nf_PCI_read32_masked(timeOrDelay, batch, address27, expected_data, mask)

Same as nf_PCI_read32() except that you can specify a bit mask (as an integer)
to be used when comparing the expected value with the actual value read. The
mask should be set such that a bit is 1 if it should be compared, and 0 otherwise.

Returns 0 for success and 1 if an error occurred.

e.g.

 nf_PCI_read32_masked(0, $batch, $UNET_ID_reg, 0x14444, 0x1ffff);

will only compare the least significant 17 bits.

=head2 nf_PCI_write32(timeOrDelay, batch, address27, data32)

Performs a PCI write at the specified time, to the specified address
with the specified data.
Returns 0 for success and 1 if an error occurred.

B<timeOrDelay> is the absolute time or delay (in ns) that the PCI write
should occur in simulation. See nf_packet_in() for more details.

B<batch> is the batch number when this PCI write should occur during hardware tests.
See nf_packet_in() for more details.

B<address27> is the address of the register that should
be written. Specify this as a Perl integer.

B<data32> is a 32 bit integer that should be written to the specified register.

e.g.

 nf_PCI_write32('1us', $batch, $UNET_Scratch32_reg, 0x12345678);


=head2 nf_add_port_rule(port, rule)

Specifies a rule that should be associated with a particular port. Returns 0
for success and 1 for error.

B<port> is an integer specifying the port in the range 1..NF2_MAX_PORTS.

B<rule> is a string specifying the rule that should be associated with the port.

Port rules are rules that apply to all packets that egress the specified port.

Current rules are:

  UNORDERED  - packets may egress the port in a different order to the
               expected order.

e.g.

  nf_add_port_rule(1,'UNORDERED');


=head2 nf_get_next_packet_time_us(port)

Use this to find out the earliest time that you can send in a
packet on the specified port. NOTE: the time is returned in microseconds.
Only valid for simulations and not hardware tests.

B<port> is an integer specifying the port in the range 1..NF2_MAX_PORTS.


=head2 nf_write_sim_files()

Usually called at the end of the packet generation script, this function
writes out the various ingress packet data files for use in a verilog
simulation. A separate file is generated for each port.

This function returns an estimate of time in the simulation when all
ingress packets will have been sent, in B<microseconds>. This can be
helpful when trying to set the time at which the simulation should finish.

=head2 nf_set_directory(directory)

Use this to specify which directory you want to use for the various files
that will be created. Default is packet_data.

=head2 nf_set_environment( { key => value } )

Use this to specify the environment used. Note: the parameter is an anonymous
array of key->value pairs.

B<key> can be: PORT_MODE or MAX_PORTS.

For B<PORT_MODE> the value can be PHYSICAL or VLAN (default is VLAN)

PHYSICAL : in this mode, when you specify a port then this will be the
actual physical ethernet port on the NetFPGA board (it has 4 ports).

VLAN : in this mode all packets use physical port 1, but the B<nf_packet_in>
and B<nf_expected_packet> functions will modify your packet to embed the
virtual port number in the packet using VLAN packets (IEEE 802.1Q). This
embedding should be transparent to you.

For B<MAX_PORTS> the value is the number of ports in your system. This refers
to either logical (VLAN) or physical ports, depending on the setting of PORT_MODE.
Ports are counted from 1, so if you specify 5 as MAX_PORTS then you will have ports
1..5. The minimum is 1. The maximum is 255. The default value is 4.

B<NOTE> Only set MAX_PORTS at the start of the simulation.

e.g.

 nf_set_environment( {
                      PORT_MODE => 'PHYSICAL',
                      MAX_PORTS => 8
                     }
                   );


=head2 nf_set_ingress_hardware_filename(filename)

Use this to specify the filename to use for ingress hardware packets. The
default is ingress_hardware.

=head2 nf_create_hardware_file(endian-ness)

Creates the hardware file in which ingress packets are stored. See below
for examples on how to use it. Takes in the desired byte-order or
endian-ness of the data - use LITTLE_ENDIAN or BIG_ENDIAN.

NOTE: the endian-ness specified here is the endian-ness used in the file
and has nothing to do with the endian-ness of NetFPGA. It depends on the
architecture of the server computer attached to NetFPGA. Use LITTLE_ENDIAN
if you are not sure.

Must be called before executing nf_write_hardware_file.

=head2 nf_write_hardware_file(endian-ness)

Used in conjunction with nf_packet_in(), this function writes the ingress
packet data into the hardware file for testing in hardware. Takes in the
desired byte-order or endian-ness of the data - use LITTLE_ENDIAN or
BIG_ENDIAN. See comment above on endian-ness.

=head2 nf_write_expected_files()

Usually called at the end of the packet generation script, this function
writes out the various expected egress packet data files. A separate file
is generated for each port.

These files would normally be used by a checking script, such as nf-u-compare.pl,
which attempts to match expected packets with packets that were actually
received.

The expected packets files use XML.

=head1 EXAMPLES

 #!/usr/local/bin/perl -w

 use NF::PacketGen;
 use strict;

 # Addresses of registers in PCI 24 bit address space
 # (i.e. the 16Mbyte of address space used by this board)

 my $UNET_ID_reg            = 0x400000;
 my $UNET_Reset_reg         = 0x400004;
 my $UNET_MAC_Reset_reg     = 0x400008;
 my $UNET_MAC_Enable_reg    = 0x40000c;
 my $UNET_MAC_Config_reg    = 0x400010;
 my $UNET_Scratch32_reg     = 0x400014;

 my $delay = 0;
 my $batch = 0;

 # Let's just check that basic register reads and writes work OK....
 # Read the ID register
 nf_PCI_read32_masked(0, $batch, $UNET_ID_reg, 0xf0ff4444, 0x1ffff);
 nf_PCI_write32('1us', $batch, $UNET_Scratch32_reg, 0x12345678);
 nf_PCI_read32(0,      $batch, $UNET_Scratch32_reg, 0x12345678);




 # *********** Finishing Up ***************************************
 my $t = nf_write_sim_files();
 print  "--- make_pkts.pl: Generated all configuration packets.\n";
 printf "--- make_pkts.pl: Last packet enters system (or last PCI access) at approx %0d microseconds.\n",($t/1000);
 if (nf_write_expected_files()) {
   die "Unable to write expected files\n";
 }

 nf_create_hardware_file('LITTLE_ENDIAN');
 nf_write_hardware_file('LITTLE_ENDIAN');



=cut
