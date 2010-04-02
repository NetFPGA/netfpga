#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: Expansion.pm 6035 2010-04-01 00:29:24Z grg $
#
# Register utils
#
#############################################################

package NF::RegSystem::Expansion;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw(
              expandConstants
              expandConst
              expandValue
              expandTypes
              expandSimpleType
              expandBitmasks
              expandCompoundType
              expandFields
              expandTableType
              expandBlockSize
              expandModules
              expandModule
            );

use bignum;
use Math::BigInt;
use Carp;
use Switch;
use NF::RegSystem qw($VALID_BLOCK_SIZES $NF2_MAX_MEM);

use strict;

#
# expandConstants
#   Expand the constants
#
# Params:
#   consts  -- reference to a hash of the constants
#
sub expandConstants {
  my $consts = shift;

  for my $const (values(%$consts)) {
    expandConst($const, $consts);
  }
}

#
# expandConst
#   Expand a single constant
#
# Params:
#   const   -- single constant to expand
#   consts  -- reference to a hash of the constants
#
# Return:
#   expanded version of constant
#
sub expandConst {
  my ($const, $consts) = @_;

  my $name = $const->name();
  my $value = $const->value();
  my $width = $const->width();

  my ($newValue, $wantHex) = expandValue($value, $consts, $name);
  my ($newWidth, $dummy) = expandValue($width, $consts, $name);

  # Mask the value according to the width
  my $mask = 2 ** $newWidth - 1;
  $newValue = $newValue & $mask;

  $const->value($newValue);
  $const->wantHex($wantHex);
  $const->width($newWidth);
}

#
# expandValue
#   Expand a value
#
# Params:
#   value   -- single constant to expand
#   consts  -- reference to a hash of the constants
#   name    -- name to use when reporting errors
#
# Return:
#   expanded version of value
#
my $stack = {};

sub expandValue {
  my ($value, $consts, $name) = @_;

  return ($value, 0) if (!defined($value));
  return ($value, 0) if ($value =~ /^\d+$/);
  return ($value, 0) if (ref($value) eq 'Math::BigInt');

  my @toks;
  my @needExpand;
  my $wantHex = 0;
  my $nToks = 0;

  # Parse the value
  PARSER: {
    $value =~ m/ \G( \d+\b             )/gcx && do {
      push @toks, $1;
      push @needExpand, 0;
      $nToks++;
      redo;
    };
    $value =~ m/ \G( 0x[[:xdigit:]]+\b )/gcx && do {
      $wantHex = 1;
      push @toks, Math::BigInt->new($1)->bstr();
      push @needExpand, 0;
      $nToks++;
      redo;
    };
    $value =~ m/ \G( \w+               )/gcx && do {
      push @toks, $1;
      push @needExpand, 1;
      $nToks++;
      redo;
    };
    $value =~ m/ \G( \s+               )/gcx && do {
      redo;
    };
    $value =~ m/ \G( [^\w\d\s]+        )/gcx && do {
      push @toks, $1;
      push @needExpand, 0;
      $nToks++;
      redo;
    };
  }

  # Expand any constants within the value
  for (my $i = 0; $i < scalar(@toks); $i++) {
    if ($needExpand[$i]) {
      # Attempt to expand the constant
      my $newConstName = $toks[$i];
      if (defined($stack->{$newConstName})) {
        croak "ERROR: Expansion of '$name' results in infinite recursion";
      }
      elsif (!defined($consts->{$newConstName})) {
        croak "ERROR: Expansion of '$name' references undefined constant '$newConstName'";
      }
      $stack->{$newConstName} = 1;
      my $newConst = $consts->{$newConstName};
      expandConst($newConst, $consts);
      $toks[$i] = $newConst->value();
      $wantHex |= $newConst->wantHex();
      delete($stack->{$newConstName});
    }
  }

  # Finally update the value
  my $ret;
  if ($nToks == 1) {
    $ret = $toks[0];
  }
  else {
    $ret = eval "use bignum; " . join(' ', @toks);
    # FIXME: Verify whether the eval succeeded
    if (ref($ret) eq 'Math::BigFloat') {
      $ret = $ret->as_number();
    }
  }
  return ($ret, $wantHex);
}

#
# expandTypes
#   Expand the types
#
# Params:
#   types   -- reference to a hash of the types
#   consts  -- reference to a hash of the constants
#
sub expandTypes {
  my ($types, $consts) = @_;

  for my $type (values(%$types)) {
    switch (ref($type)) {
      case "NF::RegSystem::SimpleType"   {expandSimpleType($type, $consts);}
      case "NF::RegSystem::CompoundType" {expandCompoundType($type, $types, $consts);}
      case "NF::RegSystem::TableType"    {expandTableType($type, $types, $consts);}
      else                          {croak "Unhandled Type: " . ref($type);}
    }
  }
}

#
# expandSimpleType
#   Expand a SimpleType object
#
# Params:
#   type    -- reference to type to expand
#   consts  -- reference to a hash of the constants
#
sub expandSimpleType {
  my ($type, $consts) = @_;

  my $name = $type->name();
  my $width = $type->width();

  $type->width(expandValue($width, $consts, $name));

  expandBitmasks($type->{bitmasks}, $consts, $name);
}

