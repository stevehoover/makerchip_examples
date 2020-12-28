\m4_TLV_version 1d: tlx.org

// A WIP library of \viz blocks for other logic.

// TODO: Work this content into proper files.

// Viz code that can be attached to TLV macros -- to be merged into macros.
// __viz macros should have the same parameter list as their non-viz counterparts.

\TLV trans()
   \viz_alpha
      initEach() {
         
         debugger
         this.transObj = {} // A map of transaction fabric objects, indexed by $uid.
         return {
            transObj: this.transObj,
            setTrans: (uid, obj) => {
               if (typeof(this.transObj[uid]) !== "undefined") {
                  console.log(`Adding duplicate trans #${uid.toString(16)}`)
                  debugger
               }
               this.transObj[uid] = obj
               console.log(`Added trans #${uid.toString(16)}`)
               //debugger
            },
            getTrans: (uid) => {
               let ret = this.transObj[uid]
               if (typeof(ret) === "undefined") {
                  console.log(`Failed to find trans #${uid.toString(16)}`)
                  debugger
               }
               return this.transObj[uid]
            }
         }
      },
      renderEach() {
         // Make every object invisible (and other render methods will make them visible again.
         debugger
         for (const uid in this.fromInit().transObj) {
            const obj = this.fromInit().transObj[uid];
            obj.visible = false;
         }
      }


\TLV flop_fifo_v2__viz(/_top, |_in_pipe, @_in_at, |_out_pipe, @_out_at, #_depth, /_trans, #_high_water, $_reset)
   |_in_pipe
      @1
         \viz_alpha
            initEach() {
               debugger
               context.global.getRingStopColor = function (stop) {
                  return "#00" + (255 - Math.floor((stop / this.getScope("/_top".substring(1)).getNumElements() * 256)).toString(16) + "00"
               }
\TLV disabled()
               
               // FIFO outer box.
               let stop = this.getScope("ring_stop").index
               let fifoBox = new fabric.Rect({
                  width: M4_FIFO_ENTRY_CNT * 15 + 10,
                  height: 20,
                  fill: "lightgray",
                  stroke: context.global.getRingStopColor(stop),
                  left: -5,
                  top: -5 + 50 * stop
               })
               
               return {objects: {fifoBox}}
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
\TLV disabled()
         /entry[M4_FIFO_ENTRY_RANGE]
            \viz_alpha
               renderEach() {
                  if ('$valid'.asBool()) {
                     let uid = '/trans$uid'.asInt()
                     let trans = this.getScope("top").initResults.getTrans(uid)
                     if (typeof(trans) !== "undefined") {
                        // Set position.
                        debugger
                        let pos = M4_FIFO_ENTRY_MAX - ((this.getIndex() + M4_FIFO_ENTRY_CNT - this.getScope("|_in_pipe".substring(1)).renderResults.head_ptr) % M4_FIFO_ENTRY_CNT)
                        trans.top = this.getIndex("ring_stop") * 50
                        trans.left = pos * 15
                        trans.visible = true
                     }
                  }
               }
   |fifo_out
      @0
         \viz_alpha
            renderEach() {
               if ('$accepted'.asBool()) {
                  let uid = '/trans$uid'.asInt();
                  let trans = this.getScope("top").initResults.getTrans(uid)
                  if (typeof(trans) !== "undefined") {
                     // Set position.
                     trans.top = this.getIndex("ring_stop") * 50
                     trans.left = 8 * 15
                     trans.visible = true
                  }
               }
            }
            
   |rg
      @1
         \viz_alpha
            renderEach() {
               if ('$valid'.asBool()) {
                  let uid = '/trans$uid'.asInt()
                  let trans = this.getScope("top").initResults.getTrans(uid)
                  if (typeof(trans) !== "undefined") {
                     // Set position.
                     trans.top = this.getIndex("ring_stop") * 50
                     trans.left = 10 * 15
                     trans.visible = true
                  }
               }
            }
         
   |outpipe
      @2
         \viz_alpha
            renderEach() {
               if ('$accepted'.asBool()) {
                  let uid = '/trans$uid'.asInt()
                  let trans = this.getScope("top").initResults.getTrans(uid)
                  if (typeof(trans) !== "undefined") {
                     // Set position.
                     trans.top = this.getIndex("ring_stop") * 50 - 15
                     trans.left = 8 * 15
                     trans.visible = true
                  }
               }
            }
            
