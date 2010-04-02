package org.netfpga.router;
/*
 * OutputQueues.java
 *
 * Created on May 7, 2007, 10:04 PM
 */

import java.awt.Container;

import javax.swing.Timer;

import org.netfpga.backend.NFDevice;

/**
 *
 * @author  jnaous
 */
@SuppressWarnings("serial")
public class OutputQueues extends javax.swing.JInternalFrame {

    private Timer timer;
    private NFDevice nf2;

    /** Creates new form OutputQueues */
    public OutputQueues(NFDevice nf2, Timer timer) {
        this.nf2 = nf2;
        this.timer = timer;
        myInitComponents();

    }

    /** This method is called from within the constructor to
     * initialize the form.
     */
    private void myInitComponents() {
        oqTabbedPane = new javax.swing.JTabbedPane();
        OQ0ScrollPane = new javax.swing.JScrollPane();
        oqPanel0 = new OQPanel(nf2, timer, 0);
        OQ1ScrollPane = new javax.swing.JScrollPane();
        oqPanel1 = new OQPanel(nf2, timer, 1);
        OQ2ScrollPane = new javax.swing.JScrollPane();
        oqPanel2 = new OQPanel(nf2, timer, 2);
        OQ3ScrollPane = new javax.swing.JScrollPane();
        oqPanel3 = new OQPanel(nf2, timer, 3);
        OQ4ScrollPane = new javax.swing.JScrollPane();
        oqPanel4 = new OQPanel(nf2, timer, 4);
        OQ5ScrollPane = new javax.swing.JScrollPane();
        oqPanel5 = new OQPanel(nf2, timer, 5);
        OQ6ScrollPane = new javax.swing.JScrollPane();
        oqPanel6 = new OQPanel(nf2, timer, 6);
        OQ7ScrollPane = new javax.swing.JScrollPane();
        oqPanel7 = new OQPanel(nf2, timer, 7);

        setClosable(true);
        setIconifiable(true);
        setMaximizable(true);
        setResizable(true);
        setTitle("Output Queues");
        setVisible(true);
        addInternalFrameListener(new javax.swing.event.InternalFrameListener() {
            public void internalFrameActivated(javax.swing.event.InternalFrameEvent evt) {
            }
            public void internalFrameClosed(javax.swing.event.InternalFrameEvent evt) {
                formInternalFrameClosed(evt);
            }
            public void internalFrameClosing(javax.swing.event.InternalFrameEvent evt) {
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

        OQ0ScrollPane.setViewportView(oqPanel0);

        oqTabbedPane.addTab("Output Queue 0", OQ0ScrollPane);

        OQ1ScrollPane.setViewportView(oqPanel1);

        oqTabbedPane.addTab("Output Queue 1", OQ1ScrollPane);

        OQ2ScrollPane.setViewportView(oqPanel2);

        oqTabbedPane.addTab("Output Queue 2", OQ2ScrollPane);

        OQ3ScrollPane.setViewportView(oqPanel3);

        oqTabbedPane.addTab("Output Queue 3", OQ3ScrollPane);

        OQ4ScrollPane.setViewportView(oqPanel4);

        oqTabbedPane.addTab("Output Queue 4", OQ4ScrollPane);

        OQ5ScrollPane.setViewportView(oqPanel5);

        oqTabbedPane.addTab("Output Queue 5", OQ5ScrollPane);

        OQ6ScrollPane.setViewportView(oqPanel6);

        oqTabbedPane.addTab("Output Queue 6", OQ6ScrollPane);

        OQ7ScrollPane.setViewportView(oqPanel7);

        oqTabbedPane.addTab("Output Queue 7", OQ7ScrollPane);

        Container c = getContentPane();
        c.add(oqTabbedPane);
        setContentPane(c);

        pack();
    }

    private void formInternalFrameClosed(javax.swing.event.InternalFrameEvent evt) {//GEN-FIRST:event_formInternalFrameClosed
        ((OQPanel)oqPanel0).clearTimer();
        ((OQPanel)oqPanel1).clearTimer();
        ((OQPanel)oqPanel2).clearTimer();
        ((OQPanel)oqPanel3).clearTimer();
        ((OQPanel)oqPanel4).clearTimer();
        ((OQPanel)oqPanel5).clearTimer();
        ((OQPanel)oqPanel6).clearTimer();
        ((OQPanel)oqPanel7).clearTimer();
    }//GEN-LAST:event_formInternalFrameClosed


    // Variables declaration - do not modify//GEN-BEGIN:variables
    private javax.swing.JScrollPane OQ0ScrollPane;
    private javax.swing.JScrollPane OQ1ScrollPane;
    private javax.swing.JScrollPane OQ2ScrollPane;
    private javax.swing.JScrollPane OQ3ScrollPane;
    private javax.swing.JScrollPane OQ4ScrollPane;
    private javax.swing.JScrollPane OQ5ScrollPane;
    private javax.swing.JScrollPane OQ6ScrollPane;
    private javax.swing.JScrollPane OQ7ScrollPane;
    private javax.swing.JPanel oqPanel0;
    private javax.swing.JPanel oqPanel1;
    private javax.swing.JPanel oqPanel2;
    private javax.swing.JPanel oqPanel3;
    private javax.swing.JPanel oqPanel4;
    private javax.swing.JPanel oqPanel5;
    private javax.swing.JPanel oqPanel6;
    private javax.swing.JPanel oqPanel7;
    private javax.swing.JTabbedPane oqTabbedPane;
    // End of variables declaration//GEN-END:variables

}