#
# expandBitmasks
#   Expand the bitmasks in a SimpleType object
#
# Params:
#   bitmask -- reference to the bitmasks
#   consts  -- reference to a hash of the constants
#   name    -- name of type
#
sub expandBitmasks {
  my ($bitmasks, $consts, $name) = @_;

  return if (!defined($bitmasks));

  for my $bitmask (@$bitmasks) {
    # FIXME: Better handling of bitmask name
    my $posLo = $bitmask->posLo();
    my $posHi = $bitmask->posHi();

    $bitmask->posLo(expandValue($posLo, $consts, $name));
    $bitmask->posHi(expandValue($posHi, $consts, $name));
  }
}

#
# expandCompoundType
#   Expand a CompoundType object
#
# Params:
#   type    -- reference to type to expand
#   types   -- reference to a hash of the types
#   consts  -- reference to a hash of the constants
#
sub expandCompoundType {
  my ($type, $types, $consts) = @_;
  my $name = $type->name();

  expandFields($type->{fields}, $types, $consts, $name);
}

#
# expandFields
#   Expand the fields in a CompoundType object
#
# Params:
#   fields  -- reference to the fields
#   types   -- reference to a hash of the types
#   consts  -- reference to a hash of the constants
#   name    -- name of type
#
sub expandFields {
  my ($fields, $types, $consts, $name) = @_;

  return if (!defined($fields));

  for my $field (@$fields) {
    # FIXME: Better handling of field name
    my $width = $field->width();
    my $type = $field->type();
    if (defined($width)) {
      $field->width(expandValue($width, $consts, $name));
    }
    if (defined($type)) {
      if (!defined($types->{$type})) {
        croak "ERROR: Cannot find type '$type' for compound type '$name'";
      }
      $field->type($types->{$type});
    }
  }
}

#
# expandTableType
#   Expand a TableType object
#
# Params:
#   type    -- reference to type to expand
#   types   -- reference to a hash of the types
#   consts  -- reference to a hash of the constants
#
sub expandTableType {
  my ($type, $types, $consts) = @_;

  my $name = $type->name();
  my $depth = $type->depth();
  my $entryWidth = $type->entryWidth();
  my $entryType = $type->entryType();

  $type->depth(expandValue($depth, $consts, $name));
  if (defined($entryWidth)) {
    $type->entryWidth(expandValue($entryWidth, $consts, $name));
  }
  if (defined($entryType)) {
    if (!defined($types->{$entryType})) {
      croak "ERROR: Cannot find type '$entryType' for table '$name'";
    }
    $type->entryType($types->{$entryType});
  }
}

#
# expandBlockSize
#   Expand the blocksize
#
# Params:
#   name      -- module name
#   location  -- module locaiton
#   blockSize -- block size
#
sub expandBlockSize {
  my ($name, $location, $blockSize) = @_;

  # Validate the location
  if (!exists($VALID_BLOCK_SIZES->{$location})) {
    croak "ERROR: invalid location '$location' specified in module '$name'";
  }

  # Verify and expand the blocksize
  if (! ($blockSize =~ /^(\d+)\s*([kKmM])?$/)) {
    croak "ERROR: cannot understand blocksize '$blockSize' specified in module '$name'";
  }
  if (defined($2)) {
    $blockSize = $1;
    if (lc($2) eq 'k') {
      $blockSize *= 1024;
    }
    elsif (lc($2) eq 'm') {
      $blockSize *= 1024 * 1024;
    }
  }

  # Verify that the block size is a power of 2 and is
  # allowed in the specified location
  if (defined($VALID_BLOCK_SIZES->{$location})) {
    my $valid = 0;
    for (my $i = 0; $i < scalar(@{$VALID_BLOCK_SIZES->{$location}}) && !$valid; $i++) {
      if ($blockSize == $VALID_BLOCK_SIZES->{$location}->[$i]) {
        $valid = 1;
      }
    }
    if (!$valid) {
      croak "ERROR: the blocksize '$blockSize' specified in module '$name' is invalid in the location '$location'";
    }
  }

  my $blockCheck = 1;
  my $valid = 0;
  while (!$valid && $blockCheck <= $NF2_MAX_MEM) {
    $valid = 1 if ($blockSize == $blockCheck);
    $blockCheck *= 2;
  }
  if (!$valid) {
    croak "ERROR: invalid blocksize '$blockSize' specified in module '$name'. The blocksize must be a power of 2";
  }

  return $blockSize;
}

#
# expandModules
#   Expand the modules
#
# Params:
#   modules -- reference to a hash of the used modules
#   consts  -- reference to a hash of the constants
#
sub expandModules {
  my ($modules, $consts) = @_;

  for my $module (values(%$modules)) {
    expandModule($module, $consts);
  }
}

#
# expandModules
#   Expand a single module
#
# Params:
#   module  -- single module to expand
#   consts  -- reference to a hash of the constants
#
# Return:
#   expanded version of module
#
sub expandModule {
  my ($module, $consts) = @_;

  my $name = $module->name();
  my $prefBase = $module->prefBase();
  my $forceBase = $module->forceBase();

  $module->prefBase(expandValue($prefBase, $consts, $name));
  $module->forceBase(expandValue($forceBase, $consts, $name));
}


1;

__END__
