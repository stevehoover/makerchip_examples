\m5_TLV_version 1d: tl-x.org
\m5
   // ==============================================
   // Analog Clock Visualization
   // Each cycle represents 5 seconds of real time
   // ==============================================

\SV
   m5_makerchip_module
\TLV
   $reset = *reset;
   
   // Each cycle is 5 seconds
   // 60 seconds per minute = 12 cycles per minute
   // 60 minutes per hour = 720 cycles per hour
   // 12 hours = 8640 cycles for full rotation
   
   // Time counters (in 5-second increments)
   $second_count[15:0] = $reset ? 16'b0 : (>>1$second_count + 1);
   
   // Convert to actual time units
   // Total seconds = cycle * 5
   $total_seconds[31:0] = {16'b0, $second_count} * 5;
   $seconds[5:0] = $total_seconds % 60;
   $minutes[5:0] = ($total_seconds / 60) % 60;
   $hours[4:0] = ($total_seconds / 3600) % 12;
   
   // Calculate hand angles (in degrees, 0 = 12 o'clock)
   // Second hand: 360 degrees / 60 seconds = 6 degrees per second
   $second_angle[31:0] = $seconds * 6;
   
   // Minute hand: 360 degrees / 60 minutes = 6 degrees per minute
   //              Plus fractional degrees from seconds
   $minute_angle[31:0] = ($minutes * 6) + ($seconds / 10);
   
   // Hour hand: 360 degrees / 12 hours = 30 degrees per hour
   //            Plus fractional degrees from minutes
   $hour_angle[31:0] = ($hours * 30) + ($minutes / 2);
   
   // Visual Debug representation
   \viz_js
      box: {width: 400, height: 450, strokeWidth: 2, stroke: "#333"},
      where: {left: 0, top: 0, width: 400, height: 450},
      init() {
         let ret = {};
         
         // Clock face
         ret.clock_face = new fabric.Circle({
            left: 200,
            top: 200,
            radius: 150,
            fill: "#ffffff",
            stroke: "#333333",
            strokeWidth: 4,
            originX: "center",
            originY: "center"
         });
         
         // Clock center dot
         ret.center_dot = new fabric.Circle({
            left: 200,
            top: 200,
            radius: 8,
            fill: "#333333",
            originX: "center",
            originY: "center"
         });
         
         // Hour markers (12 marks)
         for (let i = 0; i < 12; i++) {
            let angle = (i * 30 - 90) * Math.PI / 180; // Convert to radians, offset by 90 to start at top
            let innerRadius = 130;
            let outerRadius = 145;
            
            ret[`hour_mark_${i}`] = new fabric.Line([
               200 + Math.cos(angle) * innerRadius,
               200 + Math.sin(angle) * innerRadius,
               200 + Math.cos(angle) * outerRadius,
               200 + Math.sin(angle) * outerRadius
            ], {
               stroke: "#333333",
               strokeWidth: 3
            });
            
            // Hour numbers
            let numRadius = 110;
            let hourNum = i === 0 ? 12 : i;
            ret[`hour_num_${i}`] = new fabric.Text(hourNum.toString(), {
               left: 200 + Math.cos(angle) * numRadius,
               top: 200 + Math.sin(angle) * numRadius,
               fontSize: 20,
               fontFamily: "Arial",
               fontWeight: "bold",
               fill: "#333333",
               originX: "center",
               originY: "center"
            });
         }
         
         // Minute markers (60 marks, smaller)
         for (let i = 0; i < 60; i++) {
            if (i % 5 !== 0) { // Skip hour positions
               let angle = (i * 6 - 90) * Math.PI / 180;
               let innerRadius = 140;
               let outerRadius = 145;
               
               ret[`min_mark_${i}`] = new fabric.Line([
                  200 + Math.cos(angle) * innerRadius,
                  200 + Math.sin(angle) * innerRadius,
                  200 + Math.cos(angle) * outerRadius,
                  200 + Math.sin(angle) * outerRadius
               ], {
                  stroke: "#999999",
                  strokeWidth: 1
               });
            }
         }
         
         // Hour hand (short and thick)
         ret.hour_hand = new fabric.Line([200, 200, 200, 130], {
            stroke: "#333333",
            strokeWidth: 6,
            strokeLineCap: "round"
         });
         
         // Minute hand (longer and medium)
         ret.minute_hand = new fabric.Line([200, 200, 200, 90], {
            stroke: "#666666",
            strokeWidth: 4,
            strokeLineCap: "round"
         });
         
         // Second hand (longest and thin, red)
         ret.second_hand = new fabric.Line([200, 200, 200, 70], {
            stroke: "#ff0000",
            strokeWidth: 2,
            strokeLineCap: "round"
         });
         
         // Digital time display
         ret.digital_display = new fabric.Text("00:00:00", {
            left: 200,
            top: 370,
            fontSize: 24,
            fontFamily: "monospace",
            fontWeight: "bold",
            fill: "#333333",
            originX: "center",
            originY: "center",
            backgroundColor: "#f0f0f0",
            padding: 8
         });
         
         // Title
         ret.title = new fabric.Text("Analog Clock", {
            left: 200,
            top: 30,
            fontSize: 28,
            fontFamily: "Arial",
            fontWeight: "bold",
            fill: "#333333",
            originX: "center",
            originY: "center"
         });
         
         // Subtitle
         ret.subtitle = new fabric.Text("(Each cycle = 5 seconds)", {
            left: 200,
            top: 60,
            fontSize: 14,
            fontFamily: "Arial",
            fill: "#666666",
            originX: "center",
            originY: "center"
         });
         
         return ret;
      },
      render() {
         // Get current angles from the hardware
         let secondAngle = '$second_angle'.asInt();
         let minuteAngle = '$minute_angle'.asInt();
         let hourAngle = '$hour_angle'.asInt();
         
         // Get time values for digital display
         let hours = '$hours'.asInt();
         let minutes = '$minutes'.asInt();
         let seconds = '$seconds'.asInt();
         
         // Convert angles to radians (subtract 90 to start at top)
         let secondRad = (secondAngle - 90) * Math.PI / 180;
         let minuteRad = (minuteAngle - 90) * Math.PI / 180;
         let hourRad = (hourAngle - 90) * Math.PI / 180;
         
         // Clock center
         let centerX = 200;
         let centerY = 200;
         
         // Update hour hand
         let hourLength = 70;
         this.obj.hour_hand.set({
            x1: centerX,
            y1: centerY,
            x2: centerX + Math.cos(hourRad) * hourLength,
            y2: centerY + Math.sin(hourRad) * hourLength
         });
         
         // Update minute hand
         let minuteLength = 110;
         this.obj.minute_hand.set({
            x1: centerX,
            y1: centerY,
            x2: centerX + Math.cos(minuteRad) * minuteLength,
            y2: centerY + Math.sin(minuteRad) * minuteLength
         });
         
         // Update second hand
         let secondLength = 130;
         this.obj.second_hand.set({
            x1: centerX,
            y1: centerY,
            x2: centerX + Math.cos(secondRad) * secondLength,
            y2: centerY + Math.sin(secondRad) * secondLength
         });
         
         // Update digital display
         let hoursStr = hours.toString().padStart(2, "0");
         let minutesStr = minutes.toString().padStart(2, "0");
         let secondsStr = seconds.toString().padStart(2, "0");
         this.obj.digital_display.set({
            text: hoursStr + ":" + minutesStr + ":" + secondsStr
         });
      }

\SV
   endmodule
