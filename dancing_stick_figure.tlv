\m5_TLV_version 1d: tl-x.org
\SV
   m4_makerchip_module
\TLV
   $reset = *reset;
   
   // Animation counter - cycles through dance moves
   $cycle[7:0] = $reset ? 0 : >>1$cycle + 1;
   
   // Center position
   $cx[9:0] = 10'd300;
   $cy[9:0] = 10'd200;
   
   // Head bobs up and down every 4 cycles
   $head_bob[9:0] = $cycle[2] ? 10'd10 : 10'd0;
   
   // Arms alternate waving (one up, one down)
   $left_arm_up = $cycle[3];
   $right_arm_up = ! $cycle[3];
   
   // Legs alternate kicking
   $left_leg_kick = $cycle[3];
   $right_leg_kick = ! $cycle[3];
   
   // Body tilts side to side
   $body_tilt[9:0] = $cycle[2] ? 10'd5 : -10'd5;
   
   // Calculate positions
   $head_y[9:0] = $cy - 10'd60 - $head_bob;
   $left_arm_y[9:0] = $cy - ($left_arm_up ? 10'd40 : 10'd20);
   $right_arm_y[9:0] = $cy - ($right_arm_up ? 10'd40 : 10'd20);
   $left_leg_x[9:0] = $cx - ($left_leg_kick ? 10'd40 : 10'd15);
   $right_leg_x[9:0] = $cx + ($right_leg_kick ? 10'd40 : 10'd15);
   $body_x[9:0] = $cx + $body_tilt;
   
   // Visualization
   \viz_js
      box: {width: 600, height: 400, strokeWidth: 0, fill: "lightblue"},
      render() {
         let cycle = '$cycle'.asInt();
         let cx = '$cx'.asInt();
         let cy = '$cy'.asInt();
         let head_y = '$head_y'.asInt();
         let left_arm_y = '$left_arm_y'.asInt();
         let right_arm_y = '$right_arm_y'.asInt();
         let left_leg_x = '$left_leg_x'.asInt();
         let right_leg_x = '$right_leg_x'.asInt();
         let body_x = '$body_x'.asInt();
         
         return [
            new fabric.Text("Silly Dancing Stick Figure!", {
               left: 200, top: 20,
               fontSize: 24,
               fontWeight: "bold",
               fill: "darkblue"
            }),
            
            new fabric.Text("Cycle: " + cycle, {
               left: 250, top: 50,
               fontSize: 16,
               fill: "black"
            }),
            
            // Dance floor line
            new fabric.Line([50, 350, 550, 350], {
               stroke: "brown",
               strokeWidth: 3
            }),
            
            // Head circle
            new fabric.Circle({
               left: cx - 20,
               top: head_y - 20,
               radius: 20,
               fill: "yellow",
               stroke: "orange",
               strokeWidth: 3
            }),
            
            // Left eye
            new fabric.Circle({
               left: cx - 28,
               top: head_y - 25,
               radius: 3,
               fill: "black"
            }),
            
            // Right eye
            new fabric.Circle({
               left: cx - 12,
               top: head_y - 25,
               radius: 3,
               fill: "black"
            }),
            
            // Body line
            new fabric.Line([cx, head_y + 20, body_x, cy], {
               stroke: "red",
               strokeWidth: 4,
               strokeLineCap: "round"
            }),
            
            // Left arm
            new fabric.Line([cx, cy - 20, cx - 30, left_arm_y], {
               stroke: "blue",
               strokeWidth: 4,
               strokeLineCap: "round"
            }),
            
            // Right arm
            new fabric.Line([cx, cy - 20, cx + 30, right_arm_y], {
               stroke: "blue",
               strokeWidth: 4,
               strokeLineCap: "round"
            }),
            
            // Left leg
            new fabric.Line([body_x, cy, left_leg_x, cy + 50], {
               stroke: "green",
               strokeWidth: 4,
               strokeLineCap: "round"
            }),
            
            // Right leg
            new fabric.Line([body_x, cy, right_leg_x, cy + 50], {
               stroke: "green",
               strokeWidth: 4,
               strokeLineCap: "round"
            })
         ];
      }
   
   *passed = *cyc_cnt > 40;
   
\SV
   endmodule
