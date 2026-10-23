\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   var(deck_url, ['https://people.eecs.berkeley.edu/~randy/Courses/CS150.F00/Lectures/06-SeqImpl.pdf'])
   var(deck_title, ['R. H. Katz, CS 150 (Fall 2000), UC Berkeley: Sequential Logic Implementation'])
   var(slide_box, ['width: 208.8, height: 156.3, strokeWidth: 0'])
   macro(slide_where, ['left: (($1) - 1) % 10 * 230, top: 50 + Math.floor((($1) - 1) / 10) * 175'])
\SV
   // =========================================================================
   // Live Doc example: a whole lecture slide deck, with animated slides.
   //
   // All 73 slides are fetched and extracted at runtime from (not reproduced here):
   //   R. H. Katz, CS 150 Fall 2000, UC Berkeley, "Sequential Logic Implementation",
   //   https://people.eecs.berkeley.edu/~randy/Courses/CS150.F00/Lectures/06-SeqImpl.pdf
   // Students can follow the lecture in Makerchip; the instructor can project it via VIZ.
   //
   // Slides are laid out in reading order, 10 across. m5+slide() shows any slide as-is; an
   // animated slide has its own macro providing its own scope, logic, and VIZ in the same slot.
   //
   // Animated slides run their FSM on pseudo-random inputs, filling the current state, outlining
   // the next state, highlighting the transition (arc) taken, and highlighting the active state-table row:
   //    4      a 5-state FSM on input In
   //    5      combination lock (reset every 16 cycles)
   //    6      shift register, showing IN and OUT values
   //    7, 10, 11  3-bit up-counter; 11 also highlights the K-map cells
   //   13      shift register, also coloring schematic nets by value
   //   14, 16  complex counter; 16 restarts in a random (possibly unused) state every 8 cycles
   //   22, 24, 26, 28, 30, 31, 32  ant brain (one FSM; 28 also drops it into unused states,
   //                               31, 32 show B and C merged)
   //   34, 35  Moore and Mealy 01/10 sequence detectors
   //   41      vending machine input-sequence tree
   //   42, 43, 45  vending machine (opens at 15 cents, then resets)
   //   46      vending machine as Moore and Mealy, showing both outputs
   //   48, 49, 50, 51  traffic light controller with a real interval timer (TS, TL); 48 and 50
   //           show the lights
   //   53      vending machine PLD pin values
   //   58, 59, 60  010/110 sequence detector, before and after state minimization
   //   61, 62  multiple-input state minimization
   //   64, 65  edge detectors, 3- and 4-state
   // =========================================================================
   m5_makerchip_module

// Shared deck JS, published as this.global.slideDeck. Instantiate before any slide: sibling
// scopes init in order.
\TLV slide_deck(/_top)
   /_top
      \viz_js
         box: {width: 2290, height: 40, strokeWidth: 0},
         init() {
            // Slide frames, 6 per page (handout layout) in reading order, in PDF page coordinates.
            const W = 208.8, H = 156.3, COLS = [78.6, 324.5], ROWS = [109.9, 317.2, 524.4]
            // This PDF's ZapfDingbats bullets extract as bars; show them as the slides' bullets.
            const bullets = {"\u275a": "\u2022", "\u2759": "\u2013", "\u2758": "\u00bb"}
            this.global.slideDeck = {
               // The Live Doc group for slide n, built into viz (the slide scope). build: extractToFabric build options.
               figure: (viz, n, build = {}) => {
                  const x = COLS[(n - 1) % 2], y = ROWS[Math.floor((n - 1) % 6 / 2)]
                  return this.global.pdf.extractToFabric(viz, {url: "m5_deck_url"}, {
                     extract: {page: Math.ceil(n / 6), clip: true, select: {mode: "region", rect: [x, y, x + W, y + H]},
                               imageData: true},
                     build: {...build, onReady: (r) => {
                        r.parts.filter(t => t.type === "text" && bullets[t.text]).forEach(t => t.set({text: bullets[t.text]}))
                        if (build.onReady) build.onReady(r)
                     }},
                  })
               },
               // Primitive selectors naming state circles <prefix><code> by their centers (figure
               // coordinates), indexed by state code (null for unused codes). For showStates().
               states: (centers, prefix = "state_") => Object.fromEntries(centers.flatMap((at, s) => at ? [[prefix + s, {near: at}]] : [])),
               // Fill the current state circle; outline the next.
               showStates: (el, cur, next, prefix = "state_") => Object.keys(el).filter(k => k.startsWith(prefix)).forEach(k => {
                  const c = el[k]
                  c.orig = c.orig || {fill: c.fill, stroke: c.stroke, strokeWidth: c.strokeWidth}
                  c.set({fill: k === prefix + cur ? "#ffcc80" : c.orig.fill,
                         stroke: k === prefix + next ? "#e65100" : c.orig.stroke,
                         strokeWidth: k === prefix + next ? 1 : c.orig.strokeWidth})
               }),
               // Primitive selectors naming arcs <prefix><key> (e.g. arc_0_1: state 0 to 1) by pool index
               // ranges, e.g. {"0_1": "7,21-22"}. Straight arcs are a line and arrowhead; curved ones are
               // scanline slivers then an arrowhead. Arcs may share primitives (e.g. a return bus).
               arcs: (spec, prefix = "arc_") => Object.fromEntries(Object.entries(spec).map(([k, v]) => [prefix + k,
                  {nth: v.split(",").map(r => { const [from, to] = r.split("-").map(Number); return to === undefined ? from : {from, to} })}])),
               // Color the primitives of arc <prefix><key>; restore other arcs.
               showArc: (el, key, prefix = "arc_") => {
                  const arcs = Object.keys(el).filter(k => k.startsWith(prefix))
                  arcs.forEach(k => [].concat(el[k]).forEach(p => {
                     p.orig = p.orig || {fill: p.fill, stroke: p.stroke}
                     p.set(p.orig)
                  }))
                  const paint = (c) => c && c !== "none" ? "#e65100" : c
                  ;[].concat(el[prefix + key] || []).forEach(p => p.set({fill: paint(p.orig.fill), stroke: paint(p.orig.stroke)}))
               },
               // A table-row highlight bar in figure. top: row 0 label top; pitch: row spacing.
               // Returns row => void, positioning the bar on that row (null hides it).
               rowBar: (figure, {left, width, top, pitch, fontSize, height = 0.94 * pitch}) => {
                  const bar = new fabric.Rect({left, top: 0, width, height, fill: "rgba(255, 152, 0, 0.30)", strokeWidth: 0})
                  figure.add(bar)
                  return (row) => bar.set(row == null ? {visible: false} : {visible: true, top: top + row * pitch + fontSize / 2 - height / 2})
               },
               // A text overlay in figure.
               text: (figure, left, top, opts = {}) => {
                  const t = new fabric.Text("", {left, top, fontSize: 4, fontFamily: "Roboto", ...opts})
                  figure.add(t)
                  return t
               },
            }
            return {
               title: new fabric.Text("m5_deck_title", {left: 0, top: 0, fontSize: 18, fontFamily: "Roboto", fill: "#333"}),
               credit: new fabric.Text("Slides fetched from people.eecs.berkeley.edu at runtime; not reproduced.",
                  {left: 0, top: 24, fontSize: 10, fontFamily: "Roboto", fill: "#888"}),
            }
         },

