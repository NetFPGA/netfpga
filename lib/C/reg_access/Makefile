#
# $Id: Makefile 2957 2007-11-17 00:42:42Z g9coving $
#

CFLAGS = -g
CC = gcc

# Location of binary files
BINDIR ?= /usr/local/bin

# Location of common files
COMMON = ../common



all : common regread regwrite

regread : regread.o ../common/nf2util.o
regwrite : regwrite.o ../common/nf2util.o

common:
	$(MAKE) -C $(COMMON)

clean :
	rm -rf regread regwrite *.o

install: regread regwrite
	install regread $(BINDIR)
	install regwrite $(BINDIR)

.PHONY: all clean install

