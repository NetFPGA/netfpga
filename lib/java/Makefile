#
# Run make in each of the subdirectories
#

SUBDIRS = gui

# Install the various files
subdirs: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean install:
	for dir in $(SUBDIRS) ; do \
		$(MAKE) -C $$dir $@; \
	done

.PHONY: install subdirs $(SUBDIRS) clean
