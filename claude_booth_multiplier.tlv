\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
   m4_makerchip_module
\TLV
   
   |booth
      @0
         $multiplicand[7:0] = 8'sd13;
         $multiplier[7:0] = 8'sd11;
         
         $reset = *reset;
         $start = ! $reset && (>>1$reset || >>1$done);
         
      @1
         $iter[3:0] = $reset ? 4'b0 :
                      $start ? 4'b0 :
                      $busy  ? >>1$iter + 1 : >>1$iter;
         
         $busy = ! $reset && ($start || (>>1$busy && >>1$iter < 4'd7));
         $done = >>1$busy && >>1$iter == 4'd7;
         $init = $start;
         
         $q0 = $init ? $multiplier[0] : >>1$acc_q[0];
         $q_1 = $init ? 1'b0 : >>1$acc_q_1;
         
         $booth_sel[1:0] = {$q0, $q_1};
         $do_add = $booth_sel == 2'b01;
         $do_sub = $booth_sel == 2'b10;
         
         $acc[8:0] = $init ? 9'b0 : >>1$acc_q[16:8];
         $mcand[8:0] = {{1{$multiplicand[7]}}, $multiplicand};
         
         $acc_op[8:0] = $do_add ? $acc + $mcand :
                        $do_sub ? $acc - $mcand :
                        $acc;
         
         $pre_shift[16:0] = {$acc_op, $init ? $multiplier : >>1$acc_q[7:0]};
         $acc_q[16:0] = {$pre_shift[16], $pre_shift[16:1]};
         $acc_q_1 = $pre_shift[0];
         
         $product[15:0] = $acc_q[15:0];
         $product_valid = $done;
         $expected[15:0] = $multiplicand * $multiplier;
         
         `BOGUS_USE($product_valid $expected $product)
         
         \viz_js
            box: {strokeWidth: 0},
            
            init() {
               let ret = {};
               
               ret.bg = new fabric.Rect({left: -10, top: -10, width: 340, height: 450, fill: "#1a2332", stroke: "#5a6a7a", strokeWidth: 2, rx: 8});
               ret.title = new fabric.Text("Booth Radix-2 Multiplier", {left: 55, top: 5, fontSize: 16, fontFamily: "monospace", fontWeight: "bold", fill: "#4da6ff"});
               
               // Input display
               ret.inputLabel = new fabric.Text("INPUTS", {left: 10, top: 28, fontSize: 9, fill: "#888"});
               ret.mcandText = new fabric.Text("", {left: 10, top: 40, fontSize: 10, fontFamily: "monospace", fill: "#7fef7f"});
               ret.mplierText = new fabric.Text("", {left: 10, top: 52, fontSize: 10, fontFamily: "monospace", fill: "#6699ff"});
               
               // Status display  
               ret.statusLabel = new fabric.Text("STATUS", {left: 220, top: 28, fontSize: 9, fill: "#888"});
               ret.iterText = new fabric.Text("", {left: 220, top: 40, fontSize: 10, fontFamily: "monospace", fill: "#ffff66"});
               ret.statusText = new fabric.Text("", {left: 220, top: 52, fontSize: 11, fontFamily: "monospace", fontWeight: "bold", fill: "#ffff66"});
               
               ret.div1 = new fabric.Line([5, 66, 325, 66], {stroke: "#5a6a7a", strokeWidth: 1});
               
               // Computation section
               ret.compLabel = new fabric.Text("COMPUTATION", {left: 10, top: 70, fontSize: 9, fill: "#888"});
               
               // Create text objects for computation lines (main part + last bit separate)
               for (let i = 0; i < 22; i++) {
                  ret["compLine" + i] = new fabric.Text("", {left: 0, top: 85 + i * 12, fontSize: 10, fontFamily: "monospace", fill: "#aaa"});
                  ret["compLineLast" + i] = new fabric.Text("", {left: 0, top: 85 + i * 12, fontSize: 10, fontFamily: "monospace", fill: "#00ff00"});
               }
               
               // Highlight rectangle for active computation
               ret.activeHighlight = new fabric.Rect({left: 0, top: 0, width: 0, height: 24,
                                                      fill: "rgba(255,255,255,0.1)", strokeWidth: 0, visible: false});
               
               // Result
               ret.productText = new fabric.Text("", {left: 10, top: 324, fontSize: 11, fontFamily: "monospace", fontWeight: "bold", fill: "#00ff00"});
               ret.expectedText = new fabric.Text("", {left: 230, top: 280, fontSize: 10, fontFamily: "monospace", fill: "#999"});
               ret.matchText = new fabric.Text("", {left: 230, top: 324, fontSize: 11, fontFamily: "monospace", fontWeight: "bold", fill: "#00ff00"});
               
               ret.div2 = new fabric.Line([5, 355, 325, 355], {stroke: "#5a6a7a", strokeWidth: 1});
               
               // STATE section
               ret.stateLabel = new fabric.Text("STATE (Hardware Registers)", {left: 10, top: 359, fontSize: 9, fill: "#888"});
               
               // Labels above the bit fields
               ret.accLabel = new fabric.Text("", {left: 0, top: 373, fontSize: 8, fontFamily: "monospace", fill: "#888"});
               ret.qLabel = new fabric.Text("", {left: 0, top: 373, fontSize: 8, fontFamily: "monospace", fill: "#888"});
               ret.boothLabel = new fabric.Text("", {left: 0, top: 373, fontSize: 8, fontFamily: "monospace", fill: "#ffaa00"});
               
               // Bit fields with separators - split into result portion and rest
               ret.accBitsResult = new fabric.Text("", {left: 0, top: 384, fontSize: 10, fontFamily: "monospace", fill: "#ffffff"});
               ret.accBitsRest = new fabric.Text("", {left: 0, top: 384, fontSize: 10, fontFamily: "monospace", fill: "#bbb"});
               ret.sep1 = new fabric.Text("", {left: 0, top: 384, fontSize: 10, fontFamily: "monospace", fill: "#666"});
               ret.qBits = new fabric.Text("", {left: 0, top: 384, fontSize: 10, fontFamily: "monospace", fill: "#bbb"});
               ret.sep2 = new fabric.Text("", {left: 0, top: 384, fontSize: 10, fontFamily: "monospace", fill: "#666"});
               ret.boothBits = new fabric.Text("", {left: 0, top: 384, fontSize: 10, fontFamily: "monospace", fill: "#ffff00"});
               
               ret.boothDecode = new fabric.Text("", {left: 10, top: 395, fontSize: 10, fontFamily: "monospace", fill: "#aaa"});
               ret.boothLegend = new fabric.Text("Booth {Q0,Q-1}: 00,11=NOP | 01=+A | 10=-A", {left: 130, top: 409, fontSize: 8, fill: "#777"});
               
               return ret;
            },
            
            render() {
               let mcand = '$multiplicand'.asInt();
               let mplier = '$multiplier'.asInt();
               let iter = '$iter'.asInt();
               let busy = '$busy'.asBool();
               let done = '$done'.asBool();
               
               // Set opacity of all Fabric Objects to 30% if not active, else 100%.
               const opacity = (busy || done) ? 1.0 : 0.3;
               debugger;
               Object.values(this.obj).forEach(obj => {
                   if (obj !== obj.box) {
                      obj.set({opacity: opacity});
                   }
               });
            
               // Signed conversions
               let mcandS = mcand > 127 ? mcand - 256 : mcand;
               let mplierS = mplier > 127 ? mplier - 256 : mplier;
               
               // Binary strings
               let mcandBin = (mcand & 0xFF).toString(2).padStart(8, "0");
               let mplierBin = (mplier & 0xFF).toString(2).padStart(8, "0");
               
               // Update inputs
               this.obj.mcandText.set({text: "A: " + mcandS.toString().padStart(4) + " (" + mcandBin + ")"});
               this.obj.mplierText.set({text: "B: " + mplierS.toString().padStart(4) + " (" + mplierBin + ")"});
               
               // Update status
               this.obj.iterText.set({text: "Iteration: " + iter + "/7"});
               let status = done ? "DONE" : busy ? "COMPUTING..." : "IDLE";
               let statusColor = done ? "#00ff00" : busy ? "#ffff66" : "#888888";
               this.obj.statusText.set({text: status, fill: statusColor});
               
               // Clear all computation lines
               for (let i = 0; i < 22; i++) {
                  this.obj["compLine" + i].set({text: "", fill: "#aaa"});
                  this.obj["compLineLast" + i].set({text: ""});
               }
               this.obj.activeHighlight.set({visible: false});
               
               // Character width and base positioning
               let charW = 6.0;
               let rightEdge = 280;  // Base right edge
               
               // Alignment shifts (in character positions from rightEdge)
               let headerShift = 12;     // multiplicand, multiplier, underbar
               let opShift = 12;         // addends/subtrahends
               let resultShift = 12;     // sums/differences
               let productShift = 5;    // final product and overbar
               let stateShift = 12;      // STATE vector
               
               // Current iteration for highlighting
               let currentIter = busy ? iter : -1;
               let baseIter = done ? iter + 1 : iter;
               
               // Header: multiplicand x multiplier (shift by headerShift)
               let mcandLeft = rightEdge - headerShift * charW - 8 * charW;
               
               this.obj.compLine0.set({text: mcandBin, left: mcandLeft, fill: "#7fef7f"});
               this.obj.compLine1.set({text: "x " + mplierBin, left: mcandLeft - 2 * charW, fill: "#6699ff"});
               this.obj.compLine2.set({text: "=".repeat(10), left: mcandLeft - 2 * charW, fill: "#888"});
               
               let lineIdx = 3;
               
               // Find final product (static for entire computation)
               let finalProd = 0;
               let haveFinal = false;
               for (let fwd = 0; fwd < 20; fwd++) {
                  let fwdDone = '$done'.step(fwd).asBool(false);
                  if (fwdDone) {
                     finalProd = '$product'.step(fwd - 1).asInt(0);
                     haveFinal = true;
                     break;
                  }
               }
               if (!haveFinal && done) {
                  finalProd = '$product'.step(-1).asInt(0);
                  haveFinal = true;
               }
               
               // Draw computation
               for (let row = 0; row < 8 && lineIdx < 20; row++) {
                  let cyclesBack = baseIter - row;
                  let rowBusy = '$busy'.step(-cyclesBack).asBool(false);
                  if (!rowBusy && row > 0) break;

                  let rowAdd = '$do_add'.step(-cyclesBack).asBool(false);
                  let rowSub = '$do_sub'.step(-cyclesBack).asBool(false);
                  let rowAccOp = '$acc_op'.step(-cyclesBack).asInt(0);

                  let isActive = (row == iter) && busy;

                  // Operation line (shift by opShift + row for diagonal)
                  let opLeft = rightEdge - (opShift + row) * charW - 10 * charW;

                  let opStr, opColor;
                  if (rowAdd) {
                     opStr = "+ " + mcandBin;
                     opColor = isActive ? "#7fef7f" : "#4a6a4a";
                  } else if (rowSub) {
                     opStr = "- " + mcandBin;
                     opColor = isActive ? "#ff7f7f" : "#6a4a4a";
                  } else {
                     opStr = "  NOP";
                     opColor = isActive ? "#aaaaaa" : "#555555";
                  }
                  this.obj["compLine" + lineIdx].set({text: opStr, left: opLeft, fill: opColor});

                  if (isActive) {
                     this.obj.activeHighlight.set({
                        left: opLeft - 5,
                        top: 85 + lineIdx * 12 - 2,
                        width: 12 * charW,
                        visible: true
                     });
                  }
                  lineIdx++;

                  // 9-bit result (shift by resultShift + row for diagonal)
                  let resultLeft = rightEdge - (resultShift + row) * charW - 9 * charW;

                  let accOpBin = (rowAccOp & 0x1FF).toString(2).padStart(9, "0");
                  let resultColor = isActive ? "#ffffff" : "#999999";

                  // Split: first 8 bits in result color, last bit in green
                  let first8 = accOpBin.slice(0, 8);
                  let lastBit = accOpBin.slice(8, 9);

                  this.obj["compLine" + lineIdx].set({text: first8, left: resultLeft, fill: resultColor});
                  this.obj["compLineLast" + lineIdx].set({text: lastBit, left: resultLeft + 8 * charW, fill: "#00ff00"});
                  lineIdx++;
               }

               // Final product line (shift by productShift)
               let prodBin = haveFinal ? (finalProd & 0xFFFF).toString(2).padStart(16, "0") : "????????????????";
               let finalLeft = rightEdge - (productShift + 7) * charW - 16 * charW;
               this.obj["compLine" + lineIdx].set({text: "=".repeat(16), left: finalLeft, fill: "#888"});
               lineIdx++;
               this.obj["compLine" + lineIdx].set({text: prodBin, left: finalLeft, fill: "#00ff00"});
               
               // STATE section - show all bits packed with separators
               // Fields: Acc[8:0] | Q[7:0] | {Q0,Q-1}[1:0]
               let stateAccQ = '$acc_q'.asInt();
               let stateBooth = '$booth_sel'.asInt();
               let stateAdd = '$do_add'.asBool();
               let stateSub = '$do_sub'.asBool();
               
               let accBin = ((stateAccQ >> 8) & 0x1FF).toString(2).padStart(9, "0");
               let qBin = (stateAccQ & 0xFF).toString(2).padStart(8, "0");
               let boothBin = stateBooth.toString(2).padStart(2, "0");

               // Shift display left by (stateShift + iter) positions
               let currentShift = busy ? iter : 7;
               let stateLeft = rightEdge - (stateShift + currentShift) * charW - 10 * charW;

               // Labels above fields (centered-ish)
               this.obj.accLabel.set({text: "  Acc", left: stateLeft - 1 * charW, visible: true});
               this.obj.qLabel.set({text: "  Q", left: stateLeft + 8 * charW, visible: true});
               this.obj.boothLabel.set({text: "{Q0,Q-1}", left: stateLeft + 17 * charW, visible: true});

               // Color the result portion (first 8 bits of Acc correspond to result)
               // Actually, the 9-bit acc_op result maps to the full Acc
               // For correlation with computation, color it white when active
               let accColor = busy ? "#ffffff" : "#bbb";

               // Bit fields with separators
               this.obj.accBitsResult.set({text: accBin, left: stateLeft, fill: accColor, visible: true});
               this.obj.accBitsRest.set({text: "", visible: false});
               this.obj.sep1.set({text: "|", left: stateLeft + 8.5 * charW, fill: "#666", visible: true});
               this.obj.qBits.set({text: qBin, left: stateLeft + 9 * charW, fill: "#bbb", visible: true});
               this.obj.sep2.set({text: "|", left: stateLeft + 16.5 * charW, fill: "#666", visible: true});
               this.obj.boothBits.set({text: boothBin, left: stateLeft + 17 * charW, fill: "#ffff00", visible: true});

               // Booth decode line
               let opLabel = stateAdd ? "+A" : stateSub ? "-A" : "NOP";
               let opColor = stateAdd ? "#7fef7f" : stateSub ? "#ff7f7f" : "#aaaaaa";
               let boothLine = "=> " + opLabel;
               this.obj.boothDecode.set({text: boothLine, left: stateLeft + 17 * charW, fill: opColor});
               
               // Result section
               let exp = '$expected'.asInt();
               let dispProd = haveFinal ? finalProd : (done ? '$product'.step(-1).asInt() : '$product'.asInt());
               let prodS = dispProd > 32767 ? dispProd - 65536 : dispProd;
               let expS = exp > 32767 ? exp - 65536 : exp;
               
               this.obj.productText.set({text: "Product: " + prodS + ":"});
               this.obj.expectedText.set({text: "Expected: " + expS + "\n= " + mcandS + " x " + mplierS});
               
               let match = haveFinal && (dispProd === exp);
               this.obj.matchText.set({text: match ? "CORRECT" : (haveFinal ? "ERROR" : ""), fill: match ? "#00ff00" : "#ff0000"});
            }
   
\SV
   endmodule
