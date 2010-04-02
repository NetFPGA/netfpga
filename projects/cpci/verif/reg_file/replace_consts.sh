#!/bin/sh

# Shell scripts to replace constants in a verilog file

# Target file - file on which to perform replacement
TARGET=reg_file_tb.v

# Source file - file from which to extract constants
SRC=../../../common/src/defines.v

# Constants to replace
CONSTS="CPCI_VERSION_ID CPCI_REVISION_ID"

# Create the "new" name
DEST=`basename $TARGET .v`.new.v
cp $TARGET $DEST

# Loop through the consts and perform the replacement
for CONST in $CONSTS ; do
	# Grep the original file for the constant
	VALUE=`grep "define.*$CONST" $SRC | awk '{ print $3 }'`

	# Create a temporary file
	TMP=`mktemp $TARGET.XXXXXX`

	# Substitute the constant
	sed "s/\\(\`define \\+$CONST\\).*/\\1 $VALUE/" $DEST > $TMP

	# Remove the temp file
	mv $TMP $DEST
done
