#!/usr/bin/python
# Author: James Hsi
# Date:
#
#  Overarching test module. Creates and maintains file objects through file writes during tests.
# python -m pdb
#

import os

NUM_PORTS = 4;

#instantiation
f_ingress = [];

directory = 'packet_data'
dma_filename = 'ingress_dma'
pci_filename = 'pci_sim_data'
ingress_fileHeader = 'ingress_port_'

############################
# Function: init()
#   Creates the hardware and simulation files to be read by ModelSim,
############################
def init():
    if not os.path.isdir(directory):
        os.mkdir(directory)
    try:
        global f_dma; global f_pci;
        f_pci = open(directory+'/'+pci_filename,'w')
        f_dma = open(directory+'/'+dma_filename,'w')
    except IOError:
        print("File creation error")
    writeFileHeader(fPCI(), directory+'/'+pci_filename)
    writeFileHeader(fDMA(), directory+'/'+dma_filename)

    for i in range(NUM_PORTS):
        filename = ingress_fileHeader + str(i+1) #create a file for each port
        f_ingress.append(open(directory+'/'+filename, 'w'))
        writeFileHeader(fPort(i+1), directory+"/"+filename)


############################
# Function: writeFileHeader
#  Writes timestamp and general information to file head.
############################
def writeFileHeader(fp, filePath):
    from time import gmtime, strftime
    fp.write("//File "+filePath+" created "+strftime("%a %b %d %H:%M:%S %Y", gmtime())+"\n")
    fp.write("//\n//This is a data file intended to be read in by a Verilog simulation.\n//\n")


############################
# Function: close()
#   Closes all file pointers created during initialization. Must be called at the end of every test file.
############################
def close():
    f_dma.close()
    f_pci.close()

    for i in range(NUM_PORTS):
        f_ingress[i].close()

# Getters #################################################################


############################
# Function: fPCI
#  A Getter that returns the file pointer for file with register read/write info.
############################
def fPCI():
    return f_pci

############################
# Function: fDMA
#  A Getter that returns the file pointer for file with DMA read/write info.
############################
def fDMA():
    return f_dma


############################
# Function: fPHY
# Argument: port - int - port for which read/write is occurring (Should be 1-4, NOT THE INDEX OF ARRAY)
#  A Getter that returns the file pointer for file with PHY read/write info.
#
############################
def fPort(port):
    return f_ingress[port-1]

# Testing ########################################################

############################
# Function: simulate()
#  include option? no visuals right now
# wrong order
############################
def modelSim(usrName):
    #os.system("nf_run_test.pl --compile_only") #before running make_pkts.py
    os.system("MODELSIM=/tmp/"+usrName+'/verif/reference_nic/vsim_beh/modelsim.ini vsim -c -voptargs="+acc" testbench glbl -do "run -all"')
    #os.system('MODELSIM=<path_to_compiled_code>/vsim_beh/modelsim.ini vsim -c -voptargs="+acc" testbench glbl -do "run -all" ')
    # or remove -c from above, and replace "run -all" with "view object; view wave;"
