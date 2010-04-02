#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: CPCILayout.pm 6035 2010-04-01 00:29:24Z grg $
#
#############################################################

####################################################################################
# CPCI memory layout
####################################################################################
package NF::RegSystem::CPCILayout;

use Carp;
use Switch;
use NF::RegSystem::MemAlloc;
use NF::Utils;
use strict;
our $AUTOLOAD;

use constant {
  UDP                 => 'udp',
  CORE                => 'core',
  CPCI                => 'cpci',
  MAX_MEM             => 2 ** 27,
  CPCI_SIZE           => 2 ** 22,

  CORE_16M_TAG_WIDTH    => 1,
  CORE_16M_ADDR_WIDTH   => 22,
  CORE_256K_TAG_WIDTH   => 4,
  CORE_256K_ADDR_WIDTH  => 16,
  SRAM_TAG              => 1,
  SRAM_TAG_WIDTH        => 1,
  SRAM_ADDR_WIDTH       => 22,
  DRAM_TAG              => 1,
  DRAM_TAG_WIDTH        => 1,
  DRAM_ADDR_WIDTH       => 24,
};

#
# Create a new layout
#
# Params:
#
sub new {
  my ($class) = @_;

  my $self = {
    modules_by_group  => {
      "cpci" => {},
    },
    all_modules       => {},
    memalloc          => [],
    verilogOnlyMemalloc => [],
  };

  bless $self, $class;

  return $self;
}

#
# Add a module
#
# Params:
#   where   -- where to add the module
#   module  -- module to add
#   count   -- number of instances
#   base    -- base address
#
sub addModule {
  my ($self, $where, $module, $count, $base) = @_;

  $count = 1 if (!defined($count));

  # Get the name
  my $name = $module->name();

  # Verify that the location is valid
  if (!defined($self->{modules_by_group}->{$where})) {
    croak "Invalid location '$where' within layout";
  }

  my $modules = $self->{modules_by_group}->{$where};

  # Verify that the locations match
  if ($where eq CPCI) {
    if ($module->{location} ne CPCI) {
      croak "Location mismatch between layout and module '$name'. Layout specifies '$where' but module specifies '".$module->{location}."'";
    }
  }
  else {
    croak "Invalid location '$where' speicified";
  }

  # Verify that if a base is specified there is either no forceBase
  # in the module or that they match
  if (defined($base)) {
    if ($base != 0) {
      croak "ERROR: Base address '$base' specified in project for module '$name' must be zero for the CPCI";
    }

    my $forceBase = $module->forceBase();
    if (defined($forceBase) && $forceBase != $base) {
      croak "ERROR: Base address '$base' specified in project for module '$name' does not match the force base '$forceBase' specified in the module";
    }
  }

  # Set the tag width and address width
  setTagAddrWidths($module);

  # Add the module to the list of all modules
  if (!defined($self->{all_modules}->{$name})) {
    $self->{all_modules}->{$name} = {
      module  => $module,
      count   => $count,
    }
  }
  else {
    $self->{all_modules}->{$name}->{count} += $count;
  }

  # Generate the necessary base addresses
  my $bases = undef;
  if (defined($base)) {
    my $blockSize = $module->{blockSize};
    my $offset = 0;
    @$bases = (map { $_ += $offset ; $offset += $blockSize; $_; } (($base) x $count));

    if (defined($modules->{$name})) {
      if (!defined($modules->{$name}->{base})) {
        croak "ERROR: Base addresses specified for some instances of '$name'. Base addresses must be specified for none or all instances of a particular module.";
      }
    }
  }

  # Add the module to the group
  if (defined($modules->{$name})) {
    $modules->{$name}->{count} += $count;
    push @{$modules->{$name}->{base}}, @$bases;
  } else {
    $modules->{$name} = {
      module  => $module,
      count   => $count,
      base    => $bases,
      alloced => 0,
    }
  }
}

#
# Get a list of all modules
#
sub allModules {
  my $self = shift;

  return keys(%{$self->{all_modules}});
}

#
# Perform the allocation of memory to modules
#
sub doAlloc {
  my $self = shift;

  my $memalloc = [];
  my $memallocObj;

  $self->doAllocForGroup($self->{modules_by_group}->{'cpci'},
    $memalloc, 0, CPCI_SIZE);

  $memalloc = sortAndRename($memalloc, $self->{all_modules});
  generateTags($memalloc);

  $self->{memalloc} = $memalloc;
}

