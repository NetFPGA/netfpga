#
# Run make in each of the subdirectories
# $Id: Makefile 5954 2010-02-26 22:13:27Z grg $
#

SUBDIRS = kernel download reg_access tools

# Install the various files
subdirs: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean install:
	for dir in $(SUBDIRS) ; do \
		$(MAKE) -C $$dir $@; \
	done

.PHONY: install subdirs $(SUBDIRS) clean
