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
         
         /M4_YY_HIER
            \viz_js
               all: {
                  box: {
                     width: M4_XX_CNT * 20 + 20,
                     height: M4_YY_CNT * 20 + 20,
                     fill: "#505050",
                     strokeWidth: 0
                  }
               },
               where0: {left: 10, top: 10}
            /M4_XX_HIER
               \viz_js
                  box: {width: 20, height: 20,
                        fill: "lightgray",
                        strokeWidth: 0},
                  init() {
                     //debugger
                     return {
                        shadow: new fabric.Rect({
                           width: 4, height: 4,
                           fill: "lightgray",
                           left: 8, top: 8
                        })
                     }
                  },
                  render() {
                     //debugger
                     let background = ('$alive'.asBool()) ? "#10D080" : "#204030";
                     let prev_prop = ('>>1$alive'.asBool()) ? {fill: "#008000", opacity: 0.3} : {fill: null, opacity: 0};
                     this.getBox().set("fill", background);
                     this.getObjects().shadow.set(prev_prop);
                  },
                  layout: "horizontal",
      
      
      
      // ==================
      // Embedded Testbench
      // ==================
      //
      // Declare success when total live cells was above 25% and remains below 6.25% for 20 cycles.
      
      // Count live cells through accumulation, into $alive_cnt.
      // Accumulate right-to-left, then bottom-to-top through >yy[0].
      /tb
         @2
            /M4_YY_HIER
               /M4_XX_HIER
                  $right_alive_accum[10:0] = (xx < M4_XX_MAX) ? /xx[xx + 1]$horiz_alive_accum : 11'b0;
                  $horiz_alive_accum[10:0] = $right_alive_accum + {10'b0, |default/yy/xx$alive};
               $below_alive_accum[21:0] = (yy < M4_YY_MAX) ? /yy[yy + 1]$vert_alive_accum : 22'b0;
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
