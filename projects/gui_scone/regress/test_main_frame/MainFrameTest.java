import org.netbeans.jemmy.*;
import org.netbeans.jemmy.operators.*;
import org.netbeans.jemmy.util.NameComponentChooser;
import org.netbeans.jemmy.drivers.*;
import org.netbeans.jemmy.drivers.DriverManager.*;
import org.netfpga.router.RouterMainFrame;

public class MainFrameTest implements Scenario {
    public int runIt(Object param) {
	try {

		new ClassReference("org.netfpga.router.RouterMainFrame").startApplication();
                JFrameOperator mainFrame = new JFrameOperator("Router Control Panel");
	        JInternalFrameOperator quickstart = new JInternalFrameOperator(mainFrame,"Router Quickstart");

	} catch(Exception e) {
	    e.printStackTrace();
	    return(1);
	}
	return(0);
    }
    public static void main(String[] argv) {
	String[] params = {"MainFrameTest"};
	org.netbeans.jemmy.Test.main(params);
    }
}
