\m4_TLV_version 1d: tl-x.org
\SV
m4_makerchip_module

\TLV
   /yy[29:0]
      /xx[29:0]
         $row_cnt[1:0] = {1'b0, (/xx[xx - 1]>>1$alive && (xx > 0))} +
                         {1'b0, >>1$alive} +
                         {1'b0, (/xx[xx + 1]>>1$alive && (xx < 29))};
         $cnt[3:0] = {2'b00, (/yy[yy - 1]/xx$row_cnt & {2{(yy > 0)}})} +
                     {2'b00, $row_cnt[1:0]} +
                     {2'b00, (/yy[yy + 1]/xx$row_cnt & {2{(yy < 29)}})};
         $alive = *reset ? $init_alive :                   // init
                  >>1$alive ? ($cnt >= 3 && $cnt <= 4) :   // stay alive
                              ($cnt == 3);                 // born
         \viz_js
            box: {width: 10, height: 10},
            renderFill() {
               return ('$alive'.asBool()) ? "#10D080" : "#204030"
            },
   *passed = *cyc_cnt > 40;
\SV
endmodule