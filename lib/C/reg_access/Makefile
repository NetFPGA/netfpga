#
# $Id: Makefile 2957 2007-11-17 00:42:42Z g9coving $
#

CFLAGS = -g
CC = gcc

# Location of binary files
BINDIR ?= /usr/local/bin

INSTALL_PREFIX ?= /usr/local

# Location of common files
COMMON = ../common

all : common regread regwrite

# Add Xen proxy client library for register access
ifeq ($(TARGET),xen)

    regread : regread.o $(INSTALL_PREFIX)/lib/libreg_proxy.so $(COMMON)/reg_defines.h
    regwrite : regwrite.o $(INSTALL_PREFIX)/lib/libreg_proxy.so $(COMMON)/reg_defines.h

else

    regread : regread.o ../common/nf2util.o
    regwrite : regwrite.o ../common/nf2util.o

endif


common:
	$(MAKE) -C $(COMMON)

clean :
	rm -rf regread regwrite *.o

install: regread regwrite
	install regread $(BINDIR)
	install regwrite $(BINDIR)

.PHONY: all clean install

