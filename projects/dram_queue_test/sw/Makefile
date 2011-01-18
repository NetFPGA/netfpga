#
# $Id: Makefile 3739 2008-05-15 21:04:00Z grg $
#

CFLAGS = -g -I ../../../lib/C/common
CC = gcc
LDFLAGS = -lncurses

all : regdump shortcut_disable

regdump : regdump.o $(NF_ROOT)/lib/C/common/nf2util.o $(NF_ROOT)/lib/C/common/nf2util_proxy_common.o $(NF_ROOT)/lib/C/common/reg_defines.h

shortcut_disable : shortcut_disable.o $(NF_ROOT)/lib/C/common/nf2util.o $(NF_ROOT)/lib/C/common/nf2util_proxy_common.o $(NF_ROOT)/lib/C/common/reg_defines.h

clean :
	rm -f regdump *.o
	rm -f shortcut_disable *.o

install:

.PHONY: all clean install
