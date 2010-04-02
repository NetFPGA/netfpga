package org.netfpga.router;
import javax.swing.event.TableModelEvent;
import javax.swing.event.TableModelListener;
import javax.swing.table.AbstractTableModel;

import org.netfpga.backend.NFDevice;
import org.netfpga.backend.NFDeviceConsts;
import org.netfpga.backend.RegTableModel;
import org.netfpga.backend.WideRegTableModel;

/**
 * This class implements a TableModel for the interface configuration table.
 * This sits on top of the RegTableModel monitoring the registers.
 * @author jnaous
 *
 */
@SuppressWarnings("serial")
public class InterfacePortConfigTableModel extends AbstractTableModel {

    private static final String[] COLUMN_NAMES = {"Port Number", "MAC Address", "IP Address"};
    public static final int INDEX_COL = 0;
    public static final int MAC_COL = 1;
    public static final int IP_COL = 2;
    public static final int NUM_IFACES = 4;

    /** table data */
    Object [][] table;

    /** table for MAC addresses */
    private RegTableModel macTableModel;
    /** table for IP destination filter */
    private WideRegTableModel ipTableModel;

    /**
     * Create a new ionstance of InterfacePortConfigTableModel
     * @param nf2
     */
    public InterfacePortConfigTableModel(NFDevice nf2){

        table = new Object[NUM_IFACES][COLUMN_NAMES.length];

        for(int i=0; i<NUM_IFACES; i++){
            table[i][INDEX_COL] = new Integer(i);
            table[i][MAC_COL] = new MACAddress();
            table[i][IP_COL] = new IPAddress();
        }

        /* port mac addresses */
        long[] addresses = {
                NFDeviceConsts.ROUTER_OP_LUT_MAC_0_HI_REG,
                NFDeviceConsts.ROUTER_OP_LUT_MAC_0_LO_REG,
                NFDeviceConsts.ROUTER_OP_LUT_MAC_1_HI_REG,
                NFDeviceConsts.ROUTER_OP_LUT_MAC_1_LO_REG,
                NFDeviceConsts.ROUTER_OP_LUT_MAC_2_HI_REG,
                NFDeviceConsts.ROUTER_OP_LUT_MAC_2_LO_REG,
                NFDeviceConsts.ROUTER_OP_LUT_MAC_3_HI_REG,
                NFDeviceConsts.ROUTER_OP_LUT_MAC_3_LO_REG
        };

        /* instantiate the mac table and add the listener */
        macTableModel = new RegTableModel(nf2, addresses);
        macTableModel.addTableModelListener(new TableModelListener() {
            public void tableChanged(TableModelEvent e) {
                updateMACAddresses();
                fireTableDataChanged();
            }
        });

        addresses = new long[1];
        addresses[0] = NFDeviceConsts.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_ENTRY_IP_REG;

        /* instantiate the ip table and add the listener */
        ipTableModel = new WideRegTableModel(nf2, addresses,
                                             NFDeviceConsts.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_WR_ADDR_REG,
                                             NFDeviceConsts.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_RD_ADDR_REG,
                                             NFDeviceConsts.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH);

        ipTableModel.addTableModelListener(new TableModelListener() {
            /**
             * Only handle events that are in the bottom of the table
             */
            public void tableChanged(TableModelEvent e) {
                if(e.getFirstRow()>=NFDeviceConsts.ROUTER_OP_LUT_DST_IP_FILTER_TABLE_DEPTH-NUM_IFACES){
                    updateIPAddresses();
                    fireTableDataChanged();
                }
            }

        });

        updateMACAddresses();
        updateIPAddresses();
    }

    /**
     * Get the values from the underlying ipTableModel
     *
     */
    protected void updateIPAddresses() {
        Integer ipInt;
        for(int i=0; i<NUM_IFACES; i=i+1){
            ipInt = (Integer) ipTableModel.getValueAt(i, WideRegTableModel.VALUES_START_COL);
            ((IPAddress)table[i][IP_COL]).setIpInt(ipInt);
        }
    }

    /**
     * Get the values from the underlying macTableModel
     *
     */
    protected void updateMACAddresses() {
        int[] macInts = new int[2];

        for(int i=0; i<2*NUM_IFACES; i+=2){
            macInts[0] = macTableModel.getRegisterAt(i).getValue();
            macInts[1] = macTableModel.getRegisterAt(i+1).getValue();
            ((MACAddress)table[i/2][MAC_COL]).setHighShort((short)macInts[0]);
            ((MACAddress)table[i/2][MAC_COL]).setLowInt(macInts[1]);
        }
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.TableModel#getColumnCount()
     */
    public int getColumnCount() {
        return 3;
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.TableModel#getRowCount()
     */
    public int getRowCount() {
        return NUM_IFACES;
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.TableModel#getValueAt(int, int)
     */
    public Object getValueAt(int rowIndex, int columnIndex) {
        return table[rowIndex][columnIndex];
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#getColumnClass(int)
     */
    public Class<?> getColumnClass(int columnIndex){
        switch(columnIndex){
        case INDEX_COL:
            return Integer.class;

        case MAC_COL:
            return MACAddress.class;

        case IP_COL:
            return IPAddress.class;

        default:
            return null;
        }
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#isCellEditable(int, int)
     */
    public boolean isCellEditable(int rowIndex,
                                    int columnIndex) {

        switch(columnIndex){
        case INDEX_COL:
            return false;

        case MAC_COL:
            return true;

        case IP_COL:
            return true;

        default:
            return false;
        }
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#setValueAt(java.lang.Object, int, int)
     */
    public void setValueAt(Object aValue,
                            int rowIndex,
                            int columnIndex) {

        /* write to the device */
        if(columnIndex==MAC_COL){
            MACAddress mac = (MACAddress) aValue;
            macTableModel.setValueAt(new Integer(mac.getHighShort()), rowIndex*2, 1);
            macTableModel.setValueAt(new Integer(mac.getLowInt()), rowIndex*2+1, 1);
        } else if(columnIndex==IP_COL){
            IPAddress ip = (IPAddress) aValue;
            ipTableModel.setValueAt(new Integer(ip.getIpInt()),
                                    rowIndex,
                                    WideRegTableModel.VALUES_START_COL);
            ipTableModel.flushModifiedRows();
        }
    }

    /*
     * (non-Javadoc)
     * @see javax.swing.table.AbstractTableModel#getColumnName(int)
     */
    public String getColumnName(int column){
        return COLUMN_NAMES[column];
    }

    /**
     * Updates the table data from the device
     *
     */
    public void updateTable(){
        ipTableModel.updateTable();
        macTableModel.updateTable();
        fireTableDataChanged();
    }
}
