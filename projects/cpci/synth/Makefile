# Simple makefile
#

# Specify the top level file
TOP = cpci_top

# Disable the use of smartguide
USE_SMARTGUIDE = 0

# Disable the use of timing switch
TIMING = 0

# Disallow removal of SCR file
KEEP_SCR = 0

# Exclude the utils directory when searching for modules
INCLUDE_UTILS = 0

# Use a local UCF file
LOCAL_UCF = 1

MAP_OPTIONS = -r

# Include the generic synthesis makefile for the variables
#include $(NF_ROOT)/lib/Makefiles/synth_makefile
include $(NF_ROOT)/lib/Makefiles/synth_makefile.funcs
include $(NF_ROOT)/lib/Makefiles/synth_makefile.vars

# Perform any variable updates here

# Remove pci_top.v from the list of cores
PCI_TOP_V := $(COREGEN_SRC_DIR)/pci_top.v
SRCS := $(filter-out $(PCI_TOP_V),$(SRCS))
ALL_SRCS := $(SRCS)
USER_CORE_SRCS := $(filter-out $(PCI_TOP_V),$(USER_CORES_SRCS))

# Add the two PCI sources
ifeq (,$(findstring $(COREGEN_SRC_DIR)/pci_lc_i.v, $(SRCS)))
	SRCS := $(SRCS) $(COREGEN_SRC_DIR)/pci_lc_i.v
	USER_CORE_SRCS := $(USER_CORE_SRCS) $(COREGEN_SRC_DIR)/pci_lc_i.v
	ALL_SRCS := $(SRCS)
endif
ifeq (,$(findstring $(COREGEN_SRC_DIR)/pcim_lc.v, $(SRCS)))
	SRCS := $(SRCS) $(COREGEN_SRC_DIR)/pcim_lc.v
	USER_CORE_SRCS := $(USER_CORE_SRCS) $(COREGEN_SRC_DIR)/pcim_lc.v
	ALL_SRCS := $(SRCS)
endif

# Remove pci_top.ngc from the list of cores and replace it with pci_lc_i.ngo
PCI_TOP_NGC := $(SYNTH_DIR)/pci_top.ngc
ALL_CORES := $(filter-out $(PCI_TOP_NGC),$(ALL_CORES)) $(SYNTH_DIR)/pci_lc_i.ngo
USER_CORES := $(filter-out $(PCI_TOP_NGC),$(USER_CORES)) $(SYNTH_DIR)/pci_lc_i.ngo

CORE_NAMES := $(filter-out $(notdir $(PCI_TOP_NGC)),$(CORE_NAMES)) pci_lc_i.ngo

##################################################################
# Rules
#

# Include the generic synthesis makefile for the rules
include $(NF_ROOT)/lib/Makefiles/synth_makefile.rules

all: $(TOP)_par.mcs

# Rule to build a .mcs/bitfile for a rev 0 board
.PHONY: rev0
rev0: cpci_top_r0_par.mcs
	@echo $(UCF)

cpci_top_r0.ngc: cpci_top.ngc
	@cp $< $@

# Phony rule for cpci_top.scr in the GENERIC_TOP directory -- don't
# actually do anything as this file shouldn't exist and we don't want
# to create it
#
$(GENERIC_TOP)/synth/$(TOP).scr: $(TOP).ucf

# Invoke coregen to create edn or ngc files etc needed for ngdbuild
# we create a temporary work directory, generate all the files and
# copy the verilog/edn/ngc files to the right places then remove the
# temp dir
#
pci_lc_i.ngo: pci_top.xco
	@echo ==================================================
	@echo "=== Invoking coregen to rebuild $@"
	@echo ==================================================
	@echo "+++testStarted:build.core.$(notdir $@)"
	@if [ -d $(COREGEN_WORK_DIR) ] ; then \
		rm -rf $(COREGEN_WORK_DIR)/* ; \
	else \
		mkdir $(COREGEN_WORK_DIR) ; \
	fi
	@cd $(COREGEN_WORK_DIR) ; \
	coregen -b $$OLDPWD/$< ; \
	cd -
	@if [ ! -r $(COREGEN_WORK_DIR)/pci_top/verilog/src/xpci/$@ ] ; then \
		echo "Could not find target file '$@'" ; \
		exit 1 ; \
	else \
		echo "Copying Verilog files to $(COREGEN_SRC_DIR)/" ; \
		if [ ! -d $(COREGEN_SRC_DIR) ] ; then \
			mkdir $(COREGEN_SRC_DIR) ; \
		fi ; \
		cp $(COREGEN_WORK_DIR)/pci_top/verilog/src/xpci/pci_lc_i.v $(COREGEN_SRC_DIR) ; \
		cp $(COREGEN_WORK_DIR)/pci_top/verilog/src/xpci/pcim_lc.v $(COREGEN_SRC_DIR) ; \
		cp $(COREGEN_WORK_DIR)/pci_top/verilog/src/xpci/pci_lc_i.ngo . ; \
	fi
	@rm -rf $(COREGEN_WORK_DIR)
	@echo "+++testFinished:build.core.$(notdir $@)"


# Make mcs file (for iMPACT)
%_par.mcs: %_par.bit
	@echo ==================================================
	@echo "=== Generate MCS file for iMPACT download"
	@echo ==================================================
	@echo "+++testStarted:build.promgen.$@"
	promgen -w -x xcf02s -u 0 $*_par
	@echo "+++testFinished:build.promgen.$@"

clean::
	rm -rf *.mcs *.prm
