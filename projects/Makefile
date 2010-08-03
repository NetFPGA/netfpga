#
# Build the register defines for *all* projects
#

# Identify which projects have Makefiles
projects := $(subst /,, $(dir $(wildcard */Makefile)))

all: $(projects)

$(projects):
	$(MAKE) -C $@

.PHONY: all $(projects)
