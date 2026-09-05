\m5_TLV_version 1d: tl-x.org
\m5

\SV
   m5_makerchip_module
\TLV
   // Pi approximation using the Leibniz series:
   //   pi = 4 * sum_{k=0..N-1} ((-1)^k / (2k+1))
   // Values are maintained in Q16 fixed-point format.

   /top
      |calc
         @1
            $k[15:0] = *reset ? 0 : >>1$k + 1;

            $k_prev[15:0] = >>1$k;
            $den[31:0] = ($k_prev << 1) + 1;
            $term_q16[31:0] = 32'd262144 / $den;

            $acc_q16[47:0] =
               *reset ? 0 :
               ($k_prev[0] ? >>1$acc_q16 - $term_q16 : >>1$acc_q16 + $term_q16);

            $pi_x1000[31:0] = ($acc_q16 * 1000) >> 16;
            $err_x1e6[31:0] = ($pi_x1000 > 3141) ? ($pi_x1000 - 3141) * 1000 : (3141 - $pi_x1000) * 1000;

      \viz_js
         box: {left: -230, top: -140, width: 600, height: 360, fill: "#f6f4ef", stroke: "#c9c2b5", strokeWidth: 2},
         init() {
            let obj = {
               title: new fabric.Text("Pi via Leibniz Series (Hardware)", {
                  left: -220, top: -124, fontSize: 24, fontFamily: "Georgia", fill: "#2f2a24"
               }),
               formula: new fabric.Text("pi = 4 * sum((-1)^k / (2k+1))", {
                  left: -220, top: -92, fontSize: 16, fontFamily: "Georgia", fill: "#574d42"
               }),
               iter: new fabric.Text("", {
                  left: -220, top: -56, fontSize: 18, fontFamily: "Courier New", fill: "#1f1b17"
               }),
               pi_text: new fabric.Text("", {
                  left: -220, top: -28, fontSize: 22, fontFamily: "Courier New", fill: "#1f1b17"
               }),
               err_text: new fabric.Text("", {
                  left: -220, top: 6, fontSize: 18, fontFamily: "Courier New", fill: "#7a2e1f"
               }),
               axis: new fabric.Line([-220, 120, 330, 120], {stroke: "#9f9688", strokeWidth: 1}),
               pi_ref: new fabric.Line([-220, 40, 330, 40], {stroke: "#3a7d44", strokeWidth: 1, strokeDashArray: [6, 4]}),
               pi_ref_text: new fabric.Text("math pi", {
                  left: 336, top: 32, fontSize: 12, fontFamily: "Courier New", fill: "#3a7d44"
               })
            }

            for (let i = 0; i < 64; i++) {
               obj["bar" + i] = new fabric.Rect({
                  left: -220 + i * 8,
                  top: 120,
                  width: 6,
                  height: 1,
                  fill: "#2f6f8f",
                  strokeWidth: 0
               })
            }

            return obj
         },
         render() {
            let piMilli = '/top|calc>>1$pi_x1000'.asInt(0)
            let iter = '/top|calc>>1$k'.asInt(0)
            let err1e6 = '/top|calc>>1$err_x1e6'.asInt(0)

            let pi = piMilli / 1000.0
            this.obj.iter.set({text: `iterations: ${iter}`})
            this.obj.pi_text.set({text: `pi estimate: ${pi.toFixed(6)}`})
            this.obj.err_text.set({text: `abs error: ${(err1e6 / 1000000.0).toFixed(6)}`})

            let $hist = '/top|calc>>1$pi_x1000'
            for (let i = 0; i < 64; i++) {
               let p = $hist.asInt(3141) / 1000.0
               let y = 40 - (p - Math.PI) * 1400
               let h = 120 - y
               if (h < 1) h = 1
               if (h > 220) h = 220
               this.obj["bar" + (63 - i)].set({top: 120 - h, height: h})
               $hist.step(-1)
            }
         },
         where: {left: 0, top: 0, width: 10, height: 10}

   *passed = *cyc_cnt > 500;
   *failed = 1'b0;

\SV
   endmodule
