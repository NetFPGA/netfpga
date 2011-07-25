#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: PythonOutput.pm 6035 2010-04-01 00:29:24Z grg $
#
# Python file output
#
#############################################################

package NF::RegSystem::PythonOutput;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw(
                genPythonOutput
            );

use Carp;
use NF::RegSystem::File;
use NF::Utils;
use NF::RegSystem qw($PROJECTS_DIR $LIB_DIR);
use POSIX;
use Math::BigInt;
use strict;

# Path locations
my $LIB_PYTHON = $LIB_DIR . '/Python';
my $PYTHON_PREFIX = 'reg_defines';

my @exports;

#
# genPythonOutput
#   Generate the Python defines file corresponding to the project
#
# Params:
#   project     -- Project object
#   layout      -- Layout object
#   usedModules -- Hash of used modules
#   constsHash  -- Hash of constants
#   constsArr   -- Array of constant names?
#   typesHash   -- Hash of types
#   typesArr    -- Array of type names?
sub genPythonOutput {
  my ($project, $layout, $usedModules,
    $constsHash, $constsArr, $typesHash, $typesArr) = @_;

  my $projDir = $project->dir();
  my $memalloc = $layout->getMemAlloc();
  my $verilogOnlyMemalloc = $layout->getVerilogOnlyMemAlloc();

  # Get a file handle
  my $moduleName = "${PYTHON_PREFIX}_${projDir}";
  $moduleName =~ s/\./_/g;
  my $fh = openRegFile("$PROJECTS_DIR/$projDir/$LIB_PYTHON/${moduleName}.py");

  outputHeader($fh, $moduleName, $project);

  # Output the version
  outputVersion($fh, $project, $layout);

  # Output the constants
  outputConstants($fh, $constsArr);

  # Output the modules
  outputMemAlloc($fh, $memalloc, $verilogOnlyMemalloc);

  # Output the registers
  outputRegisters($fh, $memalloc);

  # Output the bitmasks associated with the types
  outputBitmasks($fh, $typesArr);

  # Output the reverse register map
  outputRegMap($fh, $memalloc);

  outputFooter($fh);

  # Finally close the file
  closeRegFile($fh);
}

# outputVersion
#   Output version information
#
# Params:
#   fh        -- file handle
#   project   -- project object
#   layout    -- layout object
#
sub outputVersion {
  my ($fh, $project, $layout) = @_;

  my $dir = $project->dir();
  my $name = $project->name();
  my $desc = $project->desc();
  my $verMajor = $project->verMajor();
  my $verMinor = $project->verMinor();
  my $verRevision = $project->verRevision();
  my $devId = $project->devId();

  print $fh <<VERSION_TITLE;
# -------------------------------------
#   Version Information
# -------------------------------------
VERSION_TITLE

  my $type = ref($layout);
  if ($type eq 'NF::RegSystem::CPCILayout') {
    my $verStr = sprintf('%06x', $verMajor);
    my $revStr = sprintf('%02x', $verMinor);

    print $fh <<VERSION_CPCI;
# CPCI version number (major number)
def CPCI_VERSION_ID ():
    return 0x$verStr

# CPCI revision number (minor number)
def CPCI_REVISION_ID ():
    return 0x$revStr


VERSION_CPCI
  }
  elsif ($type eq 'NF::RegSystem::ReferenceLayout') {

    print $fh <<VERSION_REFERENCE;
def DEVICE_ID ():
    return $devId

def DEVICE_MAJOR ():
    return $verMajor

def DEVICE_MINOR ():
    return $verMinor

def DEVICE_REVISION ():
    return $verRevision

def DEVICE_PROJ_DIR ():
    return "$dir"

def DEVICE_PROJ_NAME ():
    return "$name"

def DEVICE_PROJ_DESC ():
    return "$desc"


VERSION_REFERENCE
  }
  else {
    croak "Unknown layout $type";
  }
}

