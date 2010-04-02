#!/usr/local/bin/perl -W

#
# Script to convert a .bin file to a hex file for reading by readmemh
#

my $data;
my $length;
my $count = 0;
my $line = "";

#
# Check the number of arguments
#

if (scalar(@ARGV) != 1) {
	die "$0: Expecting one filename on command line";
}

# Open the file for reading
open INFILE, "$ARGV[0]";

while (($length = read(INFILE, $data, 1024)) != 0)
{
	for (my $i = 0; $i < $length; $i++)
	{
		$line = sprintf("%02x", ord(substr($data, $i, 1))) . $line;
		$count++;

		if ($count == 4)
		{
			print "$line\n";
			$line = "";
			$count = 0;
		}
	}
}

if ($count != 0)
{
	$line = ("00" x (4 - $count)) . $line;
	print "$line\n";
}

# Close the file, we're done
close INFILE;
