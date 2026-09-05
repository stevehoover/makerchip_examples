\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   // 8-entry cosine LUT, scaled by 100:  100*cos(2*pi*idx/8), idx = 0..7
   macro(COS, ['(($1 == 3'd0) ? 32'sd100 : ($1 == 3'd1) ? 32'sd71 : ($1 == 3'd2) ? 32'sd0 : ($1 == 3'd3) ? -32'sd71 : ($1 == 3'd4) ? -32'sd100 : ($1 == 3'd5) ? -32'sd71 : ($1 == 3'd6) ? 32'sd0 : 32'sd71)'])
\SV
   // ============================================================
   // 8-Point Radix-2 Decimation-In-Time (DIT) FFT
   // ------------------------------------------------------------
   // A real cosine test frame x[n] = 100*cos(2*pi*k*n/8) is fed in.
   // The frequency bin k sweeps 0,1,2,3,4,... over time so you can
   // watch the spectral peak hop across the FFT output bins.
   //
   // The datapath is a fully-combinational 3-stage butterfly network
   // (log2(8) = 3 stages, 4 butterflies each). Twiddle factors are
   // fixed-point, scaled by 64:  W8^1 ~ (45,-45)/64, W8^2 = -j, etc.
   // Visual Debug draws the input, the butterfly dataflow, and the
   // resulting magnitude spectrum.
   // ============================================================
   m5_makerchip_module