// Any slide, unanimated.
\TLV slide(/_top, _n)
   /_top
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(_n)},
         init() {
            return {figure: this.global.slideDeck.figure(this, _n)}
         },

// Slide 13: "Another Example: Shift Register" (3-bit shift register as an FSM).
\TLV slide13(/_top)
   /_top
      $reset = *reset;
      $lfsr[4:0] = $reset ? 5'b1 : {>>1$lfsr[3:0], >>1$lfsr[4] ^ >>1$lfsr[2]};
      $in = $lfsr[0];
      // Three D flip-flops in series: OUT1 = C1, OUT2 = C2, OUT3 = C3.
      $c1 = $reset ? 1'b0 : >>1$in;
      $c2 = $reset ? 1'b0 : >>1$c1;
      $c3 = $reset ? 1'b0 : >>1$c2;
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(13)},
         init() {
            const figure = this.global.slideDeck.figure(this, 13, {
               // Table rows: row = {In,C1,C2,C3}. State circles in the order of _stateCodes.
               primitives: {
                  circles: {nth: {from: 5, to: 12}},
                  in_net:  {path: 680, all: true},
                  out1_net: [{path: 682, all: true}, {path: 686, all: true}],
                  out2_net: [{path: 688, all: true}, {path: 692, all: true}],
                  out3_net: {path: 694, all: true},
               },
            })
            this._stateCodes = ["100", "110", "111", "011", "101", "010", "000", "001"]
            // Overlays, in figure coordinates.
            const D = this.global.slideDeck
            this._row = D.rowBar(figure, {left: 5.9, width: 69, top: 70.1, pitch: 4.885, fontSize: 3.36})
            const chip = (left, top) => D.text(figure, left, top, {fontWeight: "bold", originX: "center", originY: "center"})
            this._chips = [chip(107.4, 131.6), chip(137.2, 126.1), chip(163.4, 126.1), chip(190, 126.1)]
            return {figure}
         },
         render() {
            const el = this.liveDocElements
            if (!el) return []
            const inV = '$in'.asInt(), c1 = '$c1'.asInt(), c2 = '$c2'.asInt(), c3 = '$c3'.asInt()
            const cur = `${c1}${c2}${c3}`, next = `${inV}${c1}${c2}`
            const row = inV * 8 + c1 * 4 + c2 * 2 + c3

            this._row(row)

            el.circles.forEach((c, i) => {
               const code = this._stateCodes[i]
               c.set({fill: code === cur ? "#ffcc80" : "",
                      stroke: code === next ? "#e65100" : "#000000",
                      strokeWidth: code === next ? 1 : 0.5})
            })

            const color = (v) => v ? "#2e7d32" : "#9e9e9e"
            const nets = [el.in_net, el.out1_net.flat(), el.out2_net.flat(), el.out3_net]
            ;[inV, c1, c2, c3].forEach((v, i) => {
               nets[i].forEach(p => p.set({stroke: color(v), strokeWidth: 0.9}))
               this._chips[i].set({text: String(v), fill: color(v)})
            })
            return []
         }

// ---- FSMs. Each provides $state and $next (held in reset); state codes match the slide.

// Pseudo-random stimulus: a 16-bit maximal-length LFSR. Deterministic, so slides sharing an FSM agree.
\TLV rnd()
   $rnd[15:0] = *reset ? 16'hACE1 : {>>1$rnd[14:0], >>1$rnd[15] ^ >>1$rnd[13] ^ >>1$rnd[12] ^ >>1$rnd[10]};

// 3-bit up-counter.
\TLV counter_fsm()
   $state[2:0] = *reset ? 3'b0 : >>1$next;
   $next[2:0] = *reset ? 3'b0 : $state + 3'b1;

// Complex counter, state {C,B,A}: C+ = A, B+ = B' + A'C', A+ = BC' (slide 16).
// _restart: when to load a random state instead (exercising self-starting).
\TLV complex_counter_fsm(_restart)
   m5+rnd()
   $state[2:0] = *reset ? 3'b0 : _restart ? $rnd[2:0] : >>1$next;
   $next[2:0] = *reset ? 3'b0 : {$state[0], ~$state[1] | (~$state[0] & ~$state[2]), $state[1] & ~$state[2]};

