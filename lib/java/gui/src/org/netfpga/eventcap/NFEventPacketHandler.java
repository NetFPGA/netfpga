package org.netfpga.eventcap;
public interface NFEventPacketHandler {
    public void processPacketData(byte[] data);
}
