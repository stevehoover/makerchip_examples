\m5_TLV_version 1d: tl-x.org
\m5
   // Logic Analyzer, based on https://www.linkedin.com/posts/frans-skarman-20b781171_how-long-would-it-take-you-to-write-an-integrated-activity-7393654048299659264-39DH
   // as a point of comparison with Spade.
   // Thanks to Frans Skarman for the initial Spade example and post.

   use(m5-1.0)

   // Parameters
   var(fifo_depth, 8)
   var(fifo_width, 24)
   define_hier(SAMPLE_BYTE, m5_calc(m5_fifo_width / 8), 0)
   var(viz_fifo_entry_height, (m5_calc(60 * 100 / (m5_fifo_depth - 1)) / 100))
\SV
   m4_include_url(['https://raw.githubusercontent.com/TL-X-org/tlv_flow_lib/f9ef7cce254dfdaaa714cf8dcc9e3ebe7d5e1fac/pipeflow_lib.tlv'])



// Inputs:
// |in
//    @1
//       $avail: Data available from upstream; must be presented contiguously.
//       /trans
//          $ANY: The input sample data.
// |out
//    @1
//       $blocked: Output backpressure.
// Outputs:
// |in
//    @1
//       $blocked: Backpressure (which blocks until FIFO empty).
// |out
//    @1
//       $avail: Data available to downstream.
//       $out_byte[7:0]: Output byte value.
\TLV quickscope(/_top)
   

   // Trigger logic

   |in
      @1
         // Trigger on $avail and FIFO empty and untrigger on FIFO full or ! $avail, terminating the burst.
         $Triggered <= $reset ? 1'b0 : 
                       ! $avail ? 1'b0 :
                       $avail && ! /_top|fifo_out>>1$avail ? 1'b1 :
                       $RETAIN;
         // Backpressure, applied when input data stream stops until FIFO empties.
         $must_empty = ! $Triggered && /_top|fifo_out>>1$avail;
         
   // The trigger logic blocks the input once the data begins streaming out until the FIFO empties.
   m5+connect(/_top, |in, @1, |fifo_in, @1, /trans, $reset, ['|| $must_empty'])


   // FIFO
   
   m5+simple_bypass_fifo_v2(/quickscope, |fifo_in, @1, |fifo_out, @1, m5_fifo_depth, m5_fifo_width, /trans)

   // Into Bytes

   |fifo_out
      @1
         $accepted = $avail && ! $blocked;
         // Vectorize the sample from the FIFO.
         $sample[m5_fifo_width-1:0] = {/trans$color[23:0]};
         $ByteCnt[m5_SAMPLE_BYTE_INDEX_MAX:0] <=
               $reset   ? 0 :
               /_top|out<>0$read_data ?
                           ($ByteCnt + 1) % m5_SAMPLE_BYTE_CNT :
               //default
                           $RETAIN;
         // Block FIFO until all bytes are sampled or if downstream is blocked (priority arbitor is not selecting this input).
         // Also block 
         $blocked = $ByteCnt != m5_SAMPLE_BYTE_MAX || ! /quickscope|out<>0$data_byte || /quickscope|out<>0$blocked;
         $sample_byte[7:0] = $sample\[$ByteCnt * 8 +: 8\];
      
   // Arbitrate and sequence output byte stream with framing and escaping

   // Following Frans's example, the byte stream gets injected header and footer, and
   // byte values are escaped:
   //   - Header bytes are injected: 0xFF, then 0x00, then byte count.
   //   - Footer byte is injected: 0xFF, then 0x01.
   //   - Data bytes equal to 0xFF and 0xFE are injected as:
   //     - 0xFF is injected as 0xFE, 0x7F.
   //     - 0xFE is injected as 0xFE, 0x7E.
   
   // We could instantiate arbiters, but it's probably easier to just code the logic here.
   // We combine the arbiter and the escape sequence inserter together.
   |out
      @1
         $reset = /_top|fifo_out<>0$reset;

         // SequenceCnt cycles through:
         //  0: Header byte 0xFF
         //  1: Header byte 0x00
         //  2: Header byte: byte count
         //  3: Data bytes (escaped as needed)
         //  4: Footer byte 0xFF
         //  5: Footer byte 0x01
         
         // Send a data byte or escape byte while the FIFO is non-empty.
         $data_byte = $SequenceCnt == 3'd3 && /quickscope|fifo_out<>0$avail;
         $accepted = $avail && ! $blocked;
         $SequenceCnt[2:0] <=
               // Reset to 0
               $reset   ? '0 :
               // Don't advance if output not accepted
               ! $accepted ? $RETAIN :
               // Retain if sending not-the-last byte or
               //                   an escape byte
               ($SequenceCnt == 3'd3) &&
               (// not last byte in the fifo
                ! ((/quickscope|fifo_out<>0$ByteCnt == m5_SAMPLE_BYTE_MAX) &&
                   (/quickscope|fifo_in/fifo<>0$cnt == 1)
                  ) ||
                // escape byte
                ($out_byte == 8'hFE)
               )        ? $RETAIN :
               // By default, advance to next state (with wrap-around)
                           ($SequenceCnt + 1) % 6;
         // Determine whether to output an escape byte and hold until the escaped byte sends.
         $needs_escape = /quickscope|fifo_out<>0$sample_byte[7:1] == 7'h7F;
         $escape = ($SequenceCnt == 3'd3) && $needs_escape &&
                   (>>1$accepted ^ >>1$escape);  // toggle on accepted
         // Sample byte width:
         $sample_width[7:0] = m5_SAMPLE_BYTE_CNT;
         $out_byte[7:0] =
               $SequenceCnt == 3'd0 ? 8'hFF :  // Header byte 0
               $SequenceCnt == 3'd1 ? 8'h00 :  // Header byte 1
               $SequenceCnt == 3'd2 ? $sample_width : // Header byte: byte count
               $escape              ? 8'hFE :  // Escape byte
               $SequenceCnt == 3'd3 ? (/quickscope|fifo_out<>0$sample_byte ^
                                       {$needs_escape, 7'd0}) :  // Data byte (possibly having been escaped)
               $SequenceCnt == 3'd4 ? 8'hFF :  // Footer byte 0
                                      8'h01 ;  // Footer byte 1
         $read_data = ! $blocked && $SequenceCnt == 3'd3 && ! $escape;
         // Output data is continuously available until sequence wraps and awaits FIFO data.
         $avail = $SequenceCnt != 3'd0 || /_top|fifo_out<>0$avail;
      


   // Visualization

   |in
      @1
         \viz_js
            where: {left: 0, top: -10},
            box: {width: 50, height: 50, top: -10, strokeWidth: 0},
            init() {
               let ret = {}
               
               // Input data box
               ret.data_box = new fabric.Rect({
                  left: 10, top: -5,
                  width: 30, height: m5_viz_fifo_entry_height - 1,
                  strokeWidth: 1, stroke: "#404040",
                  fill: "white"
               })
               
               ret.value = new fabric.Text("--", {
                  originX: "center", originY: "center",
                  left: 25.5, top: -5 + m5_viz_fifo_entry_height / 2,
                  fontSize: m5_viz_fifo_entry_height * 3/4, fontFamily: "monospace",
                  fill: "lightgray"
               })
               
               // Input data available (blue downward arrow)
               ret.in_avail_arrow = new fabric.Triangle({
                  originX: "center",
                  left: 25.5, top: 14,
                  width: 10, height: 10,
                  fill: "blue",
                  angle: 180,  // Point downward
                  opacity: 0.3
               })
               
               // Input blocked (black rectangle, bottom-to-top backpressure)
               ret.in_blocked_rect = new fabric.Rect({
                  originX: "center",
                  left: 25.5, top: 13,
                  width: 20, height: 7.5,
                  fill: "black",
                  opacity: 0.3
               })
               
               return ret
            },
            render() {
               let avail = '$avail'.asBool()
               let blocked = '$blocked'.asBool()
               let color = '/trans$color'.asInt()
               
               // Update input handshake indicators
               this.obj.in_avail_arrow.set({opacity: avail ? 1 : 0})
               this.obj.in_blocked_rect.set({opacity: blocked ? 1 : 0})
               
               const valueStr = color.toString(16).toUpperCase().padStart(m5_calc((m5_fifo_width + 3) / 4), "0")
               const colorStr = "#" + valueStr.substr(valueStr.length - 6)
               
               this.obj.data_box.set({
                  fill: avail ? colorStr : "white"
               })
               
               // Use black for light colors, white for dark colors
               let sum = 0
               for(let c = 0; c < 3; c++) {
                  sum += parseInt(valueStr.substr(c * 2, 2), 16)
               }
               const strColor = (sum > 0x180) ? "#000" : "#FFF"
               
               this.obj.value.set({
                  text: avail ? valueStr : "--",
                  fill: avail ? strColor : "lightgray"
               })
               
               return []
            }
   \viz_js
      box: {left: -19, top: -33, width: 320, height: 353, strokeWidth: 1, stroke: "#e0e0e0"},
      init() {
         let ret = {}
         
         // Background logic diagram
         ret.bg_img = this.newImageFromURL(
            "https://raw.githubusercontent.com/stevehoover/makerchip_examples/refs/heads/master/viz_imgs/quickscope_logic_diagram.png",
            "CC-BY-4.0 Frans Skarman",    // TODO: This isn't showing up.
            {left: -19, top: -33, width: 320, height: 353}
         )
         
         // Title
         ret.title = new fabric.Text("Quickscope Logic Analyzer", {
            left: 115, top: -25,
            originX: "center",
            fontSize: 12, fontFamily: "Arial", fontWeight: "bold",
            fill: "#2c3e50"
         })
         
         return ret
      },
      render() {
         debugger;
         
         return []
      }
   /fifo_entry[m5_calc(m5_fifo_depth-1):1]
      \viz_js
         where: {left: 10, top: 51, scale: 1},
         layout: {top: -m5_viz_fifo_entry_height},
         box: {width: 31, height: m5_viz_fifo_entry_height, strokeWidth: 1, stroke: "#404040"},
         init() {
            return {
               value: new fabric.Text("--", {
                  originX: "center", originY: "center",
                  left: 15, top: m5_viz_fifo_entry_height / 2,
                  fontSize: m5_viz_fifo_entry_height * 3/4, fontFamily: "monospace",
                  fill: "lightgray"
               })
            }
         },
         render() {
            debugger
            
            // For other entries, show FIFO array contents
            // Adjust index by -1 since we're skipping the head
            const physIndex = (this.sigVal("fifo.next_head").asInt() + this.getIndex() - 1) % m5_fifo_depth
            let valueSig = this.sigVal("fifo.arr[" + physIndex + "]")
            const valueStr = valueSig.asInt().toString(16).toUpperCase().padStart(m5_calc((m5_fifo_width + 3) / 4), "0")
            // Assuming the payload contains $color as low bits.
            const colorStr = "#" + valueStr.substr(valueStr.length - 6)
            const visible = this.getIndex() < this.sigVal("fifo.cnt").asInt()
            this.obj.box.set({
               fill: this.getIndex() < this.sigVal("fifo.cnt").asInt() ? colorStr : "white",
               opacity: 1
            })
            // Use black for light colors, white for dark colors, based on the sum of component values.
            let tmpValueStr = valueStr
            let sum = 0
            for(let c = 0; c < 3; c++) {
               let compVal = parseInt(tmpValueStr.substr(tmpValueStr.length - 2), 16)
               tmpValueStr = tmpValueStr.substr(0, tmpValueStr.length - 2)
               sum += compVal
            }
            const strColor = (sum > 0x180) ? "#000" : "#FFF"
            this.obj.value.set({
               text: valueStr,
               fill: visible ? strColor : "lightgray",
               visible: true //visible
            })
         }
   
   |fifo_out
      @1
         \viz_js
            where: {left: 7, top: 128},
            box: {width: 45, height: 19, strokeWidth: 1, stroke: "#404040"},
            init() {
               let ret = {}
               
               // FIFO data available (blue downward arrow out of FIFO)
               ret.fifo_avail_arrow = new fabric.Triangle({
                  originX: "center",
                  left: 19, top: 29,
                  width: 10, height: 10,
                  fill: "blue",
                  angle: 180,  // Point downward
                  opacity: 0.3
               })
               
               // FIFO blocked (black rectangle, right-to-left backpressure)
               ret.fifo_blocked_rect = new fabric.Rect({
                  originX: "center",
                  left: 18, top: -7,
                  width: 20, height: 7.5,
                  fill: "black",
                  opacity: 0.3
               })
               
               // Three byte component boxes
               for (let i = 0; i < 3; i++) {
                  ret[`byte${i}_rect`] = new fabric.Rect({
                     left: (2-i) * 15 + 0.5, top: 5,
                     width: 11, height: 10,
                     fill: "#000",
                     strokeWidth: 2,
                     stroke: "#000"  // Will be white for selected byte
                  })
                  
                  ret[`byte${i}_text`] = new fabric.Text("", {
                     left: (2-i) * 15 + 7, top: 11,
                     originX: "center", originY: "center",
                     fontSize: 6, fontFamily: "monospace",
                     fill: "#FFF"
                  })
               }
               
               return ret
            },
            preRender() {
               // Compute byte colors once and store in .data for child scopes to use
               let sample = '$sample'.asInt()
               let avail = '$avail'.asBool()
               
               // Store byte component colors
               '|fifo_out'.data.byteColors = []
               for (let i = 0; i < 3; i++) {
                  if (avail) {
                     let byteVal = (sample >> (i * 8)) & 0xFF
                     let r = (i === 2) ? byteVal : 0
                     let g = (i === 1) ? byteVal : 0
                     let b = (i === 0) ? byteVal : 0
                     '|fifo_out'.data.byteColors[i] = {
                        color: "#" + 
                           r.toString(16).toUpperCase().padStart(2, "0") +
                           g.toString(16).toUpperCase().padStart(2, "0") +
                           b.toString(16).toUpperCase().padStart(2, "0"),
                        byteVal: byteVal,
                        brightness: (r + g + b) / 3
                     }
                  } else {
                     '|fifo_out'.data.byteColors[i] = null
                  }
               }
               
               // Also store commonly used values
               '|fifo_out'.data.sample = sample
               '|fifo_out'.data.avail = avail
               '|fifo_out'.data.byte_cnt = '$ByteCnt'.asInt()
            },
            render() {
               let sample = '|fifo_out'.data.sample
               let byte_cnt = '|fifo_out'.data.byte_cnt
               let avail = '|fifo_out'.data.avail
               let seq_cnt = '/quickscope|out<>0$SequenceCnt'.asInt()
               
               // Update FIFO handshake indicators
               let blocked = '$blocked'.asBool()
               this.obj.fifo_avail_arrow.set({opacity: avail ? 1 : 0})
               this.obj.fifo_blocked_rect.set({opacity: blocked ? 1 : 0})
               
               // Color the box with the full sample color
               let colorStr = "#" + sample.toString(16).toUpperCase().padStart(6, "0")
               
               // Highlight box border when sequence count is 3 (data byte state) and data is available.
               const sample_active = seq_cnt === 3 && avail
               this.obj.box.set({
                  fill: avail ? colorStr : "#888",
                  stroke: sample_active ? "#FFFF00" : "#404040"
               })
               
               // Show each byte component using precomputed colors
               for (let i = 0; i < 3; i++) {
                  let byteInfo = '|fifo_out'.data.byteColors[i]
                  let byteStr = byteInfo ? byteInfo.byteVal.toString(16).toUpperCase().padStart(2, "0") : "--"
                  
                  // Determine border color: yellow when active and current, gold when current but not active, black otherwise
                  let borderColor = "#000"
                  if (byte_cnt === i) {
                     borderColor = sample_active ? "#FFFF00" : "#c0b600"  // Yellow when active, gold otherwise
                  }
                  
                  this.obj[`byte${i}_rect`].set({
                     fill: byteInfo ? byteInfo.color : "#000",
                     stroke: borderColor
                  })
                  
                  this.obj[`byte${i}_text`].set({
                     text: byteStr
                  })
               }
               
               return []
            }
   |out
      @1
         \viz_js
            where: {left: 0, top: 130},
            box: {width: 155, height: 145, strokeWidth: 0, stroke: "#404040", fill: "transparent"},
            init() {
               let ret = {}
               
               // Output data available (green downward arrow out of arbiter)
               ret.out_avail_arrow = new fabric.Triangle({
                  originX: "center",
                  left: 85, top: 138,
                  width: 14, height: 12,
                  fill: "#40e040",
                  angle: 180,  // Point downward
                  opacity: 0.3
               })
               
               // Output blocked (black rectangle, bottom-to-top backpressure)
               ret.out_blocked_rect = new fabric.Rect({
                  originX: "center",
                  left: 85, top: 137,
                  width: 20, height: 7.5,
                  fill: "black",
                  opacity: 0.3
               })
               
               // Byte Stream Visualization (right side)
               ret.stream_label = new fabric.Text("Output Bytes (Current Packet):", {
                  left: 170, top: 65,
                  fontSize: 7, fontFamily: "monospace", fontWeight: "bold"
               })
               
               // Create boxes for last 20 bytes in the stream
               for (let i = 0; i < 20; i++) {
                  let x = 170 + (i % 5) * 27.5
                  let y = 80 + Math.floor(i / 5) * 15
                  ret[`stream_box${i}`] = new fabric.Rect({
                     left: x, top: y,
                     width: 25, height: 12,
                     fill: "#f0f0f0",
                     strokeWidth: 1,
                     stroke: "#ccc"
                  })
                  ret[`stream_bytes${i}`] = new fabric.Text("--", {
                     left: x + 12.5, top: y + 6,
                     originX: "center", originY: "center",
                     fontSize: 5.5, fontFamily: "monospace",
                     fill: "#555"
                  })
               }
               
               // Legend
               ret.legend_label = new fabric.Text("States:", {
                  left: 170, top: -25,
                  fontSize: 6, fontFamily: "monospace", fontWeight: "bold"
               })
               ret.legend1 = new fabric.Text("0: Header 0xFF", {
                  left: 170, top: -15,
                  fontSize: 5, fontFamily: "monospace", fill: "#2196F3"
               })
               ret.legend2 = new fabric.Text("1: Header 0x00", {
                  left: 170, top: -5,
                  fontSize: 5, fontFamily: "monospace", fill: "#2196F3"
               })
               ret.legend3 = new fabric.Text("2: Byte Count", {
                  left: 170, top: 5,
                  fontSize: 5, fontFamily: "monospace", fill: "#2196F3"
               })
               ret.legend4 = new fabric.Text("3: Data Bytes", {
                  left: 170, top: 15,
                  fontSize: 5, fontFamily: "monospace", fill: "#4CAF50"
               })
               ret.legend5 = new fabric.Text("4: Footer 0xFF", {
                  left: 170, top: 25,
                  fontSize: 5, fontFamily: "monospace", fill: "#FF9800"
               })
               ret.legend6 = new fabric.Text("5: Footer 0x01", {
                  left: 170, top: 35,
                  fontSize: 5, fontFamily: "monospace", fill: "#FF9800"
               })
               
               // Header bytes (3) and Footer bytes (2)
               this.labels = ["FF", "00", (m5_SAMPLE_BYTE_CNT).toString(16).padStart(2, "0"), "FF", "01"]
               this.positions = [60, 75, 90, 112, 127]  // Reuse left positions for header/footer
               this.corresponding_seq_cnt = [0, 1, 2, 4, 5]  // Corresponding sequence count.
               for (let i = 0; i < 5; i++) {
                  ret[`seq${i}_rect`] = new fabric.Rect({
                     left: this.positions[i], top: 3,
                     width: 11, height: 10,
                     fill: "#888",
                     strokeWidth: 2,
                     stroke: "#404040"
                  })

                  ret[`seq${i}_text`] = new fabric.Text(this.labels[i], {
                     left: this.positions[i] + 6, top: 9,
                     originX: "center", originY: "center",
                     fontSize: 5, fontFamily: "monospace",
                     fill: "#000"
                  })
               }
               
               // Escape box (positioned at 105 to the right and 110 above the main box, which is at 0,130)
               // So absolute position should be 105, 240 relative to the main visualization origin
               ret.escape_box = new fabric.Rect({
                  left: 105, top: 93,
                  width: 11, height: 10,
                  fill: "#E0E0E0",
                  strokeWidth: 2,
                  stroke: "#404040"
               })
               
               ret.escape_text = new fabric.Text("FE", {
                  left: 105 + 6, top: 93 + 6,
                  originX: "center", originY: "center",
                  fontSize: 6, fontFamily: "monospace",
                  fill: "#000"
               })
               
               // Output byte box (positioned above the |out arrowhead at 85, 268)
               // Relative to this viz at 0, 130: left = 85-0 = 85, top = 268-130-15 = 123 (15px above arrow)
               ret.out_byte_box = new fabric.Rect({
                  left: 78, top: 112,
                  width: 13, height: 12,
                  fill: "#888",
                  strokeWidth: 1,
                  stroke: "#FFFF00"
               })
               
               ret.out_byte_text = new fabric.Text("", {
                  left: 78 + 7, top: 112 + 7,
                  originX: "center", originY: "center",
                  fontSize: 7, fontFamily: "monospace",
                  fill: "#FFF"
               })
               
               // Blocking indicator (vertical black rectangle)
               // Positioned below and to the left of the sample data (which is at 7, 128)
               // Relative to this viz at 0, 130: left = 7-0 = 7, top = 128+17-130 = 15
               ret.read_blocked_rect = new fabric.Rect({
                  left: 55, top: 33.5,
                  width: 7.5, height: 20,
                  fill: "black",
                  opacity: 0.3
               })
               
               return ret
            },
            render() {
               let seq_cnt = '$SequenceCnt'.asInt()
               let out_byte = '$out_byte'.asInt()
               let avail = '$avail'.asBool()
               let escape = '$escape'.asBool()
               
               // Update output handshake indicators
               let out_blocked = '$blocked'.asBool()
               this.obj.out_avail_arrow.set({opacity: avail ? 1 : 0})
               this.obj.out_blocked_rect.set({opacity: out_blocked ? 1 : 0})
               
               // Display current output byte stream (history of bytes in the current packet)
               // Walk backward in time to collect output bytes in the current packet
               let searchSig = '$SequenceCnt'
               let acceptedSig = '$accepted'
               let outByteSig = '$out_byte'
               
               // Start from current cycle
               let maxSteps = 50 // Look back up to 50 cycles
               let packetBytes = []
               
               // Collect bytes going backward in time
               for (let backSteps = 0; backSteps < maxSteps; backSteps++) {
                  let seq = searchSig.asInt(-1)
                  let wasAccepted = acceptedSig.asBool(false)
                  let byte = outByteSig.asInt(0)
                  
                  // If this byte was accepted, add it to our history
                  if (wasAccepted && seq >= 0) {
                     packetBytes.unshift({
                        byte: byte,
                        seq: seq
                     })
                  }
                  
                  // Step all signals back by 1 cycle for next iteration
                  searchSig.step(-1)
                  acceptedSig.step(-1)
                  outByteSig.step(-1)
                  
                  // After stepping back, check if we've crossed into a previous packet
                  // (transitioned from state 0 to state 5, which means new packet boundary)
                  let nextSeq = searchSig.asInt(-1)
                  if (seq === 0 && nextSeq === 5) {
                     break
                  }
               }
               
               // Display the bytes (most recent at the end)
               // If there are more than 20 bytes, show only the most recent 20
               let startIndex = Math.max(0, packetBytes.length - 20)
               for (let i = 0; i < 20; i++) {
                  let dataIndex = startIndex + i
                  if (dataIndex < packetBytes.length) {
                     let byteData = packetBytes[dataIndex]
                     let byteVal = byteData.byte & 0xFF
                     let byteStr = byteVal.toString(16).toUpperCase().padStart(2, "0")
                     
                     // Color based on sequence state and byte value
                     let bgColor = "#f0f0f0"
                     let textColor = "#000"
                     
                     // Check if this is an escape byte (0xFE)
                     if (byteVal === 0xFE) {
                        bgColor = "#800000"  // Maroon for escape bytes
                        textColor = "#FFF"
                     } else if (byteData.seq === 0 || byteData.seq === 1 || byteData.seq === 2) {
                        bgColor = "#2196F3"  // Blue for header
                        textColor = "#FFF"
                     } else if (byteData.seq === 3) {
                        bgColor = "#4CAF50"  // Green for data
                        textColor = "#FFF"
                     } else if (byteData.seq === 4 || byteData.seq === 5) {
                        bgColor = "#FF9800"  // Orange for footer
                        textColor = "#FFF"
                     }
                     
                     this.obj[`stream_box${i}`].set({
                        fill: bgColor,
                        stroke: "#404040",
                        strokeWidth: 1
                     })
                     this.obj[`stream_bytes${i}`].set({
                        text: byteStr,
                        fill: textColor
                     })
                  } else {
                     this.obj[`stream_box${i}`].set({
                        fill: "#f0f0f0",
                        stroke: "#ccc",
                        strokeWidth: 1
                     })
                     this.obj[`stream_bytes${i}`].set({
                        text: "--",
                        fill: "#555"
                     })
                  }
               }
               
               // Update legend - make active state bold
               for (let i = 0; i < 6; i++) {
                  this.obj[`legend${i+1}`].set({
                     fontWeight: (i === seq_cnt) ? "bold" : "normal"
                  })
               }
               
               // Background color based on state
               let bgColor = ["#2196F3", "#2196F3", "#2196F3", "#4CAF50", "#FF9800", "#FF9800"][seq_cnt] || "#888"
               
               // Highlight active header/footer bytes
               for (let i = 0; i < 5; i++) {
                  let isActive = seq_cnt == this.corresponding_seq_cnt[i]  // Not data byte state
                  let color = isActive ? (i <= 2 ? "#2196F3" : "#FF9800") : "#888"
                  
                  this.obj[`seq${i}_rect`].set({
                     fill: avail ? color : "#888",
                     stroke: isActive ? "#FFFF00" : "#404040"
                  })
                  
                  this.obj[`seq${i}_text`].set({
                     fill: isActive ? "#FFFF00" : "#000"
                  })
               }
               
               // Update escape box - use maroon when escape is active
               let escapeActive = (seq_cnt === 3 && escape && avail)
               this.obj.escape_box.set({
                  fill: escapeActive ? "#800000" : "#E0E0E0",  // Maroon for escape
                  stroke: escapeActive ? "#FFFF00" : "#404040",
                  strokeWidth: escapeActive ? 2 : 1
               })
               
               this.obj.escape_text.set({
                  fill: escapeActive ? "#FFFF00" : "#000"
               })
               
               // Update output byte box
               let out_byte_val = out_byte & 0xFF
               let out_byte_str = out_byte_val.toString(16).toUpperCase().padStart(2, "0")
               debugger
               // Background color based on sequence state and byte value
               let outByteColor = bgColor  // Default to state color
               let textColor = "#FFF"

               if (!avail) {
                  // Not available - use gray background with dark text
                  outByteColor = "#888"
                  textColor = "#000"
               } else if (out_byte_val === 0xFE) {
                  // FE bytes are always shown in maroon (escape sequences)
                  outByteColor = "#800000"  // Maroon
                  textColor = "#FFF"
               } else if (seq_cnt === 3 && !escape) {
                  // For data bytes, use precomputed colors from parent scope
                  let byte_cnt = '/quickscope|fifo_out'.data.byte_cnt
                  let byteInfo = '/quickscope|fifo_out'.data.byteColors[byte_cnt]
                  
                  if (byteInfo) {
                     outByteColor = byteInfo.color
                     textColor = byteInfo.brightness > 0x80 ? "#000" : "#FFF"
                  }
               } else {
                  // For header/footer bytes, use white text
                  textColor = "#FFF"
               }
               
               // Determine border color: black if blocked, yellow otherwise
               let accepted = '$accepted'.asBool()
               let borderColor = !accepted ? "#000000" : "#FFFF00"
               
               this.obj.out_byte_box.set({
                  fill: outByteColor,
                  stroke: borderColor,
                  strokeWidth: 1
               })
               
               this.obj.out_byte_text.set({
                  text: avail ? out_byte_str : "--",
                  fill: textColor
               })
               
               // Update blocking indicator (show when in data state but blocked)
               let blocked = '$blocked'.asBool()
               let data_blocked = ! (seq_cnt === 3 && !escape)
               this.obj.read_blocked_rect.set({
                  opacity: data_blocked ? 1 : 0
               })
               
               return []
            }
                         


\SV
   m5_makerchip_module

\TLV
   $reset = *reset;
   
   /quickscope
      // Inputs
      |in
         @1
            $reset = /top<>0$reset;
            ?$avail
               /trans
                  // Generate colors that include escape sequences (0xFF and 0xFE bytes)
                  // Mix random colors with intentional escape-triggering values
                  m4_rand($rand_color, 23, 0)
                  m4_rand($use_escape_rand, 2, 0)  // 1/8 chance to use escape-triggering value
                  $use_escape = $use_escape_rand == 3'd0;

                  // Create test patterns with escape sequences:
                  // 0xFF in any byte position, or 0xFE in any byte position
                  m4_rand($escape_pattern, 1, 0)  // Which pattern to use
                  $escape_color[23:0] = 
                     $escape_pattern == 2'd0 ? 24'hFF_00_00 :  // Red with 0xFF
                     $escape_pattern == 2'd1 ? 24'h00_FF_00 :  // Green with 0xFF
                     $escape_pattern == 2'd2 ? 24'h00_00_FF :  // Blue with 0xFF
                                             24'hFE_FE_FE ;  // All bytes 0xFE
                  
                  $color[23:0] =
                       |in>>1$blocked ? >>1$color :
                       $use_escape    ? $escape_color :
                       //default to random
                                        $rand_color;
                  
            // When triggered (with 50% probability), hold $avail for $max cycles.
            m4_rand($trigger, 0, 0)
            m4_rand($max, 3, 0)
            $Cnt[3:0] <= $reset ? 0 :
                         // set to max when triggered
                         $Cnt == 0 && $trigger ? $max :
                         // hold at zero
                         $Cnt == 0 ? 0 :
                         $blocked ? $RETAIN :
                         //default, decrement
                                  $Cnt - 1;
                    
            $avail = ($Cnt != 0) && ! >>1$reset;
         /fifo  // fix simple_bypass_fifo_v2
      // Logic
      m5+quickscope(/quickscope)
      // Outputs
      |out
         @1
            m4_rand($blocked, 0, 0)
            `BOGUS_USE($avail)
   

   // Assert these to end simulation (before the cycle limit).
   *passed = *cyc_cnt > 400;
   *failed = 1'b0;

\SV
   endmodule
