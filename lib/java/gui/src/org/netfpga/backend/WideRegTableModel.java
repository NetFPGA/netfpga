/**
 *
 */
package org.netfpga.backend;

import javax.swing.event.TableModelEvent;
import javax.swing.table.AbstractTableModel;

/**
 * @author jnaous
 * Implements a wide register table such as the routing table
 * The first column contains the index of the entry.
 */
@SuppressWarnings("serial")
public class WideRegTableModel extends AbstractTableModel {

    public static final int MODIFIED_COL = 1;
    public static final int INDEX_COL = 0;
    public static final int VALUES_START_COL = 2;
    private int[][] table;
    private long[] colAddresses;
    private long wrAddress;
    private long rdAddress;
    private String[] columnNames;
    private NFDevice nf2;

    /**
     * Constructs a new instance of WideRegTableModel
     * @param nf2 the device to bind to
     * @param colAddresses the register addresses of the columns of the table
     * @param wrAddress the address of the register in which the index to write to is written
     * @param rdAddress the address of the register in which the index to read from is written
     * @param numRows number of entries in the table
     */
    public WideRegTableModel(NFDevice nf2, long[] colAddresses, long wrAddress, long rdAddress, int numRows){

        table = new int[numRows][colAddresses.length+2];
        this.colAddresses = new long[colAddresses.length];
        for(int i=0; i<colAddresses.length; i++){
            this.colAddresses[i] = colAddresses[i];
        }
        this.wrAddress = wrAddress;
        this.rdAddress = rdAddress;

        for(int i=0; i<numRows; i=i+1){
            table[i][MODIFIED_COL] = 0; //modified flag: 0 is false
            table[i][INDEX_COL] = i;
        }

        this.nf2 = nf2;

        updateTable();
    }
    /* (non-Javadoc)
     * @see javax.swing.table.TableModel#getColumnCount()
     */
    public int getColumnCount() {
        return table[0].length;
    }

    /* (non-Javadoc)
     * @see javax.swing.table.TableModel#getRowCount()
     */
    public int getRowCount() {
        return table.length;
    }

    /* (non-Javadoc)
     * @see javax.swing.table.TableModel#getValueAt(int, int)
     */
    public Object getValueAt(int rowIndex, int columnIndex) {
        if(columnIndex==MODIFIED_COL){
            return new Boolean(table[rowIndex][columnIndex]==1);
        } else {
            return new Integer(table[rowIndex][columnIndex]);
        }
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#getColumnClass(int)
     */
    public Class<?> getColumnClass(int columnIndex) {
        if(columnIndex==MODIFIED_COL){
            return Boolean.class;
        } else {
            return Integer.class;
        }
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#isCellEditable(int, int)
     */
    public boolean isCellEditable(int rowIndex, int columnIndex){
        if(columnIndex==MODIFIED_COL || columnIndex==INDEX_COL){
            return false;
        } else {
            return true;
        }
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#getColumnName(int)
     */
    public String getColumnName(int column) {
        if(columnNames!=null){
            return columnNames[column];
        } else {
            return super.getColumnName(column);
        }
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#setValueAt(java.lang.Object, int, int)
     */
    public void setValueAt(Object aValue, int rowIndex, int columnIndex){
        /* set the modified flag */
        table[rowIndex][MODIFIED_COL] = 1;

        /* Now modify the entry */
        table[rowIndex][columnIndex] = ((Integer)aValue).intValue();

        fireTableRowsUpdated(rowIndex, rowIndex);
    }

    /**
     * Write the modified rows to the device
     * and reset their modified status
     */
    public void flushModifiedRows(){
        /* setup the arrays to access the device */
        int[] values = new int[colAddresses.length+1];
        long[] addresses = new long[colAddresses.length+1];
        int[] access_types = new int[colAddresses.length+1];

        /* store the table addresses and access types*/
        for(int i=0; i<colAddresses.length; i++) {
            addresses[i] = colAddresses[i];
            access_types[i] = NFDevice.WRITE_ACCESS;
        }
        addresses[addresses.length-1] = wrAddress;
        access_types[access_types.length-1] = NFDevice.WRITE_ACCESS;

        /* For each modified row, write the row to the hardware */
        for(int i=0; i<this.getRowCount(); i++){
            if(table[i][MODIFIED_COL]!=0){
                /* get the row's cell values */
                for(int j=0; j<colAddresses.length; j++){
                    values[j] = table[i][j+VALUES_START_COL];
                }
                /* add the write address */
                values[values.length-1] = i;

                /* write the full row */
                nf2.accessRegArray(addresses, values, access_types, values.length);

                /* clear the modified flag */
                table[i][MODIFIED_COL] = 0;

            }
        }
    }

    /**
     * Reads a full row back from the device and signals a change
     * This only happens if the row is not modified.
     * @param rowIndex
     */
    public void updateRow(int rowIndex){
        if(table[rowIndex][MODIFIED_COL]==0){
            /* setup the arrays to access the device */
            int[] values = new int[colAddresses.length+1];
            long[] addresses = new long[colAddresses.length+1];
            int[] access_types = new int[colAddresses.length+1];

            /* add the read address */
            values[0] = rowIndex;
            addresses[0] = rdAddress;
            access_types[0] = NFDevice.WRITE_ACCESS;

            /* store the table addresses */
            for(int i=1; i<=colAddresses.length; i++) {
                addresses[i] = colAddresses[i-1];
                access_types[i] = NFDevice.READ_ACCESS;
            }

            /* read the full row */
            nf2.accessRegArray(addresses, values, access_types, values.length);

            /* set the values */
            for(int i=0; i<colAddresses.length; i++){
                table[rowIndex][i+VALUES_START_COL] = values[i+1];
            }

            fireTableRowsUpdated(rowIndex, rowIndex);
        }
    }

    /**
     * Updates the full table row-by-row. Modified rows are skipped.
     *
     */
    public void updateTable(){
        for(int i=0; i<table.length; i++){
            updateRow(i);
        }
    }

    /**
     * @param columnNames the columnNames to set
     */
    @SuppressWarnings("unused")
    private void setColumnNames(String[] columnNames) {
        this.columnNames = columnNames;
        fireTableRowsUpdated(TableModelEvent.HEADER_ROW, TableModelEvent.HEADER_ROW);
    }

    /**
     * @return the columnNames
     */
    @SuppressWarnings("unused")
    private String[] getColumnNames() {
        return columnNames;
    }
}
