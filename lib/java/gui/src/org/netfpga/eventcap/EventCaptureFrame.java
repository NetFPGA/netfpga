package org.netfpga.eventcap;
/*
 * EventCaptureFrame.java
 *
 * Created on May 23, 2007, 1:20 AM
 */

import java.awt.Color;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.event.ItemEvent;
import java.awt.event.ItemListener;
import java.io.ByteArrayInputStream;
import java.io.IOException;

import javax.swing.AbstractButton;
import javax.swing.InputVerifier;
import javax.swing.JComponent;
import javax.swing.JOptionPane;
import javax.swing.JScrollPane;
import javax.swing.JTextField;
import javax.swing.Timer;
import javax.swing.event.ChangeEvent;
import javax.swing.event.ChangeListener;
import javax.swing.JSlider;

import net.sourceforge.jpcap.capture.CaptureDeviceOpenException;
import net.sourceforge.jpcap.capture.CapturePacketException;
import net.sourceforge.jpcap.capture.InvalidFilterException;
import net.sourceforge.jpcap.capture.PacketCapture;
import net.sourceforge.jpcap.capture.PacketListener;
import net.sourceforge.jpcap.net.EthernetProtocol;
import net.sourceforge.jpcap.net.Packet;
import org.netfpga.router.ControlButton;
import org.netfpga.router.ControlCheckBox;
import org.netfpga.router.ControlRegGroup;
import org.netfpga.router.IPAddress;
import org.netfpga.router.MACAddress;
import org.netfpga.router.RegSliderGroupControl;
import org.netfpga.router.StatsRegTable;
import org.netfpga.router.StatsRegTableModel;
import org.netfpga.router.ValueTransformer;
import org.netfpga.backend.NFDevice;
import org.netfpga.backend.NFDeviceConsts;

/**
 *
 * @author  jnaous
 */
@SuppressWarnings("serial")
public class EventCaptureFrame extends javax.swing.JInternalFrame implements PacketListener{

    EventCaptureQueuePanel[] evtQPanels;
    JScrollPane[] evtQScrollPanes;

    private ControlRegGroup enableCtrl;
    private ControlRegGroup resetSysCtrl;
    private ControlRegGroup outPortsCtrl;
    private ControlRegGroup resetTimerCtrl;
    private ControlRegGroup monMaskCtrl;

    private RegSliderGroupControl timerResolutionSliderCtrl;

    private StatsRegTableModel statsRegTableModel;

    private NFDevice nf2;
    private Timer timer;
    private ActionListener timerActionListener;

    private static final int EVENT_ETHERTYPE = 0x9999;
    private static final int STATS_NUM_REGS_USED = 3;

    private PacketCapture m_pcap;

    private CaptureThread captureThread;

    private int numEvtPktsLost = 0;
    private int lastPktSeqNum = 0;
    private boolean newCapture = true;

