\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
   m4_include_lib(['https://raw.githubusercontent.com/TL-X-org/tlv_lib/3543cfd9d7ef9ae3b1e5750614583959a672084d/fundamentals_lib.tlv'])
   m5_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV frog_maze(/_top, _where)
   /_top
      |pipe
         @1
            $reset = *reset;
            m5_var(maze_name, dev)  /// original, dev
            m5+ifelse(maze_name, original,
               \TLV
                  m5_define_hier(YY, 24, 0)
                  m5_define_hier(XX, 38, 0)
                  m5_var(FROG_START_XX, 1)
                  m5_var(FROG_START_YY, m5_YY_MAX-2)
                  \SV_plus
                     logic [m5_YY_RANGE][m5_XX_RANGE] maze;
                     assign maze = '{
                          38'b11111111111111111111111111111111111111,
                          38'b10010010000110001000000000100100000000,
                          38'b10001000000000000000000000000001100000,
                          38'b10000000010000000011001000001000000101,
                          38'b10000000000001100110000100000000000001,
                          38'b11001000010010000000000000000001000001,
                          38'b10001100000001000000000110011011010011,
                          38'b10000010000001000001100100000000000001,
                          38'b10001001001010011001100000000001000001,
                          38'b10000000000000000000000001001000100101,
                          38'b10010001000000000000001001001100000001,
                          38'b10000000010010010000000000000000000011,
                          38'b10000000000000000100100000000100100001,
                          38'b10010100100000000000010010100000010001,
                          38'b10000000100101001000000000000000000001,
                          38'b10000100000000000110010000000000010001,
                          38'b10001100000001000000001010010011000001,
                          38'b10001000100110100100000000001001000001,
                          38'b11000001000000000001000100000000001001,
                          38'b10000000000000000011000000100000000001,
                          38'b10011000001100110000001000110000000001,
                          38'b10000000000000000000000000000000001001,
                          38'b10000000110000010010000000001010100011,
                          38'b11111111111111111111111111111111111111
                        };
               ,
               \TLV
                  // Default small maze for development.
                  m5_define_hier(YY, 11, 0)
                  m5_define_hier(XX, 10, 0)
                  m5_var(FROG_START_XX, 1)
                  m5_var(FROG_START_YY, m5_YY_MAX-2)
                  \SV_plus
                     logic [m5_YY_RANGE][m5_XX_RANGE] maze;
                     assign maze = '{
                          10'b1111111111,
                          10'b1000000101,
                          10'b1000000001,
                          10'b1000000000,
                          10'b1100110000,
                          10'b1000010001,
                          10'b1000000011,
                          10'b1000000001,
                          10'b1000000001,
                          10'b1000000001,
                          10'b1111111111
                        };
               )

            m5_var(UP, 2'b00)
            m5_var(DOWN, 2'b10)
            m5_var(LEFT, 2'b11)
            m5_var(RIGHT, 2'b01)


            // 1 while solving until the frog location knows where to go.
            $solved = /yy[/frog$Yy]/xx[/frog$Xx]$Solved;
            /m5_YY_HIER
               /m5_XX_HIER
                  $wall = *maze\[m5_YY_MAX - #yy\]\[m5_XX_MAX - #xx\];
                  // Can the upper-left corner of the frog be at these coordinates?
                  $FrogOk <= (! $wall) &&
                             ( ! (/yy/xx[(#xx + 1) % m5_XX_CNT]$wall)) &&
                             ( ! (/yy[(#yy + 1) % m5_YY_CNT]/xx$wall)) &&
                             ( ! (/yy[(#yy + 1) % m5_YY_CNT]/xx[(#xx + 1) % m5_XX_CNT]$wall));
                  // $Solved: 1 once it is known how to get the frog to the exit from this location.
                  // $Dir: directiton to solve from this space if solved. Otherwise, 00, or 11 for exit location.
                  $Solved <= $next_solved;
                  $Dir[1:0] <= $next_dir;
                  {$next_solved, $next_dir[1:0]} =
                     // On reset, we have a solution for all FrogOk positions (presumably one) that are at the edge.
                     |pipe$reset ? ($FrogOk && (#xx == 0 || #yy == 0 || #xx >= m5_XX_MAX-1 || #yy >= m5_YY_MAX-1) ? {1'b1, #xx == 0 ? 2'b11 : #yy == 0 ? 2'b00 : #xx >= m5_XX_MAX-1 ? 2'b01 : 2'b10} : {1'b0, 2'b00}
                                  ) :
                     ! $FrogOk ? {1'b0, 2'b00} :
                     $Solved ? {1'b1, $Dir} :
                     // solve by going left?
                     (/yy/xx[(#xx + m5_XX_CNT - 2) % m5_XX_CNT]$Solved ||
                      (! /yy/xx[(#xx + m5_XX_CNT - 2) % m5_XX_CNT]$FrogOk && /yy/xx[(#xx + m5_XX_CNT - 1) % m5_XX_CNT]$Solved)
                     ) ? {1'b1, m5_LEFT} :
                     // solve by going right?
                     (/yy/xx[(#xx + 2) % m5_XX_CNT]$Solved ||
                      (! /yy/xx[(#xx + 2) % m5_XX_CNT]$FrogOk && /yy/xx[(#xx + 1) % m5_XX_CNT]$Solved)
                     ) ? {1'b1, m5_RIGHT} :
                     // solve by going up?
                     (/yy[(#yy + m5_YY_CNT - 2) % m5_YY_CNT]/xx$Solved ||
                      (! /yy[(#yy + m5_YY_CNT - 2) % m5_YY_CNT]/xx$FrogOk && /yy[(#yy + m5_YY_CNT - 1) % m5_YY_CNT]/xx$Solved)
                     ) ? {1'b1, m5_UP} :
                     // solve by going down?
                     (/yy[(#yy + 2) % m5_YY_CNT]/xx$Solved ||
                      (! /yy[(#yy + 2) % m5_YY_CNT]/xx$FrogOk && /yy[(#yy + 1) % m5_YY_CNT]/xx$Solved)
                     ) ? {1'b1, m5_DOWN} :
                         {1'b0, 2'b00};
            /frog
               $reset = |pipe$reset;
               // Make one hop per cycle in the following direction.
               $dir[1:0] = |pipe/yy[$Yy]/xx[$Xx]$Dir;

               // Determine the +1 and +2 position of the frog based on $dir.
               $hop1_x[m5_XX_INDEX_RANGE] =
                  $dir == m5_RIGHT ? $Xx + 1 :
                  $dir == m5_LEFT  ? $Xx - 1 :
                                     $Xx;
               $hop1_y[m5_YY_INDEX_RANGE] =
                  $dir == m5_DOWN  ? $Yy + 1 :
                  $dir == m5_UP    ? $Yy - 1 :
                                     $Yy;
               $hop2_x[m5_XX_INDEX_RANGE] =
                  $dir == m5_RIGHT ? $Xx + 2 :
                  $dir == m5_LEFT  ? $Xx - 2 :
                  $Xx;
               $hop2_y[m5_YY_INDEX_RANGE] =
                  $dir == m5_DOWN  ? $Yy + 2 :
                  $dir == m5_UP    ? $Yy - 2 :
                                     $Yy;
               // Hop by 0, 1 or 2.
               $hop1_ok = |pipe/yy[$hop1_y]/xx[$hop1_x]$FrogOk;
               $hop2_ok = |pipe/yy[$hop2_y]/xx[$hop2_x]$FrogOk;
               $Xx[m5_XX_INDEX_RANGE] <=
                  $reset || ! |pipe$solved ? m5_FROG_START_XX :
                  $hop2_ok ? $hop2_x :
                  $hop1_ok ? $hop1_x :
                             $RETAIN;
               $Yy[m5_YY_INDEX_RANGE] <=
                  $reset || ! |pipe$solved ? m5_FROG_START_YY :
                  $hop2_ok ? $hop2_y :
                  $hop1_ok ? $hop1_y :
                             $RETAIN;


      // Assert these to end simulation (before Makerchip cycle limit).
      |pipe
         @1
            /frog
               $done = ($Xx == 0 || $Yy == 0 || $Xx >= m5_XX_MAX-1 || $Yy >= m5_YY_MAX-1);

      // Visualization
      \viz_js
         box: {strokeWidth: 0},
         where: {_where}
      |pipe
         @1
            \viz_js
               strokeWidth: 0,
               // Board background
               template() {
                 //debugger
                 let objects = {}
                 let TILE_SIZE = 2
                 for (let x = 0; x < m5_XX_HIGH; x = x + TILE_SIZE) {
                    for (let y = 0; y < m5_YY_HIGH; y = y + TILE_SIZE) {
                       objects[`b_${x}_${y}`] = ["Rect",
                         {left: x * 10,
                          top: y * 10,
                          width:  (x + TILE_SIZE > m5_XX_HIGH ? m5_XX_HIGH - x : TILE_SIZE) * 10,
                          height: (y + TILE_SIZE > m5_YY_HIGH ? m5_YY_HIGH - y : TILE_SIZE) * 10,
                          fill: (((x + y) % (TILE_SIZE * 2)) == 0) ? "#102020" : "#1C2C2C",
                          strokeWidth: 0,
                         }
                       ]
                    }
                 }
                 return objects
               }

            /m5_YY_HIER
               \viz_js
                  box: {height: 10, strokeWidth: 0},
                  layout: {top: 10}
               /m5_XX_HIER
                  \viz_js
                     layout: {left: 10},
                     box: {
                        width: 10, height: 10,
                        fill: "#A030A0",
                        strokeWidth: 0,
                        visible: false,
                     },   // (TODO: arrowhead is outside the box, which is bad form.)
                     template: {
                        arrowhead: ["Triangle",
                          {left: 10, top: 10,
                           width: 6, height: 6,
                           originX: "center", originY: "center",
                           fill: "gray",
                           visible: false,
                          }
                        ]
                     },
                     render() {
                        this.getBox().set({visible: '$wall'.asBool()})
                        this.obj.arrowhead.set({visible: '$Solved'.asBool() && ! '|pipe$solved'.asBool(),
                                                        angle: '$Dir'.asInt() * 90})
                     }
            /frog
               \viz_js
                  box: {width: 10 * m5_XX_HIGH, height: 10 * m5_YY_HIGH, strokeWidth: 0},
                  init() {
                     //debugger
                     let frog_circle = new fabric.Circle(
                        {originX: "center", originY: "center",
                         radius: 10,
                         fill: "#ffffff10"
                        }
                     )

                     frog_image = this.newImageFromURL(
                          "https://raw.githubusercontent.com/stevehoover/makerchip_examples/master/viz_imgs/frog.png",
                          "",
                          {originX: "center", originY: "center",
                           left: 0, top: 0,
                           scaleX: 0.03, scaleY: 0.03,
                           angle: -7,
                          }
                     )
                     let frog = new fabric.Group([frog_circle, frog_image],
                        {originX: "center", originY: "center",
                         angle: 0,
                         width: 20, height: 20,
                        })

                     return {frog}
                  },
                  render() {
                     let old_angle = this.obj.frog.angle
                     let new_angle = '>>1$dir'.asInt() * 90
                     if (old_angle == 0 && new_angle == 270) {
                        old_angle = 360
                     } else if (old_angle == 270 && new_angle == 0) {
                        old_angle = -90
                     }
                     this.obj.frog
                        .set({angle: old_angle})
                        .animate(
                             {angle: new_angle},
                             {duration: 500})
                        .thenAnimate(
                             {left: ('$Xx'.asInt() + 1) * 10, top: ('$Yy'.asInt() + 1) * 10},
                             {duration: '>>1$hop2_ok'.asBool() ? 400 : '>>1$hop1_ok'.asBool() ? 200 : 0})
                  }

\TLV
   m5+frog_maze(/maze)
   
   *passed = *cyc_cnt > 10 && /maze|pipe/frog>>2$done;
   *failed = 1'b0;
\SV
   endmodule
