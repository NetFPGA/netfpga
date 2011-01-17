#
# $Id: Makefile 6054 2010-04-01 16:33:06Z grg $
#

CFLAGS = -g
CC = gcc

# Location of binary files
BINDIR ?= /usr/local/bin

# Location of common files
COMMON = ../../common



all: common nf_info

nf_info : nf_info.o $(COMMON)/nf2util.o $(COMMON)/nf2util_proxy_common.o

common:
	$(MAKE) -C $(COMMON)

clean :
	rm -rf nf_info *.o

install: nf_info
	install nf_info $(BINDIR)

.PHONY: all clean install
