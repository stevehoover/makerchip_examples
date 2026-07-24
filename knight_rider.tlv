\m4_TLV_version 1d -p verilog --bestsv --noline: tl-x.org
\SV
   // Knight Rider "KITT" scanner, built on the latest Virtual FPGA Lab in
   // resources/ (os-fpga commit 3760a43). A single LED sweeps back and forth
   // across the LED bank, bouncing off each end like the front scanner of KITT.
   m4_include_lib(['https://raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/3760a43f58573fbcf7b7893f13c8fa01da6260fc/tlv_lib/fpga_includes.tlv'])

// Top-level module declaration and pin signal declarations.
m4+lab()


\TLV fpga(/_fpga)

   // ===== Knight Rider scanner =====
   |scan
      @0
         // Heartbeat: advance one step per pulse.
         // Fast in simulation, artificially slowed on a real FPGA so the
         // sweep is visible to the human eye (~4 steps/sec @ 50MHz).
         m4+fpga_heartbeat($step, 1, 12500000)
         $reset = *reset;
         ?$step
            // $Dir: 0 = sweeping up (toward LED 15), 1 = sweeping down.
            // Reverse direction when we reach either end.
            $Dir <= $reset                       ? 1'b0 :
                    (($Pos == 4'd15) && ! $Dir)  ? 1'b1 :   // hit the top, head down
                    (($Pos == 4'd0)  &&   $Dir)  ? 1'b0 :   // hit the bottom, head up
                                                   $Dir;
            // $Pos: index of the lit LED, 0..15. Step toward the (possibly new) direction.
            $Pos[3:0] <= $reset                      ? 4'd0 :
                         (($Pos == 4'd15) && ! $Dir) ? $Pos - 4'd1 :   // bounce off the top
                         (($Pos == 4'd0)  &&   $Dir) ? $Pos + 4'd1 :   // bounce off the bottom
                         $Dir                        ? $Pos - 4'd1 :
                                                       $Pos + 4'd1;
         // Light only the LED at the current position.
         *led[15:0] = 16'b1 << $Pos;
   // ================================


// The workbench: instantiate the board.
// Board selection (3rd arg):
//   0 - 1st CLaaS on AWS F1   1 - Zedboard   2 - Artix-7   3 - Basys3
//   4 - Icebreaker            5 - Nexys      6 - CLEAR
\TLV
   /board
      m4+board(/board, /fpga, 3, *, , fpga)
\SV
   endmodule
