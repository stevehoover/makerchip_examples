\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   
   // ================================================================
   // N-body gravitational simulation, with Visual Debug.
   //
   // Fixed-point integer physics, one simulation step per clock cycle.
   //   - Positions: 32-bit, units of 1/256 pixel; world is 512x512 pixels
   //     (0..131071 position units).
   //   - Velocities: 32-bit, in position units; x += vx >>> 6 per cycle.
   //   - Gravity: for each pair, a += (dx * G * mass_other / MASS_NOM) /
   //     (dx^2 + dy^2 + SOFT), G = 2^25, SOFT = 2^24. (Force falls off as
   //     1/r; softened; not strictly Newtonian, but visually pleasing and
   //     division-friendly.)
   //   - Per-body mass is randomized at reset: 16..47, nominal/mean 32
   //     (MASS_NOM), so a body of nominal mass reproduces the original
   //     (pre-mass) gravity strength. Mass only affects the body's pull
   //     on OTHERS, as in real gravity (acceleration is independent of
   //     the receiving body's own mass).
   //   - Gravity-sum scaling with N: summing N-1 roughly-independent
   //     pairwise pulls gives a resultant whose *typical* magnitude
   //     grows like sqrt(N) (random-walk/CLT scaling), not like N. So
   //     the summed gravity term is right-shifted by GSHIFT bits, where
   //     2^GSHIFT is the largest power of 2 not exceeding sqrt(N)
   //     (computed once at compile time from N; a plain 1/N scale would
   //     over-correct and make gravity vanish for large N).
   //   - A weak pull toward the world center ((C - x) >>> 13) and mild
   //     velocity damping (v -= v >>> 11) keep the system bounded.
   //   - Semi-implicit Euler integration (velocity updates first).
   //   - Initial positions/velocities/masses are randomized (via
   //     SandPiper's built-in m4_rand) at reset, independently per body,
   //     so the design is not tied to a fixed table and generalizes to
   //     any N.
   //
   // Note on rounding: SystemVerilog's signed >>> is a FLOOR operation
   // (rounds toward -infinity) for both positive and negative operands,
   // not round-toward-zero. Applied uniformly to a value that's
   // sometimes positive and sometimes negative (as with the center-pull
   // and damping terms here), floor rounding is NOT symmetric in its
   // effect: it under-corrects a positive (rightward/downward) pull and
   // over-corrects a negative (leftward/upward) one, biasing the whole
   // system's equilibrium toward smaller x and smaller y -- i.e. toward
   // the upper-left of the world. Every arithmetic right-shift below
   // therefore adds a round-to-nearest correction (+2^(shift-1)) before
   // shifting, eliminating this bias.
   //
   // Note: Signed arithmetic-shift terms are computed in dedicated
   // pipesignals. (Embedded in a wider unsigned expression, SystemVerilog
   // signedness rules would demote >>> to a logical shift.)
   var(N, 10)
   // GSHIFT: floor(log4(N)), i.e. 2^GSHIFT is the largest power of 2 not
   // exceeding sqrt(N). Extend the ifelse chain with more m5_if levels
   // (thresholds 4^k) if N can exceed 63.
   var(GSHIFT, m5_if(m5_calc(m5_N >= 64), 3,
                 m5_if(m5_calc(m5_N >= 16), 2,
                   m5_if(m5_calc(m5_N >= 4), 1, 0))))
   // Rounding constant for a >>> GSHIFT shift: 2^(GSHIFT-1), or 0 if
   // GSHIFT is 0 (no shift, no rounding needed).
   var(GROUND, m5_if(m5_calc(m5_GSHIFT == 0), 0,
                 m5_if(m5_calc(m5_GSHIFT == 1), 1,
                   m5_if(m5_calc(m5_GSHIFT == 2), 2, 4))))
\SV
   m5_makerchip_module
