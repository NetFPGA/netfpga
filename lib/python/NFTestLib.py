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
# Function: init
# Arguments: map file, connection file
#            hw/sw/both
# Description: takes a map file and connection file
#              displays usage notes if --help is specified
############################
def nftest_init(interfaces, connectionsfileName, *args, **kwargs):
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
# Function: start
# Arguments:
#
# Description: begins the test
#
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
# Function: pktSend
# Arguments:
#
# Description:
#
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
# Function: pktExpect
# Arguments:
#
# Description:
#
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
# Function: barrier
# Arguments:
#
# Description:
#
############################
def nftest_barrier():
    if sim:
        simPkt.barrier()
    else:
        hwPktLib.barrier()

############################
# Function: finish
# Arguments:
#
# Description:
#
############################
def nftest_finish():
    if sim:
        simLib.close()
        return 0
    else:
        return hwPktLib.finish()

############################
# Function: regread_expect
# Arguments:
#
# Description:
#
############################
def nftest_regread_expect(addr, val):
    if sim:
        simReg.regRead(addr, val)
        return 0
    else:
        return hwRegLib.regread_expect(map['nf2c0'], addr, val)


############################
# Function: regwrite
# Arguments:
#
# Description:
#
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
