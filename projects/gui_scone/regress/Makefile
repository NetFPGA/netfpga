#
# Run make in each of the subdirectories
# $Id: Makefile 5441 2009-05-05 00:15:26Z g9coving $
#

SUBDIRS = test_arp_table test_main_frame test_popup test_port_config_table test_reg_update_rt test_routing_table

# Install the various files
subdirs: $(SUBDIRS)

$(SUBDIRS):
	$(MAKE) -C $@

clean install:
	or dir in $(SUBDIRS) ; do \
		$(MAKE) -C $$dir $@; \
	done

.PHONY: install subdirs $(SUBDIRS) clean
