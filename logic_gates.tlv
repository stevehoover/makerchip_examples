\m4_TLV_version 1d: tl-x.org


// A logic gate in its own scope with its own \viz_js.
\TLV gate(/_top, /_gate, _label, #_x, #_y, _not, _op, _url)
   /_gate
      $out = _not(/_top$in0 _op /_top$in1);
      \viz_js
         box: {width: 100, height: 60, strokeWidth: 0},
         init() {
            let ret = {}
            // Heading
            ret.heading = new fabric.Text("_label", {
               left: 47, top: 0,
               originX: "center",
               fontSize: 16, fontFamily: "Courier New",
            })
            // Image
            ret.img = this.newImageFromURL(['"_url"'], {left: 10, top: 20, width: 80})
            // IO Values
            IO = function (left, top) {
               return new fabric.Text("", {
                 left, top,
                 fontSize: 14, fontFamily: "Courier New",
               })
            }
            ret.in0 = IO(0, 24)
            ret.in1 = IO(0, 40)
            ret.out = IO(90, 32)
            return ret
         },
         render() {
            let objs = this.getObjects()
            objs.in0.set({text: '/_top$in0'.asBinaryStr()})
            objs.in1.set({text: '/_top$in1'.asBinaryStr()})
            objs.out.set({text: '$out'.asBinaryStr()})
            return []
         },
         where: {left: #_x * 120, top: #_y * 75}


\SV
   m4_makerchip_module
\TLV
   |example
      @0
         m4+gate(|example, /and,  AND,  0, 0,  , &&, ['https:/']['/upload.wikimedia.org/wikipedia/commons/6/64/AND_ANSI.svg'])
         m4+gate(|example, /nand, NAND, 1, 0, ~, &&, ['https:/']['/upload.wikimedia.org/wikipedia/commons/f/f2/NAND_ANSI.svg'])
         m4+gate(|example, /or,   OR,   0, 1,  , ||, ['https:/']['/upload.wikimedia.org/wikipedia/commons/b/b5/OR_ANSI.svg'])
         m4+gate(|example, /nor,  NOR,  1, 1, ~, ||, ['https:/']['/upload.wikimedia.org/wikipedia/commons/6/6c/NOR_ANSI.svg'])
         m4+gate(|example, /xor,  XOR,  0, 2,  , ^,  ['https:/']['/upload.wikimedia.org/wikipedia/commons/0/01/XOR_ANSI.svg'])
         m4+gate(|example, /xnor, XNOR, 1, 2, ~, ^,  ['https:/']['/upload.wikimedia.org/wikipedia/commons/d/d6/XNOR_ANSI.svg'])
         
         // reset signal from instantiation of m4_makerchip_module above
         $reset = *reset;
         
         // Two inputs, x1 and x2, used a counter to increment its value to obtain all input values
         $cnt[1:0] = $reset ? 0 : >>1$cnt + 1;
         $in1 = $cnt[1];
         $in0 = $cnt[0];
         
         
         // Assert these to end simulation (before Makerchip cycle limit).
         *passed = *cyc_cnt > 40;      // Simulation ends after 40 cycles
         *failed = 1'b0;
         
         
         // Visualization for logic gates
         \viz_js
            // JavaScript code
            box: {left: -40, top: -75, width: 300, height: 330, fill: "#fcf5ee"},
            init() {
               return {
                  title: new fabric.Text("Digital Logic Gates", {
                     left: 110, top: -50,
                     originX: "center",
                     fontSize: 20, fontFamily: "Courier New",
                  })
               }
            },
\SV
   endmodule      // close the module
