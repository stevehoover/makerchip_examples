\m4_TLV_version 1d: tl-x.org
\SV
   // A state machine for a 3-floor elevator controller.
   // Elevator can travel one story each cycle, stopping at each floor (whether necessary or not).

   // This controller is written three ways:
   //   1) in SystemVerilog, in a big always_ff block
   //   2) directly translated to TL-Verilog
   //   3) cleanly rewritten in TL-Verilog with a single assignment for each signal
   //   4) (and the generated Verilog could be considered a fourth style)
   //
   //   Sequential style: 1) SV -> 2) TLV
   //                        |         |
   //   Parallel style:   4) SV <- 3) TLV

   // Observations:
   //  o Using a nested if-else structure is not better or worse than individual assignments
   //    in terms of code size. With nested if-else, signals are repeated multiple times.
   //    With individual assignments, cases are repeated multiple times.
   //  o TL-Verilog is optimized for individual assignment statements
   //     - allowing signal declarations to be incorporated into assignments
   //     - providing many atomic re-timable statements.
   //  o The style chosen for TL-Verilog is less specific to 3 floors, with more logic replicated
   //    per floor, where Verilog logic is coded uniquely per-floor.
   //  o Coding time was about the same for Verilog and TL-Verilog, but, for what it's
   //    worth, I had two bugs of any significance in my Verilog and none in TL-Verilog.
   //  o Even though no simplicity benefit is claimed for TL-Verilog for state machines, the code
   //    is about half the size.

   m4_makerchip_module
   /* verilator lint_on WIDTH */

   // ==========
   // Version 1) SystemVerilog by hand.
   // ==========

   // Inputs:
   logic [2:0] up_pressed, down_pressed;  // Elevator up/down button input on each floor. 1 == pressed.
   logic [2:0] elevator_button_pressed;  // The floor buttons/lights in the elevator. 1 == pressed.

   logic [2:0] floor_mask;  // Floor the elevator is on (1-hot decoded).
   logic [1:0] up_light; logic [2:1] down_light;   // Elevator up/down button lights on each floor. 1 == lit. Cleared after departure.
   logic [2:0] elevator_light;  // The floor lights in the elevator. 1 == lit. Cleared on arrival.
   logic went_up, went_down; // 1 if the elevator just went this direction to reach its current floor.

   logic called_top, called_bottom;  // 1 if there's a reason to go up/down.
   always_comb begin
      // For decisions from floor 1:
      called_top = elevator_light[2] || down_light[2] || up_light[1];
      called_bottom = elevator_light[0] || up_light[0] || down_light[1];
   end
   always_ff @(posedge clk) begin
      // Random input:
      // Note that we do not keep track of who is in the elevator, and elevator buttons
      // can be pressed at any time, whether there is a passenger or not.
      // All button presses are given 1/8 probability, here.
      {up_pressed, down_pressed, elevator_button_pressed} <=
           9'b011110111 &  // Mask non-existant buttons.
           RW_rand_raw[26:18] & RW_rand_raw[17:9] & RW_rand_raw[8:0];  // random w/ 1/8 probability.
      
      // State machine, to update:
      //   o floor
      //   o up/down_light
      //   o went_up/down
      
      // Stay, until we decide otherwise.
      //went_up <= 1'b0;
      went_down <= 1'b0;
      
      // Update state for elevator button presses.
      for (int fl = 0; fl < 3; fl++) begin
         if (elevator_button_pressed[fl]) elevator_light[fl] <= '1;
            // Note that if button is pressed for our new floor, the light is not lit.
      end
      // Note that we cannot have been called to the floor we are on.
      if (reset) begin
         floor_mask <= 3'b001;
         up_light <= 2'b00;
         down_light <= 2'b00;
         elevator_light <= 3'b000;
      end else if (floor_mask[0]) begin
         // From floor 0
         if (| {up_light[1:0], down_light[2:1], elevator_light[2:1]}) begin
            // Go up.
            //went_up <= '1;
            floor_mask <= 3'b010;
            up_light[0] <= '0;
            elevator_light[1] <= '0;
         end else begin
            // Stay.
            elevator_light[0] <= '0;
         end
      end else if (floor_mask[2]) begin
         // From floor 2
         if (| {down_light[2:1], up_light[1:0], elevator_light[1:0]}) begin
            // Go down.
            went_down <= '1;
            floor_mask <= 3'b010;
            down_light[2] <= '0;
            elevator_light[1] <= '0;
         end else begin
            // Stay.
            elevator_light[2] <= '0;
         end
      end else begin
         // From floor 1
         if (called_top && (!went_down || !called_bottom)) begin
            // Go up (gets priority over down when no momentum).
            //went_up <= '1;
            floor_mask <= 3'b100;
            up_light[1] <= '0;
            elevator_light[2] <= '0;
         end else if (called_bottom && (went_down || !called_top)) begin
            // Go down.
            went_down <= '1;
            floor_mask <= 3'b001;
            down_light[1] <= '0;
            elevator_light[0] <= '0;
         end else begin
            // Stay.
            elevator_light[1] <= '0;
         end
      end
         
      // Update state for floor button presses.
      for (int fl = 0; fl < 3; fl++) begin
         if (up_pressed[fl]) up_light[fl] <= '1;
         if (down_pressed[fl]) down_light[fl] <= '1;
      end
   end

