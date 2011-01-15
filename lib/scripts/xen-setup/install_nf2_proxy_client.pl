#!/usr/bin/perl -w
#
# Script to copy the Proxy Client files to the user account and
# create the enviornment variables
#

use strict;

my $INSTALL_PREFIX = "/usr/local";
my $BITFILES_PREFIX = "/usr/local/netfpga/bitfiles";
my $PROXY_CLIENT_BIN = "../proxy_client_bin";

#Install libnf2regs.so which is required by Proxy Client
`install -d /usr/local/lib`;
`install -m 644 "$PROXY_CLIENT_BIN"/libnf2.so /usr/local/lib`;
`ln -s -f "$INSTALL_PREFIX"/lib/libnf2.so "$INSTALL_PREFIX"/lib/libnf2regs.so`;
`ldconfig`;

#Install Proxy Client library
`install -d "$INSTALL_PREFIX"/lib`;
`install -m 644 "$PROXY_CLIENT_BIN"/libreg_proxy.so "$INSTALL_PREFIX"/lib`;
`rm -f "$INSTALL_PREFIX"/lib/libnf2regs.so`;
`ln -s "$INSTALL_PREFIX"/lib/libreg_proxy.so "$INSTALL_PREFIX"/lib/libnf2regs.so`;
`ldconfig`;

#Setup LD_LIBRARY_PATH for Proxy Client
print "Adding LD_LIBRARY_PATH Enviornment Variable to your .bashrc\n";
`cat proxy_addon >> ~/.bashrc\n`;

#Install nf_download binary into /usr/local/bin
`rm -f "$INSTALL_PREFIX"/bin/nf_download`;
`cp ../download/nf_download "$INSTALL_PREFIX"/bin/nf_download`;

#Install regread and regwrite into /usr/local/bin
`rm -f "$INSTALL_PREFIX"/bin/regread`;
`cp ../reg_access/regread "$INSTALL_PREFIX"/bin/regread`;

`rm -f "$INSTALL_PREFIX"/bin/regwrite`;
`cp ../reg_access/regwrite "$INSTALL_PREFIX"/bin/regwrite`;

#Copy bitfiles into /usr/local/netfpga/bitfiles

if(!-d "$BITFILES_PREFIX")
{
  print "Creating NetFPGA directory to your user account\n";
  `mkdir -p "$BITFILES_PREFIX"`;
}

`cp ../bitfiles/cpci.bit "$BITFILES_PREFIX"/.`;
`cp ../bitfiles/cpci_reprogrammer.bit "$BITFILES_PREFIX"/.`;
`cp ../bitfiles/reference_nic.bit "$BITFILES_PREFIX"/.`;
