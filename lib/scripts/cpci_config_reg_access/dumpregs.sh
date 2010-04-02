#!/bin/sh
#
# $Id: dumpregs.sh 4266 2008-07-10 00:06:57Z jnaous $
#
# Shell script to read the PCI configuration registers for a device
#
# Use -f to specify the file to write to
# otherwise defaults to STDOUT

# Registers to save
REGS="VENDOR_ID \
DEVICE_ID \
COMMAND \
STATUS \
REVISION \
CLASS_PROG \
CLASS_DEVICE \
CACHE_LINE_SIZE \
LATENCY_TIMER \
HEADER_TYPE \
BIST \
BASE_ADDRESS_0 \
BASE_ADDRESS_1 \
BASE_ADDRESS_2 \
BASE_ADDRESS_3 \
BASE_ADDRESS_4 \
BASE_ADDRESS_5 \
CARDBUS_CIS \
SUBSYSTEM_VENDOR_ID \
SUBSYSTEM_ID \
ROM_ADDRESS \
INTERRUPT_LINE \
INTERRUPT_PIN \
MIN_GNT \
MAX_LAT \
PRIMARY_BUS \
SECONDARY_BUS \
SUBORDINATE_BUS \
SEC_LATENCY_TIMER \
IO_BASE \
IO_LIMIT \
SEC_STATUS \
MEMORY_BASE \
MEMORY_LIMIT \
PREF_MEMORY_BASE \
PREF_MEMORY_LIMIT \
PREF_BASE_UPPER32 \
PREF_LIMIT_UPPER32 \
IO_BASE_UPPER16 \
IO_LIMIT_UPPER16 \
BRIDGE_ROM_ADDRESS \
BRIDGE_CONTROL"

# Check the command line parameters
FFLAG=
while getopts f: name ; do
	case $name in
		f) FFLAG=1
		   FILE="$OPTARG";;
		*) printf "Usage: %s: [-f dumpfile] [device]\n" $0
		   exit 2;;
	esac
done
shift $(($OPTIND - 1))

# Handle the device name
if [ $# -gt 0 ] ; then
        DEVICE="-s $1"
else
        DEVICE="-d feed:0001"
fi

# Process the filename flag if specified
if [ ! -z "$FFLAG" ]; then
	# Remove the dump file if it exists
	if [ -f "$FILE" ] ; then
		rm $FILE
	fi

	# Redirect stdout to the requested file
	exec 1>$FILE
fi

# Dump the registers
echo "Dumping registers..." >&2
for REG in $REGS ; do
	echo -n "$REG="
	/sbin/setpci $DEVICE $REG
done

# Close stdout
if [ ! -z "$FFLAG" ]; then
	exec 1>&-
fi

echo "Done" >&2
