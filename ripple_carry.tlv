\m5_TLV_version 1d: tl-x.org
\m5
   // This region contains M5 macro definitions. It will not appear
   // in the resulting TLV code (in the NAV-TLV tab).
   use(m5-0.2) // Use M5 libraries

// Full adder adding two bits and a carry to produce an output bit and carry.
\TLV full_adder($_out, $_carry_out, $_in1, $_in2, $_carry_in)
   $_out = $_in1 ^ $_in2 ^ $_carry_in;
   $_carry_out = ($_in1 + $_in2 + $_carry_in) > 2'b1;

// A ripple-carry adder chaining full adders, instantiating full adders in /_slice[*].
// Input and output bits are under /_slice[*].
\TLV ripple_carry_adder(/_slice, #_width, $_out, $_carry_out, $_in1, $_in2)
   /_slice[m5_calc((#_width)-1):0]
      $carry_in = (#m4_strip_prefix(/_slice) == 0) ? 1'b0 : /_slice[(#m4_strip_prefix(/_slice) - 1) % (#_width)]$_carry_out;
      m5+full_adder($_out, $_carry_out, $_in1, $_in2, $carry_in)

\SV
   // The main module (as required for Makerchip).
   m5_makerchip_module
\TLV
   // Instantiate an 8-bit ripple-carry adder, connecting input and output bits to vector signals.
   
   m5_var(width, 8)  // adder width
   // Inputs
   m4_rand($addend1, m5_width-1, 0)
   m4_rand($addend2, m5_width-1, 0)
   // Connect inputs
   /slice[m5_width-1:0]
      $in1 = /top$addend1[#slice];
      $in2 = /top$addend2[#slice];
   // Adder
   m5+ripple_carry_adder(/slice, m5_width, $out, $carry_out, $in1, $in2)
   // Outputs
   $result[m5_width:0] = {/slice[m5_width-1]$carry_out, /slice[*]$out};
   
   // VIZ
   \viz_js
      box: {width: 80, height: 12, fill: "darkblue", strokeWidth: 0, rx: 2, ry: 2},
      render() {
         return [new fabric.Text(`${'$addend1'.asInt()} + ${'$addend2'.asInt()} = ${'$result'.asInt()}`,
                                 {left: 2, top: 0, fontFamily: "mono", fontSize: 10, fill: "#d0d0d0"}
         )]
      },
\SV
   endmodule
