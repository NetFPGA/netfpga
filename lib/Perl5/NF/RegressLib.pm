#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
# $Id: RegressLib.pm 6067 2010-04-01 22:36:26Z grg $
#
#
# NetFPGA test library for sending/receiving packets
#
#
# Invoke using: use NF::RegressLib
#
# Module provides NetFPGA-specific functions
#
# Revisions:
#
##############################################################

use Test::TestLib;

package NF::RegressLib;

use strict;
use Exporter;

use Test::TestLib;
use Test::Pcap;
use Test::PacketLib;

use NF::Base;
use NF::RegAccess;

use threads;
use threads::shared;
use Net::RawIP;
use Getopt::Long;

use vars qw(@ISA @EXPORT);    # needed cos strict is on

@ISA    = ('Exporter');
@EXPORT = qw(
  &nftest_get_hw_reg_access
  &nftest_get_badReads
  &nftest_regwrite
  &nftest_regread
  &nftest_regread_expect

  &nftest_fpga_reset
  &nftest_phy_loopback
  &nftest_phy_reset
  &nftest_reset_phy
);

# badReads[x]=(ifname,
#              address,
#              expected_value,
#              found_value)
my @badReads;

use constant CPCI_Control_reg => 0x008;

###############################################################
# Name: nftest_get_hw_reg_access
#
# Used to access NF21RouterLib generic functions
# returns (\&nftest_regwrite, \&nftest_regread,
#          \&nftest_regread_expect, device)
#
# Arguments: device
#
###############################################################
sub nftest_get_hw_reg_access {
	my $ifaceName = shift;
	my %ifaceNameMap = nftest_get_iface_name_map();
	die "Interface $ifaceName is not known\n"
	  unless defined $ifaceNameMap{$ifaceName};
	return ( \&nftest_regwrite, \&nftest_regread, \&nftest_regread_expect, $ifaceName );
}

###############################################################
# Name: nftest_get_badReads
# Subroutine to access failed reads list
# Arguments: none
# Returns  : @badReads which is a list of lists
#                      badReads[x]=(ifname,
#                                   address,
#                                   expected_value,
#                                   found_value)
###############################################################
sub nftest_get_badReads {
	return @badReads;
}

###############################################################
# Name: nftest_regwrite
# writes a register to the netfpga
# Arguments: ifaceName string
#            address   uint32
#            value     uint32
# Return:
###############################################################
sub nftest_regwrite {
	my $ifaceName = shift;
	my %ifaceNameMap = nftest_get_iface_name_map();
	die "Interface $ifaceName is not known\n"
	  unless defined $ifaceNameMap{$ifaceName};
	nf_regwrite( $ifaceNameMap{$ifaceName}, @_ );
}

###############################################################
# Name: nftest_regread
#
# reads a register from the NetFPGA and returns the value
#
# Arguments: ifaceName string
#            address   uint32
#
# Return:    value     uint32
###############################################################
sub nftest_regread {
	my $dev = shift;
	my %ifaceNameMap = nftest_get_iface_name_map();
	return nf_regread( $ifaceNameMap{$dev}, @_ );
}

###############################################################
# Name: nftest_regread_expect
#
# reads a register from the NetFPGA and compares it to
# given value
#
# Arguments: ifaceName string
#            address   uint32
#            exp_value uint32
#            mask      uint32  (optional. 0 specifies don't cares)
#
# Return:    value     boolean
###############################################################
sub nftest_regread_expect {
	my $device = shift;
	my $addr   = shift;
	my $exp    = shift;
	my $mask   = shift;

	$mask = 0xffffffff unless defined $mask;

	my %ifaceNameMap = nftest_get_iface_name_map();
	my $val = nf_regread( $ifaceNameMap{$device}, $addr );

	if ( ( $val & $mask ) != ( $exp & $mask ) ) {
		printf "ERROR: Register read expected $exp (0x%08x) ", $exp;
		printf "but found $val (0x%08x) at address 0x%08x\n", $val, $addr;
		push @badReads, [ $device, $addr, $exp, $val ];
	}

	return $val;
}

###############################################################
# Name: nftest_fpga_reset
# Resets both the Virtex and Spartan FPGAs
# Note: This resets the state of the logic but does not clear
# the FGPGAs
# Arguments: $ifaceName string containing name of interface
# Returns:
###############################################################
sub nftest_fpga_reset {
	my $ifaceName = shift;

	my %ifaceNameMap = nftest_get_iface_name_map();
	die "Interface $ifaceName is not known\n"
	  unless defined $ifaceNameMap{$ifaceName};

	# Must write 1 into bit 8 while keeping the other values
	my $currVal = nf_regread( $ifaceNameMap{$ifaceName}, CPCI_Control_reg );
	$currVal |= 0x100;
	nf_regwrite( $ifaceNameMap{$ifaceName}, CPCI_Control_reg, $currVal );

	# Sleep for a while to allow the reset to complete
	sleep 1;
}

###############################################################
# Name: nftest_reset_phy
# resets the phy on the NetFPGA
# Arguments: $ifaceName string containing name of interface
# Returns:
###############################################################
sub nftest_reset_phy {

	my %pktHashes = nftest_get_pkt_hashes();

	# reset PHY in case it has been modified
	foreach my $ifaceName ( keys %pktHashes ) {
		if ( $ifaceName =~ /^nf2c/ ) {
			nftest_phy_reset($ifaceName);
		}
	}

	`sleep 6`;

	return;
}

###############################################################
# Name: nftest_phy_loopback
# Puts the phy in loopback mode
# Arguments: $ifaceName string containing name of interface
# Returns:
###############################################################
sub nftest_phy_loopback {
	my $ifaceName = shift;
	my $portNum   = $ifaceName;

	my %ifaceNameMap = nftest_get_iface_name_map();
	die "Couldn't find interface $ifaceName.\n" unless defined $ifaceNameMap{$ifaceName};
	die "Interface has to be an nfcX interface\n" unless ( $ifaceName =~ /^nf2c/ );

	$portNum =~ s/nf2c//;
	$portNum = ( $portNum % 4 );

	my @addr = (
		main::MDIO_PHY_0_CONTROL_REG(), main::MDIO_PHY_1_CONTROL_REG(),
		main::MDIO_PHY_2_CONTROL_REG(), main::MDIO_PHY_3_CONTROL_REG()
	);
	nftest_regwrite( $ifaceName, $addr[$portNum], 0x5140 );
	system "usleep 10";
}

###############################################################
# Name: nftest_phy_reset
# resets the phy
# Arguments: $ifaceName string containing name of interface
# Returns:
###############################################################
sub nftest_phy_reset {
	my $ifaceName = shift;
	my $portNum   = $ifaceName;

	my %ifaceNameMap = nftest_get_iface_name_map();
	die "Couldn't find interface $ifaceName.\n" unless defined $ifaceNameMap{$ifaceName};
	die "Interface has to be an nfcX interface\n" unless ( $ifaceName =~ /^nf2c/ );

	$portNum =~ s/nf2c//;
	$portNum = ( $portNum % 4 );

	my @addr = (
		main::MDIO_PHY_0_CONTROL_REG(), main::MDIO_PHY_1_CONTROL_REG(),
		main::MDIO_PHY_2_CONTROL_REG(), main::MDIO_PHY_3_CONTROL_REG()
	);

	nftest_regwrite( $ifaceName, $addr[$portNum], 0x8000 );
	system "usleep 10";
}

1;
