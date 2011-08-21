#
# Build the registers/software for the project
#

PROJECT = $(notdir $(CURDIR))
ifneq ($(wildcard include/project.xml),)
	TARGETS += regs
endif
ifneq ($(wildcard sw/Makefile),)
	TARGETS += sw
endif
ifneq ($(wildcard ../reference_router/lib/Python/RegressRouterLib.py),)
	TARGETS += lib/Python/RegressRouterLib.py
endif

all: $(TARGETS)

regs: include/registers.v

lib/Python/RegressRouterLib.py:
	ln -f -s ../../../reference_router/lib/Python/RegressRouterLib.py lib/Python/RegressRouterLib.py
	ln -f -s ../../../reference_router/lib/Python/RouterLib.py lib/Python/RouterLib.py

include/registers.v: include/project.xml
	$(NF_ROOT)/bin/nf_register_gen.pl --project $(PROJECT)

sw:
	$(MAKE) -C sw

.PHONY:	all sw regs
