\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
   m4_include_lib(['https://raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/93c5e2e1434a2840753087e6a2af2c4f310a89d7/tlv_lib/tiny_tapeout_lib.tlv'])

`default_nettype none

\TLV my_design()
   
   // Inspired by: https://tinytapeout.com/digital_design/design_padlock/
   // Requires 1 tile.
   
   // This lock is in locked or unlocked state.
   // It resets to unlocked state (so reset must be tamper-proof).
   // The lock can only be unlocked by applying the correct code.
   // The code may be set if unlocked.
   
   // Input Switches 0-7:
   //  7: Lock: 1 to lock the safe to the given code.
   //  6: Unlock: 1 to attempt to unlock the safe using the Code.
   //  5-0: Code 5-0: A six-bit code, either attempting to unlock the safe, or set the code.
   
   // The 7-segment output displays:
   //   o the six binary digits of the lock's code counterclockwise from bits 7 to 0 starting from the upper-right.
   //   o the decimal point indicates whether the lock is set

   // Input Switches:
   $lock = *ui_in[7];
   $unlock = *ui_in[6];
   $input_code[5:0] = *ui_in[5:0];
   
   // The lock logic.
   {$Locked, $LockCode[5:0]} <=
      *reset ? 7'b0 :
      (! $Locked && $lock) ? {1'b1, $input_code} :
      ($Locked && $unlock && $input_code == $LockCode) ? {1'b0, $LockCode} :
      {$Locked, $LockCode};
   
   // Output.
   *uo_out = ~{$Locked, 1'b0, $LockCode};
   
   // Visualization is redundant with 7-segment output.
   \viz_js
      init() {
         return {code: new fabric.Text("------", {fontFamily: "Courier New"})}
      },
      render() {
         debugger
         this.getObjects().code.set({text: '$LockCode'.asBinaryStr().padStart(6, "0")})
      },
      renderFill() {
         return '$Locked'.asBool() ? "red" : "green"
      }
\SV

// A simple Makerchip Verilog test bench driving random stimulus.

// Include the Makerchip module only in Makerchip. (Only because Yosys chokes on $urandom.)
m4_ifelse_block(m5_if_defined_as(MAKERCHIP, 1, 1, 0), 1, ['
module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed);
   // Tiny tapeout I/O signals.
   logic [7:0] ui_in, uio_in, uo_out, uio_out, uio_oe;
   
   // Test bench input signals that drive non-tb versions at the clock edge.
   // The test bench should drive these on the B-phase of the clock odd simulation steps.
   logic [7:0] tb_ui_in, tb_uio_in;
   always @(posedge clk) begin
      ui_in <= tb_ui_in;
      uio_in <= tb_uio_in;
   end
   
   // Drive inputs.
   
   logic ena = 1'b0;
   logic rst_n = ! reset;
   assign tb_uio_in = 8'b0;
   
   // Drive tb_ui_in.
   initial begin
      #1
         passed = 1'b0;
         failed = 1'b0;
         tb_ui_in = 8'b0_0_000000;
      // Set the code/lock the safe.
      #12
         tb_ui_in = 8'b1_0_100101;
      // Do nothing.
      #2
         tb_ui_in = 8'b0_0_000101;
      // Fail to unlock.
      #2
         tb_ui_in = 8'b0_1_000101;
      #2
         tb_ui_in = 8'b0_1_100100;
      // Unlock.
      #2
         tb_ui_in = 8'b0_1_100101;
      #4
         passed = 1'b1;  // (no checking; just pass)
   end

   
   // Instantiate the Tiny Tapeout module.
   tt_um_padlock tt(.*);
   
   
endmodule

'], ['

///// Instantiate the top-level of your design, which debounces input signals for my_design.
///m5_tt_top(tt_um_padlock)

'])

\SV
module tt_um_padlock (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

   wire reset = ! rst_n;
   

\TLV
   /* verilator lint_off UNOPTFLAT */
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   m5+tt_connections()
   
   // Instantiate the Virtual FPGA Lab.
   m5+board(/top, /fpga, 7, $, , my_design)   // 3rd arg selects the board.
   m5+tt_input_labels_viz(['"Code 0", "Code 1", "Code 2", "Code 3", "Code 4","Code 5", "Unlock", "Lock"'])
   
\SV_plus
   // =========================================
   // If you are using Verilog for your design,
   // your Verilog logic goes here.
   // =========================================
   
   // ...
   

   // Connect Tiny Tapeout outputs.
   // Note that my_design will be under /fpga_pins/fpga.
   //assign uo_out = 8'b0;
   assign uio_out = 8'b0;
   assign uio_oe = 8'b0;
   
endmodule
