package org.netfpga.router;
import javax.swing.event.TableModelEvent;
import javax.swing.event.TableModelListener;
import javax.swing.table.AbstractTableModel;

import org.netfpga.backend.NFDevice;
import org.netfpga.backend.NFDeviceConsts;
import org.netfpga.backend.WideRegTableModel;

/**
 * This class implements a TableModel for the ARP cache table. This sits on top
 * of the WideTableModel monitoring the registers.
 *
 * @author jnaous
 *
 */
@SuppressWarnings("serial")
public class ARPTableModel extends AbstractTableModel {

    private static final String[] COLUMN_NAMES = {"Modified", "Index", "IP Address",
            "Next Hop MAC Address" };

    public static final int MODIFIED_COL = 0;
    public static final int INDEX_COL = 1;
    public static final int IP_COL = 2;
    public static final int MAC_COL = 3;

    public static final int ARP_TABLE_MODIFIED_COL = WideRegTableModel.MODIFIED_COL;
    public static final int ARP_TABLE_IP_COL = WideRegTableModel.VALUES_START_COL;
    public static final int ARP_TABLE_MAC_HI_COL = ARP_TABLE_IP_COL+1;
    public static final int ARP_TABLE_MAC_LO_COL = ARP_TABLE_MAC_HI_COL+1;

    /** table data */
    Object[][] table;

    /** table for ARP entries */
    private WideRegTableModel arpTableModel;

    /**
     * Create a new ionstance of InterfacePortConfigTableModel
     *
     * @param nf2
     */
    public ARPTableModel(NFDevice nf2){

        table = new Object[NFDeviceConsts.ROUTER_OP_LUT_ARP_TABLE_DEPTH][COLUMN_NAMES.length];

        for(int i=0; i<NFDeviceConsts.ROUTER_OP_LUT_ARP_TABLE_DEPTH; i++){
            table[i][MODIFIED_COL] = new Boolean(false);
            table[i][INDEX_COL] = new Integer(i);
            table[i][MAC_COL] = new MACAddress();
            table[i][IP_COL] = new IPAddress();
        }

        /* table column addresses */
        long[] addresses = new long[3];
        addresses[ARP_TABLE_IP_COL-WideRegTableModel.VALUES_START_COL] = NFDeviceConsts.ROUTER_OP_LUT_ARP_TABLE_ENTRY_NEXT_HOP_IP_REG;
        addresses[ARP_TABLE_MAC_HI_COL-WideRegTableModel.VALUES_START_COL] = NFDeviceConsts.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_HI_REG;
        addresses[ARP_TABLE_MAC_LO_COL-WideRegTableModel.VALUES_START_COL] = NFDeviceConsts.ROUTER_OP_LUT_ARP_TABLE_ENTRY_MAC_LO_REG;

        /* instantiate the table and add the listener */
        arpTableModel = new WideRegTableModel(nf2, addresses,
                                              NFDeviceConsts.ROUTER_OP_LUT_ARP_TABLE_WR_ADDR_REG,
                                              NFDeviceConsts.ROUTER_OP_LUT_ARP_TABLE_RD_ADDR_REG,
                                              NFDeviceConsts.ROUTER_OP_LUT_ARP_TABLE_DEPTH);

        arpTableModel.addTableModelListener(new TableModelListener() {
            public void tableChanged(TableModelEvent e) {
                int startRow = e.getFirstRow();
                int endRow = e.getLastRow();
                int val;
                for(int i=startRow; i<=endRow; i++){
                    if(i!=TableModelEvent.HEADER_ROW){

                        table[i][MODIFIED_COL] = arpTableModel.getValueAt(i, ARP_TABLE_MODIFIED_COL);

                        val = ((Integer)arpTableModel.getValueAt(i, ARP_TABLE_IP_COL)).intValue();
                        ((IPAddress)table[i][IP_COL]).setIpInt(val);

                        val = ((Integer)arpTableModel.getValueAt(i, ARP_TABLE_MAC_HI_COL)).intValue();
                        ((MACAddress)table[i][MAC_COL]).setHighShort(val);

                        val = ((Integer)arpTableModel.getValueAt(i, ARP_TABLE_MAC_LO_COL)).intValue();
                        ((MACAddress)table[i][MAC_COL]).setLowInt(val);
                    }
                }

                fireTableRowsUpdated(startRow, endRow);

            }
        });

        updateTable();
    }

    /*
     * (non-Javadoc)
     *
     * @see javax.swing.table.TableModel#getColumnCount()
     */
    public int getColumnCount() {
        return COLUMN_NAMES.length;
    }

    /*
     * (non-Javadoc)
     *
     * @see javax.swing.table.TableModel#getRowCount()
     */
    public int getRowCount() {
        return NFDeviceConsts.ROUTER_OP_LUT_ARP_TABLE_DEPTH;
    }

    /*
     * (non-Javadoc)
     *
     * @see javax.swing.table.TableModel#getValueAt(int, int)
     */
    public Object getValueAt(int rowIndex, int columnIndex) {
        return table[rowIndex][columnIndex];
    }

    /*
     * (non-Javadoc)
     *
     * @see javax.swing.table.AbstractTableModel#getColumnClass(int)
     */
    public Class<?> getColumnClass(int columnIndex) {
        switch (columnIndex) {
        case MODIFIED_COL:
            return Boolean.class;

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
     *
     * @see javax.swing.table.AbstractTableModel#isCellEditable(int, int)
     */
    public boolean isCellEditable(int rowIndex, int columnIndex) {

        switch (columnIndex) {
        case MAC_COL:
        case IP_COL:
            return true;

        default:
            return false;
        }
    }

    /*
     * (non-Javadoc)
     *
     * @see javax.swing.table.AbstractTableModel#setValueAt(java.lang.Object,
     *      int, int)
     */
    public void setValueAt(Object aValue, int rowIndex, int columnIndex) {

        /* write to the device */
        if (columnIndex == MAC_COL) {
            MACAddress mac = (MACAddress) aValue;

            arpTableModel.setValueAt(new Integer(mac.getHighShort()),
                                     rowIndex, ARP_TABLE_MAC_HI_COL);

            arpTableModel.setValueAt(new Integer(mac.getLowInt()),
                                     rowIndex, ARP_TABLE_MAC_LO_COL);

        } else if (columnIndex == IP_COL) {

            IPAddress ip = (IPAddress) aValue;

            arpTableModel.setValueAt(new Integer(ip.getIpInt()),
                                     rowIndex, ARP_TABLE_IP_COL);
        }
    }

    /*
     * (non-Javadoc)
     *
     * @see javax.swing.table.AbstractTableModel#getColumnName(int)
     */
    public String getColumnName(int column) {
        return COLUMN_NAMES[column];
    }

    /**
     * Updates the table data from the device
     *
     */
    public void updateTable() {
        arpTableModel.updateTable();
    }

    /**
     * flushes the underlying table to the device
     */
    public void flushTable(){
        arpTableModel.flushModifiedRows();
    }

    /**
     * Clear the entry at the selected row
     * @param selectedRow
     */
    public void clear(int selectedRow) {
        setValueAt(new IPAddress(), selectedRow, IP_COL);
        setValueAt(new MACAddress(), selectedRow, MAC_COL);
        flushTable();
    }
}
