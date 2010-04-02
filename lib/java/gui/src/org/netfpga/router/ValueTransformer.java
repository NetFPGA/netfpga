package org.netfpga.router;
public interface ValueTransformer {

    public String toLabelStringFromComponent(int val);
    public String toLabelStringFromReg(int val);
    public int toSliderValue(int val);
    public int toRegisterValue(int val);

}
