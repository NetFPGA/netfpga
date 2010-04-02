###############################################################################
## $Id$
##
## Project: CPCI
## Description: This package provides functions for use in CPCI design
##
###############################################################################

package CPCI_Lib;

################################################################
# GO and parse the verilog define file to find the address of
# CPCI registers and other constants.
#
# This lets the perl script use the Verilog symbol names instead of duplicating
# a load of constants.
#
# e.g.
#  `define CPCI_Board_ID_reg  12'h004
# would map CPCI_Board_ID_reg to address 0x004

sub get_register_addresses {

  my $filename = $ENV{'NF_ROOT'}.'/lib/verilog/common/src/global_defines.v';

  my %reg = ();

  open F,"<$filename" or
    die "ERROR: register_addresses(): Unable to read file $filename to extract reg addresses";

  while (<F>) {

    if (/`define\s+CPCI_(\S+)_reg\s+\d+\'h\s*([0-9a-fA-F]+)/) {
      my $addr = hex($2);
      # printf "map CPCI_$1_reg -> 0x%06x\n",$addr;
      $reg{'CPCI_'.$1.'_reg'} = $addr;
      next
    }
  }

  close F;

  return %reg;

}

1;

