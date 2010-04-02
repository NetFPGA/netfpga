import org.netbeans.jemmy.*;
import org.netbeans.jemmy.operators.*;
import org.netbeans.jemmy.util.NameComponentChooser;
import org.netbeans.jemmy.drivers.*;
import org.netbeans.jemmy.drivers.DriverManager.*;

import org.netfpga.router.RouterMainFrame;

public class RoutingTablePortTest implements Scenario {

    public int runIt(Object param) {
	try {

		new ClassReference("org.netfpga.router.RouterMainFrame").startApplication();
                JFrameOperator mainFrame = new JFrameOperator("Router Control Panel");
	        JInternalFrameOperator quickstart = new JInternalFrameOperator(mainFrame,"Router Quickstart");

	        JTableOperator routingtable = new JTableOperator(quickstart,new NameComponentChooser("routingTable"));

	        for(int i=0; i<=32; i++){
	    	   for(int j=5;j<=12; j++){
	    	  	routingtable.clickOnCell(i,j,1);
	    	   }
                }
	  routingtable.clickOnCell(0,0,1);
	} catch(Exception e) {
	    e.printStackTrace();
	    return(1);
	}
	return(0);
    }
    public static void main(String[] argv) {
	String[] params = {"RoutingTablePortTest"};
	org.netbeans.jemmy.Test.main(params);
    }
}
