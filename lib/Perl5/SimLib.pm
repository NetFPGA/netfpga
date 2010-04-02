#####################################
#
# $Id: SimLib.pm 5432 2009-05-01 22:56:02Z g9coving $
#
# This provides functions for use in simulations.
#
# NOTE: requires $batch and $delay to be defined in the main script.
#
# e.g.
#     use SimLib;
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

package SimLib ;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw(
              &enable_interrupts
              &prepare_DMA
              &resetDevice

              &cpu_rxfifo_rd_pkt

              &PCI_send_pkt
              &PCI_create_and_send_pkt

              &make_ethernet_pkt
              &make_IP_pkt
						  &make_IP_IP_pkt
              &make_RCP_pkt

            );

use NF::Base;
use NF::PacketGen ('nf_PCI_read32' , 'nf_PCI_write32', 'nf_dma_data_in',
        'nf_expected_packet', 'nf_expected_dma_data', 'nf_get_sim_reg_access');

use Carp;
use strict;

#
# Sets the package to main to ensure all of the functions
# are in the main namespace. Returns to NF21RouterLib before continuing.
package main;

package SimLib;

use constant CPCI_Control_reg =>        0x0000008;
use constant CPCI_Interrupt_Mask_reg => 0x0000040;

################################################################
#
# Router setup stuff
#
################################################################
sub enable_interrupts {
  my $delay;

  if(@_) {
    $delay = shift;
  }
  else {
    $delay = $main::delay;
  }

  # Enable interrupts
  nf_PCI_write32($delay, 0, CPCI_Interrupt_Mask_reg, 0x00000000);
}

sub prepare_DMA {
  my $delay;

  if(@_) {
    $delay = shift;
  }
  else {
    $delay = $main::delay;
  }

  # Set the board to do byte-swapping on DMAs
  nf_PCI_write32($delay, 0, CPCI_Control_reg, 0x00000000);
}

sub resetDevice {
  my $delay;

  if(@_) {
    $delay = shift;
  }
  else {
    $delay = $main::delay;
  }
  nf_PCI_write32($delay, 0, CPCI_Control_reg, 0x100);
}

##############################################################################################
#
# CPU RxFIFO
#
##############################################################################################

# Get the CPU to read the specified packet from the CPU RxFIFO.
#
sub cpu_rxfifo_rd_pkt {  # src port, length, $pkt_string, $delay

  my $src_port = shift;
  die "cpu_rxfifo_rd_pkt(): src port must be in 1-4 not $src_port" unless (($src_port >0) &&($src_port<5));
  my $length = shift;
  die "cpu_rxfifo_rd_pkt(): length must be in 60-10000 not $length" unless (($length >=60) &&($length<=10000));
  my $bad = shift;
  my $pkt = shift;
  my $delay;
  if(@_) {
    $delay = shift;
  }
  else {
    $delay = $main::delay;
  }

  nf_expected_dma_data($src_port, $length, $pkt);

  printf("done pkt.\n");
}


################################################################
#
# Send a packet via the PCI bus (CPU TXFIFO)
#
################################################################

# Send a packet via the CPU TxFIFO. Create the packet and then write the
# length field (which causes it to be sent).

sub PCI_send_pkt {
  my $port = shift;
  my $pkt = shift;   # string of hex

  die "Bad port $port : must be in 1..4" if (($port < 1) or ($port > 4));

  my @data = split ' ',$pkt;
  my $length = @data+0;

  nf_dma_data_in($length, $main::delay, $port, $pkt);
}

# Create and send a packet.
sub PCI_create_and_send_pkt {
  my $port = shift;
  my $length = shift;

  die "Bad port $port : must be in 1..4" if (($port < 1) or ($port > 4));
  die "Bad length $length : must be in 60..10000" if (($length < 60) or ($length > 10000));


  my $pkt = NF::PDU->new($length);
  my @tmp = (1..$length);
  for (@tmp) { $_ %= 256 }
  $pkt->set_bytes(@tmp);

  PCI_send_pkt($port, $pkt->bytes());

  nf_expected_packet($port,  $length,  $pkt->bytes());

}

################################################################
#
# IP packet stuff
#
################################################################

# Build an IP packet with the given arguments
# Data is just sequential numbers.

