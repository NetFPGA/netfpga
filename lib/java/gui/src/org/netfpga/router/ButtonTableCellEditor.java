package org.netfpga.router;
/**
 *
 */
import java.awt.Component;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

import javax.swing.AbstractCellEditor;
import javax.swing.JButton;
import javax.swing.JTable;
import javax.swing.table.TableCellEditor;

/**
 * @author jnaous
 * Implements a class that allows a cell to be edited by a button
 */
@SuppressWarnings("serial")
public class ButtonTableCellEditor extends AbstractCellEditor implements
        TableCellEditor, ActionListener {

    JButton button;

    protected static final String EDIT = "edit";

    /* (non-Javadoc)
     * @see javax.swing.table.TableCellEditor#getTableCellEditorComponent(javax.swing.JTable, java.lang.Object, boolean, int, int)
     */
    public Component getTableCellEditorComponent(JTable table, Object value,
            boolean isSelected, int row, int column) {
        this.button = new JButton();
        this.button.setActionCommand(EDIT);
        this.button.addActionListener(this);
        this.button.setBorderPainted(false);

        return button;
    }

    /* (non-Javadoc)
     * @see javax.swing.CellEditor#getCellEditorValue()
     */
    public Object getCellEditorValue() {
        return "";
    }

    /* (non-Javadoc)
     * @see java.awt.event.ActionListener#actionPerformed(java.awt.event.ActionEvent)
     */
    public void actionPerformed(ActionEvent e) {
        if (EDIT.equals(e.getActionCommand())) {
            //The user has clicked the cell
            fireEditingStopped(); //Make the renderer reappear.
        }
    }

}
