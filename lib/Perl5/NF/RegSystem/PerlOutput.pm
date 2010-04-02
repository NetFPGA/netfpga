#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: PerlOutput.pm 6035 2010-04-01 00:29:24Z grg $
#
# Perl file output
#
#############################################################

package NF::RegSystem::PerlOutput;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw(
                genPerlOutput
            );

use Carp;
use NF::RegSystem::File;
use NF::Utils;
use NF::RegSystem qw($PROJECTS_DIR $LIB_DIR);
use POSIX;
use Math::BigInt;
use strict;

# Path locations
my $LIB_PERL = $LIB_DIR . '/Perl5';
my $PERL_PREFIX = 'reg_defines';

my $buf;
my @exports;

#
# genPerlOutput
#   Generate the Perl defines file corresponding to the project
#
# Params:
#   project     -- Project object
#   layout      -- Layout object
#   usedModules -- Hash of used modules
#   constsHash  -- Hash of constants
#   constsArr   -- Array of constant names?
#   typesHash   -- Hash of types
#   typesArr    -- Array of type names?
sub genPerlOutput {
  my ($project, $layout, $usedModules,
    $constsHash, $constsArr, $typesHash, $typesArr) = @_;

  my $projDir = $project->dir();
  my $memalloc = $layout->getMemAlloc();
  my $verilogOnlyMemalloc = $layout->getVerilogOnlyMemAlloc();

  # Output the version
  outputVersion($project, $layout);

  # Output the constants
  outputConstants($constsArr);

  # Output the modules
  outputMemAlloc($memalloc, $verilogOnlyMemalloc);

  # Output the registers
  outputRegisters($memalloc);

  # Output the bitmasks associated with the types
  outputBitmasks($typesArr);

  # Get a file handle
  my $moduleName = "${PERL_PREFIX}_${projDir}";
  $moduleName =~ s/\./_/g;
  my $fh = openRegFile("$PROJECTS_DIR/$projDir/$LIB_PERL/${moduleName}.pm");

  outputHeader($fh, $moduleName, $project);
  outputBody($fh);
  outputFooter($fh);

  # Finally close the file
  closeRegFile($fh);
}

#
# outputVersion
#   Output version information
#
# Params:
#   project   -- project object
#   layout    -- layout object
#
sub outputVersion {
  my ($project, $layout) = @_;

  my $dir = $project->dir();
  my $name = $project->name();
  my $desc = $project->desc();
  my $verMajor = $project->verMajor();
  my $verMinor = $project->verMinor();
  my $verRevision = $project->verRevision();
  my $devId = $project->devId();

  $buf .= <<VERSION_TITLE;
# -------------------------------------
#   Version Information
# -------------------------------------
VERSION_TITLE

  my $type = ref($layout);
  if ($type eq 'NF::RegSystem::CPCILayout') {
    my $verStr = sprintf('%06x', $verMajor);
    my $revStr = sprintf('%02x', $verMinor);

    addExport("CPCI_VERSION_ID");
    addExport("CPCI_REVISION_ID");

    $buf .= <<VERSION_CPCI;
# CPCI version number (major number)
sub CPCI_VERSION_ID ()      { 0x$verStr; }

# CPCI revision number (minor number)
sub CPCI_REVISION_ID ()     { 0x$revStr; }


VERSION_CPCI
  }
  elsif ($type eq 'NF::RegSystem::ReferenceLayout') {
    addExport("DEVICE_ID");
    addExport("DEVICE_MAJOR");
    addExport("DEVICE_MINOR");
    addExport("DEVICE_REVISION");
    addExport("DEVICE_PROJ_DIR");
    addExport("DEVICE_PROJ_NAME");
    addExport("DEVICE_PROJ_DESC");

    $buf .= <<VERSION_REFERENCE;
sub DEVICE_ID ()        { $devId; }
sub DEVICE_MAJOR ()     { $verMajor; }
sub DEVICE_MINOR ()     { $verMinor; }
sub DEVICE_REVISION ()  { $verRevision; }
sub DEVICE_PROJ_DIR ()  { "$dir"; }
sub DEVICE_PROJ_NAME () { "$name"; }
sub DEVICE_PROJ_DESC () { "$desc"; }


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
  my ($constants) = @_;

  return if (length(@$constants) == 0);

  $buf .= <<CONSTANTS_HEADER;
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
      $buf .= "\n" if ($currFile ne '');
      $buf .= "# ===== File: $file =====\n\n";
      $currFile = $file;
    }

    my $pad = (' ') x ($maxStrLen - length($name));

    if (defined($desc) && $desc ne '') {
      $buf .= "# $desc\n";
    }

    if ($wantHex) {
      my $hexWidth = ceil($width / 4);
      my $bigVal = Math::BigInt->new($value);
      my $hexStr = substr($bigVal->as_hex(), 2);
      $hexStr = (('0') x ($hexWidth - length($hexStr))) . $hexStr;

      # Print the constant split up over multiple 32-bit values if it's
      # wider than 32 bits
      if ($width > 32) {
        outputWideConstant($name, $value, $width, $pad);
      }
      else {
        addExport("$name");
        $buf .= sprintf("sub $name () $pad  { 0x%0${hexWidth}s;}\n", $hexStr);
      }

    }
    else {
      addExport("$name");
      $buf .= sprintf("sub $name () $pad { $value;}\n");
    }
    $buf .= "\n";
  }
  $buf .= "\n\n";

}

