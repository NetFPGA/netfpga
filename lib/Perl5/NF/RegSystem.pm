#############################################################
# vim:set shiftwidth=2 softtabstop=2 expandtab:
#
# $Id: RegSystem.pm 6040 2010-04-01 05:58:00Z grg $
#
# NetFPGA register systems
#
# "Global variables" defined here
#
#############################################################

package NF::RegSystem;

use Exporter;

@ISA = ('Exporter');

@EXPORT_OK = qw(
                $GLOBAL_CONF_DIR
                $GLOBAL
                $PROJECTS_DIR
                $PROJECT_XML_DIR
                $PROJECT_XML
                $LIB_DIR
                $LIB_VERILOG
                $MODULE_XML_DIR
                $INCLUDE_DIR
                $MEMLAYOUT_REF
                $PATH_KEY
                $NF2_MAX_MEM
                $VALID_BLOCK_SIZES
                $_NF_ROOT
                $_NF_DESIGN_DIR
                $_NF_WORK_DIR
               );


use NF::Base;

use strict;

# Path locations
our $GLOBAL_CONF_DIR  = 'lib/verilog/core/common/xml';
our $GLOBAL = 'global';
our $PROJECTS_DIR = 'projects';
our $PROJECT_XML_DIR = 'include';
our $PROJECT_XML = 'project.xml';
our $LIB_DIR = 'lib';
our $LIB_VERILOG = $LIB_DIR . '/verilog';
our $MODULE_XML_DIR = 'xml';
our $INCLUDE_DIR = 'include';

# Memory layouts
our $MEMLAYOUT_REF = "reference";

# Key to indicate path
our $PATH_KEY = "_PATH";

# Maximum memory
our $NF2_MAX_MEM = 128 * 1048576;

# Locations and valid block sizes
#
# Note: undef means that there are no restrictions
our $VALID_BLOCK_SIZES = {
  'cpci'      => [ 4 * 1048576 ],
  'core'      => [ 256 * 1024 ],
  'udp'       => undef,
};

# NetFPGA environment variables
our $_NF_ROOT       = $ENV{'NF_ROOT'};
our $_NF_DESIGN_DIR = $ENV{'NF_DESIGN_DIR'};
our $_NF_WORK_DIR   = $ENV{'NF_WORK_DIR'};

# check vars are set.
BEGIN {
  check_NF2_vars_set();
}

1;

__END__