// Traffic light controller. States: 0 HG, 1 HY, 2 FG, 3 FY. ST restarts the interval timer.
\TLV traffic_fsm()
   m5+rnd()
   $c = $rnd[4] | $rnd[7];
   $timer[2:0] = (*reset || >>1$st) ? 3'b0 : >>1$timer + {2'b0, >>1$timer != 3'd7};
   $ts = $timer >= 3'd2;
   $tl = $timer >= 3'd5;
   $state[1:0] = *reset ? 2'd0 : >>1$next;
   $next[1:0] = *reset ? 2'd0 :
      ($state == 2'd0) ? (($tl && $c) ? 2'd1 : 2'd0) :
      ($state == 2'd1) ? ($ts ? 2'd2 : 2'd1) :
      ($state == 2'd2) ? (($tl || ! $c) ? 2'd3 : 2'd2) :
                         ($ts ? 2'd0 : 2'd3);
   $st = $next != $state;

// Ant brain (slide 22). States: 0 LOST, 1 E/G, 2 A, 3 B, 4 C. Unused (slide 28): 5, 6 go LOST; 7 is stuck.
// _restart: when to load a random (possibly unused) state instead.
\TLV ant_fsm(_restart)
   m5+rnd()
   $l = $rnd[3];
   $r = $rnd[9];
   $state[2:0] = *reset ? 3'd0 : _restart ? $rnd[2:0] : >>1$next;
   $next[2:0] = *reset ? 3'd0 :
      ($state == 3'd0) ? (($l || $r) ? 3'd1 : 3'd0) :
      ($state == 3'd1) ? (($l || $r) ? 3'd1 : 3'd3) :
      ($state == 3'd2) ? ($l ? 3'd1 : $r ? 3'd2 : 3'd3) :
      ($state == 3'd3 || $state == 3'd4) ? ($r ? 3'd2 : 3'd4) :
      ($state == 3'd7) ? 3'd7 : 3'd0;

// Vending machine. States: 0, 1, 2, 3 = 0, 5, 10, 15 cents. Resets after opening.
\TLV vending_fsm()
   m5+rnd()
   $n = $rnd[12:11] == 2'd1;
   $d = $rnd[12:11] == 2'd2;
   $open = $state == 2'd3;
   $state[1:0] = *reset ? 2'd0 : >>1$next;
   $sum[2:0] = {1'b0, $state} + {1'b0, $d, $n};
   $next[1:0] = (*reset || $open) ? 2'd0 : $sum > 3'd3 ? 2'd3 : $sum[1:0];

// Sequence detector for 010 or 110 (slide 58). States S0..S6; $out is Mealy.
\TLV seq_fsm()
   m5+rnd()
   $x = $rnd[6];
   $state[2:0] = *reset ? 3'd0 : >>1$next;
   $next[2:0] = (*reset || $state > 3'd2) ? 3'd0 : {$state[1:0], 1'b0} + 3'd1 + {2'b0, $x};
   $out = ! $x && ($state == 3'd4 || $state == 3'd6);

// Multiple-input example (slide 61). States S0..S5, inputs 00..11.
\TLV multi_input_fsm()
   m5+rnd()
   $in[1:0] = $rnd[9:8];
   $state[2:0] = *reset ? 3'd0 : >>1$next;
   $next[2:0] = *reset ? 3'd0 :
      ($state == 3'd0) ? ($in == 2'd0 ? 3'd0 : $in == 2'd1 ? 3'd1 : $in == 2'd2 ? 3'd2 : 3'd3) :
      ($state == 3'd1) ? ($in == 2'd0 ? 3'd0 : $in == 2'd1 ? 3'd3 : $in == 2'd2 ? 3'd1 : 3'd4) :
      ($state == 3'd2) ? ($in == 2'd0 ? 3'd1 : $in == 2'd1 ? 3'd3 : $in == 2'd2 ? 3'd2 : 3'd4) :
      ($state == 3'd3) ? ($in == 2'd0 ? 3'd1 : $in == 2'd1 ? 3'd0 : $in == 2'd2 ? 3'd4 : 3'd5) :
      ($state == 3'd4) ? ($in == 2'd0 ? 3'd0 : $in == 2'd1 ? 3'd1 : $in == 2'd2 ? 3'd2 : 3'd5) :
                         ($in == 2'd0 ? 3'd1 : $in == 2'd1 ? 3'd4 : $in == 2'd2 ? 3'd0 : 3'd5);

// Edge-detector input (slides 64, 65), shared so both detectors see the same sequence.
\TLV edge_input()
   m5+rnd()
   $x = $rnd[2];

// ---- Animated slides.

// Slide 7: "Counters are Simple Finite State Machines".
\TLV slide7(/_top)
   /_top
      m5+counter_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(7)},
         init() {
            const D = this.global.slideDeck
            return {figure: D.figure(this, 7, {primitives: {...D.states([
               [43.3, 119.3], [64.0, 98.5], [105.2, 98.6], [146.7, 98.5], [167.5, 119.3], [146.7, 139.9], [105.2, 140.0], [64.0, 139.9]]),
               ...D.arcs({"0_1": "11-12", "1_2": "7-8", "2_3": "18-19", "3_4": "9-10", "4_5": "24-25", "5_6": "16-17", "6_7": "20-21", "7_0": "22-23"})}})}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            return []
         },

// Slide 10: "FSM Design Procedure: State Diagram" (3-bit up-counter).
\TLV slide10(/_top)
   /_top
      m5+counter_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(10)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 10, {primitives: {...D.states([
               [17.9, 107.7], [33.5, 92.0], [57.3, 92.0], [80.6, 92.0], [96.7, 107.7], [80.7, 123.3], [57.4, 123.3], [33.5, 123.3]]),
               ...D.arcs({"0_1": "11-12", "1_2": "7-8", "2_3": "18-19", "3_4": "9-10", "4_5": "24-25", "5_6": "16-17", "6_7": "20-21", "7_0": "22-23"})}})
            this._row = D.rowBar(figure, {left: 122, width: 62, top: 90.4, pitch: 6.33, fontSize: 2.6})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._row(s)
            return []
         },

// Slide 14: "More Complex Counter Example".
\TLV slide14(/_top)
   /_top
      m5+complex_counter_fsm(1'b0)
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(14)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 14, {primitives: {...D.states([
               [40.6, 101.2], null, [32.1, 123.5], [54.3, 137.4], null, [75.1, 123.5], [64.8, 101.2], null]),
               ...D.arcs({"0_2": "9-10", "2_3": "11-12", "3_5": "13-14", "5_6": "15-16", "6_0": "17-18"})}})
            this._row = D.rowBar(figure, {left: 121.5, width: 57.5, top: 106.7, pitch: 4.6, fontSize: 3.4})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._row(s)
            return []
         },

// Slide 16: "Self-Starting Counters" (2nd), restarting in a random state every 8 cycles.
\TLV slide16(/_top)
   /_top
      m5+complex_counter_fsm(*cyc_cnt[2:0] == 3'b0)
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(16)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 16, {primitives: {...D.states([
               [142.2, 108.0], [187.1, 94.2], [133.6, 130.4], [156.0, 144.2], [111.3, 114.8], [176.7, 130.4], [166.3, 108.0], [121.6, 94.2]]),
               ...D.arcs({"0_2": "39-40", "2_3": "41-42", "3_5": "43-44", "5_6": "45-46", "6_0": "47-48", "1_6": "52-53", "7_4": "54-55", "4_2": "56-57"})}})
            this._row = D.rowBar(figure, {left: 25, width: 57, top: 104.3, pitch: 4.6, fontSize: 3.4})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._row(s)
            return []
         },

// Slide 22: "Designing an Ant Brain".
\TLV slide22(/_top)
   /_top
      m5+ant_fsm(1'b0)
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(22)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 22, {primitives: {...D.states([
               [39.5, 71.1], [91.2, 71.1], [149.9, 71.1], [91.2, 112.5], [149.9, 112.5]]),
               ...D.arcs({"0_0": "670-834", "0_1": "667-668", "1_1": "547-665", "1_3": "384-385", "2_1": "386-387", "2_2": "393-546",
                          "2_3": "381-382", "3_2": "388-389", "3_4": "379-380", "4_2": "391-392", "4_4": "2-377"})}})
            this._sensors = D.text(figure, 10, 128, {fontSize: 6, fontWeight: "bold"})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._sensors.set({text: `L = ${'$l'.asInt()}   R = ${'$r'.asInt()}`})
            return []
         },

// Slide 34: "Specifying Outputs for a Moore Machine" (01/10 detector). States: 0 A .. 4 E.
\TLV slide34(/_top)
   /_top
      m5+rnd()
      $reset = *reset;
      $in = $rnd[5];
      $state[2:0] = *reset ? 3'd0 : >>1$next;
      $next[2:0] = *reset ? 3'd0 :
         ($state == 3'd0) ? ($in ? 3'd2 : 3'd1) :
         ($state == 3'd1 || $state == 3'd4) ? ($in ? 3'd3 : 3'd1) :
                                             ($in ? 3'd2 : 3'd4);
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(34)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 34, {primitives: {...D.states([
               [30.1, 106.8], [50.8, 86.1], [50.8, 127.5], [92.2, 86.1], [92.2, 127.5]]),
               ...D.arcs({reset: "29-30", "0_1": "13-14", "0_2": "19-20", "1_1": "5-7", "1_3": "11-12", "2_2": "2-4", "2_4": "17-18",
                          "3_2": "23-24", "3_4": "25-26", "4_1": "21-22", "4_3": "27-28"})}})
            this._row = D.rowBar(figure, {left: 109, width: 82, top: 74.9, pitch: 6.32, fontSize: 4.3})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, '$reset'.asBool() ? "reset" : `${s}_${next}`)
            this._row('$reset'.asBool() ? 0 : 1 + 2 * '$state'.asInt() + '$in'.asInt())
            return []
         },

// Slide 35: "Specifying Outputs for a Mealy Machine" (01/10 detector). States: 0 A, 1 B, 2 C.
\TLV slide35(/_top)
   /_top
      m5+rnd()
      $reset = *reset;
      $in = $rnd[5];
      $state[1:0] = *reset ? 2'd0 : >>1$next;
      $next[1:0] = *reset ? 2'd0 : $in ? 2'd2 : 2'd1;
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(35)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 35, {primitives: {...D.states([[47.9, 104.4], [68.6, 83.6], [68.6, 125.0]]),
               ...D.arcs({reset: "19-20", "0_1": "9-10", "0_2": "13-14", "1_1": "7,21-22", "1_2": "15-16", "2_1": "17-18", "2_2": "4-6"})}})
            this._row = D.rowBar(figure, {left: 109.5, width: 82, top: 80.1, pitch: 6.33, fontSize: 4.3})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, '$reset'.asBool() ? "reset" : `${s}_${next}`)
            this._row('$reset'.asBool() ? 0 : 1 + 2 * '$state'.asInt() + '$in'.asInt())
            return []
         },

