package org.netfpga.router;
public interface GraphPanel {
    public void addPoint(double x, double y, boolean notify);
    public void clearAll();
    public void setGraphSize(int size);
    public void notifyGraph();
}
