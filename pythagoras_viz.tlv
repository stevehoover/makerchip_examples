\m4_TLV_version 1d: tl-x.org
\SV
   `include "sqrt32.v";
   
   m4_makerchip_module
\TLV
   
   // Stimulus
   |calc
      @0
         $valid = & $rand_valid[1:0];  // Valid with 1/4 probability
                                       // (& over two random bits).
   
   // DUT (Design Under Test)
   |calc
      ?$valid
         @1
            $aa_sq[7:0] = $aa[3:0] ** 2;
            $bb_sq[7:0] = $bb[3:0] ** 2;
         @2
            $cc_sq[8:0] = $aa_sq + $bb_sq;
         @3
            $cc[4:0] = sqrt($cc_sq);


   // Print
   |calc
      @3
         \viz_js
            // JavaScript code
            box: {left: -200, top: -100, width: 600, height: 500, fill: "#fcf5ee"},
            init() {
               let widgets = {}
               widgets.title = new fabric.Text("Pythagoras Vizualization", {
                     left: 100, top: -80,
                     originX: "center",
                     fontSize: 20, fontFamily: "Playfair Display",
               })
               return widgets
            },
            render() {
               let color = '$valid'.asInt() ? "black" : "gray";
               let text = '$valid'.asInt() ? "Valid" : "Invalid";
               return [
                  new fabric.Line([0, 0, 0, '$aa'.asInt()*20 ], {stroke: color, strokeWidth: 3}),
                  new fabric.Line([0, '$aa'.asInt()*20, '$bb'.asInt()*20, '$aa'.asInt()*20 ], {stroke: color, strokeWidth: 3}),
                  new fabric.Line([0, 0, '$bb'.asInt()*20 , '$aa'.asInt()*20 ], {stroke: color, strokeWidth: 3}),
                  new fabric.Text(`${'$aa'.asInt()}`, {
                     left: -30, top: '$aa'.asInt()*10,
                     originX: "center",
                     fontSize: 20, fontFamily: "Roboto", fill: color
                  }),
                  new fabric.Text(`${'$bb'.asInt()}`, {
                     left: '$bb'.asInt()*10, top: '$aa'.asInt()*20+20,
                     originX: "center",
                     fontSize: 20, fontFamily: "Roboto", fill: color
                  }),
                  new fabric.Text(`${'$aa_sq'.asInt()} + ${'$bb_sq'.asInt()} = ${'$cc_sq'.asInt()}`, {
                     left: 100, top: -50,
                     originX: "center",
                     fontSize: 20, fontFamily: "Roboto", 
                  }),
                  new fabric.Text(text, {
                     left: 100, top: -20,
                     originX: "center",
                     fontSize: 20, fontFamily: "Roboto",
                  }),
               ]
            },
            
         \SV_plus
            always_ff @(posedge clk) begin
               if ($valid)
                  \$display("sqrt((\%2d ^ 2) + (\%2d ^ 2)) = \%2d", $aa, $bb, $cc);
            end

\SV
   endmodule