// Slide 42: "Example: Vending Machine".
\TLV slide42(/_top)
   /_top
      m5+vending_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(42)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 42, {primitives: {...D.states([[47.7, 71.8], [47.7, 92.6], [47.7, 113.2], [47.7, 134.0]]),
               ...D.arcs({reset: "5-6", "0_1": "8-9", "0_2": "15-347", "1_2": "10-11", "1_3": "349-681", "2_3": "12-13"})}})
            this._row = D.rowBar(figure, {left: 94, width: 85, top: 60.5, pitch: 4.89, fontSize: 4.3})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            // Opening resets (the Reset arrow).
            D.showArc(this.liveDocElements, '$open'.asBool() ? "reset" : `${s}_${next}`)
            this._row(s === 3 ? 12 : 4 * s + 2 * '$d'.asInt() + '$n'.asInt())
            return []
         },

// Slide 50: "Example: Traffic Light Controller" (3rd): state diagram, plus the lights.
\TLV slide50(/_top)
   /_top
      m5+traffic_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(50)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 50, {primitives: {...D.states([[140.9, 61.6], [116.6, 85.8], [140.9, 109.9], [165.0, 85.8]]),
               ...D.arcs({"0_0": "14-208", "0_1": "6-7", "1_1": "209-476", "1_2": "8-9", "2_2": "744-971", "2_3": "10-11", "3_3": "477-743", "3_0": "12-13"})}})
            this._row = D.rowBar(figure, {left: 31, width: 22, top: 75.2, pitch: 8.67, fontSize: 3.5, height: 5})
            // Highway and farm road lights: red, yellow, green.
            this._lights = [116, 128].map((top, i) => {
               D.text(figure, 12, top - 2.5).set({text: ["Highway", "Farm"][i]})
               return [0, 1, 2].map(j => {
                  const c = new fabric.Circle({left: 40 + j * 7, top, radius: 2.8, originX: "center", originY: "center", stroke: "#555", strokeWidth: 0.4})
                  figure.add(c)
                  return c
               })
            })
            this._inputs = D.text(figure, 12, 137, {fontSize: 4})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._row(s)
            // Lit light index (0 red, 1 yellow, 2 green) for highway and farm road.
            const lit = [[2, 1, 0, 0][s], [0, 0, 2, 1][s]]
            const colors = ["#e53935", "#fdd835", "#43a047"]
            this._lights.forEach((head, i) => head.forEach((c, j) => c.set({fill: j === lit[i] ? colors[j] : "#e0e0e0"})))
            this._inputs.set({text: `C=${'$c'.asInt()}  TL=${'$tl'.asInt()}  TS=${'$ts'.asInt()}  ST=${'$st'.asInt()}`})
            return []
         },

// Slide 51: "Example: Traffic Light Controller" (4th): state table.
\TLV slide51(/_top)
   /_top
      m5+traffic_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(51)},
         init() {
            const figure = this.global.slideDeck.figure(this, 51)
            this._row = this.global.slideDeck.rowBar(figure, {left: 6, width: 180, top: 71.6, pitch: 4.91, fontSize: 3.2})
            return {figure}
         },
         render() {
            const c = '$c'.asInt(), tl = '$tl'.asInt(), ts = '$ts'.asInt(), s = '$state'.asInt()
            this._row([c && tl ? 2 : c ? 1 : 0, ts ? 4 : 3, c && ! tl ? 5 : c ? 7 : 6, ts ? 9 : 8][s])
            return []
         },

// Slide 24: "Transition Truth Table" (ant brain; the table lists only some rows).
\TLV slide24(/_top)
   /_top
      m5+ant_fsm(1'b0)
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(24)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 24, {primitives: {...D.states([
               [80.9, 60.1], [124.6, 60.1], [174.0, 60.1], [124.6, 95.0], [174.0, 95.0]]),
               ...D.arcs({"0_0": "13-150", "0_1": "11-12", "1_1": "151-287", "1_3": "7-8", "2_1": "595-596", "2_2": "288-422",
                          "2_3": "599-600", "3_2": "597-598", "3_4": "593-594", "4_2": "9-10", "4_4": "423-592"})}})
            this._row = D.rowBar(figure, {left: 15, width: 76, top: 96.4, pitch: 6.04, fontSize: 3.6})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt(), l = '$l'.asInt(), r = '$r'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            // Listed rows: LOST (00, -1, 1-), A (00, 01, 1-), B (-0, -1).
            this._row([r ? 1 : l ? 2 : 0, null, 3 + (l ? 2 : r), 6 + r, null][s])
            return []
         },

// Slide 26: "Synthesis of Next State and Output Functions" (ant brain, encoded table).
// This table sends E/G to A on L + R; the diagram (and ant_fsm) stays in E/G.
\TLV slide26(/_top)
   /_top
      m5+ant_fsm(1'b0)
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(26)},
         init() {
            const figure = this.global.slideDeck.figure(this, 26)
            this._row = this.global.slideDeck.rowBar(figure, {left: 14.5, width: 74, top: 58.7, pitch: 6.04, fontSize: 4.3})
            return {figure}
         },
         render() {
            const s = '$state'.asInt(), l = '$l'.asInt(), r = '$r'.asInt()
            // Rows: 000, 001 (00, -1, 1-); 010 (00, 01, 1-); 011, 100 (-0, -1).
            this._row(s < 2 ? 3 * s + (r ? 1 : l ? 2 : 0) : s === 2 ? 6 + (l ? 2 : r) : 9 + 2 * (s - 3) + r)
            return []
         },

