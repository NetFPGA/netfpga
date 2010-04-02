package org.netfpga.router;
import javax.swing.JCheckBox;

@SuppressWarnings("serial")
public class ControlCheckBox extends JCheckBox implements ControlButtonIface{
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
