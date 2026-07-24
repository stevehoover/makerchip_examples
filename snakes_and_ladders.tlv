\m5_TLV_version 1d: tl-x.org
\m5
   // ============================================================
   //  SNAKES & LADDERS  (Saanp Seedhi)  —  a classic Indian board game
   //
   //  Two players race from square 1 to square 100 on a 10x10 board.
   //  Each turn a die (1..6) is rolled and the player advances.
   //   - Land on the foot of a LADDER  -> climb UP to its top.
   //   - Land on the head of a SNAKE    -> slide DOWN to its tail.
   //   - Overshooting 100 means you stay put (you must land exactly).
   //  First player to reach square 100 wins.
   //
   //  This is a tiny synchronous game engine in plain Verilog, driven
   //  by an LFSR "die", and visualized with Makerchip VIZ.
   //
   //  Standard board layout used here:
   //    Ladders (foot -> top):
   //      1->38  4->14  9->31  21->42  28->84  36->44  51->67  71->91  80->100
   //    Snakes  (head -> tail):
   //      16->6  47->26  49->11  56->53  62->19  64->60  87->24  93->73  95->75  98->78
   // ============================================================
   use(m5-1.0)
\SV
   m5_makerchip_module

   // ----------------------------------------------------------------
   //  SNAKE / LADDER LOOKUP
   //  Given the square a player lands on, return the *resulting*
   //  square after any ladder (up) or snake (down) redirect.
   // ----------------------------------------------------------------
   function automatic [6:0] redirect(input [6:0] sq);
      case (sq)
         // ladders (climb up)
         7'd1:   redirect = 7'd38;
         7'd4:   redirect = 7'd14;
         7'd9:   redirect = 7'd31;
         7'd21:  redirect = 7'd42;
         7'd28:  redirect = 7'd84;
         7'd36:  redirect = 7'd44;
         7'd51:  redirect = 7'd67;
         7'd71:  redirect = 7'd91;
         7'd80:  redirect = 7'd100;
         // snakes (slide down)
         7'd16:  redirect = 7'd6;
         7'd47:  redirect = 7'd26;
         7'd49:  redirect = 7'd11;
         7'd56:  redirect = 7'd53;
         7'd62:  redirect = 7'd19;
         7'd64:  redirect = 7'd60;
         7'd87:  redirect = 7'd24;
         7'd93:  redirect = 7'd73;
         7'd95:  redirect = 7'd75;
         7'd98:  redirect = 7'd78;
         default: redirect = sq;       // plain square: stay
      endcase
   endfunction

   // ----------------------------------------------------------------
   //  GAME STATE
   // ----------------------------------------------------------------
   logic [15:0] lfsr;                  // pseudo-random "die" source
   logic [6:0]  p0_pos, p1_pos;        // player positions: 0 (start) .. 100
   logic        turn;                  // whose turn THIS cycle: 0=P0, 1=P1
   logic        game_over;
   logic        winner;                // valid when game_over

   // The die: map the LFSR to a 1..6 roll.
   logic [2:0]  dice;
   assign dice = (lfsr % 16'd6) + 3'd1;       // 1..6

   // Move computation for the current player.
   logic [6:0]  cur_pos;
   assign cur_pos = turn ? p1_pos : p0_pos;
   logic [7:0]  sum;
   assign sum = cur_pos + dice;
   logic [6:0]  landed;                        // square after the roll
   assign landed = (sum > 8'd100) ? cur_pos    // overshoot 100 -> stay
                                  : sum[6:0];
   logic [6:0]  final_pos;                      // after snake/ladder
   assign final_pos = redirect(landed);

   // A move happens every cycle (after reset settles) until someone wins.
   logic do_move;
   assign do_move = ~game_over & (cyc_cnt > 32'd1);

   // ----------------------------------------------------------------
   //  LAST-MOVE BOOKKEEPING  (purely for the visualization / log)
   // ----------------------------------------------------------------
   logic        last_player;
   logic [6:0]  last_from, last_land, last_final;
   logic [2:0]  last_dice;
   logic [1:0]  last_event;            // 0=none, 1=ladder(up), 2=snake(down)

   always_ff @(posedge clk) begin
      if (reset) begin
         lfsr        <= 16'hACE1;
         p0_pos      <= 7'd0;
         p1_pos      <= 7'd0;
         turn        <= 1'b0;
         game_over   <= 1'b0;
         winner      <= 1'b0;
         last_player <= 1'b0;
         last_from   <= 7'd0;
         last_land   <= 7'd0;
         last_final  <= 7'd0;
         last_dice   <= 3'd0;
         last_event  <= 2'd0;
      end else begin
         // advance the die every cycle
         lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};

         if (do_move) begin
            // commit the move for whoever's turn it is
            if (turn) p1_pos <= final_pos;
            else      p0_pos <= final_pos;

            // record details for VIZ
            last_player <= turn;
            last_from   <= cur_pos;
            last_land   <= landed;
            last_final  <= final_pos;
            last_dice   <= dice;
            last_event  <= (final_pos > landed) ? 2'd1 :    // ladder up
                           (final_pos < landed) ? 2'd2 :    // snake down
                                                  2'd0;     // none

            // win check
            if (final_pos == 7'd100) begin
               game_over <= 1'b1;
               winner    <= turn;
            end

            // next player's turn
            turn <= ~turn;
         end
      end
   end

   // Self-checking: the game must terminate with a valid winner whose
   // position is exactly 100.
   logic check_ok;
   assign check_ok = ~game_over |
                     ((winner ? p1_pos : p0_pos) == 7'd100);

   assign passed = game_over & check_ok & (cyc_cnt > 32'd4);
   assign failed = game_over & ~check_ok;
\TLV
   // -------------------------------------------------------------
   //  VISUAL DEBUG (VIZ): draw the 10x10 board, snakes, ladders,
   //  and the two player tokens hopping toward square 100.
   // -------------------------------------------------------------
   /game_viz
      \viz_js
         box: {left: 0, top: 0, width: 840, height: 560, strokeWidth: 4, stroke: "#aaa", fill: "#fcfcf7"},
         init() {
            let CELL = 46
            let X0   = 20
            let Y0   = 40
            let ret  = {}

            // Board geometry helper: square number (1..100) -> {x,y} top-left.
            // Boustrophedon ("snake") numbering: row 0 is the bottom row going
            // left->right, row 1 goes right->left, and so on.
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

            // Snake / ladder data (must match the Verilog redirect()).
            let ladders = [[1,38],[4,14],[9,31],[21,42],[28,84],[36,44],[51,67],[71,91],[80,100]]
            let snakes  = [[16,6],[47,26],[49,11],[56,53],[62,19],[64,60],[87,24],[93,73],[95,75],[98,78]]
            let ladderFeet = new Set(ladders.map(l => l[0]))
            let snakeHeads = new Set(snakes.map(s => s[0]))

            // Title
            ret.title = new fabric.Text("Snakes & Ladders  —  race to square 100", {
               left: 12, top: 8, fontSize: 16, fontWeight: "bold", fill: "#222"})

            // Board cells (rect + number). Tint ladder feet green, snake heads red.
            for (let n = 1; n <= 100; n++) {
               let p = this.cellXY(n)
               let fill = ((Math.floor((n-1)/10) + (n-1)) % 2 === 0) ? "#ffffff" : "#eef3f7"
               if (n === 100)            fill = "#fff3b0"     // goal
               if (ladderFeet.has(n))    fill = "#d7f0d0"
               if (snakeHeads.has(n))    fill = "#f6d0d0"
               ret["cell" + n] = new fabric.Rect({
                  left: p.x, top: p.y, width: CELL, height: CELL,
                  stroke: "#bbb", strokeWidth: 1, fill: fill})
               ret["num" + n] = new fabric.Text(String(n), {
                  left: p.x + 3, top: p.y + 2, fontSize: 9, fill: "#789"})
            }

            // Ladders: thick green lines from foot to top.
            ladders.forEach((l, i) => {
               let a = this.cellCenter(l[0]), b = this.cellCenter(l[1])
               ret["lad" + i] = new fabric.Line([a.x, a.y, b.x, b.y], {
                  stroke: "#2e7d32", strokeWidth: 5, opacity: 0.7, strokeLineCap: "round"})
            })
            // Snakes: thick red wavy-ish lines from head to tail.
            snakes.forEach((s, i) => {
               let a = this.cellCenter(s[0]), b = this.cellCenter(s[1])
               ret["snk" + i] = new fabric.Line([a.x, a.y, b.x, b.y], {
                  stroke: "#c62828", strokeWidth: 5, opacity: 0.7, strokeLineCap: "round"})
               ret["snkH" + i] = new fabric.Circle({
                  left: a.x, top: a.y, radius: 6, originX: "center", originY: "center",
                  fill: "#c62828", opacity: 0.85})
            })

            // Player tokens.
            ret.tok0 = new fabric.Circle({
               left: X0, top: Y0, radius: 11, originX: "center", originY: "center",
               fill: "#1565c0", stroke: "#0d3c78", strokeWidth: 2})
            ret.tok1 = new fabric.Circle({
               left: X0, top: Y0, radius: 11, originX: "center", originY: "center",
               fill: "#ef6c00", stroke: "#8a3b00", strokeWidth: 2})
            ret.tok0L = new fabric.Text("1", {left: X0, top: Y0, fontSize: 11, fontWeight: "bold",
               originX: "center", originY: "center", fill: "#fff"})
            ret.tok1L = new fabric.Text("2", {left: X0, top: Y0, fontSize: 11, fontWeight: "bold",
               originX: "center", originY: "center", fill: "#fff"})

            // ---- Right-side status panel ----
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

            // Read live state from the simulation.
            let p0   = this.svSigRef("p0_pos",      0).asInt()
            let p1   = this.svSigRef("p1_pos",      0).asInt()
            let turn = this.svSigRef("turn",        0).asInt()
            let dice = this.svSigRef("dice",        0).asInt()
            let over = this.svSigRef("game_over",   0).asBool()
            let win  = this.svSigRef("winner",      0).asInt()
            let lp   = this.svSigRef("last_player", 0).asInt()
            let lf   = this.svSigRef("last_from",   0).asInt()
            let ll   = this.svSigRef("last_land",   0).asInt()
            let lfin = this.svSigRef("last_final",  0).asInt()
            let ld   = this.svSigRef("last_dice",   0).asInt()
            let lev  = this.svSigRef("last_event",  0).asInt()

            if (isNaN(p0)) p0 = 0
            if (isNaN(p1)) p1 = 0

            // Token placement. Square 0 = "start" (just off the bottom-left).
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

            // Highlight the cell the mover just landed on.
            for (let n = 1; n <= 100; n++) {
               // (cheap reset of any prior highlight stroke)
               o["cell" + n].set({stroke: "#bbb", strokeWidth: 1})
            }
            if (lfin >= 1 && lfin <= 100) {
               o["cell" + lfin].set({stroke: lp ? "#ef6c00" : "#1565c0", strokeWidth: 3})
            }

            // Status panel.
            o.diceT.set({text: "\uD83C\uDFB2  " + (dice || "-")})
            o.turnT.set({text: over ? "Game over" :
                               ("Turn: Player " + (turn ? "2" : "1"))})
            o.p0T.set({text: "Player 1  @ square " + p0 + (p0 === 100 ? "  WIN!" : "")})
            o.p1T.set({text: "Player 2  @ square " + p1 + (p1 === 100 ? "  WIN!" : "")})

            if (lf || ll || lfin) {
               o.moveT.set({text: "Last: P" + (lp ? "2" : "1") + " rolled " + ld +
                                  ":  " + lf + " \u2192 " + ll})
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