    /**
     * Creates a new event capture frame
     * @param nf2 device to communicate with
     * @param timer signals updates
     */
    public EventCaptureFrame(NFDevice nf2, Timer timer) {
        this.nf2 = nf2;
        this.timer = timer;

        initComponents();

        setupStatsTable(nf2);
        this.statsRegTable.setModel(statsRegTableModel);
        ((StatsRegTable)this.statsRegTable).setDefaults();

        /* initialize event panels */
        evtQPanels = new EventCaptureQueuePanel[8];
        evtQScrollPanes = new JScrollPane[8];

        for(int i=0; i<8; i++) {
            evtQScrollPanes[i] = new javax.swing.JScrollPane();
            evtQPanels[i] = new EventCaptureQueuePanel();
            jTabbedPane1.addTab("Output Queue "+i, evtQScrollPanes[i]);
            evtQScrollPanes[i].setViewportView(evtQPanels[i]);
        }

        /* initialize the controller for the enabled checkbox */
        AbstractButton[] buttons = {this.enabledCheckbox};
        boolean[] invert = {false};
        enableCtrl = new ControlRegGroup(nf2, NFDeviceConsts.EVT_CAP_ENABLE_CAPTURE_REG, buttons, invert);

        /* initialize the reset system button control */
        buttons = new AbstractButton[1];
        buttons[0] = this.resetSystemButton;
        invert = new boolean[1];
        invert[0] = true;
        this.resetSysCtrl = new ControlRegGroup(nf2, NFDeviceConsts.EVT_CAP_ENABLE_CAPTURE_REG, buttons, invert);

        /* initialize the controller for the output ports */
        buttons = new AbstractButton[8];
        buttons[0] = this.sendToPortCheckbox0;
        buttons[2] = this.sendToPortCheckbox1;
        buttons[4] = this.sendToPortCheckbox2;
        buttons[6] = this.sendToPortCheckbox3;
        invert = new boolean[8];
        invert[0] = false;
        invert[1] = false;
        invert[2] = false;
        invert[3] = false;
        invert[4] = false;
        invert[5] = false;
        invert[6] = false;
        invert[7] = false;
        this.outPortsCtrl = new ControlRegGroup(nf2, NFDeviceConsts.EVT_CAP_OUTPUT_PORTS_REG, buttons, invert);

        /* initialize the controller for timer reset */
        buttons = new AbstractButton[1];
        buttons[0] = this.resetTimerButton;
        invert = new boolean[1];
        invert[0] = false;
        this.resetTimerCtrl = new ControlRegGroup(nf2, NFDeviceConsts.EVT_CAP_RESET_TIMERS_REG, buttons, invert);

        /* initialize the controller for monitored queue selects */
        buttons = new AbstractButton[8];
        buttons[0] = this.monitorQueueCheckbox0;
        buttons[1] = this.monitorQueueCheckbox1;
        buttons[2] = this.monitorQueueCheckbox2;
        buttons[3] = this.monitorQueueCheckbox3;
        buttons[4] = this.monitorQueueCheckbox4;
        buttons[5] = this.monitorQueueCheckbox5;
        buttons[6] = this.monitorQueueCheckbox6;
        buttons[7] = this.monitorQueueCheckbox7;
        invert = new boolean[8];
        invert[0] = false;
        invert[1] = false;
        invert[2] = false;
        invert[3] = false;
        invert[4] = false;
        invert[5] = false;
        invert[6] = false;
        invert[7] = false;
        this.monMaskCtrl = new ControlRegGroup(nf2, NFDeviceConsts.EVT_CAP_SIGNAL_ID_MASK_REG, buttons, invert);

        /* initialize the time precision slider control */
        timerResolutionSliderCtrl = new RegSliderGroupControl(nf2, this.tmrResSlider, this.tmrResValueLabel, NFDeviceConsts.EVT_CAP_TIMER_RESOLUTION_REG);
        timerResolutionSliderCtrl.setVt(new ValueTransformer() {

            public int toSliderValue(int val) {
                return val;
            }

            public int toRegisterValue(int val) {
                return val;
            }

            public String toLabelStringFromReg(int val) {
                return ""+(Math.pow(2,val)*8)+" ns";
            }

            public String toLabelStringFromComponent(int val) {
                return toLabelStringFromReg(val);
            }

        });

        /* add listener to change the tick length of the graphs */
        tmrResSlider.addChangeListener(new ChangeListener() {
            public void stateChanged(ChangeEvent evt) {
                JSlider source = (JSlider)evt.getSource();
                int val = (int)source.getValue();
                if(!source.getValueIsAdjusting()){
                    for (int i = 0; i<8; i++) {
                        evtQPanels[i].setTickLength((int)Math.pow(2,val)*8);
                    }
                }
            }

        });

        /* get an input verifier for mac addresses */
        InputVerifier macInputVerifier = new InputVerifier() {
            @Override
            public boolean verify(JComponent input) {
                try{
                    @SuppressWarnings("unused")
                    MACAddress addr = new MACAddress(((JTextField)input).getText());
                } catch (Exception e) {
                    return false;
                }
                return true;
            }

            /*
             * (non-Javadoc)
             * @see javax.swing.InputVerifier#shouldYieldFocus(javax.swing.JComponent)
             */
            public boolean shouldYieldFocus(JComponent input){
                if(!verify(input)){
                    ((JTextField)input).setBackground(Color.RED);
                    return false;
                } else {
                    ((JTextField)input).setBackground(Color.WHITE);
                    return true;
                }
            }
        };

        /* set the input verifier for the MAC text fields */
        this.macDestAddrTextField.setInputVerifier(macInputVerifier);

        /* write destination MAC address to the hardware */
        this.macDestAddrTextField.addActionListener(new ActionListener() {
            public void actionPerformed(ActionEvent e) {
                updateDestMac();
            }
        });

        /* set the input verifier for the source MAC address */
        this.macSrcAddrTextField.setInputVerifier(macInputVerifier);

        /* write the source mac address to the hardware */
        this.macSrcAddrTextField.addActionListener(new ActionListener() {
            public void actionPerformed(ActionEvent e) {
                updateSrcMac();
            }
        });

        /* get an input verifier for integers */
        InputVerifier integerInputVerifier = new InputVerifier() {
            @Override
            public boolean verify(JComponent input) {
                try{
                    Integer.parseInt(((JTextField)input).getText());
                } catch (Exception e) {
                    return false;
                }
                return true;
            }

            /*
             * (non-Javadoc)
             * @see javax.swing.InputVerifier#shouldYieldFocus(javax.swing.JComponent)
             */
            public boolean shouldYieldFocus(JComponent input){
                if(!verify(input)){
                    ((JTextField)input).setBackground(Color.RED);
                    return false;
                } else {
                    ((JTextField)input).setBackground(Color.WHITE);
                    return true;
                }
            }
        };

        /* set the graph num points input verifier */
        this.graphSizeTextField.setInputVerifier(integerInputVerifier);

        /* add action listener to set graph size */
        this.graphSizeTextField.addActionListener(new ActionListener() {
            public void actionPerformed(ActionEvent e) {
                updateGraphSizes();
            }
        });

        /* Set udp destination port text field input verifier */
        this.udpDestPortTextField.setInputVerifier(integerInputVerifier);

        /* set the action listener */
        this.udpDestPortTextField.addActionListener(new ActionListener() {
            public void actionPerformed(ActionEvent e) {
                updateUdpDestField();
            }
        });

        /* Set udp Source port text field input verifier */
        this.udpSrcPortTextField.setInputVerifier(integerInputVerifier);

        /* set the action listener */
        this.udpSrcPortTextField.addActionListener(new ActionListener() {
            public void actionPerformed(ActionEvent e) {
                updateUdpSrcField();
            }
        });

        /* create an IP address input verifier */
        InputVerifier ipInputVerifier = new InputVerifier() {
            @Override
            public boolean verify(JComponent input) {
                try{
                    new IPAddress(((JTextField)input).getText());
                } catch (Exception e) {
                    return false;
                }
                return true;
            }

            /*
             * (non-Javadoc)
             * @see javax.swing.InputVerifier#shouldYieldFocus(javax.swing.JComponent)
             */
            public boolean shouldYieldFocus(JComponent input){
                if(!verify(input)){
                    ((JTextField)input).setBackground(Color.RED);
                    return false;
                } else {
                    ((JTextField)input).setBackground(Color.WHITE);
                    return true;
                }
            }
        };

        /* set the input verifier for the destination IP address */
        this.ipDestAddrTextField.setInputVerifier(ipInputVerifier);

        /* add action listener for destination ip address */
        this.ipDestAddrTextField.addActionListener(new ActionListener() {
            public void actionPerformed(ActionEvent e) {
                updateIP();
            }
        });

        /* set the input verifier for the source IP address */
        this.ipSrcAddrTextField.setInputVerifier(ipInputVerifier);

        /* add action listener for source ip address */
        this.ipSrcAddrTextField.addActionListener(new ActionListener() {
            public void actionPerformed(ActionEvent e) {
                updateIP();
            }
        });

        /* add listeners to the update the tables */
        timerActionListener = new ActionListener() {
            public void actionPerformed(ActionEvent e) {
                enableCtrl.updateFromRegs();
                resetSysCtrl.updateFromRegs();
                outPortsCtrl.updateFromRegs();
                resetTimerCtrl.updateFromRegs();
                monMaskCtrl.updateFromRegs();

                timerResolutionSliderCtrl.updateFromRegs();

                statsRegTableModel.updateTable();
            }
        };

        /* add action listener to the timer */
        timer.addActionListener(timerActionListener);

        updateDestMac();
        updateSrcMac();
        updateGraphSizes();
        updateIP();
        updateUdpDestField();
        updateUdpSrcField();

        this.sendToLocalHostCheckbox.addItemListener(new ItemListener() {
            public void itemStateChanged(ItemEvent e) {
                sendToLocalHostHandler(e.getStateChange()==ItemEvent.SELECTED);
            }
        });
    }

