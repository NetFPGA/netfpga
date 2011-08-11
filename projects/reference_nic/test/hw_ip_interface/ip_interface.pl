#!/usr/bin/perl

use strict;
use Getopt::Long;

use NF::RegressLib;

my %ifaceNameMap;

# Process command line options
my $help = '';
my $mapFile;
unless ( GetOptions (
		"help" => \$help,
		"map=s" => \$mapFile
	  )
	  and ($help eq '')
	) { usage(); exit 1 }

#
# Verify that the mapfile exists
#
if (defined($mapFile)) {
	nftest_process_iface_map($mapFile);
}


my $globe_fail = 0;

for (my $i = 0; $i < 4; $i++)
{
	my $device = nftest_get_iface("nf2c$i");
	print "Testing IP assignment to $device";
	`/sbin/ifconfig $device up`;
	my $temp = `/sbin/ip address flush dev $device 2>&1`; #clear the IP addresses from interface
	`/sbin/ifconfig $device 192.168.5.4`;
	my $output = `/sbin/ifconfig $device`;
	my @elements = split(/[:\s+]/, $output);

	my $success = 0;
	for (my $j = 0; $j < @elements; $j++)
	{
		if($elements[$j] eq "inet" && $elements[$j+1] eq "addr")
		{
			if($elements[$j+2] eq "192.168.5.4")
			{
			  $success = 1;
			}
			$j = 99;
		}
	}


	my $temp2 = `/sbin/ip address flush dev $device 2>&1`; #clear the IP addresses from interface
	if($success == 1)
	{
		print "...Success\n";

	}
	else
	{
		print "...FAILED\n";
	  $globe_fail++;
	}

}

if ($globe_fail != 0)
{
	exit 1;
}
else
{
	exit 0;
}



sub usage {
  (my $cmd = $0) =~ s/.*\///;
  print <<"HERE1";
NAME
   $cmd - regression suite script

SYNOPSIS
   $cmd [--map <mapfile>]

   $cmd --help  - show detailed help

HERE1

}
