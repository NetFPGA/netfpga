#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: XMLProcess.pm 6040 2010-04-01 05:58:00Z grg $
#
# XML file processing functions
#
#############################################################

package NF::RegSystem::XMLProcess;

use Exporter;

@ISA = ('Exporter');

@EXPORT = qw(
              processXMLProject
              getModulesXMLProject
            );

use bignum;
use Math::BigInt;
use XML::Simple;
use File::Basename;
use Carp;
use Switch;
use NF::Base;
use NF::Utils;
use NF::RegSystem qw($_NF_ROOT $GLOBAL_CONF_DIR $GLOBAL $PROJECTS_DIR
                      $PROJECT_XML_DIR $PROJECT_XML $LIB_VERILOG
                      $MODULE_XML_DIR);
use NF::RegSystem::Expansion;
use NF::RegSystem::Module;
use NF::RegSystem::Constant;
use NF::RegSystem::SimpleType;
use NF::RegSystem::CompoundType;
use NF::RegSystem::TableType;
use NF::RegSystem::BitmaskType;
use NF::RegSystem::Field;
use NF::RegSystem::Register;
use NF::RegSystem::RegisterGroup;
use NF::RegSystem::ReferenceLayout;
use NF::RegSystem::CPCILayout;
use NF::RegSystem::File;
use NF::RegSystem::Project;

use strict;

# XML TAGS
my $TAG_USE_MODULES  = 'nf:use_modules';
my $TAG_CONSTANTS  = 'nf:constants';
my $TAG_CONSTANT  = 'nf:constant';
my $TAG_TYPES  = 'nf:types';
my $TAG_TYPE  = 'nf:type';
my $TAG_XSI_TYPE  = 'xsi:type';
my $TAG_LAYOUT  = 'layout';
my $TAG_NAME  = 'nf:name';
my $TAG_VALUE  = 'nf:value';
my $TAG_DESCRIPTION  = 'nf:description';
my $TAG_WIDTH  = 'nf:width';
my $TAG_BITMASK  = 'nf:bitmask';
my $TAG_POS  = 'nf:pos';
my $TAG_POS_LO  = 'nf:pos_lo';
my $TAG_POS_HI  = 'nf:pos_hi';
my $TAG_FIELD  = 'nf:field';
my $TAG_PREFIX  = 'nf:prefix';
my $TAG_LOC  = 'nf:location';
my $TAG_BLOCKSIZE  = 'nf:blocksize';
my $TAG_PREF_BASE  = 'nf:preferred_base';
my $TAG_FORCE_BASE  = 'nf:force_base';
my $TAG_MEMALLOC  = 'nf:memalloc';
my $TAG_GROUP  = 'nf:group';
my $TAG_INSTANCE  = 'nf:instance';
my $TAG_ENTRY_TYPE  = 'nf:entry_type';
my $TAG_DEPTH  = 'nf:depth';
my $TAG_LOCATION  = 'nf:location';
my $TAG_COUNT  = 'count';
my $TAG_BASE  = 'base';
my $TAG_REGISTERS  = 'nf:registers';
my $TAG_REGISTER  = 'nf:register';
my $TAG_REGISTER_GROUP  = 'nf:register_group';
my $TAG_INSTANCES  = 'nf:instances';
my $TAG_INSTANCE_SIZE  = 'nf:instance_size';
my $TAG_ADDR  = 'nf:addr';
my $TAG_USE_SHARED  = 'nf:use_shared';
my $TAG_VERSION_MAJOR  = 'nf:version_major';
my $TAG_VERSION_MINOR  = 'nf:version_minor';
my $TAG_VERSION_REVISION  = 'nf:version_revision';
my $TAG_DEVICE_ID  = 'nf:dev_id';

# Types
my $TYPE_SIMPLE = "nf:SimpleType";
my $TYPE_COMPOUND = "nf:CompoundType";
my $TYPE_TABLE = "nf:TableType";

# Memory layouts
my $MEMLAYOUT_REF = "reference";
my $MEMLAYOUT_CPCI = "cpci";

# Root elements
my $ROOT_GLOBAL = "nf:global";
my $ROOT_PROJECT = "nf:project";
my $ROOT_MODULE = "nf:module";
my $ROOT_SHARED = "nf:shared";
my @ROOT_ELEMENTS = ($ROOT_GLOBAL, $ROOT_PROJECT, $ROOT_MODULE, $ROOT_SHARED);

# Key to indicate path
my $PATH_KEY = "_PATH";

# Prefix to add to local modules
my $LOCAL_PREFIX = "local";

use constant {
  GLOBAL  => 1,
  LOCAL   => 0,
};

# Maximum version number
use constant VERSION_MAX => 255;

# Variable that determines whether XML files are printed
my $quiet = 0;

# Locations and valid block sizes
#
# Note: undef means that there are no restrictions
my $validBlockSizes = {
  'core'      => [ 256 * 1024 ],
  'udp'       => undef,
};


###############################################################################

