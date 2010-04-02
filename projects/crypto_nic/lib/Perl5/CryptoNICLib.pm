#####################################
#
# $Id: NF21RouterLib.pm 4352 2008-08-01 18:39:57Z sbolouki $
#
# Basic functions for the Crypto NIC
#
# To use this library in your Perl make_pkts.pl, just add the path to this
# library to your PERL5LIB environment variable, and then "use" it.
#
#####################################

package CryptoNICLib ;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw(
              &encrypt_pkt
              &decrypt_pkt
            );

use NF::PacketGen ('nf_PCI_read32' , 'nf_PCI_write32', 'nf_dma_data_in',
        'nf_expected_packet', 'nf_expected_dma_data', 'nf_get_sim_reg_access');

use Carp;
use strict;

# Include the reg_defines.ph header file.
#
# Sets the package to main to ensure all of the functions
# are in the main namespace. Returns to CryptoNICLib before continuing.
package main;
use reg_defines_crypto_nic;
package CryptoNICLib;


# Where should we start encrypting/decrypting?
my $START_POS = 14 + 20;

##############################################################################################
#
# Encrypt packet
#
##############################################################################################

# Encrypt a packet
#
# Params:
#  key
#  packet
sub encrypt_pkt {
  my $key = shift;
  my $pkt = shift;

  # Break up the key
  my @key;
  for (my $i = 0; $i < 4; $i++) {
    $key[$i] = ($key >> (24 - $i * 8)) & 0xff;
  }

  # Identify the packet type and break up the packet as appropriate
  if (ref($pkt) eq 'NF::IP_pkt') {
    # Extract the payload
    my @payload = map(hex, split(/ /, ${$pkt->{'payload'}}->bytes));

    # Encrypt the payload
    for (my $i = 0; $i < scalar(@payload); $i++) {
	    $payload[$i] ^= $key[($i + $START_POS) % 4];
    }

    # Update the payload
    ${$pkt->{'payload'}}->set_bytes(@payload);

    return $pkt;
  }
  else {
    chomp $pkt;
    my @pkt = map(hex, split(/ /, $pkt));

    # Encrypt the payload
    for (my $i = $START_POS; $i < scalar(@pkt); $i++) {
      $pkt[$i] ^= $key[$i % 4];
    }

    # Return the packet
    my @tmp = map {sprintf "%02x", $_} @pkt;
    return join(' ',@tmp).' ';
  }
}


##############################################################################################
#
# Decrypt packet
#
##############################################################################################

# Decrypt a packet
#
# Encryption and decryption are symmetrical so just call encrypt
#
# Params:
#  key
#  packet
sub decrypt_pkt {
  return encrypt_pkt(@_);
}

1;


