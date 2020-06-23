\m4_TLV_version 1d: tl-x.org
\SV

   // The NAND Challenge!

   m4_makerchip_module

\TLV nand($_out, $_in1, $_in2)
   $_out = !($_in1 && $_in2);

\TLV not($_out, $_in)
   m4+nand($_out, $_in, $_in)

\TLV and($_out, $_in1, $_in2)
   /and
      m4+nand($nand, $_in1, $_in2)
      m4+not($_out, /and$nand)
   $_out = /and$_out;

\TLV or($_out, $_in1, $_in2)
   /or
      m4+not($not1, $_in1)
      /not2
         m4+not($not2, $_in2)
      m4+nand($_out, /or$not1, /or/not2$not2)
   $_out = /or$_out;

\TLV nor($_out, $_in1, $_in2)
   /nor
      m4+or($or, $_in1, $_in2)
      m4+not($_out, /nor$or)
   $_out = /nor$_out;

\TLV xor($_out, $_in1, $_in2)
   /xor
      m4+or($or, $_in1, $_in2)
      m4+nand($nand, $_in1, $_in2)
      m4+and($_out, /xor$or, /xor$nand)
   $_out = /xor$_out;

\TLV mux($_out, $_sel, $_in1, $_in2)
   /mux
      m4+not($not_sel, $_sel)
      m4+and($sel1, /mux$not_sel, $_in1)
      /and2
         m4+and($sel2, $_sel, $_in2)
      m4+or($_out, /mux$sel1, /mux/and2$sel2)
   $_out = /mux$_out;

\TLV
   $reset = *reset;

   m4+or($or_test, /top$in1, /top$in2)
   m4+and($and_test, /top$in1, /top$in2)
   m4+xor($xor_test, /top$in1, /top$in2)
   m4+mux($mux_test, /top$sel, /top$in1, /top$in2)

   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
\SV
   endmodule
