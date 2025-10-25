\m5_TLV_version 1d: tl-x.org
\SV
   m5_makerchip_module
\TLV
   
   // Chess Clock Design
   // Each cycle represents 1 minute
   // Two clocks that toggle between active states
   
   |clock
      @0
         $reset = *reset;
         
         // Toggle button - when pressed, switches active clock
         // Using rand to simulate button presses for testing
         $random[7:0] = *reset ? 8'b0 : >>1$random + 8'b1;
         $button_press = $reset ? 1'b0 : ($random == 8'd20) || ($random == 8'd40) || ($random == 8'd60);
         
         // Active clock selector: 0 = player 0, 1 = player 1
         $active_player = $reset ? 1'b0 : 
                          $button_press ? ! >>1$active_player : 
                          >>1$active_player;
      
      /player[1:0]
         @0
            // Time counter (counts UP in 1-minute increments when active)
            $time_minutes[15:0] = |clock$reset ? 16'd45 + 16'd60 :
                                  (|clock$active_player == #player) ? >>1$time_minutes - 16'b1 :
                                  >>1$time_minutes;
            
            // Convert to hours and minutes for display
            $hours[15:0] = $time_minutes / 10'd60;
            $mins[15:0] = $time_minutes % 6'd60;
            
            // VIZ - Analog Chess Clock Display for each player
            \viz_js
               box: {left: 20, width: 200, height: 230, strokeWidth: 0, fill: "white"},
               layout: "horizontal",
               init() {
                  let ret = {};
                  let player_id = this.getIndex();
                  let center_x = 130;
                  let center_y = 110;
                  
                  // Rectangular black body background (extended downward)
                  ret.clock_body = new fabric.Rect({
                     left: 10,
                     top: 20,
                     width: 240,
                     height: 200,
                     fill: "black",
                     strokeWidth: 1,
                     rx: 8,
                     ry: 8
                  });
                  
                  // Player label (inside black body, top left)
                  ret.player_label = new fabric.Text(`P${player_id}`, {
                     fontSize: 14,
                     fontWeight: "bold",
                     left: 25,
                     top: 35,
                     fill: "#888"
                  });
                  
                  // Digital time display background (dark rectangle at bottom)
                  ret.time_bg = new fabric.Rect({
                     left: center_x,
                     top: 197,
                     width: 90,
                     height: 25,
                     originX: "center",
                     originY: "center",
                     fill: "#111",
                     stroke: "#333",
                     strokeWidth: 1,
                     rx: 5,
                     ry: 5
                  });
                  
                  // Digital time display text
                  ret.time_text = new fabric.Text("00:00", {
                     fontSize: 20,
                     fontFamily: "monospace",
                     fontWeight: "bold",
                     left: center_x,
                     top: 198,
                     originX: "center",
                     originY: "center",
                     fill: "#0f0"
                  });
                  
                  // Metallic button on top edge (no text)
                  ret.button = new fabric.Rect({
                     left: center_x + (this.getIndex() == 0 ? -40 : 40),
                     top: 20.5,
                     width: 40,
                     height: 20,
                     originX: "center",
                     originY: "bottom",
                     fill: "#C0C0C0",
                     strokeWidth: 0
                  });
                  
                  // Gold bezel
                  ret.bezel = new fabric.Circle({
                     left: center_x,
                     top: center_y,
                     radius: 70,
                     fill: "transparent",
                     stroke: "#D4AF37",
                     strokeWidth: 4,
                     originX: "center",
                     originY: "center"
                  });
                  
                  // Clock face - cream/white circle
                  ret.clock_face = new fabric.Circle({
                     left: center_x,
                     top: center_y,
                     radius: 66,
                     fill: "#FFFEF0",
                     stroke: "black",
                     strokeWidth: 1,
                     originX: "center",
                     originY: "center"
                  });
                  
                  // Red flag at 12 o'clock position
                  ret.flag = new fabric.Triangle({
                     left: center_x - 3,
                     top: center_y - 55,
                     width: 12,
                     height: 10,
                     fill: "red",
                     stroke: "darkred",
                     strokeWidth: 1,
                     originX: "center"
                  });
                  
                  // Clock tick marks (black on cream)
                  for (let i = 0; i < 60; i++) {
                     let angle = (i * 6) * Math.PI / 180;
                     let is_hour = (i % 5 == 0);
                     let outer_r = is_hour ? 58 : 60;
                     let inner_r = is_hour ? 50 : 56;
                     let x1 = center_x + outer_r * Math.sin(angle);
                     let y1 = center_y - outer_r * Math.cos(angle);
                     let x2 = center_x + inner_r * Math.sin(angle);
                     let y2 = center_y - inner_r * Math.cos(angle);
                     ret[`tick_${i}`] = new fabric.Line([x1, y1, x2, y2], {
                        stroke: "black",
                        strokeWidth: is_hour ? 2 : 1
                     });
                  }
                  
                  // Clock center dot
                  ret.center = new fabric.Circle({
                     left: center_x,
                     top: center_y,
                     radius: 5,
                     fill: "black",
                     originX: "center",
                     originY: "center"
                  });
                  
                  // Hour hand
                  ret.hour_hand = new fabric.Line([center_x, center_y, center_x, center_y - 30], {
                     stroke: "black",
                     strokeWidth: 4,
                     strokeLineCap: "round"
                  });
                  
                  // Minute hand
                  ret.minute_hand = new fabric.Line([center_x, center_y, center_x, center_y - 45], {
                     stroke: "black",
                     strokeWidth: 3,
                     strokeLineCap: "round"
                  });
                  
                  return ret;
               },
               render() {
                  let player_id = this.getIndex();
                  let center_x = 130;
                  let center_y = 110;
                  
                  // Get current values
                  let active = '/top|clock$active_player'.asInt();
                  let is_active = (active == player_id);
                  let hours = '$hours'.asInt() - 1;
                  let mins = '$mins'.asInt();
                  
                  // Calculate total minutes for angle calculation
                  let total_mins = hours * 60 + mins;
                  
                  // Calculate angles for 12-hour clock
                  let hour_angle = -((total_mins % 720) / 720) * 360;  // 720 minutes = 12 hours
                  let minute_angle = -((total_mins % 60) / 60) * 360;  // Full rotation every hour
                  
                  // Calculate hand endpoints
                  let hour_x = center_x + 30 * Math.sin(hour_angle * Math.PI / 180);
                  let hour_y = center_y - 30 * Math.cos(hour_angle * Math.PI / 180);
                  let minute_x = center_x + 45 * Math.sin(minute_angle * Math.PI / 180);
                  let minute_y = center_y - 45 * Math.cos(minute_angle * Math.PI / 180);
                  
                  this.obj.hour_hand.set({x2: hour_x, y2: hour_y});
                  this.obj.minute_hand.set({x2: minute_x, y2: minute_y});
                  
                  // Update digital display
                  let hours_str = String(hours).padStart(2, "0");
                  let mins_str = String(mins).padStart(2, "0");
                  this.obj.time_text.set({text: `${hours_str}:${mins_str}`});
                  
                  // Highlight active clock - brighter bezel
                  this.obj.bezel.set({
                     stroke: is_active ? "#FFD700" : "#D4AF37",
                     strokeWidth: is_active ? 6 : 4
                  });
                  
                  // Update button appearance - deeper push effect (10px)
                  let pressed_offset = !is_active ? 10 : 0;  // Opposite player's button appears pressed
                  this.obj.button.set({
                     height: 20 - pressed_offset,
                     fill: !is_active ? "#808080" : "#C0C0C0",
                     stroke: !is_active ? "#606060" : "#A0A0A0"
                  });
                  
                  // Highlight time display for active player
                  this.obj.time_text.set({
                     fill: is_active ? "#0f0" : "#0a0"
                  });
                  this.obj.time_bg.set({
                     fill: is_active ? "#1a1a1a" : "#111"
                  });
               }

   *passed = *cyc_cnt > 100;
   *failed = 1'b0;

\SV
   endmodule
