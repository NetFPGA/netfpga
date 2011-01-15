#!/usr/bin/perl -w
#
# Script to copy the Proxy Client files to the user account and
# create the enviornment variables
#

use strict;

my $NF_DIR_COMMON    = "/root/netfpga/lib/C/common";
my $NF_DIR_REG_LIB   = "/root/netfpga/lib/C/reg_lib";
my $PROXY_CLIENT_BIN = "/root/netfpga";

if((-d "$NF_DIR_COMMON") && (-d "$NF_DIR_REG_LIB"))
{
    print "Compiling Proxy Client...\n";
    chdir($NF_DIR_COMMON) or die "Cant chdir to $NF_DIR_COMMON $!";
    `make clean`; `make`; `make install`;
    chdir($NF_DIR_REG_LIB) or die "Cant chdir to $NF_DIR_REG_LIB $!";
    `make clean`; `make`; `make install_client_lib`;
}
else
{
    print "Directories $NF_DIR_COMMON or $NF_DIR_REG_LIB do not exist\n";
    exit(1);
}

#Setup LD_LIBRARY_PATH for Proxy Client
print "Adding LD_LIBRARY_PATH Enviornment Variable to your .bashrc\n";
`cat "$PROXY_CLIENT_BIN"/proxy_addon >> ~/.bashrc\n`;