    /**
     * Handles selecting/deselecting send to localhost by instantiating capture on device
     * @param selected
     */
    protected void sendToLocalHostHandler(boolean selected) {
        if(selected){
            try {
//                String m_device = "eth1";
                String m_device = nf2.getIfaceName();

                // Step 1:  Instantiate Capturing Engine
                m_pcap = new PacketCapture();

                // Step 2:  Check for devices
                System.out.println("Capturing on "+m_device);

                // Step 3:  Open Device for Capturing (requires root)
                m_pcap.open(m_device, 2048, true, 500);

                // Step 4:  Add a BPF Filter (see tcpdump documentation)
                m_pcap.setFilter("ether proto "+EVENT_ETHERTYPE, true);

                /* 1- disable all controls the user doesn't need to worry about */
                this.sendToPortCheckbox0.setEnabled(false);
                this.sendToPortCheckbox1.setEnabled(false);
                this.sendToPortCheckbox2.setEnabled(false);
                this.sendToPortCheckbox3.setEnabled(false);

                this.macDestAddrTextField.setEnabled(false);
                this.macSrcAddrTextField.setEnabled(false);

                this.ipDestAddrTextField.setEnabled(false);
                this.ipSrcAddrTextField.setEnabled(false);

                this.udpDestPortTextField.setEnabled(false);
                this.udpSrcPortTextField.setEnabled(false);

                // Write the Ethertype and where to send event packets
                nf2.writeReg(NFDeviceConsts.EVT_CAP_ETHERTYPE_REG, EVENT_ETHERTYPE);
                nf2.writeReg(NFDeviceConsts.EVT_CAP_OUTPUT_PORTS_REG, 0x2);

                // Step 5:  Register a Listener for jpcap Packets
                m_pcap.addPacketListener(this);

                // Step 6:  Capture Data (max. PACKET_COUNT packets)
                captureThread = new CaptureThread(m_pcap);
                captureThread.start();

                /* reset pkts lost and last sequence num seen */
                this.newCapture = true;
                this.numEvtPktsLost = 0;
                this.numEvtPktsLostValueLabel.setText("0");

            } catch (CaptureDeviceOpenException e) {
                JOptionPane.showMessageDialog(null, "Failed to open device for capture.", "Error", JOptionPane.ERROR_MESSAGE);
                e.printStackTrace();
            } catch (InvalidFilterException e1) {
                JOptionPane.showMessageDialog(null, "Failed to open device for capture.", "Error", JOptionPane.ERROR_MESSAGE);
                e1.printStackTrace();
            }

        } else {
            this.sendToPortCheckbox0.setEnabled(true);
            this.sendToPortCheckbox1.setEnabled(true);
            this.sendToPortCheckbox2.setEnabled(true);
            this.sendToPortCheckbox3.setEnabled(true);

            this.macDestAddrTextField.setEnabled(true);
            this.macSrcAddrTextField.setEnabled(true);

            this.ipDestAddrTextField.setEnabled(true);
            this.ipSrcAddrTextField.setEnabled(true);

            this.udpDestPortTextField.setEnabled(true);
            this.udpSrcPortTextField.setEnabled(true);

            nf2.writeReg(NFDeviceConsts.EVT_CAP_ETHERTYPE_REG, EthernetProtocol.IP);

            int outPorts = 0;
            if(this.sendToPortCheckbox0.isSelected()){
                outPorts |= 0x1;
            }
            if(this.sendToPortCheckbox0.isSelected()){
                outPorts |= 0x4;
            }
            if(this.sendToPortCheckbox0.isSelected()){
                outPorts |= 0x10;
            }
            if(this.sendToPortCheckbox0.isSelected()){
                outPorts |= 0x40;
            }
            nf2.writeReg(NFDeviceConsts.EVT_CAP_OUTPUT_PORTS_REG, outPorts);

            /* We might be trying to close right before these are instantiated */
            try {
                this.captureThread.setRunning(false);
                m_pcap.removePacketListener(this);
                m_pcap.endCapture();
                m_pcap.close();
            } catch (Exception e) {
                // don't do anything
            }
        }
    }

    /**
     * Processes the data in the byte[] as an event packet
     * @param packet the data to process as an event packet
     */
    public void processPacketData(byte[] packet){
//         System.out.println("New packet...");
        dumpPacket(packet);
        ByteArrayInputStream in = new ByteArrayInputStream(packet);
        NFEventParser parser = new NFEventParser();
        EventHeader hdr;
        NFEvent evt;
        try {
            hdr = parser.parseEventPacketHdr(in);

            /* if we get an out-of-order or duplicate packet then ignore it */
            if(hdr.getPktSeq()<=lastPktSeqNum){
                return;
            }

            /* only check the sequence number if we have previously received a pkt */
            if(!newCapture){
                long numMissingPkts = (hdr.getPktSeq()-1-lastPktSeqNum);
                numEvtPktsLost += numMissingPkts;
            }

            /* always update the absolute queue sizes */
            for(int i=0; i<evtQPanels.length; i++){
                evtQPanels[i].setOQSize(hdr.getOqSizeBytes(i), hdr.getOqSizePkts(i));
            }

            lastPktSeqNum = (int) hdr.getPktSeq();
            numEvtPktsLostValueLabel.setText(""+numEvtPktsLost);
            newCapture = false;

//             System.out.println(hdr);
            while((evt=parser.parseNextEvent(in))!=null){
                int oq=evt.getOutputQueue();
                this.evtQPanels[oq].processEvent(evt);
            }
            for(int i=0; i<evtQPanels.length; i++){
                evtQPanels[i].notifyGraphs();
            }
//             System.out.println(evtQPanels[2]);

        } catch (IOException e) {
            System.out.println("Error with reading the event packet.");
            e.printStackTrace();
        }
    }

    /**
     * Dumps the packet bytes
     * @param packet
     */
    @SuppressWarnings("unused")
    private void dumpPacket(byte[] packet) {
        for(int i=0; i<packet.length; i++){
            int b = packet[i];
            if(b<0) b += 256;
            System.out.printf("%02x ",b);
            if((i%4)==3){
                System.out.println();
            }
        }
    }

    /**
     * Sets up the statistics table
     * @param nf2
     */
    private void setupStatsTable(NFDevice nf2) {
        /* add the addresses to monitor through statsRegTableModel */
        long[] aAddresses = new long[STATS_NUM_REGS_USED];

        aAddresses[0] = NFDeviceConsts.EVT_CAP_NUM_EVT_PKTS_SENT_REG;
        aAddresses[1] = NFDeviceConsts.EVT_CAP_NUM_EVTS_SENT_REG;
        aAddresses[2] = NFDeviceConsts.EVT_CAP_NUM_EVTS_DROPPED_REG;

        String[] descriptions = new String[STATS_NUM_REGS_USED];
        descriptions[0] = "Total number of event packets sent";
        descriptions[1] = "Total number of events sent";
        descriptions[2] = "Total number of events dropped";

        /* create the register table model which we want to monitor */
        statsRegTableModel = new StatsRegTableModel(nf2, aAddresses, descriptions);
    }

    protected void updateIP() {
        IPAddress ip;
        JTextField field = ipDestAddrTextField;
        try {
            ip = new IPAddress(field.getText());
            field.setBackground(Color.WHITE);
            nf2.writeReg(NFDeviceConsts.EVT_CAP_IP_DST_REG, ip.getIpInt());
        } catch (Exception e) {
            field.setBackground(Color.RED);
        }

        field = ipSrcAddrTextField;
        try {
            ip = new IPAddress(field.getText());
            field.setBackground(Color.WHITE);
            nf2.writeReg(NFDeviceConsts.EVT_CAP_IP_SRC_REG, ip.getIpInt());
        } catch (Exception e) {
            field.setBackground(Color.RED);
        }

        nf2.writeReg(NFDeviceConsts.EVT_CAP_ETHERTYPE_REG, EthernetProtocol.IP);
        nf2.writeReg(NFDeviceConsts.EVT_CAP_MONITOR_MASK_REG, 0xf);
    }

    protected void updateUdpDestField() {
        int num;
        JTextField field = udpDestPortTextField;
        try {
            num = Integer.parseInt(field.getText());
            if(num>65535){
                throw new Exception();
            }
            field.setBackground(Color.WHITE);
            nf2.writeReg(NFDeviceConsts.EVT_CAP_UDP_DST_PORT_REG, num);
        } catch (Exception e) {
            field.setBackground(Color.RED);
        }
    }

