
# Run make in each of the subdirectories
# $Id: Makefile 5765 2009-07-22 20:58:24Z g9coving $
#

SUBDIRS = lib bitfiles projects/scone/sw projects/selftest/sw projects/reference_router/sw projects/router_buffer_sizing/sw projects/router_kit/sw

# Install the various files
subdirs: $(SUBDIRS)

$(SUBDIRS):
	if [ -f "$@/Makefile" ] ; then \
		$(MAKE) -C $@ ; \
	fi

clean install:
	for dir in $(SUBDIRS) ; do \
		if [ -f "$$dir/Makefile" ] ; then \
			$(MAKE) -C $$dir $@; \
		fi \
	done

.PHONY: install subdirs $(SUBDIRS) clean