#
# Perform the allocation of memory to modules
#
sub doAllocForGroup {
  my ($self, $group, $memalloc, $start, $size) = @_;

  my @freelist = ();
  push @freelist, {
    start => $start,
    len   => $size,
  };
  # Walk through and find the force base/preferred base instances
  my @forceBase;
  my @prefBase;
  my @base;
  for my $instance (values(%$group)) {
    my $forceBase = $instance->{module}->forceBase();
    my $prefBase = $instance->{module}->prefBase();
    my $base = $instance->{base};
    if (defined($forceBase)) {
      push @forceBase, $instance;
    }
    elsif (defined($base)) {
      push @base, $instance;
    }
    elsif (defined($prefBase)) {
      push @prefBase, $instance;
    }
  }

  # First, allocate memory for the forceBase modules
  for my $instance (@forceBase) {
    my $blockSize = $instance->{module}->blockSize();
    my $name = $instance->{module}->prefix();
    my $forceBase = $instance->{module}->forceBase();
    for (my $instNum = 0; $instNum < $instance->{count}; $instNum++) {
      my $addr = findFreeBlock(\@freelist, $blockSize, $forceBase);
      if (defined($addr)) {
        my $memallocObj = NF::RegSystem::MemAlloc->new(
          name => $name,
          module => $instance->{module},
          start => $addr,
          len => $blockSize,
        );
        push @$memalloc, $memallocObj;
        $instance->{alloced}++;
        $forceBase += $blockSize;
      }
      else {
        croak "ERROR: Unable to use forced base address for '$name'";
      }
    }
  }

  # Process the base modules
  for my $instance (@base) {
    my $blockSize = $instance->{module}->blockSize();
    my $name = $instance->{module}->prefix();
    for (my $instNum = 0; $instNum < $instance->{count}; $instNum++) {
      my $base = $instance->{base}->[$instNum];
      my $addr = findFreeBlock(\@freelist, $blockSize, $base);
      if (defined($addr)) {
        my $memallocObj = NF::RegSystem::MemAlloc->new(
          name => $name,
          module => $instance->{module},
          start => $addr,
          len => $blockSize,
        );
        push @$memalloc, $memallocObj;
        $instance->{alloced}++;
      }
    }
  }

  # Then, allocate memory for the preferred base modules
  for my $instance (@prefBase) {
    my $blockSize = $instance->{module}->blockSize();
    my $name = $instance->{module}->prefix();
    my $prefBase = $instance->{module}->prefBase();
    for (my $instNum = 0; $instNum < $instance->{count}; $instNum++) {
      my $addr = findFreeBlock(\@freelist, $blockSize, $prefBase);
      if (defined($addr)) {
        my $memallocObj = NF::RegSystem::MemAlloc->new(
          name => $name,
          module => $instance->{module},
          start => $addr,
          len => $blockSize,
        );
        push @$memalloc, $memallocObj;
        $instance->{alloced}++;
        $prefBase += $blockSize;
      }
    }
  }

  # Finally, allocate whatever is left
  for my $instance (values(%$group)) {
    my $blockSize = $instance->{module}->blockSize();
    my $name = $instance->{module}->prefix();

    # Checked whether we've already allocated the correct number
    next if ($instance->{alloced} == $instance->{count});

    for (my $instNum = $instance->{alloced}; $instNum < $instance->{count}; $instNum++) {
      my $addr = findFreeBlock(\@freelist, $blockSize, undef);
      if (defined($addr)) {
        my $memallocObj = NF::RegSystem::MemAlloc->new(
          name => $name,
          module => $instance->{module},
          start => $addr,
          len => $blockSize,
        );
        push @$memalloc, $memallocObj;
        $instance->{alloced}++;
      }
      else {
        croak "ERROR: unable to allocate memory for '$name'";
      }
    }
  }
}

#
# findFreeBlock
#   Attempt to find a free block of a particular size at a particular location
#
# Params:
#   freelist  -- reference to the free list
#   blockSize -- desired block size
#   addr      -- desired address of block
#                if this is undefined then it will place the block wherever it can
#
# Return:
#   address of block or undef if no block could be found
#
# Side effects:
#   freelist will be updated to reflect available free blocks
#
sub findFreeBlock {
  my ($freelist, $blockSize, $addr) = @_;

  my $done = 0;
  my $retAddr = undef;

  # Walk through the available free blocks searching for sufficient free space
  for (my $i = 0; $i < scalar(@$freelist) && !$done; $i++) {
    my $free = $freelist->[$i];

    # Extract the start/len from the free block for ease of processing
    my $start = $free->{start};
    my $len = $free->{len};

    # We always want modules to be aligned according to their blocksize
    my $isOffset = 0;
    my $mask = $blockSize - 1;
    if (($start & $mask) != 0) {
      my $offset = $blockSize - ($start & $mask);
      $start += $offset;
      $len -= $offset;
      $isOffset = 1;
    }

    # Processing when we have a preferred address
    if (defined($addr)) {
      if ($start <= $addr && $start + $len > $addr) {
        $isOffset |= ($addr != $start);
        $len -= $addr - $start;
        $start = $addr;
      }
      else {
        if ($start + $len > $addr) {
          $done = 1;
        }
        next;
      }
    }

    # If we make it to here we just need to make sure there is space in the desired block
    if ($len >= $blockSize) {
      $retAddr = $start;
      $done = 1;

      # Update the freelist
      if ($free->{len} == $blockSize) {
        splice(@$freelist, $i, 1);
      }
      else {
        # If we're taking data from the beginning of the free
        # block then there's no need to split the block -- just adjust
        # it's start and length as appropriate
        if (!$isOffset) {
          $free->{start} += $blockSize;
          $free->{len} -= $blockSize;
        }
        # If we are taking data not from the beginning of the block
        # then we may end up with two free blocks -- one before the
        # chunk and one after
        else {
          splice(@$freelist, $i, 1);
          my $freeBefore = {
            start => $free->{start},
            len   => $start - $free->{start},
          };
          splice(@$freelist, $i, 0, $freeBefore);
          if ($freeBefore->{len} + $blockSize != $free->{len}) {
            my $freeAfter = {
              start => $start + $blockSize,
              len   => $free->{len} - $freeBefore->{len} - $blockSize,
            };
            splice(@$freelist, $i + 1, 0, $freeAfter);
          }
        }
      }
    }
  }

  return $retAddr;
}

#
# sortAndRename
#   Sort the modules by address and rename them based on their instance number
#
# Params:
#   memalloc  -- array reference of memory allocation
#
# Return:
#   Sorted version of memalloc array. Renames the block name
#   based upon the instance number.
#
sub sortAndRename {
  my ($memalloc, $allModules) = @_;

  my %doneModuleCounts;

  # Walk through the memory allocation and identify all modules
  for my $block (@$memalloc) {
    $doneModuleCounts{$block->module()->name()} = 0;
  }

  # Get the addresses as hex strings and update the names and
  # set the tag/addr widths
  my %memalloc_hash;
  for my $block (@$memalloc) {
    my $addr = sprintf("0x%07x", $block->start());

    # Push the block into an array inside the hash.
    #
    # This allows overlapping block addresses -- currently only used to define
    # a UDP block that overlaps with the UDP modules.
    if (!defined($memalloc_hash{$addr})) {
      $memalloc_hash{$addr} = [$block];
    }
    else {
      push @{$memalloc_hash{$addr}}, $block;
    }

    my $name = $block->name();
    my $moduleName = $block->module()->name();
    if (defined($allModules->{$moduleName})) {
      if ($allModules->{$moduleName}->{count} > 1) {
        $name .= "_" . $doneModuleCounts{$moduleName}++;
      }
    }
    $block->name($name);
  }

  # Produce the sorted array
  my $memalloc_sorted = ();
  for my $loc (sort(keys(%memalloc_hash))) {
    my $blocks = $memalloc_hash{$loc};
    for my $block (@$blocks) {
      push @$memalloc_sorted, $block;
    }
  }

  return $memalloc_sorted;
}

#
# generateTags
#   Generate the tags (and set the tag/addr width) for the
#   memory allocation blocks
#
# Params:
#   memalloc  -- array reference of memory allocation
#
sub generateTags {
  my ($memalloc) = @_;

  # Walk through the array and assign the tags
  for my $memallocObj (@$memalloc) {
    my $start = $memallocObj->start();
    my $tagWidth = $memallocObj->{module}->tagWidth();
    my $addrWidth = $memallocObj->{module}->addrWidth();

    my $tag = $start >> (2 + $addrWidth);
    $tag &= (2 ** $tagWidth - 1);

    $memallocObj->tag($tag);
  }
}

#
# setTagAddrWidths
#   Set the tag and address widths for a module based on the location
#
# Params:
#   module  -- module to set the tag/addr width for
#
sub setTagAddrWidths {
  my ($module) = @_;

  return if (defined($module->tagWidth()));

  # Identify the module location
  switch ($module->location()) {
    case 'cpci'      {
      my $addrWidth = log2($module->blockSize()) - 2;
      my $tagWidth = log2(CPCI_SIZE) - 2 - $addrWidth;

      $module->tagWidth($tagWidth);
      $module->addrWidth($addrWidth);
    }
  }
}

#
# Get a list of all modules
#
sub getMemAlloc {
  my $self = shift;

  return $self->{memalloc};
}

#
# Get a list of all modules
#
sub getVerilogOnlyMemAlloc {
  my $self = shift;

  return [];
}

#
# Autoload method to access fields
# (see perltoot for more information)
#
sub AUTOLOAD {
  my $self = shift;
  my $type = ref($self)
    or croak "$self is not an object";

  my $name = $AUTOLOAD;
  $name =~ s/.*://;   # strip fully-qualified portion

  unless (exists $self->{_permitted}->{$name} ) {
    croak "Can't access `$name' field in class $type";
  }

  if (@_) {
    return $self->{$name} = shift;
  } else {
    return $self->{$name};
  }
}

#
# Destroy method
#
sub DESTROY {}


1;

__END__