\TLV
!  $reset = *reset;
   
   // -------------------------
   // Random stimulus.
   // Use values from Verilog model.
   |ctrl
      @0
         /floor[2:0]
            // Elevator up/down button input on each floor. 1 == pressed.
            $up_pressed = *up_pressed[floor];   // BUG: [#floor] doesn't work.
            $down_pressed = *down_pressed[floor];
            // The floor buttons/lights in the elevator. 1 == pressed.
            $elevator_button_pressed = *elevator_button_pressed[floor];
   // -------------------------
   
   // ==========
   // Version 2) Direct translation to TL-Verilog.
   // ==========
   
   /version2
      |ctrl
         @0
            // Random input:
            // Note that we do not keep track of who is in the elevator, and elevator buttons
            // can be pressed at any time, whether there is a passenger or not.
            // All button presses are given 1/8 probability, here.
            {$up_pressed[2:0], $down_pressed[2:0], $elevator_button_pressed[2:0]} =
                 {/top|ctrl/floor[*]$up_pressed, /top|ctrl/floor[*]$down_pressed, /top|ctrl/floor[*]$elevator_button_pressed};
            
            $reset = /top|ctrl$reset;
            
            // For decisions from floor 1:
            $called_top = $elevator_light[2] || $down_light[2] || $up_light[1];
            $called_bottom = $elevator_light[0] || $up_light[0] || $down_light[1];

            \always_comb
               // State machine, to update:
               //   o floor
               //   o up/down_light
               //   o went_up/down
               
               // Stay, until we decide otherwise.
               // 1 if the elevator will have just gone this direction to reach its current floor.
               //$$next_went_up = 1'b0;
               $$next_went_down = 1'b0;
               
               // Update state for elevator button presses.
               for (int fl = 0; fl < 3; fl++) begin
                  if ($elevator_button_pressed[fl]) $next_elevator_light[fl] = '1;
                     // Note that if button is pressed for our new floor, the light is not lit.
               end
               // Note that we cannot have been called to the floor we are on.
               if ($reset) begin
                  $$next_floor_mask[2:0] = 3'b001;     // Next value of: The floor the elevator is on (1-hot decoded).
                  $$next_up_light[1:0] = 2'b00;        // Next value of: Elevator up/down button lights on each floor. 1 == lit. Cleared after departure.
                  $$next_down_light[2:1] = 2'b00;      // Next value of: The floor lights in the elevator. 1 == lit. Cleared on arrival.
                  $$next_elevator_light[2:0] = 3'b000; // Next value of: The floor lights in the elevator. 1 == lit. Cleared on arrival.
               end else if ($floor_mask[0]) begin
                  // From floor 0
                  if (| {$up_light[1:0], $down_light[2:1], $elevator_light[2:1]}) begin
                     // Go up.
                     //$next_went_up = '1;
                     $next_floor_mask = 3'b010;
                     $next_up_light[0] = '0;
                     $next_elevator_light[1] = '0;
                  end else begin
                     // Stay.
                     $next_elevator_light[0] = '0;
                  end
               end else if ($floor_mask[2]) begin
                  // From floor 2
                  if (| {$down_light[2:1], $up_light[1:0], $elevator_light[1:0]}) begin
                     // Go down.
                     $next_went_down = '1;
                     $next_floor_mask = 3'b010;
                     $next_down_light[2] = '0;
                     $next_elevator_light[1] = '0;
                  end else begin
                     // Stay.
                     $next_elevator_light[2] = '0;
                  end
               end else begin
                  // From floor 1
                  if ($called_top && (!$went_down || !$called_bottom)) begin
                     // Go up (gets priority over down when no momentum).
                     //$next_went_up = '1;
                     $next_floor_mask = 3'b100;
                     $next_up_light[1] = '0;
                     $next_elevator_light[2] = '0;
                  end else if ($called_bottom && ($went_down || !$called_top)) begin
                     // Go down.
                     $next_went_down = '1;
                     $next_floor_mask = 3'b001;
                     $next_down_light[1] = '0;
                     $next_elevator_light[0] = '0;
                  end else begin
                     // Stay.
                     $next_elevator_light[1] = '0;
                  end 
               end
               
               // Update state for floor button presses.
               for (int fl = 0; fl < 3; fl++) begin
                  if ($up_pressed[fl]) $next_up_light[fl] = '1;
                  if ($down_pressed[fl]) $next_down_light[fl] = '1;
               end
            $went_down = >>1$next_went_down;
            //$went_up = >>1$next_went_up;
            $floor_mask[2:0] = >>1$next_floor_mask;
            $up_light[1:0] = >>1$next_up_light;
            $down_light[2:1] = >>1$next_down_light;
            $elevator_light[2:0] = >>1$next_elevator_light;

   
   // ==========
   // Version 3) Hand-coded TL-Verilog.
   // ==========
   
   // DUT
   // Macros to compute floor above/below with wrap (because some Verilog compilers complain about out-of-bounds accesses).
   // Note that for m4_above ($1 + 2) % 3 is ($1 - 1) % 3, but with positive modulo math.
   m4_define(['m4_below'], (($1 + 2) % 3))
   m4_define(['m4_above'], (($1 + 1) % 3))
   |ctrl
      @0
         $reset = /top<>0$reset;
         $next_floor[1:0] = $reset   ? 2'b0 :
                            $go_up   ? $Floor + 2'b1 :
                            $go_down ? $Floor - 2'b1 :
                                       $RETAIN;
         $Floor[1:0] <= $next_floor;  // WORKAROUND: <<1$Floor can't be used, currently, so $next_floor created as temporary.
         /floor[*]
            // Clear elevator light on arrival at next floor, or set it after pressed.
            $ElevatorLight <= |ctrl$reset ? 1'b0 :
                              |ctrl$next_floor == #floor ? 1'b0 :
                              $ElevatorLight || $elevator_button_pressed;
            // Set up   light on this floor when pressed, and clear when leaving this floor upward.
            $UpLight   <= $up_pressed                                ? 1'b1 :
                          ((|ctrl$Floor == #floor) && |ctrl$go_up)   ? 1'b0 :
                                                                       $RETAIN;
            // Set down light on this floor when pressed, and clear when leaving this floor downward.
            $DownLight <= $down_pressed                              ? 1'b1 :
                          ((|ctrl$Floor == #floor) && |ctrl$go_down) ? 1'b0 :
                                                                       $RETAIN;
            // Call elevator to this floor when requested within elevator or at floor.
            $called = $ElevatorLight || $DownLight || $UpLight;
            // $called_above/below if $called above/below or up/down button is lit on this floor.
            $called_above = $UpLight   || ((#floor == 2) ? 1'b0 : /floor[m4_above(#floor)]$called || /floor[m4_above(#floor)]$called_above);
            $called_below = $DownLight || ((#floor == 0) ? 1'b0 : /floor[m4_below(#floor)]$called || /floor[m4_below(#floor)]$called_below);
         // Go up or down if called that way, breaking tie based on momentum and then prioritizing up.
         $go_up   = ((! >>1$go_down || ! /floor[$Floor]$called_below) && /floor[$Floor]$called_above);
         $go_down = ((  >>1$go_down || ! /floor[$Floor]$called_above) && /floor[$Floor]$called_below);

         
         // Compare all three models.
         $Error <= $reset ? 1'b0 : !((*floor_mask == /top/version2|ctrl$floor_mask) && ((3'b1 << $Floor) == /top/version2|ctrl$floor_mask)) || $Error;
         *failed = (*cyc_cnt > 400) &&   $Error;
         *passed = (*cyc_cnt > 400) && ! $Error;
\SV
   endmodule
