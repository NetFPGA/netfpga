#
# $Id: Makefile 2397 2007-10-11 21:06:08Z grg $
#

CFLAGS = -g
CC = gcc
LDFLAGS = -lnf2regs
COMMON = ../common
SRCS = reg_proxy_server.c reg_proxy_client.c reg_proxy.c $(COMMON)/nf2util_proxy_common.c

INSTALL_PREFIX ?= /usr/local

all : reg_proxy_server client_test

reg_proxy_server : reg_proxy_server.o reg_proxy.o $(COMMON)/reg_defines.h $(COMMON)/nf2util.h

client_test : libreg_proxy.so client_test.o $(COMMON)/reg_defines.h

libreg_proxy.so: reg_proxy_client.c $(COMMON)/nf2util_proxy_common.c reg_proxy.c reg_proxy.h $(COMMON)/nf2util.h
	$(CC) -fpic -c reg_proxy_client.c reg_proxy.c $(COMMON)/nf2util_proxy_common.c
	$(CC) -shared reg_proxy_client.o reg_proxy.o nf2util_proxy_common.o -o $@

clean :
	rm -f reg_proxy_server client_test *.o *.so

install_client_lib: libreg_proxy.so
	install -d $(INSTALL_PREFIX)/lib
	install -m 644 libreg_proxy.so $(INSTALL_PREFIX)/lib
	rm -f $(INSTALL_PREFIX)/lib/libnf2regs.so
	ln -s $(INSTALL_PREFIX)/lib/libreg_proxy.so $(INSTALL_PREFIX)/lib/libnf2regs.so
	ldconfig

../common/libnf2.so:
	$(MAKE) -C $(COMMON) libnf2.so

install_server_lib: $(COMMON)/libnf2.so
	install -d $(INSTALL_PREFIX)/lib
	install -m 644 $(COMMON)/libnf2.so $(INSTALL_PREFIX)/lib
	rm -f $(INSTALL_PREFIX)/lib/libnf2regs.so
	ln -s $(INSTALL_PREFIX)/lib/libnf2.so $(INSTALL_PREFIX)/lib/libnf2regs.so
	ldconfig

install_server: uninstall_server reg_proxy_server
	install -d $(INSTALL_PREFIX)/sbin
	install -m 700 reg_proxy_server $(INSTALL_PREFIX)/sbin/netfpga.regproxy_server
	install -m 700 netfpga.regproxy_server.init /etc/init.d/netfpga.regproxy_server
	ln -s /etc/init.d/netfpga.regproxy_server $(INSTALL_PREFIX)/sbin/rcnetfpga.regproxy_server
	install -m 644 netfpga.regproxy_server.config /etc/sysconfig/netfpga.regproxy_server

uninstall_server: reg_proxy_server
	rm -f $(INSTALL_PREFIX)/sbin/netfpga.regproxy_server
	rm -f /etc/init.d/netfpga.regproxy_server
	rm -f $(INSTALL_PREFIX)/sbin/rcnetfpga.regproxy_server
	rm -f /etc/sysconfig/netfpga.regproxy_server

.PHONY: all clean install
