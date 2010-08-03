#
# Run make in each of the subdirectories
#

# Set environment variables to correspond to the current working directory
export NF_ROOT = $(CURDIR)
export PERL5LIB := $(CURDIR)/lib/Perl5:$(PERL5LIB)


# List of directories in which we should build
SUBDIRS = lib bitfiles projects


# Install the various files
subdirs: $(SUBDIRS)

$(SUBDIRS):
	echo $(PERL5LIB)
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
