#!/usr/bin/perl

use strict;

# Verify that we're running as root
unless ($> == 0 || $< == 0) { die "Error: $0 must be run as root" }


my $bin_dir = "$ENV{'NF_ROOT'}/bitfiles/reference_router.bit";

if ($ARGV[0] eq "--use_bin")
{
  $bin_dir = $ARGV[1];
}

`nf_download $bin_dir`;
system("pushd $ENV{'NF_ROOT'}/projects/scone/sw/ ; ./scone &");
`popd`;
system("pushd $ENV{'NF_ROOT'}/lib/java/gui ; ./router.sh");
`popd`;
`killall scone`;

exit 0;

