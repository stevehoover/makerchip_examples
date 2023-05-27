\m4_TLV_version 1d: tl-x.org
m4+definitions(['
   // Parameters:
   m4_define(M4_MAX_DEPTH, 40)
   m4_def(MAX_H, 40,
          MAX_V, 40)
   // Full size.
   //m4_define(M4_MIN_X, -2.0)
   //m4_define(M4_MIN_Y, -2.0)
   //m4_define(M4_MAX_X, 2.0)
   //m4_define(M4_MAX_Y, 2.0)
   // Good place, 20x.  
   m4_def(MIN_X, -1.3,
          MIN_Y, -0.4,
          MAX_X, -1.2,
          MAX_Y, -0.3)
   
   // Viz parameters.
   m4_def(VIZ_CELL_SIZE, 10,
          VIZ_FONT_SIZE, 5,
          VIZ_LINE_SIZE, 15)
   // Layout
   m4_def(VIZ_SCREEN_X, 0,
          VIZ_SCREEN_Y, 0)
   // Text box position
   m4_def(VIZ_TEXT_AREA_WIDTH, M4_VIZ_FONT_SIZE * 55,
          VIZ_TEXT_X, M4_VIZ_SCREEN_X - M4_VIZ_TEXT_AREA_WIDTH,
          VIZ_TEXT_Y, M4_VIZ_SCREEN_Y)
   // Coloring mode:
   // Each color component can be one of:
   //   {mode: "depth"}: least-significan-digit of depth
   //   {mode: "depth2"}: most-significant-digit of depth
   //   {mode: "Value"/"Frac"/"Exp", val: "A"/"B"/"doneA"/"doneB"/"AB", neg: "Abs"/"Continuous"/"Black"/"Zero", saturate: true/false}:
   //     val: The value to use for color (% applied and negative to black). "Frac"/"Exp" are smooth scales.
   //     neg: Treatment of negative values ("Frac" is always positive, so irrelevant):
   //          "Abs": absolute value
   //          "Continuous": continuous cycling
   //          "Black": force all components to black
   //          "Zero": zero negtives by default
   //   {mode: "Smooth", pattern: [#, #, #]}: (expected to set all dimensions to this) Based on distance (a*a+b*b) of depth calc
   //                     from 4.0 relative to distance calc of depth+1 (done). Color component at each depth border is given
   //                     by #'s (any length array).
   //   "##": A fixed value (2 hex digits)
   // Mandelbrot uses "depth" and "depth2", like: ["depth","depth2", #]
   // /* Mandelbrot: */ m4_define(M4_COLOR_MODE, ['{mode: "depth"}, {mode: "Abs", dim: "B"}, {mode: "Abs", dim: "A"}'])
   // /* Smoothed: */ m4_define(M4_COLOR_MODE, ['{mode: "Smooth", pattern: [255, 255, 0, 0, 255, 255, 0, 0]}, {mode: "Smooth", pattern: [0, 255, 255, 255, 255, 0, 0, 0]}, {mode: "Smooth", pattern: [0, 0, 0, 255, 255, 255, 255, 0]}'])
   // /* Bubbly */ m4_define(M4_COLOR_MODE, ['{mode: "depth"}, {mode: "Exp", val: "doneA", neg: "Black"}, {mode: "Frac", val: "doneA"}'])
   //m4_define(M4_COLOR_MODE, ['{mode: "Smooth", pattern: [0, 50, 50, 0]}, {mode: "Smooth", pattern: [0, 0, 50, 50]}, {mode: "Frac", val: "AB"}'])
   // /* Smoothed w/ AB exp blend */ m4_define(M4_COLOR_MODE, ['{mode: "Smooth", pattern: [0, 155, 155, 0]}, {mode: "Smooth", pattern: [0, 0, 155, 155]}, {mode: "Value", val: "blendAB", neg: "Zero", saturate: true}'])
   /* Electrified */ m4_def(COLOR_MODE, ['{mode: "Smooth", pattern: [0, 155, 155, 0]}, {mode: "Smooth", pattern: [0, 0, 155, 155]}, {mode: "Frac", val: "blendAB", neg: "Abs", saturate: true}'])
   m4_def(FIXED_DEPTH, 0)
'])
// Params:
//   _out_prefix: ['*'] or ['$'] to prefix passed/failed output signals in |pipe@0.
\TLV mandelbrot(/_top, _out_prefix, _where)
   /_top
      $reset = *reset;
      \viz_js
         box: {strokeWidth: 0},
         where: {_where}

      |pipe
         @0
            $reset = /_top<>0$reset;


            //
            // ViewBox (fly-through)
            //

            // The view, given by upper-left corner coords and pixel x & y size.
            // (Currently, constant, but will enable changes (fly-through).)
            **real $MinX;
            $MinX <= M4_MIN_X;
            **real $MinY;
            $MinY <= M4_MIN_Y;
            **real $PixX;
            $PixX <= (M4_MAX_X - M4_MIN_X) / M4_MAX_H;
            **real $PixY;
            $PixY <= (M4_MAX_Y - M4_MIN_Y) / M4_MAX_V;


            //
            // Screen render control
            //

            // Cycle over pixels (vertical (outermost) and horizontal) and depth (innermost).
            // When each wraps, increment the next.
            $wrap_h = $PixH == M4_MAX_H;
            $wrap_v = $PixV == M4_MAX_V;
            $Depth[\$clog2(M4_MAX_DEPTH+1)-1:0] <=
               $reset || $done_pix ? '0 : $Depth + 1;
            $PixH[\$clog2(M4_MAX_H+1)-1:0] <=
               $reset ?
                  '0 :
                  $done_pix ?
                     $wrap_h ? '0 : $PixH + 1 :
                     $RETAIN;
            $PixV[\$clog2(M4_MAX_V+1)-1:0] <=
               $reset ?
                  '0 :
                  ($done_pix && $wrap_h) ?
                     $wrap_v ? '0 : $PixV + 1 :
                     $RETAIN;
            // Repeat the above with a real calculation because there is no easy translation.
            // $bitstoreal() appears to just provide raw bits.
            **real $PixHReal;
            $PixHReal <=
               $reset ?
                  0.0 :
                  $done_pix ?
                     $wrap_h ? 0.0 : $PixHReal + 1.0 :
                     $RETAIN;
            **real $PixVReal;
            $PixVReal <=
               $reset ?
                  0.0 :
                  ($done_pix && $wrap_h) ?
                     $wrap_v ? 0.0 : $PixVReal + 1.0 :
                     $RETAIN;


            //
            // Map pixels to x,y coords
            //

            $init = $Depth == '0;  // 1st iteration -- initializes the pixel

            // The coordinates of the pixel we are working on.
            **real $xx;
            $xx = $init ? $MinX + $PixX * $PixHReal : $RETAIN;
            **real $yy;
            $yy = $init ? $MinY + $PixY * $PixVReal : $RETAIN;


            //
            // Mandelbrot Calculation
            //

            // Mandelbrot algorithm:
            // a = 0.0
            // b = 0.0
            // depth = 0
            // for depth [0..max_depth] until diverged {  // one iteration per cycle
            //   a <= a*a - b*b + x
            //   b <= 2*a*b + y
            //   diverged <= a*a + b*b >= 2.0*2.0
            // }
            $done_pix = (!1'b['']M4_FIXED_DEPTH && ($init ? 1'b0 : $Aa * $Aa + $Bb * $Bb >= (2.0 * 2.0))) || 
                        ($Depth == M4_MAX_DEPTH);
            $not_done = ! $done_pix;
            ?$not_done
               **real $Aa;
               $Aa <= $init ? $xx :
                              $Aa * $Aa - $Bb * $Bb + $xx;
               **real $Bb;
               $Bb <= $init ? $yy :
                              2.0 * $Aa * $Bb + $yy;
               $color_index[\$clog2(M4_MAX_DEPTH+1)-1:0] = $Depth;

            // For viz:
            /**/
            $xx_vec[63:0] = \$realtobits($xx);
            $yy_vec[63:0] = \$realtobits($yy);
            $aa_vec[63:0] = \$realtobits($Aa);
            $bb_vec[63:0] = \$realtobits($Bb);
            /**/

            \viz_js
               box: {
                  left: M4_VIZ_TEXT_X,
                  top: M4_VIZ_SCREEN_Y,
                  width: M4_VIZ_TEXT_AREA_WIDTH + M4_VIZ_CELL_SIZE * (M4_MAX_H + 1),
                  height: M4_VIZ_CELL_SIZE * (M4_MAX_V + 1),
                  //stroke: "green",
                  //strokeWidth: 10
               },
               init() {
                  let text = new fabric.Text("", {
                        left: M4_VIZ_TEXT_X,
                        top: M4_VIZ_TEXT_Y,
                        fontSize: M4_VIZ_FONT_SIZE,
                        fontFamily: "monospace"
                     })
                  //debugger
                  let circle = new fabric.Circle({
                     originX: "center",
                     left: 0,
                     originY: "center",
                     top: 0,
                     radius: M4_VIZ_CELL_SIZE / 2 * 1.5,
                     stroke: "red",
                     strokeWidth: M4_VIZ_CELL_SIZE / 10,
                     fill: "rgba(128,128,128,0)"
                  })

                  // 2D Map
                  //debugger
                  return {circle, text}
               },

               onTraceData() {
                  // Create the screen image.
                  let colorMode = [M4_COLOR_MODE]
                  let screen = new (this.getGlobal().Grid)(window, this, M4_MAX_H + 1, M4_MAX_V + 1,
                       {left: M4_VIZ_SCREEN_X, top: M4_VIZ_SCREEN_Y,
                        scaleX: M4_VIZ_CELL_SIZE,
                        scaleY: M4_VIZ_CELL_SIZE,
                        width: M4_MAX_H + 1,
                        height: M4_MAX_V + 1})

                  // Get signals (not setting time, yet).
                  let $PixH = '$PixH'
                  let $PixV = '$PixV'
                  let $color_index = '$color_index'
                  // For coloring by a and b.
                  let $Aa = '$aa_vec'
                  let $Bb = '$bb_vec'

                  // Get $done_pix, and set to first high cycle.
                  let $done_pix = '$done_pix'.goTo(0)
                  $done_pix.stepTransition()

                  // Step over pixels.
                  while (!$done_pix.offEnd()) {  // Trusting that simulation stops after filling screen.
                     // Take signals to pixel's last not-done cycle, relative to $done_pix at high cycle.
                     cyc = $done_pix.getCycle() - 1
                     $PixH.goTo(cyc)
                     $PixV.goTo(cyc)
                     $color_index.goTo(cyc)
                     $Aa.goTo(cyc + 1)
                     $Bb.goTo(cyc + 1)
                     let doneA = $Aa.asReal()
                     let doneB = $Bb.asReal()
                     $Aa.step(-1)
                     $Bb.step(-1)

                     let pixH = $PixH.asInt()
                     let pixV = $PixV.asInt()
                     let colorIndex = $color_index.asInt()
                     // For A/B-based coloring.
                     let A = $Aa.asReal()
                     let B = $Bb.asReal()
                     let AStr = $Aa.asBinaryStr()
                     let BStr = $Bb.asBinaryStr()

                     // Calculations that are necessary for some modes, but could be common to color components.
                     let doneCalc = doneA * doneA + doneB * doneB
                     let notDoneCalc = A * A + B * B
                     let doneRatio = (4.0 - notDoneCalc) / (doneCalc - notDoneCalc)

                     // Determine color by computing each component color according to mode.
                     let color = "#"
                     if (colorIndex <= 0) {
                       color = "#000000"
                     } else {
                        if (A > 2.0 || B > 2.0) {
                           debugger
                        }
                        for (m = 0; m < 3; m++) {
                           let mode = colorMode[m]
                           let colorCode = null
                           if (typeof mode === "string") {
                              color += mode
                           } else if (mode.mode === "depth") {
                              color += (colorIndex % 4) * 3  + "0"
                           } else if (mode.mode === "depth2") {
                              color += (Math.floor(colorIndex / 4) % 10) + "0"
                           } else if (mode.mode === "Smooth") {
                              if (colorIndex == M4_MAX_DEPTH - 1) {
                                 color += "00"
                              } else if (colorIndex >= M4_MAX_DEPTH) {
                                 console.log("Oops")
                                 debugger
                              } else {
                                 let beforeVal = mode.pattern[colorIndex % mode.pattern.length]
                                 let afterVal = mode.pattern[(colorIndex + 1) % mode.pattern.length]
                                 let colorVal = beforeVal + (afterVal - beforeVal) * doneRatio
                                 color += Math.floor(colorVal).toString(16).padStart(2, "0")
                              }
                           } else if (mode.val) {
                              let val = mode.val === "A" ? A / 2.0 :
                                        mode.val === "B" ? B / 2.0 :
                                        mode.val === "doneA" ? doneA / 2.0 :
                                        mode.val === "doneB" ? doneB / 2.0 :
                                        mode.val === "AB" ? A * B / 4.0 :
                                        mode.val === "doneAB" ? doneA * doneB / 4.0 :
                                        mode.val === "blendAB" ? ((doneA * doneB) * doneRatio + (A * B) * (1.0 - doneRatio)) / 4.0 :
                                              console.log("Bad mode.val")
                              if (mode.mode === "Frac" || mode.mode === "Exp") {
                                 let base = 7
                                 val = Math.abs(val)
                                 let realExp = // log(exp, base)
                                    Math.log(val) / Math.log(base)
                                 let exp = Math.ceil(realExp)
                                 let pow = Math.pow(base, exp)
                                 let frac = pow ? val / pow : 0.0
                                 //console.log(`frac: ${frac}`)
                                 if (mode.mode === "Frac") {
                                    val = frac
                                    if (val > 1.0 && colorIndex > 1) {
                                      debugger
                                    }
                                 } else { // "Exp"
                                    val = - (realExp) / 3.5  // realExp w/ various scaling hacks.
                                 }
                              } else if (mode.mode === "Value") {
                                 // Keep value as is.
                              } else {
                                 console.log("Unrecognized mode: " + mode)
                                 debugger
                              }
                              if (val < 0) {
                                 if (mode.neg === "Abs") {
                                    val = -val
                                 } else if (mode.neg === "Continuous") {
                                    val += 256 * 10000 // Bring to positive for mod.
                                    if (val < 0) {val = 0.0}
                                 } else if (mode.neg === "Black") {
                                    colorCode = "--" // Creates bad color code, resulting in black.
                                 } else if (mode.neg === "Zero") {
                                    val = 0.0
                                 }
                              }
                              if (val >= 1.0) {
                                 if (mode.saturate) {
                                    val = 0.999
                                 }
                              }
                              color += colorCode ? colorCode : (Math.floor(val * 256) % 256).toString(16).padStart(2, "0")
                           } else {
                              console.log("Failed to interpret color mode.")
                              debugger
                           }
                        }
                     }

                     // Check color
                     if (! /^#[0-9a-f]{6}$/i.test(color)) {
                       debugger
                     }
                     screen.setCellColor(pixH, pixV, color)

                     $done_pix.stepTransition(2)
                  }

                  // Add screen to canvas.
                  let screenImg = screen.getFabricObject()
                  return {objects: {screen: screenImg}}
               },

               render() {
                  let ret = []

                  // Build pixel calculation.
                  let x = '$xx_vec'.asRealFixed(3, NaN)
                  let y = '$yy_vec'.asRealFixed(3, NaN)
                  let depthSig = '$Depth'
                  let depth = depthSig.asInt()

                  // Iterate through calculation for this pixel, adding each step to calcStr.
                  // Back signals up to depth 1.
                  let aSig = '$aa_vec'.step(-depth + 1) // Back to init cycle, and +1.
                  let bSig = '$bb_vec'.step(-depth + 1) // Back to init cycle, and +1.
                  let doneSig = '$done_pix'.step(-depth + 1)
                  // Display depth 0 (even though signals are at depth 1)
                  d = 0; // Depth being displayed
                  let str = `-------- 0 --------\n`

                  let depthStr = depth == d ? "| " : "  ";
                  str += `${depthStr} $Xx (${x}) => $Aa (${aSig.asRealFixed(3, NaN)})\n`
                  str += `${depthStr} $Yy (${y}) => $Bb (${bSig.asRealFixed(3, NaN)})\n`
                  let done = false
                  do {
                    done = doneSig.asBool(true);
                    // Display calculation at this depth.
                    str += `-------- ${++d} --------\n`
                    depthStr = `${depth == d ? "| " : "  "}`
                    let str1 = `${depthStr}$Aa (${aSig.asRealFixed(3, NaN)}) ^ 2 - $Bb (${bSig.asRealFixed(3, NaN)}) ^ 2 + $xx (${x})`
                    let str2 = `${depthStr}2.0 * $Aa (${aSig.asRealFixed(3, NaN)}) * $Bb (${bSig.asRealFixed(3, NaN)}) + $yy (${y})`
                    let str3 = `${depthStr}$Aa (${aSig.asRealFixed(3, NaN)}) ^ 2 + $Bb (${bSig.asRealFixed(3, NaN)}) ^ 2 >= (2.0 * 2.0) = $done_pix (${done})\n`
                    aSig.step()
                    bSig.step()
                    doneSig.step()
                    str1 += ` => $Aa (${aSig.asRealFixed(3, NaN)})\n`
                    str2 += ` => $Bb (${bSig.asRealFixed(3, NaN)})\n`
                    str += str1 + str2 + str3
                  } while(!done && d <= M4_MAX_DEPTH)
                  this.getObjects().text.set("text", str)
                  // Calculate the screen.
                  // This is a static view reflecting the entire simulation,
                  // so we create it once, and never again.
                  //debugger
                  // Position circle
                  let circle = this.getObjects().circle
                  //debugger
                  circle.bringToFront()
                  circle.set("left", M4_VIZ_SCREEN_X + ('$PixH'.asInt() + 0.5) * M4_VIZ_CELL_SIZE)
                  circle.set("top",  M4_VIZ_SCREEN_Y + ('$PixV'.asInt() + 0.5) * M4_VIZ_CELL_SIZE)
                  return ret
               }
         @1
            // Assert these to end simulation (before Makerchip cycle limit).
            _out_prefix['']passed = !clk || ($wrap_v && $wrap_h && $done_pix) || *cyc_cnt > 40000;
            _out_prefix['']failed = !clk || 1'b0;

\SV

   // ==========================
   // Mandelbrot Set Calculation
   // ==========================

   m4_makerchip_module
      // To relax Verilator compiler checking:
      /* verilator lint_off UNOPTFLAT */
      /* verilator lint_on WIDTH */
      /* verilator lint_off REALCVT */  // !!! SandPiper DEBUGSIGS BUG.
\TLV
   m4+mandelbrot(/mandelbrot, *,)
\SV
   endmodule
