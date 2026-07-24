\m4_TLV_version 1d: tl-x.org
\m4
\SV
   // LFM Chirp Matched Filter -- a Moku:Go instrument.
   //
   // A matched filter maximizes SNR for a known pulse shape by correlating the
   // received signal against a time-reversed replica of the transmitted pulse.
   // Here the pulse is a Linear-Frequency-Modulated (LFM) "chirp": a sinusoid
   // whose frequency sweeps linearly across the pulse. Correlating an incoming
   // chirp against the matched taps produces a sharp peak when the pulse aligns
   // (pulse compression) -- the basis of radar/sonar ranging.
   //
   // This design instantiates the instrument in the first slot ("slot 0") of a
   // Moku:Go, leaving the other three slots empty. The instrument synthesizes a
   // periodic chirp burst as a self-test stimulus (added to any externally
   // routed $in_a), matched-filters it, and drives:
   //   $out_a = correlation output (a sharp peak once per period at alignment)
   //   $out_b = the chirp stimulus (scaled up for visibility)
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/moku_tlv_lib/fb953de/moku_lib.tlv'])

   // Macro providing required top-level module definition, random stimulus
   // support, and Verilator config.
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)

// LFM chirp matched-filter instrument (full instrument: drives $out_a and $out_b).
//   16-tap FIR whose coefficients are the time-reversed chirp replica.
//   Chirp: 16 samples, normalized frequency swept 0.06 -> 0.44 cycles/sample,
//          fixed-point amplitude 100.  sum(replica^2) = 80153, so the aligned
//          correlation peak is scaled down by >>2 to fit a signed 16-bit output.
\TLV lfm_chirp_matched_filter()
   // Repeating phase counter (period 32); the chirp burst occupies phases 0..15.
   $phase[4:0] = $reset ? 5'd0 : (>>1$phase == 5'd31 ? 5'd0 : >>1$phase + 5'd1);

   // Transmitted LFM chirp replica, injected as the demo stimulus for phases 0..15.
   $tx[15:0] =
      $reset ? 16'sd0 :
      ($phase == 5'd0) ? 16'sd100 :
      ($phase == 5'd1) ? 16'sd90 :
      ($phase == 5'd2) ? 16'sd48 :
      ($phase == 5'd3) ? (-16'sd27) :
      ($phase == 5'd4) ? (-16'sd94) :
      ($phase == 5'd5) ? (-16'sd74) :
      ($phase == 5'd6) ? 16'sd40 :
      ($phase == 5'd7) ? 16'sd97 :
      ($phase == 5'd8) ? (-16'sd25) :
      ($phase == 5'd9) ? (-16'sd92) :
      ($phase == 5'd10) ? 16'sd67 :
      ($phase == 5'd11) ? 16'sd35 :
      ($phase == 5'd12) ? (-16'sd96) :
      ($phase == 5'd13) ? 16'sd88 :
      ($phase == 5'd14) ? (-16'sd44) :
                          16'sd0;

   // Signal under test: injected chirp plus any externally routed input.
   $sig[15:0] = \$signed($tx) + \$signed($in_a);
   `BOGUS_USE($in_b)

   // FIR matched filter: correlate $sig against the time-reversed chirp replica.
   // Past samples x[n-k] come "for free" as >>k$sig in TL-Verilog.
   $acc[35:0] =
        (\$signed($sig) * 16'sd0)
      + (\$signed(>>1$sig) * (-16'sd44))
      + (\$signed(>>2$sig) * 16'sd88)
      + (\$signed(>>3$sig) * (-16'sd96))
      + (\$signed(>>4$sig) * 16'sd35)
      + (\$signed(>>5$sig) * 16'sd67)
      + (\$signed(>>6$sig) * (-16'sd92))
      + (\$signed(>>7$sig) * (-16'sd25))
      + (\$signed(>>8$sig) * 16'sd97)
      + (\$signed(>>9$sig) * 16'sd40)
      + (\$signed(>>10$sig) * (-16'sd74))
      + (\$signed(>>11$sig) * (-16'sd94))
      + (\$signed(>>12$sig) * (-16'sd27))
      + (\$signed(>>13$sig) * 16'sd48)
      + (\$signed(>>14$sig) * 16'sd90)
      + (\$signed(>>15$sig) * 16'sd100);

   // Correlation output (scaled to 16-bit) and the chirp stimulus (scaled for viz).
   $out_a[15:0] = \$signed($acc) >>> 2;
   $out_b[15:0] = \$signed($tx) <<< 7;

   // Visualization: illustrate "pulse compression", the whole point of a matched
   // filter. The top trace is the recent received signal ($sig) -- a chirp whose
   // energy is spread across many low-amplitude samples. The bottom trace is the
   // matched-filter output ($out_a): each time a chirp aligns with the taps, that
   // spread-out energy collapses into a single tall, narrow correlation spike.
   // So a long, hard-to-detect pulse becomes one easy-to-detect peak (this is how
   // radar/sonar measure range: the peak's timing gives the echo delay).
   //
   // NOTE: instruments are instantiated outside /moku_go, so (as the library is
   // currently written) this viz is NOT auto-positioned over its slot. Tune
   // `where.left`/`where.top` below to slide the panel over slot 1 in the Diagram.
   \viz_js
      box: {left: 0, top: 0, width: 214, height: 176, fill: "rgba(255, 255, 255, 0.92)", stroke: "gray", strokeWidth: 1, rx: 6, ry: 6},
      render() {
         let ret = []
         let hist = 40    // cycles of history to plot (> one chirp period)
         let W = 190      // plot width in px
         // Draw one autoscaled waveform of a signal's recent history.
         //   sigRef: TLV signal reference; x0: left edge; yMid: vertical center;
         //   ampl: peak deflection in px; color/label for styling.
         function waveform(sigRef, x0, yMid, ampl, color, label) {
            let objs = []
            // Gather signed history: vals[0] = now, vals[t] = t cycles ago.
            let vals = []
            let t = 0
            for (t = 0; t < hist; t++) {
               let v = sigRef.asInt()
               vals.push((v >= 0x8000) ? (v - 0x10000) : v)
               sigRef.step(-1)
            }
            // Autoscale to the window's peak magnitude.
            let peak = 1
            vals.forEach(v => { if (Math.abs(v) > peak) { peak = Math.abs(v) } })
            objs.push(new fabric.Text(label, {left: x0, top: yMid - ampl - 13, fontSize: 10, fill: color}))
            objs.push(new fabric.Text("peak " + peak, {left: x0 + W - 54, top: yMid - ampl - 13, fontSize: 9, fill: "gray"}))
            // Zero axis.
            objs.push(new fabric.Line([x0, yMid, x0 + W, yMid], {stroke: "#dddddd", strokeWidth: 1}))
            // Waveform: newest sample at the right, oldest at the left.
            for (t = 0; t < hist - 1; t++) {
               let xa = x0 + W - (t * W / hist)
               let xb = x0 + W - ((t + 1) * W / hist)
               let ya = yMid - (vals[t] / peak) * ampl
               let yb = yMid - (vals[t + 1] / peak) * ampl
               objs.push(new fabric.Line([xa, ya, xb, yb], {stroke: color, strokeWidth: 1.5}))
            }
            return objs
         }
         ret.push(new fabric.Text("Matched filter: pulse compression", {left: 8, top: 3, fontSize: 12}))
         ret = ret.concat(waveform('$sig', 12, 58, 24, "rgb(200, 60, 0)", "received chirp (in)"))
         ret = ret.concat(waveform('$out_a', 12, 130, 24, "rgb(0, 140, 0)", "correlator output"))
         ret.push(new fabric.Text("long, low chirp in  ->  one tall spike out", {left: 8, top: 160, fontSize: 9, fill: "gray"}))
         return ret
      },
      where: {left: 80, top: 185},

\TLV
   // Slots numbered 1..4; no bus routing (each slot operates independently).
   m4+moku_go(/top, 00000000, 00000000, 00000000, 00000000)

   // Slot 0 (the first slot): the LFM chirp matched filter.
   /instrument1
      m4+lfm_chirp_matched_filter()
   // Remaining slots empty (outputs held at 0).
   /instrument2
      m4+const_instrument(a, 0)
      m4+const_instrument(b, 0)
   /instrument3
      m4+const_instrument(a, 0)
      m4+const_instrument(b, 0)
   /instrument4
      m4+const_instrument(a, 0)
      m4+const_instrument(b, 0)

   // Run long enough to show several chirp periods, then end simulation.
   *passed = *cyc_cnt > 128;
   *failed = 1'b0;
\SV
   endmodule
