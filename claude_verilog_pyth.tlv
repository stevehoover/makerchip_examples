\m4_TLV_version 1d: tl-x.org
\SV
   // Pythagorean Theorem Circuit
   // Computes c = sqrt(a^2 + b^2) using Newton-Raphson iteration
   // With Visual Debug visualization

   // Pythagorean Theorem Circuit
   // Computes c = sqrt(a^2 + b^2) using Newton-Raphson iteration

   module pythagorean_theorem (
       input clk,
       input rst,
       input [15:0] a,
       input [15:0] b,
       input start,
       output reg [15:0] c,
       output reg valid
   );

       // Internal registers matching TL-Verilog signal names
       reg [31:0] sum;               // Corresponds to $sum
       reg [15:0] guess;             // Corresponds to $guess and $iter_guess  
       reg [15:0] new_guess;         // Corresponds to $new_guess
       reg [31:0] quotient;          // Corresponds to $quotient
       reg [16:0] sum_temp;          // Corresponds to $sum_temp
       reg [3:0] iteration;          // Corresponds to $iter_iteration
       reg [15:0] result;            // Corresponds to $result
       
       // Additional TL-Verilog signals for better alignment
       reg new_transaction;          // Corresponds to $new_transaction
       reg active;                   // Corresponds to $active  
       reg [31:0] target;            // Corresponds to $target
       reg [31:0] iter_target;       // Corresponds to $iter_target
       reg [15:0] iter_guess;        // Corresponds to $iter_guess
       reg [3:0] iter_iteration;     // Corresponds to $iter_iteration
       
       // Intermediate calculation variables for width handling
       reg [15:0] quotient_16;       // Quotient truncated to 16 bits
       reg [16:0] temp_sum;          // Temporary sum for calculation
       wire [31:0] division_result;  // Wire for division result
       wire [15:0] division_16;      // 16-bit division result
       wire [16:0] sum_17;           // 17-bit sum result
       wire [15:0] new_guess_calc;   // Calculated new guess
       
       // Combinational assignments for division and calculation
       assign division_result = iter_target / {16'b0, iter_guess};
       assign division_16 = division_result[15:0];
       assign sum_17 = {1'b0, iter_guess} + {1'b0, division_16};
       assign new_guess_calc = sum_17[16:1];  // Divide by 2 using bit selection
       
       reg cont;                     // Corresponds to $continue (renamed from continue - keyword)
       reg done;                     // Corresponds to $done
       
       // State machine parameters - aligned with TL-Verilog pipeline stages
       reg [2:0] state;
       parameter IDLE = 3'b000;
       parameter STAGE1_INPUT = 3'b001;      // Corresponds to @1 (input staging)
       parameter STAGE2_COMPUTE = 3'b010;    // Corresponds to @2 (sum calculation & iteration)
       parameter STAGE2_ITERATE = 3'b011;    // Corresponds to @2 (Newton-Raphson iteration)
       parameter STAGE3_OUTPUT = 3'b100;     // Corresponds to @3 (output stage)
       
       // Maximum iterations parameter
       parameter [3:0] max_iterations = 4'd6;  // Corresponds to $max_iterations

       always @(posedge clk or posedge rst) begin
           if (rst) begin
               state <= IDLE;
               valid <= 0;
               c <= 0;
               iteration <= 0;
               new_transaction <= 0;
               active <= 0;
               target <= 0;
               iter_target <= 0;
               iter_guess <= 0;
               iter_iteration <= 0;
               sum <= 0;
               guess <= 0;
               new_guess <= 0;
               quotient <= 0;
               quotient_16 <= 0;
               temp_sum <= 0;
               sum_temp <= 0;
               result <= 0;
               cont <= 0;
               done <= 0;
           end
           else begin
               case (state)
                   IDLE: begin
                       valid <= 0;
                       new_transaction <= start;  // Corresponds to $new_transaction = *start
                       if (start) begin
                           state <= STAGE1_INPUT;
                       end
                   end
                   
                   STAGE1_INPUT: begin
                       // @1 stage: Input staging (corresponds to TL-V @1)
                       if (new_transaction) begin
                           // Calculate sum and initialize iteration (matches @2 stage)
                           sum <= (a * a) + (b * b);
                           target <= (a * a) + (b * b);  // Store target for iteration
                           iteration <= 4'b0;
                           new_transaction <= 0;
                           state <= STAGE2_COMPUTE;
                       end
                   end
                   
                   STAGE2_COMPUTE: begin
                       // @2 stage: Initialize iteration (corresponds to TL-V @2)
                       // Better initial guess: use upper bits of sum for better convergence
                       guess <= (sum[31:16] == 0) ? {8'b0, sum[15:8]} + 1 : sum[31:16] + 1;
                       iter_target <= sum;     // Set up iteration variables
                       iter_guess <= (sum[31:16] == 0) ? {8'b0, sum[15:8]} + 1 : sum[31:16] + 1;
                       iter_iteration <= 4'b0;
                       active <= 1;           // Corresponds to $active
                       state <= STAGE2_ITERATE;
                   end
                   
                   STAGE2_ITERATE: begin
                       // @2 stage: Newton-Raphson iteration (corresponds to TL-V iteration logic)
                       if (active) begin
                           // Calculate quotient and new_guess combinationally (same cycle like TL-V @2)
                           // Store quotient for bit selection
                           quotient <= division_result;
                           quotient_16 <= division_16;
                           
                           // Use combinational logic for immediate calculation with proper width handling
                           temp_sum <= sum_17;
                           sum_temp <= sum_17;
                           new_guess <= new_guess_calc;
                           
                           // Update iteration variables for next cycle
                           iter_guess <= new_guess_calc;
                           iter_iteration <= iter_iteration + 1;
                           
                           // Check continuation condition
                           cont <= iter_iteration < max_iterations;
                           done <= iter_iteration >= max_iterations;
                           
                           if (iter_iteration >= max_iterations) begin
                               active <= 0;
                               state <= STAGE3_OUTPUT;
                           end
                       end
                   end
                   
                   STAGE3_OUTPUT: begin
                       // @3 stage: Output stage (corresponds to TL-V @3)
                       if (done) begin
                           result <= new_guess;    // Corresponds to $result
                           c <= new_guess;         // Corresponds to *c = $result
                           valid <= 1;            // Corresponds to *valid = $valid
                           state <= IDLE;
                       end
                   end
                   
                   default: state <= IDLE;
               endcase
           end
       end

   endmodule

   // Top-level testbench for Makerchip
   module top(input wire clk, input wire reset, input wire [31:0] cyc_cnt, output wire passed, output wire failed);
       
       reg [15:0] a;
       reg [15:0] b;
       reg start;
       wire [15:0] c;
       wire valid;    // Changed from 'done' to match TL-Verilog
       
       // Test state machine
       reg [3:0] test_state;
       reg [15:0] expected_c;
       reg test_complete;
       reg all_tests_passed;
       
       parameter TEST_IDLE = 4'd0;
       parameter TEST1_START = 4'd1;
       parameter TEST1_WAIT = 4'd2;
       parameter TEST1_CHECK = 4'd3;
       parameter TEST2_START = 4'd4;
       parameter TEST2_WAIT = 4'd5;
       parameter TEST2_CHECK = 4'd6;
       parameter TEST3_START = 4'd7;
       parameter TEST3_WAIT = 4'd8;
       parameter TEST3_CHECK = 4'd9;
       parameter TEST4_START = 4'd10;
       parameter TEST4_WAIT = 4'd11;
       parameter TEST4_CHECK = 4'd12;
       parameter TEST_DONE = 4'd13;

       // Instantiate the DUT (Device Under Test)
       pythagorean_theorem dut (
           .clk(clk),
           .rst(reset),
           .a(a),
           .b(b),
           .start(start),
           .c(c),
           .valid(valid)    // Changed from .done(done) to match TL-Verilog
       );

       // Test control logic
       always @(posedge clk) begin
           if (reset) begin
               test_state <= TEST_IDLE;
               a <= 0;
               b <= 0;
               start <= 0;
               test_complete <= 0;
               all_tests_passed <= 1;
           end
           else begin
               case (test_state)
                   TEST_IDLE: begin
                       if (cyc_cnt > 10) begin
                           test_state <= TEST1_START;
                       end
                   end
                   
                   TEST1_START: begin
                       a <= 3; b <= 4; start <= 1;
                       expected_c <= 5;
                       test_state <= TEST1_WAIT;
                   end
                   
                   TEST1_WAIT: begin
                       start <= 0;
                       if (valid) begin    // Changed from 'done' to 'valid'
                           test_state <= TEST1_CHECK;
                       end
                   end
                   
                   TEST1_CHECK: begin
                       if (c != expected_c && (c < expected_c - 1 || c > expected_c + 1)) begin
                           all_tests_passed <= 0;
                       end
                       test_state <= TEST2_START;
                   end
                   
                   TEST2_START: begin
                       a <= 5; b <= 12; start <= 1;
                       expected_c <= 13;
                       test_state <= TEST2_WAIT;
                   end
                   
                   TEST2_WAIT: begin
                       start <= 0;
                       if (valid) begin    // Changed from 'done' to 'valid'
                           test_state <= TEST2_CHECK;
                       end
                   end
                   
                   TEST2_CHECK: begin
                       if (c != expected_c && (c < expected_c - 1 || c > expected_c + 1)) begin
                           all_tests_passed <= 0;
                       end
                       test_state <= TEST3_START;
                   end
                   
                   TEST3_START: begin
                       a <= 8; b <= 15; start <= 1;
                       expected_c <= 17;
                       test_state <= TEST3_WAIT;
                   end
                   
                   TEST3_WAIT: begin
                       start <= 0;
                       if (valid) begin    // Changed from 'done' to 'valid'
                           test_state <= TEST3_CHECK;
                       end
                   end
                   
                   TEST3_CHECK: begin
                       if (c != expected_c && (c < expected_c - 1 || c > expected_c + 1)) begin
                           all_tests_passed <= 0;
                       end
                       test_state <= TEST4_START;
                   end
                   
                   TEST4_START: begin
                       a <= 10; b <= 10; start <= 1;
                       expected_c <= 14; // sqrt(200) ≈ 14.14
                       test_state <= TEST4_WAIT;
                   end
                   
                   TEST4_WAIT: begin
                       start <= 0;
                       if (valid) begin    // Changed from 'done' to 'valid'
                           test_state <= TEST4_CHECK;
                       end
                   end
                   
                   TEST4_CHECK: begin
                       if (c != expected_c && (c < expected_c - 1 || c > expected_c + 1)) begin
                           all_tests_passed <= 0;
                       end
                       test_state <= TEST_DONE;
                   end
                   
                   TEST_DONE: begin
                       test_complete <= 1;
                   end
                   
                   default: test_state <= TEST_IDLE;
               endcase
           end
       end
       
       // Output assignment
       assign passed = test_complete && all_tests_passed;
       assign failed = test_complete && !all_tests_passed;

\TLV
   // Import signals from Verilog module
   $reset = *reset;
   
   // Pythagorean Theorem Circuit Visualization
   \viz_js
      //box: {width: 800, height: 600, strokeWidth: 1},
      
      init() {
         // Title
         let title = new fabric.Text("Pythagorean Theorem Calculator", {
            left: 400, top: 20,
            fontSize: 24, fontWeight: "bold",
            fill: "darkblue", textAlign: "center", originX: "center"
         });
         
         // Mathematical formula display
         let formula = new fabric.Text("c = √(a² + b²)", {
            left: 400, top: 50,
            fontSize: 18, fontStyle: "italic",
            fill: "darkgreen", textAlign: "center", originX: "center"
         });
         
         // Newton-Raphson formula
         let nr_formula = new fabric.Text("Newton-Raphson: x_{n+1} = (x_n + target/x_n) / 2", {
            left: 400, top: 75,
            fontSize: 14, fontStyle: "italic",
            fill: "purple", textAlign: "center", originX: "center"
         });
         
         // Input section background
         let input_bg = new fabric.Rect({
            left: 50, top: 110, width: 200, height: 120,
            fill: "lightblue", stroke: "blue", strokeWidth: 2, rx: 10
         });
         
         // Input labels and values
         let input_title = new fabric.Text("Inputs", {
            left: 150, top: 120,
            fontSize: 16, fontWeight: "bold",
            fill: "darkblue", textAlign: "center", originX: "center"
         });
         
         let a_label = new fabric.Text("a =", {
            left: 70, top: 150, fontSize: 14, fill: "black"
         });
         let a_value = new fabric.Text("0", {
            left: 110, top: 150, fontSize: 14, fill: "red", fontWeight: "bold"
         });
         
         let b_label = new fabric.Text("b =", {
            left: 70, top: 175, fontSize: 14, fill: "black"
         });
         let b_value = new fabric.Text("0", {
            left: 110, top: 175, fontSize: 14, fill: "red", fontWeight: "bold"
         });
         
         let sum_label = new fabric.Text("a² + b² =", {
            left: 70, top: 200, fontSize: 14, fill: "black"
         });
         let sum_value = new fabric.Text("0", {
            left: 140, top: 200, fontSize: 14, fill: "orange", fontWeight: "bold"
         });
         
         // State machine visualization
         let state_bg = new fabric.Rect({
            left: 300, top: 110, width: 200, height: 200,
            fill: "lightyellow", stroke: "darkgoldenrod", strokeWidth: 2, rx: 10
         });
         
         let state_title = new fabric.Text("State Machine", {
            left: 400, top: 120,
            fontSize: 16, fontWeight: "bold",
            fill: "darkgoldenrod", textAlign: "center", originX: "center"
         });
         
         // State circles
         let idle_circle = new fabric.Circle({
            left: 330, top: 150, radius: 15,
            fill: "lightgray", stroke: "black", strokeWidth: 1,
            originX: "center", originY: "center"
         });
         let idle_text = new fabric.Text("IDLE", {
            left: 330, top: 150, fontSize: 8,
            fill: "black", textAlign: "center", originX: "center", originY: "center"
         });
         
         let compute_circle = new fabric.Circle({
            left: 400, top: 180, radius: 15,
            fill: "lightgray", stroke: "black", strokeWidth: 1,
            originX: "center", originY: "center"
         });
         let compute_text = new fabric.Text("COMP", {
            left: 400, top: 180, fontSize: 8,
            fill: "black", textAlign: "center", originX: "center", originY: "center"
         });
         
         let iterate_circle = new fabric.Circle({
            left: 470, top: 220, radius: 15,
            fill: "lightgray", stroke: "black", strokeWidth: 1,
            originX: "center", originY: "center"
         });
         let iterate_text = new fabric.Text("ITER", {
            left: 470, top: 220, fontSize: 8,
            fill: "black", textAlign: "center", originX: "center", originY: "center"
         });
         
         let output_circle = new fabric.Circle({
            left: 400, top: 280, radius: 15,
            fill: "lightgray", stroke: "black", strokeWidth: 1,
            originX: "center", originY: "center"
         });
         let output_text = new fabric.Text("OUT", {
            left: 400, top: 280, fontSize: 8,
            fill: "black", textAlign: "center", originX: "center", originY: "center"
         });
         
         // Iteration details section
         let iter_bg = new fabric.Rect({
            left: 550, top: 110, width: 200, height: 200,
            fill: "lightcyan", stroke: "teal", strokeWidth: 2, rx: 10
         });
         
         let iter_title = new fabric.Text("Newton-Raphson", {
            left: 650, top: 120,
            fontSize: 16, fontWeight: "bold",
            fill: "teal", textAlign: "center", originX: "center"
         });
         
         let iter_count_label = new fabric.Text("Iteration:", {
            left: 570, top: 150, fontSize: 12, fill: "black"
         });
         let iter_count_value = new fabric.Text("0", {
            left: 630, top: 150, fontSize: 12, fill: "red", fontWeight: "bold"
         });
         
         let guess_label = new fabric.Text("Guess:", {
            left: 570, top: 175, fontSize: 12, fill: "black"
         });
         let guess_value = new fabric.Text("0", {
            left: 620, top: 175, fontSize: 12, fill: "blue", fontWeight: "bold"
         });
         
         let quotient_label = new fabric.Text("Target/Guess:", {
            left: 570, top: 200, fontSize: 12, fill: "black"
         });
         let quotient_value = new fabric.Text("0", {
            left: 660, top: 200, fontSize: 12, fill: "green", fontWeight: "bold"
         });
         
         let new_guess_label = new fabric.Text("New Guess:", {
            left: 570, top: 225, fontSize: 12, fill: "black"
         });
         let new_guess_value = new fabric.Text("0", {
            left: 640, top: 225, fontSize: 12, fill: "purple", fontWeight: "bold"
         });
         
         // Result section
         let result_bg = new fabric.Rect({
            left: 50, top: 350, width: 200, height: 100,
            fill: "lightgreen", stroke: "green", strokeWidth: 2, rx: 10
         });
         
         let result_title = new fabric.Text("Result", {
            left: 150, top: 360,
            fontSize: 16, fontWeight: "bold",
            fill: "darkgreen", textAlign: "center", originX: "center"
         });
         
         let c_label = new fabric.Text("c =", {
            left: 70, top: 390, fontSize: 18, fill: "black", fontWeight: "bold"
         });
         let c_value = new fabric.Text("0", {
            left: 110, top: 390, fontSize: 18, fill: "red", fontWeight: "bold"
         });
         
         let valid_label = new fabric.Text("Valid:", {
            left: 70, top: 415, fontSize: 14, fill: "black"
         });
         let valid_value = new fabric.Text("false", {
            left: 120, top: 415, fontSize: 14, fill: "red", fontWeight: "bold"
         });
         
         // Test status section
         let test_bg = new fabric.Rect({
            left: 300, top: 350, width: 450, height: 100,
            fill: "lavender", stroke: "indigo", strokeWidth: 2, rx: 10
         });
         
         let test_title = new fabric.Text("Test Status", {
            left: 525, top: 360,
            fontSize: 16, fontWeight: "bold",
            fill: "indigo", textAlign: "center", originX: "center"
         });
         
         let test_case_label = new fabric.Text("Test Case:", {
            left: 320, top: 385, fontSize: 12, fill: "black"
         });
         let test_case_value = new fabric.Text("IDLE", {
            left: 385, top: 385, fontSize: 12, fill: "blue", fontWeight: "bold"
         });
         
         let expected_label = new fabric.Text("Expected:", {
            left: 500, top: 385, fontSize: 12, fill: "black"
         });
         let expected_value = new fabric.Text("0", {
            left: 560, top: 385, fontSize: 12, fill: "orange", fontWeight: "bold"
         });
         
         let status_label = new fabric.Text("Status:", {
            left: 320, top: 410, fontSize: 12, fill: "black"
         });
         let status_value = new fabric.Text("Running", {
            left: 370, top: 410, fontSize: 12, fill: "blue", fontWeight: "bold"
         });
         
         return {
            title, formula, nr_formula,
            input_bg, input_title, a_label, a_value, b_label, b_value, sum_label, sum_value,
            state_bg, state_title, 
            idle_circle, idle_text, compute_circle, compute_text, 
            iterate_circle, iterate_text, output_circle, output_text,
            iter_bg, iter_title, iter_count_label, iter_count_value,
            guess_label, guess_value, quotient_label, quotient_value,
            new_guess_label, new_guess_value,
            result_bg, result_title, c_label, c_value, valid_label, valid_value,
            test_bg, test_title, test_case_label, test_case_value,
            expected_label, expected_value, status_label, status_value
         };
      },
      
      render() {
         // Access SystemVerilog signals using this.sigVal("signal_path")
         // Update input values
         this.getObjects().a_value.set({text: this.sigVal("a").asInt().toString()});
         this.getObjects().b_value.set({text: this.sigVal("b").asInt().toString()});
         this.getObjects().sum_value.set({text: this.sigVal("dut.sum").asInt().toString()});
         
         // Update state machine visualization
         let state = this.sigVal("dut.state").asInt();
         
         // Reset all circles to gray
         this.getObjects().idle_circle.set("fill", "lightgray");
         this.getObjects().compute_circle.set("fill", "lightgray");
         this.getObjects().iterate_circle.set("fill", "lightgray");
         this.getObjects().output_circle.set("fill", "lightgray");
         
         // Highlight current state
         switch(state) {
            case 0: // IDLE
               this.getObjects().idle_circle.set("fill", "red");
               break;
            case 1: // STAGE1_INPUT
               this.getObjects().compute_circle.set("fill", "yellow");
               break;
            case 2: // STAGE2_COMPUTE
               this.getObjects().compute_circle.set("fill", "orange");
               break;
            case 3: // STAGE2_ITERATE
               this.getObjects().iterate_circle.set("fill", "lightblue");
               break;
            case 4: // STAGE3_OUTPUT
               this.getObjects().output_circle.set("fill", "lightgreen");
               break;
         }
         
         // Update iteration details
         this.getObjects().iter_count_value.set({text: this.sigVal("dut.iter_iteration").asInt().toString()});
         this.getObjects().guess_value.set({text: this.sigVal("dut.iter_guess").asInt().toString()});
         this.getObjects().quotient_value.set({text: this.sigVal("dut.quotient_16").asInt().toString()});
         this.getObjects().new_guess_value.set({text: this.sigVal("dut.new_guess").asInt().toString()});
         
         // Update result
         this.getObjects().c_value.set({text: this.sigVal("c").asInt().toString()});
         this.getObjects().valid_value.set({text: this.sigVal("valid").asBool() ? "true" : "false"});
         this.getObjects().valid_value.set("fill", this.sigVal("valid").asBool() ? "green" : "red");
         
         // Update test status
         let test_state = this.sigVal("test_state").asInt();
         let test_names = ["IDLE", "T1_START", "T1_WAIT", "T1_CHECK", 
                          "T2_START", "T2_WAIT", "T2_CHECK",
                          "T3_START", "T3_WAIT", "T3_CHECK",
                          "T4_START", "T4_WAIT", "T4_CHECK", "DONE"];
         this.getObjects().test_case_value.set({text: test_names[test_state] || "UNKNOWN"});
         
         this.getObjects().expected_value.set({text: this.sigVal("expected_c").asInt().toString()});
         
         let test_complete = this.sigVal("test_complete").asBool();
         let all_passed = this.sigVal("all_tests_passed").asBool();
         let status_text = test_complete ? (all_passed ? "PASSED" : "FAILED") : "Running";
         let status_color = test_complete ? (all_passed ? "green" : "red") : "blue";
         
         this.getObjects().status_value.set({text: status_text});
         this.getObjects().status_value.set("fill", status_color);
      }
\TLV
   /triangle
      \viz_js
         box: {width: 400, height: 300, strokeWidth: 1},
         where: {left: 0, top: 620},
         
         init() {
            let ret = {};
            
            // Triangle vertices (we'll draw a right triangle)
            // Bottom-left corner (right angle)
            let corner_x = 50;
            let corner_y = 250;
            
            // Title
            ret.title = new fabric.Text("Right Triangle Visualization", {
               left: 200, top: 15,
               fontSize: 16, fontWeight: "bold",
               fill: "darkblue", textAlign: "center", originX: "center"
            });
            
            // Triangle sides as lines
            ret.side_a = new fabric.Line([corner_x, corner_y, corner_x + 150, corner_y], {
               stroke: "red", strokeWidth: 3
            });
            
            ret.side_b = new fabric.Line([corner_x, corner_y, corner_x, corner_y - 100], {
               stroke: "blue", strokeWidth: 3
            });
            
            ret.side_c = new fabric.Line([corner_x, corner_y - 100, corner_x + 150, corner_y], {
               stroke: "green", strokeWidth: 3
            });
            
            // Right angle indicator (small square)
            ret.right_angle = new fabric.Rect({
               left: corner_x, top: corner_y - 15,
               width: 15, height: 15,
               fill: "transparent", stroke: "black", strokeWidth: 1
            });
            
            // Labels for the sides
            ret.label_a = new fabric.Text("a", {
               left: corner_x + 75, top: corner_y + 10,
               fontSize: 18, fontWeight: "bold", fill: "red",
               textAlign: "center", originX: "center"
            });
            
            ret.label_b = new fabric.Text("b", {
               left: corner_x - 15, top: corner_y - 50,
               fontSize: 18, fontWeight: "bold", fill: "blue",
               textAlign: "center", originX: "center"
            });
            
            ret.label_c = new fabric.Text("c", {
               left: corner_x + 85, top: corner_y - 65,
               fontSize: 18, fontWeight: "bold", fill: "green",
               textAlign: "center", originX: "center"
            });
            
            // Value displays
            ret.value_a = new fabric.Text("0", {
               left: corner_x + 75, top: corner_y + 30,
               fontSize: 14, fontWeight: "bold", fill: "red",
               textAlign: "center", originX: "center"
            });
            
            ret.value_b = new fabric.Text("0", {
               left: corner_x - 35, top: corner_y - 50,
               fontSize: 14, fontWeight: "bold", fill: "blue",
               textAlign: "center", originX: "center"
            });
            
            ret.value_c = new fabric.Text("0", {
               left: corner_x + 85, top: corner_y - 85,
               fontSize: 14, fontWeight: "bold", fill: "green",
               textAlign: "center", originX: "center"
            });
            
            // Calculation status
            ret.calc_status = new fabric.Text("Ready", {
               left: 300, top: 50,
               fontSize: 14, fill: "gray",
               textAlign: "center", originX: "center"
            });
            
            // Dynamic triangle outline (will scale with actual values)
            ret.dynamic_triangle = new fabric.Polygon([
               {x: corner_x, y: corner_y},
               {x: corner_x, y: corner_y},  // Will be updated
               {x: corner_x, y: corner_y}   // Will be updated
            ], {
               fill: "rgba(255, 255, 0, 0.1)",
               stroke: "orange",
               strokeWidth: 2,
               strokeDashArray: [5, 5]
            });
            
            // Grid lines for reference
            for (let i = 0; i <= 10; i++) {
               // Vertical grid lines
               ret["vgrid" + i] = new fabric.Line([corner_x + i * 20, corner_y + 20, corner_x + i * 20, corner_y - 120], {
                  stroke: "lightgray", strokeWidth: 0.5, opacity: 0.5
               });
               // Horizontal grid lines  
               ret["hgrid" + i] = new fabric.Line([corner_x - 20, corner_y - i * 12, corner_x + 200, corner_y - i * 12], {
                  stroke: "lightgray", strokeWidth: 0.5, opacity: 0.5
               });
            }
            
            return ret;
         },
         
         render() {
            // Get current values
            let a_val = this.sigVal("a").asInt();
            let b_val = this.sigVal("b").asInt();
            let c_val = this.sigVal("c").asInt();
            let valid = this.sigVal("valid").asBool();
            let calculating = this.sigVal("dut.active").asBool();
            
            // Update value displays
            this.getObjects().value_a.set({text: a_val.toString()});
            this.getObjects().value_b.set({text: b_val.toString()});
            this.getObjects().value_c.set({text: c_val.toString()});
            
            // Update calculation status
            let status_text = "Ready";
            let status_color = "gray";
            
            if (calculating) {
               status_text = "Calculating...";
               status_color = "orange";
            } else if (valid) {
               status_text = "Complete!";
               status_color = "green";
            }
            
            this.getObjects().calc_status.set({text: status_text, fill: status_color});
            
            // Scale the triangle based on actual values
            let scale_factor = 15; // Increased to align better with grid
            let corner_x = 50;
            let corner_y = 250;
            
            // Calculate scaled dimensions based on actual input values
            // Each unit = 20 pixels to align with grid
            let scaled_a = Math.max(a_val * 20, 20); // Each unit = 20 pixels (grid spacing)
            let scaled_b = Math.max(b_val * 20, 20); // Each unit = 20 pixels (grid spacing)
            
            // Limit to reasonable display size
            scaled_a = Math.min(scaled_a, 300);
            scaled_b = Math.min(scaled_b, 180);
            
            // Update the actual triangle sides to reflect proper dimensions
            this.getObjects().side_a.set({
               x1: corner_x, y1: corner_y,
               x2: corner_x + scaled_a, y2: corner_y
            });
            
            this.getObjects().side_b.set({
               x1: corner_x, y1: corner_y,
               x2: corner_x, y2: corner_y - scaled_b
            });
            
            this.getObjects().side_c.set({
               x1: corner_x, y1: corner_y - scaled_b,
               x2: corner_x + scaled_a, y2: corner_y
            });
            
            // Update the dynamic triangle to show actual proportions
            let triangle_points = [
               {x: corner_x, y: corner_y},                    // Bottom-left (right angle)
               {x: corner_x + scaled_a, y: corner_y},         // Bottom-right
               {x: corner_x, y: corner_y - scaled_b}          // Top-left
            ];
            
            this.getObjects().dynamic_triangle.set({
               points: triangle_points,
               opacity: valid ? 0.3 : 0.1
            });
            
            // Update labels to follow the triangle dimensions
            this.getObjects().label_a.set({
               left: corner_x + scaled_a / 2,
               top: corner_y + 15
            });
            
            this.getObjects().value_a.set({
               left: corner_x + scaled_a / 2,
               top: corner_y + 35
            });
            
            this.getObjects().label_b.set({
               left: corner_x - 15,
               top: corner_y - scaled_b / 2
            });
            
            this.getObjects().value_b.set({
               left: corner_x - 35,
               top: corner_y - scaled_b / 2
            });
            
            // Position hypotenuse label more to the right and towards the middle
            this.getObjects().label_c.set({
               left: corner_x + scaled_a * 0.6,  // 60% along the horizontal
               top: corner_y - scaled_b * 0.4   // 40% up the vertical
            });
            
            this.getObjects().value_c.set({
               left: corner_x + scaled_a * 0.6,  // 60% along the horizontal  
               top: corner_y - scaled_b * 0.4 + 20  // Slightly below the label
            });
            
            // Update right angle indicator position
            this.getObjects().right_angle.set({
               left: corner_x,
               top: corner_y - 15
            });
            
            // Make lines more prominent during calculation
            let line_width = calculating ? 4 : 3;
            let line_opacity = valid ? 1.0 : 0.7;
            
            this.getObjects().side_a.set({strokeWidth: line_width, opacity: line_opacity});
            this.getObjects().side_b.set({strokeWidth: line_width, opacity: line_opacity});
            this.getObjects().side_c.set({strokeWidth: line_width, opacity: line_opacity});
            
            // Highlight the hypotenuse when calculation is complete
            if (valid) {
               this.getObjects().side_c.set({
                  stroke: "darkgreen",
                  strokeWidth: 5,
                  strokeDashArray: [10, 5]
               });
            } else {
               this.getObjects().side_c.set({
                  stroke: "green",
                  strokeWidth: line_width,
                  strokeDashArray: []
               });
            }
         }
\TLV
   /convergence
      \viz_js
         where: {left: 420, top: 620},
         
         init() {
            let ret = {};
            
            // Title
            ret.title = new fabric.Text("Newton-Raphson Convergence", {
               left: 200, top: 15,
               fontSize: 16, fontWeight: "bold",
               fill: "darkblue", textAlign: "center", originX: "center"
            });
            
            // Graph background
            ret.graph_bg = new fabric.Rect({
               left: 50, top: 50, width: 300, height: 200,
               fill: "white", stroke: "black", strokeWidth: 2
            });
            
            // Axes
            ret.x_axis = new fabric.Line([50, 250, 350, 250], {
               stroke: "black", strokeWidth: 2
            });
            
            ret.y_axis = new fabric.Line([50, 50, 50, 250], {
               stroke: "black", strokeWidth: 2
            });
            
            // Axis labels
            ret.x_label = new fabric.Text("Iteration", {
               left: 200, top: 270,
               fontSize: 12, fill: "black",
               textAlign: "center", originX: "center"
            });
            
            ret.y_label = new fabric.Text("Guess Value", {
               left: 30, top: 150,
               fontSize: 12, fill: "black",
               textAlign: "center", originX: "center", angle: -90
            });
            
            // Grid lines
            for (let i = 0; i <= 6; i++) {
               ret["x_grid" + i] = new fabric.Line([50 + i * 50, 50, 50 + i * 50, 250], {
                  stroke: "lightgray", strokeWidth: 0.5, opacity: 0.7
               });
            }
            
            for (let i = 0; i <= 8; i++) {
               ret["y_grid" + i] = new fabric.Line([50, 50 + i * 25, 350, 50 + i * 25], {
                  stroke: "lightgray", strokeWidth: 0.5, opacity: 0.7
               });
            }
            
            // Target line (will be updated dynamically)
            ret.target_line = new fabric.Line([50, 150, 350, 150], {
               stroke: "red", strokeWidth: 2, strokeDashArray: [5, 5]
            });
            
            // Target label
            ret.target_label = new fabric.Text("Target", {
               left: 360, top: 150,
               fontSize: 10, fill: "red", fontWeight: "bold",
               originY: "center"
            });
            
            // Data points (up to 7 iterations: initial + 6 iterations)
            for (let i = 0; i <= 6; i++) {
               ret["point" + i] = new fabric.Circle({
                  left: 50 + i * 50, top: 150, radius: 4,
                  fill: "blue", stroke: "darkblue", strokeWidth: 2,
                  visible: false, originX: "center", originY: "center"
               });
               
               ret["value" + i] = new fabric.Text("0", {
                  left: 50 + i * 50, top: 130,
                  fontSize: 8, fill: "blue", fontWeight: "bold",
                  textAlign: "center", originX: "center", visible: false
               });
               
               // Connect lines between points
               if (i > 0) {
                  ret["line" + (i-1) + "to" + i] = new fabric.Line([50 + (i-1) * 50, 150, 50 + i * 50, 150], {
                     stroke: "blue", strokeWidth: 2, visible: false
                  });
               }
            }
            
            // Current time indicator (arrow at bottom)
            ret.time_arrow = new fabric.Polygon([
               {x: 50, y: 260},      // Bottom point
               {x: 45, y: 270},      // Left point
               {x: 55, y: 270}       // Right point
            ], {
               fill: "orange", stroke: "darkorange", strokeWidth: 2
            });
            
            // Current calculation status
            ret.calc_status = new fabric.Text("Ready", {
               left: 200, top: 300,
               fontSize: 12, fill: "gray",
               textAlign: "center", originX: "center"
            });
            
            // Y-axis scale labels (will be updated dynamically)
            for (let i = 0; i <= 4; i++) {
               ret["y_scale" + i] = new fabric.Text("0", {
                  left: 40, top: 250 - i * 50,
                  fontSize: 8, fill: "black",
                  textAlign: "right", originX: "right", originY: "center"
               });
            }
            
            // Legend
            ret.legend_bg = new fabric.Rect({
               left: 20, top: 320, width: 360, height: 60,
               fill: "lightblue", stroke: "blue", strokeWidth: 1, rx: 5
            });
            
            ret.legend_title = new fabric.Text("Legend:", {
               left: 30, top: 330,
               fontSize: 10, fontWeight: "bold", fill: "darkblue"
            });
            
            ret.legend_target = new fabric.Line([30, 345, 50, 345], {
               stroke: "red", strokeWidth: 2, strokeDashArray: [3, 3]
            });
            
            ret.legend_target_text = new fabric.Text("Target Value (√(a²+b²))", {
               left: 55, top: 342,
               fontSize: 9, fill: "black"
            });
            
            ret.legend_guess = new fabric.Circle({
               left: 30, top: 360, radius: 3,
               fill: "blue", stroke: "darkblue", strokeWidth: 1,
               originX: "center", originY: "center"
            });
            
            ret.legend_guess_text = new fabric.Text("Newton-Raphson Guesses", {
               left: 40, top: 357,
               fontSize: 9, fill: "black"
            });
            
            ret.legend_line = new fabric.Line([200, 345, 220, 345], {
               stroke: "blue", strokeWidth: 2
            });
            
            ret.legend_line_text = new fabric.Text("Convergence Path", {
               left: 225, top: 342,
               fontSize: 9, fill: "black"
            });
            
            return ret;
         },
         
         render() {
            // Only show convergence data when actively calculating or just finished
            let calculating = this.sigVal("dut.active").asBool();
            let valid = this.sigVal("valid").asBool();
            let state = this.sigVal("dut.state").asInt();
            
            if (!calculating && !valid && state == 0) {
               // Hide all data points when idle
               for (let i = 0; i <= 6; i++) {
                  this.getObjects()["point" + i].set("visible", false);
                  this.getObjects()["value" + i].set("visible", false);
                  if (i > 0) {
                     this.getObjects()["line" + (i-1) + "to" + i].set("visible", false);
                  }
               }
               this.getObjects().calc_status.set({text: "Ready", fill: "gray"});
               return;
            }
            
            // Get the target value (a² + b²)
            let a_val = this.sigVal("a").asInt();
            let b_val = this.sigVal("b").asInt();
            let target = Math.sqrt(a_val * a_val + b_val * b_val);
            
            // Update target line position (scale target to fit in graph)
            let max_display = 20; // Maximum value to display
            let target_scaled = Math.min(target, max_display);
            let target_y = 250 - (target_scaled / max_display) * 200;
            
            this.getObjects().target_line.set({
               y1: target_y, y2: target_y
            });
            
            this.getObjects().target_label.set({
               top: target_y,
               text: `Target: ${target.toFixed(1)}`
            });
            
            // Use SignalValueSet to collect iteration history
            let sig_obj = {
               guess: this.sigVal("dut.iter_guess"),
               iteration: this.sigVal("dut.iter_iteration"), 
               active: this.sigVal("dut.active"),
               state: this.sigVal("dut.state")
            };
            
            let sigs = this.signalSet(sig_obj);
            
            // Find the start of calculation (when we enter iteration state)
            sigs.backToValue(sigs.sig("state"), 3); // Find STAGE2_ITERATE state
            
            let iteration_data = [];
            let max_iterations = 6;
            
            // Step through and collect iteration data
            for (let i = 0; i <= max_iterations; i++) {
               if (sigs.sig("state").asInt() == 3) { // STAGE2_ITERATE
                  let guess_val = sigs.sig("guess").asInt();
                  iteration_data.push({
                     iteration: i,
                     guess: guess_val,
                     valid: true
                  });
               } else {
                  break;
               }
               
               if (!sigs.step(1)) break; // Step to next cycle
            }
            
            // Display the collected data
            let max_guess = Math.max(...iteration_data.map(d => d.guess), target);
            max_guess = Math.min(max_guess, max_display);
            
            // Update Y-axis scale labels (simple fixed scale)
            for (let i = 0; i <= 4; i++) {
               let scale_value = (max_display * i / 4);
               this.getObjects()["y_scale" + i].set({
                  text: scale_value.toFixed(0)
               });
            }
            
            for (let i = 0; i <= 6; i++) {
               if (i < iteration_data.length && iteration_data[i].valid) {
                  let guess = iteration_data[i].guess;
                  let y_pos = 250 - Math.min(guess / max_display, 1.0) * 200;
                  
                  // Show point
                  this.getObjects()["point" + i].set({
                     top: y_pos,
                     visible: true,
                     fill: (i == iteration_data.length - 1 && valid) ? "green" : "blue"
                  });
                  
                  // Show value
                  this.getObjects()["value" + i].set({
                     top: y_pos - 20,
                     text: guess.toString(),
                     visible: true,
                     fill: (i == iteration_data.length - 1 && valid) ? "green" : "blue"
                  });
                  
                  // Show connecting line
                  if (i > 0 && (i-1) < iteration_data.length && iteration_data[i-1].valid) {
                     let prev_guess = iteration_data[i-1].guess;
                     let prev_y = 250 - Math.min(prev_guess / max_display, 1.0) * 200;
                     this.getObjects()["line" + (i-1) + "to" + i].set({
                        x1: 50 + (i-1) * 50, y1: prev_y,
                        x2: 50 + i * 50, y2: y_pos,
                        visible: true,
                        stroke: valid && (i == iteration_data.length - 1) ? "green" : "blue"
                     });
                  }
               } else {
                  // Hide unused points
                  this.getObjects()["point" + i].set("visible", false);
                  this.getObjects()["value" + i].set("visible", false);
                  if (i > 0) {
                     this.getObjects()["line" + (i-1) + "to" + i].set("visible", false);
                  }
               }
            }
            
            // Update status
            if (calculating) {
               this.getObjects().calc_status.set({
                  text: `Iterating... (${iteration_data.length} steps)`,
                  fill: "orange"
               });
            } else if (valid) {
               let final_error = Math.abs(iteration_data[iteration_data.length - 1].guess - target);
               this.getObjects().calc_status.set({
                  text: `Converged! Error: ${final_error.toFixed(2)}`,
                  fill: "green"
               });
            }
         }
\SV
   endmodule