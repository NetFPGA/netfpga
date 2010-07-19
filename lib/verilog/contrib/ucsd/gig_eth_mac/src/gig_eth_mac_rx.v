///////////////////////////////////////////////////////////////////////////////
//
// Gigabit Ethernet MAC: RX logic
//
// Author: Erik Rubow
//
///////////////////////////////////////////////////////////////////////////////

module gig_eth_mac_rx
#(
  parameter MAX_FRAME_SIZE_STANDARD = 1522,
  parameter MAX_FRAME_SIZE_JUMBO = 9022
)
(
  // Reset, clocks
  input  wire reset,    // asynchronous
  input  wire rx_clk,

  // Configuration
  input  wire conf_rx_en,
  input  wire conf_rx_no_chk_crc,
  input  wire conf_rx_jumbo_en,

  // RX Client Interface
  output wire [7:0] mac_rx_data,
  output wire mac_rx_dvld,
  output wire mac_rx_goodframe,
  output wire mac_rx_badframe,

  // RX GMII Interface
  input  wire [7:0] gmii_rxd,
  input  wire gmii_rxdv,
  input  wire gmii_rxer
);

  //-------- Localparams --------//
  localparam RX_READY        = 3'd0;
  localparam RX_FRAME        = 3'd1;
  localparam RX_CHECK_CRC    = 3'd2;
  localparam RX_GOOD         = 3'd3;
  localparam RX_BAD          = 3'd4;
  localparam RX_ABORT        = 3'd5;
  localparam RX_WAIT_FOR_END = 3'd6;

  //-------- Wires/regs --------//
  reg  [7:0] gmii_rxd_in_reg;
  reg  gmii_rxdv_in_reg;
  reg  gmii_rxer_in_reg;

  reg  conf_rx_en_reg;
  reg  conf_rx_en_reg_next;
  reg  conf_rx_no_chk_crc_reg;
  reg  conf_rx_no_chk_crc_reg_next;
  reg  conf_rx_jumbo_en_reg;
  reg  conf_rx_jumbo_en_reg_next;

  reg  [2:0] rx_state;
  reg  [2:0] rx_state_next;
  reg  [13:0] rx_counter;
  reg  [13:0] rx_counter_next;
  wire [13:0] max_frame_length;
  reg  [6*8-1:0] rx_delay_data;
  wire [6*8-1:0] rx_delay_data_next;
  reg  [5:0] rx_delay_dvld;
  wire [5:0] rx_delay_dvld_next;
  reg  rx_goodframe_out;
  wire rx_goodframe_out_next;
  reg  rx_badframe_out;
  wire rx_badframe_out_next;

  wire rx_crc_init;
  wire rx_crc_en;
  wire rx_crc_chk_en;
  wire rx_crc_err;

  //-------- Instantiated modules --------//
  CRC_chk rx_crc_chk (
    .Reset       (reset),
    .Clk         (rx_clk),
    .CRC_data    (gmii_rxd_in_reg),
    .CRC_init    (rx_crc_init),
    .CRC_en      (rx_crc_en),
    .CRC_chk_en  (rx_crc_chk_en),
    .CRC_err     (rx_crc_err)
  );

  //-------- Combinational logic --------//

  // outputs
  //
  // Note: mac_rx_data is just gmii_rxd with a 7-cycle delay. The purpose of the
  // delay is to let us determine when the CRC starts (to deassert mac_rx_dvld).
  // Either mac_rx_goodframe or mac_rx_badframe is asserted one cycle after mac_rx_dvld
  // is deasserted.
  assign mac_rx_data = rx_delay_data[7:0];
  assign mac_rx_dvld = rx_delay_dvld[0];
  assign mac_rx_goodframe = rx_goodframe_out;
  assign mac_rx_badframe = rx_badframe_out;

  assign rx_delay_data_next[1*8-1:0*8] = rx_delay_data[2*8-1:1*8];
  assign rx_delay_data_next[2*8-1:1*8] = rx_delay_data[3*8-1:2*8];
  assign rx_delay_data_next[3*8-1:2*8] = rx_delay_data[4*8-1:3*8];
  assign rx_delay_data_next[4*8-1:3*8] = rx_delay_data[5*8-1:4*8];
  assign rx_delay_data_next[5*8-1:4*8] = rx_delay_data[6*8-1:5*8];
  assign rx_delay_data_next[6*8-1:5*8] = gmii_rxd_in_reg;

  assign rx_delay_dvld_next[0] = (!conf_rx_no_chk_crc && rx_state != RX_FRAME) ? 0 : rx_delay_dvld[1];
  assign rx_delay_dvld_next[1] = rx_delay_dvld[2];
  assign rx_delay_dvld_next[2] = rx_delay_dvld[3];
  assign rx_delay_dvld_next[3] = rx_delay_dvld[4];
  assign rx_delay_dvld_next[4] = rx_delay_dvld[5];
  assign rx_delay_dvld_next[5] = rx_state == RX_FRAME && rx_state_next == RX_FRAME;

  assign rx_goodframe_out_next = rx_state == RX_GOOD && rx_state_next != RX_GOOD;

  assign rx_badframe_out_next = (rx_state == RX_BAD && rx_state_next != RX_BAD) || (rx_state == RX_ABORT && rx_state_next != RX_ABORT);

  // signals for crc module
  assign rx_crc_init = rx_state == RX_READY && rx_state_next == RX_FRAME;
  assign rx_crc_en = rx_state == RX_FRAME && gmii_rxdv_in_reg;
  assign rx_crc_chk_en = rx_state == RX_CHECK_CRC;

  // update configuration between packets
  always @* begin
    if (rx_state_next == RX_READY) begin
      conf_rx_en_reg_next = conf_rx_en;
      conf_rx_no_chk_crc_reg_next = conf_rx_no_chk_crc;
      conf_rx_jumbo_en_reg_next = conf_rx_jumbo_en;
    end
    else begin
      conf_rx_en_reg_next = conf_rx_en_reg;
      conf_rx_no_chk_crc_reg_next = conf_rx_no_chk_crc_reg;
      conf_rx_jumbo_en_reg_next = conf_rx_jumbo_en_reg;
    end
  end

  assign max_frame_length = (conf_rx_jumbo_en_reg ? MAX_FRAME_SIZE_JUMBO : MAX_FRAME_SIZE_STANDARD );

  // count cycles in each state
  always @* begin
    if (rx_state != rx_state_next)
      rx_counter_next = 1;
    else
      rx_counter_next = rx_counter + 1;
  end

  // state machine
  always @* begin
    if (!conf_rx_en_reg) begin
      rx_state_next = RX_READY;
    end
    else begin
      rx_state_next = rx_state;
      case (rx_state)
        RX_READY: begin
          if (gmii_rxdv_in_reg && !gmii_rxer_in_reg && gmii_rxd_in_reg == 8'b11010101)
            rx_state_next = RX_FRAME;
        end
        RX_FRAME: begin
          if (!gmii_rxdv_in_reg) begin
            if (conf_rx_no_chk_crc_reg)
              rx_state_next = RX_GOOD;
            else
              rx_state_next = RX_CHECK_CRC;
          end
          else if (gmii_rxer_in_reg)
            rx_state_next = RX_BAD;
          else if (rx_counter > max_frame_length)
            rx_state_next = RX_ABORT;
        end
        RX_CHECK_CRC: begin
          if (rx_crc_err)
            rx_state_next = RX_BAD;
          else
            rx_state_next = RX_GOOD;
        end
        // RX_GOOD, RX_BAD, and RX_ABORT remain in that state until
        // mac_rx_dvld is deasserted. This is really just so that the
        // goodframe and badframe signals always occur after the falling
        // edge of mac_rx_dvld
        RX_GOOD: begin
          if (!mac_rx_dvld)
            rx_state_next = RX_READY;
        end
        RX_BAD: begin
          if (!mac_rx_dvld)
            rx_state_next = RX_READY;
        end
        // RX_ABORT differs from RX_BAD in that gmii_rxdv might stil be high,
        // so we need to wait for the bad packet to finish
        RX_ABORT: begin
          if (!mac_rx_dvld) begin
            if (!gmii_rxdv_in_reg)
              rx_state_next = RX_READY;
            else
              rx_state_next = RX_WAIT_FOR_END;
          end
        end
        RX_WAIT_FOR_END: begin
          if (!gmii_rxdv_in_reg)
            rx_state_next = RX_READY;
        end
      endcase
    end
  end

  //-------- Sequential logic --------//
  always @(posedge rx_clk or posedge reset) begin
    if (reset) begin
      gmii_rxd_in_reg          <= 8'h00;
      gmii_rxdv_in_reg         <= 1'b0;
      gmii_rxer_in_reg         <= 1'b0;
      conf_rx_en_reg           <= 1'b0;
      conf_rx_no_chk_crc_reg   <= 1'b1;
      conf_rx_jumbo_en_reg     <= 1'b0;
      rx_state                 <= RX_READY;
      rx_counter               <= 0;
      rx_delay_data            <= 48'd0;
      rx_delay_dvld            <= 6'd0;
      rx_goodframe_out         <= 1'b0;
      rx_badframe_out          <= 1'b0;
    end
    else begin
      gmii_rxd_in_reg          <= gmii_rxd;
      gmii_rxdv_in_reg         <= gmii_rxdv;
      gmii_rxer_in_reg         <= gmii_rxer;
      conf_rx_en_reg           <= conf_rx_en_reg_next;
      conf_rx_no_chk_crc_reg   <= conf_rx_no_chk_crc_reg_next;
      conf_rx_jumbo_en_reg     <= conf_rx_jumbo_en_reg_next;
      rx_state                 <= rx_state_next;
      rx_counter               <= rx_counter_next;
      rx_delay_data            <= rx_delay_data_next;
      rx_delay_dvld            <= rx_delay_dvld_next;
      rx_goodframe_out         <= rx_goodframe_out_next;
      rx_badframe_out          <= rx_badframe_out_next;
    end
  end

endmodule

