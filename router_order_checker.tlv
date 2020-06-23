\m4_TLV_version 1d: tl-x.org
\SV
   // TL-Verilog docs: http://tl-x.org
   // Tutorials:       http://makerchip.com/tutorials
   m4_makerchip_module
      // To relax Verilator compiler checking:
      /* verilator lint_off UNOPTFLAT */
      /* verilator lint_off WIDTH */

\TLV
   m4_checks_on
   
   $reset = *reset;
   
   // [Ring uarch here.]

   // Checker
   m4_check(['
   /node[7:0]
      
      // Count transactions at the input for each destination.
      |in
         /trans
            ?$valid
               @1
                  /out_node[7:0]
                     $to_me = |in$reset || /trans$dest == #out_node;
                     ?$to_me
                        $Cnt[31:0] <= $reset ? 0 : $Cnt + 1;
      
      // Count transactions at the output for each source.
      |out
         /trans
            ?$valid
               @1
                  /in_node[7:0]
                     $from_me = |out$reset || /trans$src == #in_node;
                     ?$from_me
                        $OutCnt[31:0] <= |out$reset ? 0 : $OutCnt + 1;
                  
                  // Compare output transaction's count with expected count.
                  $error = $Cnt != /in_node[$src]$OutCnt;
   ']

   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

\SV
   endmodule
