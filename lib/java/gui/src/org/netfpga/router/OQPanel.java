package org.netfpga.router;
/*
 * OQPanel.java
 *
 * Created on May 7, 2007, 10:31 PM
 */

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

import javax.swing.AbstractButton;
import javax.swing.Timer;

import org.netfpga.backend.NFDevice;
import org.netfpga.backend.NFDeviceConsts;

/**
 *
 * @author  jnaous
 */
@SuppressWarnings("serial")
public class OQPanel extends javax.swing.JPanel {

    private StatsRegTableModel statsRegTableModel;
    private RegSliderGroupControl oqByteSizeSliderCtrl;
    private RegSliderGroupControl oqPktSizeSliderCtrl;
    private ControlRegGroup ctrlRegGrp;

    private Timer timer;
    private ActionListener timerActionListener;

    private static final int STATS_NUM_REGS_USED = 7;
    private static final int QUEUE_SIZE = 512; // kB
    protected static final int MAX_NUM_PKTS_SIZE = 16;
    protected static final int MAX_NUM_PKTS = (int)Math.round(Math.pow(2,MAX_NUM_PKTS_SIZE))-1;

    /** Creates new form OQPanel */
    public OQPanel(NFDevice nf2, Timer timer, int index) {

        initComponents();

        this.timer = timer;
        setupStatsTable(nf2, index);
        this.statsRegTable.setModel(statsRegTableModel);
        ((StatsRegTable)this.statsRegTable).setDefaults();

        /* create controllers for the sliders */
        oqByteSizeSliderCtrl = new RegSliderGroupControl(nf2, this.oqByteSizeSlider,
                this.oqByteSizeValueLabel,
                NFDeviceConsts.OQ_QUEUE_0_FULL_THRESH_REG+index*512);
        oqByteSizeSliderCtrl.setVt(new ValueTransformer(){

            public int toRegisterValue(int val) {
                /* change number in 64-bit words */
                return (QUEUE_SIZE-val)*1024/8;
            }

            public int toSliderValue(int val) {
                return QUEUE_SIZE-val*8/1024;
            }

            public String toLabelStringFromComponent(int val) {
                return ""+val+" kB";
            }

            public String toLabelStringFromReg(int val) {
                return ""+(QUEUE_SIZE-val*8/1024) +" kB";
            }

        });

        oqPktSizeSliderCtrl = new RegSliderGroupControl(nf2, this.oqPktSizeSlider,
                this.oqPktSizeValueLabel,
                NFDeviceConsts.OQ_QUEUE_0_MAX_PKTS_IN_Q_REG+index*512);
        oqPktSizeSliderCtrl.setVt(new ValueTransformer(){

            public int toRegisterValue(int val) {
                if(val >= MAX_NUM_PKTS_SIZE) {
                    return MAX_NUM_PKTS;
                } else {
                    return (int)Math.round(Math.pow(2, val));
                }
            }

            public int toSliderValue(int val) {
                if(val == 0) {
                    return 0;
                } else if(val>=MAX_NUM_PKTS || val < 0){
                    return MAX_NUM_PKTS_SIZE;
                } else {
                    return (int)Math.round(Math.log(val)/Math.log(2));
                }
            }

            public String toLabelStringFromComponent(int val) {
                if(val>=MAX_NUM_PKTS_SIZE){
                    return "no limit";
                } else {
                    return ""+Math.round(Math.pow(2,val));
                }
            }

            public String toLabelStringFromReg(int val) {
                if (val >= MAX_NUM_PKTS) {
                    return "no limit";
                } else {
                    return ""+val;
                }
            }

        });

        AbstractButton[] buttons = new AbstractButton[2];
        boolean[] invert = {false, false};
        buttons[NFDeviceConsts.OQ_ENABLE_SEND_BIT_NUM] = this.oqEnableCheckbox;
        buttons[NFDeviceConsts.OQ_INITIALIZE_OQ_BIT_NUM] = this.resetOQButton;
        ctrlRegGrp = new ControlRegGroup(nf2, NFDeviceConsts.OQ_QUEUE_0_CTRL_REG+index*512,
                                          buttons, invert);

        /* add listeners to the update the tables */
        timerActionListener = new ActionListener() {
            public void actionPerformed(ActionEvent e) {
                statsRegTableModel.updateTable();
                oqPktSizeSliderCtrl.updateFromRegs();
                oqByteSizeSliderCtrl.updateFromRegs();
                ctrlRegGrp.updateFromRegs();
            }
        };

        /* add action listener to the timer */
        timer.addActionListener(timerActionListener);

    }

