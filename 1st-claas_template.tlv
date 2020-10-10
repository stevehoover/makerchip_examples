\m4_TLV_version 1d: tl-x.org
\SV

// --------------------------------------------------------------------
//
// A template for developing FPGA kernels for use with 1st CLaaS
// (https://github.com/stevehoover/1st-CLaaS)
//
// --------------------------------------------------------------------


m4_makerchip_module
   logic [511:0] in_data = {2{RW_rand_vect[255:0]}};
   logic in_avail = ^ RW_rand_vect[7:0];
   logic out_ready = ^ RW_rand_vect[15:8];
   
   XXX_kernel kernel (
         .clk(clk),
         .reset(reset),
         .in_ready(),  // Ignore blocking (inputs are random anyway).
         .in_avail(in_avail),
         .in_data(in_data),
         .out_ready(out_ready),  // Never block output.
         .out_avail(),  // Outputs dangle.
         .out_data()    //  "
      );
endmodule

module XXX_kernel #(
    parameter integer C_DATA_WIDTH = 512 // Data width of both input and output data
)
(
    input wire                       clk,
    input wire                       reset,
    
    output wire                      in_ready,
    input wire                       in_avail,
    input wire  [C_DATA_WIDTH-1:0]   in_data,
    
    input wire                       out_ready,
    output wire                      out_avail,
    output wire [C_DATA_WIDTH-1:0]   out_data
);
\TLV
   |inputs
      @0
         $avail = *in_avail;
         $data[C_DATA_WIDTH-1:0] = *in_data;
         *in_ready = /top|output<>0$ready;
   |output
      @0
         // Hook up inputs to outputs to implement a no-op kernel.
         // Delete this to add your kernel.
         $ANY = /top|inputs<>0$ANY;
         
         $ready = *out_ready;
         *out_avail = $avail;
         *out_data = $data;
\SV
endmodule
