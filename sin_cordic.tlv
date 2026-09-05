\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   / ------------------------------------------------------------------
   / CORDIC sine/cosine generator (rotation mode).
   /
   / A pipeline of N rotations drives the angle error toward zero.  The
   / seed vector (K, 0) is pre-scaled by the CORDIC gain so that the
   / final vector lands on the unit circle: x -> cos(theta), y -> sin(theta).
   / All values are Q16 signed fixed-point (1.0 == 65536).
   / ------------------------------------------------------------------
   / N: CORDIC rotations.  K: 1/gain in Q16 (~0.607253).
   / HALF_PI/PI/TWO_PI: angle constants in Q16.  STEP: sweep increment (~2*pi/64).
   var(N, 16)
   var(K, 39798)
   var(HALF_PI, 102944)
   var(PI, 205887)
   var(TWO_PI, 411775)
   var(STEP, 6434)
\SV
   m5_makerchip_module
   // atan(2^-i) in Q16 fixed-point, for i = 0 .. 15.
   function automatic [23:0] atan_q16(input [4:0] i);
      case (i)
        5'd0 : atan_q16 = 24'd51472;
        5'd1 : atan_q16 = 24'd30386;
        5'd2 : atan_q16 = 24'd16056;
        5'd3 : atan_q16 = 24'd8150;
        5'd4 : atan_q16 = 24'd4091;
        5'd5 : atan_q16 = 24'd2047;
        5'd6 : atan_q16 = 24'd1024;
        5'd7 : atan_q16 = 24'd512;
        5'd8 : atan_q16 = 24'd256;
        5'd9 : atan_q16 = 24'd128;
        5'd10: atan_q16 = 24'd64;
        5'd11: atan_q16 = 24'd32;
        5'd12: atan_q16 = 24'd16;
        5'd13: atan_q16 = 24'd8;
        5'd14: atan_q16 = 24'd4;
        default: atan_q16 = 24'd2;
      endcase
   endfunction
