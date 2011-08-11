#----------------------------------------------------------------------
# File: Makefile
# Date: Sun Apr 29 18:03:40 PDT 2007
# Author: Martin Casado
#
#----------------------------------------------------------------------

all: registers common rkd

HEADERS  = rtable.hh arptable.hh nf21_mon.hh iflist.hh
CXXFLAGS = -g -Wall -ansi

registers:
	$(NF_ROOT)/bin/nf_register_gen.pl --project reference_router
	ln -f -s ../../reference_router/lib/C/reg_defines_reference_router.h reg_defines.h
	mkdir -p ../lib/Python
	ln -f -s ../../../reference_router/lib/Python/reg_defines_reference_router.py ../lib/Python/reg_defines_router_kit.py
	ln -f -s ../../../reference_router/lib/Python/RegressRouterLib.py ../lib/Python/RegressRouterLib.py
	ln -f -s ../../../reference_router/lib/Python/RouterLib.py ../lib/Python/RouterLib.py

common:
	ln -s ../../../lib/C/common/ common

rkd : rkd.cc linux_proc_net.o nf21_mon.o nf21_mon.o common/nf2util.o common/nf2util_proxy_common.o common/util.o $(HEADERS)
	g++ -g -Wall -o rkd rkd.cc nf21_mon.o common/nf2util.o common/util.o linux_proc_net.o

clean:
	rm -f *.o rkd common/*.o
	rm -rf ../lib/

install:
