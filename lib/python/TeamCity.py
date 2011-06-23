#!/usr/bin/env python
import re

oe = 1

def tcGetTestSeparator():
    return ' - '

def tcTestStarted(test):
    if oe:
        print "##teamcity[testStarted name='" + str(test) + "']"

def tcTestFailed(test, msg, details):
    if oe:
        re.sub("'", "|'", msg)
        re.sub("\n", "|n", msg)
        re.sub("\r", "|r", msg)

        re.sub("'", "|'", details)
        re.sub("\n", "|n", details)
        re.sub("\r", "|r", details)

        if details == '':
            details = msg

        print "##teamcity[testFailed name='" + str(test) + "' message='" + str(msg) + "' details='" + str(details) + "']"

def tcTestFinished(test):
    if oe:
        print "##teamcity[testFinished name='" + str(test) + "']"

def tcEnableOutput():
    global oe
    oe = 1

def tcDisableOutput():
    global oe
    oe = 0

def tcIsEnabled():
    return oe
