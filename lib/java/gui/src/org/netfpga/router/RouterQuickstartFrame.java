package org.netfpga.router;
import javax.swing.JPanel;
import javax.swing.Timer;

import org.netfpga.backend.NFDevice;

@SuppressWarnings("serial")
public class RouterQuickstartFrame extends AbstractRouterQuickstartFrame {

    /**
     * Create a new instance of quickstart frame
     */
    public RouterQuickstartFrame(NFDevice nf2, Timer updateTimer, AbstractMainFrame mainFrame) {
        super(nf2, updateTimer, mainFrame);
    }

    /*
     * (non-Javadoc)
     * @see router.AbstractRouterQuickstartFrame#getDetailsPanel()
     */
    @Override
    protected JPanel getDetailsPanel() {
        return new RouterDetailsPanel(this.nf2, this.updateTimer, this.mainFrame);
    }

}
