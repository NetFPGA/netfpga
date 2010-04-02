/**
 *
 */
package org.netfpga.graphics;

import java.awt.Graphics;
import java.awt.Graphics2D;
import java.awt.Point;
import java.awt.Polygon;
import java.awt.Shape;
import java.awt.geom.AffineTransform;

/**
 * @author Jad Naous
 *
 */
public class Arrow {

	public static void paintArrow(Graphics g, int x0, int y0, int x1, int y1){
		double dx = x1-x0;
		double dy = y1-y0;

		int length = (int) Math.sqrt(Math.pow(Math.abs(dx),2) +
					Math.pow(Math.abs(dy),2));

		Polygon poly = new Polygon();
		poly.addPoint((int) x0,(int) y0);
		poly.addPoint((int) x0+ length,(int) y0);
		poly.addPoint((int) x0+ length-10,(int) y0-5);
		poly.addPoint((int) x0+ length,(int) y0);
		poly.addPoint((int) x0+ length-10,(int) y0+5);
		poly.addPoint((int) x0+ length,(int) y0);

		double angle = Math.atan2(dy, dx);

		AffineTransform tx = AffineTransform.getRotateInstance(angle, x0, y0);

		Graphics2D g2d = (Graphics2D) g;
		g2d.draw(tx.createTransformedShape((Shape)poly));
	}

	public static void paintArrow(Graphics g, Point start, Point end){
		paintArrow(g, start.x, start.y, end.x, end.y);
	}
}
