\TLV_version 1d: tl-x.org
\SV
   // Pythagorean Theorem Circuit
   // Computes c = sqrt(a² + b²) for right triangle sides a and b
   
   module pythagorean_theorem (
      input clk,
      input rst,
      input [15:0] a,        // First side of right triangle
      input [15:0] b,        // Second side of right triangle
      input start,           // Start computation
      output reg [15:0] c,   // Hypotenuse result
      output reg valid       // Result valid flag
   );

\TLV
   // Single pipeline for Pythagorean computation with iterative square root
   |compute
      @1
         // Input staging
         $new_transaction = *start;
         
      ?$new_transaction
         @1
            $a[15:0] = *a;
            $b[15:0] = *b;
            
         @2
            // Calculate sum and initialize iteration
            $sum[31:0] = ($a * $a) + ($b * $b);
            $target[31:0] = $sum;
            $guess[15:0] = $sum[31:16] + 1;  // Initial guess
            
   // Separate iteration pipeline that recirculates
   |iterate
      @1
         /compute
            $ANY = /top|compute>>2$ANY;
         /held
            $ANY = |iterate/compute$new_transaction ? |iterate/compute$ANY : >>1$ANY;
         // Start iteration or continue from previous cycle
         $active = /compute$new_transaction || >>1$continue;
         
      ?$active
         @1
            // Get values from compute pipeline or from previous iteration
            // Use different names to avoid namespace collision
            $target[31:0] = /compute$new_transaction ? /compute$target : >>1$target;
            $guess[15:0] = /compute$new_transaction ? /compute$guess : >>1$new_guess;
            $iteration[3:0] = /compute$new_transaction ? 4'b0 : (>>1$iteration + 1);
            
         @2
            // Newton-Raphson computation
            $quotient[31:0] = $target / {16'b0, $guess};
            $sum_temp[16:0] = $guess + $quotient[15:0];
            $new_guess[15:0] = $sum_temp[16:1]; // Divide by 2
            
            // Determine if we need more iterations
            $max_iterations[3:0] = 4'd6;
            $continue = $iteration < $max_iterations;
      @2
         $done = >>1$continue && ! $continue;
         $valid = $done;
      ?$valid
         @3
            // Output stage
            $result[15:0] = $done ? $new_guess : 16'b0;
            
            // Connect to module outputs  
            *c = $result;
            *valid = $valid;

            // Triangle Visualization Scope
            /triangle
               $ANY = |iterate$ANY;
               \viz_js
                  where: {left: 50, top: 50},
                  box: {width: 350, height: 250, strokeWidth: 1, stroke: "#e0e0e0"},
                  render() {
                     // Get current values
                     let a_val = '|iterate/held$a'.asInt() || 0;
                     let b_val = '|iterate/held$b'.asInt() || 0;
                     let c_val = '$result'.asInt() || 0;
                     let valid = '$valid'.asBool();
                     
                     let objects = [];

                     if (valid && a_val > 0 && b_val > 0) {
                        // Scale factors for display
                        let scale = Math.min(180 / Math.max(a_val, b_val), 8);
                        let scaled_a = a_val * scale;
                        let scaled_b = b_val * scale;
                        
                        // Center the triangle in the box
                        let offset_x = (350 - scaled_a) / 2;
                        let offset_y = (250 + scaled_b) / 2;

                        // Triangle vertices (right angle at origin)
                        let vertices = [
                           {x: offset_x, y: offset_y},              // Right angle corner
                           {x: offset_x + scaled_a, y: offset_y},   // End of side 'a'
                           {x: offset_x, y: offset_y - scaled_b}    // End of side 'b'
                        ];

                        // Draw the three sides
                        objects.push(new fabric.Line([
                           vertices[0].x, vertices[0].y,
                           vertices[1].x, vertices[1].y
                        ], {
                           stroke: "#2196F3", strokeWidth: 3, selectable: false
                        }));

                        objects.push(new fabric.Line([
                           vertices[0].x, vertices[0].y,
                           vertices[2].x, vertices[2].y
                        ], {
                           stroke: "#4CAF50", strokeWidth: 3, selectable: false
                        }));

                        objects.push(new fabric.Line([
                           vertices[1].x, vertices[1].y,
                           vertices[2].x, vertices[2].y
                        ], {
                           stroke: "#FF5722", strokeWidth: 4, selectable: false
                        }));

                        // Right angle indicator
                        let angle_size = Math.min(20, scaled_a * 0.15, scaled_b * 0.15);
                        objects.push(new fabric.Polyline([
                           {x: offset_x, y: offset_y},
                           {x: offset_x + angle_size, y: offset_y},
                           {x: offset_x + angle_size, y: offset_y - angle_size},
                           {x: offset_x, y: offset_y - angle_size}
                        ], {
                           fill: "transparent", stroke: "#666666", strokeWidth: 1, selectable: false
                        }));

                        // Labels
                        objects.push(new fabric.Text(`a = ${a_val}`, {
                           left: offset_x + scaled_a / 2, top: offset_y + 15,
                           fontSize: 13, fill: "#2196F3", fontWeight: "bold",
                           textAlign: "center", selectable: false
                        }));
                        
                        objects.push(new fabric.Text(`b = ${b_val}`, {
                           left: offset_x - 35, top: offset_y - scaled_b / 2,
                           fontSize: 13, fill: "#4CAF50", fontWeight: "bold",
                           textAlign: "center", selectable: false, angle: -90
                        }));
                        
                        objects.push(new fabric.Text(`c = ${c_val}`, {
                           left: offset_x + scaled_a / 2 + 15, top: offset_y - scaled_b / 2 - 15,
                           fontSize: 13, fill: "#FF5722", fontWeight: "bold",
                           textAlign: "center", selectable: false
                        }));

                        // Title - X-centered
                        objects.push(new fabric.Text("Right Triangle", {
                           left: 175, top: 15, fontSize: 16, fill: "#495057",
                           fontWeight: "bold", textAlign: "center", selectable: false,
                           originX: "center"
                        }));
                     }
                     
                     return objects;
                  }

            // Dashboard Visualization Scope
            /dashboard
               $ANY = |iterate$ANY;
               \viz_js
                  where: {left: 450, top: -20},
                  box: {width: 300, height: 350, strokeWidth: 1, stroke: "#e0e0e0"},
                  render() {
                     // Get current values
                     let a_val = '|iterate/held$a'.asInt() || 0;
                     let b_val = '|iterate/held$b'.asInt() || 0;
                     let c_val = '$result'.asInt() || 0;
                     let valid = '$valid'.asBool();
                     let sum_val = '|iterate/compute$sum'.asInt() || 0;
                     let target_val = '$target'.asInt() || 0;
                     let guess_val = '$guess'.asInt() || 0;
                     let new_guess_val = '$new_guess'.asInt() || 0;
                     let quotient_val = '$quotient'.asInt() || 0;
                     let iteration_val = '$iteration'.asInt() || 0;
                     let active = '$active'.asBool();
                     let continue_val = '$continue'.asBool();

                     let objects = [];

                     if (a_val > 0 || b_val > 0 || active) {
                        // Title - X-centered
                        objects.push(new fabric.Text("Newton-Raphson Dashboard", {
                           left: 150, top: 15, fontSize: 15, fill: "#495057",
                           fontWeight: "bold", textAlign: "center", selectable: false,
                           originX: "center"
                        }));
                        
                        // Input values
                        objects.push(new fabric.Text("Inputs:", {
                           left: 20, top: 45, fontSize: 13, fill: "#6c757d",
                           fontWeight: "bold", selectable: false
                        }));
                        
                        objects.push(new fabric.Text(`a = ${a_val}`, {
                           left: 30, top: 65, fontSize: 12, fill: "#2196F3",
                           fontWeight: "bold", selectable: false
                        }));
                        
                        objects.push(new fabric.Text(`b = ${b_val}`, {
                           left: 30, top: 85, fontSize: 12, fill: "#4CAF50",
                           fontWeight: "bold", selectable: false
                        }));
                        
                        // Computation
                        objects.push(new fabric.Text("Computation:", {
                           left: 20, top: 115, fontSize: 13, fill: "#6c757d",
                           fontWeight: "bold", selectable: false
                        }));
                        
                        objects.push(new fabric.Text(`a² + b² = ${a_val}² + ${b_val}² = ${sum_val}`, {
                           left: 30, top: 135, fontSize: 11, fill: "#6c757d", selectable: false
                        }));
                        
                        objects.push(new fabric.Text(`Target = √${sum_val}`, {
                           left: 30, top: 155, fontSize: 11, fill: "#6c757d", selectable: false
                        }));
                        
                        // Current iteration
                        if (active || valid) {
                           objects.push(new fabric.Text("Current Iteration:", {
                              left: 20, top: 185, fontSize: 13, fill: "#6c757d",
                              fontWeight: "bold", selectable: false
                           }));
                           
                           objects.push(new fabric.Text(`Iteration: ${iteration_val}`, {
                              left: 30, top: 205, fontSize: 11,
                              fill: active ? "#FF9800" : "#6c757d",
                              fontWeight: active ? "bold" : "normal", selectable: false
                           }));
                           
                           objects.push(new fabric.Text(`Guess: ${guess_val}`, {
                              left: 30, top: 225, fontSize: 11, fill: "#6c757d", selectable: false
                           }));
                           
                           if (quotient_val > 0) {
                              objects.push(new fabric.Text(`${target_val} ÷ ${guess_val} = ${quotient_val}`, {
                                 left: 30, top: 245, fontSize: 10, fill: "#6c757d", selectable: false
                              }));
                              
                              objects.push(new fabric.Text(`(${guess_val} + ${quotient_val}) ÷ 2 = ${new_guess_val}`, {
                                 left: 30, top: 265, fontSize: 10, fill: "#6c757d", selectable: false
                              }));
                           }
                           
                           // Status
                           let status_text = "";
                           let status_color = "";
                           if (valid) {
                              status_text = "✓ Converged!";
                              status_color = "#4CAF50";
                           } else if (active && continue_val) {
                              status_text = "⏳ Iterating...";
                              status_color = "#FF9800";
                           } else if (active && !continue_val) {
                              status_text = "🏁 Finishing...";
                              status_color = "#2196F3";
                           } else {
                              status_text = "⏸ Idle";
                              status_color = "#6c757d";
                           }
                           
                           objects.push(new fabric.Text(status_text, {
                              left: 30, top: 295, fontSize: 12, fill: status_color,
                              fontWeight: "bold", selectable: false
                           }));
                        }
                        
                        // Result
                        if (valid) {
                           objects.push(new fabric.Text("Final Result:", {
                              left: 150, top: 185, fontSize: 13, fill: "#6c757d",
                              fontWeight: "bold", selectable: false
                           }));
                           
                           objects.push(new fabric.Text(`c = ${c_val}`, {
                              left: 160, top: 205, fontSize: 15, fill: "#FF5722",
                              fontWeight: "bold", selectable: false
                           }));
                           
                           // Verification
                           let actual_c_squared = c_val * c_val;
                           let error = Math.abs(actual_c_squared - sum_val);
                           objects.push(new fabric.Text(`Verify: ${c_val}² = ${actual_c_squared}`, {
                              left: 160, top: 230, fontSize: 10, fill: "#6c757d", selectable: false
                           }));
                           
                           objects.push(new fabric.Text(`Error: ${error}`, {
                              left: 160, top: 250, fontSize: 10,
                              fill: error < 10 ? "#4CAF50" : "#FF5722", selectable: false
                           }));
                        }
                     }
                     
                     return objects;
                  }

            // Convergence Graph Scope
            /plot
               $ANY = |iterate$ANY;
               \viz_js
                  where: {left: 50, top: 320},
                  box: {width: 700, height: 250, strokeWidth: 1, stroke: "#e0e0e0"},
                  render() {
                     let active = '$active'.asBool();
                     let valid = '$valid'.asBool();
                     
                     let objects = [];

                     if (active || valid) {
                        try {
                           // Create signal set for the iteration pipeline
                           let sig_obj = {
                              active: '$active',
                              iteration: '$iteration', 
                              guess: '$guess',
                              new_guess: '$new_guess',
                              target: '$target',
                              continue: '$continue'
                           };
                           let sigs = this.signalSet(sig_obj);
                           
                           // Find the start of the current computation
                           let active_sig = sigs.sig("active");
                           sigs.backToValue(active_sig, 0);  // Go to inactive
                           sigs.forwardToValue(active_sig, 1); // Go to start of active period
                           
                           // Collect convergence data
                           let convergence_data = [];
                           let max_iterations = 7;
                           
                           for (let i = 0; i < max_iterations; i++) {
                              if (sigs.sig("active").asBool()) {
                                 let iter_num = sigs.sig("iteration").asInt();
                                 let guess = sigs.sig("guess").asInt();
                                 let target = sigs.sig("target").asInt();
                                 
                                 convergence_data.push({
                                    iteration: iter_num,
                                    guess: guess,
                                    target: target
                                 });
                                 
                                 // Step to next iteration
                                 sigs.step(1);
                                 if (!sigs.sig("continue").asBool()) break;
                              } else {
                                 break;
                              }
                           }
                           
                           if (convergence_data.length > 0) {
                              // Graph dimensions
                              let graph_width = 650;
                              let graph_height = 200;
                              let margin = 50;
                              let plot_width = graph_width - 2 * margin;
                              let plot_height = graph_height - 2 * margin;
                              
                              // Graph title - X-centered
                              objects.push(new fabric.Text("Newton-Raphson Convergence", {
                                 left: graph_width / 2, top: 15, fontSize: 16, fill: "#495057",
                                 fontWeight: "bold", textAlign: "center", selectable: false,
                                 originX: "center"
                              }));
                              
                              // Calculate scales
                              let target_val = convergence_data[0].target;
                              let actual_result = Math.sqrt(target_val);
                              let max_guess = Math.max(...convergence_data.map(d => d.guess));
                              let min_guess = Math.min(...convergence_data.map(d => d.guess));
                              let y_range = Math.max(max_guess - min_guess, actual_result * 0.5);
                              let y_center = (max_guess + min_guess) / 2;
                              
                              // Draw target line (horizontal reference)
                              let target_y = margin + plot_height * (1 - (actual_result - (y_center - y_range/2)) / y_range);
                              objects.push(new fabric.Line([
                                 margin, target_y, 
                                 margin + plot_width, target_y
                              ], {
                                 stroke: "#FF5722", strokeWidth: 2,
                                 strokeDashArray: [5, 5], selectable: false
                              }));
                              
                              objects.push(new fabric.Text(`√${target_val} = ${actual_result.toFixed(1)}`, {
                                 left: margin + plot_width + 10, top: target_y - 8,
                                 fontSize: 11, fill: "#FF5722", selectable: false
                              }));
                              
                              // Draw convergence curve
                              let points = [];
                              for (let i = 0; i < convergence_data.length; i++) {
                                 let x = margin + (i / Math.max(convergence_data.length - 1, 1)) * plot_width;
                                 let y = margin + plot_height * (1 - (convergence_data[i].guess - (y_center - y_range/2)) / y_range);
                                 points.push({x: x, y: y});
                                 
                                 // Draw point
                                 objects.push(new fabric.Circle({
                                    left: x - 4, top: y - 4, radius: 4,
                                    fill: "#2196F3", selectable: false
                                 }));
                                 
                                 // Add value label
                                 objects.push(new fabric.Text(`${convergence_data[i].guess}`, {
                                    left: x - 10, top: y - 25, fontSize: 10,
                                    fill: "#2196F3", textAlign: "center", selectable: false
                                 }));
                                 
                                 // Add iteration label
                                 objects.push(new fabric.Text(`${convergence_data[i].iteration}`, {
                                    left: x - 5, top: margin + plot_height + 10, fontSize: 11,
                                    fill: "#6c757d", textAlign: "center", selectable: false
                                 }));
                              }
                              
                              // Draw connecting lines
                              for (let i = 0; i < points.length - 1; i++) {
                                 objects.push(new fabric.Line([
                                    points[i].x, points[i].y,
                                    points[i + 1].x, points[i + 1].y
                                 ], {
                                    stroke: "#2196F3", strokeWidth: 2, selectable: false
                                 }));
                              }
                              
                              // Axes labels
                              objects.push(new fabric.Text("Iteration", {
                                 left: graph_width / 2, top: graph_height - 15,
                                 fontSize: 12, fill: "#6c757d", textAlign: "center", selectable: false
                              }));
                              
                              objects.push(new fabric.Text("Guess Value", {
                                 left: 15, top: graph_height / 2, fontSize: 12,
                                 fill: "#6c757d", angle: -90, selectable: false
                              }));
                           }
                           
                        } catch (error) {
                           // Fallback if signal stepping fails
                           objects.push(new fabric.Text("Convergence graph: " + error.message, {
                              left: 50, top: 50, fontSize: 12, fill: "#999999", selectable: false
                           }));
                        }
                     }
                     
                     return objects;
                  }

\SV
endmodule

// Makerchip testbench
module top(input wire clk, input wire reset, input wire [31:0] cyc_cnt, output wire passed, output wire failed);

   reg [15:0] a, b;
   reg start;
   wire [15:0] c;
   wire valid;
   
   pythagorean_theorem dut (
      .clk(clk),
      .rst(reset),
      .a(a),
      .b(b),
      .start(start),
      .c(c),
      .valid(valid)
   );
   
   // Test control logic based on cycle count
   always @(*) begin
      case (cyc_cnt)
         // Test case 1: 3-4-5 triangle
         32'd1: begin a = 16'd3; b = 16'd4; start = 1; end
         32'd2: begin a = 16'd3; b = 16'd4; start = 0; end
         
         // Test case 2: 5-12-13 triangle  
         32'd15: begin a = 16'd5; b = 16'd12; start = 1; end
         32'd16: begin a = 16'd5; b = 16'd12; start = 0; end
         
         // Test case 3: 8-15-17 triangle
         32'd30: begin a = 16'd8; b = 16'd15; start = 1; end
         32'd31: begin a = 16'd8; b = 16'd15; start = 0; end
         
         default: begin a = 16'd0; b = 16'd0; start = 0; end
      endcase
   end
   
   // Test validation logic
   reg test_passed;
   always @(posedge clk) begin
      if (reset) begin
         test_passed <= 0;
      end else begin
         // Check results at expected cycles (9 cycles after start)
         if (cyc_cnt == 32'd10 && valid && c >= 16'd4 && c <= 16'd6) // 3-4-5 -> ~5
            test_passed <= 1;
         else if (cyc_cnt == 32'd25 && valid && c >= 16'd12 && c <= 14) // 5-12-13 -> ~13  
            test_passed <= 1;
         else if (cyc_cnt == 32'd40 && valid && c >= 16'd16 && c <= 16'd18) // 8-15-17 -> ~17
            test_passed <= 1;
      end
   end
   
   assign passed = test_passed && (cyc_cnt > 32'd50);
   assign failed = (cyc_cnt > 32'd100) && !test_passed;
   
endmodule
