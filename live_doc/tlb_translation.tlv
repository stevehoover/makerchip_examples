\m5_TLV_version 1d: tl-x.org
\m5
   // =============================================================
   // Live Doc: TLB Address Translation
   //   Source slide: https://cim.mcgill.ca/~langer/273/18-cache1.pdf
   //   (McGill COMP 273 — "18 - caches 1: indexing", page 3)
   //
   // The referenced figure is fetched and parsed in the browser at
   // runtime; no copy of it is stored in this file. Simulation-driven
   // overlays (values / colors) are original work laid over the figure.
   // =============================================================
\SV
   m5_makerchip_module
\TLV
   /doc
      $reset = *reset;

      // ---- Stimulus: a new virtual address every 8 cycles -------------
      $cnt[9:0] = $reset ? 10'b0 : >>1$cnt + 10'b1;
      $sel[2:0] = $cnt[5:3];

      // Virtual address = { tag[3:0], index[2:0], offset[3:0] } (11 bits).
      // (Field widths are scaled down from the slide so values stay readable.)
      $va[10:0] =
         ($sel == 3'd0) ? {4'h3, 3'd0, 4'h5} :
         ($sel == 3'd1) ? {4'h4, 3'd0, 4'h2} :
         ($sel == 3'd2) ? {4'h5, 3'd1, 4'hF} :
         ($sel == 3'd3) ? {4'h9, 3'd2, 4'h1} :
         ($sel == 3'd4) ? {4'hA, 3'd3, 4'h7} :
         ($sel == 3'd5) ? {4'h7, 3'd4, 4'h0} :
         ($sel == 3'd6) ? {4'h2, 3'd6, 4'hC} :
                          {4'hF, 3'd7, 4'h9};
      $va_tag[3:0]    = $va[10:7];
      $va_index[2:0]  = $va[6:4];
      $va_offset[3:0] = $va[3:0];

      // ---- PID register ----------------------------------------------
      $pid_reg[1:0] = 2'd1;

      // ---- TLB (SRAM): 8 entries { valid, tag[3:0], pid[1:0], ppn[5:0] }
      $entry[12:0] =
         ($va_index == 3'd0) ? {1'b1, 4'h3, 2'd1, 6'h2A} :
         ($va_index == 3'd1) ? {1'b1, 4'h5, 2'd1, 6'h15} :
         ($va_index == 3'd2) ? {1'b0, 4'h0, 2'd0, 6'h00} :
         ($va_index == 3'd3) ? {1'b1, 4'hA, 2'd2, 6'h0C} :
         ($va_index == 3'd4) ? {1'b1, 4'h7, 2'd1, 6'h33} :
         ($va_index == 3'd5) ? {1'b0, 4'h0, 2'd0, 6'h00} :
         ($va_index == 3'd6) ? {1'b1, 4'h1, 2'd1, 6'h08} :
                               {1'b1, 4'hF, 2'd1, 6'h3F};
      $e_valid    = $entry[12];
      $e_tag[3:0] = $entry[11:8];
      $e_pid[1:0] = $entry[7:6];
      $e_ppn[5:0] = $entry[5:0];

      // ---- Compare & translate ---------------------------------------
      $tag_match = $e_tag == $va_tag;
      $pid_match = $e_pid == $pid_reg;
      $hit       = $e_valid & $tag_match & $pid_match;
      $tlb_miss  = ! $hit;
      $phys_addr[9:0] = {$e_ppn, $va_offset};

      \viz_js
         init() {
            let figure = new fabric.Group([], {originX: "left", originY: "top",
                                               selectable: false, evented: false})
            this._pdfReady = false
            const OFFX = 8, OFFY = 22

            // ---- Live overlay widgets (created once, mutated in render) ----
            let mk = (sz, fill) => new fabric.Text("", {fontSize: sz || 7,
                     fill: fill || "#1565c0", fontFamily: "Roboto",
                     originX: "center", originY: "center",
                     selectable: false, evented: false})
            let C = {
               vaTag: mk(7, "#6a1b9a"), vaIdx: mk(7, "#00695c"), vaOff: mk(7, "#ad1457"),
               pid:   mk(7, "#1565c0"),
               ppn:   mk(7, "#6a1b9a"), eTag: mk(7), eVal: mk(7), ePid: mk(7),
               pa:    mk(8, "#1565c0"),
               badge: new fabric.Text("", {fontSize: 11, fontFamily: "Roboto",
                      originX: "center", originY: "center",
                      selectable: false, evented: false})
            }
            this._c = C
            let status = new fabric.Text("", {left: 4, top: 312, fontSize: 8.5,
                     fill: "#455a64", fontFamily: "Roboto",
                     selectable: false, evented: false})
            this._status = status

            this.global.pdf.buildFigure(
               fabric,
               "https://cim.mcgill.ca/~langer/273/18-cache1.pdf",
               {page: 3,
                select: {mode: "region", rect: [110, 238, 500, 535], space: "device"},
                clip: true,
                text: "labels",
                left: OFFX, top: OFFY, into: figure}
            ).then(({fig}) => {
               // Anchor each overlay onto the extracted figure (figure-space coords).
               let at = (obj, fx, fy) => { let p = fig(fx, fy); obj.set({left: p.x, top: p.y}) }
               at(C.vaTag,  48, 47);  at(C.vaIdx, 112, 47);  at(C.vaOff, 171, 47)
               at(C.pid,   358, 39)
               at(C.ppn,   176, 88);  at(C.eTag, 229, 88);  at(C.eVal, 293, 88); at(C.ePid, 315, 88)
               at(C.pa,    236, 52)
               at(C.badge, 300, 250)
               this._pdfReady = true
               this.getCanvas().requestRenderAll()
            }).catch((e) => {
               status.set({text: "PDF load error: " +
                           (e && e.message ? e.message : String(e)), fill: "#c62828"})
               this.getCanvas().requestRenderAll()
            })
            return {figure, status, vaTag: C.vaTag, vaIdx: C.vaIdx, vaOff: C.vaOff,
                    pid: C.pid, ppn: C.ppn, eTag: C.eTag, eVal: C.eVal, ePid: C.ePid,
                    pa: C.pa, badge: C.badge}
         },
         render() {
            if (!this._pdfReady) return []
            let C = this._c
            let hx = (v) => v.toString(16).toUpperCase()
            let vt = '$va_tag'.asInt(), vi = '$va_index'.asInt(), vo = '$va_offset'.asInt()
            let ev = '$e_valid'.asInt(), et = '$e_tag'.asInt(),
                ep = '$e_pid'.asInt(),  epp = '$e_ppn'.asInt()
            let pr = '$pid_reg'.asInt()
            let tagM = '$tag_match'.asInt(), pidM = '$pid_match'.asInt()
            let hit = '$hit'.asInt(), miss = '$tlb_miss'.asInt()
            let pa = '$phys_addr'.asInt()
            let green = "#2e7d32", red = "#c62828", gray = "#9e9e9e"

            // Virtual address fields flowing in from the top.
            C.vaTag.set({text: hx(vt)})
            C.vaIdx.set({text: String(vi)})
            C.vaOff.set({text: hx(vo)})
            C.pid.set({text: String(pr)})

            // Retrieved TLB entry; color the compared fields by match.
            C.ppn.set({text: hx(epp), opacity: ev ? 1 : 0.35})
            C.eTag.set({text: hx(et), fill: ev && tagM ? green : red})
            C.eVal.set({text: String(ev), fill: ev ? green : red})
            C.ePid.set({text: String(ep), fill: ev && pidM ? green : red})

            // Result (TLBmiss is the diagram's output signal).
            C.pa.set({text: miss ? "\u2014" : ("0x" + pa.toString(16).toUpperCase()),
                      fill: miss ? gray : "#1565c0"})
            C.badge.set({text: miss ? "TLB MISS" : "TLB HIT", fill: miss ? red : green})

            let why = hit ? "valid \u2227 tag match \u2227 PID match"
                          : (!ev ? "entry invalid"
                                 : (!tagM ? "tag mismatch" : "PID mismatch"))
            this._status.set({text: "VA tag=" + hx(vt) + " index=" + vi +
                     " offset=" + hx(vo) + "  \u2192  " +
                     (hit ? "HIT, PA=0x" + pa.toString(16).toUpperCase() : "MISS (" + why + ")")})
            return []
         },
         where: {left: 0, top: 0, width: 420, height: 340}

   *passed = *cyc_cnt > 70;
\SV
   endmodule
