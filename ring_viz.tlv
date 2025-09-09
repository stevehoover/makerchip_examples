\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)

\TLV ring_example(/_top, _where)
   m5_var(top_scope, ['this.getScope("']m4_strip_prefix(/_top)['")'])
   /_top
      // Include fifo and ring components from a git repo.
      m4_include_url(['https://raw.githubusercontent.com/stevehoover/tlv_flow_lib/c48ad6c12e21f6fb49d77e7a633387264660d401/pipeflow_lib.tlv'])

      m5_define_hier(RING_STOP, 4, 0)
      // Using legacy M4-based pipeflow_lib.
      m4_define(['M4_RING_STOP_INDEX_RANGE'], m5_RING_STOP_INDEX_MAX:m5_RING_STOP_INDEX_MIN)
      m4_define(['M4_RING_STOP_CNT'], m5_RING_STOP_CNT)
      m5_define_hier(FIFO_ENTRY, 6)
      m5_var(NUM_PACKETS_WIDTH, 16)
      \SV_plus
         parameter NUM_PACKETS_WIDTH = m5_NUM_PACKETS_WIDTH;

      /* verilator lint_save */
      /* verilator lint_off MULTIDRIVEN */



      // *********************
      // * DESIGN UNDER TEST *
      // *********************

      // Hierarchy
      /m5_RING_STOP_HIER

      // Reset
      $reset = *reset;

      // FIFOs
      /ring_stop[*]
         // Inputs
         |inpipe
            @1
               $reset = /_top>>2$reset;

               $avail = ! $reset && /_top/tb/ring_stop|send<>0$accepted;
               ?$accepted
                  /trans
                     // Compute parity
                     // [+] $parity = ^ {$data, $dest};

                     $ANY = /_top/tb/ring_stop|send/trans_out<>0$ANY;

         // FIFOs
         m5+flop_fifo_v2(/ring_stop, |inpipe, @1, |fifo_out, @0, 6, /trans)

         |fifo_out
            @0
               $dest[m5_RING_STOP_INDEX_RANGE] = /trans$dest;

         // Outputs
         |outpipe
            @1
               $accepted = $avail && ! $blocked;
               ?$accepted
                  /trans
                     `BOGUS_USE($data)

                     // Check parity.
                     // [+] $parity_error = $parity != ^ {$data, $dest};

      // Instantiate the ring.
      m5+simple_ring_v2(/ring_stop, |fifo_out, @0, |outpipe, @0, $reset, |rg, /trans)

      // End of DUT
      // ==========



      // *******
      // * VIZ *
      // *******

      \viz_js
         lib: {
            setTrans: function (uid, obj) {
               let data = '/_top'.data
               if (typeof(data.transObj[uid]) !== "undefined") {
                  console.log(`Adding duplicate trans #${uid.toString(16)}`)
                  debugger
               }
               data.transObj[uid] = obj
               //console.log(`Added trans #${uid.toString(16)}`)
               //debugger
            },
            getTrans: function (uid) {
               let data = '/_top'.data
               let ret = data.transObj[uid]
               if (typeof(ret) === "undefined") {
                  console.log(`Failed to find trans #${uid.toString(16)}`)
                  debugger
               }
               return data.transObj[uid]
            }
         },
         box: {strokeWidth: 2, top: -25, left: -30, width: 215, height: 210, fill: "white"},
         init() {
            let data = '/_top'.data
            data.transObj = {} // A map of transaction fabric objects, indexed by $uid.
            return {}
         },
         onTraceData() {
            // Add all transactions to this top level.
            return {objects: '/_top'.data.transObj}
         },
         unrender() {
            // Make every transaction invisible (and other render methods will make them visible again.
            for (const uid in '/_top'.data.transObj) {
               const trans = '/_top'.data.transObj[uid]
               trans.set({opacity: 1})
               trans.wasVisible = trans.visible
               trans.set({visible: false})
            }
         },
         where: {_where}


      /m5_RING_STOP_HIER
         \viz_js
            box: {width: m5_FIFO_ENTRY_CNT * 15 + 10, height: 50, strokeWidth: 0},
            where: {left: -5, top: -5}
         |inpipe
            @1
               \viz_js
                  box: {strokeWidth: 0},
                  init() {
                     this.getColor = () => {
                        return "#00" + (255 - Math.floor((this.getIndex("ring_stop") / m5_RING_STOP_CNT) * 256)).toString(16) + "00"
                     }
                     
                     // FIFO outer box.
                     let stop = this.getIndex("ring_stop")
                     let fifoBox = new fabric.Rect({
                        width: m5_FIFO_ENTRY_CNT * 15 + 10,
                        height: 20,
                        fill: "lightgray",
                        stroke: this.getColor(),
                        left: 0,
                        top: 0
                     })
                     
                     return {fifoBox}
                  },
                  onTraceData() {
                     // Process the trace.
                     // Look over the entire simulation and register an object for every transaction.
                     let $accepted = '$accepted'.goTo(-1)
                     let $uid      = '/trans$uid'
                     let $response = '/trans$response'
                     let $sender   = '/trans$sender'
                     let $dest     = '/trans$dest'
                     let $data     = '/trans$data'
                     let $cnt      = '/trans$cnt'
                     while ($accepted.forwardToValue(1)) {
                        let response = $response.goTo($accepted.getCycle()).asInt()
                        if (!response) {
                           let uid      = $uid     .goTo($accepted.getCycle()).asInt()
                           let sender   = $sender  .goTo($accepted.getCycle()).asInt()
                           let dest     = $dest    .goTo($accepted.getCycle()).asInt()
                           let data     = $data    .goTo($accepted.getCycle()).asInt()
                           let cnt      = $cnt     .goTo($accepted.getCycle()).asInt()
                           // TODO: Use global function.
                           let senderColor = (255 - Math.floor((sender / m5_RING_STOP_CNT) * 256)).toString(16)
                           let destColor   = (255 - Math.floor((dest   / m5_RING_STOP_CNT) * 256)).toString(16)
                           let transRect = new fabric.Rect({
                              width: 10,
                              height: 10,
                              stroke: "#00" + senderColor + "00",
                              fill: "#00" + destColor + "00",
                              left: 0,
                              top: 0
                           })
                           let transText = new fabric.Text(`cnt: ${cnt.toString(16)}\ndata: ${data.toString(16)}`, {
                              left: 1,
                              top: 1,
                              fontSize: 2,
                              fill: "white",
                              textBackgroundColor: `#${(cnt & 1) ? "ff" : "00"}10${(cnt & 2) ? "ff" : "00"}`
                           })
                           let transObj = new fabric.Group(
                              [transRect,
                               transText
                              ],
                              {width: 10,
                               height: 10,
                               visible: false}
                           )
                           '/_top'.lib.setTrans(uid, transObj)
                         }
                     }
                  }
               /entry[m5_FIFO_ENTRY_RANGE]
                  \viz_js
                     box: {strokeWidth: 0},
                     render() {
                        // Find head entry.
                        // TODO: This is repeated for every entry unnecessarily.
                        //       With the current API, leaf processing is first, so its hard
                        //       to pass info from ancestors.
                        let head_ptr = -1
                        for (var i = 0; i < m5_FIFO_ENTRY_CNT; i++) {
                           if ('/entry[i]>>1$is_head'.step(1).asBool()) {  // '/entry[i]$is_head', but can't access @1 (will be fixed).
                              head_ptr = i
                           }
                        }
                        
                        if ('$valid'.asBool()) {
                           let uid = '/trans$uid'.asInt()
                           let trans = '/_top'.lib.getTrans(uid)
                           if (typeof(trans) !== "undefined") {
                              trans.set({visible: true})
                              // Set position.
                              let pos = m5_FIFO_ENTRY_MAX - ((this.getIndex() + m5_FIFO_ENTRY_CNT - head_ptr) % m5_FIFO_ENTRY_CNT)
                              if (!trans.wasVisible) {
                                 trans.set({top: this.getIndex("ring_stop") * 50 + 10,
                                            left: pos * 15 - 10,
                                            opacity: 0})
                                 trans.animate({opacity: 1})
                              }
                              trans.animate({top: this.getIndex("ring_stop") * 50,
                                             left: pos * 15})
                           }
                        }
                     }
         |fifo_out
            @0
               \viz_js
                  box: {strokeWidth: 0},
                  render() {
                     if ('$accepted'.asBool()) {
                        let uid = '/trans$uid'.asInt()
                        let trans = '/_top'.lib.getTrans(uid)
                        if (typeof(trans) !== "undefined") {
                           trans.set({visible: true})
                           // Set position.
                           if (!trans.wasVisible) {
                              trans.set({top: this.getIndex("ring_stop") * 50 + 10,
                                         left: 8 * 15 - 10,
                                         opacity: 0})
                              trans.animate({opacity: 1}, {duration: 500})
                           }
                           trans.animate({top: this.getIndex("ring_stop") * 50,
                                          left: 8 * 15})
                        }
                     }
                  }
               
         |rg
            @1
               \viz_js
                  box: {strokeWidth: 0},
                  render() {
                     if ('$valid'.asBool()) {
                        let uid = '/trans$uid'.asInt()
                        let trans = '/_top'.lib.getTrans(uid)
                        if (typeof(trans) !== "undefined") {
                           trans.set({visible: true})
                           // To position.
                           // If wrapping, adjust initial position.
                           if ((this.getIndex("ring_stop") == 0) && '$passed_on'.asBool()) {
                             trans.set({left: 11 * 15})
                           }
                           trans.animate({top: this.getIndex("ring_stop") * 50,
                                          left: 10 * 15})
                        }
                     }
                  }
               
         |outpipe
            @2
               \viz_js
                  box: {strokeWidth: 0},
                  render() {
                     if ('$accepted'.asBool()) {
                        let uid = '/trans$uid'.asInt()
                        let trans = '/_top'.lib.getTrans(uid)
                        if (typeof(trans) !== "undefined") {
                           // Set position and fade.
                           trans.set({visible: true})
                           trans.animate({top: this.getIndex("ring_stop") * 50 - 15,
                                          left: 8 * 15,
                                          opacity: 0})
                        }
                     }
                  }





      // *************
      // * Testbench *
      // *************
      
      // The testbench is not the focus of this lab.
      // You can ignore everything below.
      
      /tb
         |count
            @0
               $CycCount[15:0] <= /_top>>1$reset ? 16'b0 :
                                                  $CycCount + 1;
               \SV_plus
                  always_ff @(posedge clk) begin
                     \$display("Cycle: %0d", $CycCount);
                  end
         /m5_RING_STOP_HIER
            // STIMULUS
            |send
               @0
                  $reset = /_top<>0$reset;
                  $valid_in = /tb|count<>0$CycCount > 3 && /tb|count<>0$CycCount < 7; // && ring_stop == 0;
                  $Cnt[31:0] <= $reset ? 32'b0 :
                                $valid_in ? $Cnt + 32'b1 :
                                            $RETAIN;
                  ?$valid_in
                     /gen_trans
                        $response = 1'b0;
                        $sender[m5_RING_STOP_INDEX_RANGE] = ring_stop;
                        m4_rand($dest_tmp, m5_RING_STOP_INDEX_MAX, 0, ring_stop)
                        $dest[m5_RING_STOP_INDEX_RANGE] = $dest_tmp % m5_RING_STOP_CNT;
                        m4_rand($data, 7, 0, ring_stop);
                        $cnt[31:0] = |send$Cnt;
                        $uid[m5_RING_STOP_INDEX_MAX+32:0] = {$sender, $cnt};
                  $accepted = $valid_in || /ring_stop|receive<>0$request;
                  ?$accepted
                     /trans_out
                        $ANY = /ring_stop|receive<>0$request ? /ring_stop|receive/trans<>0$ANY :
                                                               |send/gen_trans<>0$ANY;
                        
                        \SV_plus
                           always_ff @(posedge clk) begin
                              if (|send$accepted) begin
                                 \$display("\|send[%0d]", ring_stop);
                                 \$display("Sender: %0d, Destination: %0d", $sender, $dest);
                              end
                           end
            
            |receive
               @0
                  $reset = /_top>>1$reset;
                  $accepted = /_top/ring_stop|outpipe>>1$accepted;
                  $request = $accepted && /trans<>0$sender != ring_stop;
                  $received = $accepted && /trans<>0$sender == ring_stop;
                  $NumPackets[NUM_PACKETS_WIDTH-1:0] <=
                       $reset                      ? '0 :
                       /ring_stop|send<>0$valid_in ? $NumPackets + 1 :
                       $request                    ? $NumPackets :
                       $received                   ? $NumPackets - 1 :
                                                     $NumPackets;
                  ?$accepted
                     /trans
                        $response = |receive$request;
                        $ANY = /_top/ring_stop|outpipe/trans>>1$ANY;
                        $dest[m5_RING_STOP_INDEX_RANGE] = |receive<>0$request ? $sender : $dest;
         |pass
            @0
               $reset = /_top>>1$reset;
               $packets[m5_RING_STOP_CNT * NUM_PACKETS_WIDTH - 1:0] = /tb/ring_stop[*]|receive<>0$NumPackets;
               $passed = !$reset && ($packets == '0) && (/tb|count<>0$CycCount > 6);
      
      /* verilator lint_restore */

\SV
   m5_makerchip_module

\TLV
   m5+ring_example(/ring, )
   *passed = /ring/tb|pass<>0$passed;
\SV
endmodule
