# simple Makefile to build and install all of our Wireshark plugins

# build a list of all sub-directories except the includes path
PLUGIN_DIRS = $(shell ls -l | grep "^d" | cut -d: -f2- | cut -d\  -f2 | fgrep -v 'wireshark-1.0.0-includes')
CLEAN_PLUGIN_DIRS = $(foreach dir,$(PLUGIN_DIRS),clean$(dir))

.PHONY: all $(PLUGIN_DIRS) clean $(CLEAN_PLUGIN_DIRS)

# build all the plugins
all:
	@make $(PLUGIN_DIRS)

# cleanup all the byproducts (including the plugin itself)
clean:
	@make $(CLEAN_PLUGIN_DIRS)

# build the plugin in the specified directory using its default rule
$(PLUGIN_DIRS):
	@gmake --no-print-directory -C $@

# cleans up the plugin in the specified directory using its 'clean' rule
$(CLEAN_PLUGIN_DIRS):
	@gmake --no-print-directory -C `echo $@ | sed -e "s#^clean##"` clean
