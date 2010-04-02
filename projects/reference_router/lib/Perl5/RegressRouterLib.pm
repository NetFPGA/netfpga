#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
# $Id: TestLib.pm 5487 2009-05-06 19:00:34Z g9coving $
#
#
# NetFPGA Router test library for loading Router Tables
#
#
# Invoke using: use NF::RegressRouterLib
#
# Module provides NetFPGA-specific Router functions
#
# Revisions:
#
##############################################################

use Test::TestLib;
use NF::RegressLib;
use RouterLib;

package RegressRouterLib;

use strict;
use Exporter;

use Test::TestLib;
use Test::Pcap;
use Test::PacketLib;

use SimLib;
use NF::RegAccess;

use threads;
use threads::shared;
use Net::RawIP;
use Getopt::Long;

use vars qw(@ISA @EXPORT);    # needed cos strict is on

@ISA    = ('Exporter');
@EXPORT = qw(
  &nftest_set_router_MAC
  &nftest_get_router_MAC
  &nftest_add_LPM_table_entry
  &nftest_check_LPM_table_entry
  &nftest_invalidate_LPM_table_entry
  &nftest_contains_LPM_table_entries
  &nftest_add_dst_ip_filter_entry
  &nftest_contains_dst_ip_filter_entries
  &nftest_invalidate_dst_ip_filter_entry
  &nftest_add_ARP_table_entry
  &nftest_invalidate_ARP_table_entry
  &nftest_check_ARP_table_entry
  &nftest_contains_ARP_table_entries
);

# Sets the package to main to ensure all of the functions
# are in the main namespace. Returns to RouterLib before continuing.
package NF2;
package RegressRouterLib;

################################################################
# Name: nftest_set_router_MAC
#
# Sets the MAC of a port
#
# Arguments: ifaceName string
#            MAC       string in format xx:xx:xx:xx:xx:xx
#
# Return:
################################################################
sub nftest_set_router_MAC {
	my $ifaceName = shift;
	my $portNum   = $ifaceName;

	my %ifaceNameMap = nftest_get_iface_name_map();
	die "Couldn't find interface $ifaceName.\n" unless defined $ifaceNameMap{$ifaceName};

	die "Interface has to be an nfcX interface\n" unless ( $ifaceName =~ /^nf2c/ );
	$portNum =~ s/nf2c//;
	$portNum = ( $portNum % 4 ) + 1;
	my @reg_access = NF::RegressLib::nftest_get_hw_reg_access($ifaceName);

	main::set_router_MAC_generic( $portNum, @_, @reg_access );
}

################################################################
# Name: nftest_get_router_MAC
#
# Gets the MAC of a port
#
# Arguments: ifaceName string
#
# Return: MAC address of interface in xx:xx:xx:xx:xx:xx format
################################################################
sub nftest_get_router_MAC {
	my $ifaceName = shift;
	my $portNum   = $ifaceName;

	my %ifaceNameMap = nftest_get_iface_name_map();
	die "Couldn't find interface $ifaceName.\n" unless defined $ifaceNameMap{$ifaceName};

	die "Interface has to be an nfcX interface\n" unless ( $ifaceName =~ /^nf2c/ );
	$portNum =~ s/nf2c//;
	$portNum = ( $portNum % 4 ) + 1;
	my @reg_access = NF::RegressLib::nftest_get_hw_reg_access($ifaceName);

	return main::get_router_MAC_generic( $portNum, @reg_access );
}

################################################################
# Name: nftest_add_LPM_table_entry
#
# Adds an entry to the routing table in the hardware.
#
# Arguments: ifaceName   string
#            entryIndex  int
#            subnetIP    string in format w.x.y.z
#            subnetMask  string in format w.x.y.z
#            nextHopIP   string in format w.x.y.z
#            outputPort  one-hot-encoded ports
#                        0x01 is MAC0, 0x02 is CPU0,
#                        0x04 is MAC1, 0x08 is CPU1,
#                        0x10 is MAC2, 0x20 is CPU2,
#                        0x40 is MAC3, 0x80 is CPU3,
# Return:
################################################################
sub nftest_add_LPM_table_entry {
	my @reg_access = NF::RegressLib::nftest_get_hw_reg_access(shift);
	main::add_LPM_table_entry_generic( @_, @reg_access );
}

################################################################
# Name: nftest_check_LPM_table_entry
#
# Checks that the entry at the given index in the routing table
# matches the provided data
#
# Arguments: ifaceName   string
#            entryIndex  int
#            subnetIP    string in format w.x.y.z
#            subnetMask  string in format w.x.y.z
#            nextHopIP   string in format w.x.y.z
#            outputPort  one-hot-encoded ports
#                        0x01 is MAC0, 0x02 is CPU0,
#                        0x04 is MAC1, 0x08 is CPU1,
#                        0x10 is MAC2, 0x20 is CPU2,
#                        0x40 is MAC3, 0x80 is CPU3,
# Return:
################################################################
sub nftest_check_LPM_table_entry {
	my @reg_access = NF::RegressLib::nftest_get_hw_reg_access(shift);
	main::check_LPM_table_entry_generic( @_, @reg_access );
}

################################################################
# Name: nftest_invalidate_LPM_table_entry
#
# clears an entry in the routing table (by setting everything
# to 0)
#
# Arguments: ifaceName   string
#            entryIndex  int
#
# Return:
################################################################
sub nftest_invalidate_LPM_table_entry {
	my @reg_access = NF::RegressLib::nftest_get_hw_reg_access(shift);
	main::invalidate_LPM_table_entry_generic( @_, @reg_access );
}

