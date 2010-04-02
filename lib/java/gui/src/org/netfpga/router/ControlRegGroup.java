package org.netfpga.router;
import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

import javax.swing.AbstractButton;
import javax.swing.event.TableModelEvent;
import javax.swing.event.TableModelListener;

import org.netfpga.backend.NFDevice;
import org.netfpga.backend.RegTableModel;

/**
 * Control checkboxes and buttons from a single register.
 * @author jnaous
 *
 */
public class ControlRegGroup implements ActionListener{

    private AbstractButton[] buttons;
    private RegTableModel regTableModel;
    private boolean[] invert;

    public ControlRegGroup(NFDevice nf2, long address, AbstractButton[] buttons, boolean[] invert){

        long[] addr = {address};
        regTableModel = new RegTableModel(nf2, addr);
        regTableModel.addTableModelListener(new TableModelListener() {

            public void tableChanged(TableModelEvent e) {
                updateFromRegs();
            }

        });

        this.buttons = new AbstractButton[buttons.length];
        this.invert= new boolean[invert.length];
        for(int i=0; i<buttons.length; i++){
            if(buttons[i]!=null){
                this.buttons[i] = buttons[i];
                this.invert = invert;
                ((ControlButtonIface)buttons[i]).setIndex(i);
                buttons[i].addActionListener(this);
            }
        }

        updateFromRegs();
    }

    public void updateFromButtons(int index, boolean isCheckBox){
        int val = regTableModel.getRegisterAt(0).getValue();
        if(isCheckBox){
//            System.out.println("Checkbox "+index+" being updated");
            if( (buttons[index].isSelected() && !invert[index]) ||
                    (!buttons[index].isSelected() && invert[index]) ){
                val = val  | (1<<index);
            } else {
                val = val  & ~(1<<index);
            }
            regTableModel.setValueAt(new Integer(val), 0, RegTableModel.VALUE_COL);
        } else {
//            System.out.println("Button "+index+" being updated");
            if(!invert[index]){
                val = val  | (1<<index);
            } else {
                val = val  & ~(1<<index);
            }
            regTableModel.setValueAt(new Integer(val), 0, RegTableModel.VALUE_COL);

            if(invert[index]){
                val = val  | (1<<index);
            } else {
                val = val  & ~(1<<index);
            }
            regTableModel.setValueAt(new Integer(val), 0, RegTableModel.VALUE_COL);
        }
    }

    public void updateFromRegs(){
        int val = (Integer) regTableModel.getValueAt(0, RegTableModel.VALUE_COL);
//        System.out.println("Read "+(val));
        for(int i=0; i<buttons.length; i++){
            if(buttons[i] != null){
                if((val & 1) == 1){
                    if(invert[i]) {
                        buttons[i].setSelected(false);
                    } else {
                        buttons[i].setSelected(true);
                    }
                } else {
                    if(invert[i]) {
                        buttons[i].setSelected(true);
                    } else {
                        buttons[i].setSelected(false);
                    }
                }
            }
            val >>= 1;
        }
    }

    public void actionPerformed(ActionEvent e) {
        AbstractButton button = (AbstractButton)e.getSource();
        int index = ((ControlButtonIface)button).getIndex();
        if(button.getClass().equals(ControlButton.class)){
            updateFromButtons(index, false);
//            System.out.println("Button!");
        } else {
            updateFromButtons(index, true);
//            System.out.println("Check!");
        }
    }
}
