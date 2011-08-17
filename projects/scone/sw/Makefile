#------------------------------------------------------------------------------
# File: Makefile
# Date: Tue Feb 03 15:03:51 PST 2004
# Author: Martin Casado
#
# Note: This Makefile requires GNU make.
#
# (c) 2001,2000 Stanford University
#
#------------------------------------------------------------------------------

all : registers scone

CC  = gcc

OSTYPE = $(shell uname)

ifeq ($(OSTYPE),Linux)
ARCH = -D_LINUX_
SOCK = -lnsl
endif

ifeq ($(OSTYPE),SunOS)
ARCH =  -D_SOLARIS_
SOCK = -lnsl -lsocket
endif

ifeq ($(OSTYPE),Darwin)
ARCH = -D_DARWIN_
SOCK =
endif

registers:
	$(NF_ROOT)/bin/nf_register_gen.pl --project reference_router
	ln -f -s $(NF_ROOT)/projects/reference_router/lib/C/reg_defines_reference_router.h reg_defines.h
	mkdir -p ../lib/Python
	ln -f -s ../../../reference_router/lib/Python/reg_defines_reference_router.py ../lib/Python/reg_defines_scone.py

# --
# To run the scone in "cpu" mode to interact with the NetFPGA uncomment
# the last flag (-D_CPUMODE_)
# --

#CFLAGS = -g -Wall -D_DEBUG_ $(ARCH) -I lwtcp -D_GNU_SOURCE
#Define _NOLWIP_ to bind to use linux sockets and bind to localhost
CFLAGS = -g -Wall -D_DEBUG_ $(ARCH) -I lwtcp -I ../../../lib/C/common -D_GNU_SOURCE -D_CPUMODE_

LIBS= $(SOCK) -lm -lresolv -lpthread -lpcap -lnet
PFLAGS= -follow-child-processes=yes -cache-dir=/tmp/${USER}
PURIFY= purify ${PFLAGS}

#------------------------------------------------------------------------------
LWTCP_SRCS = lwtcp/tcp.c lwtcp/tcp_input.c lwtcp/tcp_output.c\
             lwtcp/mem.c lwtcp/memp.c lwtcp/stats.c lwtcp/sys.c\
             lwtcp/inet.c lwtcp/pbuf.c lwtcp/sys_arch.c\
			 lwtcp/sockets.c lwtcp/api_lib.c lwtcp/api_msg.c\
			 lwtcp/transport_subsys.c lwtcp/udp.c lwtcp/icmp.c lwtcp/ip_addr.c\
			 lwtcp/err.c

LWTCP_OBJS = $(patsubst lwtcp/%.c, %.o, $(LWTCP_SRCS))


liblwtcp.a : $(LWTCP_OBJS)
	ar rcu liblwtcp.a $(LWTCP_OBJS)
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
SR_BASE_SRCS = sr_base.c sr_dumper.c sr_integration.c sr_lwtcp_glue.c\
               sr_vns.c sr_cpu_extension_nf2.c or_main.c or_utils.c\
               or_arp.c or_icmp.c or_ip.c or_iface.c or_rtable.c\
		       or_output.c or_cli.c or_vns.c or_sping.c or_pwospf.c\
		       or_dijkstra.c or_netfpga.c or_www.c or_nat.c

SR_BASE_OBJS = $(patsubst %.c,%.o,$(SR_BASE_SRCS)) nf2/nf2util.o

libsr_base.a : $(SR_BASE_OBJS)
	ar rcu libsr_base.a $(SR_BASE_OBJS)
#------------------------------------------------------------------------------


#------------------------------------------------------------------------------
SR_SRCS =  sr_main.c

SR_OBJS = $(patsubst %.c,%.o,$(SR_SRCS))

scone : $(SR_OBJS) libsr_base.a liblwtcp.a
	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

purify : $(SR_OBJS) libsr_base.a liblwtcp.a
	purify $(CC) $(CFLAGS) -o $@.purify $^ $(LIBS)

#------------------------------------------------------------------------------

DIJKSTRA_SRCS = or_dijkstra_test.c

DIJKSTRA_OBJS = $(patsubst %.c,%.o,$(DIJKSTRA_SRCS))

dijkstra-test : $(DIJKSTRA_OBJS) libsr_base.a liblwtcp.a -lnet
	$(CC) $(CFLAGS) -o dijkstra-test $^ $(LIBS)

RAWSOCK_SRCS = rawsock.c

RAWSOCK_OBJS = $(patsubst %.c,%.o,$(RAWSOCK_SRCS)) nf2/nf2util.o

rawsock : $(RAWSOCK_OBJS) libsr_base.a liblwtcp.a -lnet
	$(CC) $(CFLAGS) -o rawsock $^ $(LIBS)

#------------------------------------------------------------------------------
ALL_SRCS   = $(sort $(SR_SRCS) $(SR_BASE_SRCS) $(LWTCP_SRCS))

ALL_LWTCP_SRCS = $(filter lwtcp/%.c, $(ALL_SRCS))
ALL_SR_SRCS    = $(filter-out lwtcp/%.c, $(ALL_SRCS))

ALL_LWTCP_OBJS = $(patsubst lwtcp/%.c,%.o, $(ALL_LWTCP_SRCS))
ALL_SR_OBJS    = $(patsubst %.c,%.o, $(ALL_SR_SRCS))

ALL_LWTCP_DEPS = $(patsubst lwtcp/%.c,.%.d,$(ALL_LWTCP_SRCS))
ALL_SR_DEPS    = $(patsubst %.c,.%.d,$(ALL_SR_SRCS))

$(ALL_SR_OBJS) : %.o : %.c
	$(CC) -c $(CFLAGS) $< -o $@
$(ALL_LWTCP_OBJS) : %.o : ./lwtcp/%.c
	$(CC) -c $(CFLAGS) $< -o $@

$(ALL_LWTCP_DEPS) : .%.d : ./lwtcp/%.c
	$(CC) -MM $(CFLAGS) -I lwtcp/ $<  > $@
$(ALL_SR_DEPS) : .%.d : %.c
	$(CC) -MM $(CFLAGS) -I lwtcp/ $<  > $@

include $(ALL_LWTCP_DEPS)
include $(ALL_SR_DEPS)

#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
.PHONY : clean clean-deps dist install

clean:
	rm -f *.o *~ core.* scone *.dump *.tar tags *.a test_arp_subsystem\
          lwcli lwtcpsr sr_base.tar.gz

clean-deps:
	rm -f .*.d

dist: clean clean-deps
	(cd ..; tar --exclude-from=base/exclude -cvf sr_base.tar base/; gzip sr_base.tar; mv\
    sr_base.tar.gz base/)

tags:
	ctags *.c

install:


#------------------------------------------------------------------------------