#
# processXMLProject
#   Load a project from XML
#
# Params:
#   $projectName -- name of project
#
# Returns:
#   ($project, $layout, $modulePaths, $usedModules, $constsHash, $constsArr, $typesHash, $typesArr)
#
#   project     -- Project object
#   layout      -- Layout object
#   modulePaths -- reference to array of used library module paths
#   usedModules -- reference to array of used modules
#   constsHash  -- reference to hash of constants (keyed on const abbrev)
#   constsArr   -- reference to array of constants
#   typesHash   -- reference to hash of typeants (keyed on type abbrev)
#   typesArr    -- reference to array of typeants
#
sub processXMLProject {
  my $projectName = shift;

  # Read in the global XML file
  my $globalConfigs = loadGlobalConfigs();

  # Read the project XML file
  my $projXML = loadProject($projectName);

  # Verify that the necessary information (name etc) is specified in the project
  verifyProjectInfo($projXML);
  printProjectInfo($projectName, $projXML);

  # Load the modules
  my $modulePaths = getAllModules($projXML);
  my $modulesXML = {};
  my $sharedXML = {};
  loadModules($modulePaths, $modulesXML, $sharedXML);
  loadLocalModules($projectName, $modulesXML, $sharedXML);

  # Get the project object and print the summary
  my $projObj = extractProject($projectName, $projXML);

  # Construct module objects
  $modulesXML = extractModulePrefixes($modulesXML);
  my ($modules, $sharedList) = moduleObjectsFromXML($modulesXML);

  # Get the list of used modules
  my $usedModules = getUsedModules($projXML, $modules);

  # Get the list of used shared XML
  my $usedShared = getUsedShared($projectName, $projXML, $usedModules, $sharedXML, $sharedList);

  # Extract the constants and types
  #
  # The constants/types are processed in the following order:
  #  1. globals
  #  2. module specific
  #  3. project
  # The processing is done in this order so that projects override everything and
  # so that modules can override globals only.
  #
  # Maintain the hash (keyed on the constant/type name) and an array ordered by
  # the order that they are processed. This is to enable final output in the same
  # order as the input.
  my $constsHash = {};
  my $typesHash = {};
  my $constsArr = [];
  my $typesArr = [];

  # Process the constants and types
  processConstants($constsHash, $constsArr, $globalConfigs->{'global'}, GLOBAL);
  processTypes($typesHash, $typesArr, $globalConfigs->{'global'}, GLOBAL);
  for my $name (keys %$globalConfigs) {
    next if $name eq 'global';
    processConstants($constsHash, $constsArr, $globalConfigs->{$name}, GLOBAL);
    processTypes($typesHash, $typesArr, $globalConfigs->{$name}, GLOBAL);
  }
  # Process the constants/types from the modules
  for my $name (keys(%$usedModules)) {
    processConstants($constsHash, $constsArr, $modulesXML->{$name}, LOCAL);
    processTypes($typesHash, $typesArr, $modulesXML->{$name}, LOCAL);
  }

  # Process the constants/types from the shared
  for my $name (keys(%$usedShared)) {
    processConstants($constsHash, $constsArr, $usedShared->{$name}, LOCAL);
    processTypes($typesHash, $typesArr, $usedShared->{$name}, LOCAL);
  }

  processConstants($constsHash, $constsArr, $projXML, GLOBAL);
  processTypes($typesHash, $typesArr, $projXML, GLOBAL);

  # Replace the constant/type names with their actual values
  replaceNamesWithObjects($constsArr, $constsHash);
  replaceNamesWithObjects($typesArr, $typesHash);

  # Expand the constants
  expandConstants($constsHash);
  expandTypes($typesHash, $constsHash);
  expandModules($usedModules, $constsHash);

  # Process the registers in each module
  for my $name (keys(%$usedModules)) {
    addRegistersToModule($usedModules->{$name}, $modulesXML->{$name}, $constsHash, $typesHash);
  }

  # Verify that the registers fit in each module
  verifyModuleSizes($modules);

  # Create a layout object
  # FIXME: Need to handle previous allocations (possibly -- revisit this later)
  my $layout = extractLayout($projXML, $modules, $constsHash);

  return ($projObj, $layout, $modulePaths, $usedModules, $constsHash, $constsArr, $typesHash, $typesArr);
}

#
# getModulesXMLProject
#   Get a list of the modules from an XML project
#
# Params:
#   projectName -- name of project
#   simpleError -- print simple errors
#   listShared  -- list the shared modules used by the project
#
# Returns:
#   $modulePaths
#
#   modulePaths -- reference to array of used modules
#
sub getModulesXMLProject {
  my ($projectName, $simpleError, $listShared) = @_;

  # Read the project XML file
  my $project;
  if ($simpleError) {
    eval {$project = loadProject($projectName); };
    if ($@) {
      print "ERROR\n";
      exit 1;
    }
  }
  else {
    $project = loadProject($projectName);
  }

  # Load the modules
  my $modulePaths = getAllModules($project);

  # If loadShared is true then we need to process files enough to identify the
  # shared elements.
  if ($listShared) {
    my $modulesXML = {};
    my $sharedXML = {};
    loadModules($modulePaths, $modulesXML, $sharedXML);
    loadLocalModules($projectName, $modulesXML, $sharedXML);

    # Construct module objects
    $modulesXML = extractModulePrefixes($modulesXML);
    my ($modules, $sharedList) = moduleObjectsFromXML($modulesXML);

    # Get the list of used modules
    my $usedModules = getUsedModules($project, $modules);

    # Get the list of used shared XML
    my $usedShared = getUsedShared($projectName, $project, $usedModules, $sharedXML, $sharedList);

    # Build the list of modules
    my %modulePathHash;
    @modulePathHash{@$modulePaths} = ();

    for my $shared (keys(%$usedShared)) {
      # Skip over local shared files
      next if (! ($shared =~ m|/|));

      my $module = dirname($shared);
      next if (! ($module =~ m|/$MODULE_XML_DIR$|));

      $module =~ s|/$MODULE_XML_DIR$||;
      $modulePathHash{$module} = undef;
    }

    my @modulePaths = sort(keys(%modulePathHash));
    $modulePaths = \@modulePaths;
  }

  return $modulePaths;
}

#
# loadGlobalConfigs
#   Load the global configuration files
#
# Return:
#   reference to a hash containing the global XML config files
#
sub loadGlobalConfigs {
  my %configs;

  my $xml = {};
  my $seenGlobal = 0;

  # Read each XML file
  my @files = glob("$_NF_ROOT/$GLOBAL_CONF_DIR/*.xml");
  for my $file (@files) {
    my $conf = basename($file, ".xml");
    my ($root, $content) = myXMLin($file);

    # Skip non-global files
    next if $root ne $ROOT_GLOBAL;

    $xml->{$conf} = $content;
    $xml->{$conf}->{$PATH_KEY} = $file;

    $seenGlobal |= $conf eq $GLOBAL;
  }

  # Verify that we found the global conf file
  if (!$seenGlobal) {
    croak "Did not find global configuration file \"$GLOBAL.xml\" in $GLOBAL_CONF_DIR";
  }

  return $xml;
}

#
# loadProject
#   Load the project XML
#
# Params:
#   project     -- Project to load
#
# Return:
#   hash reference to XML
#
sub loadProject {
  my $projectName = shift;

  # FIXME: Load *all* XML files in the project include directory

  # Verify that we have the project config
  my $xmlFile = "$_NF_ROOT/$PROJECTS_DIR/$projectName/$PROJECT_XML_DIR/$PROJECT_XML";
  if (! -f $xmlFile) {
    croak "Cannot find project XML for project '$projectName': \"xmlFile\"";
  }

  my ($root, $project) = myXMLin($xmlFile);
  if ($root ne $ROOT_PROJECT) {
    croak "ERROR: Project XML file must use '$ROOT_PROJECT' as the top-level element";
  }
  $project->{$PATH_KEY} = $xmlFile;

  fixInstancesGroups($project);

  return $project;
}

#
# fixInstancesGroups
#   Fix up the instances and groups. If there is only one instance then intest of doing
#     'instance_name' => {}
#   it often produces
#     'name' => 'instance_name'
#
#   Similarly, when there is only one group, instead of doing
#     'group_name' => {'instance_name' => {...}, }
#   if produces
#     'name' => 'group_name', 'nf:instance' => {...}
#
# Params:
#   project   -- XML of the project to fix
#
sub fixInstancesGroups {
  my $project = shift;

  if (ref($project) eq 'HASH') {
    for my $key (keys(%$project)) {
      my $val = $project->{$key};
      if ($key eq $TAG_INSTANCE) {
        if (defined($val->{'name'})) {
          my $instName = $val->{'name'};
          delete($val->{'name'});
          my $instance = {};
          for my $key (keys(%$val)) {
            $instance->{$key} = $val->{$key};
            delete($val->{$key});
          }
          $val->{$instName} = $instance;
        }
      }
      elsif ($key eq $TAG_GROUP) {
        if (scalar(keys(%$val)) == 2 && defined($val->{'name'}) && defined($val->{$TAG_INSTANCE})) {
          my $instName = $val->{'name'};
          my $instance = $val->{$TAG_INSTANCE};
          delete($val->{'name'});
          delete($val->{$TAG_INSTANCE});
          $val->{$instName} = {$TAG_INSTANCE => $instance};
          fixInstancesGroups($val);
        }
      }
      elsif (ref($val) eq 'ARRAY' || ref($val) eq 'HASH') {
        fixInstancesGroups($val);
      }
    }
  }
  else {
    for my $val (@$project) {
      fixInstancesGroups($val);
    }
  }
}

#
# verifyProjectInfo
#   Verify project attribs
#
# Params:
#   project     -- XML of project
#
sub verifyProjectInfo {
  my $project = shift;

  # Check for a name
  if (!defined($project->{$TAG_NAME})) {
    croak "Connot find name in project XML file (" . $project->{PATH_KEY} . "). Missing attribute: $TAG_NAME";
  }

  # Work out whether to warn about versions
  my $warnVersion = 0;
  if (defined($project->{$TAG_MEMALLOC})) {
    my $memalloc = $project->{$TAG_MEMALLOC};
    # Attempt to identify the layout
    if (defined($memalloc->{$TAG_LAYOUT})) {
      my $layout = $memalloc->{$TAG_LAYOUT};
      switch ($layout) {
        case "$MEMLAYOUT_REF"     {$warnVersion = 1;}
        case "$MEMLAYOUT_CPCI"    {$warnVersion = 0;}
        else                      {$warnVersion = 1;}
      }
    }
  }

  # Verify version information
  my $versionInfoMissing;
  if (!defined($project->{$TAG_VERSION_MAJOR})) {
    $versionInfoMissing = 1;
    $project->{$TAG_VERSION_MAJOR} = 0;
  }
  if (!defined($project->{$TAG_VERSION_MINOR})) {
    $versionInfoMissing = 1;
    $project->{$TAG_VERSION_MINOR} = 0;
  }
  if (!defined($project->{$TAG_VERSION_REVISION})) {
    $versionInfoMissing = 1;
    $project->{$TAG_VERSION_REVISION} = 0;
  }
  if ($warnVersion && $versionInfoMissing) {
    print "WARNING: Version information missing for project. Please specify $TAG_VERSION_MAJOR, $TAG_VERSION_MINOR, and $TAG_VERSION_REVISION in project XML file.\n";
  }
  if ($project->{$TAG_VERSION_MAJOR} < 0 || $project->{$TAG_VERSION_MAJOR} > VERSION_MAX) {
    print "WARNING: Major version number ($TAG_VERSION_MAJOR) must be between 0 and " . VERSION_MAX . ".\n";
  }
  if ($project->{$TAG_VERSION_MINOR} < 0 || $project->{$TAG_VERSION_MINOR} > VERSION_MAX) {
    print "WARNING: Minor version number ($TAG_VERSION_MINOR) must be between 0 and " . VERSION_MAX . ".\n";
  }
  if ($project->{$TAG_VERSION_REVISION} < 0 || $project->{$TAG_VERSION_REVISION} > VERSION_MAX) {
    print "WARNING: Revision number ($TAG_VERSION_REVISION) must be between 0 and " . VERSION_MAX . ".\n";
  }
}

#
# printProjectInfo
#   Print project attribs
#
# Params:
#   projectName -- Name of project
#   project     -- XML of project
#
sub printProjectInfo {
  my ($projectName, $project) = @_;

  my $name = $project->{$TAG_NAME};
  my $desc = $project->{$TAG_DESCRIPTION};
  my $verMajor = $project->{$TAG_VERSION_MAJOR};
  my $verMinor = $project->{$TAG_VERSION_MINOR};
  my $verRevision = $project->{$TAG_VERSION_REVISION};
  my $devId = $project->{$TAG_DEVICE_ID};
  $devId = 0 if (!defined($devId));

  print "\n";
  print "Project: '$name' ($projectName)\n";
  if (defined($desc)) {
    print "Description: $desc\n";
  }
  print "Version: $verMajor.$verMinor.$verRevision\n";
  print "Device ID: $devId\n";
  print "\n";
}

#
# getAllModules
#   Get a list of modules from a project
#
# Params:
#   project     -- XML of the project
#
# Return:
#   array of modules
#
sub getAllModules {
  my $project = shift;

  my $moduleStr = $project->{$TAG_USE_MODULES};

  # Verify that we actually have a set of modules
  if (ref($moduleStr) eq 'HASH') {
    return [];
  }

  # Split the modules
  $moduleStr =~ s/^\s+//;
  $moduleStr =~ s/\s+$//;

  my @ret = split(/\s+/, $moduleStr);
  return \@ret;
}

#
# loadModules
#   Load the modules from the project
#
# Params:
#   modules     -- Array of modules to load for the project
#   modulesXML  -- Hash of modules to add the modules to
#   sharedXML   -- Hash of shared to add the shared to
#
sub loadModules {
  my ($modules, $modulesXML, $sharedXML) = @_;

  for my $module (@$modules) {
    # Verify that the module exists
    my $dir = "$LIB_VERILOG/$module";
    if (! -d "$_NF_ROOT/$dir") {
      croak "Cannot find module '$module'";
    }

    my $xmlDir = "$_NF_ROOT/$dir/$MODULE_XML_DIR";
    my @xmlFiles = glob("$xmlDir/*.xml");
    if (scalar(@xmlFiles) == 0) {
      print "WARNING: No module specific XML found for module '$module'\n" if !isQuiet();
      next;
    }

    my $numXMLFiles = scalar(@xmlFiles);

    for my $xmlFile (@xmlFiles) {
      my ($root, $content) = myXMLin($xmlFile);
      my $xmlFileNoLib = $xmlFile;
      $xmlFileNoLib =~ s|^$_NF_ROOT/$LIB_VERILOG/||;

      if ($root eq $ROOT_MODULE) {
        my $file = basename($xmlFileNoLib, ".xml");
        my $name = $numXMLFiles == 0 ? $module : "$module:$file";
        $modulesXML->{$name} = $content;
        $modulesXML->{$name}->{$PATH_KEY} = $xmlFile;
      }
      elsif ($root eq $ROOT_SHARED) {
        $sharedXML->{$xmlFileNoLib} = $content;
        $sharedXML->{$xmlFileNoLib}->{$PATH_KEY} = $xmlFile;
      }
      else {
        print "WARNING: Unexpected root element '$root' in '$xmlFile'\n";
      }
    }
  }
}

