#######################################################
# vim:set shiftwidth=3 softtabstop=3 expandtab:
#
# The NF::Pcap Class
# $Id: Pcap.pm 2802 2007-11-06 19:04:43Z grg $
#
#######################################################
package NF::Pcap;
use strict;
use warnings;
use threads;                # pull in threading routines
use threads::shared;        # and variable sharing routines
use Socket;
use IO::Select;

# state enumeration
use constant ETH_P_ALL     => 3;
use constant PF_PACKET     => 17;
use constant SIOCGIFINDEX  => 0x8933;
use constant SIOCGIFFLAGS  => 0x8913;
use constant SIOCSIFFLAGS  => 0x8914;
use constant IFF_PROMISC   => 0x100;

# Variable to terminate all threads
my $finished : shared = 0;

# Run a NF::Pcap thread, taking a device as an argument
# Creates a new NF::Pcap object
sub run {
   my ($dev, $callback, @aux) = @_;

   # Keep track of the number of stored packets
   my $pktCnt = 0;

   #print "Capturing on port $dev\n";

   # Bind to the device specified when the object was created
   my $sock = &bindToDevice($dev);

   # Create an IO::Select object so that we can wait
   # with timeout on the socket
   my $read_set = IO::Select->new();
   $read_set->add($sock);

   # Read packets from the interface
   while (!$finished) {
      # Wait for up to a second for a packet to arrive
      my ($rh_set) = IO::Select->select($read_set, undef, undef, 1);

      # Check to see if there is any data in the buffer
      if (defined($rh_set)) {

         # Grab the packet and shove it in the pkt hash
         my $packet;
         recv($sock, $packet, 2048, 0);

         # Call the callback
         &$callback($dev, $packet, @aux);

         # Keep track of how many packets have been captured
         $pktCnt++;
      }
   }

   &endPromisc($dev, $sock);
   close($sock);

   return $pktCnt;
}


#####################################################################
# Name: nf2_start_capture
# Starts capturing on a given interface
#####################################################################
sub start {
   my ($dev, $callback, @aux) = @_;

   return threads->new(\&NF::Pcap::run,
                       $dev, $callback, @aux);
}

#####################################################################
# Name: nf2_finish_capture
# Instruct all capture threads to terminate
#####################################################################
sub finish {
   $finished = 1;
}


#####################################################################
# Name: bindToDevice
# Bind a socket to a particular ethernet device
# Stores the socket in the self variable
#####################################################################
sub bindToDevice {
   my ($dev) = @_;
   my $s;

   # Attempt to open the socket
   socket($s, PF_PACKET, SOCK_RAW, ETH_P_ALL)
      or die "Error opening socket. Errno: $!";

   # Get the index of the given port
   my $ifr = pack('Z[16]x[16]', $dev);
   ioctl($s, SIOCGIFINDEX, $ifr)
      or die "Error calling ioctl on $dev. Errno: $!";
   my $index = unpack('x[16]I', $ifr);

   # Create the address object
   my $sockaddr = pack("SnIx[12]", PF_PACKET, ETH_P_ALL, $index);

   # Bind to the interface
   bind($s, $sockaddr) or
      die "Error binding to socket. Errno: $!";

   # Attempt to enable promiscuous mode
   $ifr = pack('Z[16]x[16]', $dev);
   ioctl($s, SIOCGIFFLAGS, $ifr)
      or die "Error calling ioctl on $dev. Errno: $!";
   my $flags = unpack('x[16]S', $ifr);
   $flags |= IFF_PROMISC;
   $ifr = pack('Z[16]Sx[14]', $dev, $flags);
   ioctl($s, SIOCSIFFLAGS, $ifr)
      or die "Error calling ioctl on $dev. Errno: $!";

   # Return the socket
   return $s;
}


#####################################################################
# Name: endPromisc
# Finish promiscuous mode
#####################################################################
sub endPromisc {
   my ($dev, $s) = @_;

   # Attempt to disable promiscuous mode
   my $ifr = pack('Z[16]x[16]', $dev);
   ioctl($s, SIOCGIFFLAGS, $ifr)
      or die "Error calling ioctl on $dev. Errno: $!";
   my $flags = unpack('x[16]S', $ifr);
   $flags &= (~IFF_PROMISC);
   $ifr = pack('Z[16]Sx[14]', $dev, $flags);
   ioctl($s, SIOCSIFFLAGS, $ifr)
      or die "Error calling ioctl on $dev. Errno: $!";

   # Return the socket
   return $s;
}


# Always return 1
1;
