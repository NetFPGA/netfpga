#
# $Id: Makefile 6042 2010-04-01 05:59:23Z grg $
#

CFLAGS = -g
CC = gcc
LDFLAGS = -lncurses

all : registers counterdump

registers:
	$(NF_ROOT)/bin/nf_register_gen.pl --project reference_nic

counterdump : counterdump.o ../../../lib/C/common/nf2util.o ../../../lib/C/common/nf2util_proxy_common.o ../lib/C/reg_defines_reference_nic.h

clean :
	rm -f counterdump *.o ../../../lib/C/common/nf2util.o ../../../lib/C/common/nf2util_proxy_common.o

install:

.PHONY: all clean install
