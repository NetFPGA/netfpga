#
# Run make in each of the subdirectories
# $Id: Makefile 2961 2007-11-17 00:54:07Z g9coving $
#

SUBDIRS = cpci_reprogram cpci_config_reg_access

# Install the various files
subdirs: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean install:
	for dir in $(SUBDIRS) ; do \
		$(MAKE) -C $$dir $@; \
	done

.PHONY: install subdirs $(SUBDIRS)
