/***************************************
 * $Id$
 *
 * Module: arbitrator.v
 * Author: Jad Naous
 * Project: utils
 * Description: Implements a generic round-robin arbitrator
 *
 * WARNING: currently only works if NUM_CLIENTS is
 *          a multiple of 2.
 *
 * Change history:
 *
 ***************************************/
`timescale 1ns/1ps
module arbitrator
  #(parameter SERV_DATA_WIDTH  = 72, /* width of data sent to server */
    parameter RSLT_DATA_WIDTH  = SERV_DATA_WIDTH, /* width of result */
    parameter SUPP_DATA_WIDTH  = 19,  /* e.g. addr or key */
    parameter FIFO_DEPTH_BITS  = 1,   /* set this to latency*BW */
    parameter USE_RESULTS      = 1,   /* use client vld and client_rslt_data */
    parameter NUM_CLIENTS      = 8)
    (input      [0:SUPP_DATA_WIDTH*NUM_CLIENTS-1] client_supp_data,
     input      [0:SERV_DATA_WIDTH*NUM_CLIENTS-1] client_serv_data,
     input      [0:NUM_CLIENTS-1]                 client_req,
     output reg [0:NUM_CLIENTS-1]                 client_ack,
     output reg [0:NUM_CLIENTS-1]                 client_vld,
     output     [0:RSLT_DATA_WIDTH-1]             client_rslt_data,

     output     [0:SUPP_DATA_WIDTH-1]             server_supp_data,
     output     [0:SERV_DATA_WIDTH-1]             server_serv_data,
     output                                       server_req,
     input                                        server_ack,
     input                                        server_vld,
     input      [0:RSLT_DATA_WIDTH-1]             server_rslt_data,

     input                                        clk,
     input                                        reset);

   function integer log2;
      input integer number;
      begin
	 log2 = 0;
         while(2**log2<number) begin
            log2=log2+1;
	 end
      end
   endfunction // log2

   //------------- Internal Parameters ---------------
   localparam NUM_CLIENTS_SIZE = log2(NUM_CLIENTS);

   //--------------- Regs/Wires ----------------------
   wire [0:SUPP_DATA_WIDTH-1]  client_supp_data_words[0:NUM_CLIENTS-1];
   wire [0:SERV_DATA_WIDTH-1]  client_serv_data_words[0:NUM_CLIENTS-1];

   reg [NUM_CLIENTS_SIZE-1:0]  selected_client;
   wire [NUM_CLIENTS_SIZE-1:0] stored_client;
   wire [0:NUM_CLIENTS-1]      rotated_client_reqs;
   wire [NUM_CLIENTS_SIZE-1:0] rotated_next_client;
   wire [NUM_CLIENTS_SIZE-1:0] next_client;

   //------------------ Logic ------------------------
   /* make words out of input */
   generate
      genvar i;
      for(i=0; i<NUM_CLIENTS; i=i+1) begin:gen_words
         assign client_supp_data_words[i] = client_supp_data[i*SUPP_DATA_WIDTH +: SUPP_DATA_WIDTH];
         assign client_serv_data_words[i] = client_serv_data[i*SERV_DATA_WIDTH +: SERV_DATA_WIDTH];
      end
   endgenerate

   /* connect server to selected client */
   assign server_supp_data = client_supp_data_words[selected_client];
   assign server_serv_data = client_serv_data_words[selected_client];
   assign server_req       = client_req[selected_client];

   /* connect client to server results */
   assign client_rslt_data = server_rslt_data;
   always @(*) begin
      client_ack = 0;
      client_vld = 0;
      client_ack[selected_client] = server_ack;
      client_vld[stored_client] = server_vld;
   end

   /* rotate the client requests so the current
    * client is at the bottom of the priority list */
   rotate #(.UNIT_SIZE(1), .NUM_UNITS(NUM_CLIENTS), .SHIFT_LEFT(1))
     rotate(.din(client_req), .rotation(selected_client+1'b1), .dout(rotated_client_reqs));

   /* select a next client using the rotated list */
   priority_encoder #(.OUTPUT_WIDTH (NUM_CLIENTS_SIZE), .RIGHT_TO_LEFT_PRIORITY(0))
     priority_encoder (.unencoded_input (rotated_client_reqs),
                       .encoded_output (rotated_next_client),
                       .valid (next_client_vld));

   /* unrotate the next client */
   assign next_client = (next_client_vld
                         ? rotated_next_client + selected_client + 1'b1
                         : selected_client);

   /* select a client. This is done by servicing one request for each
    * client. When an ack arrives, go to the next client if one has
    * a request set. */
   always @(posedge clk) begin
      if(reset) begin
         selected_client <= 0;
      end
      else begin
         /* check for other clients: if this guy was just serviced
          * or this guy is not requesting anything */
         if(server_ack || !client_req[selected_client]) begin
            selected_client <= next_client;
         end
      end // else: !if(reset)
   end // always @ (posedge clk)

   generate
      if(USE_RESULTS) begin
         /* store clients we have serviced */
         fallthrough_small_fifo
           #(.WIDTH(NUM_CLIENTS_SIZE),
             .MAX_DEPTH_BITS(FIFO_DEPTH_BITS))
             service_fifo
               (.dout         (stored_client),
                .full         (service_fifo_full),
                .nearly_full  (service_fifo_nearly_full),
                .prog_full    (),
                .empty        (service_fifo_empty),
                .din          (selected_client),
                .wr_en        (server_ack),
                .rd_en        (server_vld),
                .reset        (reset),
                .clk          (clk));
      end // if (USE_RESULTS)
   endgenerate

endmodule // arbitrator
