#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: VerilogOutput.pm 6035 2010-04-01 00:29:24Z grg $
#
# Verilog file output
#
#############################################################

package NF::RegSystem::VerilogOutput;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw(
                genVerilogOutput
            );

use Carp;
use NF::RegSystem::File;
use NF::Utils;
use NF::RegSystem qw($PROJECTS_DIR $INCLUDE_DIR);
use POSIX;
use Math::BigInt;
use strict;

# Path locations
my $REG_FILE = 'registers.v';

#
# genVerilogOutput
#   Generate the Verilog defines file corresponding to the project
#
# Params:
#   project     -- Project object
#   layout      -- Layout object
#   usedModules -- Hash of used modules
#   constsHash  -- Hash of constants
#   constsArr   -- Array of constant names?
#   typesHash   -- Hash of types
#   typesArr    -- Array of type names?
sub genVerilogOutput {
  my ($project, $layout, $usedModules,
    $constsHash, $constsArr, $typesHash, $typesArr) = @_;

  my $projDir = $project->dir();
  my $memalloc = $layout->getMemAlloc();
  my $verilogOnlyMemalloc = $layout->getVerilogOnlyMemAlloc();

  # Get a file handle
  my $fh = openRegFile("$PROJECTS_DIR/$projDir/$INCLUDE_DIR/$REG_FILE");

  # Output a header
  outputHeader($fh, $project);

  # Output version information
  outputVersion($fh, $project, $layout);

  # Output the constants
  outputConstants($fh, $constsArr);

  # Output the modules
  outputMemAlloc($fh, $memalloc, $verilogOnlyMemalloc);

  # Output the registers
  outputRegisters($fh, $usedModules);

  # Output the bitmasks associated with the types
  outputBitmasks($fh, $typesArr);

  # Finally close the file
  closeRegFile($fh);
}

#
# outputHeader
#   Output a standard header
#
# Params:
#   fh      -- file handle
#   project -- project object
#
sub outputHeader {
  my ($fh, $project) = @_;

  my $dir = $project->dir();
  my $name = $project->name();
  my $desc = $project->desc();

  print $fh <<END_HEADER_TOP;
///////////////////////////////////////////////////////////////////////////////
//
// Module: $REG_FILE
// Project: $name ($dir)
// Description: Project specific register defines
END_HEADER_TOP

  if (defined($desc)) {
    print $fh <<END_HEADER_DESC;
//
//              $desc
END_HEADER_DESC
  }

  print $fh <<END_HEADER_BOTTOM;
//
///////////////////////////////////////////////////////////////////////////////

END_HEADER_BOTTOM

}

#
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
// -------------------------------------
//   Version Information
// -------------------------------------

VERSION_TITLE

  my $type = ref($layout);
  if ($type eq 'NF::RegSystem::CPCILayout') {
    my $verStr = sprintf('%06x', $verMajor);
    my $revStr = sprintf('%02x', $verMinor);

    print $fh <<VERSION_CPCI;
// CPCI version number (major number)
`define CPCI_VERSION_ID       24'h$verStr

// CPCI revision number (minor number)
`define CPCI_REVISION_ID      8'h$revStr


VERSION_CPCI
  }
  elsif ($type eq 'NF::RegSystem::ReferenceLayout') {
    print $fh <<VERSION_REFERENCE;
`define DEVICE_ID          $devId
`define DEVICE_MAJOR       $verMajor
`define DEVICE_MINOR       $verMinor
`define DEVICE_REVISION    $verRevision
`define DEVICE_PROJ_DIR    "$dir"
`define DEVICE_PROJ_NAME   "$name"
`define DEVICE_PROJ_DESC   "$desc"


VERSION_REFERENCE
  }
  else {
    croak "Unknown layout $type";
  }
}

#
# outputConsts
#   Output the set of constants
#
# Params:
#   fh      -- file handle
#   consts  -- array of constants
#
sub outputConstants {
  my ($fh, $consts) = @_;

  if (scalar(@$consts) > 0) {
  print $fh <<CONST_HEADER;
// -------------------------------------
//   Constants
// -------------------------------------

CONST_HEADER
  }

  # Work out the maximum string length
  my $maxStrLen = 0;
  for my $const (@$consts) {
    my $len = length($const->name());
    $maxStrLen = $len if ($len > $maxStrLen);
  }

  # Walk through the list of constants and print them
  my $currFile = '';
  for my $const (@$consts) {
    my $name = uc($const->name());
    my $desc = $const->desc();
    my $value = $const->value();
    my $width = $const->width();
    my $wantHex = $const->wantHex();
    my $file = $const->file();

    if ($file ne $currFile) {
      print $fh "\n" if ($currFile ne '');
      print $fh "// ===== File: $file =====\n\n";
      $currFile = $file;
    }

    my $pad = (' ') x ($maxStrLen - length($name));

    if (defined($desc) && $desc ne '') {
      print $fh "// $desc\n";
    }

    if ($wantHex) {
      my $hexWidth = ceil($width / 4);
      my $bigVal = Math::BigInt->new($value);
      my $hexStr = substr($bigVal->as_hex(), 2);
      $hexStr = (('0') x ($hexWidth - length($hexStr))) . $hexStr;

      print $fh "`define $name$pad   ${width}'h$hexStr\n";

      # Also print the constant split up over multiple 32-bit values if it's
      # wider than 32 bits
      if ($width > 32) {
        outputWideConstant($fh, $name, $value, $width, $pad);
      }
    }
    else {
      if ($width == 32) {
        print $fh "`define $name$pad   $value\n";
      }
      else {
        print $fh "`define $name$pad   ${width}'d$value\n";
      }
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
    print $fh "`define ${name}_${suffix}$pad   32'h$hexStr\n";
  }
}

