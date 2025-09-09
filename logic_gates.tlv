\m5_TLV_version 1d: tl-x.org


// A logic gate in its own scope with its own \viz_js, now with truth table.
\TLV gate(/_top, /_gate, _label, #_x, #_y, _not, _op, _url)
   /_gate
      $out = _not(/_top$in_a _op /_top$in_b);
      \viz_js
         box: {width: 200, height: 120, strokeWidth: 0},
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
            ret.in_a = new fabric.Text("", {
               left: 0, top: 24,
               fontSize: 14, fontFamily: "Courier New",
            })
            ret.in_b = new fabric.Text("", {
               left: 0, top: 40,
               fontSize: 14, fontFamily: "Courier New",
            })
            ret.out = new fabric.Text("", {
               left: 90, top: 32,
               fontSize: 14, fontFamily: "Courier New",
            })
            
            // Truth Table (10% smaller)
            ret.table_title = new fabric.Text("Truth Table", {
               left: 143, top: 0,
               originX: "center",
               fontSize: 10, fontFamily: "Courier New",
               fontWeight: "bold"
            })
            
            // Table headers
            ret.header_a = new fabric.Text("A", {
               left: 120, top: 13,
               fontSize: 9, fontFamily: "Courier New",
               fontWeight: "bold"
            })
            ret.header_b = new fabric.Text("B", {
               left: 135, top: 13,
               fontSize: 9, fontFamily: "Courier New",
               fontWeight: "bold"
            })
            ret.header_out = new fabric.Text("Out", {
               left: 152, top: 13,
               fontSize: 9, fontFamily: "Courier New",
               fontWeight: "bold"
            })
            
            // Truth table cells - 4 rows for each combination
            for (let i = 0; i < 4; i++) {
               let row_y = 25 + i * 13
               
               // Background cells for highlighting (no border)
               ret["cell" + i] = new fabric.Rect({
                  left: 118, top: row_y - 2,
                  width: 55, height: 11,
                  fill: "transparent",
                  stroke: "transparent",
                  strokeWidth: 0
               })
               
               // Text values
               let a_val = (i >> 1) & 1
               let b_val = i & 1
               let out_val
               
               // Calculate output based on gate type
               if ("_label" === "AND") out_val = a_val && b_val ? 1 : 0
               else if ("_label" === "NAND") out_val = !(a_val && b_val) ? 1 : 0
               else if ("_label" === "OR") out_val = a_val || b_val ? 1 : 0
               else if ("_label" === "NOR") out_val = !(a_val || b_val) ? 1 : 0
               else if ("_label" === "XOR") out_val = a_val ^ b_val ? 1 : 0
               else if ("_label" === "XNOR") out_val = !(a_val ^ b_val) ? 1 : 0
               else out_val = 0
               
               ret["cell_text" + i + "_a"] = new fabric.Text(a_val.toString(), {
                  left: 123, top: row_y,
                  fontSize: 9, fontFamily: "Courier New"
               })
               ret["cell_text" + i + "_b"] = new fabric.Text(b_val.toString(), {
                  left: 138, top: row_y,
                  fontSize: 9, fontFamily: "Courier New"
               })
               ret["cell_text" + i + "_out"] = new fabric.Text(out_val.toString(), {
                  left: 158, top: row_y,
                  fontSize: 9, fontFamily: "Courier New"
               })
            }
            
            return ret
         },
         render() {
            let objs = this.obj
            objs.in_a.set({text: '/_top$in_a'.asInt().toString()})
            objs.in_b.set({text: '/_top$in_b'.asInt().toString()})
            objs.out.set({text: '$out'.asInt().toString()})
            
            // Highlight the active row in truth table
            let in_a_val = '/_top$in_a'.asBool()
            let in_b_val = '/_top$in_b'.asBool()
            let active_row = (in_a_val ? 2 : 0) + (in_b_val ? 1 : 0)
            
            // Reset all cell backgrounds
            for (let i = 0; i < 4; i++) {
               objs["cell" + i].set({
                  fill: i === active_row ? "#ffeb3b" : "transparent"
               })
               
               // Set text colors - highlight active row
               let textColor = i === active_row ? "#d84315" : "#333333"
               let fontWeight = i === active_row ? "bold" : "normal"
               
               objs["cell_text" + i + "_a"].set({fill: textColor, fontWeight: fontWeight})
               objs["cell_text" + i + "_b"].set({fill: textColor, fontWeight: fontWeight})
               objs["cell_text" + i + "_out"].set({fill: textColor, fontWeight: fontWeight})
            }
            
            return []
         },
         where: {left: #_x * 220, top: #_y * 140}


\TLV gates(/_top, _where)
   /_top
      \viz_js
         where: {_where}
      |example
         @0
            m5+gate(|example, /and,  AND,  0, 0,  , &&, ['https:/']['/upload.wikimedia.org/wikipedia/commons/6/64/AND_ANSI.svg'])
            m5+gate(|example, /nand, NAND, 1, 0, ~, &&, ['https:/']['/upload.wikimedia.org/wikipedia/commons/f/f2/NAND_ANSI.svg'])
            m5+gate(|example, /or,   OR,   0, 1,  , ||, ['https:/']['/upload.wikimedia.org/wikipedia/commons/b/b5/OR_ANSI.svg'])
            m5+gate(|example, /nor,  NOR,  1, 1, ~, ||, ['https:/']['/upload.wikimedia.org/wikipedia/commons/6/6c/NOR_ANSI.svg'])
            m5+gate(|example, /xor,  XOR,  0, 2,  , ^,  ['https:/']['/upload.wikimedia.org/wikipedia/commons/0/01/XOR_ANSI.svg'])
            m5+gate(|example, /xnor, XNOR, 1, 2, ~, ^,  ['https:/']['/upload.wikimedia.org/wikipedia/commons/d/d6/XNOR_ANSI.svg'])

            // reset signal from instantiation of m4_makerchip_module above
            $reset = *reset;

            // Two inputs, starting from 00 after reset
            $cnt[1:0] = $reset ? 2'b11 : >>1$cnt + 1;
            $in_a = $cnt[1];
            $in_b = $cnt[0];


            // Visualization context for logic gates
            \viz_js
               // JavaScript code
               box: {strokeWidth: 0, left: -40, top: -75, width: 500, height: 480, fill: "#fcf5ee"},
               init() {
                  return {
                     title: new fabric.Text("Digital Logic Gates with Truth Tables", {
                        left: 210, top: -50,
                        originX: "center",
                        fontSize: 20, fontFamily: "Courier New",
                     })
                  }
               },

\SV
   m5_makerchip_module
\TLV
   m5+gates(/gates, ['left: -200, top: -200'])   
         
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;      // Simulation ends after 40 cycles
   *failed = 1'b0;
         
\SV
   endmodule      // close the module