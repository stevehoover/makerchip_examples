\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
   // =========================================================================
   // PDF -> VIZ demo: a live 2:1-MUX + AND gate.
   //
   // The schematic is NOT drawn by hand. It is extracted at run time, as live
   // vector geometry, from a referenced lecture PDF:
   //   https://cs2461-2020.github.io/lectures/logic2.pdf  (page 12,
   //   "Example: MUX in a circuit", F = xAC + x'BC).
   // via  this.global.pdf.extractFigure(...)  (see viz-pane/PdfExtractor.js).
   //
   // The TL-Verilog below drives the same signals the figure names (A, B, C, x,
   // F) so the textbook diagram comes alive with simulation values.
   // =========================================================================
   m5_makerchip_module
\TLV
   $reset = *reset;

   // Free-running counter cycles the inputs through every combination.
   $cnt[3:0] <= $reset ? 4'b0 : $cnt + 1'b1;
   $a = $cnt[0];
   $b = $cnt[1];
   $c = $cnt[2];
   $x = $cnt[3];              // MUX select: x=1 -> A, x=0 -> B (per the slide).

   $mux = $x ? $a : $b;       // 2:1 MUX
   $f   = $mux & $c;          // AND gate:  F = mux & C

   \viz_js
      box: {left: 0, top: 0, width: 240, height: 135, fill: "#ffffff"},

      init() {
         let widgets = {}

         widgets.title = new fabric.Text("Live 2:1-MUX + AND  (figure extracted from logic2.pdf)", {
               left: 4, top: 2, fontSize: 7, fontFamily: "Roboto", fill: "#555"
         })

         // Empty group that the async extraction will fill with the figure.
         let figure = new fabric.Group([], {
               originX: "left", originY: "top",
               selectable: false, evented: false
         })
         widgets.figure = figure

         // Placeholder shown until the PDF has been fetched + extracted.
         widgets.loading = new fabric.Text("extracting figure from PDF...", {
               left: 20, top: 60, fontSize: 9, fontFamily: "Roboto", fill: "#999"
         })

         // Where the extracted figure's top-left sits in box coordinates.
         const OFFX = 12, OFFY = 30
         this._offX = OFFX
         this._offY = OFFY
         this._pdfReady = false

         // NOTE: SandHost's CSP connect-src currently allows only 'self',
         // cdn.jsdelivr.net and raw.githubusercontent.com. The canonical PDF is
         // at https://cs2461-2020.github.io/lectures/logic2.pdf; we fetch the
         // identical file via its CSP-allowed raw.githubusercontent.com mirror.
         this.global.pdf.buildFigure(
            fabric,
            {url: "https://raw.githubusercontent.com/cs2461-2020/cs2461-2020.github.io/master/lectures/logic2.pdf"},
            {page: 12, clip: true,
             select: {mode: "region", rect: [200, 520, 380, 605], space: "device"},
             left: OFFX, top: OFFY, into: figure}
         ).then(({fig}) => {

            // Overlay anchors in figure coordinates, placed directly on the
            // extracted wires. fig() shifts by the content origin so box coords
            // line up with where the figure actually renders. Coords taken from
            // the figure's line primitives:
            //   A input   y=48.8  (x 24-41)      B input   y=71.3  (x 24-41)
            //   x select  x=48.4  (y 26-41)      MUX->AND  y=60.3  (x 57-111)
            //   AND lower input (C) y=72.5       F out     y=66.5
            this._pos = {
               x:   fig(48.4, 30),     // select wire, above the MUX
               a:   fig(32,   48.8),   // top MUX input (A)
               b:   fig(32,   71.3),   // bottom MUX input (B)
               mux: fig(83.6, 60.3),   // MUX output, midway to the AND
               c:   fig(116.5, 72.5),  // AND lower input (C)
               f:   fig(152.5, 66.5)   // AND output (F)
            }

            widgets.loading.set({visible: false})
            this._pdfReady = true
            this.getCanvas().requestRenderAll()
         }).catch((e) => {
            console.error("PDF figure extraction failed:", e)
            widgets.loading.set({text: "PDF extraction failed (see console)", fill: "#c00"})
            this.getCanvas().requestRenderAll()
         })

         return widgets
      },

      render() {
         if (!this._pdfReady) { return [] }

         const a   = '$a'.asInt()
         const b   = '$b'.asInt()
         const c   = '$c'.asInt()
         const x   = '$x'.asInt()
         const mux = '$mux'.asInt()
         const f   = '$f'.asInt()
         const P   = this._pos

         // A value "chip": colored dot (green=1, gray=0) with the bit inside.
         const chip = (p, v) => new fabric.Group([
               new fabric.Circle({
                  left: p.x, top: p.y, radius: 6,
                  originX: "center", originY: "center",
                  fill: v ? "#2e7d32" : "#bdbdbd",
                  stroke: "#222", strokeWidth: 0.5
               }),
               new fabric.Text(String(v), {
                  left: p.x, top: p.y, fontSize: 8,
                  originX: "center", originY: "center",
                  fontFamily: "Roboto", fill: "#fff"
               })
            ], {selectable: false, evented: false})

         let arr = [
            chip(P.x,   x),
            chip(P.a,   a),
            chip(P.b,   b),
            chip(P.c,   c),
            chip(P.mux, mux),
            chip(P.f,   f)
         ]

         // Ring the MUX input currently selected by x.
         let sel = x ? P.a : P.b
         arr.push(new fabric.Circle({
               left: sel.x, top: sel.y, radius: 10,
               originX: "center", originY: "center",
               fill: "", stroke: "#e65100", strokeWidth: 1.5
         }))

         return arr
      }
\SV
   endmodule