    protected void updateUdpSrcField() {
        int num;
        JTextField field = udpSrcPortTextField;
        try {
            num = Integer.parseInt(field.getText());
            if(num>65535){
                throw new Exception();
            }
            field.setBackground(Color.WHITE);
            nf2.writeReg(NFDeviceConsts.EVT_CAP_UDP_SRC_PORT_REG, num);
        } catch (Exception e) {
            field.setBackground(Color.RED);
        }
    }

    protected void updateGraphSizes() {
        int graphSize;
        JTextField field = graphSizeTextField;
        try {
            graphSize = Integer.parseInt(field.getText());
            field.setBackground(Color.WHITE);
            for(int i=0; i<8; i++){
                this.evtQPanels[i].setGraphSize(graphSize);
            }
        } catch (NumberFormatException e) {
            field.setBackground(Color.RED);
        }
    }

    /**
     * Pushes the destination MAC address from the text field to the hardware
     *
     */
    protected void updateDestMac() {
        MACAddress addr;
        try {
            addr = new MACAddress(this.macDestAddrTextField.getText());
            nf2.writeReg(NFDeviceConsts.EVT_CAP_DST_MAC_HI_REG, addr.getHighShort());
            nf2.writeReg(NFDeviceConsts.EVT_CAP_DST_MAC_LO_REG, addr.getLowInt());
            macDestAddrTextField.setBackground(Color.WHITE);
        } catch (Exception e) {
            macDestAddrTextField.setBackground(Color.RED);
        }
    }

    /**
     * Pushes the source MAC address from the text field to the hardware
     *
     */
    protected void updateSrcMac() {
        MACAddress addr;
        try {
            addr = new MACAddress(this.macSrcAddrTextField.getText());
            nf2.writeReg(NFDeviceConsts.EVT_CAP_SRC_MAC_HI_REG, addr.getHighShort());
            nf2.writeReg(NFDeviceConsts.EVT_CAP_SRC_MAC_LO_REG, addr.getLowInt());
            macSrcAddrTextField.setBackground(Color.WHITE);
        } catch (Exception e) {
            macSrcAddrTextField.setBackground(Color.RED);
        }
    }

