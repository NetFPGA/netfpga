#!/usr/bin/perl -w

#
# Script to copy the NetFPGA files to the user account and
# create the enviornment variables
# $Id: user_account_setup.pl gac1 $
#

use strict;

my $NF_DIR = $ENV{"HOME"} . "/netfpga";

if(-d "$NF_DIR")
{
	print "NetFPGA directory already exists copy has been canceled\n";
}
else
{
  print "Copying the NetFPGA directory to your user account\n";
  `cp -r /usr/local/netfpga ~`;
}

print "Adding the NetFPGA Enviornment Variables to your .bashrc\n";
`cat /usr/local/netfpga/bashrc_addon >> ~/.bashrc\n`;
