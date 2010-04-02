package org.netfpga.router;
/*
 * RouterMainFrame.java
 *
 * Created on June 4, 2007, 7:52 AM
 *
 */

import jargs.gnu.CmdLineParser;

import javax.swing.JInternalFrame;

import org.netfpga.eventcap.EventCaptureMainFrame;

/**
 * Implements the router main frame
 * @author jnaous
 */
@SuppressWarnings("serial")
public class RouterMainFrame extends AbstractMainFrame {

    public static String DEFAULT_BIN = "router.bit";

    /**
     * @param args the command line arguments
     */
    public static void main(final String args[]) {

        /* parse args, download bin file, start sr */
        AbstractMainFrame.runEnv(args, DEFAULT_BIN);

        java.awt.EventQueue.invokeLater(new Runnable() {
            public void run() {

                new RouterMainFrame().setVisible(true);

                System.out.println("Started...");
            }
        });
    }

    /* (non-Javadoc)
     * @see router.AbstractMainFrame#getNewQuickStartFrame()
     */
    protected JInternalFrame getNewQuickStartFrame() {
        return new RouterQuickstartFrame(nf2, updateTimer, this);
    }

}