// Slide 28: "Don't Cares in FSM Synthesis" (ant brain, encoded). Every 16 cycles the ant is
// dropped into a random state: unused 101 and 110 recover via LOST; 111 is stuck ("deep trouble").
\TLV slide28(/_top)
   /_top
      m5+ant_fsm(*cyc_cnt[3:0] == 4'b0)
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(28)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 28, {primitives: {...D.states([
               [60.1, 92.8], [103.2, 92.8], [151.9, 92.8], [103.2, 127.4], [151.9, 127.4], [25.3, 105.0], [39.8, 128.0], [68.4, 136.6]]),
               ...D.arcs({"0_0": "13-131", "0_1": "11-12", "1_1": "132-269", "1_3": "7-8", "2_1": "572-573", "2_2": "270-402",
                          "2_3": "576-577", "3_2": "574-575", "3_4": "570-571", "4_2": "9-10", "4_4": "403-569",
                          "5_0": "706-756", "6_0": "757-905", "7_7": "581-705"})}})
            this._sensors = D.text(figure, 120, 141, {fontSize: 5, fontWeight: "bold"})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._sensors.set({text: `L = ${'$l'.asInt()}   R = ${'$r'.asInt()}`})
            return []
         },

// Slide 30: "Ant Brain Revisited".
\TLV slide30(/_top)
   /_top
      m5+ant_fsm(1'b0)
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(30)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 30, {primitives: {...D.states([
               [42.5, 75.5], [94.2, 75.5], [152.9, 75.5], [94.2, 116.9], [152.9, 116.9]]),
               ...D.arcs({"0_0": "13-177", "0_1": "11-12", "1_1": "178-315", "1_3": "7-8", "2_1": "680-681", "2_2": "316-476",
                          "2_3": "684-685", "3_2": "682-683", "3_4": "678-679", "4_2": "9-10", "4_4": "477-677"})}})
            this._sensors = D.text(figure, 10, 132, {fontSize: 6, fontWeight: "bold"})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._sensors.set({text: `L = ${'$l'.asInt()}   R = ${'$r'.asInt()}`})
            return []
         },

// Slide 31: "New Improved Brain" (B and C merged), driven by the 5-state brain.
\TLV slide31(/_top)
   /_top
      m5+ant_fsm(1'b0)
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(31)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 31, {primitives: {...D.states([[53.1, 88.9], [104.8, 88.9], [163.5, 88.9], [104.8, 130.2]]),
               ...D.arcs({"0_0": "10-174", "0_1": "8-9", "1_1": "175-312", "1_3": "6-7", "2_1": "850-851", "2_2": "313-473",
                          "2_3": "854-855", "3_2": "852-853", "3_3": "474-849"})}})
            this._sensors = D.text(figure, 10, 135, {fontSize: 6, fontWeight: "bold"})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, merge = (s) => s === 4 ? 3 : s
            const s = merge('$state'.asInt()), next = merge('$next'.asInt())
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._sensors.set({text: `L = ${'$l'.asInt()}   R = ${'$r'.asInt()}`})
            return []
         },

// Slide 32: "New Brain Implementation" (merged brain table).
\TLV slide32(/_top)
   /_top
      m5+ant_fsm(1'b0)
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(32)},
         init() {
            const figure = this.global.slideDeck.figure(this, 32)
            this._row = this.global.slideDeck.rowBar(figure, {left: 11, width: 66, top: 59.0, pitch: 6.03, fontSize: 4.3})
            return {figure}
         },
         render() {
            const s = Math.min('$state'.asInt(), 3), l = '$l'.asInt(), r = '$r'.asInt()
            // Rows: 00, 01 (00, -1, 1-); 10 (00, 01, 1-); 11 (-0, -1).
            this._row(s < 2 ? 3 * s + (r ? 1 : l ? 2 : 0) : s === 2 ? 6 + (l ? 2 : r) : 9 + r)
            return []
         },

// Slides 43, 45: "Example: Vending Machine (cont'd)": encoded and one-hot state tables.
\TLV vending_table(/_top, _n)
   /_top
      m5+vending_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(_n)},
         init() {
            const figure = this.global.slideDeck.figure(this, _n)
            this._row = this.global.slideDeck.rowBar(figure, {
               43: {left: 62, width: 80, top: 62.3, pitch: 4.88, fontSize: 4.3},
               45: {left: 16.5, width: 81, top: 65.9, pitch: 4.89, fontSize: 4.0},
            }[_n])
            return {figure}
         },
         render() {
            const s = '$state'.asInt()
            this._row(s === 3 ? 12 : 4 * s + 2 * '$d'.asInt() + '$n'.asInt())
            return []
         },

// Slide 46: "Equivalent Mealy and Moore State Diagrams". Mealy open leads Moore by a cycle.
\TLV slide46(/_top)
   /_top
      m5+vending_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(46)},
         init() {
            const D = this.global.slideDeck
            const ys = [73.3, 94.0, 114.7, 135.4]
            // Arcs: Moore, then the same arcs of the Mealy diagram (prefix marc_).
            const arcs = [
               {reset: "6-7", "0_0": "540-705", "0_1": "8-9", "0_2": "1893-2233", "1_1": "355-539", "1_2": "10-11", "1_3": "14-354",
                "2_2": "1525-1708", "2_3": "12-13", "3_0": "706-1524", "3_3": "1709-1892"},
               {reset: "2238-2239", "0_0": "2772-2937", "0_1": "2240-2241", "0_2": "4125-4465", "1_1": "2587-2771", "1_2": "2242-2243", "1_3": "2246-2586",
                "2_2": "3757-3940", "2_3": "2244-2245", "3_0": "2938-3756", "3_3": "3941-4124"}]
            const figure = D.figure(this, 46, {primitives: {
               ...D.states(ys.map(y => [56.4, y])), ...D.states(ys.map(y => [161.5, y]), "mealy_"),
               ...D.arcs(arcs[0]), ...D.arcs(arcs[1], "marc_")}})
            this._io = D.text(figure, 92, 96, {fontSize: 4.5, lineHeight: 1.3})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showStates(this.liveDocElements, s, next, "mealy_")
            D.showArc(this.liveDocElements, `${s}_${next}`)
            D.showArc(this.liveDocElements, `${s}_${next}`, "marc_")
            this._io.set({text: `N = ${'$n'.asInt()}   D = ${'$d'.asInt()}\nopen (Moore) = ${+(s === 3)}\nopen (Mealy) = ${+(next === 3)}`})
            return []
         },

// Slides 58, 59: "State Minimization Example", "Method of Successive Partitions".
\TLV seq_slide(/_top, _n)
   /_top
      m5+seq_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(_n)},
         init() {
            const D = this.global.slideDeck
            // Arcs from S3..S6 to S0 (<s>_0_<x>) are a stub (left for X = 0) plus the shared return bus (28-30).
            const {bar, centers, io, arcs} = {
               58: {bar: {left: 57, width: 131, top: 66.3, pitch: 4.6, fontSize: 4.3}, io: [100, 115],
                    centers: [[47.9, 105.4], [34.1, 119.2], [61.7, 119.2], [27.1, 133.0], [41.0, 133.0], [54.8, 133.0], [68.6, 133.0]],
                    arcs: {"0_1": "14-15", "0_2": "24-25", "1_3": "16-17", "1_4": "18-19", "2_5": "20-21", "2_6": "22-23",
                           "3_0_0": "28-32", "3_0_1": "28-30,33-34", "4_0_0": "28-30,35-36", "4_0_1": "28-30,37-38",
                           "5_0_0": "28-30,39-40", "5_0_1": "28-30,41-42", "6_0_0": "28-30,43-44", "6_0_1": "28-30,45-46"}},
               59: {bar: {left: 37, width: 130, top: 52.1, pitch: 4.6, fontSize: 4.4}, io: [131, 132], centers: [], arcs: {}},
            }[_n]
            const figure = D.figure(this, _n, {primitives: {...D.states(centers), ...D.arcs(arcs)}})
            this._row = D.rowBar(figure, bar)
            this._io = D.text(figure, ...io, {fontSize: 6, fontWeight: "bold"})
            return {figure}
         },
         render() {
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            if (this.liveDocElements) {
               D.showStates(this.liveDocElements, s, next)
               D.showArc(this.liveDocElements, s > 2 ? `${s}_0_${'$x'.asInt()}` : `${s}_${next}`)
            }
            this._row(s)
            this._io.set({text: `X = ${'$x'.asInt()}   out = ${'$out'.asInt()}`})
            return []
         },

