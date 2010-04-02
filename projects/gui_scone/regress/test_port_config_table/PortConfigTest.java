import org.netbeans.jemmy.*;
import org.netbeans.jemmy.operators.*;
import org.netbeans.jemmy.util.NameComponentChooser;
import org.netbeans.jemmy.drivers.*;
import org.netbeans.jemmy.drivers.DriverManager.*;

import org.netfpga.router.RouterMainFrame;

public class PortConfigTest implements Scenario {
    public int runIt(Object param) {
	try {

		new ClassReference("org.netfpga.router.RouterMainFrame").startApplication();
                JFrameOperator mainFrame = new JFrameOperator("Router Control Panel");
	        JInternalFrameOperator quickstart = new JInternalFrameOperator(mainFrame,"Router Quickstart");

                JTableOperator portconfigtable = new JTableOperator(quickstart,new NameComponentChooser("ifaceTable"));
	        portconfigtable.clickOnCell(0,1);
                portconfigtable.changeCellObject(0,1,"a0:b0:c0:d0:e0:f0");
                portconfigtable.changeCellObject(1,1,"a1:b1:c1:d1:e1:f1");
                portconfigtable.changeCellObject(2,1,"a2:b2:c2:d2:e2:f2");
                portconfigtable.changeCellObject(3,1,"a3:b3:c3:d3:e3:f3");

                /*
                portconfigtable.changeCellObject(0,2,"255.0.0.01");
                portconfigtable.changeCellObject(1,2,"255.0.0.02");
                portconfigtable.changeCellObject(2,2,"255.0.0.03");
                portconfigtable.changeCellObject(3,2,"255.0.0.04");
                */


	} catch(Exception e) {
	    e.printStackTrace();
	    return(1);
	}
	return(0);
    }
    public static void main(String[] argv) {
	String[] params = {"PortConfigTest"};
	org.netbeans.jemmy.Test.main(params);
    }
}
