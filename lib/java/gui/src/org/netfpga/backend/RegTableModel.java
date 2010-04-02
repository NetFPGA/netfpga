/**
 *
 */
package org.netfpga.backend;

import java.util.HashMap;
import javax.swing.event.TableModelEvent;
import javax.swing.table.AbstractTableModel;

/**
 * @author jnaous
 * Implements a TableModel interface.
 * The first column is a long, and it contains the addresses. The second column
 * is an int and it has the values.
 */
@SuppressWarnings("serial")
public class RegTableModel extends AbstractTableModel{

    /**
     * Word alignment boundary
     */
    public static final int WORD_ALIGN = 4;

    public static final int VALUE_COL = 1;

    private HashMap<Long,Register> regHashMap;
    private Register[] regArray;
    private String[] columnNames;

    @SuppressWarnings("unused")
    private NFDevice nf2;

    /**
     * Constructs a new register table instance that handles addresses
     * between startAddr and endAddr. Note that addresses are aligned
     * to WORD_ALIGN bytes. i.e. consecutive regHashMap' addresses differ by WORD_ALIGN
     * @param nf2 the device to access
     * @param startAddr first of the list of addresses to handle
     * @param endAddr last address to handle
     */
    public RegTableModel(NFDevice nf2, long startAddr, long endAddr){
        this.nf2 = nf2;

        int numRegs = (int) ((endAddr-startAddr+1)/WORD_ALIGN);
        long addr = startAddr;

        regHashMap = new HashMap<Long, Register>();
        this.regArray = new Register[numRegs];

        for(int i=0; i<numRegs; i++){
            Register reg;
            if(addr != Long.MAX_VALUE){
                reg = new Register(addr, nf2.readReg(addr), i);
            } else {
                reg = new Register(addr, 0, i);
            }
            regHashMap.put(new Long(addr), reg);
            reg.setIndex(i);
            regArray[i] = reg;
            addr += WORD_ALIGN;
        }
    }

    /**
     * Constructs a new register table instance that handles all addresses
     * in the addresses parameter
     * @param nf2 the device to access
     * @param addresses the addresses to handle
     */
    public RegTableModel(NFDevice nf2, long[] addresses){
        this.nf2 = nf2;

        int numRegs = addresses.length;

        regHashMap = new HashMap<Long, Register>();
        this.regArray = new Register[numRegs];

        for(int i=0; i<numRegs; i++){
            Register reg;
            if(addresses[i]!=Long.MAX_VALUE){
                reg = new Register(addresses[i], nf2.readReg(addresses[i]), i);
            } else {
                reg = new Register(addresses[i], 0, i);
            }
            regHashMap.put(new Long(addresses[i]), reg);
            regArray[i] = reg;
        }
    }

    /* (non-Javadoc)
     * @see javax.swing.table.TableModel#getColumnCount()
     */
    public int getColumnCount() {
        return 2;
    }

    /* (non-Javadoc)
     * @see javax.swing.table.TableModel#getRowCount()
     */
    public int getRowCount() {
        return regHashMap.size();
    }

    /* (non-Javadoc)
     * @see javax.swing.table.TableModel#getValueAt(int, int)
     */
    public Object getValueAt(int rowIndex, int columnIndex) {
        if(columnIndex==0){
            return regArray[rowIndex].getAddress();
        }
        else {
            return regArray[rowIndex].getValue();
        }
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#getColumnClass(int)
     */
    public Class<?> getColumnClass(int columnIndex){
        if(columnIndex==0){
            return Long.class;
        }
        else {
            return Integer.class;
        }
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#isCellEditable(int, int)
     */
    public boolean isCellEditable(int rowIndex, int colIndex){
        if(colIndex == 0){
            return false;
        } else {
            return regArray[rowIndex].isEditable();
        }
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#setValueAt(java.lang.Object, int, int)
     */
    public void setValueAt(Object aValue, int rowIndex, int columnIndex){
        Register reg = regArray[rowIndex];
        if(columnIndex!=0) {
            writeRegisterAddress(reg.getAddress(), ((Integer)aValue).intValue());
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

    /**
     * Get the register at the given row index in the table
     * @param rowIndex
     * @return the register object at the row
     */
    public Register getRegisterAt(int rowIndex){
        return regArray[rowIndex];
    }

    /**
     * Sets the isCellEditable property for convenient table representation. This only
     * affects column index 1. The register address is not editable
     * @param rowIndex the index of the cell to set
     * @param colIndex the index of the column
     * @param isEditable
     */
    public void setCellEditable(int rowIndex, int colIndex, boolean isEditable){
        Long key = new Long(regArray[rowIndex].getAddress());
        if(colIndex == 0){
            return;
        } else {
            ((Register)regHashMap.get(key)).setEditable(isEditable);
        }
    }

    /**
     * Rereads the Register value from the device using a row index
     * @param rowIndex the row in the table where the register sits
     */
    public void updateRegisterRow(int rowIndex){
        long address = regArray[rowIndex].getAddress();
        if(address!=Long.MAX_VALUE){
            regArray[rowIndex].setValue(nf2.readReg(address));
            fireTableCellUpdated(rowIndex, 1);
        }
    }

    /**
     * Rereads the Register value from the device at the address given
     * @param address the register address
     */
    public void updateRegisterAddress(long address){
        Long key = new Long(address);
        Register reg = regHashMap.get(key);
        if(reg!=null && address!=Long.MAX_VALUE){
            reg.setValue(nf2.readReg(address));
            fireTableCellUpdated(reg.getIndex(), 1);
        }
    }

    /**
     * Updates all addresses in the table
     */
    public void updateTable(){
        for(int i=0; i<regArray.length; i++){
            updateRegisterRow(i);
        }
    }

    /**
     * Write a register in the device
     * @param address the address to write to
     * @param value the value to write
     */
    public void writeRegisterAddress(long address, int value){
        Long key = new Long(address);
        Register reg = regHashMap.get(key);
        if(reg!=null && address!=Long.MAX_VALUE){
            /* write the value to the device first */
            nf2.writeReg(address, value);
            /* then update it from the device */
            updateRegisterRow(reg.getIndex());
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
