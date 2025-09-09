\m5_TLV_version 1d: tl-x.org
\SV
   `include "sqrt32.v";
   m4_include_lib(https://raw.githubusercontent.com/stevehoover/makerchip_examples/refs/heads/master/pythagoras_viz.tlv)
   
   m5_makerchip_module
\TLV
      
   // Stimulus
   |calc
      @0
         $valid = & $rand_valid[1:0];  // Valid with 1/4 probability
                                       // (& over two random bits).
   
   // DUT (Design Under Test)
   |calc
      ?$valid
         // Pythagoras's Theorem
         @0
            m4_rand($color, 23, 0)
            m4_rand($aa, 3, 0)
            m4_rand($bb, 3, 0)
         @0
            $aa_sq[7:0] = $aa ** 2;
            $bb_sq[7:0] = $bb ** 2;
         @2
            $cc_sq[8:0] = $aa_sq + $bb_sq;
         @3
            $cc[4:0] = sqrt($cc_sq);
         @4
            `BOGUS_USE($color $cc)

\SV
   endmodule