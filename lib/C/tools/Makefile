#
# Run make in each of the subdirectories
# $Id: Makefile 6054 2010-04-01 16:33:06Z grg $
#

SUBDIRS = nf_info

# Install the various files
subdirs: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean install:
	for dir in $(SUBDIRS) ; do \
		$(MAKE) -C $$dir $@; \
	done

.PHONY: install subdirs $(SUBDIRS) clean
