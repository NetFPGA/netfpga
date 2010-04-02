#
# $Id: Makefile 6051 2010-04-01 16:27:04Z grg $
#

CFLAGS = -g --static
CC = gcc
LDFLAGS = -lnf2regs

# Location of binary files
BINDIR ?= /usr/local/bin

all: nf_download.h nf_download

nf_download : nf_download.o

nf_download.c: ../../download/nf_download.c
	cp ../../download/nf_download.c .
	patch -p0 <nf_download.patch

nf_download.h: ../../download/nf_download.h
	cp ../../download/nf_download.h .

clean :
	rm -rf nf_download *.o nf_download.c nf2_dowload.h

install: nf_download
	install nf_download $(BINDIR)

.PHONY: all clean install