sub make_RCP_pkt { # len, DA, SA, TTL, DST_IP, SRC_IP, @RCP

  my ($len, $DA, $SA, $TTL, $DST_IP, $SRC_IP, @RCP) = @_;
  my ($fwd, $rev, $rtt, $proto) = @RCP;

  my $RCP_hdr = NF::RCP_hdr->new(      fwd => $fwd,
                                        rev => $rev,
                                        rtt => $rtt,
                                        proto => $proto
                                );
  my $MAC_hdr = NF::Ethernet_hdr->new(DA => $DA,
                                       SA => $SA,
                                       Ethertype => 0x800
                                      );
  my $IP_hdr = NF::IP_hdr->new(ttl => $TTL,
                                src_ip => $SRC_IP,
                                dst_ip => $DST_IP,
                                proto => 0xfe
                               );
  $IP_hdr->checksum(0);  # make sure its zero before we calculate it.
  $IP_hdr->checksum($IP_hdr->calc_checksum);

  # create packet filling.... (IP PDU)
  my $PDU = NF::PDU->new($len - $MAC_hdr->length_in_bytes() - $IP_hdr->length_in_bytes() - $RCP_hdr->length_in_bytes());
  my $start_val = $MAC_hdr->length_in_bytes() + $IP_hdr->length_in_bytes() + $RCP_hdr->length_in_bytes()+1;
  my @data = ($start_val..$len);
  for (@data) {$_ %= 100}
  $PDU->set_bytes(@data);

  # Return complete packet data
  $MAC_hdr->bytes().$IP_hdr->bytes().$RCP_hdr->bytes().$PDU->bytes();
}

sub make_IP_pkt { # len, DA, SA, TTL, DST_IP, SRC_IP

  my ($len, $DA, $SA, $TTL, $DST_IP, $SRC_IP) = @_;

  my $MAC_hdr = NF::Ethernet_hdr->new(DA => $DA,
                                       SA => $SA,
                                       Ethertype => 0x800
                                      );
  my $IP_hdr = NF::IP_hdr->new(ttl => $TTL,
                                src_ip => $SRC_IP,
                                dst_ip => $DST_IP,
				dgram_len => $len - $MAC_hdr->length_in_bytes(),
                               );
  $IP_hdr->checksum(0);  # make sure its zero before we calculate it.
  $IP_hdr->checksum($IP_hdr->calc_checksum);

  # create packet filling.... (IP PDU)
  my $PDU = NF::PDU->new($len - $MAC_hdr->length_in_bytes() - $IP_hdr->length_in_bytes() );
  my $start_val = $MAC_hdr->length_in_bytes() + $IP_hdr->length_in_bytes()+1;
  my @data = ($start_val..$len);
  for (@data) {$_ %= 100}
  $PDU->set_bytes(@data);

  # Return complete packet data
  $MAC_hdr->bytes().$IP_hdr->bytes().$PDU->bytes();
}


sub make_IP_IP_pkt { # len, DA, SA, TTL, DST_IP_TUN, SRC_IP_TUN, DST_IP, SRC_IP

  my ($len, $DA, $SA, $TTL, $DST_IP_TUN, $SRC_IP_TUN, $DST_IP, $SRC_IP) = @_;

  my $pad_length = 4;

  my $MAC_hdr = NF::Ethernet_hdr->new(DA => $DA,
                                       SA => $SA,
                                       Ethertype => 0x800
                                      );

  my $IP_hdr_tun = NF::IP_hdr->new(ttl => $TTL,
				    src_ip => $SRC_IP_TUN,
				    dst_ip => $DST_IP_TUN,
				    proto  => 0xf4,  #IP_IP encapsulation protocol
                                    dgram_len => $len- 14,
				   );

  $IP_hdr_tun->checksum(0);  # make sure its zero before we calculate it.
  $IP_hdr_tun->checksum($IP_hdr_tun->calc_checksum);

  my $IP_hdr = NF::IP_hdr->new(ttl => $TTL,
                                src_ip => $SRC_IP,
                                dst_ip => $DST_IP
                               );
  $IP_hdr->checksum(0);  # make sure its zero before we calculate it.
  $IP_hdr->checksum($IP_hdr->calc_checksum);


  # create packet filling.... (IP PDU)
  my $PDU = NF::PDU->new($len - $MAC_hdr->length_in_bytes() - $IP_hdr->length_in_bytes() - $IP_hdr_tun->length_in_bytes());
  my $start_val = $MAC_hdr->length_in_bytes() + $IP_hdr->length_in_bytes()+1;
  my @data = ($start_val..($len-$pad_length-$IP_hdr_tun->length_in_bytes));
  for (@data) {$_ %= 100}
  $PDU->set_bytes(@data);

  # Return complete packet data
  $MAC_hdr->bytes().$IP_hdr_tun->bytes()."ff ff ff ff ".$IP_hdr->bytes().$PDU->bytes();
}

sub make_ethernet_pkt { # len, DA, SA, type

  my ($len, $DA, $SA, $type) = @_;

  my $MAC_hdr = NF::Ethernet_hdr->new(DA => $DA,
                                       SA => $SA,
                                       Ethertype => $type
                                      );

  my $PDU = NF::PDU->new($len - $MAC_hdr->length_in_bytes());
  my $start_val = $MAC_hdr->length_in_bytes()+1;
  my @data = ($start_val..$len);
  for (@data) {$_ %= 100}
  $PDU->set_bytes(@data);

  # Return complete packet data
  $MAC_hdr->bytes().$PDU->bytes();
}

1;

