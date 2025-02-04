\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\TLV pythagorean_viz_and_log(#_valid)

   //
   // THE REST IS FOR OUTPUT TO VIZ AND LOG TABS.
   //
   
   \viz_js
      // JavaScript code
      box: {left: -200, top: -150, width: 600, height: 500, fill: "#fcf5ee"},
      init() {
         let widgets = {}
         widgets.title = new fabric.Text("Pythagorean Theorem", {
               left: 100, top: -125,
               originX: "center",
               fontSize: 25, fontFamily: "Playfair Display",
         })
         return widgets
      },
      render() {
         let valid = m5_if(#_valid, [''$valid'.asInt()'], ['"yes"'])
         let color = valid ? "black" : "lightgray";
         let valid_str = valid === 1 ? "Valid" : valid === 0 ? "Invalid" : "";
         let a = '$aa'.asInt();
         let b = '$bb'.asInt();
         let angle = Math.atan(a/b);
         return [
            new fabric.Line([0, 0, 0, a*20 ], {stroke: color, strokeWidth: 3}),
            new fabric.Line([0, a*20, b*20, a*20 ], {stroke: color, strokeWidth: 3}),
            new fabric.Line([0, 0, b*20 , a*20 ], {stroke: color, strokeWidth: 3}),
            new fabric.Text(`${a}`, {
               left: -17, top: a*10,
               originX: "right",
               fontSize: 20, fontFamily: "Roboto", fill: color
            }),
            new fabric.Text(`${b}`, {
               left: b*10, top: a*20+17,
               originX: "center",
               fontSize: 20, fontFamily: "Roboto", fill: color
            }),
            new fabric.Text(`${'$cc'.asInt()}`, {
               left: b*10+18*Math.sin(angle), top: a*10-18*Math.cos(angle),
               originY: "center",
               fontSize: 20, fontFamily: "Roboto", fill: color
            }),
            new fabric.Text(`${'$aa_sq'.asInt()} + ${'$bb_sq'.asInt()} = ${'$cc_sq'.asInt()}`, {
               left: 100, top: -70,
               originX: "center",
               fontSize: 20, fontFamily: "Roboto",
               fill: color,
            }),
            new fabric.Text(valid_str, {
               left: 100, top: -40,
               originX: "center",
               fontSize: 20, fontFamily: "Roboto",
            }),
         ]
      },

   \SV_plus
      always_ff @(posedge clk) begin
         m5_if(#_valid, ['if ($valid)'])
            \$display("sqrt((\%2d ^ 2) + (\%2d ^ 2)) = \%2d", $aa, $bb, $cc);
      end

\SV
   `include "sqrt32.v";
   
   m5_makerchip_module
\TLV
      
   |calc
      
      // Pythagora's Theorem
      @1
         $aa_sq[7:0] = $aa[3:0] ** 2;
         $bb_sq[7:0] = $bb[3:0] ** 2;
      @2
         $cc_sq[8:0] = $aa_sq + $bb_sq;
      @3
         $cc[4:0] = sqrt($cc_sq);




         m5+pythagorean_viz_and_log(0)

\SV
   endmodule
