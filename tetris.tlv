\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
   m5_makerchip_module   // (Expanded in Nav-TLV pane.)

   // Board dimensions (rows top-to-bottom 0..20, cols left-to-right 0..9).
   m5_define_hier(ROW, 21, 0)
   m5_define_hier(COL, 10)
   // Spawn position for the center of a new falling shape.  Shapes occupy box rows
   // 1-2 (see the shape table), so SPAWN_Y = 0 places only their bottom row (box row
   // 2) on the top board row (row 0); the rest of the shape is above the board (see
   // the coordinate / off-board notes below).
   m5_var(SPAWN_X, 5)
   m5_var(SPAWN_Y, 0)
   // Stimulus: 1 = scripted test that fills and clears the bottom row (for verifying
   // line clearing); 0 = random "player" stimulus.
   m5_var(CLEAR_TEST, 0)
\TLV
   // ============================================================================
   // TL-Verilog Tetris (random "player" input; there is no interactive input).
   //
   // Shapes: I, J, L, T, O (indices 0-4), rendered from the glyphs ▀▀,▛▘,▙▖,▟▖,█.
   // Each shape is a 4x4 (16-bit) grid, row-major, LSB = cell (0,0):
   //   bit(r,c) = r*4 + c.
   //
   // Coordinate system:
   //   The falling shape's shape is a 4x4 box of single-bit signals, one per cell:
   //   /shape_y[r]/shape_x[c]$Shape (the rotated occupancy -- the source of truth).
   //   $ShapeX/$ShapeY are the *center* of the box, expressed as the board cell whose
   //   top-left corner sits at the box center (the 4x4's (2,2) grid intersection).
   //   So a box cell (shape_y, shape_x) maps to board cell:
   //       col = $ShapeX + shape_x - 2 ,  row = $ShapeY + shape_y - 2 .
   //
   // Rotation: spin rotates the shape 90° about a per-shape pivot chosen to match the
   //   shape's center of mass ($rot_k in the shape table): the 3-wide shapes (J/L/T)
   //   pivot about their center *cell* (2,2), while the I bar and O block -- whose
   //   center of mass lands on a grid *intersection* -- pivot about the box-center
   //   intersection (1.5,1.5).  It is expressed as bitwise cross-references over a
   //   /shape_y/shape_x hierarchy (see below).  O is rotation-invariant, so its spin
   //   is suppressed anyway.
   //
   // Landing pipeline (matches the sketch's timing):
   //   - cycle N:   shape falling, no collision.
   //   - cycle N+1: the freshly-advanced position collides -> |tetris$land.
   //                The board freezes the *previous* (N) position (>>1$shape), and a
   //                new random shape is spawned.
   //   - cycle N+2: $Filled reflects the landed shape; the next shape is falling.
   //
   // Line clearing: any full row is removed and rows above collapse down by one, one
   //   removal per cycle (the lowest full row each cycle).
   //
   // Spawning: a shape enters from the top with only its bottom row on the board
   //   (row 0).  Box cells above row 0 map to negative board rows; those rows are not
   //   part of the board hierarchy, so they are neither drawn nor able to collide.
   //
   // Game over: if a shape locks while any of it is still above the board -- its
   //   top-most occupied cell is at board row < 0, so it could not fully enter -- the
   //   board is cleared and play restarts (auto-restart), so the demo keeps playing.
   // ============================================================================

   |tetris
      @1
         $reset = *reset;

         //
         // Stimulus
         //

         // Two sources, selected by m5_CLEAR_TEST: a random LFSR (normal play) and a
         // scripted controller that deterministically clears the bottom row.
         m4_rand($rnd, 11, 0)
         $rnd_shape[2:0] = $rnd[2:0] > 3'd4 ? $rnd[2:0] - 3'd5 : $rnd[2:0];
         $rnd_spin_ccw  = (& $rnd[4:3]);
         $rnd_spin_cw = (& $rnd[6:5]) && ! $rnd_spin_ccw;
         $rnd_move_left  =   $rnd[7] && $rnd[8];
         $rnd_move_right = ! $rnd[7] && $rnd[9];

         // Scripted stimulus: repeatedly drop five O shapes (2x2) side by side at cols
         // {0-1, 2-3, 4-5, 6-7, 8-9} so they tile the bottom two rows exactly -- both
         // rows fill and clear with no residue, so the test repeats indefinitely.
         // $Slot (0..4) tracks the current shape's step and advances on each spawn;
         // $next_slot is its value for the shape spawned this cycle.
         $next_slot[3:0] = $reset ? 4'd0 : ($Slot == 4'd4 ? 4'd0 : $Slot + 4'd1);
         $Slot[3:0] <= $new_spawn ? $next_slot : $Slot;
         $scr_shape[2:0] = *cyc_cnt < 200 ? 3'd4 : {1'b0, $rnd[1:0]};   // always O (2x2)
         $target_x[4:0]  = *cyc_cnt > 200 ? 5'd10 : $Slot == 4'd0 ? 5'd1 :
                           $Slot == 4'd1 ? 5'd3 :
                           $Slot == 4'd2 ? 5'd5 :
                           $Slot == 4'd3 ? 5'd7 : 5'd1;
         $scr_move_left  = $ShapeX > $target_x;
         $scr_move_right = $ShapeX < $target_x;

         // ---- Active stimulus (suppressed during reset) ----------------------------
         $rand_shape[2:0] = m5_CLEAR_TEST ? $scr_shape : $rnd_shape;
         $spin_ccw  = ! $reset && (m5_CLEAR_TEST ? 1'b0 : $rnd_spin_ccw);
         $spin_cw = ! $reset && (m5_CLEAR_TEST ? 1'b0 : $rnd_spin_cw);
         $move_left  = ! $reset && (m5_CLEAR_TEST ? $scr_move_left  : $rnd_move_left);
         $move_right = ! $reset && (m5_CLEAR_TEST ? $scr_move_right : $rnd_move_right);


         //
         // Hardware
         //

         // ---- Falling-shape registers ---------------------------------------------
         // Respawn a new shape on reset or on landing (which includes game over).
         $new_spawn = $reset || $land;
         // The index of the shape currently falling; O (index 4) is rotation-invariant.
         $FallingShape[2:0] <= $new_spawn ? $rand_shape : $FallingShape;
         $is_o = $FallingShape == 3'd4;
         // This shape's rotation pivot (see the shape table): the diagonal reflection
         // constant used by $cw/$ccw below.
         $rot_k[2:0] = /shape[$FallingShape]$rot_k;
         // Tentative horizontal step (validated below before it is committed).
         $try_x[4:0] = $ShapeX + {4'b0, $move_right} - {4'b0, $move_left};

         // ---- The falling shape's shape, as a 4x4 grid of single-bit signals ------
         // The shape pipeline lives per-cell over /shape_y[3:0]/shape_x[3:0] (box row
         // #shape_y, box col #shape_x) rather than as a packed 16-bit vector, so row/
         // column occupancy and board lookups become [*] reductions / hierarchy
         // indexing instead of bit-slicing.  Per cell:
         //   $Shape   : committed occupancy (source of truth), one register per cell.
         //   $cw/$ccw : the two 90-degree rotations about the center cell (1,1).
         //   $try     : shape after the requested rotation (O ignores spins).
         //   $acc     : shape actually used this cycle (the rotation, if accepted).
         // A rotation reads a neighbour, reflecting the box about the shape's pivot:
         // (rot_k - i) mod 4 is a diagonal pivot at (rot_k/2, rot_k/2) -- rot_k = 4 ->
         // center cell (2,2); rot_k = 3 -> box-center intersection (1.5,1.5):
         //   CW  (clockwise):         new(y,x) = old(rot_k - x, y)
         //   CCW (counter clockwise): new(y,x) = old(x, rot_k - y)
         /shape_y[3:0]
            /shape_x[3:0]
               // This box cell's bit in each shape's default vector ($shape_vector,
               // below), smashed from the 16-bit constant to per-cell bits.
               /shape[4:0]
                  $cell = |tetris/shape[#shape]$shape_vector[#shape_y * 4 + #shape_x];
               $spawn = /shape[|tetris$rand_shape]$cell;   // the spawning shape's cell
               $Shape <= |tetris$new_spawn ? $spawn : $acc;
               $cw  = /shape_y[(|tetris$rot_k + 4 - #shape_x) & 3]/shape_x[#shape_y]$Shape;
               $ccw = /shape_y[#shape_x]/shape_x[(|tetris$rot_k + 4 - #shape_y) & 3]$Shape;
               $try = (|tetris$spin_ccw && ! |tetris$is_o) ? $ccw :
                      (|tetris$spin_cw  && ! |tetris$is_o) ? $cw  : $Shape;
               $acc = |tetris$try_ok ? $try : $Shape;
            // Per-row occupancy (box row #shape_y set iff any of its 4 cells is).
            $try_row = | /shape_x[*]$try;
            $acc_row = | /shape_x[*]$acc;
         // Transpose $try into /shape_x/shape_y so per-column occupancy vectorizes too.
         /shape_x[3:0]
            /shape_y[3:0]
               $try_t = |tetris/shape_y[#shape_y]/shape_x[#shape_x]$try;
            $try_col = | /shape_y[*]$try_t;   // box col #shape_x occupied?

         // ---- Validate the tentative transform (rotate + move) before committing ---
         // Accept the rotated/moved shape only if it stays on the board and does not
         // overlap landed matter, so the shape is never committed in a collision.
         // $try_left/$try_right: left-/right-most occupied columns (board-edge test);
         // $try_bottom: bottom-most occupied row (floor edge for the on-board test).
         $try_left[2:0]   = /shape_x[0]$try_col ? 3'd0 : /shape_x[1]$try_col ? 3'd1 : 3'd2;
         $try_right[2:0]  = /shape_x[3]$try_col ? 3'd3 : /shape_x[2]$try_col ? 3'd2 : 3'd1;
         $try_bottom[2:0] = /shape_y[3]$try_row ? 3'd3 : /shape_y[2]$try_row ? 3'd2 : 3'd1;
         // On the board horizontally, and not through the floor (shape stays at row Y)?
         $try_in_board = (($try_x + {2'b0, $try_left})  >= 5'd2) &&
                         (($try_x + {2'b0, $try_right}) <= (m5_COL_MAX + 2));
         $try_on_board = ($ShapeY + {2'b0, $try_bottom}) <= (m5_ROW_MAX + 2);
         // Accept unless the transform leaves the board or hits matter ($try_hit,
         // reduced from the board below).
         $try_ok = $try_in_board && $try_on_board && ! $try_hit;
         $acc_x[4:0] = $try_ok ? $try_x : $ShapeX;   // this cycle's actual X

         // Bottom-/top-most occupied row of the accepted shape $acc: $acc_bottom feeds
         // the landing floor test, $acc_top the off-board game-over test.
         $acc_bottom[2:0] = /shape_y[3]$acc_row ? 3'd3 : /shape_y[2]$acc_row ? 3'd2 : 3'd1;
         $acc_top[2:0]    = /shape_y[0]$acc_row ? 3'd0 : /shape_y[1]$acc_row ? 3'd1 : 3'd2;

         // ---- Position registers: advance one row (shape commit is per-cell above) -
         $ShapeX[4:0]  <= $new_spawn ? m5_SPAWN_X : $acc_x;
         $ShapeY[4:0]  <= $new_spawn ? m5_SPAWN_Y : $ShapeY + 5'd1;

         // The shapes in their default orientations, as 16-bit row-major vectors
         // (bit r*4+c = cell (r,c), LSB first); smashed to per-cell bits above.
         /shape[4:0]
            // Each shape is centred on its rotation pivot so it spins in place, and
            // every shape's bottom occupied row is box row 2, so all spawn uniformly
            // with that row on board row 0.  The 3-wide shapes (J/L/T) put their body
            // in row 2 (cols 1-3) with the tip in row 1, centred on cell (2,2); the I
            // bar fills row 2; O is a 2x2 in rows 1-2 centred on the box intersection.
            $shape_vector[15:0] =
               #shape == 0 ? 16'b0000_1111_0000_0000 :   // I  (row 2, 4 wide)
               #shape == 1 ? 16'b0000_1110_0010_0000 :   // J  (tip row 1 col 1)
               #shape == 2 ? 16'b0000_1110_1000_0000 :   // L  (tip row 1 col 3)
               #shape == 3 ? 16'b0000_1110_0100_0000 :   // T  (tip row 1 col 2)
                             16'b0000_0110_0110_0000;    // O  (2x2 in rows 1-2)
            // Rotation pivot's reflection constant for $cw/$ccw: 4 = center cell
            // (2,2) (J/L/T); 3 = box-center intersection (1.5,1.5) (I and O).
            $rot_k[2:0] =
               #shape == 0 ? 3'd3 :   // I  -> box-center intersection
               #shape == 4 ? 3'd3 :   // O  -> box-center intersection
                             3'd4;    // J/L/T -> center cell (2,2)
         // Landing floor test: the accepted shape, one row lower, would drop its
         // bottom-most cell below the board.
         $floor_collision = (($ShapeY + 5'd1) + {2'b0, $acc_bottom}) > (m5_ROW_MAX + 2);

         // ---- The board -----------------------------------------------------------
         /m5_ROW_HIER
            /m5_COL_HIER
               // Shape occupancy at three positions, each reading the per-cell shape
               // hierarchy at this board cell's (box_row, box_col):
               //   $shape     : accepted shape at (acc_x, ShapeY)      -- shown & frozen.
               //   $try_cell  : requested transform at (try_x, ShapeY) -- move/spin test.
               //   $down_cell : accepted shape one row lower           -- landing test.
               $in_x = (#col + 2 >= |tetris$acc_x) && (#col + 2 <= |tetris$acc_x + 3);
               $in_y = (#row + 2 >= |tetris$ShapeY) && (#row + 2 <= |tetris$ShapeY + 3);
               $box_col[1:0] = (#col + 2) - |tetris$acc_x;    // this cell's column within the 4x4 box
               $box_row[1:0] = (#row + 2) - |tetris$ShapeY;   // this cell's row within the 4x4 box
               $shape = $in_x && $in_y && |tetris/shape_y[$box_row]/shape_x[$box_col]$acc;

               // Requested-transform occupancy (same row, tentative X/shape).
               $try_in_x = (#col + 2 >= |tetris$try_x) && (#col + 2 <= |tetris$try_x + 3);
               $try_box_col[1:0] = (#col + 2) - |tetris$try_x;
               $try_cell = $try_in_x && $in_y && |tetris/shape_y[$box_row]/shape_x[$try_box_col]$try;
               $try_collision = $Filled && $try_cell;

               // One-row-down occupancy (same X/shape, row + 1).
               $down_in_y = (#row + 2 >= |tetris$ShapeY + 1) && (#row + 2 <= |tetris$ShapeY + 4);
               $down_box_row[1:0] = (#row + 2) - (|tetris$ShapeY + 1);
               $down_cell = $in_x && $down_in_y && |tetris/shape_y[$down_box_row]/shape_x[$box_col]$acc;
               $down_collision = $Filled && $down_cell;

               // Board matter (landed shapes), excluding the falling shape.
               $Filled <=
                    |tetris$board_clear   ? 1'b0 :                    // reset / game over
                    /row$clear_at_or_below
                                          ? (#row == 0 ? 1'b0 : /row[#row - 1]/col$board) :  // collapse
                                            $board;                   // hold / land
               // Board including the shape frozen at its resting spot on landing.
               $board = $Filled || (|tetris$land && $shape);
            // Would a move/spin (this row) or the next fall collide with matter?
            $row_try  = | /col[*]$try_collision;
            $row_down = | /col[*]$down_collision;
            // A full row is eligible for clearing.
            $full = & /col[*]$board;
            // Is there a full row at or below this row?  (Scanned from the bottom up.)
            $clear_at_or_below = $full || (#row == m5_ROW_MAX ? 1'b0 : /row[#row + 1]$clear_at_or_below);
         // Reductions of the per-cell collision tests over the whole board.
         $try_hit  = | /row[*]$row_try;
         $down_hit = | /row[*]$row_down;

         // Land when the accepted shape cannot fall another row (matter or floor).
         $land = $down_hit || $floor_collision;

         // Game over: the shape locks while still partly above the board -- its top
         // occupied cell is at board row (ShapeY + $acc_top - 2) < 0, so it could not
         // fully enter.  ($Spawned && $land also ends a game that tops out with a flat
         // shape that fills the top row exactly.)  Clear & restart.
         $off_board = ($ShapeY + {2'b0, $acc_top}) < 5'd2;
         $Spawned <= $new_spawn;
         $game_over = $land && ($off_board || $Spawned);
         $board_clear = $reset || $game_over;

      // ---- Visualization -------------------------------------------------------
      @1
         /m5_ROW_HIER
            /m5_COL_HIER
               \viz_js
                  box: {width: 20, height: 20, strokeWidth: 1, stroke: "#0a0d14"},
                  renderFill() {
                     if ('$Filled'.asBool()) return "#6c8cff"   // landed matter
                     if ('$shape'.asBool())  return "#33e0e0"   // falling shape
                     return "#1a2130"                            // empty
                  }

   // Assert these to end simulation (before the cycle limit).
   *passed = *cyc_cnt > 600;
   *failed = 1'b0;
\SV
   endmodule
