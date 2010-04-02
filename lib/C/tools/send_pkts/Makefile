
#CFLAGS = -g
CFLAGS = -O2
CC = gcc
LIBS = -L/usr/lib -lnet -lpcap --static
LIBNET_CONFIG_PRE = `libnet-config --defines --cflags`
LIBNET_CONFIG_POST = `libnet-config --libs`

send_pkts: send_pkts.c ../../common/nf2util.o
	$(CC) $(LIBNET_CONFIG_PRE) $(CFLAGS) -o send_pkts send_pkts.c $(LIBNET_CONFIG_POST) $(LIBS)

clean :
	rm send_pkts *.o
