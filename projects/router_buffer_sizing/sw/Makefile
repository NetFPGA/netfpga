CFLAGS = -g
CC = gcc
LDFLAGS = -lncurses
LIBS = -L/usr/lib -lnet -lpcap --static

all : monitor_ctrl rcv_evts

monitor_ctrl: monitor_ctrl.o ../../../lib/C/common/nf2util.o
	$(CC) $(CFLAGS) -o monitor_ctrl monitor_ctrl.c ../../../lib/C/common/nf2util.o

rcv_evts: rcv_evts.o ../../../lib/C/common/nf2util.o
	$(CC) $(CFLAGS) -o rcv_evts rcv_evts.c ../../../lib/C/common/nf2util.o $(LIBS)

clean :
	rm monitor_ctrl rcv_evts *.o

install:
