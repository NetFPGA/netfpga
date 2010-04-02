#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: DeviceID.pm 6035 2010-04-01 00:29:24Z grg $
#
# Device ID utilities
#
#############################################################

=head1 NAME

NF::DeviceID - Read and verify device ID information in the Virtex

=cut

package NF::DeviceID;

use warnings;
use strict;

use Exporter;
use Carp;
use NF::Base ('projects/cpci/lib/Perl5');
use NF::RegAccess;
use reg_defines_cpci ();

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';


=head1 SYNOPSIS

    use NF::DeviceID;

    nfReadInfo('nf2c0');
    my $verStr = nfGetDeviceInfoStr();

    # Verify that the reference router is downloaded and is version 1.0,X
    if (!checkVirtexBitfile('nf2c0', 'reference_router', 1, 0, undef, 1, 0, undef)) {
      print getVirtexBitfileErr() . "\n";
    }

=head1 EXPORTS

=head2 Default exports

C<NF::DeviceID> exports the following functions by default:
C<nfReadInfo>,
C<getDeviceInfoStr>,
C<isVirtexProgrammed>,
C<checkVirtexBitfile>,
C<getVirtexBitfileErr>

=head2 Available exports

Additional functions that may be exported are:
C<getCPCIVersion>,
C<getCPCIRevision>,
C<getDeviceID>,
C<getDeviceCPCIVersion>,
C<getDeviceCPCIRevision>,
C<getDeviceMajor>,
C<getDeviceMinor>,
C<getDeviceRevision>,
C<getDeviceIDModuleVersion>,
C<getProjDir>,
C<getProjName>,
C<getProjDesc>

=cut

our @ISA = ('Exporter');

our @EXPORT = qw(
        nfReadInfo
        nfGetDeviceInfoStr
        isVirtexProgrammed
        checkVirtexBitfile
        getVirtexBitfileErr
                );

our @EXPORT_OK = qw(
        getCPCIVersion
        getCPCIRevision
        getDeviceID
        getDeviceCPCIVersion
        getDeviceCPCIRevision
        getDeviceMajor
        getDeviceMinor
        getDeviceRevision
        getDeviceIDModuleVersion
        getProjDir
        getProjName
        getProjDesc
                );

my $prev_device = '';
my $virtex_programmed = 0;
my $have_version_info = 0;
my $cpci_version = -1;
my $cpci_revision = -1;
my $nf2_dev_id_module_version = -1;
my $nf2_device_id = -1;
my $nf2_version = -1;
my $nf2_cpci_version = -1;
my $nf2_cpci_revision = -1;
my $nf2_proj_name_v1 = '';
my $nf2_proj_dir = '';
my $nf2_proj_name = '';
my $nf2_proj_desc = '';
my $versionErrStr = '';

use constant PROJ_UNKNOWN => "Unknown";


=head1 FUNCTIONS

=over 4

=item nfReadInfo ( DEVICE )

Retrieve the device info from C<DEVICE>. The data read can be accessed via the I<getDeviceInfoStr> function or the per-field accessor functions, such as I<getCPCIVersion> and I<getDeviceMajor>.

=cut
sub nfReadInfo {
  my ($nf2) = @_;
  my @md5;
  my ($md5_good_v1, $md5_good_v2);

  # Record which device we last accessed
  $prev_device = $nf2;

  # Read the CPCI version/revision
  my $cpci_id = nf_regread($nf2, reg_defines_cpci::CPCI_ID_REG());
  $cpci_version = $cpci_id & 0xffffff;
  $cpci_revision = $cpci_id >> 24;
  $have_version_info = 1;

  # Check if the Virtex is programmed
  $virtex_programmed = isVirtexProgrammed($nf2);

  # Clear the Virtex-related variables
  $nf2_dev_id_module_version = -1;
  $nf2_device_id = -1;
  $nf2_version = -1;
  $nf2_cpci_version = -1;
  $nf2_cpci_revision = -1;
  $nf2_proj_name_v1 = '';
  $nf2_proj_dir = '';
  $nf2_proj_name = '';
  $nf2_proj_desc = '';

  # Verify the MD5 checksum of the device ID block
  for  (my $i = 0; $i < 4; $i++) {
    $md5[$i] = nf_regread($nf2, main::DEV_ID_MD5_0_REG() + $i * 4);
  }

  $md5_good_v1 = ($md5[0] == main::DEV_ID_MD5_VALUE_V1_0()) &&
                 ($md5[1] == main::DEV_ID_MD5_VALUE_V1_1()) &&
                 ($md5[2] == main::DEV_ID_MD5_VALUE_V1_2()) &&
                 ($md5[3] == main::DEV_ID_MD5_VALUE_V1_3());

  $md5_good_v2 = ($md5[0] == main::DEV_ID_MD5_VALUE_V2_0()) &&
                 ($md5[1] == main::DEV_ID_MD5_VALUE_V2_1()) &&
                 ($md5[2] == main::DEV_ID_MD5_VALUE_V2_2()) &&
                 ($md5[3] == main::DEV_ID_MD5_VALUE_V2_3());

  # Process only if the MD5 sum is good
  if ($md5_good_v1 || $md5_good_v2) {
    # Read the version and revision
    $nf2_device_id = nf_regread($nf2, main::DEV_ID_DEVICE_ID_REG());
    $nf2_version = nf_regread($nf2, main::DEV_ID_VERSION_REG());
    my $nf2_cpci_id = nf_regread($nf2, main::DEV_ID_CPCI_ID_REG());
    $nf2_cpci_version = $nf2_cpci_id & 0xffffff;
    $nf2_cpci_revision = $nf2_cpci_id >> 24;
  }

  if ($md5_good_v1) {
    $nf2_dev_id_module_version = 1;
    $nf2_proj_name_v1 = nf_regreadstr($nf2, main::DEV_ID_PROJ_DIR_0_REG(), main::DEV_ID_PROJ_NAME_BYTE_LEN_V1());
  }

  if ($md5_good_v2) {
    $nf2_dev_id_module_version = 2;
    $nf2_proj_dir = nf_regreadstr($nf2, main::DEV_ID_PROJ_DIR_0_REG(), main::DEV_ID_PROJ_DIR_BYTE_LEN());
    $nf2_proj_name = nf_regreadstr($nf2, main::DEV_ID_PROJ_NAME_0_REG(), main::DEV_ID_PROJ_NAME_BYTE_LEN());
    $nf2_proj_desc = nf_regreadstr($nf2, main::DEV_ID_PROJ_DESC_0_REG(), main::DEV_ID_PROJ_DESC_BYTE_LEN());
  }
}


=item isVirtexProgrammed ( DEVICE )

Check whether the Virtex in C<DEVICE> is programmed.

=cut
sub isVirtexProgrammed {
  my ($nf2) = @_;

  my $progStatus = nf_regread($nf2, reg_defines_cpci::CPCI_REPROG_STATUS_REG());
  return ($progStatus & reg_defines_cpci::CPCI_REPROG_STATUS_DONE()) != 0;
}


=item getCPCIVersion ( DEVICE )

Return the CPCI version active from C<DEVICE>

=cut
sub getCPCIVersion {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  return $cpci_version;
}


=item getCPCIRevision ( DEVICE )

Get the CPCI revision number active from C<DEVICE>

=cut
sub getCPCIRevision {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  return $cpci_revision;
}


=item getDeviceID ( DEVICE )

Get the Virtex device ID from C<DEVICE>

=cut
sub getDeviceID {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  return $nf2_device_id;
}


=item getDeviceCPCIVersion ( DEVICE )

Get the CPCI version that the Virtex bitfile was compiled against from C<DEVICE>

=cut
sub getDeviceCPCIVersion {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  return $nf2_cpci_version;
}


=item getDeviceCPCIRevision ( DEVICE )

Get the CPCI revision that the Virtex bitfile was compiled against from C<DEVICE>

=cut
sub getDeviceCPCIRevision {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  return $nf2_cpci_revision;
}


=item getDeviceMajor ( DEVICE )

Get the Virtex bitfile major version from C<DEVICE>

=cut
sub getDeviceMajor {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  if ($nf2_dev_id_module_version > 1) {
    return ($nf2_version >> 16) & 0xff;
  }
  else {
    return $nf2_version;
  }
}


=item getDeviceMinor ( DEVICE )

Get the Virtex bitfile minor version from C<DEVICE>

=cut
sub getDeviceMinor {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  if ($nf2_dev_id_module_version > 1) {
    return ($nf2_version >> 8) & 0xff;
  }
  else {
    return 0;
  }
}


=item getDeviceRevision ( DEVICE )

Get the Virtex bitfile revision from C<DEVICE>

=cut
sub getDeviceRevision {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  if ($nf2_dev_id_module_version > 1) {
    return ($nf2_version >> 0) & 0xff;
  }
  else {
    return 0;
  }
}


=item getDeviceIDModuleVersion ( DEVICE )

Get the Virtex bitfile device ID module version from C<DEVICE>

=cut
sub getDeviceIDModuleVersion {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  return $nf2_dev_id_module_version;
}


=item getProjDir ( DEVICE )

Get the Virtex bitfile project dir from C<DEVICE>

