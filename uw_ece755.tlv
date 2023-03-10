\m4_TLV_version 1d: tl-x.org
\SV
   m4_makerchip_module
\TLV
   $reset = *reset;

   |node
      @1
         // Capture input on rise of $in_ready.
         $capture = ! /top<>0$reset && |node$in_ready && ! |node>>1$in_ready;
         /in[3:0]
            $value[4:0] = |node$capture ? $random[4:0] : $RETAIN;
         /hidden[3:0]
            /in
               /weight[3:0]
                  $value[4:0] = |node$capture ? $random[4:0] : $RETAIN;
            
            $neuron[10:0] = \$signed(|node/in[0]$value[4:0]) * \$signed(|node/hidden[0]/in/weight[#hidden]$value[4:0]) +
                            \$signed(|node/in[1]$value[4:0]) * \$signed(|node/hidden[1]/in/weight[#hidden]$value[4:0]) +
                            \$signed(|node/in[2]$value[4:0]) * \$signed(|node/hidden[2]/in/weight[#hidden]$value[4:0]) +
                            \$signed(|node/in[3]$value[4:0]) * \$signed(|node/hidden[3]/in/weight[#hidden]$value[4:0]);
            $relu[9:0] = $neuron[10] ? '0 : $neuron[9:0];
         /out[1:0]
            /in
               /weight[3:0]
                  $value[4:0] = |node$capture ? $random[4:0] : $RETAIN;
            $out[16:0] = |node/hidden[0]$relu * \$signed(/in/weight[0]$value[4:0]) +
                         |node/hidden[1]$relu * \$signed(/in/weight[1]$value[4:0]) +
                         |node/hidden[2]$relu * \$signed(/in/weight[2]$value[4:0]) +
                         |node/hidden[3]$relu * \$signed(/in/weight[3]$value[4:0]);
         $out0_ready = ! $reset && ($capture || >>1$out0_ready);
         $out1_ready = ! $reset && ($capture || >>1$out1_ready);
         
         // VIZ
         /viz_img
            \viz_js
               box: {strokeWidth: 0},
               init() {
                  debugger
                  return {img: this.newImageFromURL("https://raw.githubusercontent.com/stevehoover/makerchip_examples/master/viz_imgs/gnn.png", "",
                     { left: 0,
                       top: 0,
                       width: 200,
                       height: 120,
                     })}
               },
               where: {left: -60},
         
         /in[*]
            \viz_js
               layout: "vertical",
               box: {top: -20, left: -20, width: 80, height: 40, strokeWidth: 0},
               render() {
                  debugger
                  let $value = '$value'.asInt()
                  let sign = $value >> 4
                  let val = ($value << 4) & 255
                  let red = sign ? 255 - val : 0
                  let green = sign ? 0 : val
                  
                  return [
                     new fabric.Circle({radius: 10, left: -20, top: -10, fill: `rgb(${red}, ${green}, 0)`}),
                  ]
               },
               where: {top: 120},
         /hidden[*]
            \viz_js
               layout: "vertical",
               box: {top: -20, left: -20, width: 80, height: 40, strokeWidth: 0},
               render() {
                  let relu = '$relu'.asInt() >> 2
                  
                  return [
                     new fabric.Circle({radius: 10, left:  40, top: -10, fill: `rgb(0, ${relu}, 0)`}),
                  ]
               },
               where: {top: 120},
            /in
               /weight[*]
                  \viz_js
                     box: {strokeWidth: 0},
                     layout: {top: 0, left: 0},
                     render() {
                        debugger
                        let $value = '$value'.asInt()
                        let sign = $value >> 4
                        let val = ($value << 4) & 255
                        let red = sign ? 255 - val : 0
                        let green = sign ? 0 : val
                        return [new fabric.Line([0, 0, 40, (this.getIndex() - this.getIndex("hidden")) * 40],
                                                {stroke: `rgb(${red}, ${green}, 0)`, strokeWidth: 3})
                               ]
                     },
         /out[*]
            \viz_js
               layout: "vertical",
               box: {left: 0, top: -20, width: 20, height: 40, strokeWidth: 0},
               render() {
                  let $out = '$out'.asInt()
                  let sign = $out >> 16
                  let val = ($out >> 8) & 255
                  let red = sign ? 255 - val : 0
                  let green = sign ? 0 : val
                  return [new fabric.Circle({radius: 10, left: 0, top: -10, fill: `rgb(${red}, ${green}, 0)`})]
               },
               where: {left: 100, top: 160}
            /in
               /weight[*]
                  \viz_js
                     box: {strokeWidth: 0},
                     layout: {top: 0, left: 0},
                     render() {
                        debugger
                        let $value = '$value'.asInt()
                        let sign = $value >> 4
                        let val = ($value << 4) & 255
                        let red = sign ? 255 - val : 0
                        let green = sign ? 0 : val
                        return [new fabric.Line([-40, (this.getIndex() - this.getIndex("out") - 1) * 40, 0, 0],
                                                {stroke: `rgb(${red}, ${green}, 0)`, strokeWidth: 3})
                               ]
                     },
                     
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
\SV
   endmodule