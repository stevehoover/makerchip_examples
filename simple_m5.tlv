\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   
   /A few simple uses of the M5 Macro/Text Processing Language.
   /These examples are not specific to TL-Verilog.
   
   macro(hello, ['['Hello, $1!']'])
   
   fn(greater_than, A, B, {
      ~if(m5_A > m5_B, [
         ~(['Yes, ']m5_A[' > ']m5_B)
      ])
   })
   
\SV
   /*----------
    * Now, we'll use these macros.
    * You can see the result in the NAV-TLV tab.
    *----------
    
    m5_hello(World)
    greater? m5_greater_than(m5_calc(4 ** 4), m5_calc(6 ** 3))
    */
      
/// Some code we don't care about here that passes in simulation.
\SV
   // Macro providing required top-level module definition, random
   // stimulus support, and Verilator config.
   m5_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   *passed = *cyc_cnt > 40;
\SV
   endmodule
