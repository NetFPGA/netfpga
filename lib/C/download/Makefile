#
# $Id: Makefile 6051 2010-04-01 16:27:04Z grg $
#

CFLAGS = -g
CC = gcc

# Location of binary files
BINDIR ?= /usr/local/bin

# Location of common files
COMMON = ../common



all: common nf_download

nf_download : nf_download.o $(COMMON)/nf2util.o

common:
	$(MAKE) -C $(COMMON)

clean :
	rm -rf nf_download *.o

install: nf_download
	install nf_download $(BINDIR)

.PHONY: all clean install
