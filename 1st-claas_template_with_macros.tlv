\m4_TLV_version 1d: tl-x.org
m4+definitions(['
// --------------------------------------------------------------------
//
// A library file for developing FPGA kernels for use with 1st CLaaS
// (https://github.com/stevehoover/1st-CLaaS)
//
// --------------------------------------------------------------------

m4_include_url(['https://raw.githubusercontent.com/stevehoover/tlv_flow_lib/7a2b37cc0ccd06bc66984c37e17ceb970fd6f339/pipeflow_lib.tlv'])


// The 1st CLaaS kernel module definition.
// This must be defined prior to any \TLV region, so \TLV macro syntax cannot be used - just raw m4.
// $1: kernel name
m4_define(['m4_kernel_module_def'], ['
   module $1['']_kernel #(
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
'])

// Makerchip module definition containing a testbench and instantiation of the custom kernel.
// This must be defined prior to any \TLV region, so \TLV macro syntax cannot be used - just raw m4.
// $1: kernel name
// $2: (opt) passed statement
// $3: (opt) failed statement
m4_define(['m4_makerchip_module_with_random_kernel_tb'], ['
   // Makerchip interfaces with this module, coded in SV.
   m4_makerchip_module
      // Instantiate a 1st CLaaS kernel with random inputs.
      logic [511:0] in_data = {2{RW_rand_vect[255:0]}};
      logic in_avail = ^ RW_rand_vect[7:0];
      logic out_ready = ^ RW_rand_vect[15:8];

      $1['']_kernel kernel (
            .*,  // clk, reset, and signals above
            .in_ready(),  // Ignore blocking (inputs are random anyway).
            .out_avail(),  // Outputs dangle.
            .out_data()    //  "
         );
      $2
      $3
   endmodule
m4_kernel_module_def($1)
'])
'])

// (Finally, now in TLV-land)

// The hookup of kernel module SV interface signals to TLV signals following flow library conventions.
\TLV tlv_wrapper(|_in, @_in, |_out, @_out, /_trans)
   m4_pushdef(['m4_trans_ind'], m4_ifelse(/_trans, [''], [''], ['   ']))
   // The input interface hookup.
   |_in
      @_in
         $reset = *reset;
         `BOGUS_USE($reset)
         $avail = *in_avail;
         *in_ready = ! $blocked;
         /trans
      m4_trans_ind   $data[C_DATA_WIDTH-1:0] = *in_data;
   // The output interface hookup.
   |_out
      @_out
         $blocked = ! *out_ready;
         *out_avail = $avail;
         /trans
      m4_trans_ind   *out_data = $data;
\SV



// -------------------------------------
// Main code.
// If this file is included as a library, below is the template to follow in your main file.
// You may also want your own version of the testbench with your own customized stimulus, though consider whether you have any way to prevent bad input data.

m4_makerchip_module_with_random_kernel_tb(my, ['assign passed = cyc_cnt > 20;'])
m4+definitions([''])  // A hack to reset line alignment to address the fact that the above macro is multi-line. 
\TLV
   
   // Connect SV inputs to TLV pipelines (m4+tlv_wrapper) and create a flow from in to out.
   // A few options provided.
   
   // Option 1) A default direct hookup from |in to |out.
   m4+tlv_wrapper(|in, @0, |out, @0, /trans)
   m4+rename_flow(/top, |in, @0, |out, @0, /trans)
   
   // Option 2) A 5-cycle backpressured pipeline from |in to |out (5 backpressured recirculation muxes).
   //m4+tlv_wrapper(|kernel0, @1, |kernel5, @1, /trans)
   //m4+bp_pipeline(/top, |kernel, 0, 5, /trans)
   
   // Option 3) ...
   
\SV
   endmodule