#
# outputMemAlloc
#   Output the module allocations
#
# Params:
#   fh          -- file handle
#   memalloc    -- memory allocations
#   voMemalloc  -- Verilog only memory allocations
#
sub outputMemAlloc {
  my ($fh, $memalloc, $voMemalloc) = @_;

  return if (scalar(@$memalloc) == 0 && scalar(@$voMemalloc) == 0);

  print $fh <<MEMALLOC_HEADER;
// -------------------------------------
//   Modules
// -------------------------------------

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
  my %modules;
  my $maxModuleLen = 0;
  my $maxMemAllocLen = 0;
  for my $memallocObj (@$memalloc, @$voMemalloc) {
    # Record the module
    my $prefix = $memallocObj->{module}->prefix();
    $modules{$prefix} = $memallocObj->{module};

    # Update the max abbrev/full name lengths
    my $len = length($prefix);
    $maxModuleLen = $len if ($len > $maxModuleLen);

    $len = length($memallocObj->name());
    $maxMemAllocLen = $len if ($len > $maxMemAllocLen);
  }
  print $fh "// Tag/address widths\n";
  for my $prefix (sort(keys(%modules))) {
    my $tagWidth = $modules{$prefix}->tagWidth();
    my $addrWidth = $modules{$prefix}->addrWidth();

    $prefix = uc($prefix);
    my $pad = (' ') x ($maxModuleLen - length($prefix));

    print $fh "`define ${prefix}_BLOCK_ADDR_WIDTH$pad  $tagWidth\n";
    print $fh "`define ${prefix}_REG_ADDR_WIDTH$pad    $addrWidth\n";
  }
  print $fh "\n";

  # Walk through the list of memory allocations and print them
  print $fh "// Module tags\n";
  for my $memallocObj (@localMemalloc) {
    my $prefix = uc($memallocObj->name());
    my $start = $memallocObj->start();
    my $len = $memallocObj->len();
    my $tag = $memallocObj->tag();
    my $tagWidth = $memallocObj->{module}->tagWidth();

    my $hexWidth = ceil($tagWidth / 4);
    my $bigVal = Math::BigInt->new($tag);
    my $hexStr = substr($bigVal->as_hex(), 2);
    $hexStr = (('0') x ($hexWidth - length($hexStr))) . $hexStr;

    my $pad = (' ') x ($maxMemAllocLen - length($prefix));

    print $fh "`define ${prefix}_BLOCK_ADDR$pad  ${tagWidth}'h$hexStr\n";
  }
  print $fh "\n\n";
}

#
# outputRegisters
#   Output the registers associated with each module
#
# Params:
#   fh      -- file handle
#   modules -- hash of used modules
#
sub outputRegisters {
  my ($fh, $modules) = @_;

  return if (length(keys(%$modules)) == 0);

  print $fh <<REGISTER_HEADER;
// -------------------------------------
//   Registers
// -------------------------------------

REGISTER_HEADER

  # Walk through the modules and print their registers
  for my $name (sort(keys(%$modules))) {
    my $module = $modules->{$name};
    my $regs = $module->getRegDump();
    my $desc = $module->desc();
    my $addrWidth = $module->addrWidth();
    my $file = $module->file();

    print $fh "// Name: $name\n";
    print $fh "// Description: $desc\n" if (defined($desc));
    print $fh "// File: $file\n";

    if ($module->hasRegisterGroup()) {
      my $regGroup = $module->getRegGroup();
      outputModuleRegisterGroup($fh, $module, $regGroup, $addrWidth);
    }

    $regs = $module->getRegDumpNonGroup();
    outputModuleRegisters($fh, $module, $regs, $addrWidth, '');
    print $fh "\n";
  }
  print $fh "\n\n";
}

