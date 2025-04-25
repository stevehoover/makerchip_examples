\m4_TLV_version 1d --noline: tl-x.org
\SV
   // This design was constructed to demonstrate the value of TLV logic diagrams vs. Yosys diagrams.
   // It defines an SV ring module as the point of comparison.

   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/tlv_lib/db48b4c22c4846c900b3fa307e87d9744424d916/fundamentals_lib.tlv'])
   m4_def(VIZ, 1)
   
   module ring(
      input clk,
      input reset,
      input [3:0] valid,
      input [(32*4)-1:0] data,
      input [(2*4)-1:0] dest,
      input [31:0] cyc_cnt,
      output [3:0] valid_out,
      output [(32*4)-1:0] data_out
   );


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
                                    trans.set({opacity: 0, left: -20, top: 0})
                                    trans.animate({opacity: 1, left: 0, top: 5}, {duration: 700})
                                 } else {
                                    // Continuing from ring.
                                    if (this.getIndex("port") == 0) {
                                       trans.set({opacity: 1, left: 0, top: 20 * #_size - 15})
                                       trans.animate({left: 20}, {duration: 150})
                                            .thenAnimate({top: 5}, {duration: 400})
                                            .thenAnimate({left: 0}, {duration: 150})
                                    } else {
                                       trans.set({opacity: 1, left: 0, top: -15})
                                       trans.animate({left: 0, top: 5}, {duration: 700})
                                    }
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
                                 trans.animate({left: -20, top: 10, opacity: 0})
                              }
                           }
                           return ret
                        }
         )



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
               /in
                  $valid = *valid[port];
                  $data[31:0] = *data[32*(port+1)-1:32* port];
                  $dest[1:0] = *dest[2*(port+1)-1:2* port];
               
               *data_out[32*(port+1)-1:32* port] = $data;
               *valid_out[port] = $exit;
   // Instantiate Ring
   m4+ring(/my_ring, 4, m4_ifelse(M4_VIZ, 1, ['['{left: -20, top: -40, width: 40, height: 80}']']), this.getScope("my_ring"),
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
   

\SV
   endmodule
   
   m4_makerchip_module
      genvar p;
\TLV
   \SV_plus
      wire [3:0] valid;
      wire [(32*4)-1:0] data;
      wire [(2*4)-1:0] dest;
      wire [3:0]valid_out;
      wire [(32*4)-1:0] data_out;
      for(p = 0; p < 4; p++) begin
         assign valid[p:p] = RW_rand_vect[(0 + (p)) % 257 +: 1];
         assign data[32*(p+1)-1:32* p] = RW_rand_vect[(124 + (p)) % 257 +: 32];
         assign dest[2*(p+1)-1:2* p] = RW_rand_vect[(248 + (p)) % 257 +: 2];
      end
\SV
      ring ring(clk, reset, valid, data, dest, cyc_cnt, valid_out, data_out);

      // Assert these to end simulation (before Makerchip cycle limit).
      assign passed = cyc_cnt > 40;
      assign failed = 1'b0;
   
   endmodule
