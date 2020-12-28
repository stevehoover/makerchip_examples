\m4_TLV_version 1d: tl-x.org
\SV
   m4_define(['m4_viz'], 1)
   m4_makerchip_module

// Inputs:
//   /_name
//      /node[3:0]
//         |ring
//            /in
//               @1
//                  $ANY
//                  $dest[1:0]
// Outputs:
//   /_name
//      /node[3:0]
//         |ring
//            @1
//               $ANY
//               $exit
\TLV ring(/_name)
   /_name
      /node[*]
         |ring
            @1
               /from_ring
                  $ANY = /node[(#node + 1) % M4_NODE_CNT]|ring>>1$ANY;
               $ANY = /from_ring$continue ? /from_ring$ANY : /from_node$ANY;
               $valid = ! *reset && (/from_node$valid || /from_ring$continue);
               $exit = $valid && $dest == #node;
               $continue = $valid && ! $exit;
      
      
      m4_ifelse_block(m4_viz, 1, ['
      // ===
      // VIZ
      // ===
      
      /node[*]
         |ring
            @1
               /from_node
                  $src[1:0] = #node;
                  $uid[31:0] = {$src, *cyc_cnt[29:0]};
               $enter = ! *reset && ($valid && ! /from_ring$continue);
      \viz_alpha
         initEach() {
            context.global.canvas.add(new fabric.Rect({
               top: 5,
               left: 10,
               height: 3 * 20,
               width: 20,
               stroke: "black",
               fill: "#FFFFFF00"
            }))
            return {
               objects: {
                  //ring: this.canvas
               },
               transObj: {} // A map of transaction fabric objects, indexed by $uid.
            }
         },
         renderEach() {
            // Make every transaction invisible (and other render methods will make them visible again.
            for (const uid in this.fromInit().transObj) {
               const trans = this.fromInit().transObj[uid]
               //trans.wasVisible = trans.visible
               trans.visible = false
            }
         }
      /node[3:0]
         |ring
            @1
               \viz_alpha
                  initEach() {
                     let colorByte = Math.floor((this.getIndex("node") / 4) * 256)
                     let colorByteString = colorByte.toString(16).padStart(2, "0")
                     let colorByteString2 = (255 - colorByte).toString(16).padStart(2, "0")
                     let color = "#00" + colorByteString + colorByteString2
                     context.global.canvas.add(new fabric.Circle({
                        top: (3 - this.getIndex("node")) * 20 + 5 - 2,
                        left: 10 - 2,
                        radius: 2,
                        fill: color
                     }))
                     return {color: color}
                  },
                  renderEach()) {
                     // Scan entire simulation for transactions originating in this node.
                     if (typeof this.getContext().preppedTrace === "undefined") {
                        let $enter = '$enter'.goTo(-1);
                        let $uid = '$uid';
                        let $dest = '$dest';
                        let $data = '$data';
                        while ($enter.forwardToValue(1)) {
                           let uid  = $uid .goTo($enter.getCycle()).asInt();
                           let dest = $dest.goTo($enter.getCycle()).asInt();
                           let data = $data.goTo($enter.getCycle()).asInt();
                           let ring_scope = this.getScope("my_ring");
                           debugger;
                           let transRect = new fabric.Rect({
                              width: 20,
                              height: 10,
                              fill: this.getScope("m4_strip_prefix(/_name)").children.node.instances[dest].children.ring.instances[""].initResults.color,
                              left: 0,
                              top: 0
                           });
                           let transText = new fabric.Text(`${data.toString(16)}`, {
                              left: 1,
                              top: 3,
                              fontSize: 4,
                              fill: "white"
                           });
                           let transObj = new fabric.Group(
                              [transRect,
                               transText
                              ],
                              {width: 20,
                               height: 10,
                               visible: false}
                           );
                           context.global.canvas.add(transObj);
                           this.getScope("m4_strip_prefix(/_name)").initResults.transObj[uid] = transObj;
                        }
                        
                        this.getContext().preppedTrace = true;
                     }
                     
                     // Position trans.
                     if ('$valid'.asBool()) {
                        let uid = '$uid'.asInt();
                        let trans = this.getScope("m4_strip_prefix(/_name)").initResults.transObj[uid];
                        if (trans) {
                           trans.set("visible", true);
                           if ('$enter'.asBool()) {
                              trans.set("opacity", 0);
                              trans.set("top", (3 - this.getIndex("node")) * 20 - 6);
                              trans.set("left", -20);
                              trans.animate("left", 0, { onChange: this.global.canvas.renderAll.bind(this.global.canvas) });
                              trans.animate("top", (3 - this.getIndex("node")) * 20, { onChange: this.global.canvas.renderAll.bind(this.global.canvas) });
                              trans.animate("opacity", 1, { onChange: this.global.canvas.renderAll.bind(this.global.canvas) });
                           } else {
                              if (this.getIndex("node") == 3) {
                                 trans.set("left", 10);
                              }
                              trans.animate("top", (3 - this.getIndex("node")) * 20, { onChange: this.global.canvas.renderAll.bind(this.global.canvas) });
                              trans.animate("left", 0, { onChange: this.global.canvas.renderAll.bind(this.global.canvas) });
                           }
                        } else {
                           console.log(`Transaction ${uid} not found.`);
                        }
                     }
                     // Exiting trans.
                     if ('>>1$exit'.asBool()) {
                        let uid = '>>1$uid'.asInt();
                        let trans = this.getScope("m4_strip_prefix(/_name)").initResults.transObj[uid];
                        if (trans) {
                           trans.set("visible", true);
                           trans.set("top", (3 - this.getIndex("node")) * 20);
                           trans.animate("top", (3 - this.getIndex("node")) * 20 + 6);
                           trans.animate("left", -20, { onChange: this.global.canvas.renderAll.bind(this.global.canvas) });
                           trans.animate("opacity", 0, { onChange: this.global.canvas.renderAll.bind(this.global.canvas) });
                        }
                     }
                  }
      '])

\TLV ring2(/_port, |_in, @_in, |_out, @_out)
   /_port[*]
      // Ring
      m4+arb2(/_port, |_in, @_in, |continue, @0, |ring, @0, /flit)
      // Pipeline for ring hop.
      m4+pipe(ff, 1, /_port, |ring, @0, |continue2, @0, /flit)
      // Fork from off-ramp out or into FIFO
      |continued2
         @0
            $exit = /flit$dest == #pm4_strip_prefix(/_port);
            $true = 1'b1;
      m4+fork(/_port, |continued2, @0, $exit, |_out, @_out, $true, |continue, @0, /flit)


\TLV
   
   // =========
   // Testbench
   // =========
   
   //
   // My Ring
   //
   
   // Inputs/Outputs
   m4_define_hier(['M4_NODE'], 4, 0)
   /my_ring
      /M4_NODE_HIER
         |ring
            @1
               // Random inputs:
               /from_node
                  m4_rand($valid, 0, 0, node)
                  m4_rand($data, 31, 0, node)
                  m4_rand($dest, 1, 0, node)
               // Consume outputs:
               `BOGUS_USE($data $valid)
   // Instantiate Ring
   m4+ring(/my_ring)
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
   

         
\SV
   endmodule
