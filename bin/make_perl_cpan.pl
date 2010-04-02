#!/usr/bin/perl -w
# $Id$
# Reads all Perl libraries and creates a CPAN
# module out of them


use strict;
use warnings;
use ExtUtils::ModuleMaker;
use Data::Dumper;

my $version = 'beta.1.2.5';

my $basedir = "$ENV{NF_ROOT}/lib/Perl5";

# get list of all packages
my @filenames = `cd $basedir; ls *.pm; ls */*.pm`;

my @pkg_names = @filenames;

# change into modules by replacing '/' with ':',
# and removing trailing .pm
map({chomp; s/\//::/; s/\.pm//} @pkg_names);

# remove base pkg name
@pkg_names = grep {!/NF::Base/} @pkg_names;

my $extras = [map({NAME => $_}, @pkg_names)];

my $mod = ExtUtils::ModuleMaker->new
  (
   NAME => 'NF::Base',
   ABSTRACT => 'Packages used for NetFPGA',
   VERSION => $version,
   COMPACT => '1',
   NEED_POD => '0',
   NEED_NEW_METHOD => '0',
   AUTHOR => 'NetFPGA Team',
   EMAIL => 'netfpga@stanford.edu',
   WEBSITE => 'http://netfpga.org',
   ORGANIZATION => 'Stanford University',
   EXTRA_MODULES => $extras,
  );

$mod->complete_build();

# replace stub libs with real ones
map {chomp; system("cp $basedir/$_ NetFPGA-Base/lib/$_")} @filenames;

# rename directory
my $pkg_name = "netfpga-perl-libs-$version";
system("mv NetFPGA-Base $pkg_name");

# now tar it up
system("tar -cjf $pkg_name.tar.bz2 $pkg_name/");

# delete old dir
system("rm -rf $pkg_name/");
