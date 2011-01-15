#
# $Id: Makefile 6051 2010-04-01 16:27:04Z grg $
#

CFLAGS = -g
CC = gcc

# Location of binary files
BINDIR ?= /usr/local/bin

INSTALL_PREFIX ?= /usr/local

# Location of common files
COMMON = ../common

all: common nf_download

# Add Xen proxy client library for register access
ifeq ($(TARGET),xen)

    nf_download : $(INSTALL_PREFIX)/lib/libreg_proxy.so nf_download.o $(COMMON)/reg_defines.h

else

    nf_download : nf_download.o $(COMMON)/nf2util.o $(COMMON)/nf2util_proxy_common.o

endif

common:
	$(MAKE) -C $(COMMON)

clean :
	rm -rf nf_download *.o

install: nf_download
	install nf_download $(BINDIR)

.PHONY: all clean install
