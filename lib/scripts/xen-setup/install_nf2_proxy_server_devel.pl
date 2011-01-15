#!/usr/bin/perl -w
#
# Script to download NetFPGA Bitfiles into NIC from XenServer DOM0 aka
# control domain
#
use strict;
use Getopt::Long;

my $NF_DIR_COMMON  = "/root/netfpga/lib/C/common";
my $NF_DIR_REG_LIB = "/root/netfpga/lib/C/reg_lib";
my $NF_DIR_SCRIPTS = "/root/netfpga/lib/scripts";
my $NF_DIR_ROOT    = "/root/netfpga";

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

if((-d "$NF_DIR_COMMON") && (-d "$NF_DIR_REG_LIB"))
{
    print "Compiling Proxy Server...\n";
    chdir($NF_DIR_COMMON) or die "Cant chdir to $NF_DIR_COMMON $!";
    `make clean`; `make`; `make install`;
    chdir($NF_DIR_REG_LIB) or die "Cant chdir to $NF_DIR_REG_LIB $!";
    `make clean`; `make`;
    chdir($NF_DIR_COMMON) or die "Cant chdir to $NF_DIR_COMMON $!";
    `scp libnf2.so. root@"$ipaddr":/root/proxy_server_bin`;
    chdir($NF_DIR_REG_LIB) or die "Cant chdir to $NF_DIR_REG_LIB $!";
    `scp reg_proxy_server root@"$ipaddr":/root/proxy_server_bin`;
    `scp netfpga.regproxy_server.init root@"$ipaddr":/root/proxy_server_bin`;
    `scp netfpga.regproxy_server.config root@"$ipaddr":/root/proxy_server_bin`;
    chdir($NF_DIR_SCRIPTS) or die "Cant chdir to $NF_DIR_SCRIPTS $!";
    `scp install_nf2_proxy_server.pl root@"$ipaddr":/root`;
    chdir($NF_DIR_ROOT) or die "Cant chdir to $NF_DIR_ROOT $!";
    `scp proxy_addon root@"$ipaddr":/root/proxy_server_bin`;
}
else
{
    print "Directories $NF_DIR_COMMON or $NF_DIR_REG_LIB do not exist\n";
    exit(1);
}