#
# outputConstants
#   Output the constants associated with each module
#
# Params:
#   fh         -- file handle
#   constsArr  -- Array of constant names
#
sub outputConstants {
  my ($fh, $constants) = @_;

  return if (length(@$constants) == 0);

  print $fh <<CONSTANTS_HEADER;
# -------------------------------------
#   Constants
# -------------------------------------

CONSTANTS_HEADER

  my $maxStrLen = 0;
  for my $constant (@$constants) {
    my $len = length($constant->name());
    $maxStrLen = $len if ($len > $maxStrLen);
  }

  # Walk through the constants
  my $currFile = '';
  for my $constant (@$constants) {
    my $name = uc($constant->name());
    my $desc = $constant->desc();
    my $value = $constant->value();
    my $width = $constant->width();
    my $wantHex = $constant->wantHex();
    my $file = $constant->file();

    if ($file ne $currFile) {
      print $fh "\n" if ($currFile ne '');
      print $fh "# ===== File: $file =====\n\n";
      $currFile = $file;
    }

    my $pad = (' ') x ($maxStrLen - length($name));

    if (defined($desc) && $desc ne '') {
      print $fh "# $desc\n";
    }

    if ($wantHex) {
      my $hexWidth = ceil($width / 4);
      my $bigVal = Math::BigInt->new($value);
      my $hexStr = substr($bigVal->as_hex(), 2);
      $hexStr = (('0') x ($hexWidth - length($hexStr))) . $hexStr;

      # Print the constant split up over multiple 32-bit values if it's
      # wider than 32 bits
      if ($width > 32) {
        outputWideConstant($fh, $name, $value, $width, $pad);
      }
      else {
        printf($fh "def $name (): $pad\n");
        printf($fh "    return 0x%0${hexWidth}s\n", $hexStr);
      }

    }
    else {
      printf($fh "def $name (): $pad\n");
      printf($fh "    return $value\n");
    }
    print $fh "\n";
  }
  print $fh "\n\n";

}

#
# outputWideConstant
#   Split a wide constant and output it as multiple small constants
#
# Params:
#   fh        -- file handle
#
sub outputWideConstant {
  my ($fh, $name, $value, $width, $pad) = @_;

  my $bigVal = Math::BigInt->new($value);

  # Adjust the pad
  $pad = trimString($pad, 2);

  # Work out the number of sub constants
  my $numSubConsts = $width >> 5;
  $numSubConsts += 1 if (($width & (32 - 1)) != 0);

  if ($numSubConsts == 2) {
    $pad = trimString($pad, 1);
  }

  for (my $i = 0; $i < $numSubConsts; $i++) {
    my $subConst = $bigVal >> (($numSubConsts - $i - 1) * 32);
    $subConst &= 2 ** 32 - 1;

    my $hexWidth = 32;
    if ($i == 0 && (($width & (32 - 1)) != 0)) {
      $hexWidth = $width & (32 - 1);
    }
    $hexWidth = ceil($hexWidth / 4);

    my $hexStr = substr($subConst->as_hex(), 2);
    $hexStr = (('0') x ($hexWidth - length($hexStr))) . $hexStr;

    my $suffix = $i;
    if ($numSubConsts == 2) {
      $suffix = $i == 0 ? 'HI' : 'LO';
    }
    printf($fh "def ${name}_${suffix} (): $pad\n");
    printf($fh "    return 0x%0${hexWidth}s\n", $hexStr);
    print $fh "\n";
  }
}

