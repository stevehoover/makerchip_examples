\m4_TLV_version 1d: tl-x.org
\SV
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/tlv_lib/db48b4c22c4846c900b3fa307e87d9744424d916/fundamentals_lib.tlv'])
   m4_makerchip_module


// An simple ring implementation, as presented at DAC (See https://www.redwoodeda.com/publications)
// provided as a macro with VIZ support, along with two instantiations with different transaction visualization.



// The Ring Macro
// Args:
//   /_name: The name of the ring scope.
//   #_size: The number of ring ports (matching /port[#_size-1:0])
//   _where: The where JS object for /_name\viz_js, or [''] for no VIZ.
//   _trans_scope: VIZ JS code to reference the transaction Fabric Objects is _trans_scope.context.transObj['$uid']
//   _in: The \TLV block in \_name\port[*]|ring@1\in that generates transaction Fabric Objects.
//        (Done as an arg only due to a current VIZ limitation with lexically reentered scopes.)
//
// Inputs:
//   /_name
//      /_port[3:0]
//         |ring
//            /in
//               @1
//                  $ANY
//                  $dest[1:0]
// Outputs:
//   /_name
//      /port[3:0]
//         |ring
//            @1
//               $ANY
//               $exit
\TLV ring(/_name, #_size, _where, _trans_scope, _in)
   /_name
      /port[*]
         |ring
            @1
               /upstream
                  $ANY = /port[(#port + #_size - 1) % #_size]|ring>>1$ANY;
               $ANY = /upstream$continue ? /upstream$ANY : /in$ANY;
               $valid = ! *reset && (/in$valid || /upstream$continue);
               $exit = $valid && $dest == #port;
               $continue = $valid && ! $exit;
      
      
      m4+ifelse(['_where'], [''], ,
         \TLV
            // ===
            // VIZ
            // ===
            
            \viz_js
               box: {strokeWidth: 0},
               init() {
                  let ring = new fabric.Rect({
                     top: 9.5,
                     left: 9.5,
                     height: (#_size - 1) * 20,
                     width: 20,
                     stroke: "black",
                     strokeWidth: 1,
                     fill: "#FFFFFF00"
                  })
                  this.transObj = {} // A map of transaction fabric objects, indexed by $uid.
                  return {ring}
               },
               where: _where,
            /port[m4_eval(#_size-1):0]
               |ring
                  @1
                     /in
                        m4+_in
                     \viz_js
                        box: {left: 0, top: 0, width: 40, height: 20, strokeWidth: 0},
                        init() {
                           // TODO: HACK for broken this.getScope.
                           this.getScope = (index) => {return this.scopes[index]}
                           let colorByte = Math.floor((this.getIndex("port") / #_size) * 256)
                           let colorByteString = colorByte.toString(16).padStart(2, "0")
                           let colorByteString2 = (255 - colorByte).toString(16).padStart(2, "0")
                           this.color = "#00" + colorByteString + colorByteString2
                           let dot = new fabric.Circle({
                              top: 10 - 2,
                              left: 10 - 2,
                              radius: 2,
                              fill: this.color,
                              strokeWidth: 0
                           })
                           return {dot}
                        },
                        render() {
                           ret = []
                           // Position trans.
                           if ('$valid'.asBool()) {
                              let uid = '$uid'.asInt()
                              let trans = _trans_scope.context.transObj[uid]
                              if (trans) {
                                 ret.push(trans)
                                 if ('$valid'.asBool() && ! '/upstream$continue'.asBool()) {
                                    // Entering.
                                    trans.set({opacity: 0, top: 0, left: -20})
                                    trans.animate({left: 0, top: 5, opacity: 1}, { onChange: this.global.canvas.renderAll.bind(this.global.canvas) })
                                 } else {
                                    // Continuing from ring.
                                    if (this.getIndex("port") == 0) {
                                       trans.set({opacity: 1, left: 15, top: 20 * #_size - 15})
                                    } else {
                                       trans.set({opacity: 1, left: 0, top: -15})
                                    }
                                    trans.animate({top: 5, left: 0}, { onChange: this.global.canvas.renderAll.bind(this.global.canvas) })
                                 }
                              } else {
                                 console.log(`Transaction ${uid} not found.`)
                              }
                           }
                           // Exiting trans.
                           if ('>>1$exit'.asBool()) {
                              let uid = '>>1$uid'.asInt()
                              let trans = _trans_scope.context.transObj[uid]
                              if (trans) {
                                 ret.push(trans)
                                 trans.set({top: 5, left: 0, opacity: 1})
                                 trans.animate({left: -20, top: 10, opacity: 0}, { onChange: this.global.canvas.renderAll.bind(this.global.canvas) })
                              }
                           }
                           return ret
                        }
         )



// A similar ring implementation built from the flow library.
\TLV ring2(/_port, |_in, @_in, |_out, @_out)
   /_port[*]
      // Ring
      m4+arb2(/_port, |_in, @_in, |continue, @0, |ring, @0, /flit)
      // Pipeline for ring hop.
      m4+pipe(ff, 1, /_port, |ring, @0, |continue2, @0, /flit)
      // Fork from off-ramp out or into FIFO
      |continued2
         @0
            $exit = /flit$dest == #port;
            $true = 1'b1;
      m4+fork(/_port, |continued2, @0, $exit, |_out, @_out, $true, |continue, @0, /flit)


\TLV
   
   // =========
   // Testbench
   // =========
   
   // Instantiates two example rings with stimulus and VIZ.
   
   
   //
   // My Ring
   //
   
   
   // Inputs/Outputs
   /my_ring
      /port[3:0]
         |ring
            @1
               // Random inputs:
               /in
                  m4_rand($valid, 0, 0, port)
                  m4_rand($data, 31, 0, port)
                  m4_rand($dest, 1, 0, port)
               
               // Consume outputs:
               `BOGUS_USE($data $valid)
   // Instantiate Ring
   m4+ring(/my_ring, 4, ['{left: -20, top: -40, width: 40, height: 80}'], this.getScope("my_ring"),
      \TLV
         $src[1:0] = #port;
         $uid[31:0] = {$src, *cyc_cnt[29:0]};
         $enter = ! *reset && (|ring$valid && ! |ring/upstream$continue);
         \viz_js
            box: {strokeWidth: 0},
            onTraceData() {
               // TODO: HACK for broken this.getScope.
               this.getScope = (index) => {return this.scopes[index]}
               // Scan entire simulation for transactions originating in this port.
               let $enter = '$enter'.goTo(-1)
               let $uid = '$uid'
               let $dest = '$dest'
               let $data = '$data'
               while ($enter.forwardToValue(1)) {
                  let uid  = $uid.goTo($enter.getCycle()).asInt()
                  let dest = $dest.goTo($enter.getCycle()).asInt()
                  let data = $data.goTo($enter.getCycle()).asInt()
                  let transRect = new fabric.Rect({
                     width: 20,
                     height: 10,
                     fill: this.getScope("my_ring").children.port.children[dest].children.ring.context.color,
                     left: 0,
                     top: 0,
                     strokeWidth: 0
                  })
                  let transText = new fabric.Text(`${data.toString(16)}`, {
                     left: 1,
                     top: 2.5,
                     fontSize: 4,
                     fill: "white"
                  })
                  let transObj = new fabric.Group(
                     [transRect,
                      transText
                     ],
                     {width: 20,
                      height: 10}
                  )
                  this.getScope("my_ring").context.transObj[uid] = transObj
               }
               return {}
            }
      )
   
   
   //
   // My Other Ring
   //
   
   
   // Inputs/Outputs
   /my_other_ring
      /port[5:0]
         |ring
            @1
               // Random inputs:
               /in
                  m4_rand($valid, 0, 0, port)
                  m4_rand($hour_rand, 3, 0, port)
                  m4_rand($dest_rand, 2, 0, port)
                  $hour[3:0] = $hour_rand % 12;
                  $dest[2:0] = $dest_rand % 6;
               // Consume outputs:
               `BOGUS_USE($hour $valid)
   // Instantiate Ring
   m4+ring(/my_other_ring, 6, ['{left: 40, top: -20, width: 40, height: 30}'], this.getScope("my_other_ring"),
      \TLV
         $src[2:0] = #port;
         $uid[31:0] = {$src, *cyc_cnt[28:0]};
         $enter = ! *reset && (|ring$valid && ! |ring/upstream$continue);
         \viz_js
            box: {strokeWidth: 0},
            onTraceData() {
               // TODO: HACK for broken this.getScope.
               this.getScope = (index) => {return this.scopes[index]}
               // Scan entire simulation for transactions originating in this port.
               let $enter = '$enter'.goTo(-1)
               let $uid = '$uid'
               let $dest = '$dest'
               let $hour = '$hour'
               while ($enter.forwardToValue(1)) {
                  let uid  = $uid.goTo($enter.getCycle()).asInt()
                  let dest = $dest.goTo($enter.getCycle()).asInt()
                  let data = $hour.goTo($enter.getCycle()).asInt()
                  let transRect = new fabric.Rect({
                     width: 20,
                     height: 10,
                     rx: 4,
                     ry: 3,
                     fill: "#303030d0",
                     left: 0,
                     top: 0,
                     strokeWidth: 1,
                     stroke: this.getScope("my_other_ring").children.port.children[dest].children.ring.context.color
                  })
                  let transText = new fabric.Text(`${data.toString(16)}`, {
                     left: 1,
                     top: 2.5,
                     fontSize: 4,
                     fontFamily: "mono",
                     fill: "yellow"
                  })
                  let transObj = new fabric.Group(
                     [transRect,
                      transText
                     ],
                     {width: 20,
                      height: 10}
                  )
                  transObj.debug_name = `${uid}`  // Just to help w/ debug.
                  console.log(`Created trans ${uid}, at ${$enter.getCycle()}, with canvas: ${!!transObj.canvas}`)
                  if (this.getScope("my_other_ring").context.transObj[uid]) {
                    debugger
                    console.log("BUG: Duplicate transaction!")
                  }
                  this.getScope("my_other_ring").context.transObj[uid] = transObj
               }
               return {}
            }
      )
   
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
         
\SV
   endmodule
