/**
 *
 */
package org.netfpga.backend;

import com.sun.jna.Library;
import com.sun.jna.Native;
import com.sun.jna.Structure;
import com.sun.jna.ptr.IntByReference;

/**
 * Provides access to ioctl calls for register access.
 * @author jnaous
 *
 */
public interface NFRegAccess extends Library {

	/* create an instance of this interface to load the library */
	NFRegAccess INSTANCE = (NFRegAccess) Native.loadLibrary ("nf2", NFRegAccess.class);

	public static class NF2 extends Structure {
		public String device_name;
		public int fd;
		public int net_iface;
	}

	public int readReg(NF2 nf2, int reg, IntByReference val);
	public int writeReg(NF2 nf2, int reg, int val);
	public int check_iface(NF2 nf2);
	public int openDescriptor(NF2 nf2);
	public int closeDescriptor(NF2 nf2);
	public void read_info(NF2 nf2);
	public void printHello(NF2 nf2, IntByReference val);
}