// Slide 60: "Minimized FSM" (010/110 detector), driven by the 7-state detector.
\TLV slide60(/_top)
   /_top
      m5+seq_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(60)},
         init() {
            const D = this.global.slideDeck
            // Arcs to S0 are a stub plus the shared return bus (19-21); S4' has one stub per X (left for X = 0).
            const figure = D.figure(this, 60, {primitives: {...D.states([[58.1, 94.0], [58.1, 112.9], [44.3, 126.7], [71.9, 126.2]]),
               ...D.arcs({"0_1": "15-16", "1_2": "11-12", "1_3": "13-14", "2_0": "19-23", "3_0_0": "19-21,24-25", "3_0_1": "19-21,26-27"})}})
            this._row = D.rowBar(figure, {left: 58, width: 129, top: 63.4, pitch: 4.6, fontSize: 3.8})
            this._io = D.text(figure, 100, 110, {fontSize: 6, fontWeight: "bold"})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            // S0; S1' = S1, S2; S3' = S3, S5; S4' = S4, S6.
            const D = this.global.slideDeck, merge = (s) => [0, 1, 1, 2, 3, 2, 3][s]
            const s = merge('$state'.asInt()), next = merge('$next'.asInt())
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, s === 3 ? `3_0_${'$x'.asInt()}` : `${s}_${next}`)
            this._row(s)
            this._io.set({text: `X = ${'$x'.asInt()}   out = ${'$out'.asInt()}`})
            return []
         },

// Slide 61: "More Complex State Minimization" (multiple inputs).
\TLV slide61(/_top)
   /_top
      m5+multi_input_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(61)},
         init() {
            const D = this.global.slideDeck
            // The diagram draws S1 on 11 to S5 (1_5); the table (and multi_input_fsm) says S4, which has no arc.
            const figure = D.figure(this, 61, {primitives: {...D.states([
               [38.8, 70.9], [66.4, 70.9], [38.8, 96.7], [66.4, 96.7], [38.8, 122.7], [66.4, 122.7]]),
               ...D.arcs({"0_0": "228-318", "0_1": "33-34", "0_2": "37-38", "0_3": "41-42", "1_0": "35-36", "1_1": "137-227", "1_3": "23-24", "1_5": "857-1272",
                          "2_1": "27-28", "2_2": "743-856", "2_3": "25-26", "2_4": "13-14", "3_0": "43-44", "3_1": "21-22", "3_4": "29-30", "3_5": "11-12",
                          "4_0": "319-742", "4_1": "31-32", "4_2": "15-16", "4_5": "17-18", "5_0": "39-40", "5_1": "1273-1696", "5_4": "19-20", "5_5": "45-136"})}})
            this._row = D.rowBar(figure, {left: 107, width: 73, top: 83.9, pitch: 4.88, fontSize: 3.6})
            this._io = D.text(figure, 104, 135, {fontSize: 6, fontWeight: "bold"})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._row(s)
            this._io.set({text: `inputs = ${'$in'.asInt().toString(2).padStart(2, "0")}`})
            return []
         },

// Slide 62: "Minimized FSM" (S0' = S0, S4; S3' = S3, S5), driven by slide 61's FSM.
\TLV slide62(/_top)
   /_top
      m5+multi_input_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(62)},
         init() {
            const figure = this.global.slideDeck.figure(this, 62)
            this._row = this.global.slideDeck.rowBar(figure, {left: 107, width: 72, top: 80.8, pitch: 4.93, fontSize: 4.4})
            return {figure}
         },
         render() {
            const s = '$state'.asInt()
            this._row([0, 1, 2, 3, 0, 3][s])
            return []
         },

// Slide 64: "Minimizing States May Not Yield Best Circuit" (edge detector, 3 states).
\TLV slide64(/_top)
   /_top
      m5+edge_input()
      $state[1:0] = *reset ? 2'd0 : >>1$next;
      $next[1:0] = (*reset || ! $x) ? 2'd0 : ($state == 2'd0) ? 2'd1 : 2'd3;
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(64)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 64, {primitives: {...D.states([[36.6, 74.5], [71.1, 90.0], null, [36.6, 107.2]]),
               ...D.arcs({"0_0": "358-451", "0_1": "198-277", "1_0": "278-357", "1_3": "7-100", "3_0": "196-197", "3_3": "101-195"})}})
            this._row = D.rowBar(figure, {left: 113.5, width: 50, top: 61.3, pitch: 6.02, fontSize: 4.2})
            this._io = D.text(figure, 15, 132, {fontSize: 6, fontWeight: "bold"})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt(), x = '$x'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._row(3 * x + (s === 3 ? 2 : s))
            this._io.set({text: `X = ${x}   out = ${+(s === 1)}`})
            return []
         },

// Slide 65: "Another Implementation of Edge Detector" (state = last two inputs).
\TLV slide65(/_top)
   /_top
      m5+edge_input()
      $state[1:0] = *reset ? 2'd0 : >>1$next;
      $next[1:0] = *reset ? 2'd0 : {$state[0], $x};
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(65)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 65, {primitives: {...D.states([[55.6, 69.4], [83.1, 91.8], [28.0, 91.8], [55.6, 114.2]]),
               ...D.arcs({"0_0": "360-453", "0_1": "241-359", "1_2": "5-103", "1_3": "672-808", "2_0": "104-240", "2_1": "454-551", "3_2": "553-671", "3_3": "809-902"})}})
            this._io = D.text(figure, 15, 132, {fontSize: 6, fontWeight: "bold"})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._io.set({text: `X = ${'$x'.asInt()}   out = ${+(s === 1)}`})
            return []
         },

