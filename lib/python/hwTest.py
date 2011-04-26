#!/usr/bin/python

import subprocess
from nf_test import args
from nf_test import rootDir as _ROOT_DIR
import os
import re

REQUIRED = 1
OPTIONAL = 0

teardown = 'teardown'
setup = 'setup'
run = 'run'
commonDir = 'common'
globalDir = 'global'
projectRoot = 'projects'
testRoot = 'test'

if args.common_setup:
    commonSetup = args.common_setup
else:
    commonSetup = setup
if args.common_teardown:
    commonTeardown = args.common_teardown
else:
    commonTeardown = teardown

def runTest(project, test):
    testDir = _ROOT_DIR + '/' + projectRoot + '/' + project + '/' + testRoot + '/' + test
    if os.path.exists(testDir) and os.path.isdir(testDir):
        return runScript(project, test, run + ' --hw', REQUIRED)
    else:
        match = re.search(r'/(.*)\/([^\/]*)/', test)
        if match:
            return runScript(project, match.group(1), match.group(2) + ' --hw', REQUIRED)
        else:
            print 'Error finding test file: ' + test
            sys.exit(1)

def runGlobalSetup(project):
    return runScript(project, globalDir, setup, OPTIONAL)

def runGlobalTeardown(project):
    return runScript(project, globalDir, teardown, OPTIONAL)

def runCommonSetup(project):
    return runScript(project, commonDir, commonSetup, OPTIONAL)

def runCommonTeardown(project):
    return runScript(project, commonDir, commonTeardown, OPTIONAL)

def runLocalSetup(project, test):
    match = re.search(r'/(.*)\/([^\/]*)/', test)
    if match:
        return runScript(project, match.group(1), teardown, OPTIONAL)
    else:
        return runScript(project, test, teardown, OPTIONAL)

def runLocalTeardown(project, test):
    match = re.search(r'/(.*)\/([^\/]*)/', test)
    if match:
        return runScript(project, match.group(1), teardown, OPTIONAL)
    else:
        return runScript(project, test, teardown, OPTIONAL)

def runScript(project, subdir, script, required):
    testDir = _ROOT_DIR + '/' + projectRoot + '/' + project + '/' + testRoot + '/' + subdir
    cmd = testDir + '/' + script
    if args.map:
        cmd += ' --map ' + args.map

    status = 0
    output = ''

    origDir = os.getcwd()

    try:
        os.chdir(testDir)
        process = subprocess.Popen(cmd.split(), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        output = process.communicate()[0]
        status = process.returncode
    except OSError as exc:
        if required == REQUIRED:
            print 'Unable to run test ' + script + ' for project ' + project
            print exc.strerror, exc.filename
        else:
            return (1, '')
    finally:
        os.chdir(origDir)

    if status is not 0:
        print cmd + ' exited with value ' + str(status)

    return (status == 0, output)

def printScriptOutput(result, output):
    if not args.quiet:
        if result:
            print 'PASS'
        else:
            print 'FAIL'
            print 'Output was:'
            print output
