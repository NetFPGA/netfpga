#!/usr/bin/perl

use strict;

my $bin_dir = "$ENV{'NF_ROOT'}/bitfiles/router_buffer_sizing.bit";

if ($ARGV[0] eq "--use_bin")
{
  $bin_dir = $ARGV[1];
}

`nf_download $bin_dir`;
system("pushd $ENV{'NF_ROOT'}/projects/scone/sw/ ; sudo ./scone &");
`popd`;
system("pushd $ENV{'NF_ROOT'}/lib/java/gui ; sudo ./eventcap.sh");
`popd`;
`killall scone`;

exit 0;
