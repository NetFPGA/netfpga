#####################################
#
# $Id: RouterLib.pm 6036 2010-04-01 00:30:59Z grg $
#
# This provides functions for use in tests of the reference_router system.
#
# NOTE: Many of these functions are hardware specific (e.g. LPM  and ARP table
# configuration), so beware if you use them in another system!
#
# NOTE: requires $batch and $delay to be defined in the main script.
#
# e.g.
#     use RouterLib;
#     $delay = 0;
#     $batch = 0;
#
#     # use strict AFTER the $delay, $batch are declared
#     use strict;
#     # Must add this so that global vars are visible after the 'use strict'
#     use vars qw($delay $batch);
#
# To use this library in your Perl make_pkts.pl, just add the path to this
# library to your PERL5LIB environment variable, and then "use" it, as shown
# above.
#
#####################################

package RouterLib ;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw(
              &add_LPM_table_entry
              &check_LPM_table_entry
              &invalidate_LPM_table_entry
              &get_LPM_table_entry
              &add_LPM_table_entry_generic
              &check_LPM_table_entry_generic
              &invalidate_LPM_table_entry_generic
              &get_LPM_table_entry_generic

              &add_dst_ip_filter_entry
              &invalidate_dst_ip_filter_entry
              &get_dst_ip_filter_entry
              &add_dst_ip_filter_entry_generic
              &invalidate_dst_ip_filter_entry_generic
              &get_dst_ip_filter_entry_generic

              &add_ARP_table_entry
              &invalidate_ARP_table_entry
              &get_ARP_table_entry
              &check_ARP_table_entry
              &add_ARP_table_entry_generic
              &invalidate_ARP_table_entry_generic
              &check_ARP_table_entry_generic
              &get_ARP_table_entry_generic

              &set_router_MAC
              &set_router_MAC_generic
              &get_router_MAC
              &get_router_MAC_generic

              &dotted

            );

use NF::PacketGen ('nf_PCI_read32' , 'nf_PCI_write32', 'nf_dma_data_in',
        'nf_expected_packet', 'nf_expected_dma_data', 'nf_get_sim_reg_access');

use Carp;
use strict;

# Include the reg_defines.ph header file.
#
# Sets the package to main to ensure all of the functions
# are in the main namespace. Returns to RouterLib before continuing.
package main;
package RouterLib;

use constant CPCI_Control_reg =>        0x0000008;
use constant CPCI_Interrupt_Mask_reg => 0x0000040;

################################################################
#
# Setting and getting the router MAC addresses
#
################################################################
sub set_router_MAC { # port, MAC
  my @sim_reg_access = nf_get_sim_reg_access();
  set_router_MAC_generic(@_, @sim_reg_access);
}

sub get_router_MAC { # port, MAC
  my @sim_reg_access = nf_get_sim_reg_access();
  return get_router_MAC_generic(@_, @sim_reg_access);
}


################################################################
#
# LPM table stuff
#
################################################################

sub add_LPM_table_entry {  # index, IP_subnet, MASK, NEXT_hop_IP, port
  my @sim_reg_access = nf_get_sim_reg_access();
  add_LPM_table_entry_generic(@_, @sim_reg_access);
}

sub check_LPM_table_entry {  # index, IP_subnet, MASK, NEXT_hop_IP, port
  my @sim_reg_access = nf_get_sim_reg_access();
  check_LPM_table_entry_generic(@_, @sim_reg_access);
}

sub invalidate_LPM_table_entry { #table index to invalidate
  my @sim_reg_access = nf_get_sim_reg_access();
  invalidate_LPM_table_entry_generic(@_, @sim_reg_access);
}

sub get_LPM_table_entry { #table index to get
  my @sim_reg_access = nf_get_sim_reg_access();
  get_LPM_table_entry_generic(@_, @sim_reg_access);
}

################################################################
#
# Destination IP filter table stuff
#
################################################################

sub add_dst_ip_filter_entry {  # index, dest ip
  my @sim_reg_access = nf_get_sim_reg_access();
  add_dst_ip_filter_entry_generic(@_, @sim_reg_access);
}


sub invalidate_dst_ip_filter_entry { #table index to invalidate
  my @sim_reg_access = nf_get_sim_reg_access();
  invalidate_dst_ip_filter_entry_generic(@_, @sim_reg_access);
}

sub get_dst_ip_filter_entry { #index to retrieve
  my @sim_reg_access = nf_get_sim_reg_access();
  return get_dst_ip_filter_entry_generic(@_, @sim_reg_access);
}

################################################################
#
# ARP stuff
#
################################################################
sub add_ARP_table_entry {  # index, IP, MAC,
  my @sim_reg_access = nf_get_sim_reg_access();
  add_ARP_table_entry_generic(@_, @sim_reg_access);
}

