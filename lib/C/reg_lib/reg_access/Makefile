#
# $Id: Makefile 4566 2008-10-11 01:47:15Z jnaous $
#

CFLAGS = -g
CC = gcc
LDFLAGS = -lnf2regs

# Location of binary files
BINDIR ?= /usr/local/bin

all : regread regwrite

regread : regread.o
regwrite : regwrite.o

regread.c: ../../reg_access/regread.c
	cp ../../reg_access/regread.c .
	patch -p0 <regread.patch

regwrite.c: ../../reg_access/regwrite.c
	cp ../../reg_access/regwrite.c .
	patch -p0 <regwrite.patch

clean :
	rm -rf regread regwrite *.o

install: regread regwrite
	install regread $(BINDIR)
	install regwrite $(BINDIR)

.PHONY: all clean install

