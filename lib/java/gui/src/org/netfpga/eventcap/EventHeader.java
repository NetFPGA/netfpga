package org.netfpga.eventcap;

import java.util.Arrays;

public class EventHeader {

    private int version;
    private int numMonEvts;
    private long pktSeq;
    private int[] oqSizesBytes;
    private int[] oqSizesPkts;

    public EventHeader(int version, int numMonEvts, long pktSeq, int[] oqSizesBytes, int[] oqSizesPkts) {
        this.version = version;
        this.numMonEvts = numMonEvts;
        this.pktSeq = pktSeq;
        this.oqSizesBytes = Arrays.copyOf(oqSizesBytes, oqSizesBytes.length);
        this.oqSizesPkts = Arrays.copyOf(oqSizesPkts, oqSizesPkts.length);
    }

    /**
     * @return the number of monitored events in this event packet
     */
    public int getNumMonEvts() {
        return numMonEvts;
    }

    /**
     * @param numMonEvts the number of monitored events in the header
     */
    public void setNumMonEvts(int numMonEvts) {
        this.numMonEvts = numMonEvts;
    }

    /**
     * @return the packet sequence number
     */
    public long getPktSeq() {
        return pktSeq;
    }

    /**
     * @param pktSeq the packet sequenc number to set
     */
    public void setPktSeq(int pktSeq) {
        this.pktSeq = pktSeq;
    }

    /**
     * @return the version
     */
    public int getVersion() {
        return version;
    }

    /**
     * @param version the version to set
     */
    public void setVersion(int version) {
        this.version = version;
    }

    public String toString(){
        StringBuffer str = new StringBuffer("Version: "+version+", seq: "+pktSeq+"\n");
        for(int i=0; i<oqSizesBytes.length; i++){
            str.append("OQ "+i+" size (bytes): "+oqSizesBytes[i]+"\n");
        }
        for(int i=0; i<oqSizesPkts.length; i++){
            str.append("OQ "+i+" size (pkts): "+oqSizesPkts[i]+"\n");
        }
        return str.toString();
    }

    public int getOqSizeBytes(int oq) {
        return oqSizesBytes[oq];
    }

    public void setOqSizeBytes(int oq, int oqSizeBytes) {
        this.oqSizesBytes[oq] = oqSizeBytes;
    }

    public int getOqSizePkts(int oq) {
        return oqSizesPkts[oq];
    }

    public void setOqSizePkts(int oq, int oqSizePkts) {
        this.oqSizesPkts[oq] = oqSizePkts;
    }
}
