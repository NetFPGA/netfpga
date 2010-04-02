#
# $Id:
#

# Binary files to install
BITFILES = cpci.bit cpci_reprogrammer.bit

# NF_DIR
NF_DIR = /usr/local/netfpga

# Bitfile dir
BITFILE_DIR = $(NF_DIR)/bitfiles

# Install the various files
all:

# Install the various files
install:
	for bitfile in $(BITFILES) ; do \
		install -D -m 0644 $$bitfile $(BITFILE_DIR)/$$bitfile ; \
	done

clean:

.PHONY: all install clean
