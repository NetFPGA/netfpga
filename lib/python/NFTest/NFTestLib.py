import hwPktLib
from hwPktLib import scapy
import hwRegLib
import simLib
import simReg
import simPkt
import sys
import os

sim = True # default, pass an argument if hardware is needed
map = {} # key is interface specified by test, value is physical interface to use
connections = {} # key is an interface specified by test, value is connected interface specified by test

ifaceArray = []

sent_phy = {}
sent_dma = {}
expected_phy = {}
expected_dma = {}

CPCI_Control_reg = 0x08
CPCI_Interrupt_Mask = 0x40

############################
# Function: nftest_init
# Arguments: list of valid configurations
# Description: parses the configurations to find a valid configuration
#              populates map and connections dictionaries
#              configurations are formatted ('path/to/conn/file', ['looped', 'ifaces'])
############################
def nftest_init(configurations):
    global sim
    if isHW():
        sim = False

    # validate connections and process loopback
    portConfig = 0
    looped = [False, False, False, False]
    global connections
    if '--conn' in sys.argv:
        specified_connections = {}
        # read specified connections
        lines = open(sys.argv[sys.argv.index('--conn')+1], 'r').readlines()
        for line in lines:
            conn = line.strip().split(':')
            if not isHW() and conn[0].beginswith('nf2c') and  conn[1].beginswith('nf2c'):
                print "Error: nf2cX interfaces cannot be interconnected in simulation"
                sys.exit(1)
            specified_connections[conn[0]] = conn[1]

        # find matching configuration
        for portConfig in range(len(configurations)):
            conns = {}
            lines = open(configurations[portConfig][0]).readlines()
            match = True
            for line in lines:
                conn = line.strip().split(':')
                conns[conn[0]] = conn[1]
            # physical connections match
            if conns == specified_connections:
                connections = specified_connections
                # check if we've got disconnected interfaces
                for connection in connections:
                    if connections[connection] == '':
                        if isHW():
                            hwRegLib.phy_isolate(iface)
                        else:
                            print "Error: ports should not be isolated in simulation.  Should this be a hardware only test?"
                            sys.exit(1)
                # specify loopback
                for iface in configurations[portConfig][1]:
                    if iface.startswith('nf2c'):
                        if isHW():
                            hwRegLib.phy_loopback(iface)
                        else:
                            looped[int(iface[4:5])] = True
                    else:
                        print "Error: Only nf2cX interfaces can be put in loopback"
                        sys.exit(1)
                break
            # incompatible configuration
            elif portConfig == len(configurations) - 1:
                print "Specified connections file incompatible with this test."
                sys.exit(1)

    else:
        portConfig = 0
        # use the first valid_conn_file if not specified
        lines = open(configurations[0][0], 'r').readlines()
        for line in lines:
            conn = line.strip().split(':')
            connections[conn[0]] = conn[1]
        # specify loopback
        if len(configurations[0][1]) > 0:
            for iface in configurations[0][1]:
                if iface.startswith('nf2c'):
                    if isHW():
                        hwRegLib.phy_loopback(iface)
                    else:
                        looped[int(iface[4:5])] = True
                else:
                    print "Error: Only nf2cX interfaces can be put in loopback"
                    sys.exit(1)

    # avoid duplicating interfaces
    ifaces = list(set(connections.keys() + connections.values() + list(configurations[portConfig][1])) - set(['']))

    global ifaceArray
    ifaceArray = ifaces

    global sent_phy, sent_dma, expected_phy, expected_dma
    for iface in ifaces:
        sent_phy[iface] = []
        sent_dma[iface] = []
        expected_phy[iface] = []
        expected_dma[iface] = []

    global map
    # populate map
    if '--map' in sys.argv:
        mapfile = open(sys.argv[sys.argv.index('--map')+1], 'r')
        lines = mapfile.readlines()
        for line in lines:
            mapping = line.strip().split(':')
            map[mapping[0]] = mapping[1]
    else:
        for iface in ifaces:
            map[iface] = iface

    if sim:
        simLib.init()
        portcfgfile = 'portconfig.sim'
        portcfg = open(portcfgfile, 'w')
        portcfg.write('LOOPBACK=')
        for loop_state in reversed(looped):
            if loop_state:
                portcfg.write('1')
            else:
                portcfg.write('0')
        portcfg.close()
    else:
        hwPktLib.init(ifaces)

    # print setup for inspection
    print 'Running test using the following physical connections:'
    for connection in connections.items():
        try:
            print map[connection[0]] + ':' + map[connection[1]]
        except KeyError:
            print map[connection[0]] + ' initialized but not connected'
    if len(list(configurations[portConfig][1])) > 0:
        print 'Ports in loopback:'
        for iface in list(configurations[portConfig][1]):
            print map[iface]
    print '------------------------------------------------------'

    return portConfig