#
# loadLocalModules
#   Load the local modules defined for the project
#
# Params:
#   projectName -- Project to load
#   modulesXML  -- Hash of modules to add the modules to
#   sharedXML   -- Hash of shared to add the shared to
#
# Return:
#   reference to a hash containing the XML for each local module
#
sub loadLocalModules {
  my ($projectName, $modulesXML, $sharedXML) = @_;

  # Read each XML file
  my @xmlFiles = glob("$_NF_ROOT/$PROJECTS_DIR/$projectName/$PROJECT_XML_DIR/*.xml");
  for my $xmlFile (@xmlFiles) {
    next if basename($xmlFile) eq $PROJECT_XML;

    my ($root, $content) = myXMLin($xmlFile);
    my $xmlFileNoProj = $xmlFile;
    $xmlFileNoProj =~ s|^$_NF_ROOT/$PROJECTS_DIR/$projectName/$PROJECT_XML_DIR/||;

    if ($root eq $ROOT_MODULE) {
      my $file = basename($xmlFileNoProj, ".xml");
      my $name = "$LOCAL_PREFIX:$file";
      $modulesXML->{$name} = $content;
      $modulesXML->{$name}->{$PATH_KEY} = $xmlFile;
    }
    elsif ($root eq $ROOT_SHARED) {
      my $name = "$LOCAL_PREFIX:$xmlFileNoProj";
      $sharedXML->{$name} = $content;
      $sharedXML->{$name}->{$PATH_KEY} = $xmlFile;
    }
    else {
      print "WARNING: Unexpected root element '$root' in '$xmlFile'\n";
    }
  }
}

#
# processConstants
#   Process the constants in a config file
#
# Params:
#   constsHash  -- reference to a hash of the constants
#   constsArr   -- reference to an array of the constant names
#   xml         -- reference to a hash of the XML constants
#   isGlobal    -- should constants be global by default
#
sub processConstants {
  my ($constsHash, $constsArr, $xml, $isGlobal) = @_;

  # Verify that we have constants
  return if (!defined($xml->{$TAG_CONSTANTS}));
  return if (!defined($xml->{$TAG_CONSTANTS}->{$TAG_CONSTANT}));

  my $file = stripNF2Root($xml->{$PATH_KEY});
  my $prefix = $xml->{$TAG_PREFIX};
  my $consts = $xml->{$TAG_CONSTANTS}->{$TAG_CONSTANT};
  if (ref($consts) eq 'HASH') {
    $consts = [$consts];
  }

  # Attempt to add the constants
  for my $const (@$consts) {
    addConstant($constsHash, $constsArr, $const, $file, $isGlobal ? undef : $prefix);
  }
}

#
# addConstant
#   Add a single constant to the hash of constants
#
# Params:
#   constsHash  -- reference to a hash of the constants
#   constsArr   -- reference to an array of the constants
#   const       -- reference to a hash of the constant
#   file        -- XML file name
#   prefix      -- prefix to add to the constant if necessary
#
sub addConstant {
  my ($constsHash, $constsArr, $const, $file, $prefix) = @_;

  my $name = $const->{$TAG_NAME};
  my $value = $const->{$TAG_VALUE};
  my $desc = squelch($const->{$TAG_DESCRIPTION});
  my $width = $const->{$TAG_WIDTH};

  # Add prefixes to name/value as appropriate
  $name = addPrefixToName($name, $prefix);
  $value = addPrefixToValue($value, $prefix);
  $width = addPrefixToValue($width, $prefix);

  if (defined($constsHash->{$name})) {
    my $constObj = $constsHash->{$name};
    print "WARNING: Configuration file '$file' overrides constant '$name' previously defined in '" . $constObj->file() . "'\n";
  }
  else {
    push @$constsArr, $name;
  }

  my $constObj = NF::RegSystem::Constant->new($name, $value);
  $constObj->desc($desc);
  $constObj->width($width);
  $constObj->file($file);

  $constsHash->{$name} = $constObj;
}

#
# addPrefixToName
#   Add a prefix to a name
#
# Params:
#   name        -- name to add prefix to
#   prefix      -- prefix to add to the constant if necessary
#
# Return:
#   name with prefixes added as necessary
#
sub addPrefixToName {
  my ($name, $prefix) = @_;

  if (defined($prefix)) {
    if ($name =~ /^:/) {
      $name =~ s/^://;
    }
    else {
      $name = $prefix . '_' . $name;
    }
  }

  return $name;
}

#
# addPrefixToValue
#   Add a prefix to a name
#
# Params:
#   value       -- name to add prefix to
#   prefix      -- prefix to add to the constant if necessary
#
# Return:
#   value with prefixes added as necessary
#
my $stack = {};

sub addPrefixToValue {
  my ($value, $prefix) = @_;

  return $value if (!defined($value));
  return $value if (!defined($prefix));
  return $value if ($value =~ /^\d+$/);
  return $value if (ref($value) eq 'Math::BigInt');

  my @toks;

  # Parse the value
  PARSER: {
    $value =~ m/ \G( \d+\b             )/gcx && do {
      push @toks, $1;
      redo;
    };
    $value =~ m/ \G( 0x[[:xdigit:]]+\b )/gcx && do {
      push @toks, $1;
      redo;
    };
    $value =~ m/ \G( :?\w+               )/gcx && do {
      push @toks, addPrefixToName($1, $prefix);
      redo;
    };
    $value =~ m/ \G( \s+               )/gcx && do {
      redo;
    };
    $value =~ m/ \G( [^\w\d\s]+        )/gcx && do {
      push @toks, $1;
      redo;
    };
  }

  return join(' ', @toks);
}

#
# processTypes
#   Process the types in a config file
#
# Params:
#   typesHash -- reference to a hash of the types
#   typesArr  -- reference to an array of the types
#   xml       -- reference to a hash of the XML types
#   isGlobal    -- should constants be global by default
#
sub processTypes {
  my ($typesHash, $typesArr, $xml, $isGlobal) = @_;

  # Verify that we have typeants
  return if (!defined($xml->{$TAG_TYPES}));
  return if (!defined($xml->{$TAG_TYPES}->{$TAG_TYPE}));

  my $file = stripNF2Root($xml->{$PATH_KEY});
  my $prefix = $xml->{$TAG_PREFIX};
  my $types = $xml->{$TAG_TYPES}->{$TAG_TYPE};
  if (ref($types) eq 'HASH') {
    $types = [$types];
  }

  # Attempt to add the typeants
  for my $type (@$types) {
    addType($typesHash, $typesArr, $type, $file, $isGlobal ? undef : $prefix);
  }
}

#
# addType
#   Add a single type to the hash of types
#
# Params:
#   typesHash -- reference to a hash of the types
#   typesArr  -- reference to an array of the types
#   type      -- reference to a hash of the type
#   file      -- XML file name
#   prefix    -- prefix to add to any constants as necessary
#
sub addType {
  my ($typesHash, $typesArr, $type, $file, $prefix) = @_;

  # Identify the type
  my $typeOfType = $type->{$TAG_XSI_TYPE};
  switch ($typeOfType) {
    case "$TYPE_SIMPLE"       {addSimpleType($typesHash, $typesArr, $type, $file, $prefix);}
    case "$TYPE_COMPOUND"     {addCompoundType($typesHash, $typesArr, $type, $file, $prefix);}
    case "$TYPE_TABLE"        {addTableType($typesHash, $typesArr, $type, $file, $prefix);}
    else                      {croak "Unhandled Type: $typeOfType";}
  }
}

