#!/usr/bin/perl -w
#
# $Id$
# This script reads a configuration file that describes a topology and
# verifies that the connections indeed match the topology.
#
# It does this by ssh'ing into the machines and sending packets using
# send_pkts, and checking that the pkts are received on the right ports.
#
# Author: Jad Naous
#

use strict;
use Cwd;
use Getopt::Long;
use File::Basename;
use POSIX ":sys_wait_h";

# default config file
my $config_file="./config";

# default locations
my $NF_ROOT="../../..";
my $send_pkts_dir="${NF_ROOT}/lib/C/tools/send_pkts";
my $send_pkts_bin="${NF_ROOT}/lib/C/tools/send_pkts/send_pkts";
my $refnic_bitfile="${NF_ROOT}/bitfiles/reference_nic.bit";
my $tmpdir=$ENV{TMPDIR};
$tmpdir = "/tmp" unless defined $tmpdir;

# list of links
my @links=();

# parse commandline options
my $help='';
my $setup_keys=0;
my $no_source=0;
my $no_download=0;
my @opts=@ARGV;

unless ( GetOptions ( "config_file=s" => \$config_file,
		      "nf2_root=s" => \$NF_ROOT,
		      "send_pkts_dir=s" => \$send_pkts_dir,
		      "send_pkts_bin=s" => \$send_pkts_bin,
		      "refnic_bitfile=s" => \$refnic_bitfile,
		      "setup_keys" => \$setup_keys,
		      "no_source" => \$no_source,
		      "no_download" => \$no_download,
		      "help" => \$help
		     )
	 and ($help eq '')
       ) { usage(); exit 1 }

# filenames
my $send_pkts_name = fileparse($send_pkts_bin);
my ($refnic_name, $refnic_dir) = fileparse($refnic_bitfile);

# Get topology configuration
my %machines;
eval `cat $config_file`;
my @machines = keys %machines;
$ENV{MACHINE_LIST}="@machines";

print "Found machines @machines.\n";

# machines with netfpga interfaces
my @nf_machines=();
foreach my $machine (keys %machines) {
  my @ifaces = keys %{$machines{$machine}};
  my $num_nf_ifaces = map {$_ =~ /^nf2c/} @ifaces;
  print "Found $num_nf_ifaces nf2 ifaces on $machine.\n";
  push(@nf_machines, $machine) if($num_nf_ifaces > 0);
}

die ("Can't find reference nic bitfile $refnic_bitfile.\n")
  if ((! -r $refnic_bitfile) && scalar(@nf_machines)>0 && $no_download!=1);

# setup keys on the machines for communication if requested
if($setup_keys) {
  print "Setting up keys on machines: @machines.\n";
  system("./setup_machines.sh") == 0
    or die "Failed to setup keys on machines.\n";
}

# use the helper to source the net_commons once
unless($no_source) {
  exec("./verify_helper.sh @opts");
}

# copy send_pkts to all machines
unless( -x $send_pkts_bin) {
  system("make -C $send_pkts_dir");
  die "Failed to build send_pkts.\n" unless -x $send_pkts_bin;
}

system("cp $send_pkts_bin .; ./exec_scp.sh $send_pkts_name /tmp") == 0
  or die "Failed to copy send_pkts to all machines.\n";
unlink($send_pkts_name);

# copy the reference_nic bitfile to all machines with netfpga
if (scalar @nf_machines > 0 && $no_download != 1) {
  $ENV{MACHINE_LIST}="@nf_machines";
  system("cp $refnic_bitfile .; ./exec_scp.sh $refnic_name /tmp") == 0
    or die "Failed to copy nic bitfile $refnic_bitfile to NF machines.\n";
  unlink $refnic_name;

  # reprogram the netfpga on each machine
  print "Reprogramming the netfpga to a NIC on all machines.\n";
  system("./exec_cmd.sh \"sudo nf_download /tmp/$refnic_name ; sleep 1 ; exit\"") == 0
    or die "Failed to download reference nic on NF machines.\n";

  $ENV{MACHINE_LIST}=keys %machines;
}

# make sure all interfaces are up
my $cmd = "source net_common.sh;\n";
foreach my $machine (keys %machines) {
  my @ifaces = keys %{$machines{$machine}};
  $cmd = $cmd . "ssh -t -i \$NET_ID \$NET_USER\@$machine 'for iface in @ifaces; \n";
  $cmd = $cmd . "do sudo /sbin/ifconfig \$iface up;\n done ; exit';\n ";
}
system($cmd) == 0 or die "Failed to bring up interfaces on machines.\n";

# verify each link in the topology
print "\n\n--------------------------------------------------------------------\n";
foreach my $link (@links) {
  verify_link($link);
}
print "--------------------------------------------------------------------\n\n";

exit(0);

