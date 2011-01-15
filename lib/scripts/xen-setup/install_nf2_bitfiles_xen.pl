#!/usr/bin/perl -w
#
# Script to download NetFPGA Bitfiles into NIC from XenServer DOM0 aka
# control domain
#
use strict;
use Getopt::Long;

my $NF_DIR_SCRIPTS      = "/root/netfpga/lib/scripts/cpci_reprogram";
my $NF_DIR_BITFILES     = "/root/netfpga/bitfiles";
my $NF_DIR_DOWNLOAD     = "/root/netfpga/lib/C/download";
my $NF_DIR_CPCI_SCRIPTS = "/root/netfpga/lib/scripts/cpci_config_reg_access";

# Verify the command line arguments
if ($#ARGV != 0) {
    usage();
    exit 1;
}

sub usage {
	(my $cmd = $0) =~ s/.*\///;
	print <<"HERE1";
NAME
   $cmd - Setup NetFPGA Bitfiles download from DOM0

SYNOPSIS
   $cmd <IP Address of DOM0>

HERE1
}

my $ipaddr=$ARGV[0];

if(-d "$NF_DIR_SCRIPTS")
{
    print "Copying cpci_reprogram.pl...\n";
    chdir($NF_DIR_SCRIPTS) or die "Cant chdir to $NF_DIR_SCRIPTS $!";
    `scp cpci_reprogram.pl root@"$ipaddr":/usr/local/sbin`;
}
else
{
    print "Directory $NF_DIR_SCRIPTS does not exist\n";
    exit(1);
}

if(-d "$NF_DIR_BITFILES")
{
    print "Copying NetFPGA Bitfiles...\n";
    chdir($NF_DIR_BITFILES) or die "Cant chdir to $NF_DIR_BITFILES $!";
    `scp cpci.bit root@"$ipaddr":/usr/local/netfpga/bitfiles`;
    `scp cpci_reprogrammer.bit root@"$ipaddr":/usr/local/netfpga/bitfiles`;
    `scp reference_nic.bit root@"$ipaddr":/usr/local/netfpga/bitfiles`;
}
else
{
    print "Directory $NF_DIR_BITFILES does not exist\n";
    exit(1);
}

if(-d "$NF_DIR_DOWNLOAD")
{
    print "Copying nf_download...\n";
    chdir($NF_DIR_DOWNLOAD) or die "Cant chdir to $NF_DIR_DOWNLOAD $!";
    `make clean`; `make`;
    `scp nf_download root@"$ipaddr":/usr/local/bin`;
}
else
{
    print "Directory $NF_DIR_DOWNLOAD does not exist\n";
    exit(1);
}

if(-d "$NF_DIR_CPCI_SCRIPTS")
{
    print "Copying dump_regs.sh and load_regs.sh...\n";
    chdir($NF_DIR_CPCI_SCRIPTS) or die "Cant chdir to $NF_DIR_CPCI_SCRIPTS $!";
    `scp dumpregs.sh root@"$ipaddr":/usr/local/sbin`;
    `scp loadregs.sh root@"$ipaddr":/usr/local/sbin`;
}
else
{
    print "Directory $NF_DIR_CPCI_SCRIPTS does not exist\n";
    exit(1);
}