#
# outputModuleRegisters
#   Output the registers associated with a module (non register group)
#
# Params:
#   fh        -- file handle
#   module    -- module
#   regs      -- register array dump
#   addrWidth -- address width
#   prefix    -- any prefix to place between the module prefix and the reg name
#
sub outputModuleRegisters {
  my ($fh, $module, $regs, $addrWidth, $prefix) = @_;

  my $modPrefix = uc($module->prefix());

  if ($prefix ne '') {
    $prefix .= '_';
  }

  my $maxStrLen = 0;
  for my $reg (@$regs) {
    my $len = length($reg->{name});
    $maxStrLen = $len if ($len > $maxStrLen);
  }

  for my $reg (@$regs) {
    my $regName = uc($reg->{name});
    my $addr = $reg->{addr};

    my $pad = (' ') x ($maxStrLen - length($regName));

    my $bigVal = Math::BigInt->new($addr >> 2);
    my $hexStr = substr($bigVal->as_hex(), 2);
    print $fh "`define ${modPrefix}_${prefix}${regName}$pad  ${addrWidth}'h$hexStr\n";
  }
}

#
# outputModuleRegisterGroup
#   Output the register group associated with a module
#
# Params:
#   fh        -- file handle
#   module    -- module
#   regGroup  -- hash of used modules
#   addrWidth -- address width
#
sub outputModuleRegisterGroup {
  my ($fh, $module, $regGroup, $addrWidth) = @_;

  my $prefix = uc($module->prefix());
  my $grpName = uc($regGroup->name());

  my $instNewAddrWidth = log2ceil($regGroup->instSize() >> 2);
  my $instTagWidth = $addrWidth - $instNewAddrWidth;

  my $log2Instances = log2ceil($regGroup->instances);
  my $grpNewAddrWidth = $instNewAddrWidth + $log2Instances;
  my $grpTagWidth = $addrWidth - $grpNewAddrWidth;

  my $instOffset = $regGroup->offset() >> (2 + $instNewAddrWidth);
  my $grpOffset = $regGroup->offset() >> (2 + $grpNewAddrWidth);

  print $fh "//   Register group: $grpName\n";
  print $fh "//\n";
  print $fh "//   Address decompositions:\n";
  print $fh "//     - Inst:  Addresses of the *instances* within the module\n";
  if ($regGroup->offset() != 0) {
    print $fh "//     - Group: Addresses of the *group* within the module\n";
    print $fh "`define ${prefix}_${grpName}_GROUP_BLOCK_ADDR_WIDTH   $grpTagWidth\n";
    print $fh "`define ${prefix}_${grpName}_GROUP_REG_ADDR_WIDTH     $grpNewAddrWidth\n";
    print $fh "\n";
    print $fh "`define ${prefix}_${grpName}_GROUP_BLOCK_ADDR         ${grpTagWidth}'d${grpOffset}\n";
    print $fh "\n";
  }
  print $fh "`define ${prefix}_${grpName}_INST_BLOCK_ADDR_WIDTH    $instTagWidth\n";
  print $fh "`define ${prefix}_${grpName}_INST_REG_ADDR_WIDTH      $instNewAddrWidth\n";
  print $fh "\n";

  for (my $i = 0; $i < $regGroup->instances(); $i++) {
    print $fh "`define ${prefix}_${grpName}_${i}_INST_BLOCK_ADDR  ${instTagWidth}'d${i}\n";
  }
  print $fh "\n";

  my $regs = $regGroup->getSingleInstanceRegDump();
  outputModuleRegisters($fh, $module, $regs, $instNewAddrWidth, $grpName);
  print $fh "\n";
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
#   fh          -- file handle
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
// -------------------------------------
//   Bitmasks
// -------------------------------------

BITMASK_HEADER
  # Walk through the list of bitmask types and output the bitmasks
  my $widthLen = length('_WIDTH');
  my $posHiLen = length('_POS_HI');
  my $posLen = length('_POS');
  for my $type (@bitmaskTypes) {
    # Get the name
    my $typeName = $type->name();
    my $desc = $type->desc();
    my $file = $type->file();

    print $fh "// Type: $typeName\n";
    print $fh "// Description: $desc\n" if (defined($desc));
    print $fh "// File: $file\n";

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
    for my $bitmask (@{$type->bitmasks()}) {
      my $bitmaskName = uc($bitmask->name());
      my $len = length($bitmaskName);

      if ($bitmask->posLo() == $bitmask->posHi()) {
        my $pos = $bitmask->pos();
        my $pad = (' ') x ($maxStrLen - length($bitmaskName) - $posLen);
        print $fh "`define ${typeName}_${bitmaskName}_POS$pad   $pos\n";
      }
      else {
        my $posLo = $bitmask->posLo();
        my $posHi = $bitmask->posHi();
        my $width = $posHi - $posLo + 1;
        my $pad;

        $pad = (' ') x ($maxStrLen - length($bitmaskName) - $posHiLen);
        print $fh "`define ${typeName}_${bitmaskName}_POS_LO$pad   $posLo\n";
        print $fh "`define ${typeName}_${bitmaskName}_POS_HI$pad   $posHi\n";

        $pad = (' ') x ($maxStrLen - length($bitmaskName) - $widthLen);
        print $fh "`define ${typeName}_${bitmaskName}_WIDTH$pad   $width\n";
      }
    }

    print $fh "\n";
  }
  print $fh "\n\n";
}

1;

__END__
