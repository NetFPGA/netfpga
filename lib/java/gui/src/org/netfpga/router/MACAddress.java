package org.netfpga.router;
/**
 * Implement a MAC Address container class that parses MAC addresses.
 * @author jnaous
 *
 */
public class MACAddress {

    private int[] mac;

    public MACAddress(String macStr) throws Exception{
        mac = MACStringToIntArray(macStr);
    }

    public MACAddress() {
        mac = null;
    }

    /**
     * Converts MAC address string format xx:xx:xx:xx:xx:xx to
     * an array of 6 bytes. Byte at index 0 has the left-most byte
     * of the address as described above
     * @param macStr
     * @return
     * @throws Exception if the String is not a MAC address
     */
    public static int[] MACStringToIntArray(String macStr) throws Exception{
        String[] byteWords = macStr.split(":");
        if(byteWords.length!=6){
            throw new Exception("Bad MAC Address");
        }

        int[] macBytes = new int[6];

        for(int i=0; i<6; i++){
            macBytes[i] = Integer.parseInt(byteWords[i], 16);
            if(macBytes[i]>255 || macBytes[i]<0){
                throw new Exception("MAC address bytes should be between 0x0 and 0xff");
            }
        }
        return macBytes;
    }

    /**
     * Get the highest (left-most) two bytes of the mac address
     * @return a short representing the highest two bytes
     */
    public int getHighShort(){
        if(mac != null){
            short hi;
            hi = (short) mac[0];
            hi = (short) ((hi<<8) | mac[1]);
            return (hi & 0xffff);
        } else {
            return 0;
        }
    }

    /**
     * Sets the upper two bytes of the mac address from a short
     * @param macHi high 16 bits (short) of the mac address
     */
    public void setHighShort(int macHi){
        if(mac==null){
            mac = new int[6];
        }
        mac[1] = (macHi & 0xff);
        mac[0] = ((macHi>>8) & 0xff);
    }

    /**
     * Returns the lowest 4 bytes of the mac address as an int
     * @return
     */
    public int getLowInt(){
        if(mac != null){
            int lo;
            lo = mac[2];
            lo = ((lo<<8) | mac[3]);
            lo = ((lo<<8) | mac[4]);
            lo = ((lo<<8) | mac[5]);
            return lo;
        } else {
            return 0;
        }
    }

    /**
     * Sets the lower four bytes of the mac address from an int
     * @param macLo low 32 bits (int) of the mac address
     */
    public void setLowInt(int macLo){
        if(mac==null){
            mac = new int[6];
        }
        mac[5] = (macLo & 0xff);
        mac[4] = ((macLo>>8) & 0xff);
        mac[3] = ((macLo>>16) & 0xff);
        mac[2] = ((macLo>>24) & 0xff);
    }

    /*
     * (non-Javadoc)
     * @see java.lang.Object#toString()
     */
    public String toString() {
        if(mac != null){
            String macStr;
            String hex;
            macStr = "";
            for(int i=0; i<6; i++){
                hex = Integer.toHexString(mac[i]);
                if(hex.length()==1) {
                    hex = "0"+hex;
                }
                macStr = macStr + hex + ":";
            }
            return macStr.substring(0, macStr.length()-1);
        } else {
            return "";
        }
    }

    /**
     * @return the mac
     */
    public int[] getMac() {
        return mac;
    }

    /**
     * @param mac the mac to set
     */
    public void setMac(int[] mac) {
        this.mac = mac;
    }

    public static void main(String[] args) throws Exception{
        System.out.println("ff:ff:ff:ff:ff:ff becomes "+new MACAddress("ff:ff:ff:ff:ff:ff").toString());
        MACAddress mac = new MACAddress("1:2:3:4:5:6");
        System.out.println("01:2:3:4:5:6 becomes "+Integer.toHexString(mac.getHighShort()));
        System.out.println("01:2:3:4:5:6 becomes "+Integer.toHexString(mac.getLowInt()));
    }
}
