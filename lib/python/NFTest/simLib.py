#!/usr/bin/env python
# Author: James Hsi, Eric Lo
# Date: 1/31/2011
#
#  Overarching test module.
#  Creates and maintains file objects through file writes during tests.
# python -m pdb
#

import os

NUM_PORTS = 4
NF2_MAX_PORTS = 4
DMA_QUEUES = 4

#instantiation
f_ingress = []
f_expectPHY = []
f_expectDMA = []

directory = 'packet_data'
dma_filename = 'ingress_dma'
pci_filename = 'pci_sim_data'
ingress_fileHeader = 'ingress_port_'
expectPHY_fileHeader = 'expected_port_'
expectDMA_fileHeader = 'expected_dma_'

############################
# Function: init()
#   Creates the hardware and simulation files to be read by ModelSim,
############################
def init():
    if not os.path.isdir(directory):
        os.mkdir(directory)
    try:
        global f_pci; global f_dma
        f_pci = open(directory+'/'+pci_filename,'w')
        f_dma = open(directory+'/'+dma_filename,'w')
    except IOError:
        print("File creation error")
    writeFileHeader(fPCI(), directory+'/'+pci_filename)
    writeFileHeader(fDMA(), directory+'/'+dma_filename)

    for i in range(NUM_PORTS):
        filename = ingress_fileHeader + str(i+1)
        f_ingress.append(open(directory+'/'+filename, 'w'))
        writeFileHeader(fPort(i+1), directory+"/"+filename)

    # make XML files
    for i in range(NUM_PORTS):
        filename = expectPHY_fileHeader + str(i+1)
        f_expectPHY.append(open(directory+'/'+filename, 'w'))
        writeXMLHeader(fExpectPHY(i+1), directory+"/"+filename)

    for i in range(NUM_PORTS):
        filename = expectDMA_fileHeader + str(i+1)
        f_expectDMA.append(open(directory+'/'+filename, 'w'))
        writeXMLHeader(fExpectDMA(i+1), directory+"/"+filename)


############################
# Function: writeFileHeader
#  Writes timestamp and general information to file head.
############################
def writeFileHeader(fp, filePath):
    from time import gmtime, strftime
    fp.write("//File " + filePath + " created " +
                strftime("%a %b %d %H:%M:%S %Y", gmtime())+"\n")
    fp.write("//\n//This is a data file intended to be read in by a " +
                "Verilog simulation.\n//\n")


############################
# Function: writeXMLHeader
#  Writes timestamp and general information to file head.
############################
def writeXMLHeader(fp, filePath):
    from time import gmtime, strftime
    fp.write("<?xml version=\"1.0\" standalone=\"yes\" ?>\n")
    fp.write("<!-- File "+filePath+" created "+
                strftime("%a %b %d %H:%M:%S %Y", gmtime())+" -->\n")
    if str.find(filePath, expectPHY_fileHeader)>0:
        fp.write("<!-- PHYS_PORTS = "+str(NUM_PORTS)+" MAX_PORTS = "+
                    str(NF2_MAX_PORTS)+" -->\n")
        fp.write("<PACKET_STREAM>\n")
    elif str.find(filePath, expectDMA_fileHeader)>0:
        fp.write("<!-- DMA_QUEUES = "+"%d"%DMA_QUEUES+" -->")
        fp.write("<DMA_PACKET_STREAM>\n")
    fp.write("\n")


############################
# Function: close()
#   Closes all file pointers created during initialization.
#   Must be called at the end of every test file.
############################
def close():
    f_dma.close()
    f_pci.close()

    for i in range(NUM_PORTS):
        f_ingress[i].close()

    for i in range(NUM_PORTS):
        f_expectPHY[i].write("</PACKET_STREAM>")
        f_expectPHY[i].close()

    for i in range(NUM_PORTS):
        f_expectDMA[i].write("</DMA_PACKET_STREAM>")
        f_expectDMA[i].close()

# Getters #################################################################


############################
# Function: fPCI
#  A Getter that returns the file pointer for file with
#  register read/write info.
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
# Function: fPort
# Argument: port - int - port for which read/write is occurring
#                   (Should be 1-4, NOT THE INDEX OF ARRAY)
#  A Getter that returns the file pointer for file with PHY read/write info.
#
############################
def fPort(port):
    return f_ingress[port-1]


############################
# Function: fExpectPHY
# Argument: port - int - port for which read/write is occurring
#                   (Should be 1-4, NOT THE INDEX OF ARRAY)
#  A Getter that returns the file pointer for file with PHY read/write info.
#
############################
def fExpectPHY(port):
    return f_expectPHY[port-1]


############################
# Function: fExpectDMA
# Argument: port - int - port for which read/write is occurring
#                   (Should be 1-4, NOT THE INDEX OF ARRAY)
#  A Getter that returns the file pointer for file with DMA read/write info.
#
############################
def fExpectDMA(port):
    return f_expectDMA[port-1]
