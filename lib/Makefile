#
# Run make in each of the subdirectories
# $Id: Makefile 5441 2009-05-05 00:15:26Z g9coving $
#

SUBDIRS = C scripts

# Work out if we have java in the system path, in which case we should recurse into the java directory as well
JAVA := $(shell which javac)
JAVAMAKE := $(wildcard java/Makefiles)

ifneq ($(JAVA), )
	ifneq ($(JAVAMAKE), )
		SUBDIRS += java
	endif
endif


# Install the various files
subdirs: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean install:
	for dir in $(SUBDIRS) ; do \
		$(MAKE) -C $$dir $@; \
	done

.PHONY: install subdirs $(SUBDIRS) clean
