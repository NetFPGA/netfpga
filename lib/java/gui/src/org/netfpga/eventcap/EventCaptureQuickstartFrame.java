package org.netfpga.eventcap;
/**
 *
 */
import javax.swing.JPanel;
import javax.swing.Timer;

import org.netfpga.backend.NFDevice;

import org.netfpga.router.AbstractRouterQuickstartFrame;

/**
 * @author jnaous
 *
 */
@SuppressWarnings("serial")
public class EventCaptureQuickstartFrame extends AbstractRouterQuickstartFrame {

    public EventCaptureQuickstartFrame(NFDevice nf2, Timer updateTimer, EventCaptureMainFrame mainFrame) {
        super(nf2, updateTimer, mainFrame);
    }

    /* (non-Javadoc)
     * @see router.AbstractRouterQuickstartFrame#getDetailsPanel()
     */
    @Override
    protected JPanel getDetailsPanel() {
        return new EventCaptureDetailsPanel(nf2, updateTimer, mainFrame);
    }

}
