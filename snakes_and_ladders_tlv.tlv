\m5_TLV_version 1d: tl-x.org
\SV
   // ============================================================
   //  SNAKES & LADDERS  (Saanp Seedhi)  —  idiomatic TL-Verilog
   //
   //  Same game as snakes_and_ladders.tlv, but the engine is written
   //  in pure TL-Verilog: state lives in single-assignment $signals
   //  that recirculate with >>1$ (previous-cycle reference) instead of
   //  Verilog `always_ff` blocks.
   //
   //  Two players race from square 0 (start) to square 100. Each cycle
   //  the player whose turn it is rolls a die (1..6) and advances.
   //    - Foot of a LADDER -> climb up.   - Head of a SNAKE -> slide down.
   //    - Overshoot 100 -> stay put (must land exactly on 100 to win).
   // ============================================================
   m5_makerchip_module
\TLV
   // -------------------------------------------------------------
   //  GAME ENGINE  (all state via >>1$ recirculation)
   // -------------------------------------------------------------
   $reset = *reset;

   // ---- pseudo-random die ----
   // 16-bit Galois-ish LFSR; map its value to a 1..6 roll.
   $lfsr[15:0] = $reset ? 16'hACE1
                        : {>>1$lfsr[14:0],
                           >>1$lfsr[15] ^ >>1$lfsr[13] ^ >>1$lfsr[12] ^ >>1$lfsr[10]};
   $dice[2:0] = ($lfsr % 16'd6) + 3'd1;            // 1..6

   // ---- whose turn is it this cycle, and is the game still going? ----
   $turn_now    = $reset ? 1'b0 : >>1$turn;        // 0 = Player 1, 1 = Player 2
   $over_prev   = $reset ? 1'b0 : >>1$game_over;
   $do_move     = !$reset && !$over_prev;          // one move per cycle until won

   // ---- current mover's position (previous-cycle registered value) ----
   $p0_prev[6:0] = $reset ? 7'd0 : >>1$p0_pos;
   $p1_prev[6:0] = $reset ? 7'd0 : >>1$p1_pos;
   $cur_pos[6:0] = $turn_now ? $p1_prev : $p0_prev;

   // ---- roll, then apply the overshoot rule ----
   $sum[7:0]    = $cur_pos + $dice;
   $landed[6:0] = ($sum > 8'd100) ? $cur_pos       // overshoot -> stay
                                  : $sum[6:0];

   // ---- snake / ladder redirect (foot->top, head->tail) ----
   $final_pos[6:0] =
      ($landed == 7'd1)  ? 7'd38 :   // ladders
      ($landed == 7'd4)  ? 7'd14 :
      ($landed == 7'd9)  ? 7'd31 :
      ($landed == 7'd21) ? 7'd42 :
      ($landed == 7'd28) ? 7'd84 :
      ($landed == 7'd36) ? 7'd44 :
      ($landed == 7'd51) ? 7'd67 :
      ($landed == 7'd71) ? 7'd91 :
      ($landed == 7'd80) ? 7'd100 :
      ($landed == 7'd16) ? 7'd6  :   // snakes
      ($landed == 7'd47) ? 7'd26 :
      ($landed == 7'd49) ? 7'd11 :
      ($landed == 7'd56) ? 7'd53 :
      ($landed == 7'd62) ? 7'd19 :
      ($landed == 7'd64) ? 7'd60 :
      ($landed == 7'd87) ? 7'd24 :
      ($landed == 7'd93) ? 7'd73 :
      ($landed == 7'd95) ? 7'd75 :
      ($landed == 7'd98) ? 7'd78 :
                           $landed; // plain square

   $win_now = $do_move && ($final_pos == 7'd100);

   // ---- next-state for each player position ----
   $p0_pos[6:0] = $reset                      ? 7'd0 :
                  ($do_move && !$turn_now)    ? $final_pos :
                                                $p0_prev;
   $p1_pos[6:0] = $reset                      ? 7'd0 :
                  ($do_move &&  $turn_now)    ? $final_pos :
                                                $p1_prev;

   // ---- turn, game_over, winner ----
   $turn      = $reset ? 1'b0 : ($do_move ? !$turn_now : $turn_now);
   $game_over = $reset ? 1'b0 : ($over_prev || $win_now);
   $winner    = $reset ? 1'b0 : ($win_now ? $turn_now : (>>1$winner));

   // ---- last-move bookkeeping (purely for the visualization) ----
   $last_player = $reset ? 1'b0  : ($do_move ? $turn_now  : >>1$last_player);
   $last_from[6:0]  = $reset ? 7'd0 : ($do_move ? $cur_pos   : >>1$last_from);
   $last_land[6:0]  = $reset ? 7'd0 : ($do_move ? $landed    : >>1$last_land);
   $last_final[6:0] = $reset ? 7'd0 : ($do_move ? $final_pos : >>1$last_final);
   $last_dice[2:0]  = $reset ? 3'd0 : ($do_move ? $dice      : >>1$last_dice);
   $last_event[1:0] = $reset ? 2'd0 :
                      ($do_move ? (($final_pos > $landed) ? 2'd1 :   // ladder up
                                   ($final_pos < $landed) ? 2'd2 :   // snake down
                                                            2'd0)
                                : >>1$last_event);

   // ---- end the simulation one cycle after someone wins ----
   *passed = >>1$game_over;
   *failed = $game_over && ((($winner ? $p1_pos : $p0_pos)) != 7'd100);

   // -------------------------------------------------------------
   //  VISUAL DEBUG (VIZ): 10x10 board with snakes, ladders, tokens.
   // -------------------------------------------------------------
   \viz_js
      box: {left: 0, top: 0, width: 840, height: 560, strokeWidth: 4, stroke: "#aaa", fill: "#fcfcf7"},
      init() {
         let CELL = 46
         let X0   = 20
         let Y0   = 40
         let ret  = {}

         // Square number (1..100) -> top-left {x,y}. Boustrophedon numbering:
         // bottom row left->right, next row right->left, etc.
         this.cellXY = (n) => {
            let row = Math.floor((n - 1) / 10)          // 0 = bottom
            let idx = (n - 1) % 10
            let col = (row % 2 === 0) ? idx : (9 - idx)
            return {x: X0 + col * CELL, y: Y0 + (9 - row) * CELL}
         }
         this.cellCenter = (n) => {
            let p = this.cellXY(n)
            return {x: p.x + CELL / 2, y: p.y + CELL / 2}
         }

         // Snake / ladder data (matches the redirect logic above).
         let ladders = [[1,38],[4,14],[9,31],[21,42],[28,84],[36,44],[51,67],[71,91],[80,100]]
         let snakes  = [[16,6],[47,26],[49,11],[56,53],[62,19],[64,60],[87,24],[93,73],[95,75],[98,78]]
         let ladderFeet = new Set(ladders.map(l => l[0]))
         let snakeHeads = new Set(snakes.map(s => s[0]))

         ret.title = new fabric.Text("Snakes & Ladders (TL-Verilog)  —  race to square 100", {
            left: 12, top: 8, fontSize: 16, fontWeight: "bold", fill: "#222"})

         // Board cells (rect + number).
         for (let n = 1; n <= 100; n++) {
            let p = this.cellXY(n)
            let fill = ((Math.floor((n-1)/10) + (n-1)) % 2 === 0) ? "#ffffff" : "#eef3f7"
            if (n === 100)         fill = "#fff3b0"     // goal
            if (ladderFeet.has(n)) fill = "#d7f0d0"
            if (snakeHeads.has(n)) fill = "#f6d0d0"
            ret["cell" + n] = new fabric.Rect({
               left: p.x, top: p.y, width: CELL, height: CELL,
               stroke: "#bbb", strokeWidth: 1, fill: fill})
            ret["num" + n] = new fabric.Text(String(n), {
               left: p.x + 3, top: p.y + 2, fontSize: 9, fill: "#789"})
         }

         // Ladders (green) and snakes (red) as lines.
         ladders.forEach((l, i) => {
            let a = this.cellCenter(l[0]), b = this.cellCenter(l[1])
            ret["lad" + i] = new fabric.Line([a.x, a.y, b.x, b.y], {
               stroke: "#2e7d32", strokeWidth: 5, opacity: 0.7, strokeLineCap: "round"})
         })
         snakes.forEach((s, i) => {
            let a = this.cellCenter(s[0]), b = this.cellCenter(s[1])
            ret["snk" + i] = new fabric.Line([a.x, a.y, b.x, b.y], {
               stroke: "#c62828", strokeWidth: 5, opacity: 0.7, strokeLineCap: "round"})
            ret["snkH" + i] = new fabric.Circle({
               left: a.x, top: a.y, radius: 6, originX: "center", originY: "center",
               fill: "#c62828", opacity: 0.85})
         })

         // Player tokens.
         ret.tok0 = new fabric.Circle({left: X0, top: Y0, radius: 11, originX: "center", originY: "center",
            fill: "#1565c0", stroke: "#0d3c78", strokeWidth: 2})
         ret.tok1 = new fabric.Circle({left: X0, top: Y0, radius: 11, originX: "center", originY: "center",
            fill: "#ef6c00", stroke: "#8a3b00", strokeWidth: 2})
         ret.tok0L = new fabric.Text("1", {left: X0, top: Y0, fontSize: 11, fontWeight: "bold",
            originX: "center", originY: "center", fill: "#fff"})
         ret.tok1L = new fabric.Text("2", {left: X0, top: Y0, fontSize: 11, fontWeight: "bold",
            originX: "center", originY: "center", fill: "#fff"})

         // Right-side status panel.
         let PX = 500
         ret.pTitle = new fabric.Text("Game status", {left: PX, top: 44, fontSize: 14, fontWeight: "bold", fill: "#222"})
         ret.diceT  = new fabric.Text("", {left: PX, top: 74,  fontSize: 22, fontWeight: "bold", fill: "#000"})
         ret.turnT  = new fabric.Text("", {left: PX, top: 110, fontSize: 14, fill: "#000"})
         ret.p0T    = new fabric.Text("", {left: PX, top: 140, fontSize: 14, fill: "#1565c0"})
         ret.p1T    = new fabric.Text("", {left: PX, top: 166, fontSize: 14, fill: "#ef6c00"})
         ret.moveT  = new fabric.Text("", {left: PX, top: 200, fontSize: 13, fill: "#000"})
         ret.eventT = new fabric.Text("", {left: PX, top: 226, fontSize: 14, fontWeight: "bold", fill: "#000"})
         ret.winT   = new fabric.Text("", {left: PX, top: 280, fontSize: 22, fontWeight: "bold", fill: "#2e7d32"})
         ret.legend1 = new fabric.Text("\u25CF Player 1 (blue)    \u25CF Player 2 (orange)", {
            left: PX, top: 360, fontSize: 12, fill: "#444"})
         ret.legend2 = new fabric.Text("green = ladder (up)   red = snake (down)", {
            left: PX, top: 384, fontSize: 12, fill: "#444"})
         ret.legend3 = new fabric.Text("yellow = square 100 (goal)", {
            left: PX, top: 408, fontSize: 12, fill: "#444"})
         return ret
      },
      render() {
         let CELL = 46
         let X0   = 20
         let Y0   = 40
         let o    = this.obj

         // Read live TL-Verilog $signals.
         let p0   = '$p0_pos'.asInt()
         let p1   = '$p1_pos'.asInt()
         let turn = '$turn'.asInt()
         let dice = '$dice'.asInt()
         let over = '$game_over'.asBool()
         let win  = '$winner'.asInt()
         let lp   = '$last_player'.asInt()
         let lf   = '$last_from'.asInt()
         let ll   = '$last_land'.asInt()
         let lfin = '$last_final'.asInt()
         let ld   = '$last_dice'.asInt()
         let lev  = '$last_event'.asInt()

         if (isNaN(p0)) p0 = 0
         if (isNaN(p1)) p1 = 0

         // Token placement. Square 0 = "start" (just below the bottom-left).
         let place = (tok, lbl, n, dx) => {
            let cx, cy
            if (n <= 0) { cx = X0 + 16 + dx; cy = Y0 + 10 * CELL + 24 }
            else {
               let c = this.cellCenter(n)
               cx = c.x + dx; cy = c.y - 4
            }
            tok.set({left: cx, top: cy})
            lbl.set({left: cx, top: cy})
         }
         place(o.tok0, o.tok0L, p0, -9)
         place(o.tok1, o.tok1L, p1,  9)

         // Highlight the square the mover just landed on.
         for (let n = 1; n <= 100; n++) {
            o["cell" + n].set({stroke: "#bbb", strokeWidth: 1})
         }
         if (lfin >= 1 && lfin <= 100) {
            o["cell" + lfin].set({stroke: lp ? "#ef6c00" : "#1565c0", strokeWidth: 3})
         }

         // Status panel.
         o.diceT.set({text: "\uD83C\uDFB2  " + (dice || "-")})
         o.turnT.set({text: over ? "Game over" : ("Turn: Player " + (turn ? "2" : "1"))})
         o.p0T.set({text: "Player 1  @ square " + p0 + (p0 === 100 ? "  WIN!" : "")})
         o.p1T.set({text: "Player 2  @ square " + p1 + (p1 === 100 ? "  WIN!" : "")})
         if (lf || ll || lfin) {
            o.moveT.set({text: "Last: P" + (lp ? "2" : "1") + " rolled " + ld + ":  " + lf + " \u2192 " + ll})
         } else {
            o.moveT.set({text: ""})
         }
         if (lev === 1) {
            o.eventT.set({text: "\u2191 LADDER!  " + ll + " \u2192 " + lfin, fill: "#2e7d32"})
         } else if (lev === 2) {
            o.eventT.set({text: "\u2193 SNAKE!  " + ll + " \u2192 " + lfin, fill: "#c62828"})
         } else {
            o.eventT.set({text: ""})
         }
         o.winT.set({text: over ? ("\uD83C\uDFC6  Player " + (win ? "2" : "1") + " wins!") : ""})
      }
\SV
   endmodule
