\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   var(bit_width, 16)
   var(max_bit, m5_calc(m5_bit_width - 1))
   var(bit_range, m5_max_bit:0)
   var(num_targets, 5)
\SV
   ///m4_define_hier(TARGET, 5)
   ///m4_define_hier(BITS, 16)
   `include "sqrt32.v";
   
   m5_makerchip_module
      
\TLV pyth(/_leg, $_out, $_value, #_bits, @_sq, @_add, @_sqrt)
   // Pythagora's Theorem
   @_sq
      /_leg[*]
         $value_sq[m5_calc(#_bits - 1):0] = $_value[7:0] ** 2;
   @_add
      $cc_sq[m5_calc(#_bits - 1):0] = /coord[0]$value_sq + /coord[1]$value_sq;
   @_sqrt
      $_out[m5_calc(#_bits - 1):0] = sqrt($cc_sq);

\TLV
   |calc
      /coord[1:0]
         @0
            m4_rand($main_in, 6, 0, coord)
            $main[m5_bit_range] = {16'b0};
      /target[m5_calc(m5_num_targets - 1):0]
         /coord[1:0]
            @0
               m4_rand($value_in, 6, 0, 10 * coord + target)
               $value[m5_bit_range] = {9'b0, $value_in};
            @1
               $dist[m5_bit_range] = |calc/target/coord$value -
                                     |calc/coord$main;
         m5+pyth(/coord, $dist, $dist, m5_bit_width, @1, @2, @3)
         @4
            $accum_nearest_target[m5_calc(m5_num_targets - 1):0] =
               #target == 0
                     ? 0 :
               $dist < |calc/target[(#target - 1) % m5_num_targets]$accum_nearest_distance
                     ? #target :
               //default
                     |calc/target[(#target - 1) % m5_num_targets]$accum_nearest_target;
            $accum_nearest_distance[m5_bit_range] =
               #target == 0
                     ? |calc/target$dist :
               $dist < |calc/target[(#target - 1) % m5_num_targets]$accum_nearest_distance
                     ? |calc/target$dist :
               //default
                       |calc/target[(#target - 1) % m5_num_targets]$accum_nearest_distance;
      @4
         $nearest_target[\$clog2(m5_num_targets) - 1:0] =
             |calc/target[m5_calc(m5_num_targets - 1)]$accum_nearest_target;
         $min_dist[m5_bit_range] = |calc/target[m5_calc(m5_num_targets - 1)]$accum_nearest_distance;

      // Visualization of the main point, the target points, the lines from the
      // main point to each target, and a distance circle (centered on the main
      // point, passing through each target) using the circuit's computed
      // distance ($dist) as the radius.
      /scene
         @5
            \viz_js
               where: {left: 0, top: 0},
               box: {width: 460, height: 460, strokeWidth: 1, stroke: "#d0d0d0"},
               render() {
                  let objects = [];

                  // --- Read the main point and every target straight from the
                  //     design hierarchy (VIZ aligns each signal to its home
                  //     pipestage, so $value@0 and $dist@5 stay coherent). ---
                  let mainX = '|calc/coord[0]$main'.asInt();
                  let mainY = '|calc/coord[1]$main'.asInt();
                  let targets = [];
                  for (let i = 0; i < m5_num_targets; i++) {
                     targets.push({
                        x: '|calc/target[i]/coord[0]$value'.asInt(),
                        y: '|calc/target[i]/coord[1]$value'.asInt(),
                        d: '|calc/target[i]$dist'.asInt()
                     });
                  }

                  // --- Read the nearest target index straight from the design,
                  //     which now computes it for any number of targets. ---
                  let nearest = '|calc$nearest_target'.asInt();

                  // --- Establish a screen mapping centered on the main point ---
                  const W = 460, H = 460, margin = 40;
                  let maxR = 1;
                  targets.forEach(t => {
                     maxR = Math.max(maxR, Math.abs(t.x - mainX), Math.abs(t.y - mainY), t.d);
                  });
                  let scale = (Math.min(W, H) / 2 - margin) / maxR;
                  let ox = W / 2, oy = H / 2;
                  const sx = x => ox + (x - mainX) * scale;
                  const sy = y => oy - (y - mainY) * scale;

                  let palette = ["#2196F3", "#E91E63", "#4CAF50", "#FF9800", "#9C27B0"];

                  // --- Distance circle + line + target point, per target ---
                  targets.forEach((t, i) => {
                     let color = palette[i % palette.length];
                     let isNearest = (i === nearest);

                     // Highlight ring behind the nearest target.
                     if (isNearest) {
                        objects.push(new fabric.Circle({
                           left: sx(t.x), top: sy(t.y), radius: 11,
                           originX: "center", originY: "center",
                           fill: "transparent", stroke: "#FFC107", strokeWidth: 4,
                           opacity: 0.9, selectable: false
                        }));
                     }

                     // Distance circle, centered on the main point, radius = computed distance.
                     objects.push(new fabric.Circle({
                        left: ox, top: oy, radius: t.d * scale,
                        originX: "center", originY: "center",
                        fill: "transparent", stroke: color,
                        strokeWidth: isNearest ? 2 : 1,
                        opacity: isNearest ? 0.9 : 0.6, selectable: false
                     }));

                     // Line from the main point to the target.
                     objects.push(new fabric.Line([ox, oy, sx(t.x), sy(t.y)], {
                        stroke: color, strokeWidth: isNearest ? 4 : 2, selectable: false
                     }));

                     // Target point.
                     objects.push(new fabric.Circle({
                        left: sx(t.x), top: sy(t.y), radius: isNearest ? 7 : 5,
                        originX: "center", originY: "center",
                        fill: color, stroke: "#ffffff", strokeWidth: 1, selectable: false
                     }));

                     // Coordinate + distance label near the target.
                     objects.push(new fabric.Text(`(${t.x},${t.y})  d=${t.d}${isNearest ? "  \u2605 nearest" : ""}`, {
                        left: sx(t.x) + 8, top: sy(t.y) - 8,
                        fontSize: 11, fill: color,
                        fontWeight: isNearest ? "bold" : "normal", selectable: false
                     }));
                  });

                  // --- Main point (drawn last, on top) ---
                  objects.push(new fabric.Circle({
                     left: ox, top: oy, radius: 6,
                     originX: "center", originY: "center",
                     fill: "#212121", stroke: "#ffffff", strokeWidth: 1, selectable: false
                  }));
                  objects.push(new fabric.Text(`main (${mainX},${mainY})`, {
                     left: ox + 8, top: oy + 6,
                     fontSize: 11, fill: "#212121", selectable: false
                  }));

                  // --- Title ---
                  objects.push(new fabric.Text("Distance from main point to targets", {
                     left: W / 2, top: 12, fontSize: 14, fill: "#37474F",
                     fontWeight: "bold", originX: "center", selectable: false
                  }));

                  return objects;
               }
\SV
   endmodule