############################
# Function: nftest_start
# Arguments: none
# Description: performs initialization
############################
def nftest_start():
    if sim:
        simReg.regWrite(CPCI_Control_reg, 0)
        simReg.regWrite(CPCI_Interrupt_Mask, 0)
        simReg.regDelay(1000)
    else:
        hwPktLib.start()
        hwRegLib.fpga_reset()
    nftest_barrier()

############################
# Function: nftest_send_phy
# Arguments: interface name
#            packet to send
# Description: send a packet from the phy
############################
def nftest_send_phy(ifaceName, pkt):
    if connections[ifaceName] == ifaceName:
        print "Error: cannot send on phy of a port in loopback"
        sys.exit(1)
    sent_phy[ifaceName].append(pkt)
    if sim:
        simPkt.pktSendPHY(int(ifaceName[4:5])+1, pkt)
    else:
        hwPktLib.send(map[connections[ifaceName]], pkt)

############################
# Function: nftest_send_dma
# Arguments: interface name
#            packet to send
# Description: send a packet from the dma
############################
def nftest_send_dma(ifaceName, pkt):
    sent_dma[ifaceName].append(pkt)
    if sim:
        simPkt.pktSendDMA(int(ifaceName[4:5])+1, pkt)
    else:
        hwPktLib.send(map[ifaceName], pkt)

############################
# Function: nftest_expect_phy
# Arguments: interface name
#            packet to expect
# Description: expect a packet on the phy
############################
def nftest_expect_phy(ifaceName, pkt):
    if connections[ifaceName] == ifaceName:
        print "Error: cannot expect on phy of a port in loopback"
        sys.exit(1)
    expected_phy[ifaceName].append(pkt)
    if sim:
        simPkt.pktExpectPHY(int(ifaceName[4:5])+1, pkt)
    else:
        hwPktLib.expect(map[connections[ifaceName]], pkt)

############################
# Function: nftest_expect_dma
# Arguments: interface name
#            packet to expect
# Description: expect a packet on dma
############################
def nftest_expect_dma(ifaceName, pkt):
    expected_dma[ifaceName].append(pkt)
    if sim:
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
#              (hw) performs finalization, writes pcap files and prints success
############################
def nftest_finish(total_errors = 0):
    nftest_barrier()

    # write out the sent/expected pcaps for easy viewing
    if not os.path.isdir("./source_pcaps"):
        os.mkdir("./source_pcaps")
    for iface in ifaceArray:
        if len(sent_phy[iface]) > 0:
            scapy.wrpcap("./source_pcaps/%s_sent_phy.pcap"%iface,
                         sent_phy[iface])
        if len(sent_dma[iface]) > 0:
            scapy.wrpcap("./source_pcaps/%s_sent_dma.pcap"%iface,
                         sent_dma[iface])
        if len(expected_phy[iface]) > 0:
            scapy.wrpcap("./source_pcaps/%s_expected_phy.pcap"%iface,
                         expected_phy[iface])
        if len(expected_dma[iface]) > 0:
            scapy.wrpcap("./source_pcaps/%s_expected_dma.pcap"%iface,
                         expected_dma[iface])

    if sim:
        simLib.close()
        return 0
    else:
        total_errors += hwPktLib.finish()
        if total_errors == 0:
            print 'SUCCESS!'
            sys.exit(0)
        else:
            print 'FAIL: ' + str(total_errors) + ' errors'
            sys.exit(1)

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
# Function: nftest_fpga_reset
# Arguments: none
# Description: resets the fpga
############################
def nftest_fpga_reset():
    if sim:
        simReg.regWrite(simReg.CPCI_REG_CTRL, simReg.CPCI_REG_CTRL_RESET)
    else:
        hwRegLib.fpga_reset()

############################
# Function: isHW
# Arguments: none
# Description: helper for HW specific tasks in tests supporting hw and sim
############################
def isHW():
    if '--hw' in sys.argv:
        return True
    return False
