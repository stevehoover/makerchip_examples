\m4_TLV_version 1d: tl-x.org
\SV

// --------------------------------------------------------------------
//
// This example implements Conway's Game of Life.
// In this "game", a grid of cells (10x10) are born and die based on the
// number of live neighbors they have in each step (clock cycle).
// A cell's neighbors are the surrounding 8 cells, which includes the
// diagonals.
//   - A cell is born if exactly 3 neighbors are alive.
//   - A cell dies from overcrowding or starvation if it have >3 or <2
//     neighbors.
//
// Output shows the grid in each step of simulation.
//
// This example shows:
//   - Use of SystemVerilog constants.
//   - Use of TL-Verilog "behavioral hierarchy".  (Eg, >xx[M4_XX_CNT-1:0])
//   - That TL-Verilog is not just for pipelines!
//
// --------------------------------------------------------------------


m4_makerchip_module

// -------------------------
// Parameters

// Board size
m4_define_hier(['M4_XX'], 10, 0)
m4_define_hier(['M4_YY'], 10, 0)

/* verilator lint_off UNOPTFLAT */  // To silence Verilator warnings.

\TLV



   // ======
   // Design
   // ======
   
   |default
      @1
!        $reset = *reset;
      /M4_YY_HIER
         /M4_XX_HIER
            @1
               // Cell logic
               
               // -----------
               // Population count ($cnt) of 3x3 square (with edge logic).
               
               // Sum left + me + right.
               $row_cnt[1:0] = {1'b0, (/xx[(xx + M4_XX_CNT-1) % M4_XX_CNT]>>1$alive & (xx > 0))} +
                               {1'b0, >>1$alive} +
                               {1'b0, (/xx[(xx + 1) % M4_XX_CNT]>>1$alive & (xx < M4_XX_CNT-1))};
               // Sum three $row_cnt's: above + mine + below.
               $cnt[3:0] = {2'b00, (/yy[(yy + M4_YY_CNT-1) % M4_YY_CNT]/xx$row_cnt & {2{(yy > 0)}})} +
                           {2'b00, $row_cnt[1:0]} +
                           {2'b00, (/yy[(yy + 1) % M4_YY_CNT]/xx$row_cnt & {2{(yy < M4_YY_CNT-1)}})};
               
               
               // ----------
               // Init state
               
               //m4_rand($init_alive, 0, 0, (yy * xx) ^ ((3 * xx) + yy))
               
               
               // -----------
               // Am I alive?
               
               $alive = |default$reset ? $init_alive :           // init
                        >>1$alive ? ($cnt >= 3 && $cnt <= 4) :   // stay alive
                                    ($cnt == 3);                 // born
               
               
               // ===
               // VIZ
               // ===
               
               \viz_alpha
                  initEach: function () {
                     let rect = new fabric.Rect({
                        width: 20,
                        height: 20,
                        fill: "green",
                        left: scopes.xx.index * 20,
                        top: scopes.yy.index * 20
                     })
                     let shadow = new fabric.Rect({
                        width: 20,
                        height: 20,
                        fill: "green",
                        left: scopes.xx.index * 20,
                        top: scopes.yy.index * 20
                     })
                     return {objects: {rect: rect, shadow: shadow}};
                  },
                  layout: "horizontal",
                  renderEach: function () {
                     debugger
                     let background = ('$alive'.asBool()) ? "blue" : "red";
                     let background2 = ('>>1$alive'.asBool()) ? "black" : null;
                     let opacity2 = ('>>1$alive'.asBool()) ? 0.2 : 0;
                     this.getInitObjects().rect.set("fill", background);
                     this.getInitObjects().shadow.set("fill", background2);
                     this.getInitObjects().shadow.set("opacity", opacity2);
                  }
            
      


      // ==================
      // Embedded Testbench
      // ==================
      //
      // Declare success when total live cells was above 25% and remains below 6.25% for 20 cycles.

      // Count live cells through accumulation, into $alive_cnt.
      // Accumulate right-to-left, then bottom-to-top through >yy[0].
      /tb
         @2
            /yy[M4_YY_CNT-1:0]
               /xx[M4_XX_CNT-1:0]
                  \SV_plus
                     if (xx < M4_XX_CNT - 1)
                        assign $$right_alive_accum[10:0] = /xx[xx + 1]$horiz_alive_accum;
                     else
                        assign $right_alive_accum[10:0] = 11'b0;
                  $horiz_alive_accum[10:0] = $right_alive_accum + {10'b0, |default/yy/xx$alive};
               \SV_plus
                  if (yy < M4_YY_CNT -1)
                     assign $$below_alive_accum[21:0] = /yy[yy + 1]$vert_alive_accum;
                  else
                     assign $below_alive_accum[21:0] = 22'b0;
               $vert_alive_accum[21:0] = $below_alive_accum + {11'b0, /xx[0]$horiz_alive_accum};
            $alive_cnt[21:0] = /yy[0]$vert_alive_accum;
            $above_min_start = $alive_cnt > (M4_XX_CNT * M4_YY_CNT) >> 2;  // 1/4
            $below_max_stop  = $alive_cnt < (M4_XX_CNT * M4_YY_CNT) >> 4;  // 1/16
            $start_ok = |default$reset ? 1'b0 : (>>1$start_ok || $above_min_start);
            $stop_cnt[7:0] = |default$reset  ? 8'b0 :
                             $below_max_stop ? >>1$stop_cnt + 8'b1 :
                                               8'b0;
            *passed = >>1$start_ok && (($alive_cnt == '0) || (>>1$stop_cnt > 8'd20));



      // =====
      // Print
      // =====
      
      /print
         @2
            \SV_plus
               always_ff @(posedge clk) begin
                  \$display("---------------");
                  for (int y = 0; y < M4_YY_CNT; y++) begin
                     if (! |default$reset) begin
                        \$display("    \%10b", |default/yy[y]/xx[*]$alive);
                     end
                  end
               end
   
\SV
endmodule