#
# outputWideConstant
#   Split a wide constant and output it as multiple small constants
#
# Params:
#
sub outputWideConstant {
  my ($name, $value, $width, $pad) = @_;

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
    addExport("${name}_${suffix}");
    $buf .= sprintf("sub ${name}_${suffix} () $pad { 0x%0${hexWidth}s;}\n", $hexStr);
  }
}

#
# outputMemAlloc
#   Output the module allocations
#
# Params:
#   memalloc    -- memory allocations
#   voMemalloc  -- Verilog only memory allocations
#
sub outputMemAlloc {
  my ($memalloc, $voMemalloc) = @_;

  return if (scalar(@$memalloc) == 0 && scalar(@$voMemalloc) == 0);

  $buf .= <<MEMALLOC_HEADER;
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
  $buf .= "# Module tags\n";
  for my $memallocObj (@localMemalloc) {
    my $prefix = uc($memallocObj->name());
    my $start = $memallocObj->start();

    my $pad = (' ') x ($maxMemAllocLen - length($prefix));

    addExport("${prefix}_BASE_ADDR");
    $buf .= sprintf("sub ${prefix}_BASE_ADDR () $pad  { 0x%07x; }\n", $start);
  }
  $buf .= "\n";

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
	addExport("${ucPrefix}_OFFSET");
        $buf .= sprintf("sub ${ucPrefix}_OFFSET () $pad  { 0x%07x; }\n", $offset);
      }
    }
  }
  $buf .= "\n\n";
}

#
# outputRegisters
#   Output the registers associated with each module
#
# Params:
#   memalloc  -- memory allocation
#
sub outputRegisters {
  my ($memalloc) = @_;

  return if (length(@$memalloc) == 0);

  $buf .= <<REGISTER_HEADER;
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

    $buf .= "# Name: $name ($prefix)\n";
    $buf .= "# Description: $desc\n" if (defined($desc));
    $buf .= "# File: $file\n" if (defined($file));

    my $regs = $module->getRegDump();
    outputModuleRegisters($prefix, $start, $module, $regs);
    $buf .= "\n";

    if ($module->hasRegisterGroup()) {
      my $regGroup = $module->getRegGroup();
      outputModuleRegisterGroupSummary($prefix, $start, $module, $regGroup);
    }
  }
  $buf .= "\n\n";
}

#
# outputModuleRegisters
#   Output the registers associated with a module (non register group)
#
# Params:
#   prefix    -- prefix
#   start     -- start address
#   module    -- module
#   regs      -- register array dump
#
sub outputModuleRegisters {
  my ($prefix, $start, $module, $regs) = @_;

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

    addExport("${prefix}_${regName}_REG");
    $buf .= sprintf("sub ${prefix}_${regName}_REG () $pad  { 0x%07x;}\n", $addr + $start);
  }
}

#
# outputModuleRegisterGroupSummary
#   Output the register group summary associated with a module
#
# Params:
#   prefix    -- prefix
#   start     -- start address
#   module    -- module
#   regGroup  -- hash of used modules
#
sub outputModuleRegisterGroupSummary {
  my ($prefix, $start, $module, $regGroup) = @_;

  my $grpName = uc($regGroup->name());
  my $instSize = $regGroup->instSize();
  my $offset = $regGroup->offset();

  addExport("${prefix}_${grpName}_GROUP_BASE_ADDR");
  addExport("${prefix}_${grpName}_GROUP_INST_OFFSET");

  $buf .= sprintf("sub ${prefix}_${grpName}_GROUP_BASE_ADDR ()  { 0x%07x; }\n", $start + $offset);
  $buf .= sprintf("sub ${prefix}_${grpName}_GROUP_INST_OFFSET() { 0x%07x; }\n", $instSize);
  $buf .= "\n";
}

