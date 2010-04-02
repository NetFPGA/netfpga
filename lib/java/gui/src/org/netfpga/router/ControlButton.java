package org.netfpga.router;
/**
 *
 */
import javax.swing.JButton;

/**
 * @author jnaous
 *
 */
@SuppressWarnings("serial")
public class ControlButton extends JButton implements ControlButtonIface{
    private int index;

    /**
     * @return the index
     */
    public int getIndex() {
        return index;
    }

    /**
     * @param index the index to set
     */
    public void setIndex(int index) {
        this.index = index;
    }

}
