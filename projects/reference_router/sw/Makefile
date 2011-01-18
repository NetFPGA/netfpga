#
# $Id: Makefile 2397 2007-10-11 21:06:08Z grg $
#

CFLAGS = -g
CC = gcc
LDFLAGS = -lncurses

all : registers cli regdump show_stats

registers:
	$(NF_ROOT)/bin/nf_register_gen.pl --project reference_router

show_stats: show_stats.o ../../../lib/C/common/nf2util.o ../../../lib/C/common/nf2util_proxy_common.o ../../../lib/C/common/util.o ../lib/C/reg_defines_reference_router.h

cli : cli.o ../../../lib/C/common/nf2util.o ../../../lib/C/common/nf2util_proxy_common.o ../../../lib/C/common/util.o ../lib/C/reg_defines_reference_router.h

regdump : regdump.o ../../../lib/C/common/nf2util.o ../../../lib/C/common/nf2util_proxy_common.o ../lib/C/reg_defines_reference_router.h

clean :
	rm -f cli regdump show_stats *.o

install:

.PHONY: all clean install
