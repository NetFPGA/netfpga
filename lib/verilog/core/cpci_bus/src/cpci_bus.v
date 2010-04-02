///////////////////////////////////////////////////////////////////////////////
// vim:set shiftwidth=3 softtabstop=3 expandtab:
// $Id: cpci_bus.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: cpci_bus.v
// Project: NetFPGA-1G
// Description: Virtex/CPCI bus interface.
//
//              Provides synchronization logic for CPCI register bus
//              including logic to insert/remove from the FIFOs.
//
//              Does not implement the register processing logic.
//
//              Note: bus_rd_data and bus_rd_data are NOT registers on input
//
///////////////////////////////////////////////////////////////////////////////

module cpci_bus
   #(
     parameter CPCI_NF2_ADDR_WIDTH = 27,
     parameter CPCI_NF2_DATA_WIDTH = 32
   )

   (
   // --- These are sigs to/from pins going to CPCI device
   input                                  cpci_rd_wr_L,
   input                                  cpci_req,
   input       [CPCI_NF2_ADDR_WIDTH-1:0]  cpci_addr,
   input       [CPCI_NF2_DATA_WIDTH-1:0]  cpci_wr_data,
   output reg  [CPCI_NF2_DATA_WIDTH-1:0]  cpci_rd_data,
   output reg                             cpci_data_tri_en,
   output reg                             cpci_wr_rdy,
   output reg                             cpci_rd_rdy,

   // --- Internal signals to/from register rd/wr logic
   //
   output                                 fifo_empty, // functions like a bus_req signal
   input                                  fifo_rd_en,
   output wire                            bus_rd_wr_L,
   output      [CPCI_NF2_ADDR_WIDTH-1:0]  bus_addr,
   output      [CPCI_NF2_DATA_WIDTH-1:0]  bus_wr_data,
   input       [CPCI_NF2_DATA_WIDTH-1:0]  bus_rd_data,
   input                                  bus_rd_vld,

   // --- Misc
   input                                  reset,
   input                                  pci_clk,
   input                                  core_clk
);

// --------------------------------------------------------
// Local registers/wires
// --------------------------------------------------------

   // all p2n_* signals are cpci signals registered
   reg p2n_rd_wr_L;
   reg p2n_req;
   reg p2n_req_d1;
   reg [CPCI_NF2_ADDR_WIDTH-1:0] p2n_addr;
   reg [CPCI_NF2_DATA_WIDTH-1:0] p2n_wr_data;
   reg p2n_wr_rdy;
   reg p2n_rd_rdy;

   reg cpci_wr_rdy_nxt;
   reg cpci_rd_rdy_nxt;

   wire p2n_almost_full;
   wire p2n_prog_full;

   wire [CPCI_NF2_DATA_WIDTH-1:0] n2p_rd_data;
   wire n2p_rd_rdy;

   // Read/write enables for the N2P fifo
   wire n2p_rd_en;
   wire n2p_wr_en;


   // Full/empty signals for n2p fifo
   wire n2p_fifo_empty;
   wire n2p_almost_full;

   wire [CPCI_NF2_DATA_WIDTH-1:0]  cpci_rd_data_nxt;


   // Clock-domain crossing signals
   // core -> pci domains
   reg reset_pci;
   reg reset_pci_sync;


/*
-----------------------------------------------------------------
- Reset clock domain crossing
-----------------------------------------------------------------
*/
   // Reset signal -- don't forget that this should
   // cross a clock domain!
   always @(posedge pci_clk)
   begin
      reset_pci_sync <= reset;
      reset_pci <= reset_pci_sync;
   end


// -----------------------------------------------------------------
// - Registering of all P2N signals
// -----------------------------------------------------------------

   /* We register everything coming in from the pins so that we have a
      timing-consistent view of the signals.

      Note: the wr_rdy and rd_rdy signals are recorded as we need to be able to
      identify whether the other would have recorded the operation as a success
      or failure
      */
   always @(posedge pci_clk) begin
      p2n_rd_wr_L <= cpci_rd_wr_L;
      p2n_req     <= cpci_req;
      p2n_addr    <= cpci_addr;
      p2n_wr_data <= cpci_wr_data;
      p2n_wr_rdy  <= cpci_wr_rdy;
      p2n_rd_rdy  <= cpci_rd_rdy;
   end

   always @(posedge pci_clk) begin
      p2n_req_d1     <= p2n_req;
   end

/*
-----------------------------------------------------------------
- CPCI -> Virtex requests
-----------------------------------------------------------------
*/

// All requests get funnelled into a 60-bit wide FIFO.
//       60-bits = 32 (data) + 27 (address) + 1 (rd_wr_L)
// Write in new addr/data when req and wr_rdy are high

