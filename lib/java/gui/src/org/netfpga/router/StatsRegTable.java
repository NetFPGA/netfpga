package org.netfpga.router;
/**
 *
 */
import javax.swing.JComponent;
import javax.swing.JLabel;
import javax.swing.table.DefaultTableCellRenderer;
import javax.swing.table.TableModel;

/**
 * This class extends JTable to create a table which is invisible
 * @author jnaous
 *
 */
@SuppressWarnings("serial")
public class StatsRegTable extends JComponentTable {

    private static final int BUTTON_HEIGHT = 25;
    public StatsRegTable(){
    }

    public void setModel(TableModel dataModel){
        super.setModel(dataModel);
        this.setRowHeight(this.getRowCount()-1, BUTTON_HEIGHT);
        this.setBackground(javax.swing.UIManager.getDefaults().getColor("Label.background"));
        this.setFont(new java.awt.Font("Dialog", 1, 12));
        this.setGridColor(javax.swing.UIManager.getDefaults().getColor("Label.background"));
        this.setRowSelectionAllowed(false);
        this.setShowHorizontalLines(false);
        this.setShowVerticalLines(false);
    }

    public void setDefaults(){
        this.setRowHeight(this.getRowCount()-1, BUTTON_HEIGHT);
        this.setBackground(javax.swing.UIManager.getDefaults().getColor("Label.background"));
        this.setFont(new java.awt.Font("Dialog", 1, 12));
        this.setGridColor(javax.swing.UIManager.getDefaults().getColor("Label.background"));
        this.setRowSelectionAllowed(false);
        this.setShowHorizontalLines(false);
        this.setShowVerticalLines(false);
        this.setDefaultRenderer( JComponent.class, new JComponentCellRenderer() );
        this.setDefaultEditor( JComponent.class, new JComponentCellEditor() );
        /* Set right aligned */
        DefaultTableCellRenderer  tcrColumn  =  new DefaultTableCellRenderer();
        tcrColumn.setHorizontalAlignment(JLabel.RIGHT);
        this.getColumnModel().getColumn(StatsRegTableModel.VALUE_COL).setCellRenderer(tcrColumn);
        AutofitTableColumns.autoResizeTable(this, false, 0);
    }

}