#
# addSimpleType
#   Add a simple type to the hash of types
#
# Params:
#   typesHash -- reference to a hash of the types
#   typesArr  -- reference to an array of the types
#   type      -- reference to a hash of the type
#   file      -- XML file name
#   prefix    -- prefix to add to any constants as necessary
#
sub addSimpleType {
  my ($typesHash, $typesArr, $type, $file, $prefix) = @_;

  my $name = $type->{$TAG_NAME};
  my $desc = squelch($type->{$TAG_DESCRIPTION});
  my $width = $type->{$TAG_WIDTH};
  my $bitmasks = createBitmasks($type->{$TAG_BITMASK}, $prefix);

  $width = addPrefixToValue($width, $prefix);

  if (defined($typesHash->{$name})) {
    my $typeObj = $typesHash->{$name};
    croak "ERROR: Configuration file '$file' overrides type '$name' previously defined in '" . $typeObj->file() . "'\n";
  }
  else {
    push @$typesArr, $name;
  }

  my $typeObj = NF::RegSystem::SimpleType->new($name, $desc);
  $typeObj->width($width);
  $typeObj->bitmasks($bitmasks);
  $typeObj->file($file);

  $typesHash->{$name} = $typeObj;
}

#
# addCompoundType
#   Add a simple type to the hash of types
#
# Params:
#   typesHash -- reference to a hash of the types
#   typesArr  -- reference to an array of the types
#   type      -- reference to a hash of the type
#   file      -- XML file name
#   prefix    -- prefix to add to any constants as necessary
#
sub addCompoundType {
  my ($typesHash, $typesArr, $type, $file, $prefix) = @_;

  my $name = $type->{$TAG_NAME};
  my $desc = squelch($type->{$TAG_DESCRIPTION});
  my $fields = createFields($type->{$TAG_FIELD}, $prefix);

  if (defined($typesHash->{$name})) {
    my $typeObj = $typesHash->{$name};
    croak "ERROR: Configuration file '$file' overrides type '$name' previously defined in '" . $typeObj->file() . "'\n";
  }
  else {
    push @$typesArr, $name;
  }

  my $typeObj = NF::RegSystem::CompoundType->new($name, $desc);
  $typeObj->fields($fields);
  $typeObj->file($file);

  $typesHash->{$name} = $typeObj;
}

#
# addTableType
#   Add a simple type to the hash of types
#
# Params:
#   typesHash -- reference to a hash of the types
#   typesArr  -- reference to an array of the types
#   type      -- reference to a hash of the type
#   file      -- XML file name
#   prefix    -- prefix to add to any constants as necessary
#
sub addTableType {
  my ($typesHash, $typesArr, $type, $file, $prefix) = @_;

  my $name = $type->{$TAG_NAME};
  my $desc = squelch($type->{$TAG_DESCRIPTION});
  my $depth = $type->{$TAG_DEPTH};
  my $width = $type->{$TAG_WIDTH};
  my $entryType = $type->{$TAG_ENTRY_TYPE};

  $depth = addPrefixToValue($depth, $prefix);
  $width = addPrefixToValue($width, $prefix);

  if (defined($typesHash->{$name})) {
    my $typeObj = $typesHash->{$name};
    croak "ERROR: Configuration file '$file' overrides type '$name' previously defined in '" . $typeObj->file() . "'\n";
  }
  else {
    push @$typesArr, $name;
  }

  my $typeObj = NF::RegSystem::TableType->new($name, $desc);
  $typeObj->depth($depth);
  if (defined($entryType)) {
    $typeObj->entryType($entryType);
  } else {
    $typeObj->entryWidth($width);
  }
  $typeObj->file($file);

  $typesHash->{$name} = $typeObj;
}

#
# createBitmasks
#   Create the bitmasks objects corresponding to the XML
#
# Params:
#   bitmask   -- XML bitmask reference
#   prefix    -- prefix to add to any constants as necessary
#
# Return:
#   reference to an array of bitmask objects
#
sub createBitmasks {
  my ($bitmaskXML, $prefix) = @_;

  return undef if (!defined($bitmaskXML));

  if (ref($bitmaskXML) eq 'HASH') {
    $bitmaskXML = [$bitmaskXML];
  }
  my $bitmasks = [];
  for my $bitmask (@$bitmaskXML) {
    push @$bitmasks, createBitmask($bitmask, $prefix);
  }

  return $bitmasks;
}

#
# createBitmask
#   Create the bitmask objects corresponding to the XML
#
# Params:
#   bitmask   -- XML bitmask reference
#   prefix    -- prefix to add to any constants as necessary
#
# Return:
#   bitmask object
#
sub createBitmask {
  my ($bitmaskXML, $prefix) = @_;

  my $name = $bitmaskXML->{$TAG_NAME};
  my $desc = squelch($bitmaskXML->{$TAG_DESCRIPTION});
  my $pos = $bitmaskXML->{$TAG_POS};
  my $posLo = $bitmaskXML->{$TAG_POS_LO};
  my $posHi = $bitmaskXML->{$TAG_POS_HI};

  $pos = addPrefixToValue($pos, $prefix);
  $posLo = addPrefixToValue($posLo, $prefix);
  $posHi = addPrefixToValue($posHi, $prefix);

  my $bitmaskObj = NF::RegSystem::BitmaskType->new($name, $desc);
  if (defined($pos)) {
    $bitmaskObj->pos($pos);
  } else {
    $bitmaskObj->posLo($posLo);
    $bitmaskObj->posHi($posHi);
  }

  return $bitmaskObj;
}

#
# createFields
#   Create the fields objects corresponding to the XML
#
# Params:
#   field   -- XML field reference
#   prefix  -- prefix to add to any constants as necessary
#
# Return:
#   reference to an array of field objects
#
sub createFields {
  my ($fieldXML, $prefix) = @_;

  return undef if (!defined($fieldXML));

  if (ref($fieldXML) eq 'HASH') {
    $fieldXML = [$fieldXML];
  }
  my $fields = [];
  for my $field (@$fieldXML) {
    push @$fields, createField($field, $prefix);
  }

  return $fields;
}

#
# createField
#   Create the field objects corresponding to the XML
#
# Params:
#   field   -- XML field reference
#   prefix  -- prefix to add to any constants as necessary
#
# Return:
#   field object
#
sub createField {
  my ($fieldXML, $prefix) = @_;

  my $name = $fieldXML->{$TAG_NAME};
  my $desc = squelch($fieldXML->{$TAG_DESCRIPTION});
  my $type = $fieldXML->{$TAG_TYPE};
  my $width = $fieldXML->{$TAG_WIDTH};

  $width = addPrefixToValue($width, $prefix);

  my $fieldObj = NF::RegSystem::Field->new($name, $desc);
  if (defined($type)) {
    $fieldObj->type($type);
  } else {
    $fieldObj->width($width);
  }

  return $fieldObj;
}

