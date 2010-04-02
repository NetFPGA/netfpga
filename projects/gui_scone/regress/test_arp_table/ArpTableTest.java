
import org.netbeans.jemmy.*;
import org.netbeans.jemmy.operators.*;
import org.netbeans.jemmy.util.NameComponentChooser;
import org.netbeans.jemmy.drivers.*;
import org.netbeans.jemmy.drivers.DriverManager.*;

import org.netfpga.router.RouterMainFrame;

public class ArpTableTest implements Scenario {
    public int runIt(Object param) {
	try {

		new ClassReference("org.netfpga.router.RouterMainFrame").startApplication();
                JFrameOperator mainFrame = new JFrameOperator("Router Control Panel");
	        JInternalFrameOperator quickstart = new JInternalFrameOperator(mainFrame,"Router Quickstart");

                JTableOperator arptable = new JTableOperator(quickstart,new NameComponentChooser("arpTable"));

                arptable.changeCellObject(0,2,"00.00.00.00");
                arptable.changeCellObject(1,2,"00.00.00.01");
                arptable.changeCellObject(2,2,"00.00.00.02");
                arptable.changeCellObject(3,2,"00.00.00.03");
                arptable.changeCellObject(4,2,"00.00.00.04");
                arptable.changeCellObject(5,2,"00.00.00.05");
                arptable.changeCellObject(6,2,"00.00.00.06");
                arptable.changeCellObject(7,2,"00.00.00.07");
                arptable.changeCellObject(8,2,"00.00.00.08");
                arptable.changeCellObject(9,2,"00.00.00.09");
                arptable.changeCellObject(10,2,"00.00.00.10");
                arptable.changeCellObject(11,2,"00.00.00.11");
                arptable.changeCellObject(12,2,"00.00.00.12");
                arptable.changeCellObject(13,2,"00.00.00.13");
                arptable.changeCellObject(14,2,"00.00.00.14");
                arptable.changeCellObject(15,2,"00.00.00.15");
                arptable.changeCellObject(16,2,"00.00.00.16");
                arptable.changeCellObject(17,2,"00.00.00.17");
                arptable.changeCellObject(18,2,"00.00.00.18");
                arptable.changeCellObject(19,2,"00.00.00.19");
                arptable.changeCellObject(20,2,"00.00.00.20");
                arptable.changeCellObject(21,2,"00.00.00.21");
                arptable.changeCellObject(22,2,"00.00.00.22");
                arptable.changeCellObject(23,2,"00.00.00.23");
                arptable.changeCellObject(24,2,"00.00.00.24");
                arptable.changeCellObject(25,2,"00.00.00.25");
                arptable.changeCellObject(26,2,"00.00.00.26");
                arptable.changeCellObject(27,2,"00.00.00.27");
                arptable.changeCellObject(28,2,"00.00.00.28");
                arptable.changeCellObject(29,2,"00.00.00.29");
                arptable.changeCellObject(30,2,"00.00.00.30");
                arptable.changeCellObject(31,2,"00.00.00.31");


                arptable.changeCellObject(0,3,"aa:bb:cc:dd:ee:00");
                arptable.changeCellObject(1,3,"aa:bb:cc:dd:ee:01");
                arptable.changeCellObject(2,3,"aa:bb:cc:dd:ee:02");
                arptable.changeCellObject(3,3,"aa:bb:cc:dd:ee:03");
                arptable.changeCellObject(4,3,"aa:bb:cc:dd:ee:04");
                arptable.changeCellObject(5,3,"aa:bb:cc:dd:ee:05");
                arptable.changeCellObject(6,3,"aa:bb:cc:dd:ee:06");
                arptable.changeCellObject(7,3,"aa:bb:cc:dd:ee:07");
                arptable.changeCellObject(8,3,"aa:bb:cc:dd:ee:08");
                arptable.changeCellObject(9,3,"aa:bb:cc:dd:ee:09");
                arptable.changeCellObject(10,3,"aa:bb:cc:dd:ee:0a");
                arptable.changeCellObject(11,3,"aa:bb:cc:dd:ee:0b");
                arptable.changeCellObject(12,3,"aa:bb:cc:dd:ee:0c");
                arptable.changeCellObject(13,3,"aa:bb:cc:dd:ee:0d");
                arptable.changeCellObject(14,3,"aa:bb:cc:dd:ee:0e");
                arptable.changeCellObject(15,3,"aa:bb:cc:dd:ee:0f");
                arptable.changeCellObject(16,3,"aa:bb:cc:dd:ee:10");
                arptable.changeCellObject(17,3,"aa:bb:cc:dd:ee:11");
                arptable.changeCellObject(18,3,"aa:bb:cc:dd:ee:12");
                arptable.changeCellObject(19,3,"aa:bb:cc:dd:ee:13");
                arptable.changeCellObject(20,3,"aa:bb:cc:dd:ee:14");
                arptable.changeCellObject(21,3,"aa:bb:cc:dd:ee:15");
                arptable.changeCellObject(22,3,"aa:bb:cc:dd:ee:16");
                arptable.changeCellObject(23,3,"aa:bb:cc:dd:ee:17");
                arptable.changeCellObject(24,3,"aa:bb:cc:dd:ee:18");
                arptable.changeCellObject(25,3,"aa:bb:cc:dd:ee:19");
                arptable.changeCellObject(26,3,"aa:bb:cc:dd:ee:1a");
                arptable.changeCellObject(27,3,"aa:bb:cc:dd:ee:1b");
                arptable.changeCellObject(28,3,"aa:bb:cc:dd:ee:1c");
                arptable.changeCellObject(29,3,"aa:bb:cc:dd:ee:1d");
                arptable.changeCellObject(30,3,"aa:bb:cc:dd:ee:1e");
                arptable.changeCellObject(31,3,"aa:bb:cc:dd:ee:1f");
             		arptable.clickOnCell(0,0,1);


	} catch(Exception e) {
	    e.printStackTrace();
	    return(1);
	}
	return(0);
    }
    public static void main(String[] argv) {
	String[] params = {"ArpTableTest"};
	org.netbeans.jemmy.Test.main(params);
    }
}
