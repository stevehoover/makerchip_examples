\m4_TLV_version 1d: tl-x.org
\SV
   // Experimenting with new m4 stuff.
   
   m4_include_lib(['https://raw.githubusercontent.com/TL-X-org/tlv_lib/3543cfd9d7ef9ae3b1e5750614583959a672084d/fundamentals_lib.tlv'])

   //m4_define(['M4_FMT_NO_SOURCE'], ['1'])
   m4_def(['ok'], ['OK'])
   m4_func(fool, ['
      m4_push(['ok'], ['UGH'])
      m4_output(m4_ok ['hi'])
      m4_pop(['ok'])
      m4_output(m4_ok ['hi'])
   '])
   /* m4_fool() */
   // =========================================
   // Welcome!  Try the tutorials via the menu.
   // =========================================
   /*
   m4_do(['m4_define(['m4_hi'], ['Hello!'])'])
   m4_hi()
   m4_func(['test'], ['hi
     I'm a test
     m4_output(['My output'])
     
     m4_output(['m4_nothing()'])
     okay
   '])
   m4_test()
   */
   // Default Makerchip TL-Verilog Code Template
   
   // Macro providing required top-level module definition, random
   // stimulus support, and Verilator config.
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)

                   
                   

\TLV tree_test()
   /* tree_test#$# */
   m4_define_hier(['M4_FLAT'], 9)
   |pipe
      /M4_FLAT_HIER
         @1
            $sig[2:0] = #flat;
      m4+tree_redux(
         |pipe, /flat, 8, 0,
         ['@m4_ifelse(m4_level, 2, 1, m4_level, 1, 3, m4_level, 0, 5, Uh-Oh)'],
         ['$sig[m4_ifelse(m4_level, 2, 2, m4_level, 1, 4, m4_level, 0, 5, Uh-Oh):0]'],
         3, ['m4_op1 + m4_op2'], '0)

\TLV test($_a, $_b, _block)
   // test macro
   m4+_block
\TLV test2($_a, $_b, _block)
   // test macro
   m4+_block()

\TLV

   m4+tree_test
   m4_def(test_var, ['TEST_VAR_EVALUATED'])
   $reset = *reset;
   m4+ifelse(
      1, 2,
      \TLV
         $one = $two;
      , 3, 4,
      \TLV
         $three = $four;
      , 5, 6,
      \TLV
         $five = $six;
      ,
      \TLV
         $seven = $eight;
      )
   
   /hier
      m4+test(
         $one,
         $two,
         \TLV    // Removed comment
            |foo
               /* m4_test_var */
               m4+test(
                  m4foo,
                  1,
                  \TLV
                     /stage4
                        @4
                           $hmm = 1'b0;
                     m4+forloop(i, 5, 6,
                        \TLV
                           /stage['']m4_i
                              @['']m4_i
                                 $hmm = |foo/stage['']m4_eval(m4_i - 1)<<1$hmm;
                        )
                     @1
                        $foo = $bar;
                  )
         )
      


   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
\SV
   endmodule
