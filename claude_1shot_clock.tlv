\m5_TLV_version 1d: tl-x.org
\SV
   // A simple clock where each cycle represents 5 seconds
   m4_makerchip_module
\TLV
   $reset = *reset;
   
   // Counter that increments every cycle (each cycle = 5 seconds)
   $seconds[31:0] = $reset ? 0 : >>1$seconds + 5;
   
   // Break down into hours, minutes, and seconds
   $total_seconds[31:0] = $seconds;
   $hours[31:0] = $total_seconds / 3600;
   $minutes[31:0] = ($total_seconds % 3600) / 60;
   $display_seconds[31:0] = $total_seconds % 60;
   
   // Visualization
   \viz_js
      box: {width: 300, height: 150, strokeWidth: 2, stroke: "black", fill: "#f0f0f0"},
      init() {
         return {
            // Title
            title: new fabric.Text("Digital Clock", {
               left: 150, top: 10,
               originX: "center",
               fontSize: 20,
               fontWeight: "bold",
               fill: "darkblue"
            }),
            
            // Clock display background
            clock_bg: new fabric.Rect({
               left: 50, top: 50,
               width: 200, height: 60,
               fill: "black",
               stroke: "gray",
               strokeWidth: 2
            }),
            
            // Time display
            time_display: new fabric.Text("00:00:00", {
               left: 150, top: 80,
               originX: "center",
               originY: "center",
               fontSize: 36,
               fontFamily: "Courier New",
               fill: "lime"
            }),
            
            // Info text
            info: new fabric.Text("Each cycle = 5 seconds", {
               left: 150, top: 130,
               originX: "center",
               fontSize: 12,
               fill: "gray"
            })
         }
      },
      render() {
         // Get current time values
         let hours = '$hours'.asInt(0);
         let minutes = '$minutes'.asInt(0);
         let seconds = '$display_seconds'.asInt(0);
         
         // Format as HH:MM:SS
         let h_str = hours.toString().padStart(2, "0");
         let m_str = minutes.toString().padStart(2, "0");
         let s_str = seconds.toString().padStart(2, "0");
         
         let time_str = h_str + ":" + m_str + ":" + s_str;
         
         // Update the display
         this.obj.time_display.set({text: time_str});
         
         // Optional: Change color based on time of day
         let color = "lime";
         if (hours >= 6 && hours < 12) {
            color = "yellow";  // Morning
         } else if (hours >= 12 && hours < 18) {
            color = "orange";  // Afternoon
         } else if (hours >= 18 && hours < 22) {
            color = "pink";    // Evening
         }
         this.obj.time_display.set({fill: color});
      }

\SV
   endmodule
