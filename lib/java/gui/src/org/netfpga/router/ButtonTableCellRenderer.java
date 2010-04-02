package org.netfpga.router;
/**
 *
 */
import java.awt.Component;

import javax.swing.JButton;
import javax.swing.JTable;
import javax.swing.table.TableCellRenderer;

/**
 * @author jnaous
 *
 */
@SuppressWarnings("serial")
public class ButtonTableCellRenderer extends JButton implements
        TableCellRenderer {

    /* (non-Javadoc)
     * @see javax.swing.table.TableCellRenderer#getTableCellRendererComponent(javax.swing.JTable, java.lang.Object, boolean, boolean, int, int)
     */
    public Component getTableCellRendererComponent(JTable table, Object value,
            boolean isSelected, boolean hasFocus, int row, int column) {
        this.setSelected(isSelected);
        return this;
    }

}
