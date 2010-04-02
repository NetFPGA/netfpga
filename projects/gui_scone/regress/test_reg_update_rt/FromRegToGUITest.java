import org.netbeans.jemmy.*;
import org.netbeans.jemmy.operators.*;
import org.netbeans.jemmy.util.NameComponentChooser;
import org.netbeans.jemmy.drivers.*;
import org.netbeans.jemmy.drivers.DriverManager.*;

import org.netfpga.router.RouterMainFrame;

public class FromRegToGUITest implements Scenario {

    public int runIt(Object param) {
	try {

		new ClassReference("netfpga.router.RouterMainFrame").startApplication();
                JFrameOperator mainFrame = new JFrameOperator("Router Control Panel");
	        JInternalFrameOperator quickstart = new JInternalFrameOperator(mainFrame,"Router Quickstart");

	        JTableOperator routingtable = new JTableOperator(quickstart,new NameComponentChooser("routingTable"));

                JTextFieldOperator testField = new JTextFieldOperator(routingtable);

	    //type new value in the text field
	        //testField.clearText();
	         //testField.typeText("3");
                 testField.getText();

	        //for(int i=0; i<=32; i++){
	    	  // for(int i=0; i<=32; i++){
	    	  	//routingtable.g
                   //}
               // }
                routingtable.clickOnCell(0,0,1);

	} catch(Exception e) {
	    e.printStackTrace();
	    return(1);
	}
	return(0);
    }
    public static void main(String[] argv) {
	String[] params = {"FromRegToGUITest"};
	org.netbeans.jemmy.Test.main(params);
    }
}
