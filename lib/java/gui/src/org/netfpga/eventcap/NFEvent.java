package org.netfpga.eventcap;
/**
 * This class implements an event container for Queue events
 * @author jnaous
 *
 */
public class NFEvent {

    public static final int TIMESTAMP_TYPE = 0;
    public static final int STORE_TYPE = 1;
    public static final int REMOVE_TYPE = 2;
    public static final int DROP_TYPE = 3;

    public static final String[] TYPE_NAMES = {
        "Timestamp",
        "Store    ",
        "Remove   ",
        "Drop     "
    };

    private int type;
    private long absoluteTime;
    private int pktLength;
    private int outputQueue;

    public NFEvent(int type, long absoluteTime, int pktLength, int outputQueue){
        this.type = type;
        this.absoluteTime = absoluteTime;
        this.pktLength = pktLength;
        this.outputQueue = outputQueue;
    }

    /**
     * @return the absoluteTime
     */
    public long getAbsoluteTime() {
        return absoluteTime;
    }

    /**
     * @param absoluteTime the absoluteTime to set
     */
    public void setAbsoluteTime(long absoluteTime) {
        this.absoluteTime = absoluteTime;
    }

    /**
     * @return the pktLength
     */
    public int getPktLength() {
        return pktLength;
    }

    /**
     * @param pktLength the pktLength to set
     */
    public void setPktLength(int pktLength) {
        this.pktLength = pktLength;
    }

    /**
     * @return the type
     */
    public int getType() {
        return type;
    }

    /**
     * @param type the type to set
     */
    public void setType(int type) {
        this.type = type;
    }

    public int getOutputQueue() {
        return outputQueue;
    }

    public void setOutputQueue(int outputQueue) {
        this.outputQueue = outputQueue;
    }

    public String toString(){
        String str;
        str = "Type: ";
        if(type==TIMESTAMP_TYPE){
            str += "Timestamp";
        } else if(type==STORE_TYPE){
            str += "Store    ";
        } else if(type==REMOVE_TYPE){
            str += "Remove   ";
        } else if(type==DROP_TYPE){
            str += "Drop     ";
        } else {
            str += "Unknown "+type;
        }

        str += " - absolute time: "+absoluteTime;
        if(this.type!=TIMESTAMP_TYPE){
            str += " - Queue: "+this.outputQueue;
            str += " - length: "+pktLength;
        }
        return str;
    }
}
