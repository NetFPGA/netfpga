/**
 *
 */
package org.netfpga.backend;

import com.sun.jna.ptr.IntByReference;

/**
 * @author jnaous
 *
 */
public class NFDevice {

    public static final int WRITE_ACCESS = 0;
    public static final int READ_ACCESS = 1;

    private NFRegAccess.NF2 nf2 = new NFRegAccess.NF2 ();

    public NFDevice(){};

    public NFDevice(String ifaceName) {
        this.nf2.device_name = ifaceName;
        this.nf2.fd = 0;
        this.nf2.net_iface = 0;
    }

    public NFDevice(String ifaceName, int fileDescriptor, int netIface) {
        this.nf2.device_name = ifaceName;
        this.nf2.fd = fileDescriptor;
        this.nf2.net_iface = netIface;
    }

    /**
     * Read the register at the specified address
     * @param addr
     * @return the value at the address
     */
    public int readReg(long addr) {
    	/* create pointer to int */
    	IntByReference val = new IntByReference();
    	NFRegAccess.INSTANCE.readReg(nf2, (int)addr, val);
    	return val.getValue();
    }

    /**
     * Write value to the specified address
     * @param addr the location to write
     * @param value the value to write
     */
    public void writeReg(long addr, int val) {
    	NFRegAccess.INSTANCE.writeReg(nf2, (int)addr, val);
    }

    /**
     * Perform all operations in the array in one go
     * @param addr the locations to read/write
     * @param value the values to read/write
     * @param access_types for each location, a 1 is a read, a 0 is a write
     * @param num_accesses the number of addresses in the array to read/write
     * @return
     */
    public void accessRegArray(long []addr, int []value, int[] access_types, int num_accesses) {
        int i;

        /* perform the accesses */
        for(i=0; i<num_accesses; i=i+1) {
            if(access_types[i]==WRITE_ACCESS) {
            	writeReg(addr[i], value[i]);
            } else if (access_types[i]==READ_ACCESS) {
                value[i] = readReg(addr[i]);;
            }
        }
    }

    /**
     * check if the interface exists
     * @return 1 on error
     */
    public int checkIface() {
    	return NFRegAccess.INSTANCE.check_iface(nf2);
    }

    /**
     * Opens the interface for access
     * @return non-zero on error
     */
    public int openDescriptor() {
    	return NFRegAccess.INSTANCE.openDescriptor(nf2);
    }

    /**
     * Closes the file descriptor
     * @return non-zero on error
     */
    public int closeDescriptor() {
    	return NFRegAccess.INSTANCE.closeDescriptor(nf2);
    }

	public String getIfaceName() {
		return nf2.device_name;
	}

	public void setIfaceName(String devName) {
		nf2.device_name = devName;
	}
}
