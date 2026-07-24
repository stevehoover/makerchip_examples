\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
   // =========================================================================
   // Live Doc example: NAND R-S Latch.
   //
   // The circuit is extracted at runtime from:
   //   https://cs2461-2020.github.io/lectures/latches.pdf  (page 9,
   //   "Storage - Cross-Coupled NANDs (R-S Latch)").
   //
   // Inputs S and R are ACTIVE-LOW (NAND latch convention):
   //   S=0, R=1  →  SET   (Q becomes 1)
   //   S=1, R=0  →  RESET (Q becomes 0)
   //   S=1, R=1  →  HOLD
   //   S=0, R=0  →  ILLEGAL (avoided in this demo)
   //
   // The counter cycles: HOLD (4) → SET (4) → HOLD (4) → RESET (4).
   // =========================================================================
   m5_makerchip_module
\TLV
   $reset = *reset;

   // 4-phase counter (4 cycles per phase, 16-cycle period).
   $cnt[4:0]   = $reset ? 5'b0 : >>1$cnt + 5'b1;
   $phase[1:0] = $cnt[3:2];

   // Active-low set_n and rst_n. Phase 1 = SET, phase 3 = RESET, others = HOLD.
   $set_n = ($phase != 2'b01);   // active-low SET (0 = asserted)
   $rst_n = ($phase != 2'b11);   // active-low RESET (0 = asserted)

   // NAND RS latch: !set_n forces Q=1; !rst_n forces Q=0; else hold.
   $qlat[0] = $reset ? 1'b0 : !$set_n ? 1'b1 : !$rst_n ? 1'b0 : >>1$qlat;
   $qbar    = !$qlat;

   \viz_js
      box: {left: 0, top: 0, width: 148, height: 115, fill: "#ffffff"},

      init() {
         let widgets = {}

         widgets.title = new fabric.Text("NAND R-S Latch  (latches.pdf p.9)", {
               left: 4, top: 2, fontSize: 7, fontFamily: "Roboto", fill: "#555"
         })

         let figure = new fabric.Group([], {
               originX: "left", originY: "top",
               selectable: false, evented: false
         })
         widgets.figure = figure

         widgets.loading = new fabric.Text("extracting figure from PDF...", {
               left: 10, top: 55, fontSize: 9, fontFamily: "Roboto", fill: "#999"
         })
         widgets.status = new fabric.Text("", {
               left: 4, top: 101, fontSize: 8, fontFamily: "Roboto",
               fill: "#1565c0", selectable: false, evented: false
         })

         const OFFX = 10, OFFY = 22
         this._pdfReady = false

         // ext.labels indices (page 9, clip [242,456,350,540]):
         //   0:"-"  1:"Coupled NANDs (R"  2:"S"  3:"R"  4:"Q"  9:"~Q"
         //   5:"1"(~Q wire)  6:"0"(S wire)  7:"0"(R wire)  8:"1"(Q wire)
         this.global.pdf.buildFigure(
            fabric,
            {url: "https://raw.githubusercontent.com/cs2461-2020/cs2461-2020.github.io/master/lectures/latches.pdf"},
            {page: 9, clip: true,
             select: {mode: "region", rect: [242, 456, 350, 540], space: "device"},
             labels: {s: 6, r: 7, q: 8, qb: 5},
             left: OFFX, top: OFFY, into: figure}
         ).then(({elements}) => {
            this._el = elements   // {s, r, q, qb} → fabric.Text refs inside the group
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
         const sVal = '$set_n'.asInt(), rVal = '$rst_n'.asInt()
         const qVal = '$qlat'.asInt(), qbVal = '$qbar'.asInt()
         const E = this._el
         E.s.set({text: String(sVal), fill: sVal ? "#2e7d32" : "#e65100"})
         E.r.set({text: String(rVal), fill: rVal ? "#2e7d32" : "#e65100"})
         E.q.set({text: String(qVal), fill: qVal ? "#2e7d32" : "#c00"})
         E.qb.set({text: String(qbVal), fill: qbVal ? "#2e7d32" : "#c00"})
         const op = !sVal && rVal ? "SET" : sVal && !rVal ? "RESET" : sVal && rVal ? "HOLD" : "ILLEGAL"
         this._statusLabel.set({text: op + "  (S=" + sVal + ", R=" + rVal + ")"})
         return []
      }
\SV
   endmodule
