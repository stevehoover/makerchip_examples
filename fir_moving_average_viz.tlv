\m5_TLV_version 1d: tl-x.org
\m5

\SV
   m5_makerchip_module
\TLV
   // ============================================================
   // 8-Tap Moving-Average FIR Filter
   // ------------------------------------------------------------
   // A "clean" sine wave (16-entry LUT) is corrupted with pseudo-
   // random noise from an 8-bit LFSR to form a noisy input stream.
   // An 8-tap moving-average filter (a simple FIR) smooths it.
   // VIZ overlays the noisy input against the filtered output as
   // scrolling waveforms.
   // ============================================================

   /top
      |calc
         @1
            // Phase index for the sine LUT (period = 16 cycles).
            $phase[3:0] = *reset ? 4'd0 : >>1$phase + 4'd1;

            // 16-entry sine LUT, amplitude ~ +/-127 centered at 128.
            $clean[7:0] =
               ($phase == 4'd0)  ? 8'd128 :
               ($phase == 4'd1)  ? 8'd177 :
               ($phase == 4'd2)  ? 8'd218 :
               ($phase == 4'd3)  ? 8'd245 :
               ($phase == 4'd4)  ? 8'd255 :
               ($phase == 4'd5)  ? 8'd245 :
               ($phase == 4'd6)  ? 8'd218 :
               ($phase == 4'd7)  ? 8'd177 :
               ($phase == 4'd8)  ? 8'd128 :
               ($phase == 4'd9)  ? 8'd79  :
               ($phase == 4'd10) ? 8'd38  :
               ($phase == 4'd11) ? 8'd11  :
               ($phase == 4'd12) ? 8'd1   :
               ($phase == 4'd13) ? 8'd11  :
               ($phase == 4'd14) ? 8'd38  :
                                   8'd79;

            // 8-bit LFSR (taps x^8 + x^6 + x^5 + x^4) for noise.
            $lfsr[7:0] = *reset ? 8'hA5 :
                         {>>1$lfsr[6:0], >>1$lfsr[7] ^ >>1$lfsr[5] ^ >>1$lfsr[4] ^ >>1$lfsr[3]};

            // Noisy input = clean + noise(0..31) - 16, clamped to 0..255.
            $noisy[9:0] = $clean + $lfsr[4:0];
            $in_adj[9:0] = $noisy - 10'd16;
            $in[7:0] = ($noisy < 10'd16)  ? 8'd0 :
                       ($noisy > 10'd271) ? 8'd255 :
                                            $in_adj[7:0];

            // 8-tap moving average using the pipeline's own history.
            $sum[10:0] = $in + >>1$in + >>2$in + >>3$in +
                         >>4$in + >>5$in + >>6$in + >>7$in;
            $out[7:0] = $sum[10:3];   // divide by 8

      \viz_js
         box: {left: -40, top: -70, width: 620, height: 340, fill: "#0f1117", stroke: "#2b2f3a", strokeWidth: 2},
         init() {
            let W = 512, H = 200, top = 24
            return {
               title: new fabric.Text("8-Tap Moving-Average FIR", {
                  left: -20, top: -56, fontSize: 22, fontFamily: "Helvetica", fill: "#e6e6e6"
               }),
               subtitle: new fabric.Text("noisy sine  ->  smoothed output", {
                  left: -20, top: -30, fontSize: 14, fontFamily: "Helvetica", fill: "#8a90a0"
               }),
               legendIn: new fabric.Text("input (noisy)", {
                  left: 360, top: -56, fontSize: 14, fontFamily: "Helvetica", fill: "#ff6b6b"
               }),
               legendOut: new fabric.Text("output (filtered)", {
                  left: 360, top: -34, fontSize: 14, fontFamily: "Helvetica", fill: "#4dd0e1"
               }),
               baseline: new fabric.Line([0, top + H, W, top + H], {stroke: "#3a3f4b", strokeWidth: 1}),
               midline: new fabric.Line([0, top + H / 2, W, top + H / 2], {stroke: "#22262f", strokeWidth: 1, strokeDashArray: [4, 4]})
            }
         },
         render() {
            let N = 64, W = 512, H = 200, top = 24
            let sIn = '/top|calc>>1$in'
            let sOut = '/top|calc>>1$out'
            let px = [], pin = [], pout = []
            for (let i = 0; i < N; i++) {
               // i = 0 is the newest sample -> rightmost.
               let x = W - (i * W / (N - 1))
               px.push(x)
               pin.push(top + H - (sIn.asInt(128) * H / 255))
               pout.push(top + H - (sOut.asInt(128) * H / 255))
               sIn.step(-1)
               sOut.step(-1)
            }
            let objs = []
            for (let j = 0; j < N - 1; j++) {
               objs.push(new fabric.Line([px[j], pin[j], px[j + 1], pin[j + 1]], {
                  stroke: "#ff6b6b", strokeWidth: 1
               }))
            }
            for (let j = 0; j < N - 1; j++) {
               objs.push(new fabric.Line([px[j], pout[j], px[j + 1], pout[j + 1]], {
                  stroke: "#4dd0e1", strokeWidth: 2
               }))
            }
            let curIn = '/top|calc>>1$in'.asInt(0)
            let curOut = '/top|calc>>1$out'.asInt(0)
            objs.push(new fabric.Text(`in=${curIn}   out=${curOut}`, {
               left: -20, top: 250, fontSize: 14, fontFamily: "Courier New", fill: "#a0a0a0"
            }))
            return objs
         },
         where: {left: 0, top: 0, width: 10, height: 10}

   *passed = *cyc_cnt > 300;
   *failed = 1'b0;

\SV
   endmodule
