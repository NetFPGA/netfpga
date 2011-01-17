
CFLAGS = -g
CC = gcc
LDFLAGS = -lncurses
LIBS = -L/usr/lib -lpcap -lnsl -lm -lresolv -lnet
SRLIBS = -lpthread

INSTALL_PREFIX ?= /usr/local
COMMON = $(NF_ROOT)/lib/C/common

# Include appropriate library modules depending upon whether we're compiling
# for Xen
ifeq ($(TARGET),xen)
    NF_UTIL_LIB = $(INSTALL_PREFIX)/lib/libreg_proxy.so
else
    NF_UTIL_LIB = $(COMMON)/nf2util.o $(COMMON)/nf2util_proxy_common.o
endif

all : registers selftest bad_pkt_dump

registers:
	$(NF_ROOT)/bin/nf_register_gen.pl --project selftest
	$(NF_ROOT)/bin/nf_register_gen.pl --project cpci

selftest: selftest.o \
	selftest_dram.o \
	selftest_sram.o \
	selftest_serial.o \
	selftest_phy.o \
	selftest_mdio.o \
	selftest_reg.o \
	selftest_clk.o \
	selftest_dma.o or_ip.o or_utils.o \
	$(NF_UTIL_LIB) \

bad_pkt_dump: bad_pkt_dump.o $(NF_UTIL_LIB)

clean :
	rm -f selftest bad_pkt_dump *.o FAIL selftest.log

install:

