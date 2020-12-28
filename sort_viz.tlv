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
      /pos[m4_n-1:0]
         m4_rand($num, 7, 0, pos)
         //$num[7:0] = (m4_n - 1 - #pos) * 32;  // Reverse order.
   /level[m4_n-1:0]
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
               /pos[m4_n-1:0]
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
   
   m4_define(M4_ROW_HEIGHT, 20)
   m4_define(M4_COL_WIDTH, 40)
   m4_define(M4_FONT_SIZE, 10)
   |pipe
      @1
         \viz_alpha
            initEach() {
               return {objects: {title: new fabric.Text("Sorting Network",
                  {  top: -40,
                     left: 0,
                     fontSize: 20,
                     fontWeight: 800
                     //fontFamily: "monospace"
                  })}}
            }
   /level[m4_eval(m4_n-1):0]
      |pipe
         @1
            /pos[m4_eval(m4_n-1):0]
               \viz_alpha
                  initEach() {
                     //debugger
                     let level = parseInt(scopes.level.index)
                     let pos = parseInt(scopes.pos.index)
                     let x = level * M4_COL_WIDTH
                     let y = pos * M4_ROW_HEIGHT
                     if (level == 0 && pos == 0) {
                        global.canvas.add(new fabric.Rect({
                           width: M4_COL_WIDTH,
                           height: M4_ROW_HEIGHT * m4_n,
                           left: -10,
                           top: 0,
                           fill: "rgb(0, 255, 150)"}))
                     }
                     let valText = new fabric.Text("",
                     {  top: y + 5,
                        left: x,
                        fontFamily: "monospace",
                        fontSize: M4_FONT_SIZE
                     });
                     let lineX1 = x + 8;
                     let lineX2 = x + 48;
                     let lineY = y + 10;
                     let lineProp = {
                        stroke: "lightgray",
                        strokeWidth: 4};
                     let swapLine = null;
                     let noSwapLine = null;
                     //if (level < m4_n - 1) {
                        // No swap line.
                        noSwapLine = new fabric.Line(
                           [lineX1, lineY, lineX2, lineY],
                           lineProp);
                        global.canvas.add(noSwapLine);
                        // Swap line.
                        //if (!((level % 2) && (pos == 0 || pos == m4_n - 1))) {
                           let fromDelta = ((level + pos + 2) % 2) ? -1 : 1;
                           swapLine = new fabric.Line(
                              [lineX1, lineY, lineX2, lineY + fromDelta * M4_ROW_HEIGHT],
                              lineProp);
                           global.canvas.add(swapLine);
                        //}
                     //}
                     global.canvas.add(valText);
                     
                     return {valText, swapLine, noSwapLine};
                  },
                  renderEach() {
                     debugger;
                     let level = parseInt(this.scopes.level.index);  // ISSUE: Fix index references.
                     let validSig = '/level|pipe$valid'.step(level);  // BUG: "/level" required. "'|" doesn't parse.
                     let numSig = '$in_num'.step(level);
                     let swapSig = '$swap'.step(level);
                     
                     let valid = validSig.asBool();
                     let num = numSig.asInt();
                     let swap = swapSig.asBool();
                     let inRange = typeof valid !== "undefined";
                     
                     let color = inRange ? (valid ? (`rgb(${num},0,${255-num})`) : "lightgray") : "darkgrey";
                     
                     this.fromInit().valText.setFill(valid ? "white" : "gray");
                     this.fromInit().valText.setBackgroundColor(valid ? color : "lightgray");
                     //global.canvas.bringToFront(context.initEach.valText);
                     this.fromInit().valText.setText(inRange ? num.toString().padStart(3, " ") : "--");
                     if (this.fromInit().swapLine) {
                        this.fromInit().swapLine.setStroke(inRange ? (swap && valid ? color : "lightgray") : "black");
                     }
                     if (this.fromInit().noSwapLine) {
                        this.fromInit().noSwapLine.setStroke(inRange ? (!swap && valid ? color : "lightgray") : "black");
                     }
                  }
   
   
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

\SV
   endmodule