#
# outputMemAlloc
#   Output the module allocations
#
# Params:
#   fh        -- file handle
#   memalloc    -- memory allocations
#   voMemalloc  -- Verilog only memory allocations
#
sub outputMemAlloc {
  my ($fh, $memalloc, $voMemalloc) = @_;

  return if (scalar(@$memalloc) == 0 && scalar(@$voMemalloc) == 0);

  print $fh <<MEMALLOC_HEADER;
## -------------------------------------
##   Modules
## -------------------------------------

MEMALLOC_HEADER

  # Sort the memory allocation
  my %localMemalloc;
  my @localMemalloc;
  for my $memallocObj (@$voMemalloc, @$memalloc) {
    my $start = sprintf("%07x", $memallocObj->start());
    if (!defined($localMemalloc{$start})) {
      $localMemalloc{$start} = [$memallocObj];
    }
    else {
      push @{$localMemalloc{$start}}, $memallocObj;
    }
  }
  for my $start (sort(keys(%localMemalloc))) {
    push @localMemalloc, @{$localMemalloc{$start}};
  }

  # Walk through the list of memory allocations and print the tag/addr widths
  # for each module
  my %moduleAddrs;
  my $maxModuleLen = 0;
  my $maxMemAllocLen = 0;
  for my $memallocObj (@$memalloc, @$voMemalloc) {
    my $prefix = $memallocObj->{module}->prefix();

    # Record the address
    if (!defined($moduleAddrs{$prefix})) {
      $moduleAddrs{$prefix} = [];
    }
    push @{$moduleAddrs{$prefix}}, $memallocObj->start();

    # Update the max abbrev/full name lengths
    my $len = length($prefix);
    $maxModuleLen = $len if ($len > $maxModuleLen);

    $len = length($memallocObj->name());
    $maxMemAllocLen = $len if ($len > $maxMemAllocLen);
  }

  # Walk through the list of memory allocations and print them
  print $fh "# Module tags\n";
  for my $memallocObj (@localMemalloc) {
    my $prefix = uc($memallocObj->name());
    my $start = $memallocObj->start();

    my $pad = (' ') x ($maxMemAllocLen - length($prefix));

    printf($fh "def ${prefix}_BASE_ADDR (): $pad\n");
    printf($fh "    return 0x%07x\n", $start);
    print $fh "\n";
  }
  print $fh "\n";

  # Walk through the list of memory allocations and print offsets
  for my $prefix (sort(keys(%moduleAddrs))) {
    my $addrs = $moduleAddrs{$prefix};
    if (scalar(@$addrs) > 1) {

      my $offset = $addrs->[1] - $addrs->[0];
      for (my $i = 2; $i < scalar(@$addrs); $i++) {
        if ($addrs->[$i] - $addrs->[$i-1] != $offset) {
          $offset = -1;
        }
      }

      if ($offset != -1) {
        my $ucPrefix = uc($prefix);
        my $pad = (' ') x ($maxModuleLen - length($prefix));
        printf($fh "def ${ucPrefix}_OFFSET (): $pad\n");
        printf($fh "    return 0x%07x\n", $offset);
        print $fh "\n";
      }
    }
  }
  print $fh "\n\n";
}

#
# outputRegisters
#   Output the registers associated with each module
#
# Params:
#   fh        -- file handle
#   memalloc  -- memory allocation
#
sub outputRegisters {
  my ($fh, $memalloc) = @_;

  return if (length(@$memalloc) == 0);

  print $fh <<REGISTER_HEADER;
# -------------------------------------
#   Registers
# -------------------------------------

REGISTER_HEADER

  # Walk through the list of memory allocations and print them
  for my $memallocObj (@$memalloc) {
    my $module = $memallocObj->module();
    my $name = $module->name();
    my $desc = $module->desc();
    my $file = $module->file();

    my $prefix = uc($memallocObj->name());
    my $start = $memallocObj->start();
    my $len = $memallocObj->len();
    my $tag = $memallocObj->tag();
    my $tagWidth = $memallocObj->{module}->tagWidth();

    print $fh "# Name: $name ($prefix)\n";
    print $fh "# Description: $desc\n" if (defined($desc));
    print $fh "# File: $file\n" if (defined($file));

    my $regs = $module->getRegDump();
    outputModuleRegisters($fh, $prefix, $start, $module, $regs);
    print $fh "\n";

    if ($module->hasRegisterGroup()) {
      my $regGroup = $module->getRegGroup();
      outputModuleRegisterGroupSummary($fh, $prefix, $start, $module, $regGroup);
    }
  }
  print $fh "\n\n";
}

#
# outputModuleRegisters
#   Output the registers associated with a module (non register group)
#
# Params:
#   fh        -- file handle
#   prefix    -- prefix
#   start     -- start address
#   module    -- module
#   regs      -- register array dump
#
sub outputModuleRegisters {
  my ($fh, $prefix, $start, $module, $regs) = @_;

  #my $prefix = uc($module->prefix());

  my $maxStrLen = 0;
  for my $reg (@$regs) {
    my $len = length($reg->{name});
    $maxStrLen = $len if ($len > $maxStrLen);
  }

  for my $reg (@$regs) {
    my $regName = uc($reg->{name});
    my $addr = $reg->{addr};

    my $pad = (' ') x ($maxStrLen - length($regName));

    printf($fh "def ${prefix}_${regName}_REG (): $pad\n");
    printf($fh "    return 0x%07x\n", $addr + $start);
    print $fh "\n";
  }
}

