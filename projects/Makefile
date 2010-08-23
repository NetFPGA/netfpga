#
# Build the register defines for *all* projects
#

# Identify which projects have Makefiles
projects := $(subst /,, $(dir $(wildcard */Makefile)))

all: $(projects)

$(projects):
	$(MAKE) -C $@

clean install:
	#for dir in $(projects) ; do \
	#	$(MAKE) -C $$dir $@; \
	#done

.PHONY: all clean install $(projects)
