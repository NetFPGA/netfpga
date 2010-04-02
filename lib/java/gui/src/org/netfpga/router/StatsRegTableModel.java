package org.netfpga.router;
/**
 *
 */
import java.awt.event.*;

import javax.swing.JButton;
import javax.swing.event.TableModelEvent;
import javax.swing.event.TableModelListener;
import javax.swing.table.AbstractTableModel;

import org.netfpga.backend.NFDevice;
import org.netfpga.backend.RegTableModel;

/**
 * @author jnaous
 * Implements a table model that can display statistcs registers.
 * It handles updates to these registers as well as updating any given
 * graphs. It can update graphs with differential values or with totals.
 * It has two register table models that are linearly combined together.
 */
@SuppressWarnings("serial")
public class StatsRegTableModel extends AbstractTableModel
                                    implements TableModelListener,
                                    ActionListener{

    private static final int NUM_COLS  = 2;
    public static final int DESCR_COL = 0;
    public static final int VALUE_COL = 1;

    StatsRegGroup[] table;
    RegTableModel aRegTableModel;
    RegTableModel bRegTableModel;
    private int[] aCoef;
    private int[] bCoef;
    private JButton resetButton;

    /**
     * Instantiates a new StatsTable with linearly combined coefficients from registers.
     * The value that is stored in the table is aCoef*aVal+bCoef*bVal. If the addresses
     * specified are equal to Lon.MAX_VALUE then the value from that address will always
     * be 0 and this will not cause any additional accesses to the device.
     *
     * @param nf2 the device to read registers from
     * @param aAddresses the list of addresses from which aVal is read
     * @param bAddresses the list of addresses from which bVal is read
     * @param aCoef the coefficients of aVal
     * @param bCoef the coefficients of bVal
     * @param descriptions strings that describe what each value is
     */
    public StatsRegTableModel(NFDevice nf2, long[] aAddresses,
                                long[] bAddresses, int[] aCoef, int[] bCoef,
                                String[] descriptions){

        this.table = new StatsRegGroup[aAddresses.length];

        this.aCoef = new int[aCoef.length];
        this.bCoef = new int[bCoef.length];

        this.aRegTableModel = new RegTableModel(nf2, aAddresses);
        this.bRegTableModel = new RegTableModel(nf2, bAddresses);

        for(int i=0; i<aAddresses.length; i++){
            table[i] = new StatsRegGroup(descriptions[i]);
            this.aCoef[i] = aCoef[i];
            this.bCoef[i] = bCoef[i];
        }

        /* add listener to the registers */
        /* Add listener to changes in the register values */

        aRegTableModel.addTableModelListener(this);
        bRegTableModel.addTableModelListener(this);

        this.resetButton = new JButton("Reset Stats");
        this.resetButton.addActionListener(this);
    }

    /**
     * Constructor that does not do any linear combinations
     * @param nf2
     * @param addresses
     * @param descriptions
     */
    public StatsRegTableModel(NFDevice nf2, long[] addresses, String[] descriptions){

        this.table = new StatsRegGroup[addresses.length];

        this.aCoef = new int[addresses.length];
        this.bCoef = new int[addresses.length];

        long[] bAddresses = new long[addresses.length];

        for(int i=0; i<addresses.length; i++){
            table[i] = new StatsRegGroup(descriptions[i]);
            bAddresses[i] = Long.MAX_VALUE;
            this.aCoef[i] = 1;
            this.bCoef[i] = 0;
        }

        this.aRegTableModel = new RegTableModel(nf2, addresses);
        this.bRegTableModel = new RegTableModel(nf2, bAddresses);

        /* add listener to the registers */
        /* Add listener to changes in the register values */

        aRegTableModel.addTableModelListener(this);
        bRegTableModel.addTableModelListener(this);

        this.resetButton = new JButton("Reset Stats");
        this.resetButton.addActionListener(this);
    }

    /**
     * Constructor that does not do any linear combinations
     * @param nf2
     * @param addresses
     * @param descriptions
     */
    public StatsRegTableModel(NFDevice nf2, long[] addresses){

        this.table = new StatsRegGroup[addresses.length];

        this.aCoef = new int[addresses.length];
        this.bCoef = new int[addresses.length];

        long[] bAddresses = new long[addresses.length];

        for(int i=0; i<addresses.length; i++){
            table[i] = new StatsRegGroup();
            bAddresses[i] = Long.MAX_VALUE;
            this.aCoef[i] = 1;
            this.bCoef[i] = 0;
        }

        this.aRegTableModel = new RegTableModel(nf2, addresses);
        this.bRegTableModel = new RegTableModel(nf2, bAddresses);

        /* add listener to the registers */
        /* Add listener to changes in the register values */

        aRegTableModel.addTableModelListener(this);
        bRegTableModel.addTableModelListener(this);

        this.resetButton = new JButton("Reset Stats");
        this.resetButton.addActionListener(this);
    }

    /* (non-Javadoc)
     * @see javax.swing.event.TableModelListener#tableChanged(javax.swing.event.TableModelEvent)
     */
    public void tableChanged(TableModelEvent e) {
        int firstRow = e.getFirstRow();
        int lastRow = e.getLastRow();
        int aVal;
        int bVal;
        for(int i=firstRow; i<=lastRow; i++){
            if(i!=TableModelEvent.HEADER_ROW){
                aVal = aRegTableModel.getRegisterAt(i).getValue();
                aVal = aVal*aCoef[i];

                bVal = bRegTableModel.getRegisterAt(i).getValue();
                bVal = bVal*bCoef[i];

                table[i].update(aVal+bVal);
            }
        }
        fireTableRowsUpdated(firstRow, lastRow);
    }

    /* (non-Javadoc)
     * @see javax.swing.table.TableModel#getColumnCount()
     */
    public int getColumnCount() {
        return NUM_COLS;
    }

    /* (non-Javadoc)
     * @see javax.swing.table.TableModel#getRowCount()
     */
    public int getRowCount() {
        return table.length+1;
    }

    /* (non-Javadoc)
     * @see javax.swing.table.TableModel#getValueAt(int, int)
     */
    public Object getValueAt(int rowIndex, int columnIndex) {
        if(rowIndex<table.length){
            if(columnIndex==DESCR_COL){
                return table[rowIndex].getDescription();
            } else {
                return table[rowIndex].getValueString();
            }
        } else if(columnIndex==0){
            return resetButton;
        } else {
            return null;
        }
    }

    /* (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#setValueAt(java.lang.Object, int, int)
     */
    public void setValueAt(Object aValue,
            int rowIndex,
            int columnIndex){
/*        if(columnIndex==DESCR_COL){
            table[rowIndex].setDescription(aValue.toString());
        } else if(columnIndex==VALUE_COL) {
            table[rowIndex].setCurrentValue(Integer.parseInt(aValue.toString()));
        } */
    }

    /**
     * Updates the table values
     */
    public void updateTable(){
        this.aRegTableModel.updateTable();
        this.bRegTableModel.updateTable();
    }

    /**
     * @return the differentialGraph
     */
    public boolean isDifferentialGraph(int rowIndex) {
        return table[rowIndex].isDifferentialGraph();
    }

    /**
     * @param differentialGraph the differentialGraph to set
     */
    public void setDifferentialGraph(int rowIndex, boolean differentialGraph) {
        this.table[rowIndex].setDifferentialGraph(differentialGraph);
    }

    /**
     * @return the divider
     */
    public int getDivider(int rowIndex) {
        return table[rowIndex].getDivider();
    }

    /**
     * @param divider the divider to set
     */
    public void setDivider(int rowIndex, int divider) {
        table[rowIndex].setDivider(divider);
    }

    /**
     * @return the graph
     */
    public GraphPanel getGraph(int rowIndex) {
        return table[rowIndex].getGraph();
    }

    /**
     * @param graph the graph to set
     */
    public void setGraph(int rowIndex, GraphPanel graph) {
        table[rowIndex].setGraph(graph);
    }

    /**
     * @return the startTime
     */
    public long getStartTime(int rowIndex) {
        return table[rowIndex].getStartTime();
    }

    /**
     * @param startTime the startTime to set
     */
    public void setStartTime(int rowIndex, long startTime) {
        table[rowIndex].setStartTime(startTime);
    }

    /**
     * @return the units
     */
    public String getUnits(int rowIndex) {
        return table[rowIndex].getUnits();
    }

    /**
     * @param units the units to set
     */
    public void setUnits(int rowIndex, String units) {
        table[rowIndex].setUnits(units);
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#getColumnName(int)
     */
    public String getColumnName(int column){
        return null;
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#getColumnClass(int)
     */
//    public Class<?> getColumnClass(int column){
//        return JButton.class;
//    }

    public boolean isCellEditable(int row, int column){
        if(row<table.length){
            return false;
        } else if(column==0){
            return true;
        } else {
            return false;
        }
    }

    /**
     * Clears the registers and graphs
     */
    public void actionPerformed(ActionEvent e) {
        for(int i=0; i<table.length; i++){
            table[i].reset();
            aRegTableModel.setValueAt(new Integer(0), i, RegTableModel.VALUE_COL);
            bRegTableModel.setValueAt(new Integer(0), i, RegTableModel.VALUE_COL);
        }
    }

    /**
     * Clears the registers and graphs
     */
    public void clearAll() {
        this.actionPerformed(null);
    }
}
