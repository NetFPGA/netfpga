#############################################################
# vim:set shiftwidth=3 softtabstop=3 expandtab:
# $Id: RegAccess.pm 6035 2010-04-01 00:29:24Z grg $
#
#
# NetFPGA register access library for NetFPGA
#
#
# Invoke using: use NF::RegAccess
#
# Module provides the ability to access registers on a
# NetFPGA card
#
# Revisions:
#
##############################################################

package NF::RegAccess;

use strict;
use Exporter;
use Socket;
use IO::Socket;
use English;
use POSIX qw(floor);

use vars qw(@ISA @EXPORT);  # needed cos strict is on

@ISA = ('Exporter');
@EXPORT = qw(
               &nf_regread
               &nf_regreadstr
               &nf_regwrite
               &nf_get_hw_reg_access
            );

# Hash of file descriptors corresponding to each port
my %sockets;

# Convenient constants
sub SO_BINDTODEVICE {25;}
sub SIOCREGREAD {0x89F0;}
sub SIOCREGWRITE {0x89F1;}
sub SIOCGIFNAME {0x8910;}
sub SIOCGIFADDR {0x8915;}
#sub SIOCREGREAD {SIOCDEVPRIVATE;}
#sub SIOCREGWRITE {SIOCDEVPRIVATE + 1;}

###############################################################
# Name: nf_get_hw_reg_access
# returns (\&nf_regwrite, \&nf_regread, \&nf_regread_expect, device)
# Arguments: device
#
###############################################################
sub nf_get_hw_reg_access {
  return (\&nf_regwrite, \&nf_regread, \&nf_regread_expect, shift);
}

###############################################################
# Name: nf_regread
# Subroutine to read a hardware register and return the value
# in that register
# Arguments: device
#            address
###############################################################
sub nf_regread {
   my $device = shift;
   my $reg = shift;
   my $val = 0;

   # Call the ioctl to perform the read
   return regAccess($device, SIOCREGREAD, $reg, $val);
}

###############################################################
# Name: nf2_regread_expect
# Subroutine to read a hardware register and check if it matches
# the expected value.
# Arguments: device
#            address
#            expected_data
###############################################################
sub nf_regread_expect {
   my $device = shift;
   my $reg = shift;
   my $exp = shift;
   my $val = 0;

   # Call the ioctl to perform the read
   return ($exp==regAccess($device, SIOCREGREAD, $reg, $val));
}


###############################################################
# Name: nf2_regwrite
# Subroutine to write a hardware register
# Arguments: device
#            address
#            value
###############################################################
sub nf_regwrite {
   my $device = shift;
   my $reg = shift;
   my $val = shift;

   # Call the ioctl to perform the read
   return regAccess($device, SIOCREGWRITE, $reg, $val);
}



###############################################################
# Name: regAccess
# Subroutine to read or write a hardware register and return
# the value in that register
# Arguments: device
#            accessType
#            address
#            value
###############################################################
sub regAccess {
   my $device = shift;
   my $accessType = shift;
   my $reg = shift;
   my $val = shift;

   # Open a descriptor if necessary
   openDescriptor($device);

   # Get the descriptor
   my $fh = $sockets{$device};

   # Create an "nf2reg" struct variable
   my $nf2reg = pack('II', $reg, $val);

   # Create an "ifr" struct variable
   my $ifr = pack('a[16]Px[12]', $device, $nf2reg);

   # Call the ioctl to perform the read
   ioctl($fh, $accessType, $ifr);

   # Get the result
   ($reg, $val) = unpack('II', $nf2reg);

   return $val;
}



###############################################################
# Name: openDesciptor
# Subroutine to open a descriptor corresponding to a particular port
# Arguments: device
###############################################################
sub openDescriptor
{
   # Arguments
   my $device = shift;

   # Check to see if the descriptor already exists
   if (!exists($sockets{$device})) {
      # Generate the socket
      my $proto = getprotobyname('udp');
      socket(my $fh, PF_INET, SOCK_DGRAM, $proto)
         or die "Unable to create socket for '$device'";

      # Work out whether we're running as root or not. Root can bind to a
      # network interface -- non-root users have to bind to the address
      # corresponding to the device.
      if ($EUID == 0) {
         # Set the necessary options on the socket to bind it to the device
         setsockopt($fh, SOL_SOCKET, SO_BINDTODEVICE, pack('Z*', $device))
            or die "Unable to set socket option SO_BINDTODEVICE on device '$device'";
      }
#      else {
#         my $ifr;
#         my $found = 0;
#
#         # Attempt to find the IP address for the interface
#         SEARCH: for (my $i = 1; 1 ; $i++) {
#            # Find interface number i
#            $ifr = pack('a[16]a[16]', '', pack('I', $i));
#            last if ((ioctl ($fh, SIOCGIFNAME, $ifr) || -1) < 0);
#
#            # Check if we've found the correct interface */
#            my ($name, $data) = unpack('Z[16]a[16]', $ifr);
#            next SEARCH if ($name ne $device);
#
#            # If we get to here we've found the IP */
#            $found = 1;
#            last;
#         }
#
#         # Check to ensure that we actually found the device
#         if (!$found) {
#            die "Can't find address for device '$device'";
#         }
#
#         # Attempt to get the IP address associated with the interface
#         if ((ioctl ($fh, SIOCGIFADDR, $ifr) || -1) < 0) {
#            die "Unable to get address for device '$device' -- error calling SIOCGIFADDR";
#         }
#
#         # Bind to the given address
#         my ($name, $data) = unpack('Z[16]a[16]', $ifr);
#         bind($fh, sockaddr_in(0, substr($data, 4, 4)))
#            or die "Unable to bind to address associated with '$device'";
#      }

      # Store the descriptor on the hash
      $sockets{$device} = $fh;
   }

   1;
}

###############################################################
# Name: nf_regreadstr
# Read a string from the NetFPGA
# Arguments:
#     nf2      - NetFPGA device to read from
#     regStart - address of first word of string
#     len      - maximum length of string
# Returns: string read from NetFPGA
###############################################################
sub nf_regreadstr {
	my ($nf2, $regStart, $len) = @_;
	my $result = '';
        my $done = 0;

	# Read the string
        for (my $i = 0; $i < floor($len / 4) && !$done; $i++)
        {
                my $val = nf_regread($nf2, $regStart + $i * 4);

		# Extract the bytes
		my @vals = reverse(unpack('CCCC', pack('L', $val)));

		# Convert to characters
		for (my $j = 0; $j < 4 && !$done; $j++) {
			if ($vals[$j] != 0) {
                           $result .= chr($vals[$j]);
                        }
                        else {
                           $done = 1;
                        }
		}
        }

	return $result;
}


# Always end library in 1
1;