sub invalidate_ARP_table_entry { #table index to invalidate
  my @sim_reg_access = nf_get_sim_reg_access();
  invalidate_ARP_table_entry_generic(@_, @sim_reg_access);
}

sub check_ARP_table_entry {  # index, IP, MAC,
  my @sim_reg_access = nf_get_sim_reg_access();
  check_ARP_table_entry_generic(@_, @sim_reg_access);
}

sub get_ARP_table_entry {  # index
  my @sim_reg_access = nf_get_sim_reg_access();
  get_ARP_table_entry_generic(@_, @sim_reg_access);
}

################################################################
#
# Misc routines
#
################################################################

sub dotted { # convert dotted decimal to 32 bit integer
  my $dot = shift;
  if ($dot =~ m/^\s*(\d+)\.(\d+)\.(\d+)\.(\d+)\s*$/) {
    my $newip = $1<<24 | $2<<16 | $3<<8 | $4;
    return $newip
  }
  else {
    die "Bad format - expected dotted decimal: $dot"
  }
}

################################################################
#
# Setting and getting the router MAC addresses - Generic function
#
################################################################
sub set_router_MAC_generic { # port, MAC, delay
  my $port = shift;
  my $mac = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "bad port number" if (($port < 1) or ($port > 4));

  my @MAC = NF::PDU::get_MAC_address($mac);

  my $mac_hi = $MAC[0]<<8 | $MAC[1];
  my $mac_lo = $MAC[2]<<24 | $MAC[3]<<16 | $MAC[4]<<8 | $MAC[5];

  $port -= 1;

  $reg_write->( @aux, (main::ROUTER_OP_LUT_MAC_0_HI_REG() + ($port*8)), $mac_hi);
  $reg_write->( @aux, (main::ROUTER_OP_LUT_MAC_0_LO_REG() + ($port*8)), $mac_lo);
}

sub get_router_MAC_generic { # port, delay
  my $port = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "bad port number" if (($port < 1) or ($port > 4));

  $port -= 1;

  my $mac_hi = $reg_read->( @aux, (main::ROUTER_OP_LUT_MAC_0_HI_REG() + ($port*8)));
  my $mac_lo = $reg_read->( @aux, (main::ROUTER_OP_LUT_MAC_0_LO_REG() + ($port*8)));

  my $mac_tmp = sprintf("%04x%08x", $mac_hi, $mac_lo);
  $mac_tmp =~ /^(..)(..)(..)(..)(..)(..)$/;

  return "$1:$2:$3:$4:$5:$6";
}


################################################################
#
# LPM table stuff
#
################################################################

sub add_LPM_table_entry_generic {  # index, IP_subnet, MASK, NEXT_hop_IP, port
  my $index = shift;
  my $IP = shift;
  my $mask = shift;
  my $next_IP = shift;
  my $next_port = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "Bad data" if (($index < 0) or ($index > main::ROUTER_OP_LUT_ROUTE_TABLE_DEPTH()-1) or ($next_port < 1) or ($next_port > 255));

  if ($IP =~ m/(\d+)\./) { $IP = dotted($IP) }
  if ($mask =~ m/(\d+)\./) { $mask = dotted($mask) }
  if ($next_IP =~ m/(\d+)\./) { $next_IP = dotted($next_IP) }

  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG(), $IP);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG(), $mask);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG(), $next_IP);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG(), $next_port);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR_REG(), $index);
}

sub check_LPM_table_entry_generic {  # index, IP_subnet, MASK, NEXT_hop_IP, port
  my $index = shift;
  my $IP = shift;
  my $mask = shift;
  my $next_IP = shift;
  my $next_port = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "Bad data" if (($index < 0) or ($index > main::ROUTER_OP_LUT_ROUTE_TABLE_DEPTH()-1) or ($next_port < 0) or ($next_port > 255));

  if ($IP =~ m/(\d+)\./) { $IP = dotted($IP) }
  if ($mask =~ m/(\d+)\./) { $mask = dotted($mask) }
  if ($next_IP =~ m/(\d+)\./) { $next_IP = dotted($next_IP) }

  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG(), $index);
  $reg_read_expect->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG(), $IP);
  $reg_read_expect->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG(), $mask);
  $reg_read_expect->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG(), $next_IP);
  $reg_read_expect->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG(), $next_port);
}


sub invalidate_LPM_table_entry_generic { #table index to invalidate
  my $index = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "Bad data" if (($index < 0) or ($index > main::ROUTER_OP_LUT_ROUTE_TABLE_DEPTH()-1));
  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG(), 0);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG(), 0xffffffff);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG(), 0);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG(), 0);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR_REG(), $index);
}