#
# extractModulePrefixes
#   Extract the module prefixes from modules
#
# Params:
#   modulesXML -- Ref to hash of modules by path
#
# Return:
#   reference to hash of XML modules keyed on module names
#
sub extractModulePrefixes {
  my ($modulesXML) = @_;

  my %localModules;
  my $modules = {};
  for my $path (keys(%$modulesXML)) {
    my $module = $modulesXML->{$path};
    my $name = $module->{$TAG_NAME};
    my $isLocal = 0;
    $isLocal = 1 if ($path =~ /^$LOCAL_PREFIX/);

    if (!defined($name)) {
      croak "Missing module name for module '$path'";
    }

    # Check for duplicate module names. Local modules can override global ones.
    if (defined($localModules{$name})) {
      if (! $isLocal) {
        croak "Multiple definitions of module with name '$name'\n" .
            "Defined in '" . $modules->{$name}->{$PATH_KEY} . "' and '$path'";
      }
      else {
        if ($localModules{$name}) {
          croak "Multiple LOCAL definitions of module with name '$name'\n" .
              "Defined in '" . $modules->{$name}->{$PATH_KEY} . "' and '$path'";
        }
        else {
          print "WARNING: Local module with name '$name' overrides global module.\n" .
              "(Defined in '" . $modules->{$name}->{$PATH_KEY} . "' and '$path')\n" if !isQuiet();
        }
      }
    }

    $modules->{$name} = $module;
    $localModules{$name} = $isLocal;
  }

  return $modules;
}

#
# moduleObjectsFromXML
#   Create module objects from the XML
#
# Params:
#   modulesXML -- Ref to hash of modules
#
# Return:
#   modules, sharedList -- reference to hash of modules keyed on names,
#                          list of shared requested by modules
#
sub moduleObjectsFromXML{
  my ($modulesXML) = @_;

  my $modules = {};
  my $sharedList = {};
  for my $xmlModule (values(%$modulesXML)) {
    my $name = $xmlModule->{$TAG_NAME};
    my $prefix = $xmlModule->{$TAG_PREFIX};
    my $location = $xmlModule->{$TAG_LOCATION};
    my $desc = squelch($xmlModule->{$TAG_DESCRIPTION});
    my $blockSize = $xmlModule->{$TAG_BLOCKSIZE};
    my $prefBase = $xmlModule->{$TAG_PREF_BASE};
    my $forceBase = $xmlModule->{$TAG_FORCE_BASE};
    my $useShared = $xmlModule->{$TAG_USE_SHARED};
    my $path = $xmlModule->{$PATH_KEY};
    if (defined($useShared)) {
      my $sharedPath = '';
      if ($path =~ m|^$_NF_ROOT/$LIB_VERILOG/|) {
        $sharedPath = $path;
        $sharedPath =~ s|^$_NF_ROOT/$LIB_VERILOG/||;
        $sharedPath = dirname($sharedPath) . '/';
      }

      $useShared =~ s/^\s+//;
      $useShared =~ s/\s+$//;
      my @useShared = split('\s+', $useShared);
      $useShared = ();
      for my $shared (@useShared) {
        if (! ($shared =~ m|/|)) {
          $shared = $sharedPath . $shared;
        }
        push @$useShared, $shared;
      }
    }

    if (!defined($name)) {
      croak "Missing module name for module '$path'";
    }
    if (!defined($prefix)) {
      croak "Missing module prefix for module '$path'";
    }

    # Expand the blocksize
    $blockSize = expandBlockSize($name, $location, $blockSize);

    my $module = NF::RegSystem::Module->new($name, $prefix, $location);
    $module->desc($desc);
    $module->blockSize($blockSize);
    $module->prefBase($prefBase);
    $module->forceBase($forceBase);
    $module->file(stripNF2Root($path));

    $modules->{$name} = $module;
    $sharedList->{$name} = $useShared if (defined($useShared));
  }

  return ($modules, $sharedList);
}

#
# getUsedModules
#   Identify which modules are used in instance statements
#
# Params:
#   project -- Project XML hash reference
#   modules -- Hash of module objects
#
# Return:
#   Hash of used modules
#
sub getUsedModules {
  my $project = shift;
  my $modules = shift;

  # Attempt to find the memalloc
  if (!defined($project->{$TAG_MEMALLOC})) {
    croak "Could not find a memalloc section in project XML";
  }
  my $memalloc = $project->{$TAG_MEMALLOC};

  # Attempt to identify the layout
  if (!defined($memalloc->{$TAG_LAYOUT})) {
    croak "Could not find a memalloc section in project XML";
  }
  my $layout = $memalloc->{$TAG_LAYOUT};

  # Process the memalloc according to the layout
  switch ($layout) {
    case "$MEMLAYOUT_REF"     {return getUsedModulesRefLayout($memalloc, $modules);}
    case "$MEMLAYOUT_CPCI"    {return getUsedModulesCPCILayout($memalloc, $modules);}
    else                      {croak "Unhandled memory layout: $layout";}
  }
}

#
# getUsedShared
#   Load the used shared
#
# Params:
#   projectName -- name of project
#   project     -- Project XML hash reference
#   modules     -- Hash of module objects
#   shared      -- Hash of shared elements
#   sharedList  -- Hash of shared elements
#
# Return:
#   Hash of used modules
#
sub getUsedShared {
  my $projectName = shift;
  my $project = shift;
  my $modules = shift;
  my $shared = shift;
  my $sharedList = shift;

  my $usedShared = {};

  # Check for shareds in the project
  if (defined($project->{$TAG_USE_SHARED})) {
    my $sharedListForProj = $project->{$TAG_USE_SHARED};
    $sharedListForProj =~ s/^\s+//;
    $sharedListForProj =~ s/\s+$//;
    my @sharedListForProj = split('\s+', $sharedListForProj);
    for my $sharedName (@sharedListForProj) {
      addUsedShared($sharedName, $projectName, $shared, $usedShared);
    }
  }
  for my $moduleName (keys(%$modules)) {
    if (defined($sharedList->{$moduleName})) {
      my $sharedListForModule = $sharedList->{$moduleName};
      for my $sharedName (@$sharedListForModule) {
        addUsedShared($sharedName, $projectName, $shared, $usedShared);
      }
    }
  }

  return $usedShared;
}

#
# addUsedShared
#   Add a shared to the list of used shareds, loading it if necessary
#
# Params:
#   name          -- name of shared
#   projectName   -- name of project
#   loadedShared  -- list of loaded shareds
#   usedShared    -- list of used shareds
#
sub addUsedShared {
  my ($name, $projectName, $loadedShared, $usedShared) = @_;

  # Check if it's already in the list of shareds
  return if (defined($usedShared->{$name}));

  # Check if it's loaded in the list of loaded shareds
  if (defined($loadedShared->{$name})) {
    $usedShared->{$name} = $loadedShared->{$name};
  }

  # Attempt to load the file
  my $file;
  if ($name =~ m|/|) {
    $file = "$_NF_ROOT/$LIB_VERILOG/$name";
  }
  else {
    $file = "$_NF_ROOT/$PROJECTS_DIR/$projectName/$PROJECT_XML_DIR/$name";
  }

  if (! -f $file) {
    croak "ERROR: Cannot find required shared file '$file'";
  }
  my ($root, $content) = myXMLin($file);
  $content->{$PATH_KEY} = $file;

  $loadedShared->{$name} = $content;
  $usedShared->{$name} = $content;
}

