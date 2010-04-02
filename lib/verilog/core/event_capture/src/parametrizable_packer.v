///////////////////////////////////////////////////////////////////////////////
// $Id: parametrizable_packer.v 1887 2007-06-19 21:33:32Z grg $
//
// Module: parametrizable_packer.v
// Project: event capture
// Description: Packs a set of entries, removing invalid entries
//
///////////////////////////////////////////////////////////////////////////////


module parametrizable_packer

    #(parameter NUM_ENTRIES = 9,
      parameter NUM_ENTRIES_SIZE = log2(NUM_ENTRIES),
      parameter ALL_ENTRIES_SIZE = NUM_ENTRIES*NUM_ENTRIES_SIZE)

      ( input  [NUM_ENTRIES-1:0]             valid_entries,
        output reg [ALL_ENTRIES_SIZE-1:0]    ordered_entries,
        output reg [log2(NUM_ENTRIES+1)-1:0] num_valid_entries,
        input clk,
        input reset);

   function integer log2;
      input integer number;
      begin
         log2=0;
         while(2**log2<number) begin
            log2=log2+1;
         end
      end
   endfunction // log2

   wire [log2(ALL_ENTRIES_SIZE)-1:0]  size_valid_before_entry[NUM_ENTRIES-1:0];
   wire [log2(NUM_ENTRIES+1)-1:0]     num_valid_at_entry[NUM_ENTRIES-1:0];
   wire [ALL_ENTRIES_SIZE-1:0]        shifted_entries [NUM_ENTRIES-1:0];
   wire [ALL_ENTRIES_SIZE-1:0]        ORed_entries [NUM_ENTRIES-1:0];
   wire [NUM_ENTRIES_SIZE-1:0]        entry_num [NUM_ENTRIES-1:0];

   generate
      genvar i;
      for(i=0; i<NUM_ENTRIES; i=i+1) begin: count_valid
         // get the number of valid entries before each entry so we know
         // how much it needs to be shifted by
         if(i==0)
           assign size_valid_before_entry[i] = 0;
         else
           assign size_valid_before_entry[i] = size_valid_before_entry[i-1] + (valid_entries[i-1] ? NUM_ENTRIES_SIZE : 0);

         if(i==0)
           assign num_valid_at_entry[i] = valid_entries[i];
         else
           assign num_valid_at_entry[i] = num_valid_at_entry[i-1] + valid_entries[i];

         // shift each entry's number by the number of zeros found (set invalid entries to zero)
         assign entry_num[i] = i;
         assign shifted_entries[i] = valid_entries[i] ? ({{(ALL_ENTRIES_SIZE-NUM_ENTRIES_SIZE){1'b0}}, entry_num[i]} << size_valid_before_entry[i]) : 0;

         // OR the shifted entries to get the final
         if (i==0)
           assign ORed_entries[i] = shifted_entries[i];
         else
           assign ORed_entries[i] = ORed_entries[i-1] | shifted_entries[i];

      end // block: count_zeros
   endgenerate

   always @(posedge clk) begin
      if(reset) begin
         ordered_entries <= 0;
         num_valid_entries <= 0;
      end
      else begin
         ordered_entries <= ORed_entries[NUM_ENTRIES-1];
         num_valid_entries <= num_valid_at_entry[NUM_ENTRIES-1];
      end
   end // always @ (posedge clk)

endmodule // parametrizable_packer
