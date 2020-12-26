\m4_TLV_version 1d --fmtFlatSignals --bestsv --noline: tl-x.org
\SV
   // For exporting the kernel, use --bestsv --noline, and cut debug sigs statements from _gen file.

   // ==========================
   // Mandelbrot Set Calculation
   // ==========================

   // To relax Verilator compiler checking:
   /* verilator lint_off UNOPTFLAT */
   /* verilator lint_on WIDTH */
   /* verilator lint_off REALCVT */  // !!! SandPiper DEBUGSIGS BUG.


   // M4_PE_CNT engines compute pixel depths (in reading order) for a given image.
   // Image width must be a multiple of M4_PE_CNT or things could break.
   // PEs start at the same time.
   // Each may finish at different times, but all wait for the last to complete.
   // For each pixel calculation for each PE, computation proceeds through:
   //   o an "init" cycle where values are initialized based on pixel parameters
   //   o any number of "calc" cycles
   //   o a "done" cycle ("done_pulse")
   //   o any number of "wait" cycles ("done" but not "done_pulse")
   //   o (repeat)
   // Kernel has one active frame at a time, from the acceptance of config data to the transmission of the last data out.



   // Parameters:

   // Number of replicated Processing Elements
   m4_define_hier(M4_PE, 16)

   m4_define(M4_MAX_DEPTH, 8)

   // Fixed numbers (sign, int, fraction)
	// Fixed values are < 8.0.
	// There are two bit widths, normal and extended:
	// 	- Extended is used for X and Y coordinates calculation to avoid
	//      the accumulation of the rounding error as pixel width is added
   m4_define(M4_FIXED_UNSIGNED_WIDTH, 32)

	// Extended precision
   m4_define(M4_FIXED_EXT_PRECISION, 10)
	m4_define(M4_FIXED_EXT_UNSIGNED_WIDTH, m4_eval(M4_FIXED_UNSIGNED_WIDTH + M4_FIXED_EXT_PRECISION))

	// Data width for the incoming configuration data
	m4_define_vector(M4_CONFIG_DATA, 512)

	// Interleaving computation cycles
	m4_define(M4_ITER, 1)

	// PE pipeline depth
	m4_define(M4_PIPE_DEPTH, 2)
   // Latency between last pixel calculation and first of next pixels.
   m4_define(M4_PIX_LATENCY, 4)
   // Min latency between last pixels of one frame and the first of the next.
   m4_define(M4_FRAME_LATENCY, 5)

   // Constants and computed values:
   // Bit indices for fixed numbers
	// 	- [X:0] = integer portion
	// 	- [-1:Y] = fractional portion

	m4_define(M4_FIXED_INT_WIDTH, 3)
   m4_define(M4_FIXED_SIGN_BIT, M4_FIXED_INT_WIDTH)

	// Fixed point definition
   m4_define(M4_FIXED_FRAC_WIDTH, m4_eval(M4_FIXED_UNSIGNED_WIDTH - M4_FIXED_INT_WIDTH))
   m4_define(M4_FIXED_RANGE, ['M4_FIXED_SIGN_BIT:-M4_FIXED_FRAC_WIDTH'])
   m4_define(M4_FIXED_UNSIGNED_RANGE, ['m4_eval(M4_FIXED_SIGN_BIT-1):-M4_FIXED_FRAC_WIDTH'])

   // Extended fixed point definitions
	m4_define(M4_FIXED_EXT_FRAC_WIDTH, m4_eval(M4_FIXED_EXT_UNSIGNED_WIDTH - M4_FIXED_INT_WIDTH))
	m4_define(M4_FIXED_EXT_RANGE, ['M4_FIXED_SIGN_BIT:m4_eval(-(M4_FIXED_FRAC_WIDTH + M4_FIXED_EXT_PRECISION))'])
	m4_define(M4_FIXED_EXT_UNSIGNED_RANGE, ['m4_eval(M4_FIXED_SIGN_BIT-1):-M4_FIXED_EXT_FRAC_WIDTH'])
	//m4_makerchip_module
   // Zero extend to given width.
   `define ZX(val, width) {{1'b0{width-$bits(val)}}, val}

	m4_makerchip_module
		logic s_tvalid;
		logic [M4_CONFIG_DATA_RANGE] s_tdata;
		logic m_tvalid;
		logic [M4_CONFIG_DATA_RANGE] m_tdata;

		assign s_tvalid = cyc_cnt == 10;
      m4_define(M4_IMG_SIZE_H, 32)
      m4_define(M4_IMG_SIZE_V, 32)
		assign s_tdata = {
         					64'b0,
         					64'd128,  // depth
         					64'd['']M4_IMG_SIZE_V,    // img v size
         					64'd['']M4_IMG_SIZE_H,    // img h size
                        2'b0, {7{1'b1}}, 1'b0, {2{1'b1}}, 52'b0,  // pix_size_y
         					2'b0, {7{1'b1}}, 1'b0, {2{1'b1}}, 52'b0,  // pix_size_x
         					{2{1'b1}}, 62'b0,  // y
         					{2{1'b1}}, 62'b0   // x
							  };
      logic long_reset;
      assign long_reset = cyc_cnt < 32'h8;

		mandelbrot_kernel dut (
         .clk(clk),
         .reset(long_reset),
         .in_ready(),  // Assumed not blocked.
         .in_avail(s_tvalid),
         .in_data(s_tdata),
         .out_ready(1'b1),  // Never block output.
         .out_avail(m_tvalid),
         .out_data(m_tdata)
      );
		// Assert these to end simulation (before Makerchip cycle limit).
      assign passed = !clk || dut.frame_done || cyc_cnt > 2000;
      assign failed = !clk || 1'b0;
   endmodule


   module mandelbrot_kernel #(
     parameter integer C_DATA_WIDTH = 512 // Data width of both input and output data
   )
   (
     input wire                       clk,
     input wire                       reset,

     output wire                      in_ready,
     input wire                       in_avail,
     input wire  [C_DATA_WIDTH-1:0]   in_data,

     input wire                       out_ready,
     output wire                      out_avail,
     output wire [C_DATA_WIDTH-1:0]   out_data

   );
   logic frame_done;  // Instrumentation-only. Used to end simulation.

   function logic [M4_FIXED_RANGE] fixed_mul (input logic [M4_FIXED_RANGE] v1, v2);
      logic [M4_FIXED_INT_WIDTH-1:0] drop_bits;
      logic [M4_FIXED_FRAC_WIDTH-1:0] insignificant_bits;
      {fixed_mul[M4_FIXED_SIGN_BIT], drop_bits, fixed_mul[M4_FIXED_UNSIGNED_RANGE], insignificant_bits} =
         {v1[M4_FIXED_SIGN_BIT] ^ v2[M4_FIXED_SIGN_BIT], ({{M4_FIXED_UNSIGNED_WIDTH{1'b0}}, v1[M4_FIXED_UNSIGNED_RANGE]} * {{M4_FIXED_UNSIGNED_WIDTH{1'b0}}, v2[M4_FIXED_UNSIGNED_RANGE]})};
   endfunction;

   function logic [M4_FIXED_RANGE] fixed_add (input logic [M4_FIXED_RANGE] v1, v2, input logic sub);
      logic [M4_FIXED_RANGE] binary_v2;
      binary_v2 = fixed_to_binary(v1) +
                  fixed_to_binary({v2[M4_FIXED_SIGN_BIT] ^ sub, v2[M4_FIXED_UNSIGNED_RANGE]});
      fixed_add = binary_to_fixed(binary_v2);
   endfunction;

   function logic [M4_FIXED_RANGE] fixed_to_binary (input logic [M4_FIXED_RANGE] f);
      fixed_to_binary =
         f[M4_FIXED_SIGN_BIT]
            ? // Flip non-sign bits and add one. (Adding one is insignificant, so we save hardware and don't do it.)
              {1'b1, ~f[M4_FIXED_UNSIGNED_RANGE] /* + {{M4_FIXED_UNSIGNED_WIDTH-1{1'b0}}, 1'b1} */}
            : f;
   endfunction;

   function logic [M4_FIXED_RANGE] binary_to_fixed (input logic [M4_FIXED_RANGE] b);
      // The conversion is symmetric.
      binary_to_fixed = fixed_to_binary(b);
   endfunction;

   function logic [M4_FIXED_RANGE] real_to_fixed (input logic [63:0] b);
      real_to_fixed = {b[63], {1'b1, b[51:53-M4_FIXED_UNSIGNED_WIDTH]} >> (-(b[62:52] - 1023) + M4_FIXED_INT_WIDTH - 1)};
   endfunction;

   function logic [M4_FIXED_EXT_RANGE] real_to_ext_fixed (input logic [63:0] b);
      real_to_ext_fixed = {b[63], {1'b1, b[51:53-M4_FIXED_EXT_UNSIGNED_WIDTH]} >> (-(b[62:52] - 1023) + M4_FIXED_INT_WIDTH - 1)};
   endfunction;

\TLV

   |pipe
      
      // SV<->TLV for incoming data interface.
      @-2
         $reset = *reset;
      @-1
         *in_ready = $in_ready;
         $in_avail = *in_avail;
         $in_data[C_DATA_WIDTH-1:0] = *in_data;
         
      
      @-1
         $in_ready = ! >>1$frame_active;  // One frame at a time. Must be a one-cycle loop.
         $valid_config_data_in = $in_avail && $in_ready;
         {$config_data_bogus[63:0],
          $config_max_depth[63:0],
          $config_img_size_y[63:0],
          $config_img_size_x[63:0],
          $config_data_pix_y[63:0],
          $config_data_pix_x[63:0],
          $config_data_min_y[63:0],
          $config_data_min_x[63:0]} = $in_data;

         `BOGUS_USE($config_data_bogus)
      @0
         // Pulse for first calc of a new frame.
         $start_frame = $valid_config_data_in;  // Note, can assert only once the hardware is idle.
         $frame_active = $reset ? 1'b0 :
                         $start_frame ? 1'b1 :
                         >>m4_eval(M4_FRAME_LATENCY)$done_frame ? 0'b0 :  // (Falling edge alignment is arbitrary to meet timing.)
                         $RETAIN;

         // The computation is interleaved across M4_ITER cycles/strings

         // Val holds the valid condition for the computation
         // $val = $reset ? 0 : $start_frame || >>M4_ITER$val;
         //
         // ViewBox (fly-through)
         //
         // The view, given by upper-left corner coords and pixel x & y size.
         // It is initialized by the input FIFO
         $min_x[M4_FIXED_RANGE] = $reset ? '0 : $valid_config_data_in ? real_to_fixed($config_data_min_x) : $RETAIN;
         $min_y[M4_FIXED_RANGE] = $reset ? '0 : $valid_config_data_in ? real_to_fixed($config_data_min_y) : $RETAIN;
         $pix_x[M4_FIXED_EXT_RANGE] = $reset ? '0 : $valid_config_data_in ? real_to_ext_fixed($config_data_pix_x) : $RETAIN;
         $pix_y[M4_FIXED_EXT_RANGE] = $reset ? '0 : $valid_config_data_in ? real_to_ext_fixed($config_data_pix_y) : $RETAIN;

         // The size of the image is dynamic
         $size_x[M4_FIXED_RANGE] = $reset ? '0 : $valid_config_data_in ? $config_img_size_x[31:0] : $RETAIN;
         $size_y[M4_FIXED_RANGE] = $reset ? '0 : $valid_config_data_in ? $config_img_size_y[31:0] : $RETAIN;

         $max_depth[31:0] = $reset ? '0 : $valid_config_data_in ? $config_max_depth[31:0] : $RETAIN;

         // Pulse for first valid calc cycle of new pixels.
         $init_pixels = $reset ? 1'b0 :
                                 ($start_frame || (>>M4_PIX_LATENCY$done_pixels && ! >>M4_PIX_LATENCY$done_frame));

      /M4_PE_HIER
         @0
            // Reset signal
            $reset = |pipe$reset;

            $init_pix = |pipe$init_pixels;
            
            // Assign next iteration values. Reset and last of frame resets values.
            $depth[15:0] =
               $reset       ? '0      :
               $init_pix    ? '0      :
                              >>M4_ITER$depth + 1;
            $pix_h[31:0] =
               $reset            ? #pe :
               |pipe$start_frame ? #pe :
               $init_pix         ? >>M4_ITER$last_h ? #pe :
                                                      >>M4_ITER$pix_h + M4_PE_CNT :
                                   >>M4_ITER$pix_h;
            $pix_v[31:0] =
               $reset                          ? '0 :
               ($init_pix && >>M4_ITER$last_h) ? >>M4_ITER$last_v ? '0 :
                                                                    >>M4_ITER$pix_v + 1 :
                                                 >>M4_ITER$pix_v;

         @1
            //
            // Screen render control
            //


            // Cycle over pixels (vertical (outermost) and horizontal) and depth (innermost).
            // When each wraps, increment the next.
            $last_h = $pix_h >= |pipe$size_x - M4_PE_CNT;  // TODO: If size_x is not a multiple of M4_PE_CNT, things will go awry!
            $last_v = $pix_v == |pipe$size_y - 1;

            //
            // Map pixels to x,y coords
            //


         @2
            // The coordinates of the pixel we are working on.
            // $xx = $init_pix ? $MinX + $PixX * $PixH : $RETAIN;  (in fixed-point)
            $xx_mul[M4_FIXED_EXT_UNSIGNED_RANGE] =
               (|pipe$pix_x[M4_FIXED_EXT_UNSIGNED_RANGE] * `ZX($pix_h, M4_FIXED_EXT_UNSIGNED_WIDTH));
            $xx[M4_FIXED_RANGE] =
               $init_pix ? fixed_add(|pipe$min_x[M4_FIXED_RANGE],
                                     {1'b0, $xx_mul[M4_FIXED_UNSIGNED_RANGE]},
                                     1'b0)
                         : >>M4_ITER$xx;
            // $yy = $init_pix ? $MinY + $PixY * $PixV : $RETAIN;  (in fixed-point)
            $yy_mul[M4_FIXED_EXT_UNSIGNED_RANGE] =
               (|pipe$pix_y[M4_FIXED_EXT_UNSIGNED_RANGE] * `ZX($pix_v, M4_FIXED_EXT_UNSIGNED_WIDTH));
            $yy[M4_FIXED_RANGE] =
               $init_pix ? fixed_add(|pipe$min_y[M4_FIXED_RANGE],
                                     {1'b0, $yy_mul[M4_FIXED_UNSIGNED_RANGE]},
                                     1'b0)
                         : >>M4_ITER$yy;

         @3
            //
            // Mandelbrot Calculation
            //
            // Mandelbrot algorithm:
            // a = 0.0
            // b = 0.0
            // depth = 0
            // for depth [0..max_depth] until diverged {  // one iteration per cycle
            //   a <= a*a - b*b + x
            //   b <= 2*a*b + y
            //   diverged = a*a + b*b >= 2.0*2.0
            // }
            $aa_sq[M4_FIXED_RANGE] = fixed_mul($aa, $aa);
            $bb_sq[M4_FIXED_RANGE] = fixed_mul($bb, $bb);
            $aa_sq_plus_bb_sq[M4_FIXED_RANGE] = fixed_add($aa_sq, $bb_sq, 1'b0);
            // Assert from $init_pix through $done_pix:
            $calc_valid = $reset             ? 1'b0 :
                          >>M4_ITER$init_pix ? 1'b1 :
                          >>M4_ITER$done_pix ? 1'b0 :
                                               >>M4_ITER$calc_valid;
            $done_pix =
                $reset ? 1'b0 :
                |pipe>>M4_ITER$out_valid ? 1'b0 :
                >>M4_ITER$done_pix       ? 1'b1 : // Hold value until sent (|pipe$out_valid). Must be a 1-iteration loop preventing back-to-back $out_valid.
                                           $calc_valid && (
                                              // a*a + b*b
                                              ({1'b0, $aa_sq_plus_bb_sq[M4_FIXED_UNSIGNED_RANGE]} >= real_to_fixed({1'b0, 1'b1, 9'b0, 1'b1, 52'b0})
                                              ) ||
                                              // This term catches some overflow cases w/ the multiply and allows fewer int bits to be used.
                                              // |a| >= 2.0 || |b| >= 2.0
                                              (|{$aa[M4_FIXED_SIGN_BIT-1:M4_FIXED_SIGN_BIT-M4_FIXED_INT_WIDTH+1],
                                                 $bb[M4_FIXED_SIGN_BIT-1:M4_FIXED_SIGN_BIT-M4_FIXED_INT_WIDTH+1]}
                                              ) ||
                                              ($depth == |pipe$max_depth)
                                           );
            //+$not_done = ! $done_pix;

            //?$not_done
            $aa_sq_minus_bb_sq[M4_FIXED_RANGE] = fixed_add($aa_sq, $bb_sq, 1'b1);
            <<M4_ITER$aa[M4_FIXED_RANGE] = $init_pix ? $xx : fixed_add($aa_sq_minus_bb_sq, $xx, 1'b0);
            $aa_times_bb[M4_FIXED_RANGE] = fixed_mul($aa, $bb);
            $aa_times_bb_times_2[M4_FIXED_RANGE] = {$aa_times_bb[M4_FIXED_SIGN_BIT], $aa_times_bb[M4_FIXED_UNSIGNED_RANGE] << 1};
            <<M4_ITER$bb[M4_FIXED_RANGE] = $init_pix ? $yy : fixed_add($aa_times_bb_times_2, $yy, 1'b0);

            $done_pix_pulse = $done_pix & ! >>M4_ITER$done_pix;
            $depth_out[7:0] = $done_pix_pulse ? $depth[7:0] : $RETAIN;
      @4
         $all_pix_done = $reset ? '0 : & /pe[*]$done_pix && *out_ready;
         //$all_pix_done_pulse = $all_pix_done & ! >>1$all_pix_done;
         $out_data[C_DATA_WIDTH-1:0] = /pe[*]$depth_out;
         $out_avail = $all_pix_done;
         $out_valid = $out_avail && $out_ready;
         $done_pixels = $out_valid;
         $done_frame = $done_pixels && /pe[*]$last_h & /pe[*]$last_v;
      
      // SV<->TLV for outgoing data interface.
      @4
         *out_data = $out_data;
         *out_avail = $out_avail;
         $out_ready = *out_ready;
      
      // Testbench control.
      @10
         *frame_done = $done_frame;
         
         
         
      // =============
      // VISUALIZATION
      // =============
      // TODO: Account for M4_ITER.
      
      // Viz parameters.
      m4_define(M4_VIZ_CELL_SIZE, 20)
      m4_define(M4_VIZ_FONT_SIZE, 10)
      m4_define(M4_VIZ_LINE_SIZE, 15)

      @4
         /M4_PE_HIER
            \viz_alpha
               initEach() {
                  let text = new fabric.Text("",
                     {  top: -M4_VIZ_LINE_SIZE * (M4_MAX_DEPTH + 1) * 4,
                        left: 600 * this.getScope("pe").index,
                        fontSize: M4_VIZ_FONT_SIZE,
                        fontFamily: "monospace"
                     });
                  return {objects: {text}};
               },
               
               renderEach() {
                  debugger;
                  // @param: sig {SignalValue}
                  // @param: decimalPlaces {int, undefined} The number of decimal places with which to represent the number, of undefined for no rounding.
                  let asFixed = function(sig, decimalPlaces) {
                     if (sig.inTrace()) {
                        let str = sig.asBinaryStr();
                        let sign = str.substr(0, 1) == "0" ? 1 : -1;
                        // TODO: This won't extend to high-precision calc.
                        let unsigned = parseInt(str.substr(1), 2) / Math.pow(2, M4_FIXED_FRAC_WIDTH);
                        let val = sign * unsigned;
                        if (decimalPlaces) {
                           val = val.toFixed(decimalPlaces);
                        }
                        return val;
                     } else {
                        return NaN;
                     }
                  }
                  
                  // Build pixel calculation.
                  let x = asFixed('$xx', 3);
                  let y = asFixed('$yy', 3);
                  let depthSig = '$depth';
                  let depthSigCyc = depthSig.getCycle();
                  
                  if (depthSig.asInt() != 0) {depthSig.backToValue(0);}
                  depthSig.step();
                  let delta = depthSig.getCycle() - depthSigCyc;
                  console.log(`delta: ${delta}`);
                  
                  /**/
                  // Iterate through calculation for this pixel, adding each step to calcStr.
                  // Back signals up to depth 0.
                  let aSig = '$aa'.step(delta);
                  let bSig = '$bb'.step(delta);
                  let aSq = '$aa_sq'.step(delta);
                  let bSq = '$bb_sq'.step(delta);
                  let aSqMinusBSq = '$aa_sq_minus_bb_sq'.step(delta);
                  let aSqPlusBSq = '$aa_sq_plus_bb_sq'.step(delta);
                  let aTimesB = '$aa_times_bb'.step(delta);
                  let aTimesBTimes2 = '$aa_times_bb_times_2'.step(delta);
                  let doneSig = '$done_pix'.step(delta);
                  // Display first iteration
                  let d = 0; // Depth being displayed
                  let str = `${doneSig.getCycle()}\n-------- 0 --------\n`;
                  
                  let depthStr = (depthSigCyc == depthSig.getCycle() - 1) ? "| " : "  ";
                  str += `${depthStr} $xx[${x}] => $aa[${asFixed(aSig, 3)}]\n`;
                  str += `${depthStr} $yy[${y}] => $bb[${asFixed(bSig, 3)}]\n`;
                  let done = false;
                  do {
                     done = doneSig.asBool(true);
                     // Display calculation at this depth.
                     str += `${doneSig.getCycle()}\n-------- ${++d} --------\n`;
                     console.log(`dc: ${depthSigCyc}, ${depthSig.getCycle()}`);
                     depthStr = `${(depthSigCyc == depthSig.getCycle()) ? "| " : "  "}`;
                     let str1 = `${depthStr}(($aa[${asFixed(aSig, 3)}] ^ 2)[${asFixed(aSq, 3)}] - ($bb[${asFixed(bSig, 3)}] ^ 2)[${asFixed(bSq,3)}]])[${asFixed(aSqMinusBSq, 3)}] + $xx[${x}]`;
                     let str2 = `${depthStr}(2.0 * ($aa[${asFixed(aSig, 3)}] * $bb[${asFixed(bSig, 3)}])[${asFixed(aTimesB)}])[${asFixed(aTimesBTimes2)}] + $yy[${y}]`;
                     let str3 = `${depthStr}(($aa[${asFixed(aSig, 3)}] ^ 2)[${asFixed(aSq,3)}] + ($bb[${asFixed(bSig, 3)}] ^ 2)[${asFixed(bSq,3)}])[${asFixed(aSqPlusBSq,3)}] >= (2.0 * 2.0) = $done_pix[${done}]\n`;
                     aSig.step();
                     bSig.step();
                     aSq.step();
                     bSq.step();
                     aSqMinusBSq.step();
                     aSqPlusBSq.step();
                     aTimesB.step();
                     aTimesBTimes2.step();
                     doneSig.step();
                     console.log(`AAA: ${depthSig.getCycle()}`);
                     depthSig.step();
                     console.log(`BBB: ${depthSig.getCycle()}`);
                     str1 += ` => $aa[${asFixed(aSig, 3)}]\n`;
                     str2 += ` => $bb[${asFixed(bSig, 3)}]\n`;
                     str += str1 + str2 + str3;
                  } while(!done && d <= M4_MAX_DEPTH);
                  
                  this.getInitObjects().text.setText(str);
               }
         \viz_alpha
            initEach() {
               //this.getCanvas().add(text);
               let circle = new fabric.Circle({
                  originX: "center",
                  left: 0,
                  originY: "center",
                  top: 0,
                  radius: M4_VIZ_CELL_SIZE / 2 * 1.5,
                  stroke: "red",
                  strokeWidth: M4_VIZ_CELL_SIZE / 10,
                  fill: "rgba(128,128,128,0)"
               });
               //this.getCanvas().add(circle);
               
               // 2D Map
               return {objects: {circle}, start_frame_cyc: -1, done_frame_cyc: -1};
            },
            
            renderEach() {
               // Call this inside loops to avoid infinite recursion hangs.
               loopCheck = function() {
                  cnt = 0;
                  return function() {
                     if (cnt++ > 1000000) {
                        debugger;
                     }
                  }
               }();
               
               
               // Calculate the screen.
               // This is a static view reflecting the entire simulation,
               // so we create it once, and never again.
               if (this.cyc < this.fromInit().start_frame_cyc ||
                   this.cyc > this.fromInit().done_frame_cyc) {
                  
                  let screen = new VizPane.Grid(this.getCanvas(), M4_IMG_SIZE_H, M4_IMG_SIZE_V,
                       {top: 0, left: 0,
                        width: M4_VIZ_CELL_SIZE * (M4_IMG_SIZE_H),
                        height: M4_VIZ_CELL_SIZE * (M4_IMG_SIZE_V)});
                  
                  // Step back to start of frame.
                  let $start_frame = '$start_frame';
                  let start_frame_natural_cyc = $start_frame.getCycle();
                  let delta_cyc = 0;
                  let $reset = '$reset';
                  while (! $reset.asBool(true) && ! $start_frame.asBool()) {
                     loopCheck();
                     $start_frame.step(-1);
                     $reset.step(-1);
                     delta_cyc--;
                  }
                  
                  // Remember start (to avoid recreating image).
                  this.fromInit().start_frame_cyc = $start_frame.getCycle();
                  
                  if ($reset.asBool(true)) {
                     // Be sure to recreate next time.
                     this.fromInit().done_frame_cyc = $start_frame.getCycle() - 1;
                  } else {
                     // Step forward to end of frame/trace.
                     //-let cyc = $start_frame.getCycle();
                     let $done_frame = '$done_frame'.step(delta_cyc);
                     let $all_pix_done = '$all_pix_done'.step(delta_cyc);
                     let done_frame = true;
                     do {   // until done frame
                        loopCheck();
                        // Find all_pix_done cyc.
                        while (! $all_pix_done.asBool(true)) {
                           loopCheck();
                           $done_frame.step(1);
                           $all_pix_done.step(1);
                           delta_cyc++;
                        }
                        done_frame = $done_frame.asBool(true);
                        
                        if ($all_pix_done.asBool(false)) {
                           // Done all pixels; draw pixels.
                           for (let p = M4_PE_LOW; p < M4_PE_HIGH; p++) {
                              let depth = '/pe[p]$depth_out'.step(delta_cyc).asInt();
                              let pix_h = '/pe[p]$pix_h'.step(delta_cyc).asInt();
                              let pix_v = '/pe[p]$pix_v'.step(delta_cyc).asInt();
                              
                              // Determine color.
                              let color = "#";
                              if (depth <= 0) {
                                 color = "#000000";
                              } else {
                                 let componentString = function(frac) {
                                    return (Math.floor(frac * 256) % 256).toString(16).padStart(2, "0");
                                 };
                                 let r = "00";
                                 let g = "00";
                                 let b = componentString(depth / 8);
                                 color = `#${r}${g}${b}`;
                              }
                              
                              // Check color
                              if (! /^#[0-9a-f]{6}$/i.test(color)) {
                                debugger;
                              }
                              
                              screen.setCellColor(pix_h, pix_v, color);
                              console.log(`setCellColor(${pix_h}, ${pix_v}, ${color}`);
                           }
                        }
                        
                        $done_frame.step(1);
                        $all_pix_done.step(1);
                        delta_cyc++; // step past all pix done
                     } while (! done_frame);
                     
                     // Avoid recreating
                     this.fromInit().done_frame_cyc = start_frame_natural_cyc + delta_cyc;
                  }
                  
                  // Add screen to canvas.
                  let screenImg = screen.getFabricObject();
                  this.getCanvas().add(screenImg);
               }
               
               // Position circle
               let circle = this.getInitObjects().circle;
               this.getCanvas().bringToFront(circle);
               circle.set("left", ('/pe[0]$pix_h'.asInt() + 0.5) * M4_VIZ_CELL_SIZE);
               circle.set("top",  ('/pe[0]$pix_v'.asInt() + 0.5) * M4_VIZ_CELL_SIZE);
            }


\SV
   endmodule
