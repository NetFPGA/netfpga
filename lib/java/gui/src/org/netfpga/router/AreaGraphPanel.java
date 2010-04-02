package org.netfpga.router;
import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;

import javax.swing.JFrame;

import org.jfree.chart.ChartPanel;
import org.jfree.chart.JFreeChart;
import org.jfree.chart.axis.NumberAxis;
import org.jfree.chart.plot.XYPlot;
import org.jfree.chart.renderer.xy.XYAreaRenderer;
import org.jfree.chart.renderer.xy.XYLineAndShapeRenderer;
import org.jfree.chart.renderer.xy.XYStepRenderer;
import org.jfree.data.xy.XYSeries;
import org.jfree.data.xy.XYSeriesCollection;

@SuppressWarnings("serial")
public class AreaGraphPanel extends ChartPanel implements GraphPanel {
    XYSeries data;

    public AreaGraphPanel(String title, String dataLabel, String hozLabel,
            String vertLabel, int datasetSize) {
        super(new JFreeChart(title, new XYPlot()));
        this.setMouseZoomable(true);
        this.setDisplayToolTips(true);

        // Raw data container
        this.data = new XYSeries(dataLabel);
        this.data.setMaximumItemCount(datasetSize);

        // Configure the Plot
        XYPlot myPlot = (XYPlot) this.getChart().getPlot();
        myPlot.setDataset(new XYSeriesCollection(data));
//        myPlot.setRenderer(new XYAreaRenderer(XYAreaRenderer.LINES));
        myPlot.setRenderer(new XYStepRenderer());
        myPlot.setDomainAxis(new NumberAxis(hozLabel));
        myPlot.setRangeAxis(new NumberAxis(vertLabel));
        ((NumberAxis) myPlot.getDomainAxis()).setAutoRangeIncludesZero(false);
    }

    public void addPoint(double x, double y, boolean notify) {
        this.data.add(x, y, notify);
    }

    public static void main(String[] args) throws IOException {
        JFrame fr = new JFrame("Router Graph Demo");
        fr.setSize(300, 300);
        fr.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);

        AreaGraphPanel panel = new AreaGraphPanel("Example Graph",
                "packets", "time", "occupants", 100);

        fr.getContentPane().add(panel);
        fr.setVisible(true);

        BufferedReader stdin = new BufferedReader(new InputStreamReader(
                System.in));
        while (true) {
            String input = stdin.readLine();
            int x = Integer.parseInt(input.substring(0, input.indexOf(':')));
            int y = Integer.parseInt(input.substring(input.indexOf(':') + 1));
            System.out.println("Adding point: (" + x + "," + y + ")");
            panel.addPoint(x, y, true);
        }
    }

    public void clearAll() {
        this.data.clear();
        data.fireSeriesChanged();
    }

    public void setGraphSize(int size) {
        this.data.setMaximumItemCount(size);
    }

    /* (non-Javadoc)
     * @see router.GraphPanel#notifyGraph()
     */
    public void notifyGraph() {
        this.data.fireSeriesChanged();
    }
}
