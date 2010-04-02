package org.netfpga.router;
/**
 * Implements an object that can parse and display IP addresses
 * @author jnaous
 *
 */
public class IPAddress {

    /**
     * IP address in 32-bit int
     */
    private int ipInt;

    private boolean assigned = false;

    /**
     * Create a new IPAddress instance.
     * @param ipStr dotted representation of ip address
     * @throws Exception
     */
    public IPAddress(String ipStr) throws Exception{
        this.ipInt = ipStringToInt(ipStr);
        assigned = true;
    }

    /**
     * Create new instance of IPAddress
     * @param ipInt
     */
    public IPAddress(int ipInt) {
        this.ipInt = ipInt;
        assigned = true;
    }

    /**
     * Create new instance of IPAddress
     *
     */
    public IPAddress() {
        super();
    }

    /**
     * Convert a dotted IP Address string to an int
     * @param ipStr
     * @return
     * @throws Exception if the String is not a correct IP address
     */
    public static int ipStringToInt(String ipStr) throws Exception{
        int ipInt;
        String[] ipWords = ipStr.split("\\.");
        if(ipWords.length!=4){
            throw new Exception("Bad IP Address String.");
        }

        ipInt = 0;
        int parsedWord;
        for(int i=0; i<4; i++){
            parsedWord = Integer.parseInt(ipWords[i]);
            if(parsedWord>255 || parsedWord<0){
                throw new Exception("Number in dotted IP address should be between 0 and 255");
            }
            ipInt = (ipInt<<8) | parsedWord;
        }
        return ipInt;
    }

    /*
     * (non-Javadoc)
     * @see java.lang.Object#toString()
     */
    public String toString(){
        if(assigned){
            String ipStr;
            ipStr = ""+((ipInt>>24)&0xff)
                    + "." + ((ipInt>>16)&0xff)
                    + "." + ((ipInt>>8)&0xff)
                    + "." + ((ipInt)&0xff);
            return ipStr;
        } else {
            return "";
        }
    }

    /**
     * @return the int form of the ip address
     */
    public int getIpInt() {
        return ipInt;
    }

    /**
     * @param ipInt set the int form of the ip address
     */
    public void setIpInt(int ipInt) {
        this.ipInt = ipInt;
        assigned = true;
    }

    /**
     * @param assigned the assigned to set
     */
    public void setAssigned(boolean assigned) {
        this.assigned = assigned;
    }

    /**
     * @return the assigned
     */
    public boolean isAssigned() {
        return assigned;
    }
}
