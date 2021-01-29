\m4_TLV_version 1d: tl-x.org
\SV

   // ==========================
   // Mandelbrot Set Calculation
   // ==========================

   // To relax Verilator compiler checking:
   /* verilator lint_off UNOPTFLAT */
   /* verilator lint_on WIDTH */
   /* verilator lint_off REALCVT */  // !!! SandPiper DEBUGSIGS BUG.

   // Parameters:
   m4_define(M4_MAX_DEPTH, 40)
   m4_define(M4_MAX_H, 100)
   m4_define(M4_MAX_V, 100)
   m4_define(M4_MIN_FLOAT_X, -2.0) // -1.3
   m4_define(M4_MIN_FLOAT_Y, -2.0) // -0.4
   m4_define(M4_MAX_FLOAT_X, 2.0) // -1.2
   m4_define(M4_MAX_FLOAT_Y, 2.0) // -0.3
   // Fixed numbers (sign, int, fraction)
   m4_define(M4_FIXED_UNSIGNED_WIDTH, 32)

   // Constants and computed values:
   m4_define(M4_FIXED_SIGN_BIT, M4_FIXED_UNSIGNED_WIDTH)
   m4_define(M4_FIXED_INT_WIDTH, 3)  // Fixed values are < 8.0.
   m4_define(M4_FIXED_FRAC_WIDTH, m4_eval(M4_FIXED_UNSIGNED_WIDTH - M4_FIXED_INT_WIDTH)) 
   m4_define(M4_FIXED_RANGE, ['M4_FIXED_SIGN_BIT:0'])
   m4_define(M4_FIXED_UNSIGNED_RANGE, ['m4_eval(M4_FIXED_SIGN_BIT-1):0'])

   // Viz parameters.
   m4_define(M4_VIZ_CELL_SIZE, 20)
   m4_define(M4_VIZ_FONT_SIZE, 10)
   m4_define(M4_VIZ_LINE_SIZE, 15)

   function fixed_mul (v1, v2);
      logic [M4_FIXED_RANGE] fixed_mul;
      logic [M4_FIXED_RANGE] v1, v2;
      logic [M4_FIXED_INT_WIDTH-1:0] drop_bits;
      logic [M4_FIXED_FRAC_WIDTH-1:0] insignificant_bits;
      {fixed_mul[M4_FIXED_SIGN_BIT], drop_bits, fixed_mul[M4_FIXED_UNSIGNED_RANGE], insignificant_bits} =
         {v1[M4_FIXED_SIGN_BIT] ^ v2[M4_FIXED_SIGN_BIT], ({{M4_FIXED_UNSIGNED_WIDTH{1'b0}}, v1[M4_FIXED_UNSIGNED_RANGE]} * {{M4_FIXED_UNSIGNED_WIDTH{1'b0}}, v2[M4_FIXED_UNSIGNED_RANGE]})};
   endfunction;

   function fixed_add (v1, v2, sub);
      logic [M4_FIXED_RANGE] v1, v2, binary_v2, fixed_add;
      logic sub;
      binary_v2 = fixed_to_binary(v1) +
                  fixed_to_binary({v2[M4_FIXED_SIGN_BIT] ^ sub, v2[M4_FIXED_SIGN_BIT-1:0]});
      fixed_add = binary_to_fixed(binary_v2);
   endfunction;

   function fixed_to_binary (f);
      logic [M4_FIXED_RANGE] f, fixed_to_binary;
      fixed_to_binary =
         f[M4_FIXED_SIGN_BIT]
            ? // Flip non-sign bits and add one. (Adding one is insignificant, so we save hardware and don't do it.)
              {1'b1, ~f[M4_FIXED_UNSIGNED_WIDTH-1:0] /* + {{M4_FIXED_UNSIGNED_WIDTH-1{1'b0}}, 1'b1} */}
            : f;
   endfunction;

   function binary_to_fixed (b);
      logic [M4_FIXED_RANGE] binary_to_fixed, b;
      // The conversion is symmetric.
      binary_to_fixed = fixed_to_binary(b);
   endfunction;
                                  
   function real_to_fixed (r);
      logic [M4_FIXED_RANGE] real_to_fixed;
      logic [63:0] b;
      real r;
      b[63:0] = $realtobits(r);
      real_to_fixed = {b[63], {1'b1, b[51:53-M4_FIXED_UNSIGNED_WIDTH]} >> (-(b[62:52] - 1023) + M4_FIXED_INT_WIDTH - 1)};
   endfunction;

   // Zero extend to given width.
   `define ZX(val, width) {{1'b0{width-$bits(val)}}, val}
      
   m4_makerchip_module

\TLV
   $reset = *reset;
   
   |pipe
      @0
         $reset = /top<>0$reset;
         
         
         //
         // ViewBox (fly-through)
         //
         
         // The view, given by upper-left corner coords and pixel x & y size.
         // (Currently, constant, but will enable changes (fly-through).)
         //**real $MinX;
         $MinX[M4_FIXED_RANGE] <= real_to_fixed(M4_MIN_FLOAT_X);
         //**real $MinY;
         $MinY[M4_FIXED_RANGE] <= real_to_fixed(M4_MIN_FLOAT_Y);
         //**real $PixX;
         $PixX[M4_FIXED_RANGE] <= real_to_fixed((M4_MAX_FLOAT_X - M4_MIN_FLOAT_X) / M4_MAX_H);
         //**real $PixY;
         $PixY[M4_FIXED_RANGE] <= real_to_fixed((M4_MAX_FLOAT_Y - M4_MIN_FLOAT_Y) / M4_MAX_V);
         
         
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

         //
         // Map pixels to x,y coords
         //
         
         $init = $Depth == '0;  // 1st iteration -- initializes the pixel
         
         // The coordinates of the pixel we are working on.
         //**real $xx;
         // $xx = $init ? $MinX + $PixX * $PixH : $RETAIN;  (in fixed-point)
         $xx_mul[M4_FIXED_UNSIGNED_RANGE] =
            ($PixX[M4_FIXED_UNSIGNED_RANGE] * `ZX($PixH, M4_FIXED_UNSIGNED_WIDTH));
         $xx[M4_FIXED_RANGE] =
            $init ? fixed_add($MinX[M4_FIXED_RANGE],
                              {1'b0, $xx_mul},
                              1'b0)
                  : $RETAIN;
         //**real $yy;
         // $yy = $init ? $MinY + $PixY * $PixV : $RETAIN;  (in fixed-point)
         $yy_mul[M4_FIXED_UNSIGNED_RANGE] =
            ($PixY[M4_FIXED_UNSIGNED_RANGE] * `ZX($PixV, M4_FIXED_UNSIGNED_WIDTH));
         $yy[M4_FIXED_RANGE] =
            $init ? fixed_add($MinY[M4_FIXED_RANGE],
                              {1'b0, $yy_mul},
                              1'b0)
                  : $RETAIN;
         
         
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
         $aa_sq[M4_FIXED_RANGE] = fixed_mul($Aa, $Aa);
         $bb_sq[M4_FIXED_RANGE] = fixed_mul($Bb, $Bb);
         $aa_sq_plus_bb_sq[M4_FIXED_RANGE] = fixed_add($aa_sq, $bb_sq, 1'b0);
         $done_pix = $init ? 1'b0 :
             // a*a + b*b
             (($aa_sq_plus_bb_sq[M4_FIXED_SIGN_BIT] == 1'b0) &&
              ($aa_sq_plus_bb_sq[M4_FIXED_UNSIGNED_RANGE] >= real_to_fixed(4.0))
             ) || 
             // This term catches some overflow cases w/ the multiply and allows fewer int bits to be used.
             // |a| >= 2.0 || |b| >= 2.0
             (|{$Aa[M4_FIXED_SIGN_BIT-1:M4_FIXED_SIGN_BIT-M4_FIXED_INT_WIDTH+1],
                $Bb[M4_FIXED_SIGN_BIT-1:M4_FIXED_SIGN_BIT-M4_FIXED_INT_WIDTH+1]}
             ) || 
             ($Depth == M4_MAX_DEPTH);
         $not_done = ! $done_pix;
         ?$not_done
            //**real $Aa;
            $aa_sq_minus_bb_sq[M4_FIXED_RANGE] = fixed_add($aa_sq, $bb_sq, 1'b1);
            $Aa[M4_FIXED_RANGE] <= $init ? $xx : fixed_add($aa_sq_minus_bb_sq, $xx, 1'b0);
            $aa_times_bb[M4_FIXED_RANGE] = fixed_mul($Aa, $Bb);
            $aa_times_bb_times_2[M4_FIXED_RANGE] = {$aa_times_bb[M4_FIXED_SIGN_BIT], $aa_times_bb[M4_FIXED_UNSIGNED_RANGE] << 1};
            //**real $Bb;
            $Bb[M4_FIXED_RANGE] <= $init ? $yy : fixed_add($aa_times_bb_times_2, $yy, 1'b0);
            $color_index[\$clog2(M4_MAX_DEPTH+1)-1:0] = $Depth;
            
         
         \viz_alpha
            initEach() {
               let text = new fabric.Text("Hello",
                  {  top: -M4_VIZ_LINE_SIZE * (M4_MAX_DEPTH + 1) * 4,
                     left: 0,
                     fontSize: M4_VIZ_FONT_SIZE,
                     fontFamily: "monospace"
                  })
               global.canvas.add(text);
               let circle = new fabric.Circle({
                  originX: "center",
                  left: 0,
                  originY: "center",
                  top: 0,
                  radius: M4_VIZ_CELL_SIZE / 2 * 1.5,
                  stroke: "red",
                  strokeWidth: M4_VIZ_CELL_SIZE / 10,
                  fill: "rgba(128,128,128,0)"
               });
               global.canvas.add(circle)
               return {circle: circle, text: text, createdScreen: false}
            },
                  
            renderEach() {
               
               // @param: sig {SignalValue}
               // @param: decimalPlaces {int, undefined} The number of decimal places with which to represent the number, of undefined for no rounding.
               let asFixed = function(sig, decimalPlaces) {
                  if (sig.inTrace()) {
                     let str = sig.asBinaryStr()
                     let sign = str.substr(0, 1) == "0" ? 1 : -1
                     // TODO: This won't extend to high-precision calc.
                     let unsigned = parseInt(str.substr(1), 2) / Math.pow(2, M4_FIXED_FRAC_WIDTH)
                     let val = sign * unsigned
                     if (decimalPlaces) {
                        val = val.toFixed(decimalPlaces)
                     }
                     return val
                  } else {
                     return NaN;
                  }
               }
               
               /**/
               debugger;
               // Build pixel calculation.
               let x = asFixed('$xx', 3);
               let y = asFixed('$yy', 3);
               let depthSig = '$Depth';
               let depth = depthSig.asInt();
               
               /**/
               // Iterate through calculation for this pixel, adding each step to calcStr.
               // Back signals up to depth 0.
               depthSig.step(-depth + 1);
               let aSig = '$Aa'.step(-depth + 1);
               let bSig = '$Bb'.step(-depth + 1);
               let aSq = '$aa_sq'.step(-depth + 1);
               let bSq = '$bb_sq'.step(-depth + 1);
               let aSqMinusBSq = '$aa_sq_minus_bb_sq'.step(-depth + 1);
               let aSqPlusBSq = '$aa_sq_plus_bb_sq'.step(-depth + 1);
               let aTimesB = '$aa_times_bb'.step(-depth + 1);
               let aTimesBTimes2 = '$aa_times_bb_times_2'.step(-depth + 1);
               let doneSig = '$done_pix'.step(-depth + 1);
               // Display first iteration
               d = 0; // Depth being displayed
               let str = `-------- 0 --------\n`;
               
               let depthStr = depth == d ? "| " : "  ";
               str += `${depthStr} $Xx[${x}] => $Aa[${asFixed(aSig, 3)}]\n`;
               str += `${depthStr} $Yy[${y}] => $Bb[${asFixed(bSig, 3)}]\n`;
               let done = false;
               do {
                  done = doneSig.asBool(true);
                  // Display calculation at this depth.
                  str += `-------- ${++d} --------\n`;
                  depthStr = `${depth == d ? "| " : "  "}`;
                  let str1 = `${depthStr}(($Aa[${asFixed(aSig, 3)}] ^ 2)[${asFixed(aSq, 3)}] - ($Bb[${asFixed(bSig, 3)}] ^ 2)[${asFixed(bSq,3)}]])[${asFixed(aSqMinusBSq, 3)}] + $xx[${x}]`;
                  let str2 = `${depthStr}(2.0 * ($Aa[${asFixed(aSig, 3)}] * $Bb[${asFixed(bSig, 3)}])[${asFixed(aTimesB)}])[${asFixed(aTimesBTimes2)}] + $yy[${y}]`;
                  let str3 = `${depthStr}(($Aa[${asFixed(aSig, 3)}] ^ 2)[${asFixed(aSq,3)}] + ($Bb[${asFixed(bSig, 3)}] ^ 2)[${asFixed(bSq,3)}])[${asFixed(aSqMinusBSq,3)}] >= (2.0 * 2.0) = $done_pix[${done}]\n`;
                  aSig.step();
                  bSig.step();
                  aSq.step();
                  bSq.step();
                  aSqMinusBSq.step();
                  aSqPlusBSq.step();
                  aTimesB.step();
                  aTimesBTimes2.step();
                  doneSig.step();
                  str1 += ` => $Aa[${asFixed(aSig, 3)}]\n`;
                  str2 += ` => $Bb[${asFixed(bSig, 3)}]\n`;
                  str += str1 + str2 + str3;
               } while(!done && d <= M4_MAX_DEPTH);
               this.fromInit().text.setText(str);
               /**/
               
               
               // Calculate the screen.
               // This is a static view reflecting the entire simulation,
               // so we create it once, and never again.
               if (!this.fromInit().createdScreen) {
                  this.fromInit().createdScreen = true;
                  $done_pix = '$done_pix'; $done_pix.goTo(0);
                  $done_pix.goToNextTransition();
                  time = $done_pix.getCycle() - 1;
                  $PixH = '$PixH'; $PixH.goTo(time);
                  $PixV = '$PixV'; $PixV.goTo(time);
                  $color_index = '$color_index'; $color_index.goTo(time);
                  // Step over pixels.
                  while (!$done_pix.offEnd()) {  // Trusting that simulation stops after filling screen.
                     pixH = $PixH.asInt();
                     pixV = $PixV.asInt();
                     colorIndex = $color_index.asInt();
                     
                     let color = "#" + (Math.floor(colorIndex / 4) % 10) + "0" + (colorIndex % 4) * 3  + "000";
                     this.getCanvas().add(new fabric.Rect({
                        width: M4_VIZ_CELL_SIZE,
                        height: M4_VIZ_CELL_SIZE,
                        fill: color,
                        left: pixH * M4_VIZ_CELL_SIZE,
                        top: pixV * M4_VIZ_CELL_SIZE
                     }));
                     
                     $done_pix.stepTransition(); $done_pix.stepTransition();
                     time = $done_pix.getCycle() - 1;
                     $PixH.goTo(time);
                     $PixV.goTo(time);
                     $color_index.goTo(time);
                  }
                  /**/
               }
            
               // Position circle
               this.getCanvas().bringToFront(this.fromInit().circle);
               this.fromInit().circle.set("left", ('$PixH'.asInt() + 0.5) * M4_VIZ_CELL_SIZE);
               this.fromInit().circle.set("top",  ('$PixV'.asInt() + 0.5) * M4_VIZ_CELL_SIZE);
            }

      
      /*
      // The screen, one pixel updated each cycle
      // (for debug of small models only)
      /screen_v[M4_MAX_V:0]
         /screen_h[M4_MAX_H:0]
            @0
               /-* Clean, low performance approach:
               $ColorIndex[\$clog2(M4_MAX_DEPTH+1)-1:0] <=
                  (|pipe$PixH == #screen_h &&
                   |pipe$PixV == #screen_v &&
                   |pipe$done_pix) ?
                     |pipe>>1$color_index :
                     $RETAIN;
               *-/
               \viz_alpha
                  initEach() {
                     let rect = new fabric.Rect({
                        width: M4_VIZ_CELL_SIZE,
                        height: M4_VIZ_CELL_SIZE,
                        fill: "green",
                        left: scopes.screen_h.index * M4_VIZ_CELL_SIZE,
                        top: 2 + scopes.screen_v.index * M4_VIZ_CELL_SIZE
                     })
                     global.canvas.add(rect)
                     return {rect: rect}
                  },
                  renderEach() {
                     let background = "#" + (Math.floor('$color_index'.asInt() / 4) % 10) + "0" + ('$color_index'.asInt() % 4) * 3  + "000"
                     context.initEach.rect.set("fill", background)
                  }
      /*
      @0
         // Screen array write (fast approach).
         $wr = |pipe$done_pix;
         \always_comb
            if ($wr) begin
               /screen_v[|pipe$PixV]/screen_h[|pipe$PixH]$$color_index[\$clog2(M4_MAX_DEPTH+1)-1:0] =
                  |pipe>>1$color_index;
            end
      */
   /**/
   \SV_plus
      logic [32:0] v1, v2;
      logic [32:0] out;
      always_comb begin
         v1 = 33'h140000000;
         v2 = 33'h040000000;
         out = real_to_fixed(-7.0); // fixed_mul(v1, v2);
         \$display("out \%b", out);
         
      end
   /**/
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = !clk || (|pipe>>1$wrap_v && |pipe>>1$wrap_h && |pipe>>1$done_pix) || *cyc_cnt > 1000000;
   *failed = !clk || 1'b0;

\SV
   endmodule
