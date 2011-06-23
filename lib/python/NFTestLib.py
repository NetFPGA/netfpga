import hwPktLib
import hwRegLib
import simLib
import simReg
import simPkt
from sys import argv

sim = True # default, pass an argument if hardware is needed
map = {} # key is interface specified by test, value is physical interface to use
connections = {} # key is an interface specified by test, value is connected interface specified by test

CPCI_Control_reg = 0x08
CPCI_Interrupt_Mask = 0x40

############################
# Function: nftest_init
# Arguments: list of interfaces, connection file
#
# Description: parses a map file and connection file
############################
def nftest_init(interfaces, connectionsfileName):
    global sim
    if isHW():
        sim = False

    global map
    # populate map
    if '--map' in argv:
        mapfile = open(argv[argv.index('--map')+1], 'r')
        lines = mapfile.readlines()
        for line in lines:
            mapping = line.strip().split(':')
            map[mapping[0]] = mapping[1]
    else:
        for iface in interfaces:
            map[iface] = iface

    global connections
    # populate connections, line = "iface1:iface2"
    connfile = open(connectionsfileName, 'r')
    lines = connfile.readlines()
    for line in lines:
        conn = line.strip().split(':')
        connections[conn[0]] = conn[1]
        connections[conn[1]] = conn[0]
        if conn[1] == conn[0] and isHW():
            hwRegLib.phy_loopback(conn[0])

    if sim:
        pass
    else:
        hwPktLib.init(interfaces)

############################
# Function: nftest_start
# Arguments: none
# Description: performs initialization
############################
def nftest_start():
    if sim:
        simLib.init()
        simReg.regWrite(CPCI_Control_reg, 0)
        simReg.regWrite(CPCI_Interrupt_Mask, 0)
        nftest_barrier()
    else:
        hwPktLib.start()
        hwRegLib.fpga_reset()

############################
# Function: nftest_send
# Arguments: interface name
#            packet to send
# Description: send a packet on an interface
############################
def nftest_send(ifaceName, pkt):
    if sim:
        if ifaceName.startswith('eth'):
            simPkt.pktSendPHY(int(connections[ifaceName][4:5])+1, pkt)
        else:
            simPkt.pktSendDMA(int(ifaceName[4:5])+1, pkt)
    else:
        hwPktLib.send(map[ifaceName], pkt)

############################
# Function: nftest_expect
# Arguments: interface name
#            packet to expect
# Description: expect a packet on an interface
############################
def nftest_expect(ifaceName, pkt):
    if sim:
        if ifaceName.startswith('eth'):
            simPkt.pktExpectPHY(int(connections[ifaceName][4:5])+1, pkt)
        elif ifaceName == connections[ifaceName]:
            simPkt.pktExpectPHY(int(connections[ifaceName][4:5])+1, pkt)
        else:
            simPkt.pktExpectDMA(int(ifaceName[4:5])+1, pkt)
    else:
        hwPktLib.expect(map[ifaceName], pkt)

############################
# Function: nftest_barrier
# Arguments: none
# Description: pauses execution until expected packets arrive
############################
def nftest_barrier():
    if sim:
        simPkt.barrier()
    else:
        hwPktLib.barrier()

############################
# Function: nftest_finish
# Arguments: none
# Description: (sim) finalizes simulation files
#              (hw) performs finalization, writes pcap files
############################
def nftest_finish():
    if sim:
        simLib.close()
        return 0
    else:
        return hwPktLib.finish()

############################
# Function: nftest_regread_expect
# Arguments: address to read
#            value expected
# Description: reads the specified address and compares with passed value
#              (hw) returns read data
############################
def nftest_regread_expect(addr, val):
    if sim:
        simReg.regRead(addr, val)
        return 0
    else:
        return hwRegLib.regread_expect(map['nf2c0'], addr, val)


############################
# Function: regwrite
# Arguments: address to write
#            value to write
# Description: writes a value to a register
############################
def nftest_regwrite(addr, val):
    if sim:
        simReg.regWrite(addr, val)
    else:
        hwRegLib.regwrite(map['nf2c0'], addr, val)

############################
# Function: isHW
# Arguments: none
# Description: helper for HW specific tasks in tests supporting hw and sim
############################
def isHW():
    if '--hw' in argv:
        return True
    return False
