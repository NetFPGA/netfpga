####################################################
# Makefile to create java class file for regression
#
# Author: G. Adam Covington
#

JAVAC := javac

# Reference router JAR
JARFILE := $(NF_ROOT)/lib/java/gui/router_gui.jar

# Setup the classpath
CLASSPATH := $(JARFILE):$(subst $(SPACE),:,$(wildcard $(LIB)/*.jar))

all: java

java:
	@echo Building java...
	@$(JAVAC) -classpath $(CLASSPATH) *.java
	@echo done

install:

clean:
	@rm -rf *.class
