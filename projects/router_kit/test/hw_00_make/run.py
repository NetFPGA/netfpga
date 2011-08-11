#!/bin/env python

import os
import subprocess

cwd = os.getcwd()
os.chdir(os.environ['NF_DESIGN_DIR'])

subprocess.call("make")

os.chdir(cwd)
