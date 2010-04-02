package org.netfpga.router;
import javax.swing.JLabel;
import javax.swing.JSlider;
import javax.swing.event.ChangeEvent;
import javax.swing.event.ChangeListener;
import javax.swing.event.TableModelEvent;
import javax.swing.event.TableModelListener;

import org.netfpga.backend.NFDevice;
import org.netfpga.backend.RegTableModel;

/**
 * This class implements controlling the valuse of a slider
 * and the label that shows its value.
 * @author jnaous
 *
 */
public class RegSliderGroupControl {

    private RegTableModel regTableModel;
    private JSlider slider;
    private JLabel valueLabel;

    private ValueTransformer vt;

    /**
     * Create a new instance that controls the slider and its associated label with data from
     * the address specified
     * @param nf2
     * @param slider
     * @param valueLabel
     * @param address
     */
    public RegSliderGroupControl(NFDevice nf2, JSlider slider, JLabel valueLabel, long address){
        long addr[] = {address};
        this.regTableModel = new RegTableModel(nf2, addr);
        this.slider = slider;
        this.valueLabel = valueLabel;

        int val = (Integer)regTableModel.getValueAt(0, RegTableModel.VALUE_COL);
        slider.setValue(val);
        valueLabel.setText(""+val);
        vt = new DefaultValueTransformer(1, "");

        this.regTableModel.addTableModelListener(new TableModelListener() {
            public void tableChanged(TableModelEvent e) {
                updateFromRegs();
            }
        });

        slider.addChangeListener(new ChangeListener() {

            public void stateChanged(ChangeEvent evt) {
                JSlider source = (JSlider)evt.getSource();
                int value = (int)source.getValue();
                updateSlider(value);
                if(!source.getValueIsAdjusting()){
                    updateFromSlider(value);
                }
            }

        });
    }

    public void updateFromRegs() {
        if(!slider.getValueIsAdjusting()){
            int val = (Integer)regTableModel.getValueAt(0, RegTableModel.VALUE_COL);
            valueLabel.setText(vt.toLabelStringFromReg(val));
            slider.setValue(vt.toSliderValue(val));
        }
    }

    public void updateSlider(int val){
        valueLabel.setText(vt.toLabelStringFromComponent(val));
    }

    public void updateFromSlider(int value){
        //System.out.println("Setting register to "+vt.toRegisterValue(value)+" from slider");
        regTableModel.setValueAt(new Integer(vt.toRegisterValue(value)), 0, RegTableModel.VALUE_COL);
    }

    /**
     * @return the regTableModel
     */
    public RegTableModel getRegTableModel() {
        return regTableModel;
    }

    /**
     * @param regTableModel the regTableModel to set
     */
    public void setRegTableModel(RegTableModel regTableModel) {
        this.regTableModel = regTableModel;
    }

    /**
     * @return the slider
     */
    public JSlider getSlider() {
        return slider;
    }

    /**
     * @param slider the slider to set
     */
    public void setSlider(JSlider slider) {
        this.slider = slider;
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
     * @return the vt
     */
    public ValueTransformer getVt() {
        return vt;
    }

    /**
     * @param vt the vt to set
     */
    public void setVt(ValueTransformer vt) {
        this.vt = vt;
    }

}

class DefaultValueTransformer implements ValueTransformer{

    private int divider;
    private String units;

    public DefaultValueTransformer(int divider, String units){
        this.divider = divider;
        this.units = units;
    }

    public String toLabelStringFromComponent(int val) {
        return ""+val+" "+units;
    }

    public String toLabelStringFromReg(int val) {
        return ""+val/divider+" "+units;
    }

    public int toSliderValue(int val) {
        return val/divider;
    }

    public int toRegisterValue(int val) {
        return val*divider;
    }

    /**
     * @return the divider
     */
    public int getDivider() {
        return divider;
    }

    /**
     * @param divider the divider to set
     */
    public void setDivider(int divider) {
        this.divider = divider;
    }

    /**
     * @return the units
     */
    public String getUnits() {
        return units;
    }

    /**
     * @param units the units to set
     */
    public void setUnits(String units) {
        this.units = units;
    }
}