\TLV
   /top
      |calc
         @1
            // ---------- frequency-sweep control ----------
            // Hold each frequency bin for 12 cycles, then advance k: 0..4 and wrap.
            $sub_cnt[5:0] = *reset ? 6'd0 : (>>1$sub_cnt == 6'd11) ? 6'd0 : >>1$sub_cnt + 6'd1;
            $k[5:0] = *reset ? 6'd1 :
                      (>>1$sub_cnt == 6'd11) ? ((>>1$k == 6'd4) ? 6'd0 : >>1$k + 6'd1) :
                                               >>1$k;

            // ---------- phase indices  (k*n) mod 8 ----------
            $p1[5:0] = $k * 6'd1;
            $idx1[2:0] = $p1[2:0];
            $p2[5:0] = $k * 6'd2;
            $idx2[2:0] = $p2[2:0];
            $p3[5:0] = $k * 6'd3;
            $idx3[2:0] = $p3[2:0];
            $p4[5:0] = $k * 6'd4;
            $idx4[2:0] = $p4[2:0];
            $p5[5:0] = $k * 6'd5;
            $idx5[2:0] = $p5[2:0];
            $p6[5:0] = $k * 6'd6;
            $idx6[2:0] = $p6[2:0];
            $p7[5:0] = $k * 6'd7;
            $idx7[2:0] = $p7[2:0];

            // ---------- time-domain input samples (natural order) ----------
            $x0[31:0] = 32'sd100;
            $x1[31:0] = m5_COS($idx1);
            $x2[31:0] = m5_COS($idx2);
            $x3[31:0] = m5_COS($idx3);
            $x4[31:0] = m5_COS($idx4);
            $x5[31:0] = m5_COS($idx5);
            $x6[31:0] = m5_COS($idx6);
            $x7[31:0] = m5_COS($idx7);

            // ---------- Stage 0: bit-reversed input load (im = 0) ----------
            $a0_re[31:0] = $x0;
            $a1_re[31:0] = $x4;
            $a2_re[31:0] = $x2;
            $a3_re[31:0] = $x6;
            $a4_re[31:0] = $x1;
            $a5_re[31:0] = $x5;
            $a6_re[31:0] = $x3;
            $a7_re[31:0] = $x7;
            $a0_im[31:0] = 32'sd0;
            $a1_im[31:0] = 32'sd0;
            $a2_im[31:0] = 32'sd0;
            $a3_im[31:0] = 32'sd0;
            $a4_im[31:0] = 32'sd0;
            $a5_im[31:0] = 32'sd0;
            $a6_im[31:0] = 32'sd0;
            $a7_im[31:0] = 32'sd0;

            // ---------- Stage 1: 4 butterflies, all twiddle = W8^0 = 1 ----------
            $b0_re[31:0] = $a0_re + $a1_re;
            $b0_im[31:0] = $a0_im + $a1_im;
            $b1_re[31:0] = $a0_re - $a1_re;
            $b1_im[31:0] = $a0_im - $a1_im;
            $b2_re[31:0] = $a2_re + $a3_re;
            $b2_im[31:0] = $a2_im + $a3_im;
            $b3_re[31:0] = $a2_re - $a3_re;
            $b3_im[31:0] = $a2_im - $a3_im;
            $b4_re[31:0] = $a4_re + $a5_re;
            $b4_im[31:0] = $a4_im + $a5_im;
            $b5_re[31:0] = $a4_re - $a5_re;
            $b5_im[31:0] = $a4_im - $a5_im;
            $b6_re[31:0] = $a6_re + $a7_re;
            $b6_im[31:0] = $a6_im + $a7_im;
            $b7_re[31:0] = $a6_re - $a7_re;
            $b7_im[31:0] = $a6_im - $a7_im;

            // ---------- Stage 2: twiddles W8^0 and W8^2 = -j ----------
            // pair (0,2): W^0
            $c0_re[31:0] = $b0_re + $b2_re;
            $c0_im[31:0] = $b0_im + $b2_im;
            $c2_re[31:0] = $b0_re - $b2_re;
            $c2_im[31:0] = $b0_im - $b2_im;
            // pair (1,3): W^2 = -j  ->  -j*(re + j*im) = im - j*re
            $c1_re[31:0] = $b1_re + $b3_im;
            $c1_im[31:0] = $b1_im - $b3_re;
            $c3_re[31:0] = $b1_re - $b3_im;
            $c3_im[31:0] = $b1_im + $b3_re;
            // pair (4,6): W^0
            $c4_re[31:0] = $b4_re + $b6_re;
            $c4_im[31:0] = $b4_im + $b6_im;
            $c6_re[31:0] = $b4_re - $b6_re;
            $c6_im[31:0] = $b4_im - $b6_im;
            // pair (5,7): W^2 = -j
            $c5_re[31:0] = $b5_re + $b7_im;
            $c5_im[31:0] = $b5_im - $b7_re;
            $c7_re[31:0] = $b5_re - $b7_im;
            $c7_im[31:0] = $b5_im + $b7_re;

            // ---------- Stage 3: full twiddles W8^0, W8^1, W8^2, W8^3 ----------
            // Complex multiply t = W*c, then top = c_top + t, bottom = c_top - t.
            // W8^1 = (45,-45)/64 applied to c5:
            $t15_re[31:0] = (32'sd45 * \$signed($c5_re) + 32'sd45 * \$signed($c5_im)) / 32'sd64;
            $t15_im[31:0] = (32'sd45 * \$signed($c5_im) - 32'sd45 * \$signed($c5_re)) / 32'sd64;
            // W8^3 = (-45,-45)/64 applied to c7:
            $t37_re[31:0] = (-32'sd45 * \$signed($c7_re) + 32'sd45 * \$signed($c7_im)) / 32'sd64;
            $t37_im[31:0] = (-32'sd45 * \$signed($c7_im) - 32'sd45 * \$signed($c7_re)) / 32'sd64;

            // pair (0,4): W^0  -> outputs X[0], X[4]
            $d0_re[31:0] = $c0_re + $c4_re;
            $d0_im[31:0] = $c0_im + $c4_im;
            $d4_re[31:0] = $c0_re - $c4_re;
            $d4_im[31:0] = $c0_im - $c4_im;
            // pair (1,5): W^1  -> outputs X[1], X[5]
            $d1_re[31:0] = $c1_re + $t15_re;
            $d1_im[31:0] = $c1_im + $t15_im;
            $d5_re[31:0] = $c1_re - $t15_re;
            $d5_im[31:0] = $c1_im - $t15_im;
            // pair (2,6): W^2 = -j -> outputs X[2], X[6]
            $d2_re[31:0] = $c2_re + $c6_im;
            $d2_im[31:0] = $c2_im - $c6_re;
            $d6_re[31:0] = $c2_re - $c6_im;
            $d6_im[31:0] = $c2_im + $c6_re;
            // pair (3,7): W^3  -> outputs X[3], X[7]
            $d3_re[31:0] = $c3_re + $t37_re;
            $d3_im[31:0] = $c3_im + $t37_im;
            $d7_re[31:0] = $c3_re - $t37_re;
            $d7_im[31:0] = $c3_im - $t37_im;

            \viz_js
               box: {left: 0, top: 0, width: 1180, height: 800, fill: "#0d1017", stroke: "#2b2f3a", strokeWidth: 2},
               render() {
                  let objs = []
                  const sgn = (v) => v >= 2147483648 ? v - 4294967296 : v
                  const R = (p) => sgn(p.asInt(0))

                  // ---- read every stage's real/imag values ----
                  let aRe = [R('/top|calc>>0$a0_re'), R('/top|calc>>0$a1_re'), R('/top|calc>>0$a2_re'), R('/top|calc>>0$a3_re'), R('/top|calc>>0$a4_re'), R('/top|calc>>0$a5_re'), R('/top|calc>>0$a6_re'), R('/top|calc>>0$a7_re')]
                  let aIm = [0, 0, 0, 0, 0, 0, 0, 0]
                  let bRe = [R('/top|calc>>0$b0_re'), R('/top|calc>>0$b1_re'), R('/top|calc>>0$b2_re'), R('/top|calc>>0$b3_re'), R('/top|calc>>0$b4_re'), R('/top|calc>>0$b5_re'), R('/top|calc>>0$b6_re'), R('/top|calc>>0$b7_re')]
                  let bIm = [R('/top|calc>>0$b0_im'), R('/top|calc>>0$b1_im'), R('/top|calc>>0$b2_im'), R('/top|calc>>0$b3_im'), R('/top|calc>>0$b4_im'), R('/top|calc>>0$b5_im'), R('/top|calc>>0$b6_im'), R('/top|calc>>0$b7_im')]
                  let cRe = [R('/top|calc>>0$c0_re'), R('/top|calc>>0$c1_re'), R('/top|calc>>0$c2_re'), R('/top|calc>>0$c3_re'), R('/top|calc>>0$c4_re'), R('/top|calc>>0$c5_re'), R('/top|calc>>0$c6_re'), R('/top|calc>>0$c7_re')]
                  let cIm = [R('/top|calc>>0$c0_im'), R('/top|calc>>0$c1_im'), R('/top|calc>>0$c2_im'), R('/top|calc>>0$c3_im'), R('/top|calc>>0$c4_im'), R('/top|calc>>0$c5_im'), R('/top|calc>>0$c6_im'), R('/top|calc>>0$c7_im')]
                  let dRe = [R('/top|calc>>0$d0_re'), R('/top|calc>>0$d1_re'), R('/top|calc>>0$d2_re'), R('/top|calc>>0$d3_re'), R('/top|calc>>0$d4_re'), R('/top|calc>>0$d5_re'), R('/top|calc>>0$d6_re'), R('/top|calc>>0$d7_re')]
                  let dIm = [R('/top|calc>>0$d0_im'), R('/top|calc>>0$d1_im'), R('/top|calc>>0$d2_im'), R('/top|calc>>0$d3_im'), R('/top|calc>>0$d4_im'), R('/top|calc>>0$d5_im'), R('/top|calc>>0$d6_im'), R('/top|calc>>0$d7_im')]
                  let xN  = [R('/top|calc>>0$x0'), R('/top|calc>>0$x1'), R('/top|calc>>0$x2'), R('/top|calc>>0$x3'), R('/top|calc>>0$x4'), R('/top|calc>>0$x5'), R('/top|calc>>0$x6'), R('/top|calc>>0$x7')]
                  let k = '/top|calc>>0$k'.asInt(0)

                  let cols = [{re: aRe, im: aIm}, {re: bRe, im: bIm}, {re: cRe, im: cIm}, {re: dRe, im: dIm}]
                  let mag = (re, im) => Math.sqrt(re * re + im * im)
                  let allMag = []
                  cols.forEach(c => { for (let i = 0; i < 8; i++) allMag.push(mag(c.re[i], c.im[i])) })
                  let gmax = Math.max(1, ...allMag)
                  let colr = (m) => { let t = Math.min(1, m / gmax); let h = 210 - 210 * t; let l = 30 + t * 35; return `hsl(${h},85%,${l}%)` }

                  // ---- geometry ----
                  let cx = [330, 520, 710, 900]
                  let topY = 175, rowH = 52
                  let ny = (i) => topY + i * rowH

                  // ---- title ----
                  objs.push(new fabric.Text("8-Point Radix-2 DIT FFT", {left: 20, top: 12, fontSize: 22, fontFamily: "Helvetica", fill: "#e6e6e6"}))
                  objs.push(new fabric.Text(`input frequency bin  k = ${k}`, {left: 640, top: 40, fontSize: 15, fontFamily: "Helvetica", fill: "#ffcf6b"}))
                  objs.push(new fabric.Text(`\u21d2 spectral peaks expected at bins ${k % 8} and ${(8 - k) % 8}`, {left: 640, top: 62, fontSize: 13, fontFamily: "Helvetica", fill: "#9aa4b6"}))

                  // ---- time-domain input waveform (natural order) ----
                  let ix0 = 40, iw = 250, imy = 95, ia = 0.30
                  objs.push(new fabric.Text("time-domain input   x[n] = cos(2\u03c0\u00b7k\u00b7n/8)", {left: ix0, top: 30, fontSize: 13, fontFamily: "Helvetica", fill: "#9aa4b6"}))
                  objs.push(new fabric.Line([ix0, imy, ix0 + iw, imy], {stroke: "#39404e", strokeWidth: 1}))
                  let pts = []
                  for (let n = 0; n < 8; n++) {
                     let px = ix0 + n * (iw / 7)
                     let py = imy - xN[n] * ia
                     pts.push([px, py])
                     objs.push(new fabric.Line([px, imy, px, py], {stroke: "#5aa9e6", strokeWidth: 1}))
                     objs.push(new fabric.Circle({left: px - 3, top: py - 3, radius: 3, fill: "#5aa9e6"}))
                  }
                  for (let n = 0; n < 7; n++) {
                     objs.push(new fabric.Line([pts[n][0], pts[n][1], pts[n + 1][0], pts[n + 1][1]], {stroke: "#5aa9e6", strokeWidth: 1.5}))
                  }

                  // ---- butterfly dataflow ----
                  objs.push(new fabric.Text("butterfly dataflow (decimation-in-time)", {left: 330, top: 130, fontSize: 13, fontFamily: "Helvetica", fill: "#9aa4b6"}))
                  let heads = ["x[n] (bit-rev)", "stage 1", "stage 2", "X[k] (output)"]
                  for (let s = 0; s < 4; s++) {
                     objs.push(new fabric.Text(heads[s], {left: cx[s], top: 152, originX: "center", fontSize: 12, fontFamily: "Helvetica", fill: "#7f8a9e"}))
                  }

                  let stages = [
                     {pairs: [[0, 1], [2, 3], [4, 5], [6, 7]], tw: [0, 0, 0, 0]},
                     {pairs: [[0, 2], [1, 3], [4, 6], [5, 7]], tw: [0, 2, 0, 2]},
                     {pairs: [[0, 4], [1, 5], [2, 6], [3, 7]], tw: [0, 1, 2, 3]}
                  ]
                  // edges + twiddle labels (drawn under the nodes)
                  for (let s = 0; s < 3; s++) {
                     let Lx = cx[s], Rx = cx[s + 1]
                     stages[s].pairs.forEach((pr, pi) => {
                        let t = pr[0], b = pr[1]
                        let yt = ny(t), yb = ny(b)
                        let segs = [[Lx, yt, Rx, yt], [Lx, yb, Rx, yt], [Lx, yt, Rx, yb], [Lx, yb, Rx, yb]]
                        segs.forEach(sg => objs.push(new fabric.Line(sg, {stroke: "#39404e", strokeWidth: 1})))
                        let tw = stages[s].tw[pi]
                        if (tw > 0) {
                           let sup = tw === 1 ? "\u00b9" : tw === 2 ? "\u00b2" : "\u00b3"
                           objs.push(new fabric.Text("W" + sup, {left: (Lx + Rx) / 2, top: (yt + yb) / 2 - 8, originX: "center", fontSize: 13, fontFamily: "Georgia", fill: "#ffcf6b"}))
                        }
                     })
                  }
                  // nodes
                  for (let s = 0; s < 4; s++) {
                     for (let i = 0; i < 8; i++) {
                        let m = mag(cols[s].re[i], cols[s].im[i])
                        objs.push(new fabric.Circle({left: cx[s] - 9, top: ny(i) - 9, radius: 9, fill: colr(m), stroke: "#0d1017", strokeWidth: 1}))
                     }
                  }
                  // input values (left of column 0)
                  for (let i = 0; i < 8; i++) {
                     objs.push(new fabric.Text(String(aRe[i]), {left: cx[0] - 18, top: ny(i) - 7, originX: "right", fontSize: 12, fontFamily: "Courier New", fill: "#c9d1e0"}))
                  }
                  // output values (right of column 3)
                  for (let i = 0; i < 8; i++) {
                     let re = dRe[i], im = dIm[i], m = Math.round(mag(re, im))
                     let sign = im >= 0 ? "+" : "\u2212"
                     objs.push(new fabric.Text(`X[${i}] = ${re} ${sign} ${Math.abs(im)}j   |X|=${m}`, {left: cx[3] + 18, top: ny(i) - 7, originX: "left", fontSize: 11, fontFamily: "Courier New", fill: "#c9d1e0"}))
                  }

                  // ---- magnitude spectrum ----
                  let dMag = dRe.map((re, i) => mag(re, dIm[i]))
                  let mm = Math.max(1, ...dMag)
                  let sx0 = 120, sBW = 125, base = 770, sH = 120
                  objs.push(new fabric.Text("magnitude spectrum   |X[k]|", {left: sx0 - 20, top: base - sH - 34, fontSize: 14, fontFamily: "Helvetica", fill: "#e6e6e6"}))
                  objs.push(new fabric.Line([sx0 - 20, base, sx0 + 7 * sBW + 90, base], {stroke: "#39404e", strokeWidth: 1}))
                  for (let i = 0; i < 8; i++) {
                     let h = dMag[i] / mm * sH
                     let left = sx0 + i * sBW
                     let isPk = (i === k % 8 || i === (8 - k) % 8)
                     objs.push(new fabric.Rect({left: left, top: base - h, width: 70, height: h, fill: isPk ? "#ff8c42" : "#3f7fb5", rx: 3, ry: 3}))
                     objs.push(new fabric.Text(String(i), {left: left + 35, top: base + 6, originX: "center", fontSize: 13, fontFamily: "Helvetica", fill: "#9aa4b6"}))
                     objs.push(new fabric.Text(String(Math.round(dMag[i])), {left: left + 35, top: base - h - 16, originX: "center", fontSize: 12, fontFamily: "Courier New", fill: "#c9d1e0"}))
                  }

                  return objs
               }

   *passed = *cyc_cnt > 250;
   *failed = 1'b0;
\SV
   endmodule
