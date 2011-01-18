CFLAGS = -g
CC = gcc
LDFLAGS = -lncurses
LIBS = -L/usr/lib -lnet -lpcap

all : monitor_ctrl rcv_evts

monitor_ctrl: monitor_ctrl.o ../../../lib/C/common/nf2util.o ../../../lib/C/common/nf2util_proxy_common.o
	$(CC) $(CFLAGS) -o monitor_ctrl monitor_ctrl.c ../../../lib/C/common/nf2util.o ../../../lib/C/common/nf2util_proxy_common.o

rcv_evts: rcv_evts.o ../../../lib/C/common/nf2util.o ../../../lib/C/common/nf2util_proxy_common.o
	$(CC) $(CFLAGS) -o rcv_evts rcv_evts.c ../../../lib/C/common/nf2util.o ../../../lib/C/common/nf2util_proxy_common.o $(LIBS)

clean :
	rm monitor_ctrl rcv_evts *.o

install:
