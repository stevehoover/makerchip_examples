\m5_TLV_version 1d -p verilog --bestsv --noline: tl-x.org
\m5
   use(m5-1.0)
\SV
   m4_include_lib(['https://raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/84c6a4374e8457ed69e61d66efad4486efa87102/tlv_lib/fpga_includes.tlv'])                   
   m5_lab()


// === Your FPGA logic here ===
// FPGA logic can drive the signals declared by m5+lab(), above, as seen in the NAV-TLV tab.
// Not all boards utilize all signals.
// For example:
\TLV fpga(/_fpga)
   *led[15:0] = *cyc_cnt[15:0];
   *sseg_digit_n[7:0] = 8'b1 << *cyc_cnt[2:0];
   *sseg_segment_n[6:0] = 7'b1 << *cyc_cnt[2:0];
   *sseg_decimal_point_n = *cyc_cnt[2:0] == 3'b111;
   //------------------------------------------
   m5_var(examples, ['https://raw.githubusercontent.com/stevehoover/makerchip_examples/dd76634a47549fe7c0aa43faa678859785c6987b'])
   m4_include_lib(m5_examples/frog_maze.tlv)
   m4_include_lib(m5_examples/ring_viz.tlv)
   m4_include_lib(m5_examples/life_viz.tlv)
   m4_include_lib(m5_examples/logic_gates.tlv)
   m4_include_lib(m5_examples/mandelbrot_as_img.tlv)
   m4_include_lib(m5_examples/smith_waterman.tlv)
   m4_include_lib(m5_examples/sort_viz.tlv)
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v/d0bb31c8037bb82c8f47d7c733908ebd9373d10b/warp-v.tlv'])
   \viz_js
      box: {strokeWidth: 0, height: 300, width: 300}
   m5+gates(/gates, ['left:30, top:20, width:70, height:70'])
   m5+life(/life1, ['left:220, top:10, width:25, height:25'])
   m5+life(/life2, ['left:250, top:10, width:25, height:25'])
   m5+ring_example(/ring, ['left:210, top:210, width:80, height:80, justifyX: "center"'])
   m5+frog_maze(/frog_maze, ['left:220, top:40, width:60, height:60'])
   m5+smith_waterman_example(/sw_example, ['left:110, top:10, width:90, height:90'])
   m5+mandelbrot(/mandelbrot, $, ['left:20, top:120, width:120, height:80, justifyX: "center"'])
   m5+sort_example(/sort, ['left:170, top:120, width:110, height:70'])
   m5_var(NUM_CORES, 1)
   /warpv
      \viz_js
         box: {strokeWidth: 0},
         where: {left: 20, top: 210, width: 180, height: 80, justifyX: "center", justifyY: "center"}
      m5+cpu(/warpv)
      m5+cpu_viz(|fetch, "transparent")
   
// Board logic
\TLV
   /board
      /// m5+board args:
      ///   - parent hierarchy identifier
      ///   - identifier for FPGA hierarchy
      ///   - board selection (3rd arg of m4+board(..)):
      ///      0 - 1st CLaaS on AWS F1
      ///      1 - Zedboard
      ///      2 - Artix-7
      ///      3 - Basys3
      ///      4 - Icebreaker
      ///      5 - Nexys
      ///      6 - CLEAR
      ///   - where properties for board
      ///   - macro name of FPGA logic
      m5+board(/board,
               /fpga,
               3,
               *,
               ,
               fpga)
      /fpga_pins
         /fpga
            `BOGUS_USE(/frog_maze|pipe/frog>>1$done /life1|default/tb>>2$passed /life2|default/tb>>2$passed /mandelbrot|pipe>>1$failed /mandelbrot|pipe>>1$passed /ring/tb|pass>>1$passed)
   *passed = *cyc_cnt > 74;
\SV
   endmodule