#
# getUsedModulesRefLayout
#   Extract the list of module instances from a reference layout memalloc hash
#
# Params:
#   memalloc  -- Memalloc from XML
#   modules   -- Hash of module objects
#
# Return:
#   Hash of used modules
#
sub getUsedModulesRefLayout {
  my $memalloc = shift;
  my $modules = shift;

  my $usedModules = {};

  for my $groupName (keys(%{$memalloc->{$TAG_GROUP}})) {
    my $group = $memalloc->{$TAG_GROUP}->{$groupName};
    for my $name (keys(%{$group->{$TAG_INSTANCE}})) {
      # Verify that we've actually loaded the module
      if (!defined($modules->{$name})) {
        croak "Definition for module '$name' not loaded";
      }
      my $module = $modules->{$name};

      $usedModules->{$name} = $module;
    }
  }

  return $usedModules;
}

#
# getUsedModulesCPCILayout
#   Extract the list of module instances from a CPCI layout memalloc hash
#
# Params:
#   memalloc  -- Memalloc from XML
#   modules   -- Hash of module objects
#
# Return:
#   Hash of used modules
#
sub getUsedModulesCPCILayout {
  my $memalloc = shift;
  my $modules = shift;

  my $usedModules = {};

  # Get the list of keys
  my @keys = keys(%$memalloc);

  for my $groupName (keys(%{$memalloc->{$TAG_GROUP}})) {
    my $group = $memalloc->{$TAG_GROUP}->{$groupName};
    for my $name (keys(%{$group->{$TAG_INSTANCE}})) {
      # Verify that we've actually loaded the module
      if (!defined($modules->{$name})) {
        croak "Definition for module '$name' not loaded";
      }
      my $module = $modules->{$name};

      $usedModules->{$name} = $module;
    }
  }


  return $usedModules;
}

#
# extractLayout
#   Extract the memory layout from the project
#
# Params:
#   project -- Project XML hash reference
#   modules -- Hash of module objects
#   consts  -- Hash of constant objects
#
# Return:
#   Memory layout object
#
sub extractLayout {
  my $project = shift;
  my $modules = shift;
  my $consts = shift;

  # Attempt to find the memalloc
  if (!defined($project->{$TAG_MEMALLOC})) {
    croak "Could not find a memalloc section in project XML";
  }
  my $memalloc = $project->{$TAG_MEMALLOC};

  # Attempt to identify the layout
  if (!defined($memalloc->{$TAG_LAYOUT})) {
    croak "Could not find a memalloc section in project XML";
  }
  my $layout = $memalloc->{$TAG_LAYOUT};

  # Process the memalloc according to the layout
  switch ($layout) {
    case "$MEMLAYOUT_REF"     {return extractRefLayout($memalloc, $modules, $consts);}
    case "$MEMLAYOUT_CPCI"    {return extractCPCILayout($memalloc, $modules, $consts);}
    else                      {croak "Unhandled memory layout: $layout";}
  }
}

#
# extractRefLayout
#   Extract the list of module instances from a reference layout memalloc hash
#
# Params:
#   memalloc  -- Memalloc from XML
#   modules   -- Hash of module objects
#   consts  -- Hash of constant objects
#
# Return:
#   reference to list of module names
#
sub extractRefLayout {
  my $memalloc = shift;
  my $modules = shift;
  my $consts = shift;

  my $layout = NF::RegSystem::ReferenceLayout->new();

  for my $groupName (keys(%{$memalloc->{$TAG_GROUP}})) {
    my $group = $memalloc->{$TAG_GROUP}->{$groupName};
    for my $name (keys(%{$group->{$TAG_INSTANCE}})) {
      my $count = $group->{$TAG_INSTANCE}->{$name}->{$TAG_COUNT};
      my $base = $group->{$TAG_INSTANCE}->{$name}->{$TAG_BASE};

      # Verify that we've actually loaded the module
      if (!defined($modules->{$name})) {
        croak "Definition for module '$name' not loaded";
      }
      my $module = $modules->{$name};
      my ($newBase) = expandValue($base, $consts, $name);

      $layout->addModule($groupName, $module, $count, $newBase);
    }
  }

  return $layout;
}

#
# extractCPCILayout
#   Extract the list of module instances from a CPCI layout memalloc hash
#
# Params:
#   memalloc  -- Memalloc from XML
#   modules   -- Hash of module objects
#   consts  -- Hash of constant objects
#
# Return:
#   reference to list of module names
#
sub extractCPCILayout {
  my $memalloc = shift;
  my $modules = shift;
  my $consts = shift;

  my $layout = NF::RegSystem::CPCILayout->new();

  for my $groupName (keys(%{$memalloc->{$TAG_GROUP}})) {
    my $group = $memalloc->{$TAG_GROUP}->{$groupName};
    for my $name (keys(%{$group->{$TAG_INSTANCE}})) {
      my $count = $group->{$TAG_INSTANCE}->{$name}->{$TAG_COUNT};
      my $base = $group->{$TAG_INSTANCE}->{$name}->{$TAG_BASE};

      # Verify that we've actually loaded the module
      if (!defined($modules->{$name})) {
        croak "Definition for module '$name' not loaded";
      }
      my $module = $modules->{$name};
      my ($newBase) = expandValue($base, $consts, $name);

      $layout->addModule($groupName, $module, $count, $newBase);
    }
  }

  return $layout;
}

#
# addRegistersToModule
#   Add the registers to the module
#
# Params:
#   module  -- module to add registers to
#   xml     -- Module XML file
#   consts  -- Hash ref of constants
#   types   -- Hash ref of types
#
sub addRegistersToModule {
  my ($module, $xml, $consts, $types) = @_;

  # Verify that we have constants
  return if (!defined($xml->{$TAG_REGISTERS}));
  return if (!defined($xml->{$TAG_REGISTERS}->{$TAG_REGISTER}) &&
      !defined($xml->{$TAG_REGISTERS}->{$TAG_REGISTER_GROUP}));

  my $prefix = $xml->{$TAG_PREFIX};

  # Processing for registers
  if (defined($xml->{$TAG_REGISTERS}->{$TAG_REGISTER})) {
    my $regs = $xml->{$TAG_REGISTERS}->{$TAG_REGISTER};
    if (ref($regs) eq 'HASH') {
      $regs = [$regs];
    }

    for my $reg (@$regs) {
      addRegister($module, $reg, $consts, $types, $prefix);
    }
  }

  # Processing for register groups
  if (defined($xml->{$TAG_REGISTERS}->{$TAG_REGISTER_GROUP})) {
    my $regGroups = $xml->{$TAG_REGISTERS}->{$TAG_REGISTER_GROUP};
    if (ref($regGroups) eq 'HASH') {
      $regGroups = [$regGroups];
    }
    else {
      # Currently, only support one register group
      my $name = $module->name();
      croak "ERROR: Module '$name' containts multiple register groups. Currently we only support one.";
    }

    for my $regGroup (@$regGroups) {
      addRegisterGroup($module, $regGroup, $consts, $types, $prefix);
    }
  }

  # Update the register addresses
  $module->updateRegAddrs();
}