// In the current design, the CPCI chip PCI clock period is 30ns, the register
// access interface between the CPCI chip and the NetFPGA chip has clock period 16ns,
// the NetFPGA chip internal clock period is 8ns.
// The pkt DMA TX is through the register access interface at this moment (to be
// changed to use the dedicated DMA interface later). So there are a few performance
// requirements:
// 1. When DMA TX is in progress, the register access interface will see register
//    write requests back to back on two consecutive clock cycles sometimes.
// 2. The reg_grp and the DMA module must finish acking to DMA TX register write request
//    in no more than 3 clock cycles (3 * 8ns = 24ns < 30ns) to prevent the p2n fifo
//    from filling up and overflowing. The DMA TX queue full signal to CPCI chip
//    is currently indicating whether the cpu queue is full, not whether the pci2net_fifo
//    is full.


   reg [1:0] p2n_state;
   reg [1:0] p2n_state_nxt;

   reg p2n_wr_en;
   wire p2n_full;

   localparam
	    P2N_IDLE = 2'h 0,
	    READING = 2'h 1,
	    P2N_RD_DONE = 2'h 2;

   // this state machine runs in the pci-clk domain
   always @* begin

      // set default values
      p2n_wr_en = 1'b0;
      p2n_state_nxt = p2n_state;

      if (reset_pci)
         p2n_state_nxt = P2N_IDLE;
      else begin
         case (p2n_state)

            P2N_IDLE: begin
               // Only process the request if the PCI2NET fifo has space for the
               // request
               if (p2n_req && !p2n_full) begin
                  p2n_wr_en = 1'b1;
                  if (p2n_rd_wr_L)
                     p2n_state_nxt = READING;

               end   // if
            end // P2N_IDLE

            READING: begin
               // Wait until the result is ready to return
               if (p2n_rd_rdy)
                  p2n_state_nxt = P2N_RD_DONE;
            end //READING

            P2N_RD_DONE:
               // Don't return to idle until the other side deasserts the request
               // signal
               if ( ! p2n_req )
                  p2n_state_nxt = P2N_IDLE;

         endcase
      end
   end // always @*

   always @(posedge pci_clk) begin
      p2n_state <= p2n_state_nxt;
   end   // always @(posedge clk)


/*
-----------------------------------------------------------------
- Virtex -> CPCI responses
-----------------------------------------------------------------
*/

/* the way that the code is written right now, we must ensure that the net2pci
   fifo never becomes almost full - or else read replies will be lost. This is
   to be compatible with the way unet_rdwr.v was written in NF2.0 - it asserts
   bus_rd_vld for only 1 cycle while providing the data. If the fifo is full,
   this data will not be read into the fifo, but the register / memory blocks
   could go on to process the next read, causing a loss. This should not be a
   problem in practice because we can only have 1 outstanding read at a time */


   // Data to be written to the N2P fifo
   assign n2p_rd_data = bus_rd_data;
   assign n2p_rd_rdy  = bus_rd_vld;

   // Generate the read/write enables for the N2P fifo
   assign n2p_rd_en = !n2p_fifo_empty;
   assign n2p_wr_en = (!n2p_almost_full) && n2p_rd_rdy;


/*
-----------------------------------------------------------------
- Generation of signals sent back to CPCI
-----------------------------------------------------------------
*/

   // Generate the cpci_rd_rdy, cpci_rd_data, cpci_data_tri_en and
   // cpci_wr_rdy signals
   always @*
      if (reset_pci) begin
         cpci_wr_rdy_nxt = 1'b0;
         cpci_rd_rdy_nxt = 1'b0;
      end
      else begin
         cpci_wr_rdy_nxt = !p2n_prog_full;
         cpci_rd_rdy_nxt = !n2p_fifo_empty;
      end

   always @(posedge pci_clk) begin
      cpci_rd_rdy <= cpci_rd_rdy_nxt;
      cpci_data_tri_en <= cpci_rd_rdy_nxt;
      cpci_rd_data <= cpci_rd_data_nxt;
      cpci_wr_rdy <= cpci_wr_rdy_nxt;
   end // always @ (posedge pci_clk)



/*
-----------------------------------------------------------------
- Clock domain crossing FIFOs
-----------------------------------------------------------------
*/

   // Fifo to cross from the PCI clock domain to the core domain
   pci2net_16x60 pci2net_fifo (
      .din ({p2n_rd_wr_L, p2n_addr, p2n_wr_data}),
      .rd_clk (core_clk),
      .rd_en (fifo_rd_en),
      .rst (reset),
      .wr_clk (pci_clk),
      .wr_en (p2n_wr_en),
      .almost_full (p2n_almost_full),
      .prog_full (p2n_prog_full),
      .dout ({bus_rd_wr_L, bus_addr, bus_wr_data}),
      .empty (fifo_empty),
      .full (p2n_full)
   );

   // Cross from core domain to PCI clock domain
   //
   // Note: this FIFO is using first word fall through so that the data
   // appears at the output on the same clock cycle as empty goes low.
   //
   // This property is exploited to create a registered version of this signal
   // that can be pushed into the IOB.
   net2pci_16x32 net2pci_fifo (
      .din (n2p_rd_data),
      .rd_clk (pci_clk),
      .rd_en (n2p_rd_en),
      .rst (reset),
      .wr_clk (core_clk),
      .wr_en (n2p_wr_en),
      .almost_full (n2p_almost_full),
      .dout (cpci_rd_data_nxt),
      .empty (n2p_fifo_empty),
      .full ()
   );


/*
-----------------------------------------------------------------
- Debugging logic
-----------------------------------------------------------------
*/

// synthesis translate_off

   reg fifo_rd_en_d1;   // indicates if we're currently processing a request
   reg read_active;

   always @(posedge core_clk)
   begin
      if (reset || bus_rd_vld)
         read_active <= 1'b0;
      else if (fifo_rd_en_d1 && bus_rd_wr_L)   // read came through on fifo
         read_active <= 1'b1;
   end

   // Generate the bus request signal to indicate to nf2_reg_grp that
   // a request is pending
   always @(posedge core_clk)
      fifo_rd_en_d1 <= fifo_rd_en;

   always @(posedge core_clk)
   begin
      if (read_active === 1'b0 && bus_rd_vld)
         $display($time, " Error: invalid attempt to write to N2P FIFO in %m. Data: 0x%08x", bus_rd_data);
   end

// synthesis translate_on

endmodule // cpci_bus
