#!/usr/bin/perl -w

use NF::Base;
use NF::RegAccess;
use Test::RegressTest;

# check vars are set.
check_NF2_vars_set();

sub INT_Handler {
	my $signame = shift;
	nf_regwrite( 'nf2c0', MDIO_0_CONTROL_REG(), 0x8000 );
	nf_regwrite( 'nf2c0', MDIO_1_CONTROL_REG(), 0x8000 );
	nf_regwrite( 'nf2c0', MDIO_2_CONTROL_REG(), 0x8000 );
	nf_regwrite( 'nf2c0', MDIO_3_CONTROL_REG(), 0x8000 );

	print "\nResetting interfaces...\n";
	sleep 5;
	print "\nExited with SIG$signame\n";
	exit(1);
}

push @ARGV, "--root=$ENV{'NF_ROOT'}";

run_regress_test( \&INT_Handler, @ARGV );
