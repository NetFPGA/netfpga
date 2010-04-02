#####################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: SimplePacket.pm 4623 2008-10-28 20:33:35Z jnaous $
# author: Jad Naous jnaous@stanford.edu
# This provides functions for creating simple
# packets using a GenericByteArrayObject
#####################################


#######################################################
# Package to manipulate a flow header specification
#
package NFUtils::SimplePacket;
use strict;
use warnings;
use POSIX;

use NFUtils::GenericByteObject;

our @ISA = ('NFUtils::GenericByteObject');

use constant ETH_TYPE_VLAN => 0x8100;
use constant IP_PROTO_UDP => 0x11;
use constant IP_PROTO_TCP => 0x6;
use constant ETH_TYPE_IP => 0x0800;
use constant ETH_TYPE_ARP => 0x0806;
use constant IP_HDR_SIZE => 20;
use constant ETH_MIN_PKT_SIZE => 60;

use constant TRANSP_CHKSUM => 'transp_chksum';
use constant UDP_LEN => 'udp_len';
use constant TRANSP_DST => 'transp_dst';
use constant TRANSP_SRC => 'transp_src';
use constant IP_OPTS => 'ip_opts';
use constant IP_DST => 'ip_dst';
use constant IP_SRC => 'ip_src';
use constant IP_CHKSUM => 'ip_chksum';
use constant IP_PROTO => 'ip_proto';
use constant IP_TTL => 'ip_ttl';
use constant IP_FLAGS_FRAG_OFF => 'ip_flags_frag_off';
use constant IP_ID => 'ip_id';
use constant IP_LEN => 'ip_len';
use constant IP_TOS => 'ip_tos';
use constant IP_VER_HDR_LEN => 'ip_ver_hdr_len';
use constant VLAN_TAG => 'vlan_tag';
use constant VLAN_TYPE => 'vlan_type';
use constant ETH_TYPE => 'eth_type';
use constant ETH_SRC => 'eth_src';
use constant ETH_DST => 'eth_dst';
use constant PAYLOAD_GEN => 'payload_gen';
use constant PKT_LEN => 'pkt_len';
use constant PKT_TYPE => 'pkt_type';
use constant SRC_PORT => 'src_port';

use constant ARP_HW_TYPE => 'arp_hw_type';
use constant ARP_HW_TYPE_ETH => 0x0001;
use constant ARP_PROTO_TYPE => 'arp_proto_type';
use constant ARP_PROTO_TYPE_IP => 0x0800;
use constant ARP_HW_LEN => 'arp_hw_len';
use constant ARP_HW_LEN_ETH => 6;
use constant ARP_PROTO_LEN => 'arp_proto_len';
use constant ARP_PROTO_LEN_IP => 4;
use constant ARP_OPCODE => 'arp_opcode';
use constant ARP_OPCODE_REQUEST => 1;
use constant ARP_OPCODE_REPLY => 2;
use constant ARP_SRC_HW => 'arp_src_hw';
use constant ARP_SRC_IP => 'arp_src_ip';
use constant ARP_DST_HW => 'arp_dst_hw';
use constant ARP_DST_IP => 'arp_dst_ip';

use constant PKT_TYPE_UDP => 'udp';
use constant PKT_TYPE_IP  => 'ip';
use constant PKT_TYPE_ETH => 'eth';
use constant PKT_TYPE_ARP => 'arp';

use constant INVALID_VLAN_TAG => 0xffff;

