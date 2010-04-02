package org.netfpga.backend;

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;
import java.util.Collection;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Random;

import javax.swing.Timer;

public class NFDeviceTest extends NFDevice implements ActionListener{

    HashMap<Long, Integer> table;

    Timer timer;

    public NFDeviceTest(String ifaceName) {
        table = new HashMap<Long, Integer>();
        timer = new Timer(5000, this);
        timer.start();
    }

    /**
     * Read the register at the specified address
     * @param addr
     * @return the value at the address
     */
    public int readReg(long addr){
        Long key = new Long(addr);
        if(!table.containsKey(key)){
            table.put(key, new Integer(0));
        }
        int value = ((Integer)table.get(key)).intValue();
//        System.out.println("Read "+value+" from 0x"+ Long.toHexString(addr));
        return value;
    }

    /**
     * Write value to the speicifed address
     * @param addr the location to write
     * @param value the value to write
     * @return
     */
    public void writeReg(long addr, int value){
//        System.out.println("Wrote "+value+" to 0x"+ Long.toHexString(addr));
        Long key = new Long(addr);
        table.put(key, new Integer(value));
    }

    /**
     * Perform all opreations in the array in one go
     * @param addr the locations to read/write
     * @param value the values to read/write
     * @param access_types for each location, a 1 is a read, a 0 is a write
     * @param num_accesses the number of addresses in the array to read/write
     * @return
     * @return
     */
    public void accessRegArray(long []addr, int []value, int[] access_types, int num_accesses){
//        System.out.println("Accessing Reg array...");
        for(int i=0; i<num_accesses; i++){
            if(access_types[i]==WRITE_ACCESS){
                writeReg(addr[i], value[i]);
            } else {
                value[i] = readReg(addr[i]);
            }
        }
    }

    /**
     * check if the interface exists
     * @return 1 on error
     */
    public int checkIface(){
        return 0;
    }

    /**
     * Opens the interface for access
     * @return non-zero on error
     */
    public int openDescriptor(){
        return 0;
    }

    /**
     * Closes the file descriptor
     * @return non-zero on error
     */
    public int closeDescriptor(){
        return 0;
    }

    public void actionPerformed(ActionEvent e) {
        Collection<Long> keySet = table.keySet();
        Iterator<Long> i = keySet.iterator();
        Random r = new Random();
        while(i.hasNext()){
            /* flip a coin to determine if we should increment */
            boolean heads = r.nextBoolean();
            Long v=(Long)i.next();
            if(heads || r.nextBoolean()){
//                System.out.println("Updating value in 0x"+v);
                table.put(v, ((Integer)(((Integer)table.get(v)).intValue()+r.nextInt(100))));
            } else {
//                System.out.println("Not updating value in 0x"+v);
            }
        }
        /* make sure the number removed<number stored */
        for(int j=0; j<4*8; j+=4){
            int addr_rem = NFDeviceConsts.OQ_QUEUE_0_NUM_PKT_BYTES_REMOVED_REG+j;
            int addr_str = NFDeviceConsts.OQ_QUEUE_0_NUM_PKT_BYTES_STORED_REG+j;
            Integer val_rem = (Integer)table.get(addr_rem);
            Integer val_str = (Integer)table.get(addr_str);
            if(val_rem != null && val_str != null){
                if(val_rem.intValue()>val_str.intValue()){
                    Long addr = new Long(addr_str);
                    table.put(addr, val_rem);
                }
            }
        }
    }

}
