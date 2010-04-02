package org.netfpga.router;
import java.util.Date;

/**
 * Implements a row with all its associated fields of a
 * StatsRegTableModel row.
 * @author jnaous
 *
 */
public class StatsRegGroup {

    private GraphPanel graph;
    private String units;
    private int divider = 1;
    private long startTime;
    private boolean differentialGraph = true;
    private long currentValue;
    private String description;
    private boolean start;

    public StatsRegGroup(String description){
        super();
        startTime = new Date().getTime();
        this.description = description;
        start = true;
    }

    public StatsRegGroup() {
        startTime = new Date().getTime();
        this.description = "";
        start = true;
    }

    /**
     * Adds a new point and updates the graph and value
     * @param value
     */
    public void update(int value){
        update(value, true);
    }

    /**
     * Adds a new point and updates the graph and value
     * @param value
     */
    public void update(long value, boolean notify){
        int deltaTime = 0;
        long deltaCount = 0;

        if(value<0){
            value += Integer.MAX_VALUE;
        }

        value = value/divider;

        /* first value */
        if(start){
            this.currentValue = value;
            start = false;
        }

        if(graph!=null){
            /* get the time difference */
            deltaTime = (int)(new Date().getTime()-startTime);
            if(differentialGraph){
                /* get the count difference */
                deltaCount = value - currentValue;

                /* add the change in count to the graph */
                graph.addPoint(deltaTime, (int)deltaCount, notify);
            } else {
                graph.addPoint(deltaTime, (int)value, notify);
            }
        }

        /* update the stored value */
        this.currentValue = value;
    }

    /**
     * Clears the row
     *
     */
    public void reset(){
        startTime = new Date().getTime();
        if(graph!=null) {
            graph.clearAll();
        }
        this.currentValue = 0;
        start = true;
    }

    /**
     * Gets the value in a string
     * @return
     */
    public String getValueString(){
        String str = ""+currentValue;
        if(units!=null && !str.equals("")){
            str = str+" "+units;
        }
        return str;
    }

    /**
     * @return the currentValue
     */
    public long getCurrentValue() {
        return currentValue;
    }

    /**
     * @param currentValue the currentValue to set
     */
    public void setCurrentValue(long currentValue) {
        this.currentValue = currentValue;
    }

    /**
     * @return the description
     */
    public String getDescription() {
        return description;
    }

    /**
     * @param description the description to set
     */
    public void setDescription(String description) {
        this.description = description;
    }

    /**
     * @return the differentialGraph
     */
    public boolean isDifferentialGraph() {
        return differentialGraph;
    }

    /**
     * @param differentialGraph the differentialGraph to set
     */
    public void setDifferentialGraph(boolean differentialGraph) {
        this.differentialGraph = differentialGraph;
    }

    /**
     * @return the divider
     */
    public int getDivider() {
        return divider;
    }

    /**
     * @param divider the divider to set
     */
    public void setDivider(int divider) {
        this.divider = divider;
    }

    /**
     * @return the graph
     */
    public GraphPanel getGraph() {
        return graph;
    }

    /**
     * @param graph the graph to set
     */
    public void setGraph(GraphPanel graph) {
        this.graph = graph;
    }

    /**
     * @return the startTime
     */
    public long getStartTime() {
        return startTime;
    }

    /**
     * @param startTime the startTime to set
     */
    public void setStartTime(long startTime) {
        this.startTime = startTime;
    }

    /**
     * @return the units
     */
    public String getUnits() {
        return units;
    }

    /**
     * @param units the units to set
     */
    public void setUnits(String units) {
        this.units = units;
    }

    /**
     * @return Returns a string representation of the value
     */
    public String toString(){
        return description+" : "+getValueString();
    }
}
