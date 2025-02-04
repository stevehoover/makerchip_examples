\m5_TLV_version 1d: tl-x.org
\m5
   / A matrix multiply kernel.
   / Implements output-stationary Mat-Mul in a systolic array.
   / (See https://youtu.be/eQeU9R8_qGQ?feature=shared.)
   
   use(m5-1.0)
   
   var(background_color, "#303030")
   var(connect_color, "#202020")
   var(invalid_color, "#505050")
   var(a_color, "red")
   var(b_color, "yellow")
   var(default_color, "#d0d0d0")
   macro(if_valid, ['valid ? $1 : m5_invalid_color'])
   


\TLV mat_mul_output_stationary(/_top, /_name, #_size_x, #_size_y, #_data_depth)
   \viz_js
      box: {strokeWidth: 0},
      render() {
         // A safeguard render in case things are slow.
         this.timeout = setTimeout(() => {
            this.getCanvas().requestRenderAll()
         }, 500)
      },
      unrender() {
         clearTimeout(this.timeout)
      },
   // Valid for index 0,0.
   $valid00 = // start after reset
              (>>1$reset && ! $reset) ? 1'b1 :
              // end after #_data_depth valids
              /staged[m5_calc(#_data_depth)]$valid00 && ! /staged[m5_calc(#_data_depth + 1)]$valid00 ? 1'b0 :
              // for no overlap and no dead cycles,
              // start again when the lower-right cell becomes invalid
              ! /yy[#_size_y - 1]/xx[#_size_x - 1]$valid && /yy[#_size_y - 1]/xx[#_size_x - 1]>>1$valid ? 1'b1 :
                               $RETAIN;
   /staged[m5_calc(#_size_x + #_size_y - 1):0]
      $ANY = #staged == 0 ? /_top$ANY : /staged[#staged - 1]>>1$ANY;
   /yy[m5_calc(#_size_y - 1):0]
      /xx[m5_calc(#_size_x - 1):0]
         \viz_js
            box: {width: 130, height: 130, strokeWidth: 0},
            layout: "horizontal",
            template: {
               rect: ["Rect", {left: 0, top: 0, width: 100, height: 100, rx: 6, ry: 6,
                               fill: m5_background_color, strokeWidth: 0}],
               horizontal_connect: ["Line", [100, 50, 130, 50],
                                    {stroke: m5_connect_color, strokeWidth: 3}],
               vertical_connect: ["Line", [50, 100, 50, 130],
                                  {stroke: m5_connect_color, strokeWidth: 3}],
               a: ["Text", "xxx", {left: 45, top: 17, originX: "right",
                                   fill: m5_a_color,
                                   fontSize: 19, fontFamily: "Roboto"}],
               b: ["Text", "xxx", {left: 55, top: 17, originX: "left",
                                   fill: m5_b_color,
                                   fontSize: 19, fontFamily: "Roboto"}],
               times: ["Text", "*", {left: 50, top: 17, originX: "center",
                                     fill: m5_default_color,
                                     fontSize: 19, fontFamily: "Roboto"}],
               plus: ["Text", "+", {left: 10, top: 48,
                                    fill: m5_default_color,
                                    fontSize: 12, fontFamily: "Roboto", strokeWidth: 1.4}],
               old_value: ["Text", "yyyyy", {left: 50, top: 48, originX: "center",
                                             fill: m5_invalid_color,
                                             fontSize: 12, fontFamily: "Roboto", strokeWidth: 1.4}],
               line: ["Line", [30, 69, 70, 69], {strokeWidth: 1.1, stroke: m5_default_color}],
               value: ["Text", "zzzzz", {left: 50, top: 74, originX: "center",
                                         fill: m5_default_color,
                                         fontSize: 12, fontFamily: "Roboto", strokeWidth: 1.4}],
            },
            render() {
               let objs = this.getObjects()
               let valid = '$valid'.asBool()
               let next_valid = '$valid'.step(1).asBool(true)
               objs.a.set({left: 45 - 130, text: '$aa'.asInt().toString(), fill: m5_if_valid(m5_a_color)})
               objs.b.set({top:  17 - 130, text: '$bb'.asInt().toString(), fill: m5_if_valid(m5_b_color)})
               let color = m5_if_valid(m5_default_color)
               objs.times.set({fill: color})
               objs.plus.set({fill: color})
               objs.line.set({stroke: color})
               objs.a.animate({left: 45}, {
                  duration: 360,
                  onChange: () => {this.getCanvas().requestRenderAll()}
               })
               objs.b.animate({top: 17}, {
                  duration: 300,
                  onChange: () => {this.getCanvas().requestRenderAll()}
               })
               let $Out = '$Out'
               objs.old_value.set({text: $Out.asInt().toString(),
                                   top: 74, fill: m5_if_valid(m5_default_color)})
               objs.value.set({text: $Out.step(1).asInt(0).toString(),
                               fill: "transparent"})
               objs.old_value.animate({top: 48, fill: m5_if_valid("gray")}, {
                  duration: 360,
                  onChange: () => {this.getCanvas().requestRenderAll()}
               })
               this.timeout = setTimeout(() => {
                  objs.value.set({fill: valid ? (next_valid ? m5_default_color : "white") : m5_invalid_color,
                                  fontSize: valid & ! next_valid ? 15 : 12})
                  //this.getCanvas().requestRenderAll()     // This causes many renders and runs slow.
               }, 300)
            },
            unrender() {
               clearTimeout(this.timeout)
            },
         $valid = /_top/staged[#xx + #yy]$valid00;
         $aa[7:0] = #xx == 0 ? $aa_in[7:0] :
                               /xx[(#xx + #_size_x - 1) % #_size_x]>>1$aa;
         $bb[7:0] = #yy == 0 ? $bb_in[7:0] :
                               /yy[(#yy + #_size_y - 1) % #_size_y]/xx>>1$bb;
         $Out[23:0] <= $valid ? $Out + {16'b0, $aa} * {16'b0, $bb} : 24'b0;
                               
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 150;
   *failed = 1'b0;

\SV
   m5_makerchip_module
\TLV
   $reset = *reset;
   m5+mat_mul_output_stationary(/top, /matrix, 5, 4, 3)
\SV
   endmodule
