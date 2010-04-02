///////////////////////////////////////////////////////////////////////////////
// $Id: cpci_clock_checker.v 6061 2010-04-01 20:53:23Z grg $
//
// Module: cpci_clock_checker.v
// Project: CPCI
// Description:
//              Checks that the core clock and PCI clock are
//              operating at about the right frequencies.
//              We have seen funny clock behavior on Rev 1 NetFPGA-1G, so this
//              is an attempt to investigate further.
//
//              Limitation: it only checks relative frequencies, not
//              absolute.
//
///////////////////////////////////////////////////////////////////////////////


// synthesis translate_off


/************************************
* This is the testbench - the actual RTL is further down.
* Uncomment this to simulate just this file.

module tb ();

   reg reset, n_clk, p_clk;

   cpci_clock_checker cc (
      .error (error),
      .clk_chk_p_max   ('d3333333),
      .clk_chk_n_exp   ('d6250000),
      .reset (reset),
      .shift_amount(4'd3),
      .p_clk (p_clk),
      .n_clk (n_clk)
   );

   always #15 p_clk = ~p_clk;
   always #8 n_clk = ~n_clk;

   initial begin
      n_clk = 0;
      p_clk = 0;
      reset  =1;

      #200 reset = 0;

      // $monitor("st: %d ", cc.state);

      wait (cc.state == 3); #100;

      $display("%t Error is %d. n_count is %d p_count is %d",
         $time, error, cc.n_count, cc.p_count);
      if (error == 0) $display("(That was good - error should be 0");
      else begin $display ("BAD - error should be 0"); $finish; end

      wait (cc.state == 0);
      #100000 begin  end
      force n_clk  = 0;
      $display($time,"Stopping n_clk");
      #1600000 release n_clk;

      wait (cc.state == 3); #100 begin end

      $display("%t Error is %d. n_count is %d p_count is %d",
         $time, error, cc.n_count, cc.p_count);
      if (error == 1) $display("(That was good - error should be 1");
      else begin $display ("BAD - error should be 1"); $finish; end


      #100 $finish;
   end


//   always @(posedge p_clk)
//      if (($time > 1000) && (cc.p_count[19:0] == 'h0)) $display($time, "p_cnt: %d", cc.p_count);


endmodule

**********************************************************/

// synthesis translate_on

module cpci_clock_checker

   (

    output error,
    output reg [31:0] n_clk_count,
    input [31:0] clk_chk_p_max,    // MAX value for PCI counter
    input [31:0] clk_chk_n_exp,    // Expected value of n_clk counter.
    input [3:0] shift_amount, // see below
    input reset,  // pci clock reset
    input p_clk,   //nominally 33MHz
    input n_clk    //nominally 62.5 MHz

    );

   // shift_amount indicates how much to left shift (increase)
   // the allowable deviation. Range is 0-15. So a bigger value
   // on shift_amount means that we can have more deviation without
   // signaling an error.


   // create the min and max values. Use flops to make timing easier.
   reg [31:0] min_exp_count;
   reg [31:0] max_exp_count;

   always @(posedge p_clk) begin
      min_exp_count <= clk_chk_n_exp - (1<<shift_amount);
      max_exp_count <= clk_chk_n_exp + (1<<shift_amount);
   end

   reg [31:0] p_count;
   reg [31:0] n_count;

   parameter START = 0, COUNT = 1, WAIT1 = 2, CHECK = 3;

   reg [1:0] state, state_nxt;
   reg go, go_nxt, stop, stop_nxt;
   reg saw_error;

   always @* begin

      //defaults
      state_nxt = state;
      saw_error = 0;
      go_nxt = 0;
      stop_nxt = 0;

      case (state)

         START: begin
            go_nxt = 1;
            state_nxt = COUNT;
         end

         COUNT: begin  //wait for count to end
            if (p_count == clk_chk_p_max) begin
               stop_nxt = 1;
               state_nxt = WAIT1;
            end
         end

         WAIT1: begin   // Just wait a bit for asynchrony to resolve.
            if (p_count == (clk_chk_p_max + 2))
               state_nxt = CHECK;
         end

         CHECK: begin

            if ((n_count < min_exp_count) ||
                (n_count > max_exp_count))
              saw_error = 1;

            state_nxt = START;
          end

          default: state_nxt = START;

       endcase
    end

    //=============================================================
    //

   // drive error signal for a while whenever we see saw_error - this
   // drives the LED so needs to be on for a while.

   reg [15:0] error_cnt;

   always @(posedge p_clk)
     if (reset)
       error_cnt <= 0;
     else
       if (saw_error) error_cnt <= 10000;
       else if (error_cnt > 0)
	 error_cnt <= error_cnt - 1;

   assign error = (error_cnt != 0);



    always @(posedge p_clk) begin
       go <= go_nxt;
       stop <= stop_nxt;
       state <= reset ? START : state_nxt;
    end

    always @(posedge p_clk)
       if (reset || go) p_count <= 0;
       else p_count <= p_count + 1;


   //=================================================================
   // N clock (faster than PCI clock)

   reg go_n, reset_n, stop_n, run_n;

   always @(posedge n_clk) begin
      go_n <= go;
      reset_n <= reset;
      stop_n <= stop;
   end

   always @(posedge n_clk)
      if (reset_n || stop_n) run_n <= 0;
      else if (go_n) run_n <= 1;

   always @(posedge n_clk)
      if (reset_n || go_n) n_count <= 0;
      else if (run_n) n_count <= n_count + 1;

   // N-clk_count preserves the last value of n_count
   always @(posedge n_clk)
      if (reset_n ) n_clk_count <= 'h0;
      else if (stop_n) n_clk_count <= n_count;

endmodule

