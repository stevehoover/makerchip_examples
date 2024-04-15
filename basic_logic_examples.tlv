\m5_TLV_version 1d: tl-x.org
\SV
   module top(input wire clk, input wire reset, input wire [31:0] cyc_cnt, output wire passed, output wire failed);

\TLV
   
   /inv
      $out = ! $in;
   
   /and
      $out = $in1 && $in2;
   
   /sum
      $out[3:0] = $in1[2:0] + $in2[2:0];
   
   /mux
      $out = $cond ? $case1 : $case0;
   
   /wide_mux
      $out[7:0] =
         $sel[0]
            ? $case0[7:0] :
         $sel[1]
            ? $case1[7:0] :
         //default
              $default[7:0];
   
   /consts
      $eight[7:0] = 16'd8;
      $five[4:0]  = 7'b101;
      $nine[31:0]  = 9;
      $ones[7:2]  = '1;
   
   /concat
      $digits[11:0] = {$digit2[3:0], 4'hf, $digit0[3:0]};
   /repl
      $value[11:0] = {3{$digit[3:0]}};
   /sign_extend_example
      $word[15:0] = {{8{$byte[7]}}, $byte[7:0]};
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

\SV
   endmodule
