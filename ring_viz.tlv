\m4_TLV_version 1d: tl-x.org
\SV
m4_makerchip_module

// Include fifo and ring components from a git repo.
m4_include_url(['https://raw.githubusercontent.com/stevehoover/tlv_flow_lib/5a8c0387be80b2deccfcd1506299b36049e0663e/pipeflow_lib.tlv'])

m4_define_hier(M4_RING_STOP, 4, 0)
m4_define_hier(M4_FIFO_ENTRY, 6)
m4_define(M4_NUM_PACKETS_WIDTH, 16)
parameter NUM_PACKETS_WIDTH = M4_NUM_PACKETS_WIDTH;

/* verilator lint_off MULTIDRIVEN */
\TLV
   
   
   // *********************
   // * DESIGN UNDER TEST *
   // *********************
   
   // Hierarchy
   /M4_RING_STOP_HIER
   
   // Reset
   $reset = *reset;
   
   // FIFOs
   /ring_stop[*]
      // Inputs
      |inpipe
         @1
            $reset = /top>>2$reset;
            
            $avail = ! $reset && /top/tb/ring_stop|send<>0$accepted;
            ?$accepted
               /trans
                  // Compute parity
                  // [+] $parity = ^ {$data, $dest};
                   
                  $ANY = /top/tb/ring_stop|send/trans_out<>0$ANY;
      
      // FIFOs
      m4+flop_fifo_v2(/ring_stop, |inpipe, @1, |fifo_out, @0, 6, /trans)
      
      // Outputs
      |outpipe
         @1
            $blocked = 1'b0;  // No blocking at output.
            $accepted = $avail && ! $blocked;
            ?$accepted
               /trans
                  `BOGUS_USE($data)
               
                  // Check parity.
                  // [+] $parity_error = $parity != ^ {$data, $dest};
   
   // Instantiate the ring.
   m4+simple_ring(/ring_stop, |fifo_out, @0, |outpipe, @0, $reset, |rg, /trans)
   
   // End of DUT
   // ==========



   // *******
   // * VIZ *
   // *******
   
   \viz_alpha
      initEach: function () {
         
         //debugger;
         this.transObj = {}; // A map of transaction fabric objects, indexed by $uid.
         let animationRect = new fabric.Rect({
                     width: 5,
                     height: 5,
                     fill: "red",
                     stroke: "black",
                     left: -20,
                     top: -20,
                     angle: 0});
         
         return {
            transObj: this.transObj,
            setTrans: (uid, obj) => {
               if (typeof(this.transObj[uid]) !== "undefined") {
                  console.log(`Adding duplicate trans #${uid.toString(16)}`);
                  debugger;
               }
               this.transObj[uid] = obj;
               console.log(`Added trans #${uid.toString(16)}`);
               //debugger;
            },
            getTrans: (uid) => {
               let ret = this.transObj[uid];
               if (typeof(ret) === "undefined") {
                  console.log(`Failed to find trans #${uid.toString(16)}`);
                  debugger;
               }
               return this.transObj[uid];
            },
            objects: {animationRect: animationRect}
         };
      },
      renderEach: function () {
         //debugger;
         // Make every transaction invisible (and other render methods will make them visible again.
         for (const uid in this.fromInit().transObj) {
            const trans = this.fromInit().transObj[uid];
            trans.set("opacity", 1);
            trans.wasVisible = trans.visible;
            trans.visible = false;
         }
         // Force animation rendering.
         this.getInitObjects().animationRect.set("angle", 0);
         this.getInitObjects().animationRect.animate("angle", 90, {
              onChange: this.global.canvas.renderAll.bind(this.global.canvas),
              duration: 1000  // To cover default 500 + extra (hack).
         });
      }
   
   /M4_RING_STOP_HIER
      |inpipe
         @1
            \viz_alpha
               initEach: function() {
                  context.global.getRingStopColor = function (stop) {
                     return "#00" + (255 - Math.floor((stop / M4_RING_STOP_CNT) * 256)).toString(16) + "00";
                  };
                  
                  // FIFO outer box.
                  let stop = this.getScope("ring_stop").index;
                  let fifoBox = new fabric.Rect({
                     width: M4_FIFO_ENTRY_CNT * 15 + 10,
                     height: 20,
                     fill: "lightgray",
                     stroke: context.global.getRingStopColor(stop),
                     left: -5,
                     top: -5 + 50 * stop
                  });
                  
                  return {objects: {fifoBox: fifoBox}};
               },
               renderEach: function () {
                  // Look over the entire simulation and register an object for every transaction.
                  // BUG: waveform is not available to initEach(). Do we need a new method after waveform loads?
                  // Hack it here. Assume whole trace loads before any rendering.
                  if (typeof this.getContext().preppedTrace === "undefined") {
                     
                     // Process the trace.
                     let $accepted = '$accepted'.goTo(-1);
                     let $uid      = '/trans$uid';
                     let $response = '/trans$response';
                     let $sender   = '/trans$sender';
                     let $dest     = '/trans$dest';
                     let $data     = '/trans$data';
                     let $cnt      = '/trans$cnt';
                     while ($accepted.forwardToValue(1)) {
                        //debugger;
                        let response = $response.goTo($accepted.getCycle()).asInt();
                        if (!response) {
                           let uid      = $uid     .goTo($accepted.getCycle()).asInt();
                           let sender   = $sender  .goTo($accepted.getCycle()).asInt();
                           let dest     = $dest    .goTo($accepted.getCycle()).asInt();
                           let data     = $data    .goTo($accepted.getCycle()).asInt();
                           let cnt      = $cnt     .goTo($accepted.getCycle()).asInt();
                           // TODO: Use global function.
                           let senderColor = (255 - Math.floor((sender / M4_RING_STOP_CNT) * 256)).toString(16);
                           let destColor   = (255 - Math.floor((dest   / M4_RING_STOP_CNT) * 256)).toString(16);
                           //debugger;
                           let transRect = new fabric.Rect({
                              width: 10,
                              height: 10,
                              stroke: "#00" + senderColor + "00",
                              fill: "#00" + destColor + "00",
                              left: 0,
                              top: 0
                           });
                           let transText = new fabric.Text(`cnt: ${cnt.toString(16)}\ndata: ${data.toString(16)}`, {
                              left: 1,
                              top: 1,
                              fontSize: 2,
                              fill: "white",
                              textBackgroundColor: `#${(cnt & 1) ? "ff" : "00"}10${(cnt & 2) ? "ff" : "00"}`
                           });
                           let transObj = new fabric.Group(
                              [transRect,
                               transText
                              ],
                              {width: 10,
                               height: 10,
                               visible: false}
                           );
                           context.global.canvas.add(transObj);
                           this.getScope("top").initResults.setTrans(uid, transObj);
                         }
                     }
                     
                     this.getContext().preppedTrace = true;
                  }
                  
                  //context.global.canvas.add(fifoBox);
                  // Find head entry.
                  let head_ptr = -1;
                  for (var i = 0; i < M4_FIFO_ENTRY_CNT; i++) {
                     if ('/entry[i]>>1$is_head'.step(1).asBool()) {  // '/entry[i]$is_head', but can't access @1 (will be fixed).
                        head_ptr = i;
                     }
                  }
                  
                  return {head_ptr: head_ptr};
               }
            /entry[M4_FIFO_ENTRY_RANGE]
               \viz_alpha
                  renderEach: function () {
                     if ('$valid'.asBool()) {
                        let uid = '/trans$uid'.asInt();
                        let trans = this.getScope("top").initResults.getTrans(uid);
                        let canvas = context.global.canvas;
                        if (typeof(trans) !== "undefined") {
                           // Set position.
                           debugger;
                           let pos = M4_FIFO_ENTRY_MAX - ((this.getIndex() + M4_FIFO_ENTRY_CNT - this.getScope("inpipe").renderResults.head_ptr) % M4_FIFO_ENTRY_CNT);
                           if (!trans.wasVisible) {
                              trans.set("top", this.getIndex("ring_stop") * 50 + 10);
                              trans.set("left", pos * 15 - 10);
                              trans.set("opacity", 0);
                              trans.animate("opacity", 1);
                           }
                           trans.visible = true;
                           trans.animate("top", this.getIndex("ring_stop") * 50);
                           trans.animate("left", pos * 15);
                        }
                     }
                  }
      |fifo_out
         @0
            \viz_alpha
               renderEach: function () {
                  if ('$accepted'.asBool()) {
                     let uid = '/trans$uid'.asInt();
                     let trans = this.getScope("top").initResults.getTrans(uid);
                     if (typeof(trans) !== "undefined") {
                        // Set position.
                        if (!trans.wasVisible) {
                           trans.set("top", this.getIndex("ring_stop") * 50 + 10);
                           trans.set("left", 8 * 15 - 10);
                           trans.set("opacity", 0);
                           trans.animate("opacity", 1);
                        }
                        trans.animate("top", this.getIndex("ring_stop") * 50);
                        trans.animate("left", 8 * 15);
                        trans.visible = true;
                     }
                  }
               }
               
      |rg
         @1
            \viz_alpha
               renderEach: function () {
                  if ('$valid'.asBool()) {
                     let uid = '/trans$uid'.asInt();
                     let trans = this.getScope("top").initResults.getTrans(uid);
                     if (typeof(trans) !== "undefined") {
                        // To position.
                        // If wrapping, adjust initial position.
                        if ((this.getIndex("ring_stop") == 0) && '$passed_on'.asBool()) {
                          trans.set("left", 11 * 15);
                        }
                        trans.animate("top", this.getIndex("ring_stop") * 50);
                        trans.animate("left", 10 * 15);
                        trans.visible = true;
                     }
                  }
               }
            
      |outpipe
         @2
            \viz_alpha
               renderEach: function () {
                  if ('$accepted'.asBool()) {
                     let uid = '/trans$uid'.asInt();
                     let trans = this.getScope("top").initResults.getTrans(uid);
                     if (typeof(trans) !== "undefined") {
                        // Set position and fade.
                        trans.animate("top", this.getIndex("ring_stop") * 50 - 15);
                        trans.animate("left", 8 * 15);
                        trans.animate("opacity", 0);
                        trans.visible = true;
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
            $CycCount[15:0] <= /top>>1$reset ? 16'b0 :
                                               $CycCount + 1;
            \SV_plus
               always_ff @(posedge clk) begin
                  \$display("Cycle: %0d", $CycCount);
               end
      /M4_RING_STOP_HIER
         // STIMULUS
         |send
            @0
               $reset = /top<>0$reset;
               $valid_in = /tb|count<>0$CycCount > 3 && /tb|count<>0$CycCount < 7; // && ring_stop == 0;
               $Cnt[31:0] <= $reset ? 32'b0 :
                             $valid_in ? $Cnt + 32'b1 :
                                         $RETAIN;
               ?$valid_in
                  /gen_trans
                     $response = 1'b0;
                     $sender[M4_RING_STOP_INDEX_RANGE] = ring_stop;
                     m4_rand($dest_tmp, M4_RING_STOP_INDEX_MAX, 0, ring_stop)
                     $dest[M4_RING_STOP_INDEX_RANGE] = $dest_tmp % M4_RING_STOP_CNT;
                     m4_rand($data, 7, 0, ring_stop);
                     $cnt[31:0] = |send$Cnt;
                     $uid[M4_RING_STOP_INDEX_MAX+32:0] = {$sender, $cnt};
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
               $reset = /top>>1$reset;
               $accepted = /top/ring_stop|outpipe>>1$accepted;
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
                     $ANY = /top/ring_stop|outpipe/trans>>1$ANY;
                     $dest[M4_RING_STOP_INDEX_RANGE] = |receive<>0$request ? $sender : $dest;
      |pass
         @0
            $reset = /top>>1$reset;
            $packets[M4_RING_STOP_CNT * NUM_PACKETS_WIDTH - 1:0] = /tb/ring_stop[*]|receive<>0$NumPackets;
            *passed = !$reset && ($packets == '0) && (/tb|count<>0$CycCount > 6);


\SV
endmodule
