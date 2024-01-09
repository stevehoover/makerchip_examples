\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
   m4_include_lib(['https://raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/9216ec3ddb2ead1a2b2eee93c334927b500af330/tlv_lib/fpga_includes.tlv'])
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/MEST_Course/53d95456e5d2f2e4bf6edb9d8f15d09f8c8c2151/tlv_lib/calculator_shell_lib.tlv'])
   
// An 8-bit calculator.
\TLV fpga_calculator(/_fpga)
   |calc
      @0
         // Run artificially slow in the real FPGA. 
         //m5+fpga_heartbeat($refresh, 1, 50000000)
         $reset = *reset;
      @1
         // Board inputs
         $op[2:0] = *ui_in[7:5];
         $val2[7:0] = {3'b0, *ui_in[4:0]};
         
         $val1[7:0] = >>2$out;
         //$val2[7:0] = $rand2[3:0];
         $valid = $reset ? 1'b0 : >>1$valid + 1'b1;
         $reset_or_valid = $valid || $reset;
      ?$reset_or_valid
         @1
            $sum[7:0] = $val1 + $val2;
            $diff[7:0] = $val1 - $val2;
            $prod[7:0] = $val1 * $val2;
            $quot[7:0] = $val1 / $val2;
         @2
            $mem[7:0] = $reset               ? 8'b0 :
                        ($op[2:0] == 3'b101) ? $val1 :
                                               >>2$mem;
            $out[7:0] = $reset          ? 8'b0 :
                        ($op == 3'b000) ? $sum  :
                        ($op == 3'b001) ? $diff :
                        ($op == 3'b010) ? $prod :
                        ($op == 3'b011) ? $quot :
                        ($op == 3'b100) ? >>2$mem : >>2$out;
      @2
         m5+sseg_decoder($uo_out, $out[3:0])
   \SV_plus
      m5_if_defined_as(MAKERCHIP, 1, ['logic [256:0] RW_rand_vect = tt_um_calculator.RW_rand_vect;'])
      m5_if_defined_as(MAKERCHIP, 1, ['logic [31:0] cyc_cnt = tt_um_calculator.cyc_cnt;'])
   m5_if_defined_as(MAKERCHIP, 1, ['m4+cal_viz(@2, /_fpga)'])


\SV

`default_nettype none

// A simple Makerchip Verilog test bench driving random stimulus.

// Comment out the Makerchip module if not using Makerchip. (Only because Yosys chokes on $urandom.)
m5_if_defined_as(MAKERCHIP, 1, [''], ['/']['*'])
module top(input wire clk, input wire reset, input wire [31:0] cyc_cnt, output wire passed, output wire failed);
   logic [7:0] ui_in, uio_in, uo_out, uio_out, uio_oe;
   logic [31:0] r;
   always @(posedge clk) r = $urandom();
   assign ui_in = r[7:0];
   assign uio_in = r[15:8];
   logic ena = 1'b0;
   logic rst_n = ! reset;
   
   // Instantiate the Tiny Tapeout module.
   tt_um_calculator tt(.*);
   
   assign passed = cyc_cnt > 100;
   assign failed = 1'b0;
endmodule
// End comment block.
m5_if_defined_as(MAKERCHIP, 1, [''], ['*']['/'])

module tt_um_calculator (
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
   /* verilator lint_off WIDTHTRUNC */  // (Calculator library was built for a 32-bit calculator.)
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   m5+tt_connections()
   
   // Instantiate the Virtual FPGA Lab.
   m5+board(/top, /fpga, 7, $, , fpga_calculator)   // 3rd arg selects the board.
   
\SV_plus
   
   // Connect outputs.
   // Note that TL-Verilog fpga_logic will be under /fpga_pins/fpga.
   assign uo_out = {1'b1, /fpga_pins/fpga|calc>>2$uo_out};
   assign uio_out = 8'b0;
   assign uio_oe = 8'b0;

\SV
endmodule