// Slide 4: "Finite State Machine Representations" (a 5-state FSM on input In).
\TLV slide4(/_top)
   /_top
      m5+rnd()
      $in = $rnd[7];
      $state[2:0] = *reset ? 3'd1 : >>1$next;
      $next[2:0] = *reset ? 3'd1 :
         ($state == 3'd1) ? 3'd2 :
         ($state == 3'd2) ? 3'd7 :
         ($state == 3'd7) ? 3'd6 :
         ($state == 3'd6) ? ($in ? 3'd4 : 3'd2) :
                            ($in ? 3'd2 : 3'd1);
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(4)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 4, {primitives: {...D.states([
               null, [88.0, 89.7], [129.4, 89.7], null, [108.8, 110.5], null, [150.2, 110.5], [170.8, 89.7]]),
               ...D.arcs({"1_2": "7-8", "2_7": "9-10", "7_6": "11-12", "6_4": "13-14", "4_1": "15-16", "4_2": "17-18", "6_2": "19-20"})}})
            this._io = D.text(figure, 162, 115, {fontSize: 5, fontWeight: "bold"})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            this._io.set({text: `In = ${'$in'.asInt()}`})
            return []
         },

// Slide 5: "Example Finite State Machine Diagram" (combination lock), reset every 16 cycles.
// States: 0 S1, 1 S2, 2 S3, 3 OPEN, 4 ERR.
\TLV slide5(/_top)
   /_top
      m5+rnd()
      $reset = *reset || *cyc_cnt[3:0] == 4'hF;
      $new = $rnd[10];
      $equal = $rnd[13] | $rnd[14] | $rnd[0];
      $state[2:0] = *reset ? 3'd0 : >>1$next;
      $next[2:0] = $reset ? 3'd0 :
         ($state >= 3'd3 || ! $new) ? $state :
         $equal ? $state + 3'd1 : 3'd4;
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(5)},
         init() {
            const D = this.global.slideDeck
            // labelsOnTop: the PDF paints state names under their circles, which showStates() fills.
            const figure = D.figure(this, 5, {labelsOnTop: true, primitives: {...D.states([
               [51.5, 103.8], [87.1, 103.7], [122.9, 103.8], [158.5, 103.7], [158.6, 73.2]]),
               ...D.arcs({reset: "3-4", "0_1": "641-642", "1_2": "643-644", "2_3": "645-646", "0_4": "9-219", "1_4": "220-430", "2_4": "431-640",
                          "0_0": "647-750", "1_1": "751-854", "2_2": "855-958", "3_3": "959-1062", "4_4": "1063-1165"})}})
            this._io = D.text(figure, 40, 132, {fontSize: 5, fontWeight: "bold"})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, '$reset'.asBool() ? "reset" : `${s}_${next}`)
            this._io.set({text: `reset = ${'$reset'.asInt()}   new = ${'$new'.asInt()}   equal = ${'$equal'.asInt()}`})
            return []
         },

// Slide 6: "Can Any Sequential System be Represented with a State Diagram?" (shift register).
// State = OUT1 OUT2 OUT3.
\TLV slide6(/_top)
   /_top
      m5+rnd()
      $in = $rnd[1];
      $state[2:0] = *reset ? 3'd0 : >>1$next;
      $next[2:0] = *reset ? 3'd0 : {$in, $state[2:1]};
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(6)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 6, {primitives: {...D.states([
               [47.6, 110.8], [68.3, 131.6], [89.0, 110.8], [144.1, 131.6], [68.3, 90.2], [123.5, 110.8], [144.1, 90.2], [164.9, 110.8]]),
               ...D.arcs({"0_0": "536-836", "0_4": "518-519", "1_0": "528-529", "1_4": "516-517", "2_1": "524-525", "2_5": "113-212", "3_1": "522-523", "3_5": "520-521",
                          "4_2": "526-527", "4_6": "111-112", "5_2": "10-110", "5_6": "213-214", "6_3": "534-535", "6_7": "532-533", "7_3": "530-531", "7_7": "215-515"})}})
            // Values of IN, OUT1, OUT2, OUT3.
            this._chips = [[86, 60.3], [146, 44.6], [175.5, 44.6], [205, 44.6]].map(([x, y]) =>
               D.text(figure, x, y, {fontSize: 5, fontWeight: "bold", originX: "center", originY: "center"}))
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt(), inV = '$in'.asInt()
            D.showStates(this.liveDocElements, s, next)
            D.showArc(this.liveDocElements, `${s}_${next}`)
            ;[inV, s >> 2 & 1, s >> 1 & 1, s & 1].forEach((v, i) => this._chips[i].set({text: String(v), fill: v ? "#2e7d32" : "#9e9e9e"}))
            return []
         },

// Slide 11: "Implementation" (3-bit up-counter table and K-maps; state = C3 C2 C1).
\TLV slide11(/_top)
   /_top
      m5+counter_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(11)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 11)
            this._row = D.rowBar(figure, {left: 30, width: 60, top: 65.8, pitch: 6.33, fontSize: 4.4})
            // The current cell of the N3, N2, N1 K-maps (rows C1; columns C2 C3 = 00, 10, 11, 01).
            this._cells = [27.5, 92.3, 157.0].map(left => {
               const r = new fabric.Rect({left, width: 9.6, height: 9.6, originX: "center", originY: "center",
                                          fill: "rgba(255, 152, 0, 0.30)", strokeWidth: 0})
               figure.add(r)
               return r
            })
            return {figure}
         },
         render() {
            const s = '$state'.asInt()
            const col = [0, 3, 1, 2]
            const c = col[(s >> 1 & 1) * 2 + (s >> 2)]
            this._row(s)
            this._cells.forEach((r, i) => r.set({left: [27.5, 92.3, 157.0][i] + 0.9 + 10.35 * c, top: (s & 1 ? 139.1 : 128.8) + 1.6}))
            return []
         },

// Slide 41: "Example: Vending Machine (cont'd)" (tree of input sequences). Open states return to S0.
\TLV slide41(/_top)
   /_top
      m5+rnd()
      $n = $rnd[12:11] == 2'd1;
      $d = $rnd[12:11] == 2'd2;
      $open = $state >= 3'd4;
      $state[2:0] = *reset ? 3'd0 : >>1$next;
      $next[2:0] = (*reset || $open) ? 3'd0 :
         ($state == 3'd0) ? ($n ? 3'd1 : $d ? 3'd2 : 3'd0) :
         ($state == 3'd1) ? ($n ? 3'd3 : $d ? 3'd4 : 3'd1) :
         ($state == 3'd2) ? ($n ? 3'd5 : $d ? 3'd6 : 3'd2) :
                            ($n ? 3'd7 : 3'd3);
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(41)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 41, {primitives: {...D.states([
               [154.7, 63.2], [139.1, 83.9], [170.2, 83.9], [123.6, 104.6], [144.2, 104.6], [165.0, 104.6], [185.6, 104.6], [123.6, 128.8]]),
               ...D.arcs({reset: "3-4", "0_1": "15-16", "0_2": "6-7", "1_3": "18-19", "1_4": "12-13", "2_5": "24-25", "2_6": "9-10", "3_7": "21-22"})}})
            this._io = D.text(figure, 140, 124, {fontSize: 5, fontWeight: "bold"})
            return {figure}
         },
         render() {
            if (!this.liveDocElements) return []
            const D = this.global.slideDeck, s = '$state'.asInt(), next = '$next'.asInt()
            D.showStates(this.liveDocElements, s, next)
            // Opening resets (the Reset arrow).
            D.showArc(this.liveDocElements, '$open'.asBool() ? "reset" : `${s}_${next}`)
            this._io.set({text: `N = ${'$n'.asInt()}   D = ${'$d'.asInt()}   open = ${'$open'.asInt()}`})
            return []
         },