#
# addExport
#   Add a string to the list of exports to generate
#
# Params:
#   var       -- variable to export
#
sub addExport {
  my ($var) = @_;

  push @exports, $var;
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
#############################################################
#
# Perl register defines
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

package $modName;

use Exporter;

\@ISA = ('Exporter');

\@EXPORT = qw(
REGISTER_HEADER_2

  print $fh join("\n", map { "                " . $_} @exports) . "\n";

  print $fh <<REGISTER_HEADER_3;
            );


REGISTER_HEADER_3
}

#
# outputBody
#   Output the body of the module
#
# Params:
#   fh        -- file handle
#
sub outputBody {
  my $fh = shift;

  # Output the content to the file
  print $fh $buf;
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


1;

__END__
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

1;

#
# outputBitmasks
#   Output the bitmasks associated with types
#
# Params:
#   types       -- array of all types
#
sub outputBitmasks {
  my ($types) = @_;

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

  $buf .= <<BITMASK_HEADER;
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

    $buf .= "# Type: $typeName\n";
    $buf .= "# Description: $desc\n" if (defined($desc));
    $buf .= "# File: $file\n";
    $buf .= "\n";

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
    $buf .= "# Part 1: bit positions\n";
    my $width = $type->width();
    for my $bitmask (@{$type->bitmasks()}) {
      my $bitmaskName = uc($bitmask->name());
      my $len = length($bitmaskName);

      if ($bitmask->posLo() == $bitmask->posHi()) {
        my $pos = $bitmask->pos();
        my $pad = (' ') x ($maxStrLen - length($bitmaskName) - $posLen);
        addExport("${typeName}_${bitmaskName}_POS$pad");
        $buf .= "sub ${typeName}_${bitmaskName}_POS$pad ()   { $pos; }\n";
      }
      else {
        my $posLo = $bitmask->posLo();
        my $posHi = $bitmask->posHi();
        my $width = $posHi - $posLo + 1;
        my $pad;

        $pad = (' ') x ($maxStrLen - length($bitmaskName) - $posHiLen);
        addExport("${typeName}_${bitmaskName}_POS_LO");
        addExport("${typeName}_${bitmaskName}_POS_HI");
        $buf .= "sub ${typeName}_${bitmaskName}_POS_LO$pad ()   { $posLo; }\n";
        $buf .= "sub ${typeName}_${bitmaskName}_POS_HI$pad ()   { $posHi; }\n";

        $pad = (' ') x ($maxStrLen - length($bitmaskName) - $widthLen);
        addExport("${typeName}_${bitmaskName}_WIDTH");
        $buf .= "sub ${typeName}_${bitmaskName}_WIDTH$pad ()   { $width; }\n";
      }
    }
    $buf .= "\n";

    # Part 2: Masks/values
    $buf .= "# Part 2: masks/values\n";
    my $nibbles = ceil($width / 4);
    for my $bitmask (@{$type->bitmasks()}) {
      my $bitmaskName = uc($bitmask->name());
      my $len = length($bitmaskName);

      if ($bitmask->posLo() == $bitmask->posHi()) {
        my $pos = $bitmask->pos();
        my $pad = (' ') x ($maxStrLen - length($bitmaskName));
        my $mask = 1 << $pos;
        addExport("${typeName}_${bitmaskName}$pad");
        $buf .= sprintf "sub ${typeName}_${bitmaskName}$pad ()   { 0x%0${nibbles}x; }\n", $mask;
      }
      else {
        my $posLo = $bitmask->posLo();
        my $posHi = $bitmask->posHi();
        my $width = $posHi - $posLo + 1;
        my $pad;

        my $mask = (2 ** ($posHi + 1)) - 1;
        $mask ^= (2 ** $posLo) - 1;

        $pad = (' ') x ($maxStrLen - length($bitmaskName) - $maskLen);
        addExport("${typeName}_${bitmaskName}_MASK");
        $buf .= sprintf "sub ${typeName}_${bitmaskName}_MASK$pad ()   { 0x%0${nibbles}x; }\n", $mask;
      }
    }
    $buf .= "\n";
  }
  $buf .= "\n\n";
}

__END__