################################################################
# Name: nftest_contains_LPM_table_entries
#
# Compares the expected_entries array against what is in hardware
# returning any expected_entries that do not exist in hardware
#
# Arguments: expected_entries array of entries, with each field
# separated by a hyphen ('-')
#
# Return: array of missing entries as strings
################################################################
sub nftest_contains_LPM_table_entries {
	my @reg_access       = NF::RegressLib::nftest_get_hw_reg_access("nf2c0");
	my $expected_entries = shift;
	my %actual_entries;
	my @missing_entries;

	for ( 0 .. ( main::ROUTER_OP_LUT_ROUTE_TABLE_DEPTH() - 1 ) ) {
		my $entry = main::get_LPM_table_entry_generic( $_, @reg_access );
		$actual_entries{$entry} = $entry;
	}

	foreach my $expected_entry (@$expected_entries) {
		if ( !exists $actual_entries{$expected_entry} ) {
			push( @missing_entries, $expected_entry );
		}
	}

	return \@missing_entries;
}

################################################################
# Name: nftest_add_dst_ip_filter_entry
#
# Adds an entry in the IP destination filtering table. Any
# packets with IP dst addr that matches in this table is sent to
# the CPU. This is also used to set the IP address of the
# router's ports.
#
# Arguments: ifaceName   string
#            entryIndex  int
#            destIP      string in format w.x.y.z
# Return:
################################################################
sub nftest_add_dst_ip_filter_entry {
	my $ifaceName  = shift;
	my @reg_access = NF::RegressLib::nftest_get_hw_reg_access($ifaceName);
	main::add_dst_ip_filter_entry_generic( @_, @reg_access );
}

################################################################
# Name: nftest_add_dst_ip_filter_entry
#
# Removes an entry from the IP destination filtering table by
# setting it to 0.
#
# Arguments: ifaceName   string
#            entryIndex  int
#
# Return:
################################################################
sub nftest_invalidate_dst_ip_filter_entry {
	my @reg_access = NF::RegressLib::nftest_get_hw_reg_access(shift);
	main::invalidate_dst_ip_filter_entry_generic( @_, @reg_access );
}

################################################################
# Name: nftest_contains_dst_ip_filter_entries
#
# Compares the expected_ips array against what is in hardware
# returning any expected_ips that do not exist in hardware
#
# Arguments: expected_ips array of ip address strings
#
# Return: array of missing ip address strings
################################################################
sub nftest_contains_dst_ip_filter_entries {
	my @reg_access   = NF::RegressLib::nftest_get_hw_reg_access("nf2c0");
	my $expected_ips = shift;
	my %actual_ips;
	my @missing_ips;

	for ( 0 .. ( main::ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH() - 1 ) ) {
		my $ip = main::get_dst_ip_filter_entry_generic( $_, @reg_access );
		$actual_ips{$ip} = $ip;
	}

	foreach my $expected_ip (@$expected_ips) {
		if ( !exists $actual_ips{ main::dotted($expected_ip) } ) {
			push( @missing_ips, $expected_ip );
		}
	}

	return \@missing_ips;
}

################################################################
# Name: nftest_add_ARP_table_entry
#
# adds an entry to the hardware's ARP table.
#
# Arguments: ifaceName   string
#            entryIndex  int
#            nextHopIP   string in format w.x.y.z
#            nextHopMAC  string in format w.x.y.z
#
# Return:
################################################################
sub nftest_add_ARP_table_entry {
	my @reg_access = NF::RegressLib::nftest_get_hw_reg_access(shift);
	main::add_ARP_table_entry_generic( @_, @reg_access );
}

################################################################
# Name: nftest_invalidate_ARP_table_entry
#
# clears an entry from the hardware's ARP table by setting to
# all zeros.
#
# Arguments: ifaceName   string
#            entryIndex  int
#
# Return:
################################################################
sub nftest_invalidate_ARP_table_entry {
	my @reg_access = NF::RegressLib::nftest_get_hw_reg_access(shift);
	main::invalidate_ARP_table_entry_generic( @_, @reg_access );
}

################################################################
# Name: nftest_check_ARP_table_entry
#
# checks the entry in the hardware's ARP table.
#
# Arguments: ifaceName   string
#            entryIndex  int
#            nextHopIP   string in format w.x.y.z
#            nextHopMAC  string in format w.x.y.z
#
# Return:
################################################################
sub nftest_check_ARP_table_entry {
	my @reg_access = NF::RegressLib::nftest_get_hw_reg_access(shift);
	main::check_ARP_table_entry_generic( @_, @reg_access );
}

################################################################
# Name: nftest_contains_ARP_table_entries
#
# Compares the expected_entries array against what is in hardware
# returning any expected_entries that do not exist in hardware
#
# Arguments: expected_entries array of entries, with each field
# separated by a hyphen ('-')
#
# Return: array of missing entries as strings
################################################################
sub nftest_contains_ARP_table_entries {
	my @reg_access       = NF::RegressLib::nftest_get_hw_reg_access("nf2c0");
	my $expected_entries = shift;
	my %actual_entries;
	my @missing_entries;

	for ( 0 .. ( main::ROUTER_OP_LUT_ARP_TABLE_DEPTH() - 1 ) ) {
		my $entry = main::get_ARP_table_entry_generic( $_, @reg_access );
		$actual_entries{$entry} = $entry;
	}

	foreach my $expected_entry (@$expected_entries) {
		if ( !exists $actual_entries{$expected_entry} ) {
			push( @missing_entries, $expected_entry );
		}
	}

	return \@missing_entries;
}

1;
