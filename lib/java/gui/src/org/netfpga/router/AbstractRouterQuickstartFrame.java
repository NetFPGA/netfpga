package org.netfpga.router;
/*
 * AbstractRouterQuickstartFrame.java
 *
 * Created on May 6, 2007, 12:35 PM
 */

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.awt.Component;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileReader;

import javax.swing.JFileChooser;
import javax.swing.JInternalFrame;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.ListSelectionModel;
import javax.swing.Timer;
import javax.swing.event.ListSelectionEvent;
import javax.swing.event.ListSelectionListener;

import org.netfpga.backend.NFDevice;
import org.netfpga.backend.NFDeviceConsts;

/**
 *
 * @author jnaous
*/
@SuppressWarnings("serial")
public abstract class AbstractRouterQuickstartFrame extends JInternalFrame {

    private static final int STATS_NUM_REGS_USED = 12;

    private static final String RT_TABLE_KEYWORD = "ROUTE_TABLE";

    private static final int RT_ENTRY_LENGTH = 6;

    private static final String ARP_TABLE_KEYWORD = "ARP_TABLE";

    private static final int ARP_ENTRY_LENGTH = 4;

    private static final String PORT_KEYWORD = "PORT";

    private static final int PORT_ENTRY_LENGTH = 4;

    private RoutingTableModel routingTableModel;

    private ARPTableModel arpTableModel;

    private InterfacePortConfigTableModel ifaceTableModel;

    private StatsRegTableModel statsRegTableModel;

    protected AbstractMainFrame mainFrame;

    protected NFDevice nf2;

    protected Timer updateTimer;

    private JPanel detailsPanel;

    /**
     * Creates new form AbstractRouterQuickstartFrame
     *
     * @param nf2
     *            Device to bind to
     * @param mainFrame
     *            parent frame
     */
    public AbstractRouterQuickstartFrame(NFDevice nf2, Timer updateTimer,
            AbstractMainFrame mainFrame) {

        this.nf2 = nf2;
        this.updateTimer = updateTimer;
        this.mainFrame = mainFrame;

        routingTableModel = new RoutingTableModel(nf2);
        arpTableModel = new ARPTableModel(nf2);
        ifaceTableModel = new InterfacePortConfigTableModel(nf2);

        initComponents();

        detailsPanel = this.getDetailsPanel();
        this.routerDetailsScrollPane.setViewportView(detailsPanel);
        this.routerDetailsScrollPane.setName("detailsscrollpane");

        setupStatsTable(nf2);

        /*
         * set to single selection since the selected row doesn't get updates
         */
        routingTable.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);
        arpTable.setSelectionMode(ListSelectionModel.SINGLE_SELECTION);

        /* Set name for jemmy automatic test */
        arpTable.setName("arpTable");


        /* on selection changes, flush modified entries */
        routingTable.getSelectionModel().addListSelectionListener(
                new ListSelectionListener() {

                    public void valueChanged(ListSelectionEvent e) {
                        routingTableModel.flushTable();
                    }

                });

        arpTable.getSelectionModel().addListSelectionListener(
                new ListSelectionListener() {

                    public void valueChanged(ListSelectionEvent e) {
                        arpTableModel.flushTable();
                    }

                });

        AutofitTableColumns.autoResizeTable(routingTable, true);
        AutofitTableColumns.autoResizeTable(arpTable, true);

        this.mainFrame = mainFrame;

        this.nf2 = nf2;
        this.updateTimer = updateTimer;

        /* add action listener to the timer */
        updateTimer.addActionListener(new ActionListener() {

            public void actionPerformed(ActionEvent e) {
                routingTableModel.updateTable();
                arpTableModel.updateTable();
                ifaceTableModel.updateTable();
                statsRegTableModel.updateTable();
            }

        });

    }

    /**
     * Sets up statistics table for the statistics tab
     * @param nf2
     */
    private void setupStatsTable(NFDevice nf2) {
        /* add the addresses to monitor through statsRegTableModel */
        long[] aAddresses = new long[STATS_NUM_REGS_USED];
        /* get the difference between two MAC blocks of addresses */
        aAddresses[0] = NFDeviceConsts.MAC_GRP_0_RX_QUEUE_NUM_PKTS_STORED_REG;
        aAddresses[1] = NFDeviceConsts.MAC_GRP_1_RX_QUEUE_NUM_PKTS_STORED_REG;
        aAddresses[2] = NFDeviceConsts.MAC_GRP_2_RX_QUEUE_NUM_PKTS_STORED_REG;
        aAddresses[3] = NFDeviceConsts.MAC_GRP_3_RX_QUEUE_NUM_PKTS_STORED_REG;

        aAddresses[4] = NFDeviceConsts.MAC_GRP_0_TX_QUEUE_NUM_PKTS_SENT_REG;
        aAddresses[5] = NFDeviceConsts.MAC_GRP_1_TX_QUEUE_NUM_PKTS_SENT_REG;
        aAddresses[6] = NFDeviceConsts.MAC_GRP_2_TX_QUEUE_NUM_PKTS_SENT_REG;
        aAddresses[7] = NFDeviceConsts.MAC_GRP_3_TX_QUEUE_NUM_PKTS_SENT_REG;

        /* the MAC output queues are the even numbered queues */
        aAddresses[8] = NFDeviceConsts.OQ_QUEUE_0_NUM_PKTS_DROPPED_REG;
        aAddresses[9] = NFDeviceConsts.OQ_QUEUE_2_NUM_PKTS_DROPPED_REG;
        aAddresses[10] = NFDeviceConsts.OQ_QUEUE_4_NUM_PKTS_DROPPED_REG;
        aAddresses[11] = NFDeviceConsts.OQ_QUEUE_6_NUM_PKTS_DROPPED_REG;

        /* create the register table model which we want to monitor */
        statsRegTableModel = new StatsRegTableModel(nf2, aAddresses);

        statsRegTableModel.setGraph(0, (GraphPanel)this.pktsRcvdChart0);
        statsRegTableModel.setGraph(1, (GraphPanel)this.pktsRcvdChart1);
        statsRegTableModel.setGraph(2, (GraphPanel)this.pktsRcvdChart2);
        statsRegTableModel.setGraph(3, (GraphPanel)this.pktsRcvdChart3);
        statsRegTableModel.setGraph(4, (GraphPanel)this.pktsSentChart0);
        statsRegTableModel.setGraph(5, (GraphPanel)this.pktsSentChart1);
        statsRegTableModel.setGraph(6, (GraphPanel)this.pktsSentChart2);
        statsRegTableModel.setGraph(7, (GraphPanel)this.pktsSentChart3);
        statsRegTableModel.setGraph(8, (GraphPanel)this.pktsDroppedChart0);
        statsRegTableModel.setGraph(9, (GraphPanel)this.pktsDroppedChart1);
        statsRegTableModel.setGraph(10, (GraphPanel)this.pktsDroppedChart2);
        statsRegTableModel.setGraph(11, (GraphPanel)this.pktsDroppedChart3);

        for(int i=0; i<STATS_NUM_REGS_USED; i++){
            statsRegTableModel.setDifferentialGraph(i, true);
        }
    }

    /**
     * This method is called from within the constructor to initialize the form.
     * WARNING: Do NOT modify this code. The content of this method is always
     * regenerated by the Form Editor.
     */
    // <editor-fold defaultstate="collapsed" desc=" Generated Code ">//GEN-BEGIN:initComponents
    private void initComponents() {
        routerTabbedPane = new javax.swing.JTabbedPane();
        routerConfigScrollPane = new javax.swing.JScrollPane();
        routerConfigPane = new javax.swing.JPanel();
        ifaceTableScrollPane = new javax.swing.JScrollPane();
        ifaceTable = new javax.swing.JTable();
        arpTableScrollPane = new javax.swing.JScrollPane();
        arpTable = new javax.swing.JTable();
        routingTableScrollPane = new javax.swing.JScrollPane();
        routingTable = new javax.swing.JTable();
        ifaceConfigLabel = new javax.swing.JLabel();
        arpTableLabel = new javax.swing.JLabel();
        routingTableLabel = new javax.swing.JLabel();
        arpRemoveEntryButton = new javax.swing.JButton();
        routingRemoveEntryButton = new javax.swing.JButton();
        loadConfigFromFileButton = new javax.swing.JButton();
        pageTitleLabel = new javax.swing.JLabel();
        routerStatsScrollPane = new javax.swing.JScrollPane();
        quickStartPanel = new javax.swing.JPanel();
        pktsRcvdChart0 = new BarGraphPanel("Port 0 Pkts Rcvd", "Pkts Rcvd", "time", "Number of Packets", 2000);
        pktsRcvdChart1 = new BarGraphPanel("Port 1 Pkts Rcvd", "Pkts Rcvd", "time", "Number of Packets", 2000);
        pktsRcvdChart2 = new BarGraphPanel("Port 2 Pkts Rcvd", "Pkts Rcvd", "time", "Number of Packets", 2000);
        pktsRcvdChart3 = new BarGraphPanel("Port 3 Pkts Rcvd", "Pkts Rcvd", "time", "Number of Packets", 2000);
        pktsSentChart0 = new BarGraphPanel("Port 0 Pkts Sent", "Pkts Sent", "time", "Number of Packets", 2000);
        pktsSentChart1 = new BarGraphPanel("Port 1 Pkts Sent", "Pkts Sent", "time", "Number of Packets", 2000);
        pktsSentChart2 = new BarGraphPanel("Port 2 Pkts Sent", "Pkts Sent", "time", "Number of Packets", 2000);
        pktsSentChart3 = new BarGraphPanel("Port 3 Pkts Sent", "Pkts Sent", "time", "Number of Packets", 2000);
        pktsDroppedChart0 = new BarGraphPanel("Port 0 Pkts Dropped", "Pkts Sent", "time", "Number of Packets", 2000);
        pktsDroppedChart0.setName("first chart");
        pktsDroppedChart1 = new BarGraphPanel("Port 1 Pkts Dropped", "Pkts Sent", "time", "Number of Packets", 2000);
        pktsDroppedChart2 = new BarGraphPanel("Port 2 Pkts Dropped", "Pkts Sent", "time", "Number of Packets", 2000);
        pktsDroppedChart3 = new BarGraphPanel("Port 3 Pkts Dropped", "Pkts Sent", "time", "Number of Packets", 2000);
        clearStatsButton = new javax.swing.JButton();
        routerDetailsScrollPane = new javax.swing.JScrollPane();

        //setClosable(true);
        setIconifiable(true);
        setMaximizable(true);
        setResizable(true);
        setTitle("Router Quickstart");
        ifaceTable.setModel(ifaceTableModel);

        /* Set name for jemmy automatic test  */
        ifaceTable.setName("ifaceTable");

        ifaceTableScrollPane.setViewportView(ifaceTable);

        arpTable.setModel(arpTableModel);
        arpTableScrollPane.setViewportView(arpTable);

        routingTable.setModel(routingTableModel);

        /* Set name for jemmy automatic test */
        routingTable.setName("routingTable");

        routingTableScrollPane.setViewportView(routingTable);

        ifaceConfigLabel.setText("Interface Configuration");

        arpTableLabel.setText("ARP Table");

        routingTableLabel.setText("Routing Table");

        arpRemoveEntryButton.setText("Reset Entry");
        arpRemoveEntryButton.setMargin(new java.awt.Insets(2, 2, 2, 2));
        arpRemoveEntryButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                arpRemoveEntryButtonActionPerformed(evt);
            }
        });

        routingRemoveEntryButton.setText("Reset Entry");
        routingRemoveEntryButton.setMargin(new java.awt.Insets(2, 2, 2, 2));
        routingRemoveEntryButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                routingRemoveEntryButtonActionPerformed(evt);
            }
        });

        loadConfigFromFileButton.setText("Load From File");
        loadConfigFromFileButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                loadConfigFromFileButtonActionPerformed(evt);
            }
        });

        pageTitleLabel.setFont(new java.awt.Font("Dialog", 1, 18));
        pageTitleLabel.setText("Router Configuration");

        org.jdesktop.layout.GroupLayout routerConfigPaneLayout = new org.jdesktop.layout.GroupLayout(routerConfigPane);
        routerConfigPane.setLayout(routerConfigPaneLayout);
        routerConfigPaneLayout.setHorizontalGroup(
            routerConfigPaneLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(routerConfigPaneLayout.createSequentialGroup()
                .add(routerConfigPaneLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
                    .add(org.jdesktop.layout.GroupLayout.TRAILING, routerConfigPaneLayout.createSequentialGroup()
                        .add(12, 12, 12)
                        .add(routerConfigPaneLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.TRAILING)
                            .add(org.jdesktop.layout.GroupLayout.LEADING, ifaceTableScrollPane, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 683, Short.MAX_VALUE)
                            .add(org.jdesktop.layout.GroupLayout.LEADING, pageTitleLabel)
                            .add(org.jdesktop.layout.GroupLayout.LEADING, routerConfigPaneLayout.createSequentialGroup()
                                .addPreferredGap(org.jdesktop.layout.LayoutStyle.RELATED)
                                .add(ifaceConfigLabel)
                                .addPreferredGap(org.jdesktop.layout.LayoutStyle.RELATED, 412, Short.MAX_VALUE)
                                .add(loadConfigFromFileButton))))
                    .add(routerConfigPaneLayout.createSequentialGroup()
                        .addContainerGap()
                        .add(routingTableLabel)
                        .addPreferredGap(org.jdesktop.layout.LayoutStyle.RELATED, 501, Short.MAX_VALUE)
                        .add(routingRemoveEntryButton))
                    .add(org.jdesktop.layout.GroupLayout.TRAILING, routerConfigPaneLayout.createSequentialGroup()
                        .addContainerGap()
                        .add(routingTableScrollPane, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 683, Short.MAX_VALUE))
                    .add(routerConfigPaneLayout.createSequentialGroup()
                        .addContainerGap()
                        .add(arpTableLabel)
                        .addPreferredGap(org.jdesktop.layout.LayoutStyle.RELATED, 526, Short.MAX_VALUE)
                        .add(arpRemoveEntryButton))
                    .add(org.jdesktop.layout.GroupLayout.TRAILING, routerConfigPaneLayout.createSequentialGroup()
                        .addContainerGap()
                        .add(arpTableScrollPane, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 683, Short.MAX_VALUE)))
                .addContainerGap())
        );
        routerConfigPaneLayout.setVerticalGroup(
            routerConfigPaneLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(routerConfigPaneLayout.createSequentialGroup()
                .add(12, 12, 12)
                .add(pageTitleLabel)
                .add(28, 28, 28)
                .add(routerConfigPaneLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.BASELINE)
                    .add(ifaceConfigLabel)
                    .add(loadConfigFromFileButton))
                .addPreferredGap(org.jdesktop.layout.LayoutStyle.RELATED)
                .add(ifaceTableScrollPane, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE, 83, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE)
                .add(25, 25, 25)
                .add(routerConfigPaneLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.BASELINE)
                    .add(routingTableLabel)
                    .add(routingRemoveEntryButton))
                .addPreferredGap(org.jdesktop.layout.LayoutStyle.RELATED)
                .add(routingTableScrollPane, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE, 190, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE)
                .add(43, 43, 43)
                .add(routerConfigPaneLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.BASELINE)
                    .add(arpTableLabel)
                    .add(arpRemoveEntryButton))
                .addPreferredGap(org.jdesktop.layout.LayoutStyle.RELATED)
                .add(arpTableScrollPane, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 220, Short.MAX_VALUE)
                .addContainerGap())
        );
        routerConfigScrollPane.setViewportView(routerConfigPane);

        routerTabbedPane.addTab("Configuration", null, routerConfigScrollPane, "Has configuration settings for the router");

        pktsRcvdChart0.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsRcvdChart0Layout = new org.jdesktop.layout.GroupLayout(pktsRcvdChart0);
        pktsRcvdChart0.setLayout(pktsRcvdChart0Layout);
        pktsRcvdChart0Layout.setHorizontalGroup(
            pktsRcvdChart0Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsRcvdChart0Layout.setVerticalGroup(
            pktsRcvdChart0Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        pktsRcvdChart1.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsRcvdChart1Layout = new org.jdesktop.layout.GroupLayout(pktsRcvdChart1);
        pktsRcvdChart1.setLayout(pktsRcvdChart1Layout);
        pktsRcvdChart1Layout.setHorizontalGroup(
            pktsRcvdChart1Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsRcvdChart1Layout.setVerticalGroup(
            pktsRcvdChart1Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        pktsRcvdChart2.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsRcvdChart2Layout = new org.jdesktop.layout.GroupLayout(pktsRcvdChart2);
        pktsRcvdChart2.setLayout(pktsRcvdChart2Layout);
        pktsRcvdChart2Layout.setHorizontalGroup(
            pktsRcvdChart2Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsRcvdChart2Layout.setVerticalGroup(
            pktsRcvdChart2Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        pktsRcvdChart3.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsRcvdChart3Layout = new org.jdesktop.layout.GroupLayout(pktsRcvdChart3);
        pktsRcvdChart3.setLayout(pktsRcvdChart3Layout);
        pktsRcvdChart3Layout.setHorizontalGroup(
            pktsRcvdChart3Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsRcvdChart3Layout.setVerticalGroup(
            pktsRcvdChart3Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        pktsSentChart0.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsSentChart0Layout = new org.jdesktop.layout.GroupLayout(pktsSentChart0);
        pktsSentChart0.setLayout(pktsSentChart0Layout);
        pktsSentChart0Layout.setHorizontalGroup(
            pktsSentChart0Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsSentChart0Layout.setVerticalGroup(
            pktsSentChart0Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        pktsSentChart1.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsSentChart1Layout = new org.jdesktop.layout.GroupLayout(pktsSentChart1);
        pktsSentChart1.setLayout(pktsSentChart1Layout);
        pktsSentChart1Layout.setHorizontalGroup(
            pktsSentChart1Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsSentChart1Layout.setVerticalGroup(
            pktsSentChart1Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        pktsSentChart2.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsSentChart2Layout = new org.jdesktop.layout.GroupLayout(pktsSentChart2);
        pktsSentChart2.setLayout(pktsSentChart2Layout);
        pktsSentChart2Layout.setHorizontalGroup(
            pktsSentChart2Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsSentChart2Layout.setVerticalGroup(
            pktsSentChart2Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        pktsSentChart3.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsSentChart3Layout = new org.jdesktop.layout.GroupLayout(pktsSentChart3);
        pktsSentChart3.setLayout(pktsSentChart3Layout);
        pktsSentChart3Layout.setHorizontalGroup(
            pktsSentChart3Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsSentChart3Layout.setVerticalGroup(
            pktsSentChart3Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        pktsDroppedChart0.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsDroppedChart0Layout = new org.jdesktop.layout.GroupLayout(pktsDroppedChart0);
        pktsDroppedChart0.setLayout(pktsDroppedChart0Layout);
        pktsDroppedChart0Layout.setHorizontalGroup(
            pktsDroppedChart0Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsDroppedChart0Layout.setVerticalGroup(
            pktsDroppedChart0Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        pktsDroppedChart1.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsDroppedChart1Layout = new org.jdesktop.layout.GroupLayout(pktsDroppedChart1);
        pktsDroppedChart1.setLayout(pktsDroppedChart1Layout);
        pktsDroppedChart1Layout.setHorizontalGroup(
            pktsDroppedChart1Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsDroppedChart1Layout.setVerticalGroup(
            pktsDroppedChart1Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        pktsDroppedChart2.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsDroppedChart2Layout = new org.jdesktop.layout.GroupLayout(pktsDroppedChart2);
        pktsDroppedChart2.setLayout(pktsDroppedChart2Layout);
        pktsDroppedChart2Layout.setHorizontalGroup(
            pktsDroppedChart2Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsDroppedChart2Layout.setVerticalGroup(
            pktsDroppedChart2Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        pktsDroppedChart3.setPreferredSize(new java.awt.Dimension(260, 210));
        org.jdesktop.layout.GroupLayout pktsDroppedChart3Layout = new org.jdesktop.layout.GroupLayout(pktsDroppedChart3);
        pktsDroppedChart3.setLayout(pktsDroppedChart3Layout);
        pktsDroppedChart3Layout.setHorizontalGroup(
            pktsDroppedChart3Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 260, Short.MAX_VALUE)
        );
        pktsDroppedChart3Layout.setVerticalGroup(
            pktsDroppedChart3Layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 210, Short.MAX_VALUE)
        );

        clearStatsButton.setText("Clear Stats");
        clearStatsButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                clearStatsButtonActionPerformed(evt);
            }
        });

        org.jdesktop.layout.GroupLayout quickStartPanelLayout = new org.jdesktop.layout.GroupLayout(quickStartPanel);
        quickStartPanel.setLayout(quickStartPanelLayout);
        quickStartPanelLayout.setHorizontalGroup(
            quickStartPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(quickStartPanelLayout.createSequentialGroup()
                .add(10, 10, 10)
                .add(quickStartPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
                    .add(quickStartPanelLayout.createSequentialGroup()
                        .add(pktsRcvdChart0, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                        .add(20, 20, 20)
                        .add(pktsSentChart0, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                        .add(20, 20, 20)
                        .add(pktsDroppedChart0, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                    .add(quickStartPanelLayout.createSequentialGroup()
                        .add(pktsRcvdChart1, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                        .add(20, 20, 20)
                        .add(pktsSentChart1, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                        .add(20, 20, 20)
                        .add(pktsDroppedChart1, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                    .add(quickStartPanelLayout.createSequentialGroup()
                        .add(pktsRcvdChart2, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                        .add(20, 20, 20)
                        .add(pktsSentChart2, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                        .add(20, 20, 20)
                        .add(pktsDroppedChart2, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                    .add(quickStartPanelLayout.createSequentialGroup()
                        .add(pktsRcvdChart3, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                        .add(20, 20, 20)
                        .add(pktsSentChart3, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                        .add(20, 20, 20)
                        .add(pktsDroppedChart3, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)))
                .add(28, 28, 28))
            .add(quickStartPanelLayout.createSequentialGroup()
                .addContainerGap()
                .add(clearStatsButton)
                .addContainerGap(745, Short.MAX_VALUE))
        );
        quickStartPanelLayout.setVerticalGroup(
            quickStartPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(quickStartPanelLayout.createSequentialGroup()
                .addContainerGap()
                .add(clearStatsButton)
                .addPreferredGap(org.jdesktop.layout.LayoutStyle.RELATED)
                .add(quickStartPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
                    .add(pktsRcvdChart0, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                    .add(pktsSentChart0, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                    .add(pktsDroppedChart0, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                .add(20, 20, 20)
                .add(quickStartPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
                    .add(pktsRcvdChart1, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                    .add(pktsSentChart1, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                    .add(pktsDroppedChart1, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                .add(20, 20, 20)
                .add(quickStartPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
                    .add(pktsRcvdChart2, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                    .add(pktsSentChart2, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                    .add(pktsDroppedChart2, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                .add(20, 20, 20)
                .add(quickStartPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
                    .add(pktsRcvdChart3, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                    .add(pktsSentChart3, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                    .add(pktsDroppedChart3, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                .add(18, 18, 18))
        );
        routerStatsScrollPane.setViewportView(quickStartPanel);

        routerTabbedPane.addTab("Statistics", null, routerStatsScrollPane, "Displays statistics on packets going through the router");

        routerTabbedPane.addTab("Details", null, routerDetailsScrollPane, "Access hardware specific details of the router");

        org.jdesktop.layout.GroupLayout layout = new org.jdesktop.layout.GroupLayout(getContentPane());
        getContentPane().setLayout(layout);
        layout.setHorizontalGroup(
            layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(routerTabbedPane, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 730, Short.MAX_VALUE)
        );
        layout.setVerticalGroup(
            layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(routerTabbedPane, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 710, Short.MAX_VALUE)
        );
        pack();
    }// </editor-fold>//GEN-END:initComponents

    private void clearStatsButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_clearStatsButtonActionPerformed
        this.statsRegTableModel.clearAll();
    }//GEN-LAST:event_clearStatsButtonActionPerformed

    private void routingRemoveEntryButtonActionPerformed(
            java.awt.event.ActionEvent evt) {//GEN-FIRST:event_routingRemoveEntryButtonActionPerformed
        routingTableModel.clear(routingTable.getSelectedRow());
    }//GEN-LAST:event_routingRemoveEntryButtonActionPerformed

    private void arpRemoveEntryButtonActionPerformed(
            java.awt.event.ActionEvent evt) {//GEN-FIRST:event_arpRemoveEntryButtonActionPerformed
        arpTableModel.clear(arpTable.getSelectedRow());
    }//GEN-LAST:event_arpRemoveEntryButtonActionPerformed

    private void loadConfigFromFileButtonActionPerformed(
            java.awt.event.ActionEvent evt) {//GEN-FIRST:event_loadConfigFromFileButtonActionPerformed
        String filename = System.getenv("/") + File.separator + "config";
        JFileChooser fc = new JFileChooser(new File(filename));

        // Show open dialog; this method does not return until the dialog is closed
        fc.showOpenDialog(this);
        File selFile = fc.getSelectedFile();

        if(selFile == null){
            return;
        }

        /* read the configuration file */
        String line;
        try {
            BufferedReader in = new BufferedReader(new FileReader(selFile));

            // Continue to read lines while
            // there are still some left to read
            int i=0;
            while ((line = in.readLine())!=null) {
                String[] values = line.split(" ");

                /* if it's a routing table entry */
                if(line.startsWith(RT_TABLE_KEYWORD)){
                    if(values.length<RT_ENTRY_LENGTH){
                        JOptionPane.showMessageDialog(null, "Error reading line "+i+
                            ". RT Entry should be: \n" +
                            "RT <index> <destIP> <subnetMask> <nextHopIP> <outPorts>");
                        continue;
                    }
                    try {
                        int index = Integer.parseInt(values[1]);
                        IPAddress dest = new IPAddress(values[2]);
                        IPAddress mask = new IPAddress(values[3]);
                        IPAddress nextHop = new IPAddress(values[4]);
                        int outPorts = Integer.parseInt(values[5], 16);
                        this.routingTableModel.setValueAt(dest, index, RoutingTableModel.SUBNET_IP_COL);
                        this.routingTableModel.setValueAt(mask, index, RoutingTableModel.SUBNET_MASK_COL);
                        this.routingTableModel.setValueAt(nextHop, index, RoutingTableModel.NEXT_HOP_IP_COL);

                        this.routingTableModel.setValueAt(new Boolean((outPorts&1)==1), index, RoutingTableModel.OUTPUT_MAC_0_COL);
                        outPorts >>= 1;

                        this.routingTableModel.setValueAt(new Boolean((outPorts&1)==1), index, RoutingTableModel.OUTPUT_CPU_0_COL);
                        outPorts >>= 1;

                        this.routingTableModel.setValueAt(new Boolean((outPorts&1)==1), index, RoutingTableModel.OUTPUT_MAC_1_COL);
                        outPorts >>= 1;

                        this.routingTableModel.setValueAt(new Boolean((outPorts&1)==1), index, RoutingTableModel.OUTPUT_CPU_1_COL);
                        outPorts >>= 1;

                        this.routingTableModel.setValueAt(new Boolean((outPorts&1)==1), index, RoutingTableModel.OUTPUT_MAC_2_COL);
                        outPorts >>= 1;

                        this.routingTableModel.setValueAt(new Boolean((outPorts&1)==1), index, RoutingTableModel.OUTPUT_CPU_2_COL);
                        outPorts >>= 1;

                        this.routingTableModel.setValueAt(new Boolean((outPorts&1)==1), index, RoutingTableModel.OUTPUT_MAC_3_COL);
                        outPorts >>= 1;

                        this.routingTableModel.setValueAt(new Boolean((outPorts&1)==1), index, RoutingTableModel.OUTPUT_CPU_3_COL);
                        outPorts >>= 1;

                        this.routingTableModel.flushTable();
                    } catch (Exception e) {
                        JOptionPane.showMessageDialog(null, "Error parsing routing table entry.\n"+line);
                        e.printStackTrace();
                    }

                }

                /* write the arp entry */
                else if(line.startsWith(ARP_TABLE_KEYWORD)){
                    if(values.length<ARP_ENTRY_LENGTH){
                        JOptionPane.showMessageDialog(null, "Error reading line "+i+
                            ". ARP Entry should be: \n" +
                            "ARP <index> <nextHopIP> <MAC>");
                        continue;
                    }
                    try {
                        int index = Integer.parseInt(values[1]);
                        IPAddress nextHop = new IPAddress(values[2]);
                        MACAddress mac = new MACAddress(values[3]);
                        this.arpTableModel.setValueAt(nextHop, index, ARPTableModel.IP_COL);
                        this.arpTableModel.setValueAt(mac, index, ARPTableModel.MAC_COL);

                        this.arpTableModel.flushTable();
                    } catch (Exception e) {
                        JOptionPane.showMessageDialog(null, "Error parsing ARP table entry.\n"+line);
                        e.printStackTrace();
                    }
                }

                /* write port config table */
                else if(line.startsWith(PORT_KEYWORD)){
                    if(values.length<PORT_ENTRY_LENGTH){
                        JOptionPane.showMessageDialog(null, "Error reading line "+i+
                            ". Port Entry should be: \n" +
                            "PORT <index> <MAC> <IP>");
                        continue;
                    }
                    try {
                        int index = Integer.parseInt(values[1]);
                        MACAddress mac = new MACAddress(values[2]);
                        IPAddress ip = new IPAddress(values[3]);
                        this.ifaceTableModel.setValueAt(mac, index, InterfacePortConfigTableModel.MAC_COL);
                        this.ifaceTableModel.setValueAt(ip, index, InterfacePortConfigTableModel.IP_COL);
                    } catch (Exception e) {
                        JOptionPane.showMessageDialog(null, "Error parsing port table entry.\n"+line);
                        e.printStackTrace();
                    }
                }

                i++;
            }

            in.close();
        } catch (Exception e) {
            System.err.println("File input error reading configuration file");
            e.printStackTrace();
        }
    }//GEN-LAST:event_loadConfigFromFileButtonActionPerformed

    /**
     * @return the Panel that should be under the
     * details tab.
     */
    protected abstract JPanel getDetailsPanel();

    // Variables declaration - do not modify//GEN-BEGIN:variables
    private javax.swing.JButton arpRemoveEntryButton;
    private javax.swing.JTable arpTable;
    private javax.swing.JLabel arpTableLabel;
    private javax.swing.JScrollPane arpTableScrollPane;
    private javax.swing.JButton clearStatsButton;
    private javax.swing.JLabel ifaceConfigLabel;
    private javax.swing.JTable ifaceTable;
    private javax.swing.JScrollPane ifaceTableScrollPane;
    private javax.swing.JButton loadConfigFromFileButton;
    private javax.swing.JLabel pageTitleLabel;
    private javax.swing.JPanel pktsDroppedChart0;
    private javax.swing.JPanel pktsDroppedChart1;
    private javax.swing.JPanel pktsDroppedChart2;
    private javax.swing.JPanel pktsDroppedChart3;
    private javax.swing.JPanel pktsRcvdChart0;
    private javax.swing.JPanel pktsRcvdChart1;
    private javax.swing.JPanel pktsRcvdChart2;
    private javax.swing.JPanel pktsRcvdChart3;
    private javax.swing.JPanel pktsSentChart0;
    private javax.swing.JPanel pktsSentChart1;
    private javax.swing.JPanel pktsSentChart2;
    private javax.swing.JPanel pktsSentChart3;
    private javax.swing.JPanel quickStartPanel;
    private javax.swing.JPanel routerConfigPane;
    private javax.swing.JScrollPane routerConfigScrollPane;
    private javax.swing.JScrollPane routerDetailsScrollPane;
    private javax.swing.JScrollPane routerStatsScrollPane;
    private javax.swing.JTabbedPane routerTabbedPane;
    private javax.swing.JButton routingRemoveEntryButton;
    private javax.swing.JTable routingTable;
    private javax.swing.JLabel routingTableLabel;
    private javax.swing.JScrollPane routingTableScrollPane;
    // End of variables declaration//GEN-END:variables

}
