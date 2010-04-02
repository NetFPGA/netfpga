#Comment/uncomment the following line to disable/enable debugging
# DEBUG = y


# Add your debugging flag (or not) to EXTRA_CFLAGS
ifeq ($(DEBUG),y)
  DEBFLAGS = -O -g -DNF2_DEBUG # "-O" is needed to expand inlines
else
  DEBFLAGS = -O2
endif

EXTRA_CFLAGS += $(DEBFLAGS)
EXTRA_CFLAGS += -I$(LDDINC)

ifneq ($(KERNELRELEASE),)
# call from kernel build system

nf2-objs	:= nf2main.o nf2_control.o nf2util.o nf2_ethtool.o

obj-m	:= nf2.o

else

KERNELDIR ?= /lib/modules/$(shell uname -r)/build
PWD       := $(shell pwd)

modules:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) LDDINC=$(PWD)/../include modules

endif



clean:
	rm -rf *.o *~ core .depend .*.cmd *.ko *.mod.c .tmp_versions

depend .depend dep:
	$(CC) $(EXTRA_CFLAGS) -M *.c > .depend


ifeq (.depend,$(wildcard .depend))
include .depend
endif

install: modules
	install -m 644 nf2.ko /lib/modules/`uname -r`/kernel/drivers/nf2.ko
	/sbin/depmod -a
