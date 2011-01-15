#!/usr/bin/perl -w

#
# Script to copy the Proxy Server files to the user account and
# create the enviornment variables
#

use strict;

my $INSTALL_PREFIX = "/usr/local";
my $PROXY_SERVER_BIN = "../proxy_server_bin";

#Install libnf2regs.so which is required by Proxy Server
`install -d "$INSTALL_PREFIX"/lib`;
`install -m 644 "$PROXY_SERVER_BIN"/libnf2.so "$INSTALL_PREFIX"/lib`;
`rm -f "$INSTALL_PREFIX"/lib/libnf2regs.so`;
`ln -s "$INSTALL_PREFIX"/lib/libnf2.so "$INSTALL_PREFIX"/lib/libnf2regs.so`;
`ldconfig`;

#Install Proxy Server related binaries
`install -d "$INSTALL_PREFIX"/sbin`;
`install -m 700 "$PROXY_SERVER_BIN"/reg_proxy_server "$INSTALL_PREFIX"/sbin/netfpga.regproxy_server`;
`install -m 700 "$PROXY_SERVER_BIN"/netfpga.regproxy_server.init /etc/init.d/netfpga.regproxy_server`;
`rm -f "$INSTALL_PREFIX"/sbin/rcnetfpga.regproxy_server`;
`ln -s /etc/init.d/netfpga.regproxy_server "$INSTALL_PREFIX"/sbin/rcnetfpga.regproxy_server`;
`install -m 644 "$PROXY_SERVER_BIN"/netfpga.regproxy_server.config /etc/sysconfig/netfpga.regproxy_server`;

#Setup LD_LIBRARY_PATH for Proxy Server
print "Adding LD_LIBRARY_PATH Enviornment Variable to your .bashrc\n";
`cat proxy_addon >> ~/.bashrc\n`;