// Slide 48: "Example: Traffic Light Controller (cont')" (the intersection), with lights and a farm-road car.
\TLV slide48(/_top)
   /_top
      m5+traffic_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(48)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 48)
            // Light heads, red, yellow, green: highway (horizontal, SE corner), farm road (vertical, NW corner).
            const light = (left, top) => {
               const c = new fabric.Circle({left, top, radius: 2.4, originX: "center", originY: "center", stroke: "#555", strokeWidth: 0.4})
               figure.add(c)
               return c
            }
            this._lights = [[0, 1, 2].map(j => light(103 + j * 5.5, 111)), [0, 1, 2].map(j => light(78.5, 70 + j * 5.5))]
            // A car waiting at the farm-road sensor when C.
            this._car = new fabric.Rect({left: 85.3, top: 71, width: 3.6, height: 7, rx: 0.8, ry: 0.8, fill: "#1e88e5", strokeWidth: 0})
            figure.add(this._car)
            this._io = D.text(figure, 110, 124, {fontSize: 5, fontWeight: "bold"})
            return {figure}
         },
         render() {
            const s = '$state'.asInt()
            const lit = [[2, 1, 0, 0][s], [0, 0, 2, 1][s]]
            const colors = ["#e53935", "#fdd835", "#43a047"]
            this._lights.forEach((head, i) => head.forEach((c, j) => c.set({fill: j === lit[i] ? colors[j] : "#e0e0e0"})))
            this._car.set({visible: '$c'.asBool()})
            this._io.set({text: `${["HG", "HY", "FG", "FY"][s]}   C = ${'$c'.asInt()}   TS = ${'$ts'.asInt()}   TL = ${'$tl'.asInt()}`})
            return []
         },

// Slide 49: "Example: Traffic Light Controller (cont')" (inputs, outputs, and states tabulated).
\TLV slide49(/_top)
   /_top
      m5+traffic_fsm()
      $reset = *reset;
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(49)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 49)
            this._row = D.rowBar(figure, {left: 18, width: 75, top: 121.1, pitch: 5.53, fontSize: 3.8})
            // Values of reset, C, TS, TL (inputs) and ST (output), left of their names.
            this._chips = [[15, 59.0], [15, 63.8], [15, 68.6], [15, 73.4], [91, 68.6]].map(([x, y]) =>
               D.text(figure, x, y + 2.5, {fontSize: 4.3, fontWeight: "bold", originX: "center", originY: "center"}))
            return {figure}
         },
         render() {
            this._row('$state'.asInt())
            const reset = '$reset'.asInt()
            const vals = [reset, '$c'.asInt(), '$ts'.asInt(), '$tl'.asInt(), '$st'.asInt()]
            vals.forEach((v, i) => this._chips[i].set({text: String(v), fill: v ? "#2e7d32" : "#9e9e9e"}))
            return []
         },

// Slide 53: "Vending Machine Example (PLD mapping)": pin values (Q1 Q0 = state). The FSM's return
// to 0 after opening is the Reset input here.
\TLV slide53(/_top)
   /_top
      m5+vending_fsm()
      \viz_js
         box: {m5_slide_box},
         where: {m5_slide_where(53)},
         init() {
            const D = this.global.slideDeck
            const figure = D.figure(this, 53)
            // N, D, Reset, Q0, Q1, Open.
            this._chips = [[48, 72.8], [48, 105.4], [40, 138.6], [198, 55.1], [198, 88.1], [203, 120.8]].map(([x, y]) =>
               D.text(figure, x, y + 2.4, {fontSize: 4.5, fontWeight: "bold", originX: "center", originY: "center"}))
            return {figure}
         },
         render() {
            const s = '$state'.asInt(), open = '$open'.asInt(), n = '$n'.asInt()
            const vals = [n, '$d'.asInt(), open, s & 1, s >> 1, open]
            vals.forEach((v, i) => this._chips[i].set({text: String(v), fill: v ? "#2e7d32" : "#9e9e9e"}))
            return []
         },

\TLV
   m5+slide_deck(/deck)
   // Page 1
   m5+slide(/slide1, 1)
   m5+slide(/slide2, 2)
   m5+slide(/slide3, 3)
   m5+slide4(/slide4)
   m5+slide5(/slide5)
   m5+slide6(/slide6)
   // Page 2
   m5+slide7(/slide7)
   m5+slide(/slide8, 8)
   m5+slide(/slide9, 9)
   m5+slide10(/slide10)
   m5+slide11(/slide11)
   m5+slide(/slide12, 12)
   // Page 3
   m5+slide13(/slide13)
   m5+slide14(/slide14)
   m5+slide(/slide15, 15)
   m5+slide16(/slide16)
   m5+slide(/slide17, 17)
   m5+slide(/slide18, 18)
   // Page 4
   m5+slide(/slide19, 19)
   m5+slide(/slide20, 20)
   m5+slide(/slide21, 21)
   m5+slide22(/slide22)
   m5+slide(/slide23, 23)
   m5+slide24(/slide24)
   // Page 5
   m5+slide(/slide25, 25)
   m5+slide26(/slide26)
   m5+slide(/slide27, 27)
   m5+slide28(/slide28)
   m5+slide(/slide29, 29)
   m5+slide30(/slide30)
   // Page 6
   m5+slide31(/slide31)
   m5+slide32(/slide32)
   m5+slide(/slide33, 33)
   m5+slide34(/slide34)
   m5+slide35(/slide35)
   m5+slide(/slide36, 36)
   // Page 7
   m5+slide(/slide37, 37)
   m5+slide(/slide38, 38)
   m5+slide(/slide39, 39)
   m5+slide(/slide40, 40)
   m5+slide41(/slide41)
   m5+slide42(/slide42)
   // Page 8
   m5+vending_table(/slide43, 43)
   m5+slide(/slide44, 44)
   m5+vending_table(/slide45, 45)
   m5+slide46(/slide46)
   m5+slide(/slide47, 47)
   m5+slide48(/slide48)
   // Page 9
   m5+slide49(/slide49)
   m5+slide50(/slide50)
   m5+slide51(/slide51)
   m5+slide(/slide52, 52)
   m5+slide53(/slide53)
   m5+slide(/slide54, 54)
   // Page 10
   m5+slide(/slide55, 55)
   m5+slide(/slide56, 56)
   m5+slide(/slide57, 57)
   m5+seq_slide(/slide58, 58)
   m5+seq_slide(/slide59, 59)
   m5+slide60(/slide60)
   // Page 11
   m5+slide61(/slide61)
   m5+slide62(/slide62)
   m5+slide(/slide63, 63)
   m5+slide64(/slide64)
   m5+slide65(/slide65)
   m5+slide(/slide66, 66)
   // Page 12
   m5+slide(/slide67, 67)
   m5+slide(/slide68, 68)
   m5+slide(/slide69, 69)
   m5+slide(/slide70, 70)
   m5+slide(/slide71, 71)
   m5+slide(/slide72, 72)
   // Page 13
   m5+slide(/slide73, 73)
\SV
   endmodule
