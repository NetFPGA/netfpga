#!/bin/sh
#
# $Id: loadregs.sh 4266 2008-07-10 00:06:57Z jnaous $
#
# Shell script to load the PCI configuration registers from a file or STDIN
#
# Use -f to specify the file to read from
# otherwise defaults to STDIN

# Check the command line parameters
FFLAG=
while getopts f: name ; do
	case $name in
		f) FFLAG=1
		   FILE="$OPTARG";;
		*) printf "Usage: %s: [-f dumpfile]\n" $0
		   exit 2;;
	esac
done
shift $(($OPTIND - 1))

# Check if we've got any parameters
if [ $# -gt 0 ] ; then
        DEVICE="-s $1"
else
        DEVICE="-d feed:0001"
fi

# Process the filename flag if specified
if [ ! -z "$FFLAG" ]; then
	# Check for the dump file
	if [ ! -f "$FILE" ] ; then
		echo "$0: Error: cannot find register file $FILE"
		exit 1
	fi

	# Redirect stdin from the requested file
	exec 0<$FILE
fi

# Load the registers
echo "Loading registers..."
while read REG ; do
	# Verify that we don't have a blank line
	if [ "$REG" = "" ] ; then
		continue
	fi

	# Program the register
	/sbin/setpci $DEVICE "$REG"
done

echo "Done"
