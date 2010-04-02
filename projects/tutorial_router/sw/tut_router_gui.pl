#!/usr/bin/perl

use strict;

my $bin_dir = "$ENV{'NF_ROOT'}/bitfiles/reference_router.bit";

if ($ARGV[0] eq "--use_bin")
{
  $bin_dir = $ARGV[1];
}

system("make -C ../../../");
`nf_download $bin_dir`;
system("pushd $ENV{'NF_ROOT'}/projects/scone/sw/ ; ./scone &");
`popd`;
system("pushd $ENV{'NF_ROOT'}/lib/java/gui ; ./router.sh");
`popd`;
`killall scone`;

exit 0;

