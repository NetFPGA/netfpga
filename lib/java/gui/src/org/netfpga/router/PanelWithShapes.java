/*
 * NFPDetailsPane.java
 *
 * Created on May 6, 2007, 11:21 PM
 *
 */

package org.netfpga.router;

import java.awt.Graphics;
import java.awt.Point;
import java.util.AbstractList;
import java.util.Iterator;
import java.util.Vector;

import javax.swing.JComponent;
import javax.swing.JPanel;

/**
 *
 * @author jnaous
 */
public class PanelWithShapes extends JPanel {

    /**
	 *
	 */
	private static final long serialVersionUID = 1L;
	private AbstractList<JComponent> startComps;
    private AbstractList<JComponent> endComps;

    /**
     * Creates a new instance of PanelWithShapes
     */
    public PanelWithShapes() {
        startComps = new Vector<JComponent>();
        endComps = new Vector<JComponent>();
    }

    public void paint(Graphics g){
        Iterator<JComponent> i,j;
        super.paint(g);
        i=startComps.iterator();
        j=endComps.iterator();
        while(i.hasNext() && j.hasNext()) {
            connectComponents(g, (JComponent) i.next(), (JComponent) j.next());
        }
    }

    public void setComponentsList(AbstractList<JComponent> startComps, AbstractList<JComponent> endComps) {
        this.startComps=startComps;
        this.endComps = endComps;
    }

    private void connectComponents(Graphics g, JComponent startComp, JComponent endComp) {
        Point start;
        Point end;

        start = startComp.getLocation();
        start.setLocation(start.getX()+startComp.getWidth()/2, start.getY()+startComp.getHeight());

        end = endComp.getLocation();
        end.setLocation(end.getX()+endComp.getWidth()/2, end.getY());

        org.netfpga.graphics.Arrow.paintArrow(g, start, end);
    }

}
