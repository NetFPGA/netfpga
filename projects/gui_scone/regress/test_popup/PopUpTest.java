
import org.netbeans.jemmy.*;
import org.netbeans.jemmy.operators.*;
import org.netbeans.jemmy.util.NameComponentChooser;
import org.netbeans.jemmy.drivers.*;
import org.netbeans.jemmy.drivers.DriverManager.*;

import org.netfpga.router.RouterMainFrame;

public class PopUpTest implements Scenario {
	MouseDriver mdriver;
    public int runIt(Object param) {
	try {

		new ClassReference("org.netfpga.router.RouterMainFrame").startApplication();
                JFrameOperator mainFrame = new JFrameOperator("Router Control Panel");
	        JInternalFrameOperator quickstart = new JInternalFrameOperator(mainFrame,"Router Quickstart");

       	        JTabbedPaneOperator tabbedpane = new JTabbedPaneOperator(quickstart);

	        tabbedpane.selectPage("Statistics");
                tabbedpane.selectPage("Details");
                new JButtonOperator(quickstart, "Output Queues").push();
                new JButtonOperator(quickstart, "Output Port Lookup").push();
                new JButtonOperator(quickstart, "MAC TX Q0").push();
                new JButtonOperator(quickstart, "MAC TX Q1").push();
                new JButtonOperator(quickstart, "MAC TX Q2").push();
                new JButtonOperator(quickstart, "MAC TX Q3").push();
                new JButtonOperator(quickstart, "MAC RX Q0").push();
                new JButtonOperator(quickstart, "MAC RX Q1").push();
                new JButtonOperator(quickstart, "MAC RX Q2").push();
                new JButtonOperator(quickstart, "MAC RX Q3").push();

                JInternalFrameOperator queueFrame = new JInternalFrameOperator(mainFrame,"Output Queues");
                JInternalFrameOperator lookupFrame = new JInternalFrameOperator(mainFrame,"Router Output port Lookup");
                JInternalFrameOperator tx0Frame = new JInternalFrameOperator(mainFrame,"MAC Tx Queue 0");
                JInternalFrameOperator tx1Frame = new JInternalFrameOperator(mainFrame,"MAC Tx Queue 1");
                JInternalFrameOperator tx2Frame = new JInternalFrameOperator(mainFrame,"MAC Tx Queue 2");
                JInternalFrameOperator tx3Frame = new JInternalFrameOperator(mainFrame,"MAC Tx Queue 3");
                JInternalFrameOperator rx0Frame = new JInternalFrameOperator(mainFrame,"MAC Rx Queue 0");
                JInternalFrameOperator rx1Frame = new JInternalFrameOperator(mainFrame,"MAC Rx Queue 1");
                JInternalFrameOperator rx2Frame = new JInternalFrameOperator(mainFrame,"MAC Rx Queue 2");                //JScrollPaneOperator  detailpane = new JScrollPaneOperator(quickstart, new NameComponentChooser("detailsscrollpane"));
                JInternalFrameOperator rx3Frame = new JInternalFrameOperator(mainFrame,"MAC Rx Queue 3");

 		//new JButtonOperator(quickstart, "Load From File").clickMouse();


	} catch(Exception e) {
	    e.printStackTrace();
	    return(1);
	}
	return(0);
    }
    public static void main(String[] argv) {
	String[] params = {"PopUpTest"};
	org.netbeans.jemmy.Test.main(params);
    }
}