#
# outputModuleRegisterGroupSummary
#   Output the register group summary associated with a module
#
# Params:
#   fh        -- file handle
#   prefix    -- prefix
#   start     -- start address
#   module    -- module
#   regGroup  -- hash of used modules
#
sub outputModuleRegisterGroupSummary {
  my ($fh, $prefix, $start, $module, $regGroup) = @_;

  my $grpName = uc($regGroup->name());
  my $instSize = $regGroup->instSize();
  my $offset = $regGroup->offset();

  printf($fh "def ${prefix}_${grpName}_GROUP_BASE_ADDR ():\n");
  printf($fh "    return 0x%07x\n", $start + $offset);

  print $fh "\n";

  printf($fh "def ${prefix}_${grpName}_GROUP_INST_OFFSET():\n");
  printf($fh "    return 0x%07x\n", $instSize);
  print $fh "\n";
}

#
# outputHeader
#   Output the header of the module
#
# Params:
#   fh        -- file handle
#   modName   -- name of module
#   project   -- project object
#
sub outputHeader {
  my ($fh, $modName, $project) = @_;

  my $dir = $project->dir();
  my $name = $project->name();
  my $desc = $project->desc();

  print $fh <<REGISTER_HEADER_1;
#!/usr/bin/python
#############################################################
#
# Python register defines
#
# Project: $name ($dir)
REGISTER_HEADER_1

  if (defined($desc)) {
    print $fh <<END_HEADER_DESC;
# Description: $desc
END_HEADER_DESC
  }

  print $fh <<REGISTER_HEADER_2;
#
#############################################################

REGISTER_HEADER_2

}

#
# outputFooter
#   Output the footer of the module
#
# Params:
#   fh        -- file handle
#
sub outputFooter {
  my ($fh) = @_;

  print $fh <<REGISTER_FOOTER;


# End of File
REGISTER_FOOTER

}

#
# trimString
#   Trim a string by knocking off the first n characters
#
# Params:
#   str -- string to trim
#   amt -- amount to trim by
#
# Return:
#   trimmed string (note: shortest string is an empty string)
#
sub trimString {
  my ($str, $amt) = @_;

  if (length($str) <= $amt) {
    return '';
  }
  else {
    return substr($str, $amt);
  }
}

