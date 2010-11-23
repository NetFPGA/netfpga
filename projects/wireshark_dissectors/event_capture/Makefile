WIRESHARK_SRC_DIR = ../wireshark-1.0.0-includes

SRCS   = packet-eventcap.c plugin.c
CC     = gcc
OBJS   = $(foreach src, $(SRCS), $(src:.c=.o))

PLUGIN_NAME = packet-eventcap
PLUGIN_DIR  = ~/.wireshark/plugins
PLUGIN      = $(PLUGIN_DIR)/$(PLUGIN_NAME).so

# specify the port on which event capture packets will be destined
DISSECT_PORT = -DEVENTCAP_DST_UDP_PORT=27033

OSTYPE = $(shell uname)
ifeq ($(OSTYPE),Linux)
ENDIAN=-D_LITTLE_ENDIAN_
endif
ifeq ($(OSTYPE),SunOS)
ENDIAN=-D_BIG_ENDIAN_
endif

INC_DIRS   = -I. -I/usr/openwin/include -I/usr/include/glib-2.0
CFLAGS = $(INC_DIRS) -DHAVE_CONFIG_H -I$(WIRESHARK_SRC_DIR) -I/usr/local/include -I/usr/local/include -DINET6 -D_U_=__attribute__\(\(unused\)\) -Wall -Wpointer-arith -g -I/usr/local/include -DXTHREADS -D_REENTRANT -DXUSE_MTSAFE_API -pthread -I/usr/include/gtk-2.0 -I/usr/lib/gtk-2.0/include -I/usr/X11R6/include -I/usr/include/atk-1.0 -I/usr/include/pango-1.0 -I/usr/include/freetype2 -I/usr/include/freetype2/config -I/usr/local/include/glib-2.0 -I/usr/lib/glib-2.0/include -fPIC -DPIC $(ENDIAN) $(DISSECT_PORT)

LDFLAGS = -Wl,--rpath -Wl,/usr/local/lib -Wl,--rpath -Wl,/usr/local/lib -L/usr/local/lib -L$(WIRESHARK_SRC_DIR)/epan -L. -lgmodule-2.0 -ldl -lglib-2.0  -pthread -Wl,--export-dynamic -Wl,-soname -Wl,$(PLUGIN_NAME).so

$(PLUGIN) : $(OBJS)
	mkdir -p $(PLUGIN_DIR)
	$(CC) -shared $(OBJS) $(LDFLAGS) -o $@

plugin.c: moduleinfo.h Makefile.am Makefile.common
	make -f Makefile.am

%.o : %.c eventcap.h
	$(CC) -c $(CFLAGS) $< -o $@

clean:
	rm -f $(PLUGIN) $(OBJS)