#
# addRegister
#   Add a single register to a module or register group
#
# Params:
#   dest    -- module or register group to add register to
#   reg     -- Register to add (XML)
#   consts  -- Hash ref of constants
#   types   -- Hash ref of types
#   prefix  -- prefix to add to any constants as necessary
#
sub addRegister {
  my ($dest, $reg, $consts, $types, $prefix) = @_;

  my $name = $reg->{$TAG_NAME};
  my $desc = squelch($reg->{$TAG_DESCRIPTION});
  my $width = $reg->{$TAG_WIDTH};
  my $type = $reg->{$TAG_TYPE};
  my $addr = $reg->{$TAG_ADDR};

  # Expand the width
  $width = addPrefixToValue($width, $prefix);
  ($width) = expandValue($width, $consts, $name);

  # Find the type
  if (defined($type)) {
    if (!defined($types->{$type})) {
      croak "ERROR: Cannot find type '$type' for register '$name' in module '" . $dest->{name} . "'";
    }
    $type = $types->{$type};
  }

  # Expand the address
  ($addr) = expandValue($addr, $consts, $name);


  my $regObj = NF::RegSystem::Register->new($name);
  $regObj->desc($desc);
  $regObj->width($width) if (defined($width));
  $regObj->type($type) if (defined($type));
  $regObj->addr($addr) if (defined($addr));

  $dest->addRegister($regObj);
}

#
# addRegisterGroup
#   Add a register group to a module
#
# Params:
#   module  -- module to add register to
#   group   -- Register group to add (XML)
#   consts  -- Hash ref of constants
#   types   -- Hash ref of types
#   prefix  -- prefix to add to any constants as necessary
#
sub addRegisterGroup {
  my ($module, $group, $consts, $types, $prefix) = @_;

  my $name = $group->{$TAG_NAME};
  my $instances = $group->{$TAG_INSTANCES};
  my $instSize = $group->{$TAG_INSTANCE_SIZE};

  # Expand the instances and group size
  $instances = addPrefixToValue($instances, $prefix);
  ($instances) = expandValue($instances, $consts, $name);

  $instSize = addPrefixToValue($instSize, $prefix);
  ($instSize) = expandValue($instSize, $consts, $name);

  my $instPow2 = 2 ** log2ceil($instances);
  my $regGrpMaxSize = $module->getRegGrpMaxSize();

  # Set the group size if it's not already set
  if (!defined($instSize)) {
    $instSize = $regGrpMaxSize / $instPow2;
  }

  # Verify that the group size is sane
  if ($instSize * $instPow2 > $regGrpMaxSize) {
    croak "ERROR: Total size for register group '$name' in '" . $module->name() . "' exceeds the space available ($regGrpMaxSize).";
  }

  # Calculate the module offset based on the max group size
  my $offset = $module->blockSize() - $regGrpMaxSize;

  my $regGroupObj = NF::RegSystem::RegisterGroup->new($name);
  $regGroupObj->instances($instances);
  $regGroupObj->instSize($instSize);
  $regGroupObj->offset($offset);

  # Verify that we have an array
  my $regs = $group->{$TAG_REGISTER};
  if (ref($regs) eq 'HASH') {
    $regs = [$regs];
  }

  for my $reg (@$regs) {
    addRegister($regGroupObj, $reg, $consts, $types);
  }

  $module->addRegister($regGroupObj);
}

#
# replaceNamesWithObjects
#   Replace the names in the array with the objects
#
# Params:
#   arr   -- Array with names
#   hash  -- Hash keyed by name
#
sub replaceNamesWithObjects {
  my ($arr, $hash) = @_;

  for (my $i = 0; $i < scalar(@$arr); $i++) {
    my $name = $arr->[$i];
    $arr->[$i] = $hash->{$name};
  }
}

#
# verifyModuleSizes
#   Verify that all modules are large enough to contain the registers inside them
#
# Params:
#   modules -- Has of modules
#
sub verifyModuleSizes {
  my ($modules) = @_;

  my $good = 1;
  for my $module (values(%$modules)) {
    if (!$module->checkRegistersFit()) {
      $good = 0;
      carp "ERROR: The blocksize for the module " . $module->name() . " is too small to contain all registers";
    }
  }

  if (!$good) {
    croak "Exiting due to errors";
  }
}

#
# squelch
#   Remove new lines and squish adjacent white space
#
# Params:
#   str   -- String to process
#
# Return:
#   Processed string
#
sub squelch {
  my $str = shift;

  return $str if (!defined($str));

  return undef if (ref($str) eq 'HASH');

  $str =~ s/\s*(\r|\n)+\s*/ /;

  return $str;
}

#
# myXMLin
#   Local version of XMLin that prints the filename and then calls XMLin
#
# Params:
#   file -- name of XML file to process
#
# Return:
#   (root, content) -- Return the root element and a hash of the content
#
sub myXMLin {
  my ($file) = @_;

  print "Processing $file...\n" if !isQuiet();

  my $xml = XMLin($file, KeepRoot => 1);
  my @roots = keys(%$xml);
  if (scalar(@roots) != 1) {
    croak "ERROR: The XML file '$file' contains more than one top-level element'";
  }

  my $root = $roots[0];
  if( ! grep /^$root$/, @ROOT_ELEMENTS ) {
    croak "ERROR: The root element '$root' in XML file '$file' is unrecognized'";
  }
  return ($root, $xml->{$root});
}

#
# extractProject
#   Extract a project object from the XML
#
# Params:
#   projDir -- directory (external name) of project
#   projXML -- XML of project
#
# Return:
#   project object corresponding to project
#
sub extractProject {
  my ($projDir, $projXML) = @_;

  my $name = $projXML->{$TAG_NAME};
  my $desc = $projXML->{$TAG_DESCRIPTION};
  my $verMajor = $projXML->{$TAG_VERSION_MAJOR};
  my $verMinor = $projXML->{$TAG_VERSION_MINOR};
  my $verRevision = $projXML->{$TAG_VERSION_REVISION};
  my $devId = $projXML->{$TAG_DEVICE_ID};
  $devId = 0 if (!defined($devId));

  my $project = NF::RegSystem::Project->new($projDir, $name, $desc, $verMajor, $verMinor, $verRevision, $devId);

  return $project;
}

1;

__END__