\TLV
   /body[m5_calc(m5_N - 1):0]
      // ---- Initial conditions: randomized at reset. ----
      // Position: uniform in the central half of the world in each axis
      // (128..384 px), i.e. quarter- to three-quarter-world.
      m4_rand($rand_x, 15, 0, body)
      m4_rand($rand_y, 15, 0, body)
      // Velocity: uniform in [-1024, 1023] (position units/cycle).
      m4_rand($rand_vx, 10, 0, body)
      m4_rand($rand_vy, 10, 0, body)
      // Mass: uniform in [16, 47] (mean/nominal 32 == MASS_NOM).
      m4_rand($rand_mass, 4, 0, body)
      $init_x[31:0] = {16'b0, $rand_x} + 32'd32768;
      $init_y[31:0] = {16'b0, $rand_y} + 32'd32768;
      $init_vx[31:0] = {{21{$rand_vx[10]}}, $rand_vx} - 32'd1024;
      $init_vy[31:0] = {{21{$rand_vy[10]}}, $rand_vy} - 32'd1024;
      $init_mass[7:0] = {3'b0, $rand_mass} + 8'd16;
      // Mass is captured at reset and held constant thereafter, same
      // pattern as position/velocity.
      $mass[7:0] = *reset ? $init_mass : >>1$mass;
      
      // ---- Pairwise interactions (from previous-cycle positions) ----
      /other[m5_calc(m5_N - 1):0]
         $dx[31:0] = /body[#other]>>1$xx - /body[#body]>>1$xx;
         $dy[31:0] = /body[#other]>>1$yy - /body[#body]>>1$yy;
         // Squared distance, softened. (Self-pairs contribute zero force.)
         $dist2[63:0] = signed'($dx) * signed'($dx) + signed'($dy) * signed'($dy) + 64'sh0100_0000;
         // Source body's mass, zero-extended (always non-negative, so a
         // signed cast below is safe).
         $mass_ext[31:0] = {24'b0, /body[#other]>>1$mass};
         $ax_raw[63:0] = (signed'($dx) * signed'($mass_ext) * 64'sh0200_0000) / signed'($dist2);
         $ay_raw[63:0] = (signed'($dy) * signed'($mass_ext) * 64'sh0200_0000) / signed'($dist2);
         // Normalize by nominal mass (32 == 2^5), round-to-nearest.
         $ax_term[63:0] = signed'($ax_raw + 64'd16) >>> 5;
         $ay_term[63:0] = signed'($ay_raw + 64'd16) >>> 5;
      
      // ---- Acceleration: gravity sum (N-scaled) + weak center pull ----
      // (Both round-to-nearest; see rounding note above.)
      $cpull_x[31:0] = signed'(32'd65536 - >>1$xx + 32'd4096) >>> 13;
      $cpull_y[31:0] = signed'(32'd65536 - >>1$yy + 32'd4096) >>> 13;
      $grav_sum_x[31:0] = m5_repeat(m5_N, ['/other[m5_LoopCnt]$ax_term[31:0] + '])32'd0;
      $grav_sum_y[31:0] = m5_repeat(m5_N, ['/other[m5_LoopCnt]$ay_term[31:0] + '])32'd0;
      $grav_x[31:0] = signed'($grav_sum_x + m5_GROUND) >>> m5_GSHIFT;
      $grav_y[31:0] = signed'($grav_sum_y + m5_GROUND) >>> m5_GSHIFT;
      $ax[31:0] = $grav_x + $cpull_x;
      $ay[31:0] = $grav_y + $cpull_y;
      
      // ---- Integration (semi-implicit Euler, with mild damping) ----
      $damp_x[31:0] = signed'(>>1$vx + 32'd1024) >>> 11;
      $damp_y[31:0] = signed'(>>1$vy + 32'd1024) >>> 11;
      $vx[31:0] = *reset ? $init_vx : >>1$vx + $ax - $damp_x;
      $vy[31:0] = *reset ? $init_vy : >>1$vy + $ay - $damp_y;
      $step_x[31:0] = signed'($vx + 32'd32) >>> 6;
      $step_y[31:0] = signed'($vy + 32'd32) >>> 6;
      $xx[31:0] = *reset ? $init_x  : >>1$xx + $step_x;
      $yy[31:0] = *reset ? $init_y  : >>1$yy + $step_y;
      
      // ---- Visualization: one dot (+ trail + velocity vector) per body,
      //      all instances overlaid on the shared arena. Dot radius
      //      reflects the body's (randomized) mass. ----
      \viz_js
         box: {left: 0, top: 0, width: 512, height: 512, strokeWidth: 0},
         layout: {left: 0, top: 0},
         init() {
            let colors = ["rgb(255,120,90)", "rgb(90,200,255)", "rgb(255,220,90)", "rgb(160,255,120)", "rgb(230,140,255)"]
            let color = colors[this.getIndex() % colors.length]
            let ret = {}
            for (let k = 6; k >= 1; k--) {
               ret["trail" + k] = new fabric.Circle({
                  left: -100, top: -100, radius: 2.5, fill: color,
                  opacity: 0.55 - k * 0.08, strokeWidth: 0,
                  originX: "center", originY: "center"})
            }
            ret.vel = new fabric.Line([-100, -100, -100, -100], {
               stroke: color, strokeWidth: 1.5, opacity: 0.7})
            ret.dot = new fabric.Circle({
               left: -100, top: -100, radius: 7, fill: color, strokeWidth: 0,
               originX: "center", originY: "center"})
            ret.label = new fabric.Text(this.getIndex().toString(), {
               left: -100, top: -100, fontSize: 9, fill: "rgb(10,10,30)",
               fontFamily: "monospace", originX: "center", originY: "center"})
            return ret
         },
         render() {
            let toPx = (v) => {
               if (v > 0x7FFFFFFF) {
                  v -= 0x100000000
               }
               return v / 256
            }
            let xSig = '$xx'
            let ySig = '$yy'
            let x = toPx(xSig.asInt())
            let y = toPx(ySig.asInt())
            // Velocity vector, scaled to ~20 cycles of motion.
            let vx = toPx('$vx'.asInt()) * 20 / 64
            let vy = toPx('$vy'.asInt()) * 20 / 64
            // Mass 16..47 -> radius 4..10.2.
            let mass = '$mass'.asInt()
            let radius = 4 + (mass - 16) * 0.2
            this.obj.dot.set({left: x, top: y, radius: radius})
            this.obj.label.set({left: x, top: y})
            this.obj.vel.set({x1: x, y1: y, x2: x + vx, y2: y + vy})
            // Trail: positions 8, 16, ... 48 cycles in the past.
            let stepped = 0
            for (let k = 1; k <= 6; k++) {
               xSig.step(-8)
               ySig.step(-8)
               stepped += 8
               let tx = toPx(xSig.asInt())
               let ty = toPx(ySig.asInt())
               if (isNaN(tx) || isNaN(ty)) {
                  tx = -100
                  ty = -100
               }
               this.obj["trail" + k].set({left: tx, top: ty})
            }
            xSig.step(stepped)
            ySig.step(stepped)
         }
   
   // The arena.
   \viz_js
      box: {left: 0, top: 0, width: 512, height: 512,
            stroke: "rgb(110,110,140)", strokeWidth: 2, fill: "rgb(10,12,26)"},
      init() {
         return {
            title: new fabric.Text("N-Body Gravity", {
               left: 10, top: 8, fill: "rgb(190,190,215)",
               fontFamily: "monospace", fontSize: 15}),
            center: new fabric.Circle({
               left: 256, top: 256, radius: 2, fill: "rgb(90,90,120)",
               strokeWidth: 0, originX: "center", originY: "center"})
         }
      },
      where: {left: 0, top: 0}
   
   *passed = *cyc_cnt > 600;
   *failed = 1'b0;
\SV
   endmodule