sub get_LPM_table_entry_generic { #table index to invalidate
  my $index = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "get_LPM_table_entry_generic: Bad data" if (($index < 0) or ($index > main::ROUTER_OP_LUT_ROUTE_TABLE_DEPTH()-1));

  $reg_write->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG(), $index);
  my $ip = $reg_read->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG());
  my $mask = $reg_read->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG());
  my $next_hop = $reg_read->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG());
  my $output_port = $reg_read->( @aux, main::ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG());

  my $ip_str = Socket::inet_ntoa(pack('N', $ip));
  my $mask_str = Socket::inet_ntoa(pack('N', $mask));
  my $next_hop_str = Socket::inet_ntoa(pack('N', $next_hop));

  return "$ip_str-$mask_str-$next_hop_str-" . sprintf("0x%02x", $output_port);
}

################################################################
#
# Destination IP filter table stuff
#
################################################################

sub add_dst_ip_filter_entry_generic {  # index, dest ip
  my $index = shift;
  my $IP = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "Bad data" if (($index < 0) or ($index > main::ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH()-1));

  if ($IP =~ m/(\d+)\./) { $IP = dotted($IP) }

  $reg_write->( @aux, main::ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG(), $IP);
  $reg_write->( @aux, main::ROUTER_OP_LUT_DST_IP_FILTER_TABLE_WR_ADDR_REG(), $index);
}


sub invalidate_dst_ip_filter_entry_generic { #table index to invalidate
  my $index = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "Bad data" if (($index < 0) or ($index > main::ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH()-1));
  $reg_write->( @aux, main::ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG(), 0);
  $reg_write->( @aux, main::ROUTER_OP_LUT_DST_IP_FILTER_TABLE_WR_ADDR_REG(), $index);
}

sub get_dst_ip_filter_entry_generic {  # index
  my $index = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "Bad data" if (($index < 0) or ($index > main::ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH()-1));

  $reg_write->( @aux, main::ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR_REG(), $index);
  return $reg_read->( @aux, main::ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG());
}


################################################################
#
# ARP stuff
#
################################################################
sub add_ARP_table_entry_generic {  # index, IP, MAC,
  my $index = shift;
  my $IP = shift;
  my $mac = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;


  die "add_ARP_table_entry: Bad data" if (($index < 0) or ($index > main::ROUTER_OP_LUT_ARP_TABLE_DEPTH()-1));

  if ($IP =~ m/(\d+)\./) { $IP = dotted($IP) }

  my @MAC = NF::PDU::get_MAC_address($mac);

  my $mac_hi = $MAC[0]<<8 | $MAC[1];
  my $mac_lo = $MAC[2]<<24 | $MAC[3]<<16 | $MAC[4]<<8 | $MAC[5];

  $reg_write->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG(), $IP);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG(), $mac_hi);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG(), $mac_lo);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_WR_ADDR_REG(), $index);
}

sub invalidate_ARP_table_entry_generic { #table index to invalidate
  my $index = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "Bad data" if (($index < 0) or ($index > main::ROUTER_OP_LUT_ARP_TABLE_DEPTH()-1));
  $reg_write->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG(), 0);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG(), 0);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG(), 0);
  $reg_write->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_WR_ADDR_REG(), $index);
}

sub check_ARP_table_entry_generic {  # index, IP, MAC,
  my $index = shift;
  my $IP = shift;
  my $mac = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "check_ARP_table_entry: Bad data" if (($index < 0) or ($index > main::ROUTER_OP_LUT_ARP_TABLE_DEPTH()-1));

  if ($IP =~ m/(\d+)\./) { $IP = dotted($IP) }

  my @MAC = NF::PDU::get_MAC_address($mac);

  my $mac_hi = $MAC[0]<<8 | $MAC[1];
  my $mac_lo = $MAC[2]<<24 | $MAC[3]<<16 | $MAC[4]<<8 | $MAC[5];

  $reg_write->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_RD_ADDR_REG(), $index);
  $reg_read_expect->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG(), $IP);
  $reg_read_expect->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG(), $mac_hi);
  $reg_read_expect->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG(), $mac_lo);
}

sub get_ARP_table_entry_generic {  # index
  my $index = shift;
  my $reg_write = shift;
  my $reg_read  = shift;
  my $reg_read_expect  = shift;
  my @aux = @_;

  die "get_ARP_table_entry: Bad data" if (($index < 0) or ($index > main::ROUTER_OP_LUT_ARP_TABLE_DEPTH()-1));

  # Read the ARP table entry
  $reg_write->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_RD_ADDR_REG(), $index);
  my $IP = $reg_read->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG());
  my $mac_hi = $reg_read->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG());
  my $mac_lo = $reg_read->( @aux, main::ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG());

  my $IPstr = Socket::inet_ntoa(pack('N', $IP));
  my $mac_tmp = sprintf("%04x%08x", $mac_hi, $mac_lo);
  $mac_tmp =~ /^(..)(..)(..)(..)(..)(..)$/;
  my $mac_str = "$1:$2:$3:$4:$5:$6";

  return "$IPstr-$mac_str";
}

1;

