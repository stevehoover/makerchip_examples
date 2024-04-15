\m5_TLV_version 1d: tl-x.org
\SV
   module top(input wire clk, input wire reset, input wire [31:0] cyc_cnt, output wire passed, output wire failed);

\TLV
   
   $inv = ! $in;
   
   $and = $in1 && $in2;
   
   $sum[3:0] = $num1[2:0] + $num2[2:0];
   
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;

\SV
   endmodule