#
# outputBitmasks
#   Output the bitmasks associated with types
#
# Params:
#   fh        -- file handle
#   types       -- array of all types
#
sub outputBitmasks {
  my ($fh, $types) = @_;

  my @bitmaskTypes;

  # Walk through the list of types and work out which ones contain bitmasks
  for my $type (@$types) {
    if (ref($type) eq 'NF::RegSystem::SimpleType') {
      if (defined($type->bitmasks())) {
        push @bitmaskTypes, $type;
      }
    }
  }

  # Work out whether we have any bitmasks
  return if (scalar(@bitmaskTypes) == 0);

  print $fh <<BITMASK_HEADER;
# -------------------------------------
#   Bitmasks
# -------------------------------------

BITMASK_HEADER

  # Walk through the list of bitmask types and output the bitmasks
  my $widthLen = length('_WIDTH');
  my $maskLen = length('_MASK');
  my $posLen = length('_POS');
  my $posHiLen = length('_POS_HI');
  for my $type (@bitmaskTypes) {
    # Get the name
    my $typeName = $type->name();
    my $desc = $type->desc();
    my $file = $type->file();

    print $fh "# Type: $typeName\n";
    print $fh "# Description: $desc\n" if (defined($desc));
    print $fh "# File: $file\n";
    print $fh "\n";

    $typeName = uc($typeName);

    # Work out the maximum string length of the bitmasks
    my $maxStrLen = 0;
    for my $bitmask (@{$type->bitmasks()}) {
      my $len = length($bitmask->name());
      if ($bitmask->posLo() != $bitmask->posHi()) {
        $len += $posHiLen;
      }
      else {
        $len += $posLen;
      }
      $maxStrLen = $len if ($len > $maxStrLen);
    }

    # Print the bitmasks
    #
    # Part 1: Print positions
    print $fh "# Part 1: bit positions\n";
    my $width = $type->width();
    for my $bitmask (@{$type->bitmasks()}) {
      my $bitmaskName = uc($bitmask->name());
      my $len = length($bitmaskName);

      if ($bitmask->posLo() == $bitmask->posHi()) {
        my $pos = $bitmask->pos();
        my $pad = (' ') x ($maxStrLen - length($bitmaskName) - $posLen);
        #print $fh "def ${typeName}_${bitmaskName}_POS$pad ():\n";
        print $fh "def ${typeName}_${bitmaskName}_POS():\n";
        print $fh "    return $pos\n";
        print $fh "\n";
      }
      else {
        my $posLo = $bitmask->posLo();
        my $posHi = $bitmask->posHi();
        my $width = $posHi - $posLo + 1;
        my $pad;

        $pad = (' ') x ($maxStrLen - length($bitmaskName) - $posHiLen);
        #print $fh "def ${typeName}_${bitmaskName}_POS_LO$pad ():\n";
        print $fh "def ${typeName}_${bitmaskName}_POS_LO():\n";
        print $fh "    return $posLo\n";
        print $fh "\n";

        #print $fh "def ${typeName}_${bitmaskName}_POS_HI$pad ():\n";
        print $fh "def ${typeName}_${bitmaskName}_POS_HI():\n";
        print $fh "    return $posHi\n";
        print $fh "\n";

        $pad = (' ') x ($maxStrLen - length($bitmaskName) - $widthLen);

        #print $fh "def ${typeName}_${bitmaskName}_WIDTH$pad ():\n";
        print $fh "def ${typeName}_${bitmaskName}_WIDTH():\n";
        print $fh "    return $width\n";
        print $fh "\n";
      }
    }
    print $fh "\n";

    # Part 2: Masks/values
    print $fh "# Part 2: masks/values\n";
    my $nibbles = ceil($width / 4);
    for my $bitmask (@{$type->bitmasks()}) {
      my $bitmaskName = uc($bitmask->name());
      my $len = length($bitmaskName);

      if ($bitmask->posLo() == $bitmask->posHi()) {
        my $pos = $bitmask->pos();
        my $pad = (' ') x ($maxStrLen - length($bitmaskName));
        my $mask = 1 << $pos;
        #print $fh sprintf "def ${typeName}_${bitmaskName}$pad ():\n";
        print $fh sprintf "def ${typeName}_${bitmaskName}():\n";
        print $fh sprintf "    return 0x%0${nibbles}x; \n", $mask;
        print $fh "\n";
      }
      else {
        my $posLo = $bitmask->posLo();
        my $posHi = $bitmask->posHi();
        my $width = $posHi - $posLo + 1;
        my $pad;

        my $mask = (2 ** ($posHi + 1)) - 1;
        $mask ^= (2 ** $posLo) - 1;

        $pad = (' ') x ($maxStrLen - length($bitmaskName) - $maskLen);
        #print $fh sprintf "def ${typeName}_${bitmaskName}_MASK$pad ():\n";
        print $fh sprintf "def ${typeName}_${bitmaskName}_MASK():\n";
        print $fh sprintf "    return 0x%0${nibbles}x\n", $mask;
        print $fh "\n";
      }
    }
    print $fh "\n";
  }
  print $fh "\n\n";
}

#
# outputRegMap
#   Output the reverse register map
#
# Params:
#   fh        -- file handle
#   memalloc  -- memory allocation
#
sub outputRegMap {
  my ($fh, $memalloc) = @_;

  return if (length(@$memalloc) == 0);

  print $fh <<REGMAP_HEADER;
# -------------------------------------
#   Register map
# -------------------------------------

import __main__;
if 'nf_regmap' not in dir(__main__):
    __main__.nf_regmap = {}

__main__.nf_regmap.update({
REGMAP_HEADER

  # Walk through the list of memory allocations and print them
  for my $memallocObj (@$memalloc) {
    my $module = $memallocObj->module();

    my $prefix = uc($memallocObj->name());
    my $start = $memallocObj->start();

    my $regs = $module->getRegDump();
    outputModuleRegMap($fh, $prefix, $start, $module, $regs);
  }
  print $fh "})\n\n\n";
}

#
# outputModuleRegMap
#   Output the register map associated with a module (non register group)
#
# Params:
#   fh        -- file handle
#   prefix    -- prefix
#   start     -- start address
#   module    -- module
#   regs      -- register array dump
#
sub outputModuleRegMap {
  my ($fh, $prefix, $start, $module, $regs) = @_;

  my $needNewLine = 0;
  for my $reg (@$regs) {
    my $regName = uc($reg->{name});
    my $addr = $reg->{addr};

    printf($fh "    0x%07x : \"${prefix}_${regName}_REG\",\n", $addr + $start);
    $needNewLine = 1;
  }
  print $fh "\n" if $needNewLine;
}

1;
__END__