    private void setupStatsTable(NFDevice nf2, int index) {
        /* add the addresses to monitor through statsRegTableModel */
        long[] aAddresses = new long[STATS_NUM_REGS_USED];
        index = index* 512;
        aAddresses[0] = NFDeviceConsts.OQ_QUEUE_0_NUM_PKTS_STORED_REG + index;
        aAddresses[1] = NFDeviceConsts.OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG + index;
        aAddresses[2] = NFDeviceConsts.OQ_QUEUE_0_NUM_PKTS_REMOVED_REG + index;
        aAddresses[3] = NFDeviceConsts.OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG + index;
        aAddresses[4] = NFDeviceConsts.OQ_QUEUE_0_NUM_PKTS_DROPPED_REG + index;
        aAddresses[5] = NFDeviceConsts.OQ_QUEUE_0_NUM_PKTS_IN_Q_REG + index;
        aAddresses[6] = NFDeviceConsts.OQ_QUEUE_0_NUM_WORDS_IN_Q_REG + index;

        /* setup any combinations */
        long[] bAddresses = new long[STATS_NUM_REGS_USED];
        int[] aCoef = new int[STATS_NUM_REGS_USED];
        int[] bCoef = new int[STATS_NUM_REGS_USED];

        /* we only want one combination */
        for(int i=0; i<bAddresses.length; i++){
            bAddresses[i] = Long.MAX_VALUE;
            aCoef[i] = 1;
            bCoef[i] = 0;
        }

        String[] descriptions = new String[STATS_NUM_REGS_USED];
        descriptions[0] = "Total packets received";
        descriptions[1] = "Total bytes received";
        descriptions[2] = "Total packets sent";
        descriptions[3] = "Total bytes sent";
        descriptions[4] = "Total packets dropped";
        descriptions[5] = "Current queue occupancy in pkts";
        descriptions[6] = "Current queue occupancy in bytes";

        /* create the register table model which we want to monitor */
        statsRegTableModel = new StatsRegTableModel(nf2, aAddresses, bAddresses, aCoef, bCoef, descriptions);

        statsRegTableModel.setDivider(1, 1024);
        statsRegTableModel.setUnits(1, "kB");

        statsRegTableModel.setDivider(3, 1024);
        statsRegTableModel.setUnits(3, "kB");

        statsRegTableModel.setGraph(4, (GraphPanel)this.pktDroppedPanel);
        statsRegTableModel.setDifferentialGraph(4, true);

        statsRegTableModel.setGraph(5, (GraphPanel)this.pktQOccupancyPanel);
        statsRegTableModel.setDifferentialGraph(5, false);

        statsRegTableModel.setGraph(6, (GraphPanel)this.byteQOccupancyPanel);
        statsRegTableModel.setDifferentialGraph(6, false);
        statsRegTableModel.setDivider(6, 1024/8);
        statsRegTableModel.setUnits(6, "kB");
    }

    public void clearTimer(){
        this.timer.removeActionListener(timerActionListener);
    }

