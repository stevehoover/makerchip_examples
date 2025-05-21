\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV

// --------------------------------------------------------------------
//
// This example implements Conway's Game of Life.
// In this "game", a grid of cells are born and die based on the
// number of live neighbors they have in each step (clock cycle).
// A cell's neighbors are the surrounding 8 cells, which includes the
// diagonals.
//   - A cell is born if exactly 3 neighbors are alive.
//   - A cell dies from overcrowding or starvation if it have >3 or <2
//     neighbors.
//
// Output shows the grid in each step of simulation.
//
// There is support here for multiple boards simulated simultaneously and
// mirrored symmetry.
//
// --------------------------------------------------------------------


m5_makerchip_module

// -------------------------
// Parameters

// Board size
m5_define_hier(XX, 10, 0)
m5_define_hier(YY, 10, 0)

/* verilator lint_off UNOPTFLAT */  // To silence Verilator warnings.


// Provide $init_alive to initialize to random 3x (8-section) mirroring.
\TLV snowflake_init()
   |default
      @1
         /m5_YY_HIER
            /m5_YY_HIER
               // -----------
               // Am I alive?
               \SV_plus
                  localparam mirrored_x = (#xx >= (m5_XX_CNT / 2)) ? (m5_XX_MAX - #xx) \: #xx;
                  localparam mirrored_y = (#yy >= (m5_YY_CNT / 2)) ? (m5_YY_MAX - #yy) \: #yy;
                  localparam swap = mirrored_x > mirrored_y;
                  localparam ind_x = swap ? mirrored_y : mirrored_x;
                  localparam ind_y = swap ? mirrored_x : mirrored_y;
               $init_alive = /yy[ind_y]/xx[ind_x]$rand;


\TLV life(/_top, _where)
   /_top
      \viz_js
         box: {strokeWidth: 0},
         where: {_where}
      |default


         // ======
         // Design
         // ======

         @1
            $reset = *reset;
            /m5_YY_HIER
               /m5_XX_HIER
                  // Cell logic

                  // -----------
                  // Population count ($cnt) of 3x3 square (with edge logic).

                  // Sum left + me + right.
                  $row_cnt[1:0] = {1'b0, (/xx[(xx + m5_XX_CNT-1) % m5_XX_CNT]>>1$alive & (xx > 0))} +
                                  {1'b0, >>1$alive} +
                                  {1'b0, (/xx[(xx + 1) % m5_XX_CNT]>>1$alive & (xx < m5_XX_CNT-1))};
                  // Sum three $row_cnt's: above + mine + below.
                  $cnt[3:0] = {2'b00, (/yy[(yy + m5_YY_CNT-1) % m5_YY_CNT]/xx$row_cnt & {2{(yy > 0)}})} +
                              {2'b00, $row_cnt[1:0]} +
                              {2'b00, (/yy[(yy + 1) % m5_YY_CNT]/xx$row_cnt & {2{(yy < m5_YY_CNT-1)}})};


                  // ----------
                  // Init state

                  //m4_rand($init_alive, 0, 0, (yy * xx) ^ ((3 * xx) + yy))


                  // -----------
                  // Am I alive?

                  $alive = |default$reset ? $init_alive :           // init
                           >>1$alive ? ($cnt >= 3 && $cnt <= 4) :   // stay alive
                                       ($cnt == 3);                 // born


         // ==================
         // Embedded Testbench
         // ==================
         //
         // Declare success when total live cells was above 25% and remains below 6.25% for 20 cycles.

         // Count live cells through accumulation, into $alive_cnt.
         // Accumulate right-to-left, then bottom-to-top through >yy[0].
         /tb
            @2
               /m5_YY_HIER
                  /m5_XX_HIER
                     $right_alive_accum[10:0] = (xx < m5_XX_MAX) ? /xx[xx + 1]$horiz_alive_accum : 11'b0;
                     $horiz_alive_accum[10:0] = $right_alive_accum + {10'b0, |default/yy/xx$alive};
                  $below_alive_accum[21:0] = (yy < m5_YY_MAX) ? /yy[yy + 1]$vert_alive_accum : 22'b0;
                  $vert_alive_accum[21:0] = $below_alive_accum + {11'b0, /xx[0]$horiz_alive_accum};
               $alive_cnt[21:0] = /yy[0]$vert_alive_accum;
               $above_min_start = $alive_cnt > (m5_XX_CNT * m5_YY_CNT) >> 2;  // 1/4
               $below_max_stop  = $alive_cnt < (m5_XX_CNT * m5_YY_CNT) >> 4;  // 1/16
               $start_ok = |default$reset ? 1'b0 : (>>1$start_ok || $above_min_start);
               $stop_cnt[7:0] = |default$reset  ? 8'b0 :
                                $below_max_stop ? >>1$stop_cnt + 8'b1 :
                                                  8'b0;
               $passed = >>1$start_ok && (($alive_cnt == '0) || (>>1$stop_cnt > 8'd20));


         // ===
         // VIZ
         // ===
         @1
            /yy[*]
               \viz_js
                  all: {
                     box: {
                        width: m5_XX_CNT * 20 + 20,
                        height: m5_YY_CNT * 20 + 20,
                        fill: "#505050",
                        strokeWidth: 0
                     }
                  },
                  where0: {left: 10, top: 10}
               /xx[*]
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
                        this.obj.shadow.set(prev_prop);
                     },
                     layout: "horizontal",


\TLV
   /board_y[0:0]     // E.g., [2:0] for 3 boards high.
      /board_x[0:0]  // E.g., [2:0] for 3 boards across.
         \viz_js
            layout: "horizontal"
         //m5+snowflake_init()   // Uncomment to enable "snowflake" symmetry.
         m5+life(/life, )
   |tb
      @2
         // Determine passed by looking at top boards only.
         *passed = | /top/board_y[0]/board_x[*]/life|default/tb<>0$passed;

\SV
endmodule
