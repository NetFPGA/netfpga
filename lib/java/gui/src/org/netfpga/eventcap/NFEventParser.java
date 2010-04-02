package org.netfpga.eventcap;
import java.io.IOException;
import java.io.InputStream;

public class NFEventParser {
    public static int EVENT_TYPE_MASK = 0xC0000000;
    public static int EVENT_TYPE_SHIFT = 30;

    public static int OQ_MASK         = 0x38000000;
    public static int OQ_SHIFT        = 27;

    public static int LENGTH_MASK     = 0x07f80000;
    public static int LENGTH_SHIFT    = 19;

    public static int TIME_MASK       = 0x0007ffff;

    private long absoluteTime;

    /**
     * Creates a new instance of NFEventParser
     *
     */
    public NFEventParser(){
        this.absoluteTime = 0;
    }

    /**
     * Read an event from the input stream and return the corresponding parsed event
     * @param in InputStream from which to read bytes
     * @return returns the Event that was last read from the input stream
     *          or null if there aren't enough bytes in the stream for an event
     * @throws IOException
     */
    public NFEvent parseNextEvent(InputStream in) throws IOException{

        /* make sure we have enough to read */
        if(in.available()>=4){
            in.mark(8);

            /* Read exactly 4 bytes */
            long shortEvent = readUnsignedInt(in);

            /* parse the event */
            int type = (int) ((shortEvent & EVENT_TYPE_MASK) >> EVENT_TYPE_SHIFT);

            /* if the event is a timestamp event, then we need 8 bytes instead of four
             * so we read four more bytes */
            if(type == NFEvent.TIMESTAMP_TYPE) {
                if(in.available()<4){
                    in.reset();
                    return null;
                }
                long longEvent = (shortEvent & ~NFEvent.TIMESTAMP_TYPE);
                longEvent <<= Integer.SIZE;
                longEvent += readUnsignedInt(in);
                this.absoluteTime = longEvent;
                return new NFEvent(NFEvent.TIMESTAMP_TYPE, this.absoluteTime, 0, 0);
            }

            /* If we reach here then it is a short event */
            int len = (int) ((shortEvent & LENGTH_MASK) >> LENGTH_SHIFT)*8;
            int oq = (int) ((shortEvent & OQ_MASK) >> OQ_SHIFT);
            int relTime = (int) (shortEvent & TIME_MASK);

            absoluteTime = (absoluteTime & ~TIME_MASK) | relTime;
            NFEvent evt = new NFEvent(type, absoluteTime, len, oq);
//            System.out.println(evt);
            return evt;
        } else {
            return null;
        }
    }

    /**
     * Read an int from the input stream
     * @param in the input stream to read from
     * @return the int read
     * @throws IOException
     */
    private long readUnsignedInt(InputStream in) throws IOException {

        long ret;

        /* put the four bytes we just read into an int for parsing */
        ret = readUnsignedByte(in);
        ret = (ret<<8) | readUnsignedByte(in);
        ret = (ret<<8) | readUnsignedByte(in);
        ret = (ret<<8) | readUnsignedByte(in);

	//System.out.printf("    readInt 0x%08x\n", ret);

        return ret;
    }

    /**
     * Gets the header of the event packet
     * @param in the input stream from which to read the packet.
     * @return the event header
     * @throws IOException if an error occurs when reading the input stream
     */
    public EventHeader parseEventPacketHdr(InputStream in) throws IOException{
        /* skip the IP and UDP headers */
        for(int i=0; i<7 ;i++){
//            System.out.print("Skipping "+i+": ");
            readUnsignedInt(in);
        }
        int version = readUnsignedByte(in);
        int numMonEvts = readUnsignedByte(in);
//        System.out.print("Seq : ");
        long pktSeq = readUnsignedInt(in);
        int[] oqSizesBytes = new int[8];
        int[] oqSizesPkts = new int[8];
        for(int i=0; i<8; i++) {
            oqSizesBytes[i] = (int) readUnsignedInt(in)*8;
            oqSizesPkts[i] = (int) readUnsignedInt(in);
        }
        return new EventHeader(version, numMonEvts, pktSeq, oqSizesBytes, oqSizesPkts);
    }

    private int readUnsignedByte(InputStream in) throws IOException{
        int b = in.read();
        if(b<0){
            b += 256;
        }
        return b;
    }

}
