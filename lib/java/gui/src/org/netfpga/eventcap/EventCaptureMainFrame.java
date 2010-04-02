package org.netfpga.eventcap;
/**
 *
 */
import javax.swing.JInternalFrame;

import org.netfpga.router.AbstractMainFrame;

/**
 * Implements event capture main frame
 * @author jnaous
 *
 */
@SuppressWarnings("serial")
public class EventCaptureMainFrame extends AbstractMainFrame {

    public static String DEFAULT_BIN = "adv_router.bit";

    /* (non-Javadoc)
     * @see router.AbstractMainFrame#getNewQuickStartFrame()
     */
    @Override
    protected JInternalFrame getNewQuickStartFrame() {
        return new EventCaptureQuickstartFrame(this.nf2, this.updateTimer, this);
    }

    /**
     * @param args the command line arguments
     */
    public static void main(final String args[]) {

        /* parse args, download bin file, start sr */
        AbstractMainFrame.runEnv(args, DEFAULT_BIN);

        java.awt.EventQueue.invokeLater(new Runnable() {
            public void run() {

                new EventCaptureMainFrame().setVisible(true);

                System.out.println("Started...");
            }
        });
    }

}
