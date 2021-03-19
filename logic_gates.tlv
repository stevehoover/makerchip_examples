\m4_TLV_version 1d: tl-x.org
\SV

   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
   /* verilator lint_on WIDTH */

// Visualization for logic gates
\TLV calc_logic()
   /view
      \viz_alpha
         initEach(){
            let title = new fabric.Text("Digital Logic Gates", {
              left: -200,
              top: -250,
              fontSize: 28,
              fontFamily: "Courier New",
            })
             
            let and = new fabric.Text("AND", {
              left: -130,
              top: -170,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let or = new fabric.Text("OR", {
              left: 80,
              top: -170,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let nand = new fabric.Text("NAND", {
              left: -130,
              top: -20,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let nor = new fabric.Text("NOR", {
              left: 70,
              top: -20,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let xor = new fabric.Text("XOR", {
              left: -130,
              top: 130,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let xnor = new fabric.Text("XNOR", {
              left: 70,
              top: 130,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let block_square = new fabric.Rect(
                     {originX: "center",
                      originY: "center",
                      width: 500,
                      height: 550,
                      fill: "#fcf5ee" //`#00a000`
                     }
                  )
            let block_circle = new fabric.Circle(
                     {originX: "center",
                      originY: "center",
                      radius: 10,
                      fill: "lightgrey" //`#00a000`
                     }
                  )
                  // Image is not supposed to be added to canvas until it is drawn, but we need an Object to
                  // work with immediately, so let's wrap the image in a group.
            let logic_block = new fabric.Group([block_square],
                     {originX: "center",
                      originY: "center",
                      angle: 0,
                      width: 20,
                      height: 20,
                     })
            let and_img_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/64/AND_ANSI.svg/150px-AND_ANSI.svg.png"
            let and_img = new fabric.Image.fromURL(
                     and_img_url,
                     function (img) {
                        logic_block.add(img)
                        global.canvas.renderAll()
                     },
                     {originX: "center",
                      originY: "center",
                      left: -100,
                      top: -100,
                      scaleX: 0.8,
                      scaleY: 0.8,
                      angle: 0,
                     }
                  )
            let or_img_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/b/b5/OR_ANSI.svg/150px-OR_ANSI.svg.png"
            let or_img = new fabric.Image.fromURL(
                     or_img_url,
                     function (img) {
                        logic_block.add(img)
                        global.canvas.renderAll()
                     },
                     {originX: "center",
                      originY: "center",
                      left: 100,
                      top: -100,
                      scaleX: 0.8,
                      scaleY: 0.8,
                      angle: 0,
                     }
                  )
            let nand_img_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/f/f2/NAND_ANSI.svg/150px-NAND_ANSI.svg.png"
            let nand_img = new fabric.Image.fromURL(
                     nand_img_url,
                     function (img) {
                        logic_block.add(img)
                        global.canvas.renderAll()
                     },
                     {originX: "center",
                      originY: "center",
                      left: -100,
                      top: 50,
                      scaleX: 0.8,
                      scaleY: 0.8,
                      angle: 0,
                     }
                  )
            let nor_img_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6c/NOR_ANSI.svg/150px-NOR_ANSI.svg.png"
            let nor_img = new fabric.Image.fromURL(
                     nor_img_url,
                     function (img) {
                        logic_block.add(img)
                        global.canvas.renderAll()
                     },
                     {originX: "center",
                      originY: "center",
                      left: 100,
                      top: 50,
                      scaleX: 0.8,
                      scaleY: 0.8,
                      angle: 0,
                     }
                  )
            let xor_img_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/0/01/XOR_ANSI.svg/150px-XOR_ANSI.svg.png"
            let xor_img = new fabric.Image.fromURL(
                     xor_img_url,
                     function (img) {
                        logic_block.add(img)
                        global.canvas.renderAll()
                     },
                     {originX: "center",
                      originY: "center",
                      left: -100,
                      top: 200,
                      scaleX: 0.8,
                      scaleY: 0.8,
                      angle: 0,
                     }
                  )
            let xnor_img_url = "https://upload.wikimedia.org/wikipedia/commons/thumb/d/d6/XNOR_ANSI.svg/150px-XNOR_ANSI.svg.png"
            let xnor_img = new fabric.Image.fromURL(
                     xnor_img_url,
                     function (img) {
                        logic_block.add(img)
                        global.canvas.renderAll()
                     },
                     {originX: "center",
                      originY: "center",
                      left: 100,
                      top: 200,
                      scaleX: 0.8,
                      scaleY: 0.8,
                      angle: 0,
                     }
                  )
            let and_x1 = new fabric.Text("", {
              left: -180,
              top: -130,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let and_x0 = new fabric.Text("", {
              left: -180,
              top: -100,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let and_output = new fabric.Text("", {
              left: -40,
              top: -120,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let or_x1 = new fabric.Text("", {
              left: 20,
              top: -130,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let or_x0 = new fabric.Text("", {
              left: 20,
              top: -100,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let or_output = new fabric.Text("", {
              left: 160,
              top: -120,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let nand_x1 = new fabric.Text("", {
              left: -180,
              top: 20,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let nand_x0 = new fabric.Text("", {
              left: -180,
              top: 50,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let nand_output = new fabric.Text("", {
              left: -40,
              top: 35,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let nor_x1 = new fabric.Text("", {
              left: 20,
              top: 20,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let nor_x0 = new fabric.Text("", {
              left: 20,
              top: 50,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let nor_output = new fabric.Text("", {
              left: 160,
              top: 35,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let xor_x1 = new fabric.Text("", {
              left: -180,
              top: 170,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let xor_x0 = new fabric.Text("", {
              left: -180,
              top: 200,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let xor_output = new fabric.Text("", {
              left: -40,
              top: 185,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let xnor_x1 = new fabric.Text("", {
              left: 20,
              top: 170,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let xnor_x0 = new fabric.Text("", {
              left: 20,
              top: 200,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            let xnor_output = new fabric.Text("", {
              left: 160,
              top: 185,
              fontSize: 28,
              fontFamily: "Courier New",
            })
            return {
                    objects: {
                              logic_block, title, and_x0, and_x1, and_output, or_x0, or_x1, or_output, nand_x0, nand_x1, nand_output, nor_x0, nor_x1, nor_output, xor_x0, xor_x1, xor_output, xnor_x0, xnor_x1, xnor_output, and, or, nand, nor, xor, xnor
                              }};
                  },
                  renderEach() {
                     debugger
            this.getInitObject("and_x0").setText(this.svSigRef(`L0_x0_a0`).asInt(NaN).toString(16))
            this.getInitObject("and_x1").setText(this.svSigRef(`L0_x1_a0`).asInt(NaN).toString(16))
            this.getInitObject("and_output").setText(this.svSigRef(`L0_and_a0`).asInt(NaN).toString(16))
            this.getInitObject("or_x0").setText(this.svSigRef(`L0_x0_a0`).asInt(NaN).toString(16))
            this.getInitObject("or_x1").setText(this.svSigRef(`L0_x1_a0`).asInt(NaN).toString(16))
            this.getInitObject("or_output").setText(this.svSigRef(`L0_or_a0`).asInt(NaN).toString(16))
            this.getInitObject("nand_x0").setText(this.svSigRef(`L0_x0_a0`).asInt(NaN).toString(16))
            this.getInitObject("nand_x1").setText(this.svSigRef(`L0_x1_a0`).asInt(NaN).toString(16))
            this.getInitObject("nand_output").setText(this.svSigRef(`L0_nand_a0`).asInt(NaN).toString(16))
            this.getInitObject("nor_x0").setText(this.svSigRef(`L0_x0_a0`).asInt(NaN).toString(16))
            this.getInitObject("nor_x1").setText(this.svSigRef(`L0_x1_a0`).asInt(NaN).toString(16))
            this.getInitObject("nor_output").setText(this.svSigRef(`L0_nor_a0`).asInt(NaN).toString(16))
            this.getInitObject("xor_x0").setText(this.svSigRef(`L0_x0_a0`).asInt(NaN).toString(16))
            this.getInitObject("xor_x1").setText(this.svSigRef(`L0_x1_a0`).asInt(NaN).toString(16))
            this.getInitObject("xor_output").setText(this.svSigRef(`L0_xor_a0`).asInt(NaN).toString(16))
            this.getInitObject("xnor_x0").setText(this.svSigRef(`L0_x0_a0`).asInt(NaN).toString(16))
            this.getInitObject("xnor_x1").setText(this.svSigRef(`L0_x1_a0`).asInt(NaN).toString(16))
            this.getInitObject("xnor_output").setText(this.svSigRef(`L0_xnor_a0`).asInt(NaN).toString(16))
                  }

\TLV
   $reset = *reset;
   $x[1:0] = $reset ? 3 : >>1$x+1;
   $x1 = $x[1];
   $x0 = $x[0];
   $and = $x1 & $x0;
   $or = $x1 | $x0;
   $not_x1 = !$x1;
   $not_x0 = !$x0;
   $nand = !($x1 & $x0);
   $nor = !($x1 | $x0);
   $xor = $x1 ^ $x0;
   $xnor = !($x1 ^ $x0);
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
   m4+calc_logic()
\SV
   endmodule