=cut
sub getProjDir {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  if ($nf2_dev_id_module_version == 2) {
    return $nf2_proj_dir;
  }
  else {
    return PROJ_UNKNOWN;
  }
}


=item getProjName ( DEVICE )

Get the Virtex bitfile project name from C<DEVICE>

=cut
sub getProjName {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  if ($nf2_dev_id_module_version == 2) {
    return $nf2_proj_name;
  }
  elsif ($nf2_dev_id_module_version == 1) {
    return $nf2_proj_name_v1;
  }
  else {
    return PROJ_UNKNOWN;
  }
}


=item getProjDesc ( DEVICE )

Get the Virtex bitfile project description from C<DEVICE>

=cut
sub getProjDesc {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  if ($nf2_dev_id_module_version == 2) {
    return $nf2_proj_desc;
  }
  else {
    return PROJ_UNKNOWN;
  }
}


=item getDeviceInfoStr ( DEVICE )

Get a string representation of the device ID information. Includes information
for both the CPCI and the Virtex from C<DEVICE>.

=cut
sub getDeviceInfoStr {
  my ($nf2) = @_;

  prepDeviceInfo($nf2);

  my $result = '';

  $result .= sprintf(<<CPCI_INFO_STR,
CPCI Information
----------------
Version: %d (rev %d)

CPCI_INFO_STR
    getCPCIVersion($nf2), getCPCIRevision($nf2));

  if ($virtex_programmed) {
    if (getDeviceIDModuleVersion($nf2) != -1) {
      if (getDeviceIDModuleVersion($nf2) == 2) {
        $result .= sprintf(<<VIRTEX_INFO_V2,

Device (Virtex) Information
---------------------------
Project directory: %s
Project name: %s
Project description: %s

Device ID: %d
Version: %d.%d.%d
Built against CPCI version: %d (rev %d)

VIRTEX_INFO_V2
            getProjDir($nf2),
            getProjName($nf2),
            getProjDesc($nf2),
            getDeviceID($nf2),
            getDeviceMajor($nf2), getDeviceMinor($nf2), getDeviceRevision($nf2),
            getDeviceCPCIVersion($nf2), getDeviceCPCIRevision($nf2)
            );
      }
      elsif (getDeviceIDModuleVersion($nf2) == 1) {
        $result .= sprintf(<<VIRTEX_INFO_V1,
Device (Virtex) Information
---------------------------
Project name: %s

Device ID: %d
Version: %d
Built against CPCI version: %d (rev %d)

VIRTEX_INFO_V1
            getProjName($nf2),
            getDeviceID($nf2),
            getDeviceMajor($nf2),
            getDeviceCPCIVersion($nf2), getDeviceCPCIRevision($nf2)
            );
      }
      else {
        $result .= sprintf(<<VIRTEX_INFO_UNKNOWN,
Unknown Device ID Module verions: %d

VIRTEX_INFO_UNKNOWN
            getDeviceIDModuleVersion($nf2));
      }
    }
    else {
      $result .= <<DEVICE_INFO_NOT_FOUND;
Device (Virtex) Information
---------------------------
Device info not found

DEVICE_INFO_NOT_FOUND
    }
  }
  else {
    $result .= <<DEVICE_INFO_NOT_PROGRAMMED;
Device (Virtex) Information
---------------------------
Device not_programmed

DEVICE_INFO_NOT_PROGRAMMED
  }

  return $result;
}


=item checkVirtexBitfile ( DEVICE, PROJECT, MIN_MAJOR, MIN_MINOR, MIN_REV,
MAX_MAJOR, MAX_MINOR, MAX_REV )

Verify that the bitfile corresponding to C<PROJECT> is downloaded to C<DEVICE>.

Minimum and maximum version numbers can optionally be specified with
C<MIN_MAJOR>, C<MIN_MINOR>, C<MIN_REV>, C<MAX_MAJOR>, C<MAX_MINOR>, and
C<MAX_REV>. A value of C<undef> for any of these fields means "don't care",
allowing specification of some details, such as version 1.x.x: C<MIN_MAJOR> =
1, C<MIN_MINOR> = C<undef>, C<MIN_REV> = C<undef>.

