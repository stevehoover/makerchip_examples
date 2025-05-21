\m4_TLV_version 1d -p verilog --bestsv --noline: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/3760a43f58573fbcf7b7893f13c8fa01da6260fc/tlv_lib/fpga_includes.tlv'])                   
   m5_lab()


// === Your FPGA logic here ===
// FPGA logic can drive the signals declared by m4+lab(), above, as seen in the NAV-TLV tab.
// Not all boards utilize all signals.
// For example:
\TLV fpga(/_fpga)
   *led[15:0] = *cyc_cnt[15:0];
   *sseg_digit_n[7:0] = 8'b1 << *cyc_cnt[2:0];
   *sseg_segment_n[6:0] = 7'b1 << *cyc_cnt[2:0];
   *sseg_decimal_point_n = *cyc_cnt[2:0] == 3'b111;
   //------------------------------------------
   m4_def(examples, ['['https://raw.githubusercontent.com/stevehoover/makerchip_examples/009362c0160514f8858315b9b94970eaab5a2307']'])
   m4_include_lib(m4_examples/frog_maze.tlv)
   m4_include_lib(m4_examples/ring_viz.tlv)
   m4_include_lib(m4_examples/life_viz.tlv)
   m4_include_lib(m4_examples/logic_gates.tlv)
   m4_include_lib(m4_examples/mandelbrot_as_img.tlv)
   m4_include_lib(m4_examples/smith_waterman.tlv)
   m4_include_lib(m4_examples/sort_viz.tlv)
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v/bc6c485d12a26407c8000608bc9dd90748333d1d/warp-v.tlv'])
   \viz_js
      box: {strokeWidth: 0, height: 300, width: 300}
   m4+gates(/gates, ['left:30, top:20, width:70, height:70'])
   m4+life(/life1, ['left:220, top:10, width:25, height:25'])
   m4+life(/life2, ['left:250, top:10, width:25, height:25'])
   m4+ring_example(/ring, ['left:210, top:210, width:80, height:80, justifyX: "center"'])
   m4+frog_maze(/frog_maze, ['left:220, top:40, width:60, height:60'])
   m4+smith_waterman_example(/sw_example, ['left:110, top:10, width:90, height:90'])
   m4+mandelbrot(/mandelbrot, $, ['left:20, top:120, width:120, height:80, justifyX: "center"'])
   m4+sort_example(/sort, ['left:170, top:120, width:110, height:70'])
   m4_def(NUM_CORES, 1)
   /warpv
      \viz_js
         box: {strokeWidth: 0},
         where: {left: 20, top: 210, width: 180, height: 80, justifyX: "center", justifyY: "center"}
      m4+cpu(/warpv)
      m4+cpu_viz(|fetch, "transparent"/*"#404040c0"*/)


// Board logic
\TLV
   /board
      // m4+board args:
      //   - parent hierarchy identifier
      //   - identifier for FPGA hierarchy
      //   - board selection (3rd arg of m4+board(..)):
      //      0 - 1st CLaaS on AWS F1
      //      1 - Zedboard
      //      2 - Artix-7
      //      3 - Basys3
      //      4 - Icebreaker
      //      5 - Nexys
      //      6 - CLEAR
      //   - where properties for board
      //   - macro name of FPGA logic
      m4+board(/board,
               /fpga,
               3,
               *,
               ,
               fpga)
\SV
   endmodule