    /** This method is called from within the constructor to
     * initialize the form.
     * WARNING: Do NOT modify this code. The content of this method is
     * always regenerated by the Form Editor.
     */
    // <editor-fold defaultstate="collapsed" desc=" Generated Code ">//GEN-BEGIN:initComponents
    private void initComponents() {
        jTabbedPane1 = new javax.swing.JTabbedPane();
        evtCapScrollPane = new javax.swing.JScrollPane();
        evtCapConfigPanel = new javax.swing.JPanel();
        pageTitleLabel = new javax.swing.JLabel();
        jSeparator1 = new javax.swing.JSeparator();
        enabledCheckbox = new ControlCheckBox();
        sendToLocalHostCheckbox = new ControlCheckBox();
        sendToPortCheckbox0 = new ControlCheckBox();
        sendToPortCheckbox1 = new ControlCheckBox();
        sendToPortCheckbox2 = new ControlCheckBox();
        sendToPortCheckbox3 = new ControlCheckBox();
        monitorQueueCheckbox0 = new ControlCheckBox();
        monitorQueueCheckbox1 = new ControlCheckBox();
        monitorQueueCheckbox2 = new ControlCheckBox();
        monitorQueueCheckbox3 = new ControlCheckBox();
        monitorQueueCheckbox4 = new ControlCheckBox();
        monitorQueueCheckbox5 = new ControlCheckBox();
        monitorQueueCheckbox6 = new ControlCheckBox();
        monitorQueueCheckbox7 = new ControlCheckBox();
        resetSystemButton = new ControlButton();
        resetTimerButton = new ControlButton();
        tmrResHelpButton = new javax.swing.JButton();
        tmrResLabel = new javax.swing.JLabel();
        macDestAddrHelpButton = new javax.swing.JButton();
        macDestAddrLabel = new javax.swing.JLabel();
        ipDestAddrHelpButton = new javax.swing.JButton();
        ipDestAddrLabel = new javax.swing.JLabel();
        tmrResSlider = new javax.swing.JSlider();
        tmrResValueLabel = new javax.swing.JLabel();
        macDestAddrTextField = new javax.swing.JTextField();
        macSrcAddrHelpButton = new javax.swing.JButton();
        macSrcAddrLabel = new javax.swing.JLabel();
        macSrcAddrTextField = new javax.swing.JTextField();
        ipDestAddrTextField = new javax.swing.JTextField();
        ipSrcAddrHelpButton = new javax.swing.JButton();
        ipSrcAddrLabel = new javax.swing.JLabel();
        ipSrcAddrTextField = new javax.swing.JTextField();
        udpSrcPortHelpButton = new javax.swing.JButton();
        udpSrcPortLabel = new javax.swing.JLabel();
        udpSrcPortTextField = new javax.swing.JTextField();
        udpDestPortHelpButton = new javax.swing.JButton();
        udpDestPortLabel = new javax.swing.JLabel();
        udpDestPortTextField = new javax.swing.JTextField();
        graphSizeHelpButton = new javax.swing.JButton();
        graphSizeLabel = new javax.swing.JLabel();
        graphSizeTextField = new javax.swing.JTextField();
        jScrollPane1 = new javax.swing.JScrollPane();
        statsRegTable = new StatsRegTable();
        numEvtPktsLostValueLabel = new javax.swing.JLabel();
        numEvtPktsLostLabel = new javax.swing.JLabel();

        setClosable(true);
        setIconifiable(true);
        setMaximizable(true);
        setResizable(true);
        setTitle("Event Capture Module");
        addInternalFrameListener(new javax.swing.event.InternalFrameListener() {
            public void internalFrameActivated(javax.swing.event.InternalFrameEvent evt) {
            }
            public void internalFrameClosed(javax.swing.event.InternalFrameEvent evt) {
            }
            public void internalFrameClosing(javax.swing.event.InternalFrameEvent evt) {
                formInternalFrameClosing(evt);
            }
            public void internalFrameDeactivated(javax.swing.event.InternalFrameEvent evt) {
            }
            public void internalFrameDeiconified(javax.swing.event.InternalFrameEvent evt) {
            }
            public void internalFrameIconified(javax.swing.event.InternalFrameEvent evt) {
            }
            public void internalFrameOpened(javax.swing.event.InternalFrameEvent evt) {
            }
        });

        pageTitleLabel.setFont(new java.awt.Font("Dialog", 1, 18));
        pageTitleLabel.setText("Configuration");

        enabledCheckbox.setText("Enable Capture");
        enabledCheckbox.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        enabledCheckbox.setMargin(new java.awt.Insets(0, 0, 0, 0));

        sendToLocalHostCheckbox.setText("Send to local host");
        sendToLocalHostCheckbox.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        sendToLocalHostCheckbox.setMargin(new java.awt.Insets(0, 0, 0, 0));

        sendToPortCheckbox0.setText("Send on port 0");
        sendToPortCheckbox0.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        sendToPortCheckbox0.setMargin(new java.awt.Insets(0, 0, 0, 0));

        sendToPortCheckbox1.setText("Send on port 1");
        sendToPortCheckbox1.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        sendToPortCheckbox1.setMargin(new java.awt.Insets(0, 0, 0, 0));

        sendToPortCheckbox2.setText("Send on port 2");
        sendToPortCheckbox2.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        sendToPortCheckbox2.setMargin(new java.awt.Insets(0, 0, 0, 0));

        sendToPortCheckbox3.setText("Send on port 3");
        sendToPortCheckbox3.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        sendToPortCheckbox3.setMargin(new java.awt.Insets(0, 0, 0, 0));

        monitorQueueCheckbox0.setText("Monitor Queue 0");
        monitorQueueCheckbox0.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        monitorQueueCheckbox0.setMargin(new java.awt.Insets(0, 0, 0, 0));

        monitorQueueCheckbox1.setText("Monitor Queue 1");
        monitorQueueCheckbox1.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        monitorQueueCheckbox1.setMargin(new java.awt.Insets(0, 0, 0, 0));

        monitorQueueCheckbox2.setText("Monitor Queue 2");
        monitorQueueCheckbox2.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        monitorQueueCheckbox2.setMargin(new java.awt.Insets(0, 0, 0, 0));

        monitorQueueCheckbox3.setText("Monitor Queue 3");
        monitorQueueCheckbox3.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        monitorQueueCheckbox3.setMargin(new java.awt.Insets(0, 0, 0, 0));

        monitorQueueCheckbox4.setText("Monitor Queue 4");
        monitorQueueCheckbox4.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        monitorQueueCheckbox4.setMargin(new java.awt.Insets(0, 0, 0, 0));

        monitorQueueCheckbox5.setText("Monitor Queue 5");
        monitorQueueCheckbox5.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        monitorQueueCheckbox5.setMargin(new java.awt.Insets(0, 0, 0, 0));

        monitorQueueCheckbox6.setText("Monitor Queue 6");
        monitorQueueCheckbox6.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        monitorQueueCheckbox6.setMargin(new java.awt.Insets(0, 0, 0, 0));

        monitorQueueCheckbox7.setText("Monitor Queue 7");
        monitorQueueCheckbox7.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        monitorQueueCheckbox7.setMargin(new java.awt.Insets(0, 0, 0, 0));

        resetSystemButton.setText("Reset System");

        resetTimerButton.setText("Reset Timer");

        tmrResHelpButton.setFont(new java.awt.Font("Dialog", 1, 8));
        tmrResHelpButton.setText("?");
        tmrResHelpButton.setToolTipText("Click for help");
        tmrResHelpButton.setMargin(new java.awt.Insets(0, 0, 0, 0));
        tmrResHelpButton.setPreferredSize(new java.awt.Dimension(25, 25));
        tmrResHelpButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                tmrResHelpButtonActionPerformed(evt);
            }
        });

        tmrResLabel.setText("Timer Resolution:");

        macDestAddrHelpButton.setFont(new java.awt.Font("Dialog", 1, 8));
        macDestAddrHelpButton.setText("?");
        macDestAddrHelpButton.setToolTipText("Click for help");
        macDestAddrHelpButton.setMargin(new java.awt.Insets(0, 0, 0, 0));
        macDestAddrHelpButton.setPreferredSize(new java.awt.Dimension(25, 25));
        macDestAddrHelpButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                macDestAddrHelpButtonActionPerformed(evt);
            }
        });

        macDestAddrLabel.setText("Mac Destination Address:");

        ipDestAddrHelpButton.setFont(new java.awt.Font("Dialog", 1, 8));
        ipDestAddrHelpButton.setText("?");
        ipDestAddrHelpButton.setToolTipText("Click for help");
        ipDestAddrHelpButton.setMargin(new java.awt.Insets(0, 0, 0, 0));
        ipDestAddrHelpButton.setPreferredSize(new java.awt.Dimension(25, 25));
        ipDestAddrHelpButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                ipDestAddrHelpButtonActionPerformed(evt);
            }
        });

        ipDestAddrLabel.setText("IP Destination Address:");

        tmrResSlider.setMajorTickSpacing(1);
        tmrResSlider.setMaximum(7);
        tmrResSlider.setPaintTicks(true);
        tmrResSlider.setSnapToTicks(true);
        tmrResSlider.setValue(0);

        tmrResValueLabel.setText("8 ns");

        macDestAddrTextField.setFont(new java.awt.Font("Courier New", 0, 12));
        macDestAddrTextField.setText("aa:bb:cc:dd:ee:ff");

        macSrcAddrHelpButton.setFont(new java.awt.Font("Dialog", 1, 8));
        macSrcAddrHelpButton.setText("?");
        macSrcAddrHelpButton.setToolTipText("Click for help");
        macSrcAddrHelpButton.setMargin(new java.awt.Insets(0, 0, 0, 0));
        macSrcAddrHelpButton.setPreferredSize(new java.awt.Dimension(25, 25));
        macSrcAddrHelpButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                macSrcAddrHelpButtonActionPerformed(evt);
            }
        });

        macSrcAddrLabel.setText("Mac Source Address:");

        macSrcAddrTextField.setFont(new java.awt.Font("Courier New", 0, 12));
        macSrcAddrTextField.setText("00:11:22:33:44:55");

        ipDestAddrTextField.setFont(new java.awt.Font("Courier New", 0, 12));
        ipDestAddrTextField.setText("192.168.130.100");

        ipSrcAddrHelpButton.setFont(new java.awt.Font("Dialog", 1, 8));
        ipSrcAddrHelpButton.setText("?");
        ipSrcAddrHelpButton.setToolTipText("Click for help");
        ipSrcAddrHelpButton.setMargin(new java.awt.Insets(0, 0, 0, 0));
        ipSrcAddrHelpButton.setPreferredSize(new java.awt.Dimension(25, 25));
        ipSrcAddrHelpButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                ipSrcAddrHelpButtonActionPerformed(evt);
            }
        });

        ipSrcAddrLabel.setText("IP Source Address:");

        ipSrcAddrTextField.setFont(new java.awt.Font("Courier New", 0, 12));
        ipSrcAddrTextField.setText("192.168.130.55");

        udpSrcPortHelpButton.setFont(new java.awt.Font("Dialog", 1, 8));
        udpSrcPortHelpButton.setText("?");
        udpSrcPortHelpButton.setToolTipText("Click for help");
        udpSrcPortHelpButton.setMargin(new java.awt.Insets(0, 0, 0, 0));
        udpSrcPortHelpButton.setPreferredSize(new java.awt.Dimension(25, 25));
        udpSrcPortHelpButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                udpSrcPortHelpButtonActionPerformed(evt);
            }
        });

        udpSrcPortLabel.setText("UDP Source Port:");

        udpSrcPortTextField.setFont(new java.awt.Font("Courier New", 0, 12));
        udpSrcPortTextField.setText("9999");

        udpDestPortHelpButton.setFont(new java.awt.Font("Dialog", 1, 8));
        udpDestPortHelpButton.setText("?");
        udpDestPortHelpButton.setToolTipText("Click for help");
        udpDestPortHelpButton.setMargin(new java.awt.Insets(0, 0, 0, 0));
        udpDestPortHelpButton.setPreferredSize(new java.awt.Dimension(25, 25));
        udpDestPortHelpButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                udpDestPortHelpButtonActionPerformed(evt);
            }
        });

        udpDestPortLabel.setText("UDP Destination Port:");

        udpDestPortTextField.setFont(new java.awt.Font("Courier New", 0, 12));
        udpDestPortTextField.setText("9999");

        graphSizeHelpButton.setFont(new java.awt.Font("Dialog", 1, 8));
        graphSizeHelpButton.setText("?");
        graphSizeHelpButton.setToolTipText("Click for help");
        graphSizeHelpButton.setMargin(new java.awt.Insets(0, 0, 0, 0));
        graphSizeHelpButton.setPreferredSize(new java.awt.Dimension(25, 25));
        graphSizeHelpButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                graphSizeHelpButtonActionPerformed(evt);
            }
        });

        graphSizeLabel.setText("Graph Size (num of points):");

        graphSizeTextField.setFont(new java.awt.Font("Courier New", 0, 12));
        graphSizeTextField.setText("5000");

        jScrollPane1.setBorder(javax.swing.BorderFactory.createBevelBorder(javax.swing.border.BevelBorder.RAISED));
        statsRegTable.setBackground(javax.swing.UIManager.getDefaults().getColor("Label.background"));
        statsRegTable.setFont(new java.awt.Font("Dialog", 1, 12));
        statsRegTable.setGridColor(javax.swing.UIManager.getDefaults().getColor("Label.background"));
        statsRegTable.setRowSelectionAllowed(false);
        statsRegTable.setShowHorizontalLines(false);
        statsRegTable.setShowVerticalLines(false);
        jScrollPane1.setViewportView(statsRegTable);

        numEvtPktsLostValueLabel.setText("0");
        numEvtPktsLostValueLabel.setToolTipText("Number of events packets lost");

        numEvtPktsLostLabel.setText("Number of evt pkts dropped:");
        numEvtPktsLostLabel.setToolTipText("Number of events packets lost");

        javax.swing.GroupLayout evtCapConfigPanelLayout = new javax.swing.GroupLayout(evtCapConfigPanel);
        evtCapConfigPanel.setLayout(evtCapConfigPanelLayout);
        evtCapConfigPanelLayout.setHorizontalGroup(
            evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(evtCapConfigPanelLayout.createSequentialGroup()
                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(10, 10, 10)
                        .addComponent(pageTitleLabel))
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(20, 20, 20)
                        .addComponent(monitorQueueCheckbox0, javax.swing.GroupLayout.PREFERRED_SIZE, 142, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(18, 18, 18)
                        .addComponent(monitorQueueCheckbox1, javax.swing.GroupLayout.PREFERRED_SIZE, 142, javax.swing.GroupLayout.PREFERRED_SIZE))
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(20, 20, 20)
                        .addComponent(monitorQueueCheckbox2, javax.swing.GroupLayout.PREFERRED_SIZE, 142, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(18, 18, 18)
                        .addComponent(monitorQueueCheckbox3, javax.swing.GroupLayout.PREFERRED_SIZE, 142, javax.swing.GroupLayout.PREFERRED_SIZE))
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(20, 20, 20)
                        .addComponent(monitorQueueCheckbox4, javax.swing.GroupLayout.PREFERRED_SIZE, 142, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(18, 18, 18)
                        .addComponent(monitorQueueCheckbox5, javax.swing.GroupLayout.PREFERRED_SIZE, 142, javax.swing.GroupLayout.PREFERRED_SIZE))
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(20, 20, 20)
                        .addComponent(monitorQueueCheckbox6, javax.swing.GroupLayout.PREFERRED_SIZE, 142, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(18, 18, 18)
                        .addComponent(monitorQueueCheckbox7, javax.swing.GroupLayout.PREFERRED_SIZE, 142, javax.swing.GroupLayout.PREFERRED_SIZE))
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(20, 20, 20)
                        .addComponent(macDestAddrHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(10, 10, 10)
                        .addComponent(macDestAddrLabel, javax.swing.GroupLayout.PREFERRED_SIZE, 199, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(31, 31, 31)
                        .addComponent(macDestAddrTextField, javax.swing.GroupLayout.PREFERRED_SIZE, 130, javax.swing.GroupLayout.PREFERRED_SIZE))
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(20, 20, 20)
                        .addComponent(macSrcAddrHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(10, 10, 10)
                        .addComponent(macSrcAddrLabel, javax.swing.GroupLayout.PREFERRED_SIZE, 167, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(63, 63, 63)
                        .addComponent(macSrcAddrTextField, javax.swing.GroupLayout.PREFERRED_SIZE, 130, javax.swing.GroupLayout.PREFERRED_SIZE))
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(20, 20, 20)
                        .addComponent(ipDestAddrHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(10, 10, 10)
                        .addComponent(ipDestAddrLabel, javax.swing.GroupLayout.PREFERRED_SIZE, 186, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(44, 44, 44)
                        .addComponent(ipDestAddrTextField, javax.swing.GroupLayout.PREFERRED_SIZE, 130, javax.swing.GroupLayout.PREFERRED_SIZE))
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(20, 20, 20)
                        .addComponent(ipSrcAddrHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(10, 10, 10)
                        .addComponent(ipSrcAddrLabel, javax.swing.GroupLayout.PREFERRED_SIZE, 154, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGap(76, 76, 76)
                        .addComponent(ipSrcAddrTextField, javax.swing.GroupLayout.PREFERRED_SIZE, 130, javax.swing.GroupLayout.PREFERRED_SIZE))
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(20, 20, 20)
                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING, false)
                            .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                                .addComponent(tmrResHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                                .addGap(10, 10, 10)
                                .addComponent(tmrResLabel, javax.swing.GroupLayout.PREFERRED_SIZE, 130, javax.swing.GroupLayout.PREFERRED_SIZE)
                                .addGap(10, 10, 10)
                                .addComponent(tmrResValueLabel, javax.swing.GroupLayout.PREFERRED_SIZE, 50, javax.swing.GroupLayout.PREFERRED_SIZE)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED, 29, Short.MAX_VALUE)
                                .addComponent(tmrResSlider, javax.swing.GroupLayout.PREFERRED_SIZE, 121, javax.swing.GroupLayout.PREFERRED_SIZE))
                            .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                                .addComponent(graphSizeHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                                .addGap(10, 10, 10)
                                .addComponent(graphSizeLabel, javax.swing.GroupLayout.PREFERRED_SIZE, 210, javax.swing.GroupLayout.PREFERRED_SIZE)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED, 20, Short.MAX_VALUE)
                                .addComponent(graphSizeTextField, javax.swing.GroupLayout.PREFERRED_SIZE, 130, javax.swing.GroupLayout.PREFERRED_SIZE))))
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(20, 20, 20)
                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING, false)
                            .addGroup(evtCapConfigPanelLayout.createSequentialGroup()
                                .addComponent(enabledCheckbox, javax.swing.GroupLayout.PREFERRED_SIZE, 131, javax.swing.GroupLayout.PREFERRED_SIZE)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED, 29, Short.MAX_VALUE)
                                .addComponent(sendToLocalHostCheckbox, javax.swing.GroupLayout.PREFERRED_SIZE, 149, javax.swing.GroupLayout.PREFERRED_SIZE))
                            .addGroup(evtCapConfigPanelLayout.createSequentialGroup()
                                .addComponent(sendToPortCheckbox0, javax.swing.GroupLayout.PREFERRED_SIZE, 129, javax.swing.GroupLayout.PREFERRED_SIZE)
                                .addGap(31, 31, 31)
                                .addComponent(sendToPortCheckbox1, javax.swing.GroupLayout.PREFERRED_SIZE, 129, javax.swing.GroupLayout.PREFERRED_SIZE)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED, 20, Short.MAX_VALUE))
                            .addGroup(evtCapConfigPanelLayout.createSequentialGroup()
                                .addComponent(sendToPortCheckbox2, javax.swing.GroupLayout.PREFERRED_SIZE, 129, javax.swing.GroupLayout.PREFERRED_SIZE)
                                .addGap(31, 31, 31)
                                .addComponent(sendToPortCheckbox3, javax.swing.GroupLayout.PREFERRED_SIZE, 129, javax.swing.GroupLayout.PREFERRED_SIZE)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED, 20, Short.MAX_VALUE)))
                        .addGap(38, 38, 38)
                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING, false)
                            .addComponent(resetTimerButton, javax.swing.GroupLayout.PREFERRED_SIZE, 140, javax.swing.GroupLayout.PREFERRED_SIZE)
                            .addComponent(resetSystemButton, javax.swing.GroupLayout.PREFERRED_SIZE, 140, javax.swing.GroupLayout.PREFERRED_SIZE)))
                    .addGroup(javax.swing.GroupLayout.Alignment.LEADING, evtCapConfigPanelLayout.createSequentialGroup()
                        .addGap(20, 20, 20)
                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addComponent(jScrollPane1, javax.swing.GroupLayout.DEFAULT_SIZE, 443, Short.MAX_VALUE)
                            .addGroup(evtCapConfigPanelLayout.createSequentialGroup()
                                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING, false)
                                    .addGroup(evtCapConfigPanelLayout.createSequentialGroup()
                                        .addComponent(udpDestPortHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                                        .addGap(10, 10, 10)
                                        .addComponent(udpDestPortLabel, javax.swing.GroupLayout.PREFERRED_SIZE, 175, javax.swing.GroupLayout.PREFERRED_SIZE))
                                    .addGroup(evtCapConfigPanelLayout.createSequentialGroup()
                                        .addComponent(udpSrcPortHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                                        .addGap(10, 10, 10)
                                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING, false)
                                            .addComponent(udpSrcPortLabel)
                                            .addComponent(numEvtPktsLostLabel))))
                                .addGap(10, 10, 10)
                                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING, false)
                                    .addComponent(numEvtPktsLostValueLabel)
                                    .addComponent(udpDestPortTextField, javax.swing.GroupLayout.PREFERRED_SIZE, 130, javax.swing.GroupLayout.PREFERRED_SIZE)
                                    .addComponent(udpSrcPortTextField, javax.swing.GroupLayout.PREFERRED_SIZE, 130, javax.swing.GroupLayout.PREFERRED_SIZE))))))
                .addContainerGap())
            .addComponent(jSeparator1, javax.swing.GroupLayout.DEFAULT_SIZE, 475, Short.MAX_VALUE)
        );
        evtCapConfigPanelLayout.setVerticalGroup(
            evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(evtCapConfigPanelLayout.createSequentialGroup()
                .addGap(10, 10, 10)
                .addComponent(pageTitleLabel)
                .addGap(8, 8, 8)
                .addComponent(jSeparator1, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                .addGap(10, 10, 10)
                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addGroup(evtCapConfigPanelLayout.createSequentialGroup()
                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addComponent(enabledCheckbox)
                            .addComponent(sendToLocalHostCheckbox))
                        .addGap(5, 5, 5)
                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addComponent(sendToPortCheckbox0)
                            .addComponent(sendToPortCheckbox1))
                        .addGap(5, 5, 5)
                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addComponent(sendToPortCheckbox2)
                            .addComponent(sendToPortCheckbox3))
                        .addGap(15, 15, 15)
                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addComponent(monitorQueueCheckbox0)
                            .addComponent(monitorQueueCheckbox1))
                        .addGap(5, 5, 5)
                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addComponent(monitorQueueCheckbox2)
                            .addComponent(monitorQueueCheckbox3))
                        .addGap(5, 5, 5)
                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addComponent(monitorQueueCheckbox4)
                            .addComponent(monitorQueueCheckbox5))
                        .addGap(5, 5, 5)
                        .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addComponent(monitorQueueCheckbox6)
                            .addComponent(monitorQueueCheckbox7)))
                    .addGroup(evtCapConfigPanelLayout.createSequentialGroup()
                        .addComponent(resetTimerButton)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(resetSystemButton)))
                .addGap(25, 25, 25)
                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(tmrResHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                    .addComponent(tmrResLabel)
                    .addComponent(tmrResValueLabel)
                    .addComponent(tmrResSlider, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                .addGap(14, 14, 14)
                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(graphSizeHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                    .addComponent(graphSizeLabel)
                    .addComponent(graphSizeTextField, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                .addGap(12, 12, 12)
                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(macDestAddrHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                    .addComponent(macDestAddrLabel)
                    .addComponent(macDestAddrTextField, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                .addGap(2, 2, 2)
                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(macSrcAddrHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                    .addComponent(macSrcAddrLabel)
                    .addComponent(macSrcAddrTextField, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                .addGap(12, 12, 12)
                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(ipDestAddrHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                    .addComponent(ipDestAddrLabel)
                    .addComponent(ipDestAddrTextField, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                .addGap(2, 2, 2)
                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(ipSrcAddrHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                    .addComponent(ipSrcAddrLabel)
                    .addComponent(ipSrcAddrTextField, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                .addGap(12, 12, 12)
                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(udpDestPortHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                    .addComponent(udpDestPortLabel)
                    .addComponent(udpDestPortTextField, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                .addGap(2, 2, 2)
                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addComponent(udpSrcPortHelpButton, javax.swing.GroupLayout.PREFERRED_SIZE, 10, javax.swing.GroupLayout.PREFERRED_SIZE)
                    .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                        .addComponent(udpSrcPortLabel)
                        .addComponent(udpSrcPortTextField, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)))
                .addGap(19, 19, 19)
                .addGroup(evtCapConfigPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                    .addComponent(numEvtPktsLostLabel)
                    .addComponent(numEvtPktsLostValueLabel))
                .addGap(31, 31, 31)
                .addComponent(jScrollPane1, javax.swing.GroupLayout.PREFERRED_SIZE, 81, javax.swing.GroupLayout.PREFERRED_SIZE)
                .addContainerGap(85, Short.MAX_VALUE))
        );
        evtCapScrollPane.setViewportView(evtCapConfigPanel);

        jTabbedPane1.addTab("Configuration", null, evtCapScrollPane, "Click to change configuration options");

        javax.swing.GroupLayout layout = new javax.swing.GroupLayout(getContentPane());
        getContentPane().setLayout(layout);
        layout.setHorizontalGroup(
            layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addComponent(jTabbedPane1, javax.swing.GroupLayout.DEFAULT_SIZE, 619, Short.MAX_VALUE)
        );
        layout.setVerticalGroup(
            layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addComponent(jTabbedPane1, javax.swing.GroupLayout.DEFAULT_SIZE, 697, Short.MAX_VALUE)
        );
        pack();
    }// </editor-fold>//GEN-END:initComponents

    private void formInternalFrameClosing(javax.swing.event.InternalFrameEvent evt) {//GEN-FIRST:event_formInternalFrameClosed
        this.timer.removeActionListener(this.timerActionListener);
        try {
            this.captureThread.setRunning(false);
        } catch (Exception e) {
            // don't do anything
        }
        if(this.enabledCheckbox.isSelected()){
            this.sendToLocalHostHandler(false);
            this.enabledCheckbox.doClick();
        }
    }//GEN-LAST:event_formInternalFrameClosed

    private void graphSizeHelpButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_graphSizeHelpButtonActionPerformed
// TODO add your handling code here:
    }//GEN-LAST:event_graphSizeHelpButtonActionPerformed

    private void udpDestPortHelpButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_udpDestPortHelpButtonActionPerformed
// TODO add your handling code here:
    }//GEN-LAST:event_udpDestPortHelpButtonActionPerformed

    private void udpSrcPortHelpButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_udpSrcPortHelpButtonActionPerformed
// TODO add your handling code here:
    }//GEN-LAST:event_udpSrcPortHelpButtonActionPerformed

    private void ipSrcAddrHelpButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_ipSrcAddrHelpButtonActionPerformed
// TODO add your handling code here:
    }//GEN-LAST:event_ipSrcAddrHelpButtonActionPerformed

    private void ipDestAddrHelpButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_ipDestAddrHelpButtonActionPerformed
//      TODO add your handling code here:
    }//GEN-LAST:event_ipDestAddrHelpButtonActionPerformed

    private void macSrcAddrHelpButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_macSrcAddrHelpButtonActionPerformed
// TODO add your handling code here:
    }//GEN-LAST:event_macSrcAddrHelpButtonActionPerformed

    private void macDestAddrHelpButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_macDestAddrHelpButtonActionPerformed
//      TODO add your handling code here:
    }//GEN-LAST:event_macDestAddrHelpButtonActionPerformed

    private void tmrResHelpButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_tmrResHelpButtonActionPerformed
//      TODO add your handling code here:
    }//GEN-LAST:event_tmrResHelpButtonActionPerformed


    // Variables declaration - do not modify//GEN-BEGIN:variables
    private javax.swing.JCheckBox enabledCheckbox;
    private javax.swing.JPanel evtCapConfigPanel;
    private javax.swing.JScrollPane evtCapScrollPane;
    private javax.swing.JButton graphSizeHelpButton;
    private javax.swing.JLabel graphSizeLabel;
    private javax.swing.JTextField graphSizeTextField;
    private javax.swing.JButton ipDestAddrHelpButton;
    private javax.swing.JLabel ipDestAddrLabel;
    private javax.swing.JTextField ipDestAddrTextField;
    private javax.swing.JButton ipSrcAddrHelpButton;
    private javax.swing.JLabel ipSrcAddrLabel;
    private javax.swing.JTextField ipSrcAddrTextField;
    private javax.swing.JScrollPane jScrollPane1;
    private javax.swing.JSeparator jSeparator1;
    private javax.swing.JTabbedPane jTabbedPane1;
    private javax.swing.JButton macDestAddrHelpButton;
    private javax.swing.JLabel macDestAddrLabel;
    private javax.swing.JTextField macDestAddrTextField;
    private javax.swing.JButton macSrcAddrHelpButton;
    private javax.swing.JLabel macSrcAddrLabel;
    private javax.swing.JTextField macSrcAddrTextField;
    private javax.swing.JCheckBox monitorQueueCheckbox0;
    private javax.swing.JCheckBox monitorQueueCheckbox1;
    private javax.swing.JCheckBox monitorQueueCheckbox2;
    private javax.swing.JCheckBox monitorQueueCheckbox3;
    private javax.swing.JCheckBox monitorQueueCheckbox4;
    private javax.swing.JCheckBox monitorQueueCheckbox5;
    private javax.swing.JCheckBox monitorQueueCheckbox6;
    private javax.swing.JCheckBox monitorQueueCheckbox7;
    private javax.swing.JLabel numEvtPktsLostLabel;
    private javax.swing.JLabel numEvtPktsLostValueLabel;
    private javax.swing.JLabel pageTitleLabel;
    private javax.swing.JButton resetSystemButton;
    private javax.swing.JButton resetTimerButton;
    private javax.swing.JCheckBox sendToLocalHostCheckbox;
    private javax.swing.JCheckBox sendToPortCheckbox0;
    private javax.swing.JCheckBox sendToPortCheckbox1;
    private javax.swing.JCheckBox sendToPortCheckbox2;
    private javax.swing.JCheckBox sendToPortCheckbox3;
    private javax.swing.JTable statsRegTable;
    private javax.swing.JButton tmrResHelpButton;
    private javax.swing.JLabel tmrResLabel;
    private javax.swing.JSlider tmrResSlider;
    private javax.swing.JLabel tmrResValueLabel;
    private javax.swing.JButton udpDestPortHelpButton;
    private javax.swing.JLabel udpDestPortLabel;
    private javax.swing.JTextField udpDestPortTextField;
    private javax.swing.JButton udpSrcPortHelpButton;
    private javax.swing.JLabel udpSrcPortLabel;
    private javax.swing.JTextField udpSrcPortTextField;
    // End of variables declaration//GEN-END:variables

    public void packetArrived(Packet packet) {
//        System.out.println("Captured Packet:");
//        System.out.println(packet);
        processPacketData(packet.getData());
    }

}

class CaptureThread extends Thread {
    public CaptureThread(PacketCapture pc) {
        this.pc = pc;
        running = true;
    }

    public void run() {
        try {
            while(running){
//                System.out.println("Starting capture");
                pc.capture(-1);
//                System.out.println("Captured packet");
            }
        } catch (CapturePacketException cpe) {
            cpe.printStackTrace();
        }
    }

    private PacketCapture pc;
    private boolean running;

    public boolean isRunning() {
        return running;
    }

    public void setRunning(boolean running) {
        this.running = running;
    }
}