=cut
sub checkVirtexBitfile {
  my ($nf2, $projDir,
    $minVerMajor, $minVerMinor, $minVerRev,
    $maxVerMajor, $maxVerMinor, $maxVerRev,
  ) = @_;

  my ($minVer, $maxVer, $virtexVer);

  # Ensure that we've read the device info
  prepDeviceInfo($nf2);

  # Check if the Virtex is programmed
  if (!$virtex_programmed) {
    $versionErrStr = "Error: Virtex is not programmed";
    return 0;
  }

  # Calculate the version numbers as necessary
  $minVer = 0;
  $minVer += $minVerMajor if defined($minVerMajor);
  $minVer <<= 8;
  $minVer += $minVerMinor  if defined($minVerMinor);
  $minVer <<= 8;
  $minVer += $minVerRev if defined($minVerRev);

  $maxVer = 0;
  $maxVer += defined($maxVerMajor) ? $maxVerMajor : 255;
  $maxVer <<= 8;
  $maxVer += defined($maxVerMinor) ? $maxVerMinor : 255;
  $maxVer <<= 8;
  $maxVer += defined($maxVerRev) ? $maxVerRev : 255;

  $virtexVer = (getDeviceMajor($nf2) << 16) |
               (getDeviceMinor($nf2) << 8) |
               getDeviceRevision($nf2);

  # Check the device name
  my $virtexProjDir;
  my $virtexProjName;
  if ($nf2_dev_id_module_version >= 2) {
    $virtexProjDir = getProjDir($nf2);
    $virtexProjName = getProjName($nf2);
  }
  else {
    $virtexProjDir = getProjName($nf2);
    $virtexProjName = PROJ_UNKNOWN;
  }

  if ($virtexProjDir ne $projDir) {
    $versionErrStr = "Error: Incorrect bitfile loaded. Found '$virtexProjDir' ($virtexProjName), expecting: '$projDir'";
    return 0;
  }

  # Check the version number
  if ($virtexVer < $minVer || $virtexVer > $maxVer) {
    # Work out equality etc
    my $hasMin = defined($minVerMajor) || defined($minVerMinor) || defined($minVerRev);
    my $hasMax = defined($maxVerMajor) || defined($maxVerMinor) || defined($maxVerRev);
    my $verMajorEqual = (defined($minVerMajor) ? $minVerMajor : -1) ==
                        (defined($maxVerMajor) ? $maxVerMajor : -1);
    my $verMinorEqual = (defined($minVerMinor) ? $minVerMinor : -1) ==
                        (defined($maxVerMinor) ? $maxVerMinor : -1);
    my $verRevEqual = (defined($minVerRev) ? $minVerRev : -1) ==
                      (defined($maxVerRev) ? $maxVerRev : -1);
    my $minMaxEqual = $verMajorEqual && $verMinorEqual && $verRevEqual;

    # Generate strings for min and max
    my $minStr = '';
    $minStr .= defined($minVerMajor) ? $minVerMajor : "x";
    $minStr .= defined($minVerMinor) ? ".$minVerMinor" : ".x";
    $minStr .= defined($minVerRev) ? ".$minVerRev" : ".x";
    my $maxStr = '';
    $maxStr .= defined($maxVerMajor) ? $maxVerMajor : "x";
    $maxStr .= defined($maxVerMinor) ? ".$maxVerMinor" : ".x";
    $maxStr .= defined($maxVerRev) ? ".$maxVerRev" : ".x";

    my $virtexVerStr = getDeviceMajor($nf2) . '.' .
                       getDeviceMinor($nf2) . '.' .
                       getDeviceRevision($nf2);

    if ($minMaxEqual) {
      $versionErrStr = "Error: Incorrect version for bitfile: '$projDir' ($virtexProjName).  Expecting: $minStr   Active: $virtexVerStr";
    }
    elsif ($hasMin && $hasMax) {
      $versionErrStr = "Error: Incorrect version for bitfile: '$projDir' ($virtexProjName).  Expecting: $minStr -- $maxStr   Active: $virtexVerStr";
    }
    elsif ($hasMin) {
      $versionErrStr = "Error: Incorrect version for bitfile: '$projDir' ($virtexProjName).  Expecting: > $minStr   Active: $virtexVerStr";
    }
    else {
      $versionErrStr = "Error: Incorrect version for bitfile: '$projDir' ($virtexProjName).  Expecting: < $maxStr   Active: $virtexVerStr";
    }
    return 0;
  }

  $versionErrStr = 'GOOD';
  return 1;
}

=item getVirtexBitfileErr ( )

Retrieve the error string corresponding to the most-recent call to
I<checkVirtexBitfile>

=cut
sub getVirtexBitfileErr {
  return $versionErrStr;
}

=back

=cut

sub prepDeviceInfo {
  my ($nf2) = @_;

  confess "Crap" if !defined($nf2);

  if (!$have_version_info || $prev_device ne $nf2) {
    nfReadInfo($nf2);
  }
}


=head1 BUGS

Please report any bugs or feature requests through the forums/bug reporting
tools: L<http://netfpga.org/forums/> and L<http://netfpga.org/bugzilla/>

=cut

1; # End of NF::DeviceID
