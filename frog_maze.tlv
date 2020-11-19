\m4_TLV_version 1d: tl-x.org
\SV
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */
\TLV
   |pipe
      @1
         $reset = *reset;
         m4_define(['M4_MAZE_NAME'], ['dev'])  // original, dev
         m4_ifelse_block(M4_MAZE_NAME, ['original'], ['
         m4_define_hier(M4_YY, 24, 0)
         m4_define_hier(M4_XX, 38, 0)
         m4_define(M4_FROG_START_XX, 1)
         m4_define(M4_FROG_START_YY, M4_YY_MAX-2)
         \SV_plus
            logic [M4_YY_RANGE][M4_XX_RANGE] maze;
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
         '], ['
         // Default small maze for development.
         m4_define_hier(M4_YY, 11, 0)
         m4_define_hier(M4_XX, 10, 0)
         m4_define(M4_FROG_START_XX, 1)
         m4_define(M4_FROG_START_YY, M4_YY_MAX-2)
         \SV_plus
            logic [M4_YY_RANGE][M4_XX_RANGE] maze;
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
         '])
         
         m4_define(M4_UP, 2'b00)
         m4_define(M4_DOWN, 2'b10)
         m4_define(M4_LEFT, 2'b11)
         m4_define(M4_RIGHT, 2'b01)
         
         
         // 1 while solving until the frog location knows where to go.
         $solved = /yy[/frog$Yy]/xx[/frog$Xx]$Solved;
         /M4_YY_HIER
            /M4_XX_HIER
               $wall = *maze\[M4_YY_MAX - #yy\]\[M4_XX_MAX - #xx\];
               // Can the upper-left corner of the frog be at these coordinates?
               $FrogOk <= (! $wall) &&
                          ( ! (/yy/xx[(#xx + 1) % M4_XX_CNT]$wall)) &&
                          ( ! (/yy[(#yy + 1) % M4_YY_CNT]/xx$wall)) &&
                          ( ! (/yy[(#yy + 1) % M4_YY_CNT]/xx[(#xx + 1) % M4_XX_CNT]$wall));
               // $Solved: 1 once it is known how to get the frog to the exit from this location.
               // $Dir: directiton to solve from this space if solved. Otherwise, 00, or 11 for exit location.
               $Solved <= $next_solved;
               $Dir[1:0] <= $next_dir;
               {$next_solved, $next_dir[1:0]} =
                  // On reset, we have a solution for all FrogOk positions (presumably one) that are at the edge.
                  |pipe$reset ? ($FrogOk && (#xx == 0 || #yy == 0 || #xx >= M4_XX_MAX-1 || #yy >= M4_YY_MAX-1) ? {1'b1, #xx == 0 ? 2'b11 : #yy == 0 ? 2'b00 : #xx >= M4_XX_MAX-1 ? 2'b01 : 2'b10} : {1'b0, 2'b00}
                               ) :
                  ! $FrogOk ? {1'b0, 2'b00} :
                  $Solved ? {1'b1, $Dir} :
                  // solve by going left?
                  (/yy/xx[(#xx + M4_XX_CNT - 2) % M4_XX_CNT]$Solved ||
                   (! /yy/xx[(#xx + M4_XX_CNT - 2) % M4_XX_CNT]$FrogOk && /yy/xx[(#xx + M4_XX_CNT - 1) % M4_XX_CNT]$Solved)
                  ) ? {1'b1, M4_LEFT} :
                  // solve by going right?
                  (/yy/xx[(#xx + 2) % M4_XX_CNT]$Solved ||
                   (! /yy/xx[(#xx + 2) % M4_XX_CNT]$FrogOk && /yy/xx[(#xx + 1) % M4_XX_CNT]$Solved)
                  ) ? {1'b1, M4_RIGHT} :
                  // solve by going up?
                  (/yy[(#yy + M4_YY_CNT - 2) % M4_YY_CNT]/xx$Solved ||
                   (! /yy[(#yy + M4_YY_CNT - 2) % M4_YY_CNT]/xx$FrogOk && /yy[(#yy + M4_YY_CNT - 1) % M4_YY_CNT]/xx$Solved)
                  ) ? {1'b1, M4_UP} :
                  // solve by going down?
                  (/yy[(#yy + 2) % M4_YY_CNT]/xx$Solved ||
                   (! /yy[(#yy + 2) % M4_YY_CNT]/xx$FrogOk && /yy[(#yy + 1) % M4_YY_CNT]/xx$Solved)
                  ) ? {1'b1, M4_DOWN} :
                      {1'b0, 2'b00};
         /frog
            $reset = |pipe$reset;
            // Make one hop per cycle in the following direction.
            $dir[1:0] = |pipe/yy[$Yy]/xx[$Xx]$Dir;
            
            // Determine the +1 and +2 position of the frog based on $dir.
            $hop1_x[M4_XX_INDEX_RANGE] =
               $dir == M4_RIGHT ? $Xx + 1 :
               $dir == M4_LEFT  ? $Xx - 1 :
                                  $Xx;
            $hop1_y[M4_YY_INDEX_RANGE] =
               $dir == M4_DOWN  ? $Yy + 1 :
               $dir == M4_UP    ? $Yy - 1 :
                                  $Yy;
            $hop2_x[M4_XX_INDEX_RANGE] =
               $dir == M4_RIGHT ? $Xx + 2 :
               $dir == M4_LEFT  ? $Xx - 2 :
               $Xx;
            $hop2_y[M4_YY_INDEX_RANGE] =
               $dir == M4_DOWN  ? $Yy + 2 :
               $dir == M4_UP    ? $Yy - 2 :
                                  $Yy;
            // Hop by 0, 1 or 2.
            $hop1_ok = |pipe/yy[$hop1_y]/xx[$hop1_x]$FrogOk;
            $hop2_ok = |pipe/yy[$hop2_y]/xx[$hop2_x]$FrogOk;
            $Xx[M4_XX_INDEX_RANGE] <=
               $reset || ! |pipe$solved ? M4_FROG_START_XX :
               $hop2_ok ? $hop2_x :
               $hop1_ok ? $hop1_x :
                          $RETAIN;
            $Yy[M4_YY_INDEX_RANGE] <=
               $reset || ! |pipe$solved ? M4_FROG_START_YY :
               $hop2_ok ? $hop2_y :
               $hop1_ok ? $hop1_y :
                          $RETAIN;
            
            
   // Assert these to end simulation (before Makerchip cycle limit).
   |pipe
      @1
         /frog
            $done = ($Xx == 0 || $Yy == 0 || $Xx >= M4_XX_MAX-1 || $Yy >= M4_YY_MAX-1);
            *passed = *cyc_cnt > 10 && >>1$done;
            *failed = 1'b0;
   
   // Visualization
   |pipe
      @1
         \viz_alpha
            // Board background
            initEach() {
              let objects = {}
              let TILE_SIZE = 2
              for (let x = 0; x < M4_XX_HIGH; x = x + TILE_SIZE) {
                 for (let y = 0; y < M4_YY_HIGH; y = y + TILE_SIZE) {
                    objects[`b_${x}_${y}`] = new fabric.Rect(
                      {left: x * 10,
                       top: y * 10,
                       width:  (x + TILE_SIZE > M4_XX_HIGH ? M4_XX_HIGH - x : TILE_SIZE) * 10,
                       height: (y + TILE_SIZE > M4_YY_HIGH ? M4_YY_HIGH - y : TILE_SIZE) * 10,
                       fill: (((x + y) % (TILE_SIZE * 2)) == 0) ? "#102020" : "#1C2C2C",
                      }
                    )
                 }
              }
              return {objects: objects}
            }
         /M4_YY_HIER
            /M4_XX_HIER
               \viz_alpha
                  initEach() {
                     //debugger
                     return {objects: {
                        cell: new fabric.Rect(
                          {left: this.getIndex("xx") * 10,
                           top: this.getIndex("yy") * 10,
                           width: 10,
                           height: 10,
                           fill: "#A030A0",
                           visible: false,
                          }
                        ),
                        arrowhead: new fabric.Triangle(
                          {left: this.getIndex("xx") * 10 + 10,
                           top: this.getIndex("yy") * 10 + 10,
                           width: 6,
                           height: 6,
                           originX: "center",
                           originY: "center",
                           fill: "gray",
                           visible: false,
                          }
                        )
                     }}
                  },
                  renderEach() {
                     //debugger
                     this.getInitObjects().cell.set({visible: '$wall'.asBool()})
                     this.getInitObjects().arrowhead.set({visible: '$Solved'.asBool() && ! '|pipe$solved'.asBool(),
                                                          //visible: '$Solved'.asBool(),
                                                          angle: '$Dir'.asInt() * 90})
                  }
         /frog
            \viz_alpha
               initEach() {
                  debugger
                  let frog_square = new fabric.Rect(
                     {originX: "center",
                      originY: "center",
                      width: 20,
                      height: 20,
                      fill: "#ffffff10" //`#00a000`
                     }
                  )
                  let frog_circle = new fabric.Circle(
                     {originX: "center",
                      originY: "center",
                      radius: 10,
                      fill: "#ffffff10" //`#00a000`
                     }
                  )
                  
                  // Image is not supposed to be added to canvas until it is drawn, but we need an Object to
                  // work with immediately, so let's wrap the image in a group.
                  let frog = new fabric.Group([frog_circle],
                     {originX: "center",
                      originY: "center",
                      angle: 0,
                      width: 20,
                      height: 20,
                     })
                  //let sprite_sheet_url = "https://www.pngfind.com/pngs/m/351-3516508_forget-the-gifs-heres-a-behind-the-scenes.png"
                  let frog_img_url = "https://raw.githubusercontent.com/stevehoover/makerchip_examples/master/viz_imgs/frog.png"
                  let frog_img = new fabric.Image.fromURL(
                     frog_img_url,
                     function (img) {
                        frog.add(img)
                        global.canvas.renderAll()
                     },
                     {originX: "center",
                      originY: "center",
                      left: 0,
                      top: 0,
                      scaleX: 0.03,
                      scaleY: 0.03,
                      angle: -7,
                     }
                  )
                  return {objects: {frog: frog}}
                  /**/
               },
               renderEach() {
                  debugger
                  // Keep count of the number of renders so we can terminate an animation after another is started.
                  this.render_cnt = this.render_cnt ? this.render_cnt++ : 1
                  render_cnt = this.render_cnt
                  // Determine old and new angles and adjust to make sure frog rotates no more than 180.
                  let old_angle = this.getInitObjects().frog.angle
                  let new_angle = '>>1$dir'.asInt() * 90
                  if (old_angle == 0 && new_angle == 270) {
                     old_angle = 360
                  } else if (old_angle == 270 && new_angle == 0) {
                     old_angle = -90
                  }
                  this.getInitObjects().frog.set({angle: old_angle})
                  // Animate
                  this.getInitObjects().frog.animate(
                    {angle: new_angle},
                    {onChange: this.global.canvas.renderAll.bind(this.global.canvas),
                     onComplete: () => {
                        if (render_cnt == this.render_cnt) {
                           // Keep animating. Jump.
                           this.getInitObjects().frog.animate(
                             {left: ('$Xx'.asInt() + 1) * 10, top: ('$Yy'.asInt() + 1) * 10},
                             {onChange: this.global.canvas.renderAll.bind(this.global.canvas),
                              duration: '>>1$hop2_ok'.asBool() ? 400 : '>>1$hop1_ok'.asBool() ? 200 : 0
                             }
                           )
                        } else {
                           console.log("render canceled")
                        }
                     }
                    }
                  )
               }
\SV
   endmodule
