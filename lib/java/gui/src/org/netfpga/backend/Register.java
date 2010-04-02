/**
 *
 */
package org.netfpga.backend;

/**
 * @author jnaous
 *
 */
public class Register {

    private long address;
    private int value;
    private boolean isEditable = false;
    private int index;

    /**
     * Constructs a new instance of a register
     * @param addr the address where the register is located
     * @param value the value of the register
     * @param index the position of the register in its RegTableModel
     */
    public Register(long addr, int value, int index) {
        this.address = addr;
        this.value = value;
        this.index = index;
    }

    /**
     * @param address the address to set
     */
    public void setAddress(long address) {
        this.address = address;
    }

    /**
     * @return the address
     */
    public long getAddress() {
        return address;
    }

    /**
     * @param value the value to set
     */
    public void setValue(int value) {
        this.value = value;
    }

    /**
     * @return the value
     */
    public int getValue() {
        return value;
    }

    /**
     * @param isEditable the isEditable to set
     */
    public void setEditable(boolean isEditable) {
        this.isEditable = isEditable;
    }

    /**
     * @return the isEditable
     */
    public boolean isEditable() {
        return isEditable;
    }

    /**
     * @param index the index to set
     */
    public void setIndex(int index) {
        this.index = index;
    }

    /**
     * @return the index
     */
    public int getIndex() {
        return index;
    }

}
