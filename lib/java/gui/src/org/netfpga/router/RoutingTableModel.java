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
public class RoutingTableModel extends AbstractTableModel {

    private static final String[] COLUMN_NAMES = { "Modified", "Index", "Destination IP Addr",
            "Subnet Mask", "NextHop IP Addr", "MAC0", "CPU0", "MAC1", "CPU1",
            "MAC2", "CPU2", "MAC3", "CPU3"};

    /* Table indices in RoutingTableModel */
    public static final int MODIFIED_COL = 0;
    public static final int INDEX_COL = 1;
    public static final int SUBNET_IP_COL = 2;
    public static final int SUBNET_MASK_COL = 3;
    public static final int NEXT_HOP_IP_COL = 4;
    public static final int OUTPUT_MAC_0_COL = 5;
    public static final int OUTPUT_CPU_0_COL = 6;
    public static final int OUTPUT_MAC_1_COL = 7;
    public static final int OUTPUT_CPU_1_COL = 8;
    public static final int OUTPUT_MAC_2_COL = 9;
    public static final int OUTPUT_CPU_2_COL = 10;
    public static final int OUTPUT_MAC_3_COL = 11;
    public static final int OUTPUT_CPU_3_COL = 12;

    /* Table indices in the underlying WideRegTableModel (this.routingTableModel) */
    public static final int RT_TABLE_MODIFIED_COL = WideRegTableModel.MODIFIED_COL;
    public static final int RT_TABLE_SUBNET_IP_COL = WideRegTableModel.VALUES_START_COL;
    public static final int RT_TABLE_SUBNET_MASK_COL = RT_TABLE_SUBNET_IP_COL+1;
    public static final int RT_TABLE_NEXT_HOP_IP_COL = RT_TABLE_SUBNET_MASK_COL+1;
    public static final int RT_TABLE_OUTPUT_PORTS_COL = RT_TABLE_NEXT_HOP_IP_COL+1;

    /** table data */
    Object[][] table;

    /** table for ARP entries */
    private WideRegTableModel routingTableModel;