# creates a new packet
# the following fields can be passed:
#   PKT_TYPE() => PKT_TYPE_UDP/PKT_TYPE_IP  - specifies what the pkt is. Defaults to Ethernet with no IP/UDP
#   PKT_LEN()  => integer                   - specifies the length of the packet including all headers. If IP_LEN
#                                               or UDP_LEN is specified, tries to guess. Otherwise, 60.
#   PAYLOAD_GEN() => sub{}                  - reference to a function that will be passed the index of a byte
#                                               of the payload. The function should return the byte to use at that
#                                               index in the payload. Defaults to random. For example, this can be set to:
#                                                  sub {return int(rand(256));} to set to a random byte
#                                                  sub {return shift;}          to return the index
#                                                  sub {return 0;}              for a payload of zeros
#   ETH_DST() => 'xx:xx:xx:xx:xx:xx'        - destination mac address. Defaults to random;
#   ETH_SRC() => 'xx:xx:xx:xx:xx:xx'        - source mac address. Defaults to random;
#   ETH_TYPE() => 16-bit integer            - Defaults to 0x0800 if IP or UDP. Otherwise, random number > 0x600.
#   VLAN_TYPE() => 16-bit integer           - Type to use for VLAN. This is usually set to 0x8100 if
#                                               this is a VLAN packet. Defaults to 0x8100 if VLAN_TAG
#                                               is defined. Otherwise it does not exist.
#   VLAN_TAG() => 16-bit integer            - Tag to use for VLAN. This contains the VLAN ID in the
#                                               least significant 12 bits. If specified, the VLAN type and tag
#                                               are inserted into the pkt. Defaults to 0 if VLAN_TYPE is defined.
#                                               Otherwise, it does not exist.
#   IP_VER_HDR_LEN() => ipver & hdr length  - Defaults to 0x45. This package does not handle IP
#                                               hdr sizes other than 5.
#   IP_TOS() => 8-bit integer               - IP type-of-service. Defaults to 0.
#   IP_LEN() => 16-bit integer              - IP total length. Defaults to (PKT_LEN - size of the ethernet header).
#   IP_ID() => 16-bit integer               - Fragment ID. Defaults to 0.
#   IP_FLAGS_FRAG_OFF() => 16-bit integer   - IP flags and fragment offest. Defaults to 0x4000.
#   IP_TTL() => 8-bit integer               - IP Time-to-live. Defaults to 64.
#   IP_PROTO() => 8-bit integer             - IP Protocol. If PKT_TYPE is PKT_TYPE_UDP, this defaults
#                                               to 17 (IP_PROTO_UDP), 0 otherwise.
#   IP_CHKSUM() => 16-bit integer           - IP Internet Checksum. Correctly set and updated whenever an IP field is changed.
#   IP_SRC() => 32-bit integer or "X.X.X.X" - IP source address. Defaults to random.
#   IP_DST() => 32-bit integer or "X.X.X.X" - IP destination address. Defaults to random.
#   IP_OPTS() => ref to byte array          - Optional IP options.
#   TRANSP_SRC() => 16-bit integer          - Source port for transport protocol. Defaults to random.
#   TRANSP_DST() => 16-bit integer          - Destination port for transport protocol. Defaults to random.
#   UDP_LEN() => 16-bit integer             - Length of UDP packet. Defaults to (PKT_LEN - eth hdr len - 20).
#   TRANSP_CHKSUM() => 16-bit integer       - Transport Internet Checksum. Defaults to 0.
#   SRC_PORT() => anything                  - Port from/to which the packet was rcvd/will be sent
#
# WARNINGS: - Unknown fields will be silently ignored.
#           - Only fields corresponding to the pkt type will be set in the pkt.
sub new {
  my ($class, %arg) = @_;

  my $eth_hdr_format =
    { ETH_DST() => {'pos' => 0,
                    'width' => 6,
                    'to_bytes' => \&ByteArrayUtils::mac_to_bytes,
                    'from_bytes' => \&ByteArrayUtils::bytes_to_mac},
      ETH_SRC() => {'pos' => 6,
                    'width' => 6,
                    'to_bytes' => \&ByteArrayUtils::mac_to_bytes,
                    'from_bytes' => \&ByteArrayUtils::bytes_to_mac},
      ETH_TYPE() => {'pos' => 12,
                     'width' => 2,
                     'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                     'from_bytes' => \&ByteArrayUtils::bytes_to_int}
    };

  my $vlan_eth_hdr_format =
    { ETH_DST() => {'pos' => 0,
                    'width' => 6,
                    'to_bytes' => \&ByteArrayUtils::mac_to_bytes,
                    'from_bytes' => \&ByteArrayUtils::bytes_to_mac},
      ETH_SRC() => {'pos' => 6,
                    'width' => 6,
                    'to_bytes' => \&ByteArrayUtils::mac_to_bytes,
                    'from_bytes' => \&ByteArrayUtils::bytes_to_mac},
      VLAN_TYPE() => {'pos' => 12,
                      'width' => 2,
                      'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                      'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      VLAN_TAG() => {'pos' => 14,
                     'width' => 2,
                     'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                     'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      ETH_TYPE() => {'pos' => 16,
                     'width' => 2,
                     'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                     'from_bytes' => \&ByteArrayUtils::bytes_to_int}
    };

  my $arp_hdr_format =
    { ARP_HW_TYPE() => {'pos' => 0,
                        'width' => 2,
                        'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                        'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      ARP_PROTO_TYPE() => {'pos' => 2,
                           'width' => 2,
                           'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                           'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      ARP_HW_LEN() => {'pos' => 4,
                       'width' => 1,
                       'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                       'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      ARP_PROTO_LEN() => {'pos' => 5,
                          'width' => 1,
                          'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                          'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      ARP_OPCODE() => {'pos' => 6,
                       'width' => 2,
                       'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                       'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      ARP_SRC_HW() => {'pos' => 8,
                       'width' => 6,
                       'to_bytes' => \&ByteArrayUtils::mac_to_bytes,
                       'from_bytes' => \&ByteArrayUtils::bytes_to_mac},
      ARP_SRC_IP() => {'pos' => 14,
                       'width' => 4,
                       'to_bytes' => \&ByteArrayUtils::ip_to_bytes,
                       'from_bytes' => \&ByteArrayUtils::bytes_to_ip},
      ARP_DST_HW() => {'pos' => 18,
                       'width' => 6,
                       'to_bytes' => \&ByteArrayUtils::mac_to_bytes,
                       'from_bytes' => \&ByteArrayUtils::bytes_to_mac},
      ARP_DST_IP() => {'pos' => 24,
                       'width' => 4,
                       'to_bytes' => \&ByteArrayUtils::ip_to_bytes,
                       'from_bytes' => \&ByteArrayUtils::bytes_to_ip}
    };

  my $ip_hdr_format =
    { IP_VER_HDR_LEN() => {'pos' => 0,
                           'width' => 1,
                           'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                           'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      IP_TOS() => {'pos' => 1,
                   'width' => 1,
                   'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                   'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      IP_LEN() => {'pos' => 2,
                   'width' => 2,
                   'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                   'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      IP_ID() => {'pos' => 4,
                  'width' => 2,
                  'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                  'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      IP_FLAGS_FRAG_OFF() => {'pos' => 6,
                              'width' => 2,
                              'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                              'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      IP_TTL() => {'pos' => 8,
                   'width' => 1,
                   'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                   'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      IP_PROTO() => {'pos' => 9,
                     'width' => 1,
                     'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                     'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      IP_CHKSUM() => {'pos' => 10,
                      'width' => 2,
                      'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                      'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      IP_SRC() => {'pos' => 12,
                   'width' => 4,
                   'to_bytes' => \&ByteArrayUtils::ip_to_bytes,
                   'from_bytes' => \&ByteArrayUtils::bytes_to_ip},
      IP_DST() => {'pos' => 16,
                   'width' => 4,
                   'to_bytes' => \&ByteArrayUtils::ip_to_bytes,
                   'from_bytes' => \&ByteArrayUtils::bytes_to_ip}
    };

  my $udp_hdr_format =
    { TRANSP_SRC() => {'pos' => 0,
                       'width' => 2,
                       'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                       'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      TRANSP_DST() => {'pos' => 2,
                       'width' => 2,
                       'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                       'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      UDP_LEN() => {'pos' => 4,
                    'width' => 2,
                    'to_bytes' => \&ByteArrayUtils::int_to_bytes,
                    'from_bytes' => \&ByteArrayUtils::bytes_to_int},
      TRANSP_CHKSUM() => {'pos' => 6,
                          'width' => 2,
                          'to_bytes' => \&ByteArrayUtils::ip_to_bytes,
                          'from_bytes' => \&ByteArrayUtils::bytes_to_ip}
    };

  my $eth_hdr;
  my $net_hdr;
  my $transp_hdr;
  my $payload;
  my @parts = ();

  $arg{ETH_SRC()} = join(":", map(sprintf("%02x", int(rand(256))), (1..6))) unless(defined $arg{ETH_SRC()});
  $arg{ETH_DST()} = join(":", map(sprintf("%02x", int(rand(256))), (1..6))) unless(defined $arg{ETH_DST()});
  $arg{ETH_TYPE()} = int(rand(0xf9ff)) + 0x600 unless(defined $arg{ETH_TYPE()} || defined $arg{PKT_TYPE()});

  # check for vlan
  if ((defined $arg{VLAN_TAG()} && $arg{VLAN_TAG()} != INVALID_VLAN_TAG)
      || defined $arg{VLAN_TYPE()}) {
    $eth_hdr = NFUtils::GenericByteObject->new('format' => $vlan_eth_hdr_format,
                                      'fields' => \%arg);
    $eth_hdr->set(VLAN_TYPE(), ETH_TYPE_VLAN);
  }
  else {
    $eth_hdr = NFUtils::GenericByteObject->new('format' => $eth_hdr_format,
                                      'fields' => \%arg);
  }
  push @parts, $eth_hdr;

  # work out size of the packet
  if (!defined $arg{PKT_LEN()}) {
    if(defined $arg{IP_LEN()}) {
      $arg{PKT_LEN()} = $arg{IP_LEN()} + $eth_hdr->size();
    }
    elsif (defined $arg{UDP_LEN()}) {
      $arg{PKT_LEN()} = $arg{UDP_LEN()} + $eth_hdr->size() + IP_HDR_SIZE;
    }
    else {
      $arg{PKT_LEN()} = ETH_MIN_PKT_SIZE;
    }
  }

  # set the defaults for the header fields depending on the packet type
  if (defined $arg{PKT_TYPE()}) {
    if ($arg{PKT_TYPE()} eq PKT_TYPE_UDP || $arg{PKT_TYPE()} eq PKT_TYPE_IP) {
      $eth_hdr->set(ETH_TYPE(), ETH_TYPE_IP) unless (defined $arg{ETH_TYPE()});

      # check for ip options
      if(defined $arg{IP_OPTS()}){
        my $opts_len = scalar @{$arg{IP_OPTS()}};
        #print "found ip options len: $opts_len \n";
        die "ERROR: SimplePacket->new: IP options length needs to be multiple of 4 bytes. Found $opts_len\n"
          unless ($opts_len % 4 == 0);
        die "ERROR: SimplePacket->new: IP options length needs to be at most 40 bytes. Found $opts_len\n"
          unless ($opts_len <= 40);

        # add IP options to the format
        $ip_hdr_format->{IP_OPTS()} = {'pos' => 20,
                                       'width' => $opts_len,
                                       'to_bytes' => \&ByteArrayUtils::bytesRef_to_bytes,
                                       'from_bytes' => \&ByteArrayUtils::bytes_to_bytesRef};

        # set the new header length
        $arg{IP_VER_HDR_LEN()} = 0x45 + ($opts_len/4) unless (defined $arg{IP_VER_HDR_LEN()});
      }

      # set other defaults
      $net_hdr = NFUtils::GenericByteObject->new('format' => $ip_hdr_format,
                                        'fields' => \%arg);
      $net_hdr->set(IP_VER_HDR_LEN(), 0x45) unless (defined $arg{IP_VER_HDR_LEN()});
      $net_hdr->set(IP_LEN(), $arg{PKT_LEN()} - $eth_hdr->size) unless (defined $arg{IP_LEN()});
      $net_hdr->set(IP_TTL(), 64) unless (defined $arg{IP_TTL()});
      $net_hdr->set(IP_PROTO(), IP_PROTO_UDP) unless (defined $arg{IP_PROTO()} || $arg{PKT_TYPE()} ne PKT_TYPE_UDP);
      $net_hdr->set(IP_SRC(), int(rand(2**32 - 1))+1) unless (defined $arg{IP_SRC()});
      $net_hdr->set(IP_DST(), int(rand(2**32 - 1))+1) unless (defined $arg{IP_DST()});
      $net_hdr->set(IP_FLAGS_FRAG_OFF(), 0x4000) unless (defined $arg{IP_FLAGS_FRAG_OFF()});
      $net_hdr->set(IP_CHKSUM(), calc_internet_checksum($net_hdr->bytes())) unless (defined $arg{IP_CHKSUM()});

      push @parts, $net_hdr;
    }

    if ($arg{PKT_TYPE()} eq PKT_TYPE_UDP) {
      $transp_hdr = NFUtils::GenericByteObject->new('format' => $udp_hdr_format,
                                           'fields' => \%arg);
      $transp_hdr->set(UDP_LEN(), $arg{PKT_LEN()} - $eth_hdr->size - $net_hdr->size) unless (defined $arg{UDP_LEN()});
      $transp_hdr->set(TRANSP_SRC(), int(rand(2**16-1))+1) unless (defined $arg{TRANSP_SRC()});
      $transp_hdr->set(TRANSP_DST(), int(rand(2**16-1))+1) unless (defined $arg{TRANSP_DST()});

      push @parts, $transp_hdr;
    }

    if ($arg{PKT_TYPE()} eq PKT_TYPE_ARP) {
      $eth_hdr->set(ETH_TYPE(), ETH_TYPE_ARP) unless (defined $arg{ETH_TYPE()});
      $net_hdr = NFUtils::GenericByteObject->new('format' => $arp_hdr_format,
                                                 'fields' => \%arg);
      $net_hdr->set(ARP_HW_TYPE, ARP_HW_TYPE_ETH) unless defined $arg{ARP_HW_TYPE()};
      $net_hdr->set(ARP_PROTO_TYPE, ARP_PROTO_TYPE_IP) unless defined $arg{ARP_PROTO_TYPE_IP()};
      $net_hdr->set(ARP_HW_LEN, ARP_HW_LEN_ETH) unless defined $arg{ARP_HW_LEN()};
      $net_hdr->set(ARP_PROTO_LEN, ARP_PROTO_LEN_IP) unless defined $arg{ARP_PROTO_LEN()};
      $net_hdr->set(ARP_OPCODE, ARP_OPCODE_REQUEST) unless defined $arg{ARP_OPCODE()};
      $net_hdr->set(ARP_SRC_HW, join(":", map(sprintf("%02x", int(rand(256))), (1..6)))) unless defined $arg{ARP_SRC_HW()};
      $net_hdr->set(ARP_SRC_IP,  int(rand(2**32 - 1))+1) unless defined $arg{ARP_SRC_IP()};
      $net_hdr->set(ARP_DST_HW, "00:00:00:00:00:00") unless defined $arg{ARP_DST_HW()};
      $net_hdr->set(ARP_DST_IP,  int(rand(2**32 - 1))+1) unless defined $arg{ARP_DST_IP()};
      push @parts, $net_hdr;
    }
  }

  # Create the packet object
  my $pkt = NFUtils::GenericByteObject->new(format => {});
  foreach (@parts) {
    $pkt->append($_);
  }
  #print "created pkt ";
  #print $pkt->hexString() . "\n";

  # create the payload
  my $payload_size = $arg{PKT_LEN()} - $pkt->size();
  #print "payload size: $payload_size \n";

  my $payload_format =
    { 'data' => {'pos' => 0,
                 'width' => $payload_size,
                 'to_bytes' => \&ByteArrayUtils::bytesRef_to_bytes,
                 'from_bytes' => \&ByteArrayUtils::bytes_to_bytesRef}
    };
  my @payload_bytes;
  if(defined $arg{PAYLOAD_GEN()}) {
    @payload_bytes = map ($arg{PAYLOAD_GEN()}->($_), (0..$payload_size-1));
  }
  else {
    @payload_bytes = map (int(rand(256)), (1..$payload_size));
  }
  $payload = NFUtils::GenericByteObject->new(format => $payload_format,
                                         fields => {'data' => \@payload_bytes});
  $pkt->append($payload);

  # set the source port
  $pkt->{SRC_PORT()} = $arg{SRC_PORT()} if defined $arg{SRC_PORT()};

  # set the pkt length
  $pkt->{PKT_LEN()} = $arg{PKT_LEN()};

  bless $pkt, $class;
}

# updates the ip checksum in the current packet
sub update_ip_chksum {
  my $self = shift;

  # make sure this is an IP packet
  die "Error: Packet is not IP. Can't update chksum.\n" unless defined $self->{format}->{IP_VER_HDR_LEN()};

  $self->set(IP_CHKSUM, 0);
  my $bytes = $self->bytes();

  my $ip_hdr_start = $self->{format}->{IP_VER_HDR_LEN()}->{pos};
  my @ip_bytes = $bytes->[$ip_hdr_start..$ip_hdr_start+20];

  $self->set(IP_CHKSUM, calc_internet_checksum(@ip_bytes));
}

# overrides the parent's set method so that
# it updates the ip checksum if an IP field is modified
sub set {
  my ($self, $field, $val) = @_;

  die "SimplePacket: need to call set method with (field, val) as parameters.\n"
    unless defined $self && defined $field && defined $val;

  die "Ethertype has to be > 0x0600. Found 0d$val.\n" if($field eq ETH_TYPE && $val < 0x600);

  if($field eq SRC_PORT) {
    $self->{SRC_PORT()} = $val;
    return;
  }

#  print "SimplePkt: Setting $field to $val.\n";

  $self->SUPER::set($field, $val);

  if ($field =~ m/^ip_/ && $field ne IP_CHKSUM) {
    $self->update_ip_chksum();
  }
}

# overrides the parent's get method so so we can retrieve
# src_port and pkt_len
sub get {
  my ($self, $field) = @_;

  return $self->{SRC_PORT()} if($field eq SRC_PORT);
  return $self->size() if($field eq PKT_LEN);

  return $self->SUPER::get($field);
}

# utility method to update the ip checksum
sub calc_internet_checksum {
  my @bytes = @_;

  my $num_bytes = scalar @bytes;
  my $checksum = 0;
  my $word;

  for my $i (0..($num_bytes/2 - 1)) {
    $word = ( @bytes[2*$i] << 8 ) | @bytes[2*$i+1] ;
    $checksum += $word;
    if ($checksum & 0xffff0000) {
      $checksum = ($checksum & 0xffff) + ($checksum >> 16);
    }
  }
  return $checksum ^ 0xffff;
}

1;
