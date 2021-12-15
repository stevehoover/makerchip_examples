\m4_TLV_version 1d: tl-x.org
\SV
   // Sort a set of numbers, provided in a 1-dimensional array.
   // The sorting network is a pipeline (though not using a TLV pipeline because stages are replicas).
   // Each pipeline stage has a copy of the array and performs one sorting step.
   // A sorting step involves sorting adjacent pairs of numbers.
   // In even stages, natural pairs are compared ((0,1), (2,3), ...); on odd ((0), (1,2), (3,4), ...).
   
   m4_makerchip_module
      // To relax Verilator compiler checking:
      /* verilator lint_off MULTIDRIVEN */
      m4_define(m4_n, 8)
      m4_define(m4_half, m4_eval(m4_n/2))
\TLV
   $reset = *reset;
   
   /tb
      // Random $valid w/ 1/2 probability.
      m4_rand($rand_valid, 0, 0)
      $valid = (& $rand_valid) && ! /top$reset;
      /pos[m4_eval(m4_n-1):0]
         m4_rand($num, 7, 0, pos)
         //$num[7:0] = (m4_n - 1 - #pos) * 32;  // Reverse order.
   /level[m4_eval(m4_n-1):0]
      |pipe
         // Stage $valid.
         @1
            $valid = (#level == 0) ? /top/tb<>0$valid :
                                     /level[(#level-1) % m4_n]|pipe>>1$valid;
            ?$valid
               // Compare pairs each stage.
               // (For odd stages, /pair[0] is for the wrap-around comparison; /pair[1] is (1,2); etc.)
               /pair[m4_half-1:0]
                  $upper_num[7:0] = |pipe/pos[((#pair << 1) + !(#level % 2)       ) % m4_n]$in_num;
                  $lower_num[7:0] = |pipe/pos[((#pair << 1) -  (#level % 2) + m4_n) % m4_n]$in_num;
                  $swap = ((#level % 2) && (#pair == 0)) ^ // Reverse comparison for wrap-around case. 
                          ($upper_num < $lower_num);
               /pos[m4_eval(m4_n-1):0]
                  // Pull $num from previous stage as $in_num.
                  $in_num[7:0] = (#level == 0) ? /top/tb/pos<>0$num :
                                                 /level[(#level - 1) % m4_n]|pipe/pos[#pos]>>1$num;
                  // Does this number get swapped.
                  $swap = |pipe/pair[((#pos >> 1) + ((#pos % 2) & (#level % 2))) % m4_n]$swap;
                  $num[7:0] =
                      ! $swap ? $in_num :
                                // Swap with pos+1 if pos[0] == level[0], else -1.
                                /pos[(#pos + (((#pos % 2) == (#level % 2)) ? 1 \: -1)) % m4_n]$in_num;
   
   
   
   // =============
   // Visualization
   // =============
   
   m4_def(ROW_HEIGHT, 20)
   m4_def(COL_WIDTH, 40)
   m4_def(FONT_SIZE, 10)
   m4_def(LINE_WIDTH, 4)
   |pipe
      @1
         \viz_js
            box: {strokeWidth: 0},
            init() {
               return {title: new fabric.Text("Sorting Network",
                  {  top: -40,
                     left: 0,
                     fontSize: 20,
                     fontWeight: 800
                     //fontFamily: "monospace"
                  })}
            },
            where: {left: 0, top: -38}
   /level[m4_eval(m4_n-1):0]
      \viz_js
         box: {strokeWidth: 0},
         layout: {left: M4_COL_WIDTH},
         where: {left: 0, top: 0}
      |pipe
         @1
            /pos[m4_eval(m4_n-1):0]
               \viz_js
                  // 0,0: left center of value rect.
                  box: {left: 0, top: -M4_ROW_HEIGHT, width: M4_COL_WIDTH, height: 2 * M4_ROW_HEIGHT, strokeWidth: 0},
                  layout: {top: M4_ROW_HEIGHT},
                  init() {
                     ret = {}
                     //debugger
                     let level = this.getIndex("level")
                     let pos = this.getIndex("pos")
                     if (level == 0 && pos == 0) {
                        ret.highlight = new fabric.Rect({
                           width: M4_COL_WIDTH,
                           height: M4_ROW_HEIGHT * m4_n,
                           left: 0,
                           top: -M4_ROW_HEIGHT / 2,
                           fill: "rgb(0, 255, 150)"})
                     }
                     let lineX1 = M4_COL_WIDTH / 2
                     let lineX2 = M4_COL_WIDTH * 3 / 2
                     let lineY = 0 - M4_LINE_WIDTH / 2
                     let lineProp = {
                        stroke: "lightgray",
                        strokeWidth: 4}
                     let swapLine = null
                     let noSwapLine = null
                     ret.noSwapLine = new fabric.Line(
                        [lineX1, lineY, lineX2, lineY],
                        lineProp)
                     let fromDelta = ((level + pos + 2) % 2) ? -1 : 1
                     ret.swapLine = new fabric.Line(
                        [lineX1, lineY, lineX2, lineY + fromDelta * M4_ROW_HEIGHT],
                        lineProp);
                     ret.valText = new fabric.Text("", {
                        top: 0,
                        left: M4_COL_WIDTH / 2,
                        originX: "center",
                        originY: "center",
                        fontFamily: "monospace",
                        fontSize: M4_FONT_SIZE
                     })
                     
                     return ret
                  },
                  render() {
                     //debugger
                     let level = this.getIndex("level")
                     let validSig = '/level|pipe$valid'.step(level) // BUG: "/level" required. "'|" doesn't parse.
                     let numSig = '$in_num'.step(level)
                     let swapSig = '$swap'.step(level)
                     
                     let valid = validSig.asBool()
                     let num = numSig.asInt()
                     let swap = swapSig.asBool()
                     let inRange = typeof valid !== "undefined"
                     
                     let color = inRange ? (valid ? (`rgb(${num},0,${255-num})`) : "lightgray") : "darkgrey"
                     let obj = this.getObjects()
                     obj.valText.set({fill: valid ? "white" : "gray",
                                      backgroundColor: valid ? color : "lightgray",
                                      text: inRange ? num.toString().padStart(3, " ") : "--"})
                     if (obj.swapLine) {
                        obj.swapLine.set({stroke: inRange ? (swap && valid ? color : "lightgray") : "black"})
                     }
                     if (obj.noSwapLine) {
                        obj.noSwapLine.set({stroke: inRange ? (!swap && valid ? color : "lightgray") : "black"})
                     }
                     
                  }
   
   
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

\SV
   endmodule