##########################################################
# add_link
#   adds a link between two interfaces in a topology
sub add_link {
  my ($machine1, $iface1, $machine2, $iface2) = @_;

  die "Arguments for add_link are (machine1, iface1, machine2, iface2),\n".
    "where machineX can be IP or DNS name, ifaceX is the interface on ".
      "machineX \nthat is used in the link.\n"
	unless (defined $machine1 && defined $iface1 &&
		defined $machine2 && defined $iface2);

  # check that machine1/2 is in the list
  die "Machine $machine1 is not in the \%machines hash.\n"
    unless exists $machines{$machine1};

  die "Machine $machine2 is not in the \%machines hash.\n"
    unless exists $machines{$machine2};

  # check that the interfaces exist
  die "Interface $iface1 on machine $machine1 is not in the \%machines hash.\n"
    unless exists $machines{$machine1}->{$iface1};
  die "Interface $iface2 on machine $machine2 is not in the \%machines hash.\n"
    unless exists $machines{$machine2}->{$iface2};

  push @links, {machine1 => $machine1,
		iface1 => $iface1,
		machine2 => $machine2,
		iface2 => $iface2};
}

##########################################################
# verify_link
#   verifies that a link is connected between two machines
sub verify_link {
  my $link = shift; # reference to hash

  my $iface1 = $link->{iface1};
  my $machine1 = $link->{machine1};
  my $iface2 = $link->{iface2};
  my $machine2 = $link->{machine2};

  # Fork a process that will start the receiver
  my $rcvr_pid=fork;
  if($rcvr_pid == 0) {
    # I am child and so start rcvr
    my $cmd = "ssh -t -i \$NET_ID \$NET_USER\@$machine1 ".
      "'sudo /tmp/$send_pkts_name -i $iface1 -c' 2>&1" .
	"|grep 'Rcv done' |awk '{print \$4}'";
    my $percent = `$cmd`;

    chomp $percent;
    if($percent =~ "100.00") {
      exit(0);
    } else {
      exit(1);
    }
  }

  # Fork a process that will start the sender
  my $sndr_pid=fork;

  if($sndr_pid == 0) {
    # I am the child and so I will start the sender in 1s
    select(undef, undef, undef, 1);
    my $cmd = "ssh -t -i \$NET_ID \$NET_USER\@$machine2 ".
      "'sudo /tmp/$send_pkts_name -i $iface2 -c -s 10' 2>&1 >/dev/null";
    system($cmd) == 0 or die "Failed to run sender.\n";
    exit(0);
  }

  waitpid $sndr_pid, 0;
  select(undef, undef, undef, 0.5);
  waitpid $rcvr_pid, WNOHANG;
  my $red="\e[0;31m";
  my $green="\e[0;32m";
  my $normal="\e[0;39m";
  if($? == 0) {
    print "Link $machine1:$iface1 <-> $machine2:$iface2 $green verified $normal\n";
  } else {
    print "Link $machine1:$iface1 <-> $machine2:$iface2 $red FAIL $normal\n";
    system("ssh -t -i \$NET_ID \$NET_USER\@$machine1 'sudo killall send_pkts' 2>&1 >/dev/null");
  }
  waitpid $rcvr_pid, 0;
}

#########################################################
# usage
#   print usage information
sub usage {
  (my $cmd = $0) =~ s/.*\///;
  print <<"HERE1";
NAME
   $cmd - verify a topology matches current connections

SYNOPSIS
   $cmd
        [--config_file <config file>]
	[--nf2_root <location of nf2 root>]
        [--send_pkts_dir <dir of send_pkts tool>]
        [--send_pkts_bin <compiled send_pkts tool>]
        [--refnic_bitfile <bitfile of reference nic>]
        [--no_download]
        [--setup_keys]

   $cmd --help  - show detailed help

HERE1

  return unless ($help);
  print <<"HERE";

DESCRIPTION

   This script can be used to verify a topology is connected correctly.
   It uses send_pkts to test links and make sure a packet can be sent
   between two interfaces.
   It is best to use the setup_keys option in order to avoid typing
   in a password repeatedly. You only have to do this once.

OPTIONS
   --config_file <config file>
     Specify the name of the file that contains the topology specification.
     Default is config.

   --nf2_root <dirname>
     Location of the NetFPGA root directory. Defaults to the NF_ROOT
     environment variable. Not used if send_pkts_dir, send_pkts_bin, and
     refnic_bitfile are specified.

   --send_pkts_dir <dirname>
     Location of the source code for send_pkts. Defaults to
     NF_ROOT/lib/C/tools/send_pkts/. Not needed if --send_pkts_bin is used
     and the send_pkts binary is already compiled and executable.

   --send_pkts_bin <path>
     Location of compiled executable send_pkts binary.

   --refnic_bitfile <bitfile>
     Location of the bitfile for the reference nic. Defaults to
     NF_ROOT/bitfiles/. Not needed if there are no NetFPGA interfaces.

   --no_download
     Do not download the reference nic bitfile on the NetFPGA.

EXAMPLE

   To setup keys and verify a topology:

   % ./$cmd --setup_keys

   If keys had already been setup:

   % ./$cmd

HERE
}

