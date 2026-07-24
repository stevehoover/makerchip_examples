\m5_TLV_version 1d: tl-x.org

// "Stacking Logic Gates" -- the slide's circuit, animated.
//
// The slide's circuit drawing (an embedded raster, served via cloudflared)
// is used as the VIZ background. Wires and value labels are redrawn as
// Fabric.js overlays, aligned to the image's pixel coordinates, and driven
// live by the actual TL-Verilog logic below.
//
//   in0 ----------------\
//                        OR(g1) --\
//   in1 --|>o(not1)------/         \
//                                   OR(g3) --- g3
//   in2 ----------------\          /
//                        OR(g2) --/
//   in3 ----------------/

\SV
   m5_makerchip_module
\TLV
   |logic
      @0
         $reset = *reset;
         // Cycle through all 16 input combinations.
         $cnt[3:0] = $reset ? 4'b0 : >>1$cnt + 1;
         $in0 = $cnt[3];
         $in1 = $cnt[2];
         $in2 = $cnt[1];
         $in3 = $cnt[0];
         // The stacked-gate logic.
         $not1 = ! $in1;
         $g1 = $in0 | $not1;
         $g2 = $in2 | $in3;
         $g3 = $g1 | $g2;

         \viz_js
            box: {left: -10, top: -10, width: 880, height: 650, fill: "#ffffff", strokeWidth: 0},
            init() {
               // Display scale: 1 image pixel (native 339x247) -> SC viz units.
               const SC = 2.5
               const URL = "data:image/png;base64,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"+"/"+"/3Hg3/8R+M/iEjmZ83v2fC7+XwnsZNi8vLy6Io6EDyUTyzFD9l7ErqDjfzEauBQWlr6t7/97ac7d8eMGZ2RkdF7Pi+L7WNjTZpnVQIh0DywludD7QrkzNkvCwsLf7pzlxDyX2/81+CwYWZW32xo+fSTTw++f/B8bW03n4+FzwP7lA+UxqXLVzSZGir7qKjIjIwMkTNKbTQ6vX77tu0nT52Son/4PIDyfR6hg1315pK6unraFbdp86bBYcMIT3THtGVlZVVVVQ0NF7sG9jHweWAXXf35QFE0XGzYvXtPVVXV9WvXGxsv0xfXrlsTGhpafrS8rq7OtKelrFM/pH+/pydPWZazDESVpLsAAAH3SURBVJNtgHW1y/rzoXyF+vyyFYt3794j1/bAgQNMm1vJ2/9FQgiZMCH61d+/mj4vnS6MC9mDXpWPaN9t9G2w40Uaw0ujdEViKfuRTz75i1/84rXXX5MNyIHmAfJ878LxVPztIvczxuEq4Pnnf6PT6a38QiRxcVPT56XPTZ0rLX3PcUxPPYIAIM/3dPkKnMjyjvo/3UWn8ri2rKzM0GIghDBC0KChYVOmTsnIyBgcNgwhPUCe78/ZfpfTc0aGNwVo0DyA8gModiA9D/IDwBHlYzUuL8E7NjNKZHnIHvQRucdD+V4Ck52BV4HyAYDyAQBQPgAAygdeoKdVenisngSgfD8lWLT9O7QRAijfX+l7Tx4dCICoAZg/GBjJA0AACb5zMA88HwBE+wAAKB8AAOUDAKB8AACUDwCA8gEAUD4AAMoHAED5AAAoHwAA5QMAoHwAAJQPAIDyAQBQPgAAygcAQPkAACgfACgfAADlAwCgfAAAlA8AgPIBAFA+AEDRSNvqQPkAwPMBAFA+AADKBwBA+QAAKB8AAOUDAKB8AICSoF36UD4AgSh+KB8ARPsAACgfAADlAwCgfAAAlA8AgPIBAFA+AADKBwBA+QAA78CIoohSAACeDwCA8gEAUD4AAMoHAED5AAAoHwAA5QMAoHwAAJQPAPA8/x8z1TRo7SLYBgAAAABJRU5ErkJggg=="
               const X = p => p * SC
               const Y = p => p * SC

               // Wire paths in NATIVE image-pixel coordinates (measured from
               // the bitmap by color detection). Each signal -> list of
               // [x1,y1,x2,y2] segments.
               const wires = {
                  in0:  [[20, 31, 144, 31]],
                  in1:  [[18, 69, 47, 69]],
                  not1: [[100, 68, 144, 68]],
                  in2:  [[20, 131, 144, 131]],
                  in3:  [[17, 167, 144, 167]],
                  g1:   [[191, 51, 230, 51], [230, 50, 230, 82], [230, 81, 272, 81]],
                  g2:   [[190, 151, 230, 151], [230, 110, 230, 152], [230, 111, 272, 111]],
                  g3:   [[310, 91, 340, 91]]
               }
               // Value-label centers (native px).
               const labels = {
                  in0: [8.5, 29.5], in1: [7.5, 68.5], in2: [8.5, 130.5], in3: [7.5, 166.5],
                  g1:  [202.5, 67.5], g2: [202, 141], g3: [326, 96]
               }

               let ret = {}

               // Background: the slide's circuit image.
               ret.bg = this.newImageFromURL(
                  URL,
                  "BU LERNet logic-gates slide (educational use)",
                  {left: 0, top: 0, width: 339 * SC, height: 247 * SC, selectable: false}
               )

               // White "erasers" beneath each wire to hide the baked-in coloring.
               for (let sig in wires) {
                  wires[sig].forEach((s, i) => {
                     ret["we_" + sig + "_" + i] = new fabric.Line(
                        [X(s[0]), Y(s[1]), X(s[2]), Y(s[3])],
                        {stroke: "#ffffff", strokeWidth: 9, selectable: false}
                     )
                  })
               }
               // Colored wires (recolored every cycle in render()).
               for (let sig in wires) {
                  wires[sig].forEach((s, i) => {
                     ret["wc_" + sig + "_" + i] = new fabric.Line(
                        [X(s[0]), Y(s[1]), X(s[2]), Y(s[3])],
                        {stroke: "#000000", strokeWidth: 7,
                         strokeLineCap: "round", selectable: false}
                     )
                  })
               }
               // White erasers beneath the baked value digits.
               for (let sig in labels) {
                  let p = labels[sig]
                  ret["le_" + sig] = new fabric.Rect({
                     left: X(p[0]), top: Y(p[1]), width: 28, height: 38,
                     originX: "center", originY: "center",
                     fill: "#ffffff", selectable: false
                  })
               }
               // Live value digits.
               for (let sig in labels) {
                  let p = labels[sig]
                  ret["lt_" + sig] = new fabric.Text("", {
                     left: X(p[0]), top: Y(p[1]),
                     originX: "center", originY: "center",
                     fontSize: 30, fontFamily: "Courier New",
                     fontWeight: "bold", selectable: false
                  })
               }

               return ret
            },
            render() {
               const BLUE = "#1a56ff", BLACK = "#000000"
               // Current signal values (literal reads so VIZ tracks them).
               let v = {
                  in0:  '$in0'.asBool(),
                  in1:  '$in1'.asBool(),
                  in2:  '$in2'.asBool(),
                  in3:  '$in3'.asBool(),
                  not1: '$not1'.asBool(),
                  g1:   '$g1'.asBool(),
                  g2:   '$g2'.asBool(),
                  g3:   '$g3'.asBool()
               }
               for (let k in this.obj) {
                  if (k.indexOf("wc_") === 0) {
                     let sig = k.split("_")[1]
                     this.obj[k].set({stroke: v[sig] ? BLUE : BLACK})
                  } else if (k.indexOf("lt_") === 0) {
                     let sig = k.split("_")[1]
                     this.obj[k].set({text: v[sig] ? "1" : "0", fill: v[sig] ? BLUE : BLACK})
                  }
               }
               return []
            }

   *passed = *cyc_cnt > 32;
   *failed = 1'b0;
\SV
   endmodule