\TLV
   |sin
      @1
         $reset = *reset;

         // ---- Angle generator: sweep 0 .. 2*pi, wrapping. ----
         $angle_acc[23:0] =
            $reset                                       ? 24'd0 :
            (>>1$angle_acc + m5_STEP >= m5_TWO_PI)       ? (>>1$angle_acc + m5_STEP - m5_TWO_PI) :
                                                           (>>1$angle_acc + m5_STEP);
         // Re-center to signed (-pi, pi].
         $theta[23:0] = ($angle_acc > m5_PI) ? ($angle_acc - m5_TWO_PI) : $angle_acc;

         // ---- Quadrant reduction into CORDIC's convergent range [-pi/2, pi/2]. ----
         // For |theta| > pi/2 we rotate by pi (subtract/add pi) and negate the
         // result, since sin(t) = -sin(t -/+ pi) and cos(t) = -cos(t -/+ pi).
         $hi  = \$signed($theta) >  m5_HALF_PI;
         $lo  = \$signed($theta) < -m5_HALF_PI;
         $neg = $hi || $lo;
         $z0[23:0] = $hi ? (\$signed($theta) - m5_PI) :
                     $lo ? (\$signed($theta) + m5_PI) :
                            \$signed($theta);

         // ---- CORDIC seed vector (K, 0) with the reduced angle. ----
         $x_seed[23:0] = m5_K;
         $y_seed[23:0] = 24'd0;
         $z_seed[23:0] = $z0;

         // Add/subtract are
         // fine (2's-complement is sign-agnostic), so we keep plain adds and
         // implement the CORDIC arithmetic right-shift by hand with a logical
         // ">>" plus a sign-fill mask ($sh = #rot-1 bits of the sign at the top).
         // $z_neg selects rotation direction from the sign BIT of the residual angle.
         /rot[m5_N:0]
            $xp[23:0] = (#rot == 0) ? |sin$x_seed : /rot[#rot - 1]$x;
            $yp[23:0] = (#rot == 0) ? |sin$y_seed : /rot[#rot - 1]$y;
            $zp[23:0] = (#rot == 0) ? |sin$z_seed : /rot[#rot - 1]$z;
            $z_neg = (#rot == 0) ? 1'b0 : $zp[23];
            // Arithmetic right shift by (#rot-1): logical shift, then fill the
            // vacated top bits with the sign bit when the operand is negative.
            $xsh[23:0] = (#rot == 0) ? 24'd0 :
                         $xp[23] ? (($xp >> (#rot - 1)) | ~(24'hffffff >> (#rot - 1)))
                                 :  ($xp >> (#rot - 1));
            $ysh[23:0] = (#rot == 0) ? 24'd0 :
                         $yp[23] ? (($yp >> (#rot - 1)) | ~(24'hffffff >> (#rot - 1)))
                                 :  ($yp >> (#rot - 1));
            $x[23:0] = (#rot == 0) ? $xp : $z_neg ? ($xp + $ysh) : ($xp - $ysh);
            $y[23:0] = (#rot == 0) ? $yp : $z_neg ? ($yp - $xsh) : ($yp + $xsh);
            $z[23:0] = (#rot == 0) ? $zp :
                       $z_neg ? ($zp + atan_q16(#rot - 1)) : ($zp - atan_q16(#rot - 1));

         // ---- Results (Q16 signed): apply the quadrant sign fix-up. ----
         $sin_q16[23:0] = $neg ? -\$signed(/rot[m5_N]$y) : \$signed(/rot[m5_N]$y);
         $cos_q16[23:0] = $neg ? -\$signed(/rot[m5_N]$x) : \$signed(/rot[m5_N]$x);

         \viz_js
            box: {left: -290, top: -170, width: 610, height: 340, fill: "#0b1220"},
            render() {
               let objs = [];
               const s24 = v => (v >= (1 << 23) ? v - (1 << 24) : v);
               let sin = s24('$sin_q16'.asInt()) / 65536;
               let cos = s24('$cos_q16'.asInt()) / 65536;
               let th  = s24('$theta'.asInt())   / 65536;

               // Title.
               objs.push(new fabric.Text("CORDIC sin(\u03B8)", {
                  left: 20, top: -150, originX: "center",
                  fontSize: 22, fontFamily: "Playfair Display", fill: "#e6edf5"}));

               // ---- Left: unit circle with rotating vector. ----
               const cx = -170, cy = 0, R = 95;
               objs.push(new fabric.Circle({left: cx, top: cy, radius: R,
                  originX: "center", originY: "center",
                  fill: "", stroke: "#2b3d5c", strokeWidth: 1.5}));
               objs.push(new fabric.Line([cx - R, cy, cx + R, cy], {stroke: "#2b3d5c", strokeWidth: 1}));
               objs.push(new fabric.Line([cx, cy - R, cx, cy + R], {stroke: "#2b3d5c", strokeWidth: 1}));

               let dx = cx + R * cos, dy = cy - R * sin;
               objs.push(new fabric.Line([cx, cy, dx, dy], {stroke: "#ffcc44", strokeWidth: 2.5}));
               objs.push(new fabric.Line([dx, dy, cx, dy], {stroke: "#ff6688", strokeWidth: 1.5, strokeDashArray: [4, 3]}));
               objs.push(new fabric.Circle({left: dx, top: dy, radius: 5,
                  originX: "center", originY: "center", fill: "#ffcc44"}));

               // ---- CORDIC convergence: each /rot[k] stage's vector tip. ----
               // The pipeline unrolls the N rotations spatially, so all
               // intermediate vectors exist this cycle.  Plot their tips to show
               // the vector spiraling out (magnitude K -> 1) while the residual
               // angle drives to zero.  Apply the same quadrant sign fix-up used
               // for the final result so the path converges to the drawn vector.
               // Drawn last (on top of the result dot); each stage layered over
               // the previous, shrinking x2/3 and brightening from the circle's
               // shade toward bright blue so successive refinements stay distinct.
               const neg = '$neg'.asBool();
               const lerp = (a, b, t) => Math.round(a + (b - a) * t);
               const stageColor = t =>                    // #2b3d5c -> #bedeff
                  `rgb(${lerp(43, 190, t)}, ${lerp(61, 222, t)}, ${lerp(92, 255, t)})`;
               let ppt = null;
               let scale = 1;                             // shrinks x2/3 each stage
               for (let k = 0; k <= m5_N; k++) {
                  let xi = s24('/rot[k]$x'.asInt()) / 65536;
                  let yi = s24('/rot[k]$y'.asInt()) / 65536;
                  if (neg) { xi = -xi; yi = -yi; }
                  let kx = cx + R * xi, ky = cy - R * yi;
                  let col = stageColor(k / m5_N);
                  if (ppt) objs.push(new fabric.Line([ppt.x, ppt.y, kx, ky],
                     {stroke: col, strokeWidth: 1.8 * scale}));
                  ppt = {x: kx, y: ky};
                  if (k < m5_N) objs.push(new fabric.Circle({left: kx, top: ky, radius: 3.2 * scale,
                     originX: "center", originY: "center", fill: col}));
                  scale *= 2 / 3;
               }

               // ---- Right: reference sine curve (theta in -pi..pi) + moving dot. ----
               const x0 = -20, xw = 300, A = 90;
               let prev = null;
               for (let k = 0; k <= 64; k++) {
                  let t = -Math.PI + (2 * Math.PI) * k / 64;
                  let px = x0 + (t + Math.PI) / (2 * Math.PI) * xw;
                  let py = -A * Math.sin(t);
                  if (prev) objs.push(new fabric.Line([prev.x, prev.y, px, py], {stroke: "#33507a", strokeWidth: 1.5}));
                  prev = {x: px, y: py};
               }
               objs.push(new fabric.Line([x0, 0, x0 + xw, 0], {stroke: "#2b3d5c", strokeWidth: 1}));
               let mx = x0 + (th + Math.PI) / (2 * Math.PI) * xw;
               let my = -A * sin;
               objs.push(new fabric.Line([mx, 0, mx, my], {stroke: "#ff6688", strokeWidth: 1.5}));
               objs.push(new fabric.Circle({left: mx, top: my, radius: 5,
                  originX: "center", originY: "center", fill: "#ff6688"}));

               // ---- Readouts. ----
               objs.push(new fabric.Text(`\u03B8 = ${th.toFixed(3)} rad`, {
                  left: -20, top: 120, fontSize: 16, fontFamily: "Roboto", fill: "#9fb2c8"}));
               objs.push(new fabric.Text(`sin \u03B8 = ${sin.toFixed(4)}`, {
                  left: -20, top: 142, fontSize: 18, fontFamily: "Roboto", fill: "#ff6688"}));
               objs.push(new fabric.Text(`cos \u03B8 = ${cos.toFixed(4)}`, {
                  left: 150, top: 142, fontSize: 18, fontFamily: "Roboto", fill: "#ffcc44"}));
               // Legend for the CORDIC convergence path on the unit circle.
               objs.push(new fabric.Text(`\u2022 ${m5_N} CORDIC rotation stages`, {
                  left: -265, top: 118, fontSize: 12, fontFamily: "Roboto", fill: "#7ea6dd"}));
               return objs;
            },

   // Run for a couple of full sweeps, then stop.
   *passed = *cyc_cnt > 200;
\SV
   endmodule
