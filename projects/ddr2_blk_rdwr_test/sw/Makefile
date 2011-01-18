
CFLAGS = -g
CC = gcc
LDFLAGS = -lncurses
LIBS = -L/usr/lib -lnet -lpcap -lnsl -lm -lresolv
SRLIBS = -lpthread

all : throughput

throughput: throughput.o $(NF_ROOT)/lib/C/common/nf2util.o $(NF_ROOT)/lib/C/common/nf2util_proxy_common.o

clean :
	rm -f throughput *.o *~