    /** This method is called from within the constructor to
     * initialize the form.
     * WARNING: Do NOT modify this code. The content of this method is
     * always regenerated by the Form Editor.
     */
    // <editor-fold defaultstate="collapsed" desc=" Generated Code ">//GEN-BEGIN:initComponents
    private void initComponents() {
        maxQByteSizeLabel = new javax.swing.JLabel();
        resetOQButton = new ControlButton();
        oqPktSizeValueLabel = new javax.swing.JLabel();
        oqEnableCheckbox = new ControlCheckBox();
        maxQPktSizeLabel = new javax.swing.JLabel();
        oqByteSizeValueLabel = new javax.swing.JLabel();
        minOQByteSizeLabel = new javax.swing.JLabel();
        minOQPktSizeLabel = new javax.swing.JLabel();
        oqByteSizeSlider = new javax.swing.JSlider();
        oqPktSizeSlider = new javax.swing.JSlider();
        maxOQByteSizeLabel = new javax.swing.JLabel();
        pktQOccupancyPanel = new AreaGraphPanel("Queue Occupancy (pkts)", "Num Packets in Queue", "time", "Queue Occupancy", 2000);
        byteQOccupancyPanel = new AreaGraphPanel("Queue Occupancy (bytes)", "Bytes used", "time", "Queue Occupancy (kB)", 2000);
        pktDroppedPanel = new BarGraphPanel("Packet Drops due to Full Queue", "Packets dropped", "time", "Number of dropped packets", 2000);
        maxOQPktSizeLabel = new javax.swing.JLabel();
        statsTableScrollPane = new javax.swing.JScrollPane();
        statsRegTable = new StatsRegTable();

        setMinimumSize(new java.awt.Dimension(20, 20));
        maxQByteSizeLabel.setText("Output queue size in bytes :");

        resetOQButton.setText("Reset Queue");

        oqPktSizeValueLabel.setLabelFor(oqPktSizeSlider);
        oqPktSizeValueLabel.setText("no limit");

        oqEnableCheckbox.setText("Enable");
        oqEnableCheckbox.setToolTipText("Uncheck to disable servicing this output queue");
        oqEnableCheckbox.setBorder(javax.swing.BorderFactory.createEmptyBorder(0, 0, 0, 0));
        oqEnableCheckbox.setMargin(new java.awt.Insets(0, 0, 0, 0));
        oqEnableCheckbox.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                oqEnableCheckboxActionPerformed(evt);
            }
        });

        maxQPktSizeLabel.setText("Output queue size in packets :");

        oqByteSizeValueLabel.setLabelFor(oqByteSizeSlider);
        oqByteSizeValueLabel.setText("512 kB");

        minOQByteSizeLabel.setText("0");

        minOQPktSizeLabel.setText("1");

        oqByteSizeSlider.setMaximum(512);
        oqByteSizeSlider.setToolTipText("Slide to change output queue size");
        oqByteSizeSlider.setValue(512);
        oqByteSizeSlider.setMinimumSize(new java.awt.Dimension(0, 16));

        oqPktSizeSlider.setMaximum(MAX_NUM_PKTS_SIZE);
        oqPktSizeSlider.setToolTipText("Slide to change maximum number of packets that can be waiting in an output queue. Use keyboard arrows for fine adjustments.");
        oqPktSizeSlider.setValue(MAX_NUM_PKTS_SIZE);
        oqPktSizeSlider.setMinimumSize(new java.awt.Dimension(0, 16));

        maxOQByteSizeLabel.setText("512 kB");

        pktQOccupancyPanel.setMinimumSize(new java.awt.Dimension(100, 100));
        pktQOccupancyPanel.setPreferredSize(new java.awt.Dimension(200, 200));
        org.jdesktop.layout.GroupLayout pktQOccupancyPanelLayout = new org.jdesktop.layout.GroupLayout(pktQOccupancyPanel);
        pktQOccupancyPanel.setLayout(pktQOccupancyPanelLayout);
        pktQOccupancyPanelLayout.setHorizontalGroup(
            pktQOccupancyPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 520, Short.MAX_VALUE)
        );
        pktQOccupancyPanelLayout.setVerticalGroup(
            pktQOccupancyPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 182, Short.MAX_VALUE)
        );

        byteQOccupancyPanel.setPreferredSize(new java.awt.Dimension(200, 200));
        org.jdesktop.layout.GroupLayout byteQOccupancyPanelLayout = new org.jdesktop.layout.GroupLayout(byteQOccupancyPanel);
        byteQOccupancyPanel.setLayout(byteQOccupancyPanelLayout);
        byteQOccupancyPanelLayout.setHorizontalGroup(
            byteQOccupancyPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 250, Short.MAX_VALUE)
        );
        byteQOccupancyPanelLayout.setVerticalGroup(
            byteQOccupancyPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 181, Short.MAX_VALUE)
        );

        pktDroppedPanel.setPreferredSize(new java.awt.Dimension(200, 200));
        org.jdesktop.layout.GroupLayout pktDroppedPanelLayout = new org.jdesktop.layout.GroupLayout(pktDroppedPanel);
        pktDroppedPanel.setLayout(pktDroppedPanelLayout);
        pktDroppedPanelLayout.setHorizontalGroup(
            pktDroppedPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 250, Short.MAX_VALUE)
        );
        pktDroppedPanelLayout.setVerticalGroup(
            pktDroppedPanelLayout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(0, 181, Short.MAX_VALUE)
        );

        maxOQPktSizeLabel.setText("no limit");

        statsTableScrollPane.setBorder(javax.swing.BorderFactory.createBevelBorder(javax.swing.border.BevelBorder.RAISED));
        statsRegTable.setBackground(javax.swing.UIManager.getDefaults().getColor("Label.background"));
        statsRegTable.setFont(new java.awt.Font("Dialog", 1, 12));
        statsRegTable.setModel(new javax.swing.table.DefaultTableModel(
            new Object [][] {
                {null, null},
                {null, null},
                {null, null},
                {null, null},
                {null, null},
                {null, null}
            },
            new String [] {
                "", ""
            }
        ) {
            boolean[] canEdit = new boolean [] {
                false, false
            };

            public boolean isCellEditable(int rowIndex, int columnIndex) {
                return canEdit [columnIndex];
            }
        });
        statsRegTable.setGridColor(javax.swing.UIManager.getDefaults().getColor("Label.background"));
        statsRegTable.setRowSelectionAllowed(false);
        statsRegTable.setShowHorizontalLines(false);
        statsRegTable.setShowVerticalLines(false);
        statsTableScrollPane.setViewportView(statsRegTable);

        org.jdesktop.layout.GroupLayout layout = new org.jdesktop.layout.GroupLayout(this);
        this.setLayout(layout);
        layout.setHorizontalGroup(
            layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(layout.createSequentialGroup()
                .add(12, 12, 12)
                .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout.TRAILING)
                    .add(org.jdesktop.layout.GroupLayout.LEADING, pktQOccupancyPanel, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 520, Short.MAX_VALUE)
                    .add(org.jdesktop.layout.GroupLayout.LEADING, oqEnableCheckbox)
                    .add(org.jdesktop.layout.GroupLayout.LEADING, layout.createSequentialGroup()
                        .add(byteQOccupancyPanel, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 250, Short.MAX_VALUE)
                        .add(20, 20, 20)
                        .add(pktDroppedPanel, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 250, Short.MAX_VALUE))
                    .add(org.jdesktop.layout.GroupLayout.LEADING, layout.createSequentialGroup()
                        .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout.TRAILING, false)
                            .add(org.jdesktop.layout.GroupLayout.LEADING, layout.createSequentialGroup()
                                .add(maxQPktSizeLabel)
                                .add(10, 10, 10)
                                .add(oqPktSizeValueLabel, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                            .add(org.jdesktop.layout.GroupLayout.LEADING, layout.createSequentialGroup()
                                .add(maxQByteSizeLabel)
                                .add(24, 24, 24)
                                .add(oqByteSizeValueLabel, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE, 54, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE)))
                        .add(16, 16, 16)
                        .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
                            .add(layout.createSequentialGroup()
                                .add(minOQByteSizeLabel)
                                .add(2, 2, 2)
                                .add(oqByteSizeSlider, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 180, Short.MAX_VALUE)
                                .add(10, 10, 10)
                                .add(maxOQByteSizeLabel)
                                .add(6, 6, 6))
                            .add(layout.createSequentialGroup()
                                .add(minOQPktSizeLabel)
                                .add(2, 2, 2)
                                .add(oqPktSizeSlider, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 180, Short.MAX_VALUE)
                                .add(10, 10, 10)
                                .add(maxOQPktSizeLabel)
                                .add(1, 1, 1)))))
                .add(14, 14, 14))
            .add(layout.createSequentialGroup()
                .addContainerGap()
                .add(resetOQButton)
                .addContainerGap(422, Short.MAX_VALUE))
            .add(layout.createSequentialGroup()
                .addContainerGap()
                .add(statsTableScrollPane, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 522, Short.MAX_VALUE)
                .addContainerGap())
        );
        layout.setVerticalGroup(
            layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
            .add(layout.createSequentialGroup()
                .add(20, 20, 20)
                .add(oqEnableCheckbox)
                .add(5, 5, 5)
                .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
                    .add(maxQPktSizeLabel)
                    .add(minOQPktSizeLabel)
                    .add(oqPktSizeSlider, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE)
                    .add(maxOQPktSizeLabel)
                    .add(oqPktSizeValueLabel))
                .addPreferredGap(org.jdesktop.layout.LayoutStyle.RELATED)
                .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
                    .add(maxQByteSizeLabel)
                    .add(minOQByteSizeLabel)
                    .add(oqByteSizeSlider, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE)
                    .add(maxOQByteSizeLabel)
                    .add(oqByteSizeValueLabel))
                .addPreferredGap(org.jdesktop.layout.LayoutStyle.RELATED)
                .add(resetOQButton)
                .addPreferredGap(org.jdesktop.layout.LayoutStyle.RELATED)
                .add(statsTableScrollPane, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE, 145, org.jdesktop.layout.GroupLayout.PREFERRED_SIZE)
                .add(24, 24, 24)
                .add(layout.createParallelGroup(org.jdesktop.layout.GroupLayout.LEADING)
                    .add(pktDroppedPanel, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 181, Short.MAX_VALUE)
                    .add(byteQOccupancyPanel, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 181, Short.MAX_VALUE))
                .add(10, 10, 10)
                .add(pktQOccupancyPanel, org.jdesktop.layout.GroupLayout.DEFAULT_SIZE, 182, Short.MAX_VALUE))
        );
    }// </editor-fold>//GEN-END:initComponents

    private void oqEnableCheckboxActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_oqEnableCheckboxActionPerformed
// TODO add your handling code here:
    }//GEN-LAST:event_oqEnableCheckboxActionPerformed


    // Variables declaration - do not modify//GEN-BEGIN:variables
    private javax.swing.JPanel byteQOccupancyPanel;
    private javax.swing.JLabel maxOQByteSizeLabel;
    private javax.swing.JLabel maxOQPktSizeLabel;
    private javax.swing.JLabel maxQByteSizeLabel;
    private javax.swing.JLabel maxQPktSizeLabel;
    private javax.swing.JLabel minOQByteSizeLabel;
    private javax.swing.JLabel minOQPktSizeLabel;
    private javax.swing.JSlider oqByteSizeSlider;
    private javax.swing.JLabel oqByteSizeValueLabel;
    private javax.swing.JCheckBox oqEnableCheckbox;
    private javax.swing.JSlider oqPktSizeSlider;
    private javax.swing.JLabel oqPktSizeValueLabel;
    private javax.swing.JPanel pktDroppedPanel;
    private javax.swing.JPanel pktQOccupancyPanel;
    private javax.swing.JButton resetOQButton;
    private javax.swing.JTable statsRegTable;
    private javax.swing.JScrollPane statsTableScrollPane;
    // End of variables declaration//GEN-END:variables

}