    /**
     * Create a new ionstance of InterfacePortConfigTableModel
     *
     * @param nf2
     */
    public RoutingTableModel(NFDevice nf2){

        table = new Object[NFDeviceConsts.ROUTER_OP_LUT_ROUTE_TABLE_DEPTH][COLUMN_NAMES.length];

        for(int i=0; i<NFDeviceConsts.ROUTER_OP_LUT_ROUTE_TABLE_DEPTH; i++){
            table[i][INDEX_COL] = new Integer(i);
            table[i][MODIFIED_COL] = new Boolean(false);
            table[i][SUBNET_IP_COL] = new IPAddress();
            table[i][SUBNET_MASK_COL] = new IPAddress();
            table[i][NEXT_HOP_IP_COL] = new IPAddress();
            for(int j=OUTPUT_MAC_0_COL; j<=OUTPUT_CPU_3_COL; j++){
                table[i][j] = new Boolean(false);
            }
        }

        /* table column addresses */
        long[] addresses = new long[4];
        addresses[RT_TABLE_NEXT_HOP_IP_COL-WideRegTableModel.VALUES_START_COL] = NFDeviceConsts.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_NEXT_HOP_IP_REG;
        addresses[RT_TABLE_OUTPUT_PORTS_COL-WideRegTableModel.VALUES_START_COL] = NFDeviceConsts.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_OUTPUT_PORT_REG;
        addresses[RT_TABLE_SUBNET_IP_COL-WideRegTableModel.VALUES_START_COL] = NFDeviceConsts.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_IP_REG;
        addresses[RT_TABLE_SUBNET_MASK_COL-WideRegTableModel.VALUES_START_COL] = NFDeviceConsts.ROUTER_OP_LUT_ROUTE_TABLE_ENTRY_MASK_REG;

        /* instantiate the table and add the listener */
        routingTableModel = new WideRegTableModel(nf2, addresses,
                                              NFDeviceConsts.ROUTER_OP_LUT_ROUTE_TABLE_WR_ADDR_REG,
                                              NFDeviceConsts.ROUTER_OP_LUT_ROUTE_TABLE_RD_ADDR_REG,
                                              NFDeviceConsts.ROUTER_OP_LUT_ROUTE_TABLE_DEPTH);

        routingTableModel.addTableModelListener(new TableModelListener() {
            public void tableChanged(TableModelEvent e) {
                int startRow = e.getFirstRow();
                int endRow = e.getLastRow();
                int val;
                for(int i=startRow; i<=endRow; i++){
                    if(i!=TableModelEvent.HEADER_ROW){
                        table[i][MODIFIED_COL] = routingTableModel.getValueAt(i, RT_TABLE_MODIFIED_COL);

                        val = ((Integer)routingTableModel.getValueAt(i, RT_TABLE_NEXT_HOP_IP_COL)).intValue();
                        ((IPAddress)table[i][NEXT_HOP_IP_COL]).setIpInt(val);

                        val = ((Integer)routingTableModel.getValueAt(i, RT_TABLE_SUBNET_IP_COL)).intValue();
                        ((IPAddress)table[i][SUBNET_IP_COL]).setIpInt(val);

                        val = ((Integer)routingTableModel.getValueAt(i, RT_TABLE_SUBNET_MASK_COL)).intValue();
                        ((IPAddress)table[i][SUBNET_MASK_COL]).setIpInt(val);

                        val = ((Integer)routingTableModel.getValueAt(i, RT_TABLE_OUTPUT_PORTS_COL)).intValue();
                        for(int j=OUTPUT_MAC_0_COL, shift=0; j<=OUTPUT_CPU_3_COL; j++, shift++){
                            table[i][j] = new Boolean((val & (1<<shift))!=0);
                        }
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
        return NFDeviceConsts.ROUTER_OP_LUT_ROUTE_TABLE_DEPTH;
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
        case INDEX_COL:
            return Integer.class;

        case SUBNET_IP_COL:
        case SUBNET_MASK_COL:
        case NEXT_HOP_IP_COL:
            return IPAddress.class;

        case MODIFIED_COL:
        case OUTPUT_CPU_0_COL:
        case OUTPUT_CPU_1_COL:
        case OUTPUT_CPU_2_COL:
        case OUTPUT_CPU_3_COL:
        case OUTPUT_MAC_0_COL:
        case OUTPUT_MAC_1_COL:
        case OUTPUT_MAC_2_COL:
        case OUTPUT_MAC_3_COL:
            return Boolean.class;

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

        if(columnIndex==INDEX_COL || columnIndex==MODIFIED_COL){
            return false;
        } else {
            return true;
        }
    }

    /*
     * (non-Javadoc)
     *
     * @see javax.swing.table.AbstractTableModel#setValueAt(java.lang.Object,
     *      int, int)
     */
    public void setValueAt(Object aValue, int rowIndex, int columnIndex) {
        int val;
        /* write to the underlying table */
        if (columnIndex >= OUTPUT_MAC_0_COL && columnIndex <= OUTPUT_CPU_3_COL) {
            /* get the original value of the output ports */
            val = ((Integer)(routingTableModel.getValueAt(rowIndex, RT_TABLE_OUTPUT_PORTS_COL))).intValue();
            /* if the value we are setting is true then set the bit corresponding to the queue */
            if(((Boolean)aValue).booleanValue()){
                val |= (1<<(columnIndex-OUTPUT_MAC_0_COL));
            } else {
                val &= ~(1<<(columnIndex-OUTPUT_MAC_0_COL));
            }
            routingTableModel.setValueAt(new Integer(val),
                                         rowIndex, RT_TABLE_OUTPUT_PORTS_COL);

        } else if (columnIndex != INDEX_COL && columnIndex != MODIFIED_COL) {
            /* all the other columns are IPAddresses */
            IPAddress ip = (IPAddress) aValue;

            /* the column indices correspond to each other */
            routingTableModel.setValueAt(new Integer(ip.getIpInt()),
                                         rowIndex, columnIndex);
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
        routingTableModel.updateTable();
    }

    /**
     * flushes the underlying table to the device
     */
    public void flushTable(){
        routingTableModel.flushModifiedRows();
    }

    /**
     * Clear the entry at the selected row
     * @param selectedRow
     */
    public void clear(int selectedRow) {
        setValueAt(new IPAddress(), selectedRow, SUBNET_IP_COL);
        setValueAt(new IPAddress(), selectedRow, SUBNET_MASK_COL);
        setValueAt(new IPAddress(), selectedRow, NEXT_HOP_IP_COL);
        for(int i = OUTPUT_MAC_0_COL; i<= OUTPUT_CPU_3_COL; i++){
            setValueAt(new Boolean(false), selectedRow, i);
        }
        flushTable();
    }
}
