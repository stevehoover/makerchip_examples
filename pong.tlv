\m5_TLV_version 1d: tl-x.org
\SV
   m5_makerchip_module
\TLV

   // =============================================
   // PONG
   // =============================================
   // A self-playing game of Pong. Two AI paddles rally a ball back and
   // forth. Each paddle tracks the ball when it is heading toward its
   // side of the court and eases back to center otherwise, so it will
   // occasionally miss a fast shot and concede a point. First to 9 wins.
   //
   // Game field is 160 (x) by 120 (y) units, origin top-left.
   //   - Left paddle plays at x ~ 6, right paddle at x ~ 152.
   //   - Paddles are 24 units tall; $*pad_y is the paddle's TOP edge.
   //   - Ball moves 2 units/step horizontally and 1..3 units/step
   //     vertically (the vertical speed is set by where it strikes a
   //     paddle, giving the classic "english" on the ball).

   |pong
      @0
         $reset = *reset;

         // ---- Game-over / winner tracking (first to 9) ----
         $game_over = (>>1$lscore >= 7'd9) || (>>1$rscore >= 7'd9);

         // ---------------------------------------------------------
         // Wall bounces (top / bottom), computed from previous state
         // ---------------------------------------------------------
         $sy[8:0] = {7'd0, >>1$ball_sy};                 // vertical speed, zero-extended
         $will_hit_top    = (>>1$ball_dy == 1'b0) && (>>1$ball_y <= $sy);
         $will_hit_bottom = (>>1$ball_dy == 1'b1) && (>>1$ball_y + $sy >= 9'd119);

         // ---------------------------------------------------------
         // Paddle planes and catch / score detection
         // ---------------------------------------------------------
         $will_hit_left  = (>>1$ball_dx == 1'b0) && (>>1$ball_x <= 9'd8);
         $will_hit_right = (>>1$ball_dx == 1'b1) && (>>1$ball_x >= 9'd150);

         $left_catch  = $will_hit_left  && (>>1$ball_y + 9'd2 >= >>1$lpad_y) && (>>1$ball_y <= >>1$lpad_y + 9'd24);
         $right_catch = $will_hit_right && (>>1$ball_y + 9'd2 >= >>1$rpad_y) && (>>1$ball_y <= >>1$rpad_y + 9'd24);

         $right_scores = $will_hit_left  && ! $left_catch  && ! $game_over;   // left paddle missed
         $left_scores  = $will_hit_right && ! $right_catch && ! $game_over;   // right paddle missed
         $score_event  = $right_scores || $left_scores;

         // ---------------------------------------------------------
         // "English": where the ball hit the paddle sets vertical
         // speed (1..3) and up/down direction.
         // ---------------------------------------------------------
         $lp_cen[8:0] = >>1$lpad_y + 9'd12;
         $rp_cen[8:0] = >>1$rpad_y + 9'd12;
         $lp_off[8:0] = (>>1$ball_y >= $lp_cen) ? (>>1$ball_y - $lp_cen) : ($lp_cen - >>1$ball_y);
         $rp_off[8:0] = (>>1$ball_y >= $rp_cen) ? (>>1$ball_y - $rp_cen) : ($rp_cen - >>1$ball_y);
         $lp_spd[1:0] = ($lp_off > 9'd8) ? 2'd3 : ($lp_off > 9'd4) ? 2'd2 : 2'd1;
         $rp_spd[1:0] = ($rp_off > 9'd8) ? 2'd3 : ($rp_off > 9'd4) ? 2'd2 : 2'd1;
         $lp_dy = (>>1$ball_y > $lp_cen) ? 1'b1 : 1'b0;   // 1 = down
         $rp_dy = (>>1$ball_y > $rp_cen) ? 1'b1 : 1'b0;

         // ---------------------------------------------------------
         // Ball state updates
         // ---------------------------------------------------------
         $ball_dx = $reset ? 1'b1 :
                    $left_catch  ? 1'b1 :
                    $right_catch ? 1'b0 :
                    $score_event ? ($left_scores ? 1'b1 : 1'b0) :   // serve toward the side that conceded
                    >>1$ball_dx;

         $ball_dy = ($reset || $score_event || $game_over) ? 1'b1 :
                    $will_hit_top    ? 1'b1 :
                    $will_hit_bottom ? 1'b0 :
                    $left_catch      ? $lp_dy :
                    $right_catch     ? $rp_dy :
                    >>1$ball_dy;

         $ball_sy[1:0] = ($reset || $score_event || $game_over) ? 2'd1 :
                         $left_catch  ? $lp_spd :
                         $right_catch ? $rp_spd :
                         >>1$ball_sy;

         $ball_x[8:0] = ($reset || $score_event || $game_over) ? 9'd80 :
                        $left_catch  ? 9'd9 :
                        $right_catch ? 9'd149 :
                        >>1$ball_dx  ? >>1$ball_x + 9'd2 : >>1$ball_x - 9'd2;

         $ball_y[8:0] = ($reset || $score_event || $game_over) ? 9'd60 :
                        $will_hit_top    ? 9'd0 :
                        $will_hit_bottom ? 9'd119 :
                        >>1$ball_dy      ? >>1$ball_y + $sy : >>1$ball_y - $sy;

         // ---------------------------------------------------------
         // Paddle AI
         //   - Desired top edge keeps the paddle centered on the ball.
         //   - A paddle only "chases" (step 2) while the ball heads its
         //     way; otherwise it drifts back to center (step 1). This
         //     lag is what lets a fast shot slip past for a point.
         // ---------------------------------------------------------
         $lp_des[8:0] = (>>1$ball_y < 9'd12) ? 9'd0 : (>>1$ball_y > 9'd107) ? 9'd95 : >>1$ball_y - 9'd12;
         $rp_des[8:0] = $lp_des;

         $lp_tgt[8:0]  = (>>1$ball_dx == 1'b0) ? $lp_des : 9'd48;
         $lp_step[8:0] = (>>1$ball_dx == 1'b0) ? 9'd2   : 9'd1;
         $rp_tgt[8:0]  = (>>1$ball_dx == 1'b1) ? $rp_des : 9'd48;
         $rp_step[8:0] = (>>1$ball_dx == 1'b1) ? 9'd2   : 9'd1;

         $lpad_y[8:0] = $reset ? 9'd48 :
                        ($lp_tgt > >>1$lpad_y) ? (($lp_tgt - >>1$lpad_y > $lp_step) ? >>1$lpad_y + $lp_step : $lp_tgt) :
                        ($lp_tgt < >>1$lpad_y) ? ((>>1$lpad_y - $lp_tgt > $lp_step) ? >>1$lpad_y - $lp_step : $lp_tgt) :
                        >>1$lpad_y;
         $rpad_y[8:0] = $reset ? 9'd48 :
                        ($rp_tgt > >>1$rpad_y) ? (($rp_tgt - >>1$rpad_y > $rp_step) ? >>1$rpad_y + $rp_step : $rp_tgt) :
                        ($rp_tgt < >>1$rpad_y) ? ((>>1$rpad_y - $rp_tgt > $rp_step) ? >>1$rpad_y - $rp_step : $rp_tgt) :
                        >>1$rpad_y;

         // ---------------------------------------------------------
         // Score
         // ---------------------------------------------------------
         $lscore[6:0] = $reset ? 7'd0 : $left_scores  ? >>1$lscore + 7'd1 : >>1$lscore;
         $rscore[6:0] = $reset ? 7'd0 : $right_scores ? >>1$rscore + 7'd1 : >>1$rscore;

   // =============================================
   // Visualization
   // =============================================
   \viz_js
      box: {left: 0, top: 0, width: 680, height: 560, strokeWidth: 0},
      init() {
         // Field is 160 x 120 units. Canvas mapping: cx = OX + x*S, cy = OY + y*S.
         let S = 4, OX = 10, OY = 60, FW = 160 * S, FH = 120 * S;
         let ret = {};

         ret.title = new fabric.Text("PONG", {
            left: OX + FW / 2, top: 10,
            fontSize: 32, fontWeight: "bold", fill: "#e8e8e8",
            originX: "center", fontFamily: "Courier New"
         });

         // Court.
         ret.court = new fabric.Rect({
            left: OX, top: OY, width: FW, height: FH,
            fill: "#0b0f1a", stroke: "#33ff88", strokeWidth: 3
         });

         // Dashed center net.
         ret.net = new fabric.Line([OX + FW / 2, OY, OX + FW / 2, OY + FH], {
            stroke: "#2a6f4a", strokeWidth: 3, strokeDashArray: [10, 12]
         });

         // Scores.
         ret.lscore = new fabric.Text("0", {
            left: OX + FW / 2 - 60, top: 18,
            fontSize: 40, fill: "#33ff88", originX: "right", fontFamily: "Courier New"
         });
         ret.rscore = new fabric.Text("0", {
            left: OX + FW / 2 + 60, top: 18,
            fontSize: 40, fill: "#33ff88", originX: "left", fontFamily: "Courier New"
         });

         // Paddles (24 units tall -> 24*S px). Width 6 units.
         ret.lpad = new fabric.Rect({
            left: OX + 6 * S - 5, top: OY, width: 10, height: 24 * S,
            fill: "#e8e8e8", rx: 3, ry: 3
         });
         ret.rpad = new fabric.Rect({
            left: OX + 152 * S - 5, top: OY, width: 10, height: 24 * S,
            fill: "#e8e8e8", rx: 3, ry: 3
         });

         // Ball.
         ret.ball = new fabric.Rect({
            left: OX + 80 * S - 5, top: OY + 60 * S - 5, width: 10, height: 10,
            fill: "#ffd23f"
         });

         // Winner banner (hidden until game over).
         ret.banner = new fabric.Text("", {
            left: OX + FW / 2, top: OY + FH / 2,
            fontSize: 44, fontWeight: "bold", fill: "#ffd23f",
            originX: "center", originY: "center", fontFamily: "Courier New",
            visible: false
         });

         return ret;
      },
      render() {
         let S = 4, OX = 10, OY = 60;
          let get = (s) => s.asInt(0);

            let bx = get('/top|pong>>0$ball_x');
            let by = get('/top|pong>>0$ball_y');
            let ly = get('/top|pong>>0$lpad_y');
            let ry = get('/top|pong>>0$rpad_y');
            let ls = get('/top|pong>>0$lscore');
            let rs = get('/top|pong>>0$rscore');

         this.getObjects().ball.set({left: OX + bx * S - 5, top: OY + by * S - 5});
         this.getObjects().lpad.set({top: OY + ly * S});
         this.getObjects().rpad.set({top: OY + ry * S});
         this.getObjects().lscore.set({text: `${ls}`});
         this.getObjects().rscore.set({text: `${rs}`});

         let banner = this.getObjects().banner;
         if (ls >= 9 || rs >= 9) {
            banner.set({text: ls >= 9 ? "LEFT WINS!" : "RIGHT WINS!", visible: true});
         } else {
            banner.set({visible: false});
         }
      }

\SV
   endmodule
