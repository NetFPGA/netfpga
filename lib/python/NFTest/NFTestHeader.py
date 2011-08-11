#!/bin/env python

# project register defines
import sys
import os
sys.path.append(os.path.abspath(os.environ['NF_DESIGN_DIR']+'/lib/Python'))
project = os.path.basename(os.environ['NF_DESIGN_DIR'])
if project == '':
    project = os.path.basename(os.environ['NF_DESIGN_DIR'][0:-1])
reg_defines = __import__('reg_defines_'+project)

# scapy
try:
    import scapy.all as scapy
except:
    try:
        import scapy as scapy
    except:
        sys.exit("Error: need to install scapy for packet handling")
