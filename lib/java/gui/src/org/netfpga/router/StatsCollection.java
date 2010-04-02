package org.netfpga.router;
import java.util.Date;

import javax.swing.JLabel;

/**
 * Implements an object which keeps track of statistics on a value.
 * When the value changes, the change is reflected in the graph (if any) and
 * in the label if any.
 * @author jnaous
 *
 */
public class StatsCollection {

    private JLabel valueLabel;
    private GraphPanel graph;
    private String labelUnits;
    private int labelDivider;
    private long startTime;
    private long prevValue;
    private boolean start=true;

    public StatsCollection(JLabel valueLabel, GraphPanel graph){
        this.valueLabel = valueLabel;
        this.graph = graph;
        this.labelUnits = null;
        this.labelDivider = 1;
        startTime = new Date().getTime();
    }

    public StatsCollection(JLabel valueLabel, GraphPanel graph, String labelUnits, int labelDivider){
        this.valueLabel = valueLabel;
        this.graph = graph;
        this.labelUnits = labelUnits;
        this.labelDivider = labelDivider;
        startTime = new Date().getTime();
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
     * @return the labelDivider
     */
    public int getLabelDivider() {
        return labelDivider;
    }

    /**
     * @param labelDivider the labelDivider to set
     */
    public void setLabelDivider(int labelDivider) {
        this.labelDivider = labelDivider;
    }

    /**
     * @return the labelUnits
     */
    public String getLabelUnits() {
        return labelUnits;
    }

    /**
     * @param labelUnits the labelUnits to set
     */
    public void setLabelUnits(String labelUnits) {
        this.labelUnits = labelUnits;
    }

    /**
     * @return the valueLabel
     */
    public JLabel getValueLabel() {
        return valueLabel;
    }

    /**
     * @param valueLabel the valueLabel to set
     */
    public void setValueLabel(JLabel valueLabel) {
        this.valueLabel = valueLabel;
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
     * Adds a new point and updates the graph and label
     * @param value
     * @param notify signals graph redraw if true
     */
    public void update(long value, boolean notify){
        int deltaTime = 0;
        int deltaCount = 0;

        if(value<0){
            value += Integer.MAX_VALUE;
        }

        if(start){
            this.prevValue = value;
            start=false;
        }

        if(graph!=null){
            /* get the time difference */
            deltaTime = (int)(new Date().getTime()-startTime);

            /* get the count difference */
            deltaCount = (int) (value - prevValue);

            /* add the change in count to the graph */
            graph.addPoint(deltaTime, deltaCount, notify);
        }

        if(valueLabel!=null){
            /* update the label */
            if(labelUnits!=null){
                this.valueLabel.setText(String.valueOf(value/labelDivider)+labelUnits);
            } else {
                this.valueLabel.setText(String.valueOf(value/labelDivider));
            }
        }

        /* update the previous value */
        this.prevValue = value;
    }

    /**
     * Adds a new point and updates the graph and label
     * same as update(value, true);
     * @param value
     */
    public void update(int value){
        update(value, true);
    }

    public void reset(){
        if(graph!=null) graph.clearAll();
        if(valueLabel!=null){
            if(labelUnits!=null){
                this.valueLabel.setText(String.valueOf(0)+labelUnits);
            } else {
                this.valueLabel.setText(String.valueOf(0));
            }
        }
        start = true;
    }

}
