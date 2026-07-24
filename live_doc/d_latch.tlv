\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
   // =========================================================================
   // Live Doc example: Gated D-Latch.
   //
   // The circuit is extracted at runtime from:
   //   https://cs2461-2020.github.io/lectures/latches.pdf  (page 11,
   //   "Gated D-Latch: Preventing Illegal State of RS Latch").
   //
   // Two inputs: D (data) and WE (write enable):
   //   WE=1  →  Q follows D  (latch is transparent)
   //   WE=0  →  Q holds its previous value
   //
   // The counter cycles: WE=0 hold (4) → WE=1 write (4) → repeat.
   // D changes every other cycle so both 0→Q and 1→Q transitions are visible.
   // =========================================================================
   m5_makerchip_module
\TLV
   $reset = *reset;

   $cnt[3:0] = $reset ? 4'b0 : >>1$cnt + 4'b1;

   $din  = $cnt[1];    // Data input: changes every 2 cycles.
   $wen  = $cnt[2];    // Write enable: high for 4 cycles, low for 4.

   // Structural gate-level model matching the PDF diagram's 4-NAND topology.
   // NAND1(D,WE)→S_bar (top path: SET); NAND2(NOT_D,WE)→R_bar (bottom path: RESET).
   $s_bar = !($din && $wen);
   $r_bar = !(!$din && $wen);
   $qlat[0] = $reset ? 1'b0 : !$s_bar ? 1'b1 : !$r_bar ? 1'b0 : >>1$qlat;
   $q_bar  = !$qlat;

   \viz_js
      box: {left: 0, top: 0, width: 235, height: 120, fill: "#ffffff"},

      init() {
         let widgets = {}

         widgets.title = new fabric.Text("Gated D-Latch  (latches.pdf p.11)", {
               left: 4, top: 2, fontSize: 7, fontFamily: "Roboto", fill: "#555"
         })

         let figure = new fabric.Group([], {
               originX: "left", originY: "top",
               selectable: false, evented: false
         })
         widgets.figure = figure

         widgets.loading = new fabric.Text("extracting figure from PDF...", {
               left: 20, top: 55, fontSize: 9, fontFamily: "Roboto", fill: "#999"
         })
         widgets.weRing = new fabric.Circle({
               left: 0, top: 0, radius: 8, originX: "center", originY: "center",
               fill: "", stroke: "#90a4ae", strokeWidth: 1.5,
               visible: false, selectable: false, evented: false
         })
         widgets.status = new fabric.Text("", {
               left: 4, top: 107, fontSize: 8, fontFamily: "Roboto",
               fill: "#546e7a", selectable: false, evented: false
         })

         const OFFX = 8, OFFY = 22
         this._pdfReady = false

         // ext.labels indices (page 11, clip [188,593,397,681]):
         //   0:"not allow S=0..."  5:"WE"  6:"D"  7:"Q"  10:"S"  11:"Q no longer follows"
         //   1:"1"(s_bar)  2:"1"(q_bar out)  3:"0"(Q)  4:"1"(q_bar fb)  8:"0"(r_bar)  9:"0"(D)
         this.global.pdf.buildFigure(
            fabric,
            {url: "https://cs2461-2020.github.io/lectures/latches.pdf"},
            {page: 11, clip: true,
             select: {mode: "region", rect: [188, 593, 397, 681], space: "device"},
             labels: {din: 9, r_bar: 8, s_bar: 1, q_bar_fb: 4, q_bar: 2, qlat: 3},
             left: OFFX, top: OFFY, into: figure}
         ).then(({fig, elements}) => {
            this._el = elements   // {din, r_bar, s_bar, q_bar_fb, q_bar, qlat} → fabric.Text refs

            // WE wire has no value label in the PDF; ring widget is positioned here.
            const we = fig(43, 12)
            widgets.weRing.set({left: we.x, top: we.y})
            widgets.weRing.visible = true
            this._weRing = widgets.weRing
            this._statusLabel = widgets.status

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
         if (!this._pdfReady) return []
         const dinVal = '$din'.asInt(), wenVal = '$wen'.asInt(), qVal = '$qlat'.asInt()
         const qbarVal = '$q_bar'.asInt(), sbarVal = '$s_bar'.asInt(), rbarVal = '$r_bar'.asInt()
         const E = this._el
         E.din.set({text: String(dinVal), fill: dinVal ? "#2e7d32" : "#777"})
         E.r_bar.set({text: String(rbarVal), fill: rbarVal ? "#2e7d32" : "#c00"})
         E.s_bar.set({text: String(sbarVal), fill: sbarVal ? "#2e7d32" : "#c00"})
         E.q_bar_fb.set({text: String(qbarVal), fill: qbarVal ? "#2e7d32" : "#c00"})
         E.q_bar.set({text: String(qbarVal), fill: qbarVal ? "#2e7d32" : "#c00"})
         E.qlat.set({text: String(qVal), fill: qVal ? "#2e7d32" : "#777"})
         this._weRing.set({stroke: wenVal ? "#e65100" : "#90a4ae"})
         const mode = wenVal ? "TRANSPARENT  (Q follows D)" : "HOLD  (Q locked)"
         this._statusLabel.set({text: mode, fill: wenVal ? "#e65100" : "#546e7a"})
         return []
      }
\SV
   endmodule
