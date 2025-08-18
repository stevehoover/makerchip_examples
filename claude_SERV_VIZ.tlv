\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   fn(import_js, Url, ?Dir, ?FileName, {
      var(ModuleFile, m4_get_url_file(m5_Url, js_modules['']m5_Dir, m5_FileName))
      ~(['import("/compile/']m5_makerchip_compile_id()['/results/']m5_ModuleFile['")'])
   })
   fn(get_js, Url, ?Dir, ?FileName, {
      nullify(m4_get_url_file(m5_Url, js_modules['']m5_Dir, m5_FileName))
   })
\TLV

   // Top-level SERV visualization structure
   // This file provides a hierarchical layout matching the SERV core module structure
   // Each scope contains a \viz_js block defining box and where properties for layout
   \viz_js
      box: {width: 1200, height: 800, strokeWidth: 1},
      lib: {
         // Library functions for bit visualization
         initBit: function({top, left, width = 8, height = 8}) {
            return new fabric.Rect({
               top: top,
               left: left,
               width: width,
               height: height,
               fill: "white",
               stroke: "gray",
               strokeWidth: 1,
               selectable: false
            });
         },

         setBit: function(bitRect, value, position) {
            // Set fill based on value (0=white, 1=black)
            bitRect.set("fill", value ? "black" : "white");

            // Set stroke color based on bit position (0-31, red to blue)
            const ratio = position / 31;
            const red = Math.round(255 * (1 - ratio));
            const blue = Math.round(255 * ratio);
            const strokeColor = `rgb(${red}, 0, ${blue})`;
            bitRect.set("stroke", strokeColor);
         },

         // Helper to create a color for bit position
         getBitPositionColor: function(position) {
            const ratio = position / 31;
            const red = Math.round(255 * (1 - ratio));
            const blue = Math.round(255 * ratio);
            return `rgb(${red}, 0, ${blue})`;
         },
         

         // Initialize a shift register visualization
         // Returns an object with all the visual elements
         // lsb: the bit position of the LSB of this register (default 0)
         // Bits are always displayed MSB on left, LSB on right
         initShiftRegister: function(name, {left = 0, top = 0, bitWidth = 8, bitHeight = 8, spacing = 1, maxBitsPerRow = 8, showLabel = true, labelSize = 5, lsb = 0, width, transparencyMask = null, ignoreBits = []}) {
             let ret = {};

             if (width === undefined) {
                 throw new Error("width parameter is required");
             }

             // Create label if requested
             if (showLabel) {
                 ret[`${name}_label`] = new fabric.Text(`${name}[${width-1}:0]:`, {
                     fontSize: labelSize, left: left, top: top - labelSize - 3
                 });
             }

             // Create bit rectangles - always display MSB to LSB (left to right)
             let p = 0;
             for (let i = 0; p < width; i++) {
                 // Skip ignored bits
                 if (ignoreBits.includes(i)) {
                     continue;
                 }
                 if (p != i) {
                     console.log(`bit: ${i}, ${p}`)
                 }

                 let row = Math.floor(p / maxBitsPerRow);
                 let bitsInThisRow = Math.min(maxBitsPerRow, width - row * maxBitsPerRow);
                 let colIndex = p % maxBitsPerRow;
                 let col = bitsInThisRow - 1 - colIndex;

                 let bitRect = '/top'.lib.initBit({
                     left: left + col * (bitWidth + spacing),
                     top: top + row * (bitHeight + spacing),
                     width: bitWidth, height: bitHeight
                 });

                 // Set the stroke color based on the actual bit position
                 let actualBitPosition = lsb + p;
                 let strokeColor = '/top'.lib.getBitPositionColor(actualBitPosition);
                 bitRect.set("stroke", strokeColor);

                 // Apply transparency mask if provided
                 if (transparencyMask !== null) {
                     let bitMask = 1 << actualBitPosition;
                     let isOpaque = (transparencyMask & bitMask) !== 0;
                     bitRect.set("opacity", isOpaque ? 1.0 : 0.3);
                 }

                 ret[`${name}_bit_${p}`] = bitRect;

                 // Add bit index labels showing actual bit position
                 ret[`${name}_bit_label_${p}`] = new fabric.Text(actualBitPosition.toString(), {
                     fontSize: Math.min(bitWidth * 0.4, 4), left: left + col * (bitWidth + spacing) + bitWidth/2,
                     top: top + row * (bitHeight + spacing) - 4.5, textAlign: "center", originX: "center",
                     fill: "gray", opacity: 0.5
                 });
                 
                 p++;  // Next position
             }

             return ret;
         },

         // Render a shift register's current state
         // highlightMask: bit positions set in this mask will be highlighted with yellow tint
         renderShiftRegister: function(sigVal, objContainer, name, {showHex = true, highlightChanges = false, highlightMask = 0, ignoreBits = []} = {}) {
             let width = sigVal.signal.width;
             let value = sigVal.asInt(0);

             // Update each bit (skipping ignored bits)
             let p = 0;
             for (let i = 0; p < width; i++) {
                 if (ignoreBits.includes(i)) continue;

                 let bitVal = (value >> i) & 1;
                 let bitObj = objContainer[`${name}_bit_${p}`];

                 if (bitObj) {
                     // Check if this bit should be highlighted
                     let isHighlighted = (highlightMask >> i) & 1;

                     // Set fill color based on value and highlight
                     let fillColor;
                     if (isHighlighted) {
                         // Highlighted bits: yellow-tinted
                         fillColor = bitVal ? "#B0B080" : "#FFFFA0";
                     } else {
                         // Normal bits: gray or white
                         fillColor = bitVal ? "gray" : "white";
                     }

                     bitObj.set("fill", fillColor);

                     // Optional: adjust opacity for changes
                     if (highlightChanges) {
                         bitObj.set("opacity", bitVal ? 1.0 : 0.7);
                     }
                 }
                 p++;
             }

             // Update hex value display if requested and object exists
             if (showHex && objContainer[`${name}_value`]) {
                 let hexStr = "0x" + value.toString(16).toUpperCase().padStart(Math.ceil(width/4), "0");
                 objContainer[`${name}_value`].set("text", hexStr);
             }
         },

         // Initialize a collection of shift registers with connections
         initShiftRegisterArray: function(signalArray, {left = 0, top = 0, verticalSpacing = 15, ...regOptions} = {}) {
            let ret = {};
            let currentTop = top;
            
            signalArray.forEach((sigVal, index) => {
               let regObjs = '/top'.lib.initShiftRegister(sigVal, {
                  left: left,
                  top: currentTop,
                  ...regOptions
               });
               
               // Merge into return object
               Object.assign(ret, regObjs);
               
               // Calculate height for next register
               let width = sigVal.signal.width;
               let rows = Math.ceil(width / (regOptions.maxBitsPerRow || 8));
               let bitHeight = regOptions.bitHeight || 8;
               let spacing = regOptions.spacing || 1;
               currentTop += rows * (bitHeight + spacing) + verticalSpacing;
            });
            
            return ret;
         },
         
         // Create an arrow showing data flow between registers
         initDataFlowArrow: function(fromName, fromBit, toName, toBit, objRefs, {color = "gray", style = "solid"} = {}) {
            // Find the positions of the source and destination bits
            let fromObj = objRefs[`${fromName}_bit_${fromBit}`];
            let toObj = objRefs[`${toName}_bit_${toBit}`];
            
            if (!fromObj || !toObj) return null;
            
            let fromX = fromObj.left + fromObj.width/2;
            let fromY = fromObj.top + fromObj.height;
            let toX = toObj.left + toObj.width/2;
            let toY = toObj.top;
            
            // Create a path with an arrow
            let path = `M ${fromX} ${fromY} L ${toX} ${toY}`;
            
            return new fabric.Path(path, {
               stroke: color,
               strokeWidth: 1,
               strokeDashArray: style === "dashed" ? [2, 2] : [],
               selectable: false
            });
         },
         
         // Animate a bit moving through a shift register
         animateShift: function(sigVal, objRefs, {direction = "right", duration = 200} = {}) {
            let width = sigVal.signal.width;
            let name = sigVal.signal.notFullName;
            let value = sigVal.asInt(0);
            
            // This would need fabric.js animation support
            // For now, just highlight the shifting pattern
            for (let i = 0; i < width; i++) {
               let bitObj = objRefs[`${name}_bit_${i}`];
               if (bitObj) {
                  // Temporarily brighten bits that are shifting
                  if (direction === "right" && i < width - 1) {
                     let nextBitVal = (value >> (i + 1)) & 1;
                     if (nextBitVal) {
                        bitObj.set("fill", "lightblue");
                        setTimeout(() => {
                           bitObj.set("fill", (value >> i) & 1 ? "black" : "white");
                        }, duration);
                     }
                  }
               }
            }
         }
      }
   /servant_top
      \viz_js
         box: {width: 1200, height: 800, strokeWidth: 1}
         
      /dut
         \viz_js
            box: {width: 1150, height: 750, strokeWidth: 1},
            where: {left: 25, top: 25, width: 1150, height: 750}
            
         /cpu2  // serv_rf_top wrapper
            \viz_js
               box: {width: 1100, height: 700, strokeWidth: 1},
               where: {left: 25, top: 25, width: 1100, height: 700}
               
            /cpu  // serv_top core
               \viz_js
                  box: {width: 900, height: 550, strokeWidth: 1},
                  where: {left: 50, top: 50, width: 900, height: 550},
                  lib: {
                      // ... existing functions ...

                      getLifecycleColor: function(phase) {
                          switch(phase) {
                              case "FETCH": return "#4FC3F7";      // Light blue
                              case "DECODE": return "#B39DDB";      // Light purple
                              case "INIT": return "#FFD54F";       // Yellow  
                              case "EXECUTE": return "#81C784";    // Green
                              case "IDLE": return "#BDBDBD";       // Gray
                              default: return "#FF5722";           // Red for error
                          }
                      },

                      isComponentActiveInPhase: function(component, phase, active_in_phase) {
                          return active_in_phase[component] || false;
                      },

                      formatInstructionHistory: function(history, maxCount = 5) {
                          return history.slice(0, maxCount).map(instr => 
                              `${instr.asm} (${instr.cycles_executing}cy)`
                          ).join(", ");
                      }
                  },
                  init() {
                     // Initialize decoder as null, will be set when import completes
                     this.decoder = null;
                     this.instruction = null;

                     // Import decoder asynchronously
                     m5_var(DecoderUrl, https://gitlab.com/luplab/rvcodecjs/-/raw/main/core)
                     m5_get_js(m5_DecoderUrl/Config.js)
                     m5_get_js(m5_DecoderUrl/Constants.js)
                     m5_get_js(m5_DecoderUrl/Instruction.js)
                     m5_get_js(m5_DecoderUrl/Encoder.js)
                     m5_import_js(m5_DecoderUrl/Decoder.js).then(({Decoder}) => {
                        this.Decoder = Decoder;
                     }).catch(err => {
                        console.error("Failed to load decoder:", err);
                        this.Decoder = null;
                     });
                  },
                  preRender() {
                      // Initialize the data object that children can access
                      let data = '/cpu'.data;
                      let cpu = "top.servant_sim.dut.cpu.cpu.";

                      // ===== GET CURRENT COUNT/BIT POSITION =====

                      try {
                          // Get the upper 3 bits [4:2]
                          let cnt_upper = this.svSigRef(cpu+"state.o_cnt").asInt(0);

                          // Try to access the internal cnt_lsb shift register
                          let cnt_lsb = this.svSigRef(cpu+"state.gen_cnt_w_eq_1.cnt_lsb").asInt(0);

                          // Convert the shift register to position: find position of the '1' bit
                          let cnt_lower = 0;
                          if (cnt_lsb & 0x8) cnt_lower = 3; // bit 3 set
                          else if (cnt_lsb & 0x4) cnt_lower = 2; // bit 2 set  
                          else if (cnt_lsb & 0x2) cnt_lower = 1; // bit 1 set
                          else if (cnt_lsb & 0x1) cnt_lower = 0; // bit 0 set

                          // Combine: full_count = upper_bits * 4 + lower_bits
                          data.current_bit = (cnt_upper * 4) + cnt_lower;
                      } catch(e) {
                          // Fallback to just upper bits
                          try {
                              let cnt_upper = this.svSigRef(cpu+"state.o_cnt").asInt(0);
                              data.current_bit = cnt_upper * 4; // Just show groups of 4
                          } catch(e2) {
                              data.current_bit = 0;
                          }
                      }

                      // ===== GET CURRENT INSTRUCTION =====

                      // Expose these:
                      data.instruction = 0;
                      data.instruction_valid = false;
                      data.instruction_asm = "---";
                      data.instruction_format = "---";
                      data.i_wb_rdt = this.svSigRef(cpu+"decode.i_wb_rdt");

                      try {
                          // Find when i_wb_en was last asserted (instruction load cycle)
                          let sig_obj = {
                              i_wb_en: this.svSigRef(cpu+"immdec.i_wb_en"),
                              i_wb_rdt: data.i_wb_rdt
                          };

                          let sigs = this.signalSet(sig_obj);

                          // Look for when i_wb_en was last asserted
                          for (let steps = 1; steps <= 70; steps++) {
                              sigs.step(-1);
                              let wb_en = sigs.sig("i_wb_en").asBool(false);

                              if (wb_en) {
                                  // Found when instruction was loaded
                                  let i_wb_rdt_partial = sigs.sig("i_wb_rdt").asInt(0);
                                  data.instruction = (i_wb_rdt_partial << 2) | 0x3;
                                  data.instruction_valid = true;
                                  break;
                              }
                          }

                          // Try to decode the instruction if we have the decoder available
                          if (data.instruction_valid && this.Decoder) {
                              try {
                                  let instruction_obj = new this.Decoder(data.instruction.toString(2).padStart(32, "0"), {});
                                  data.instruction_asm = instruction_obj.asm || "DECODED";
                                  data.instruction_format = instruction_obj.fmt || "?";
                              } catch(e) {
                                  data.instruction_asm = "INVALID";
                                  data.instruction_format = "?";
                              }
                          }

                      } catch(e) {
                          // Keep defaults
                      }

                      // ===== GET EXECUTION STATE =====

                      try {
                          data.cnt_en = this.svSigRef(cpu+"state.o_cnt_en").asBool(false);
                          data.cnt_done = this.svSigRef(cpu+"state.o_cnt_done").asBool(false);
                          data.init = this.svSigRef(cpu+"state.o_init").asBool(false);
                          data.wb_en = this.svSigRef(cpu+"immdec.i_wb_en").asBool(false);

                          // Determine execution phase
                          if (data.wb_en) {
                              data.phase = "LOAD";
                          } else if (data.cnt_en) {
                              data.phase = "EXECUTE";
                          } else if (data.cnt_done) {
                              data.phase = "DONE";
                          } else {
                              data.phase = "IDLE";
                          }

                      } catch(e) {
                          data.cnt_en = false;
                          data.cnt_done = false;
                          data.init = false;
                          data.wb_en = false;
                          data.phase = "UNKNOWN";
                      }

                      // ===== GET ACTIVE UNITS FROM DECODE =====

                      try {
                          // Get control signals to determine which units are active
                          data.active_units = {};

                          // ALU control signals
                          let alu_sub = this.svSigRef(cpu+"decode.o_alu_sub").asBool(false);
                          let rd_alu_en = this.svSigRef(cpu+"decode.o_rd_alu_en").asBool(false);
                          data.active_units.alu = alu_sub || rd_alu_en;

                          // Memory control signals
                          let dbus_en = this.svSigRef(cpu+"decode.o_dbus_en").asBool(false);
                          let rd_mem_en = this.svSigRef(cpu+"decode.o_rd_mem_en").asBool(false);
                          data.active_units.mem = dbus_en || rd_mem_en;

                          // CSR control signals
                          let csr_en = this.svSigRef(cpu+"decode.o_csr_en").asBool(false);
                          let rd_csr_en = this.svSigRef(cpu+"decode.o_rd_csr_en").asBool(false);
                          data.active_units.csr = csr_en || rd_csr_en;

                          // Control flow signals
                          let ctrl_jal_or_jalr = this.svSigRef(cpu+"decode.o_ctrl_jal_or_jalr").asBool(false);
                          let branch_op = this.svSigRef(cpu+"decode.o_branch_op").asBool(false);
                          let ctrl_pc_rel = this.svSigRef(cpu+"decode.o_ctrl_pc_rel").asBool(false);
                          data.active_units.ctrl = ctrl_jal_or_jalr || branch_op || ctrl_pc_rel;

                          // Buffer register control signals
                          let bufreg_rs1_en = this.svSigRef(cpu+"decode.o_bufreg_rs1_en").asBool(false);
                          let bufreg_imm_en = this.svSigRef(cpu+"decode.o_bufreg_imm_en").asBool(false);
                          data.active_units.bufreg = bufreg_rs1_en || bufreg_imm_en;

                          // Register file control signals
                          let rd_op = this.svSigRef(cpu+"decode.o_rd_op").asBool(false);
                          data.active_units.rf = rd_op;

                          // Two-stage operation indicator
                          data.active_units.two_stage = this.svSigRef(cpu+"decode.o_two_stage_op").asBool(false);

                          // Immediate decoder signals
                          let immdec_en = this.svSigRef(cpu+"decode.o_immdec_en").asInt(0);
                          data.active_units.immdec = (immdec_en != 0);

                      } catch(e) {
                          // Keep empty active_units object
                          data.active_units = {};
                      }

                      // ===== INSTRUCTION TYPE ANALYSIS =====

                      try {
                          if (data.instruction_valid) {
                              let instr = data.instruction;
                              let opcode = (instr >> 2) & 0x1F; // bits [6:2]

                              // Determine instruction type based on opcode
                              if (opcode == 0x0D) data.instruction_type = "LUI";
                              else if (opcode == 0x05) data.instruction_type = "AUIPC";
                              else if (opcode == 0x1B) data.instruction_type = "JAL";
                              else if (opcode == 0x19) data.instruction_type = "JALR";
                              else if (opcode == 0x18) data.instruction_type = "BRANCH";
                              else if (opcode == 0x00) data.instruction_type = "LOAD";
                              else if (opcode == 0x08) data.instruction_type = "STORE";
                              else if (opcode == 0x04) data.instruction_type = "OP-IMM";
                              else if (opcode == 0x0C) data.instruction_type = "OP";
                              else if (opcode == 0x03) data.instruction_type = "FENCE";
                              else if (opcode == 0x1C) data.instruction_type = "SYSTEM";
                              else data.instruction_type = "UNKNOWN";
                          } else {
                              data.instruction_type = "NONE";
                          }
                      } catch(e) {
                          data.instruction_type = "ERROR";
                      }

                      // ===== NEW: ENHANCED INSTRUCTION LIFECYCLE ANALYSIS =====

                      try {
                          // Determine if this is a two-stage operation
                          data.is_two_stage = data.active_units.two_stage || 
                                            ["LOAD", "STORE", "BRANCH", "JAL", "JALR"].includes(data.instruction_type) ||
                                            data.instruction_type === "SYSTEM"; // shifts and SLT are also two-stage

                           // Enhanced lifecycle phase determination - corrected DECODE logic
                           data.lifecycle_phase = "UNKNOWN";
                           data.cycle_in_phase = 0;
                           data.stage_number = 0;

                           try {
                               let ibus_ack = this.svSigRef(cpu+"state.i_ibus_ack").asBool(false);
                               let rf_rreq = this.svSigRef(cpu+"state.o_rf_rreq").asBool(false);
                               let rf_ready = this.svSigRef(cpu+"state.i_rf_ready").asBool(false);
                               let ibus_cyc = this.svSigRef(cpu+"state.o_ibus_cyc").asBool(false);
                               let branch_op = this.svSigRef(cpu+"decode.o_branch_op").asBool(false);

                               // Get previous cycle state using signalSet for transitions
                               let prev_cnt_done = false;
                               let prev_init = false;
                               let prev_ibus_ack = false;
                               let prev_rf_rreq = false;

                               try {
                                   let sig_obj = {
                                       cnt_done: this.svSigRef(cpu+"state.o_cnt_done"),
                                       init: this.svSigRef(cpu+"state.o_init"),
                                       ibus_ack: this.svSigRef(cpu+"state.i_ibus_ack"),
                                       rf_rreq: this.svSigRef(cpu+"state.o_rf_rreq")
                                   };
                                   let sigs = this.signalSet(sig_obj);
                                   sigs.step(-1);  // Go back 1 cycle
                                   prev_cnt_done = sigs.sig("cnt_done").asBool(false);
                                   prev_init = sigs.sig("init").asBool(false);
                                   prev_ibus_ack = sigs.sig("ibus_ack").asBool(false);
                                   prev_rf_rreq = sigs.sig("rf_rreq").asBool(false);
                               } catch(e) {
                                   // If we can't look back, just use defaults
                               }

                               // RTL-accurate phase detection

                               // 1. EXECUTE phase - cnt_en=1 and init=0
                               debugger;
                               if (data.cnt_en && !data.init) {
                                   if (data.is_two_stage) {
                                       data.lifecycle_phase = "EXECUTE";
                                       data.stage_number = 2;
                                   } else {
                                       data.lifecycle_phase = "EXECUTE";
                                       data.stage_number = 1;
                                   }
                                   data.cycle_in_phase = data.current_bit;

                               // 2. INIT phase - cnt_en=1 and init=1 (two-stage only)
                               } else if (data.init && data.cnt_en) {
                                   data.lifecycle_phase = "INIT";
                                   data.cycle_in_phase = data.current_bit;
                                   data.stage_number = 1;

                               // 3. FETCH phase - ibus transaction active
                               } else if (data.wb_en || ibus_cyc) {
                                   data.lifecycle_phase = "FETCH";
                                   data.cycle_in_phase = 0;

                               // 4. DECODE phase - correct logic based on RTL
                               } else if (ibus_ack || rf_rreq || prev_ibus_ack || 
                                          (prev_rf_rreq && rf_ready) ||
                                          (!data.cnt_en && data.instruction_valid && !prev_cnt_done && !prev_init)) {
                                   data.lifecycle_phase = "DECODE";
                                   data.cycle_in_phase = 0;

                               // 5. BRANCH_DECODE - special case for branches between INIT and EXECUTE  
                               } else if (prev_init && !data.init && !data.cnt_en && branch_op && data.instruction_valid) {
                                   data.lifecycle_phase = "BRANCH_DECODE";
                                   data.cycle_in_phase = 0;

                               // 6. INTER_INSTR - gap between instructions
                               } else if (prev_cnt_done && !ibus_cyc && !data.cnt_en && !rf_rreq && !data.instruction_valid) {
                                   data.lifecycle_phase = "INTER_INSTR";
                                   data.cycle_in_phase = 0;

                               // 7. Default to IDLE
                               } else {
                                   data.lifecycle_phase = "IDLE";
                                   data.cycle_in_phase = 0;
                               }

                           } catch(e) {
                               console.warn("Error in phase detection:", e);
                               data.lifecycle_phase = "IDLE";
                               data.cycle_in_phase = 0;
                           }

                           // Debug the decode detection
                           if (data.lifecycle_phase === "DECODE") {
                               console.log(`=== DECODE: ibus_ack=${ibus_ack}, rf_rreq=${rf_rreq}, prev_ibus_ack=${prev_ibus_ack}, rf_ready=${rf_ready} ===`);
                           }
                       } catch(e) {
                          console.warn("Error in lifecycle analysis:", e);
                          data.lifecycle_phase = "ERROR";
                          data.is_two_stage = false;
                       }
                        // Add this section to your preRender() function after the lifecycle analysis:

                        // Calculate total instruction cycles and progress
                        if (data.is_two_stage) {
                            data.total_instruction_cycles = 64; // 32 + 32
                            if (data.lifecycle_phase === "INIT") {
                                data.total_cycles_completed = data.cycle_in_phase;
                            } else if (data.lifecycle_phase === "EXECUTE") {
                                data.total_cycles_completed = 32 + data.cycle_in_phase;
                            } else {
                                data.total_cycles_completed = 64;
                            }
                        } else {
                            data.total_instruction_cycles = 32;
                            data.total_cycles_completed = data.cycle_in_phase;
                        }

                        // Calculate progress percentage
                        data.instruction_progress = Math.min(data.total_cycles_completed / data.total_instruction_cycles, 1.0);

                        // Determine which components should be active in current phase
                        data.active_in_phase = {
                            fetch: data.lifecycle_phase === "FETCH",
                            decode: data.lifecycle_phase === "FETCH" || data.lifecycle_phase === "DECODE",
                            immdec: data.lifecycle_phase === "INIT" || data.lifecycle_phase === "EXECUTE",
                            rf_read: data.lifecycle_phase === "INIT" || data.lifecycle_phase === "EXECUTE",
                            alu: data.lifecycle_phase === "EXECUTE" && data.active_units.alu,
                            bufreg: data.lifecycle_phase === "INIT" && data.active_units.bufreg,
                            bufreg2: data.active_units.mem || data.instruction_type.includes("SHIFT"),
                            mem_if: data.lifecycle_phase === "EXECUTE" && data.active_units.mem,
                            ctrl: data.lifecycle_phase === "EXECUTE" && data.active_units.ctrl,
                            csr: data.active_units.csr,
                            rf_write: data.lifecycle_phase === "EXECUTE"
                        };

                      // ===== NEW: INSTRUCTION HISTORY TRACKING =====

                      try {
                          // Initialize history if it doesn't exist
                          if (!this.instruction_history) {
                              this.instruction_history = [];
                          }

                          // Add new instruction to history when we start fetching
                          if (data.lifecycle_phase === "FETCH" && data.instruction_valid) {
                              // Check if this is a new instruction (not the same as the most recent)
                              let isNewInstruction = this.instruction_history.length === 0 ||
                                                   this.instruction_history[0].instruction !== data.instruction;

                              if (isNewInstruction) {
                                  this.instruction_history.unshift({
                                      instruction: data.instruction,
                                      asm: data.instruction_asm,
                                      type: data.instruction_type,
                                      format: data.instruction_format,
                                      is_two_stage: data.is_two_stage,
                                      fetch_cycle: this.current_cycle || 0,
                                      completed: false,
                                      cycles_executing: 0
                                  });

                                  // Keep only last 8 instructions
                                  if (this.instruction_history.length > 8) {
                                      this.instruction_history.pop();
                                  }
                              }
                          }

                          // Update cycle counts for executing instructions
                          if (this.instruction_history.length > 0) {
                              let currentInstr = this.instruction_history[0];
                              if (!currentInstr.completed) {
                                  if (data.lifecycle_phase === "DONE") {
                                      currentInstr.completed = true;
                                      currentInstr.total_cycles = currentInstr.cycles_executing;
                                  } else if (data.lifecycle_phase !== "IDLE") {
                                      currentInstr.cycles_executing++;
                                  }
                              }
                          }

                          // Expose history to other components
                          data.instruction_history = this.instruction_history;

                      } catch(e) {
                          console.warn("Error in instruction history tracking:", e);
                          data.instruction_history = [];
                      }

                      // ===== NEW: BUS ACTIVITY TRACKING =====

                      try {
                          // Track instruction bus activity
                          let ibus_cyc = this.svSigRef(cpu+"state.o_ibus_cyc").asBool(false);
                          let ibus_ack = this.svSigRef(cpu+"state.i_ibus_ack").asBool(false);

                          data.bus_activity = {
                              ibus_cyc: ibus_cyc,
                              ibus_ack: ibus_ack,
                              ibus_active: ibus_cyc && !ibus_ack,
                              fetch_in_progress: ibus_cyc
                          };

                          // Track data bus activity if memory operation
                          if (data.active_units.mem) {
                              try {
                                  let dbus_cyc = this.svSigRef(cpu+"state.o_dbus_cyc").asBool(false);
                                  let dbus_ack = this.svSigRef(cpu+"mem_if.i_dbus_ack").asBool(false);

                                  data.bus_activity.dbus_cyc = dbus_cyc;
                                  data.bus_activity.dbus_ack = dbus_ack;
                                  data.bus_activity.dbus_active = dbus_cyc && !dbus_ack;
                              } catch(e) {
                                  data.bus_activity.dbus_cyc = false;
                                  data.bus_activity.dbus_ack = false;
                                  data.bus_activity.dbus_active = false;
                              }
                          }

                      } catch(e) {
                          debugger;
                          data.bus_activity = {
                              ibus_cyc: false,
                              ibus_ack: false,
                              ibus_active: false,
                              fetch_in_progress: false
                          };
                      }

                      // ===== SUMMARY DEBUG OUTPUT (ENHANCED) =====

                      console.log("=== CPU CENTRAL DATA (ENHANCED) ===");
                      console.log(`Lifecycle: ${data.lifecycle_phase} (Stage ${data.stage_number})`);
                      console.log(`Bit: ${data.current_bit}/31, Cycle in phase: ${data.cycle_in_phase}`);
                      console.log(`Progress: ${(data.instruction_progress * 100).toFixed(1)}% (${data.total_cycles_completed}/${data.total_instruction_cycles})`);
                      console.log(`Instruction: 0x${data.instruction.toString(16).padStart(8, "0")} (${data.instruction_type})`);
                      console.log(`ASM: ${data.instruction_asm} [${data.is_two_stage ? "2-STAGE" : "1-STAGE"}]`);
                      console.log(`Active units:`, data.active_units);
                      console.log(`Bus activity:`, data.bus_activity);

                      if (data.instruction_history.length > 0) {
                          console.log(`Recent instructions: ${data.instruction_history.slice(0, 3).map(i => i.asm).join(", ")}`);
                      }
                  },
                  
               // SERV core main modules arranged in logical data flow order
   
               /lifecycle  // Global instruction lifecycle visualization
                  \viz_js
                     box: {width: 850, height: 120, strokeWidth: 1},
                     where: {left: 0, top: -30, width: 150, height: 30},
                     init() {
                        let ret = {};

                        // ===== MAIN TITLE =====
                        ret.title = new fabric.Text("SERV Instruction Lifecycle", {fontSize: 14, fontWeight: "bold", top: -20, left: 425, textAlign: "center", originX: "center", selectable: false});

                        // ===== LIFECYCLE PHASE VISUALIZATION =====

                        // Background timeline
                        ret.timeline_bg = new fabric.Rect({width: 800, height: 50, top: 10, left: 25, fill: "#f5f5f5", stroke: "#333", strokeWidth: 2, selectable: false});

                        // Define 8 phases: 6 single-cycle + 2 multi-cycle
                        let phases = [
                           {name: "FETCH1", color: "#4FC3F7", width: 60, is_multi: false},     // 1 cycle
                           {name: "FETCH2", color: "#4FC3F7", width: 60, is_multi: false},     // 1 cycle  
                           {name: "DECODE", color: "#B39DDB", width: 60, is_multi: false},     // 1 cycle
                           {name: "SETUP", color: "#9C27B0", width: 60, is_multi: false},     // 1 cycle
                           {name: "INIT", color: "#FFD54F", width: 120, is_multi: true},      // 32 cycles
                           {name: "WRITEBACK", color: "#FF7043", width: 60, is_multi: false}, // 1 cycle
                           {name: "PC_UPDATE", color: "#FFA726", width: 60, is_multi: false}, // 1 cycle
                           {name: "EXECUTE", color: "#81C784", width: 120, is_multi: true},   // 32 cycles
                        ];

                        // Create phase boxes with calculated positions
                        let currentLeft = 25;
                        phases.forEach((phase, i) => {
                           ret[`${phase.name.toLowerCase()}_phase`] = new fabric.Rect({width: phase.width, height: 50, top: 10, left: currentLeft, fill: phase.color, stroke: "#333", strokeWidth: 1, opacity: 0.3, selectable: false});
                           ret[`${phase.name.toLowerCase()}_label`] = new fabric.Text(phase.name, {fontSize: phase.is_multi ? 10 : 8, fontWeight: "bold", top: 30, left: currentLeft + phase.width/2, textAlign: "center", originX: "center", fill: "#333", selectable: false});
                           currentLeft += phase.width + 5; // Add 5px spacing between phases
                        });
                        
                        // Current phase indicator (animated arrow)
                        ret.phase_pointer = new fabric.Triangle({width: 20, height: 15, top: 65, left: 100, fill: "#FF5722", stroke: "#333", strokeWidth: 1, angle: 180, selectable: false});

                        // Progress bar within current multi-cycle phase (only shown for INIT/EXECUTE)
                        ret.progress_bar = new fabric.Rect({width: 0, height: 8, top: 15, left: 25, fill: "rgba(255, 87, 34, 0.8)", selectable: false});

                        // ===== INSTRUCTION INFORMATION =====

                        // Current instruction box
                        ret.current_instr_bg = new fabric.Rect({width: 780, height: 25, top: 75, left: 35, fill: "#fff", stroke: "#666", strokeWidth: 1, selectable: false});
                        ret.current_instr_label = new fabric.Text("Current:", {fontSize: 8, fontWeight: "bold", top: 78, left: 40, selectable: false});
                        ret.current_instr_text = new fabric.Text("No instruction", {fontSize: 10, fontFamily: "monospace", top: 85, left: 85, selectable: false});
                        ret.stage_indicator = new fabric.Text("1-STAGE", {fontSize: 8, fontWeight: "bold", top: 78, left: 650, fill: "#666", selectable: false});
                        ret.progress_text = new fabric.Text("0%", {fontSize: 10, fontWeight: "bold", top: 82, left: 720, fill: "#FF5722", selectable: false});

                        // ===== BUS ACTIVITY INDICATORS =====

                        ret.bus_label = new fabric.Text("Bus:", {fontSize: 8, top: 95, left: 40, selectable: false});
                        ret.ibus_indicator = new fabric.Circle({radius: 4, left: 70, top: 97, fill: "#ccc", stroke: "#333", strokeWidth: 1, selectable: false});
                        ret.ibus_label = new fabric.Text("IBUS", {fontSize: 6, top: 105, left: 70, textAlign: "center", originX: "center", selectable: false});
                        ret.dbus_indicator = new fabric.Circle({radius: 4, left: 100, top: 97, fill: "#ccc", stroke: "#333", strokeWidth: 1, selectable: false});
                        ret.dbus_label = new fabric.Text("DBUS", {fontSize: 6, top: 105, left: 100, textAlign: "center", originX: "center", selectable: false});

                        // ===== INSTRUCTION HISTORY =====

                        ret.history_label = new fabric.Text("Recent:", {fontSize: 8, top: 95, left: 140, selectable: false});
                        ret.history_text = new fabric.Text("", {fontSize: 8, fontFamily: "monospace", top: 95, left: 180, selectable: false});

                        // ===== CYCLE COUNTER =====

                        ret.cycle_label = new fabric.Text("Cycle:", {fontSize: 8, top: 95, left: 650, selectable: false});
                        ret.cycle_text = new fabric.Text("0/32", {fontSize: 10, fontWeight: "bold", fontFamily: "monospace", top: 93, left: 685, fill: "#666", selectable: false});
                        ret.bit_text = new fabric.Text("Bit: 0", {fontSize: 8, top: 105, left: 685, fontFamily: "monospace", fill: "#666", selectable: false});

                        ret.status_indicators_label = new fabric.Text("Status:", {fontSize: 8, fontWeight: "bold", top: 70, left: 25, selectable: false});
                        ret.rf_write_indicator = new fabric.Circle({radius: 5, left: 70, top: 72, fill: "#4CAF50", stroke: "#333", strokeWidth: 1, opacity: 0.3, selectable: false});
                        ret.rf_write_label = new fabric.Text("RF Write", {fontSize: 6, top: 82, left: 70, textAlign: "center", originX: "center", selectable: false});
                        ret.pc_update_indicator = new fabric.Circle({radius: 5, left: 140, top: 72, fill: "#FF9800", stroke: "#333", strokeWidth: 1, opacity: 0.3, selectable: false});
                        ret.pc_update_label = new fabric.Text("PC Update", {fontSize: 6, top: 82, left: 140, textAlign: "center", originX: "center", selectable: false});

                        return ret;
                     },
                     render() {
                        // Get centralized data from CPU
                        debugger;
                        let cpuData = '/cpu'.data;
                        cpu = "top.servant_sim.dut.cpu.cpu.";
                        console.log(`2-stage: ${cpuData.is_two_stage}`);

                        console.log("=== LIFECYCLE RENDER ===");
                        console.log(`Phase: ${cpuData.lifecycle_phase}, Progress: ${(cpuData.instruction_progress * 100).toFixed(1)}%`);

                        // ===== UPDATE PHASE HIGHLIGHTING =====

                        let phases = ["fetch", "decode", "init", "execute"];
                        phases.forEach(phase => {
                           let isActive = cpuData.lifecycle_phase.toLowerCase() === phase;
                           let phaseObj = this.obj[`${phase}_phase`];
                           let labelObj = this.obj[`${phase}_label`];

                           if (phaseObj && labelObj) {
                              phaseObj.set({
                                 opacity: isActive ? 1.0 : 0.3,
                                 strokeWidth: isActive ? 3 : 1
                              });

                              labelObj.set({
                                 fontWeight: isActive ? "bold" : "normal",
                                 fill: isActive ? "#000" : "#666"
                              });
                           }
                        });

                        // ===== UPDATE PHASE POINTER AND PROGRESS BAR =====

                        let phasePositions = {
                            "fetch": 75,       // center of fetch phase
                            "decode": 195,     // center of decode phase
                            "init": 305,       // center of init phase  
                            "execute": 415,    // center of execute phase
                        };

                        let currentPhase = cpuData.lifecycle_phase.toLowerCase();
                        let pointerPosition = phasePositions[currentPhase] || 105;

                        this.obj.phase_pointer.set({
                           left: pointerPosition,
                           fill: '/cpu'.lib.getLifecycleColor(cpuData.lifecycle_phase)
                        });

                        // Progress bar shows progress within current phase
                        let progressWidth = 0;
                        let progressLeft = 25;

                        if (currentPhase === "fetch") {
                           progressLeft = 25;
                           // Show realistic fetch progress based on actual bus state
                           if (cpuData.bus_activity && cpuData.bus_activity.ibus_cyc) {
                              debugger;
                              if (cpuData.bus_activity.ibus_ack) {
                                 // Bus transaction completing this cycle
                                 progressWidth = 160; // Full width - fetch complete
                              } else {
                                 // Bus transaction active, waiting for ack
                                 progressWidth = 80;  // Half width - request sent, waiting
                              }
                           } else {
                              // No bus activity - either starting or idle
                              progressWidth = 20;  // Minimal progress - just starting
                           }
                        } else if (currentPhase === "decode") {
                            progressLeft = 145;
                            progressWidth = 100 * 0.7; // Show decode as mostly complete quickly
                        } else if (currentPhase === "init") {
                           progressLeft = 185;
                           progressWidth = 160 * ((cpuData.cycle_in_phase + 1) / 32.0);
                        } else if (currentPhase === "execute") {
                           progressLeft = 345;
                           progressWidth = 160 * ((cpuData.cycle_in_phase + 1) / 32.0);
                        }

                        this.obj.progress_bar.set({
                           left: progressLeft,
                           width: Math.max(0, progressWidth),
                           opacity: (currentPhase !== "idle") ? 0.8 : 0.3
                        });

                        // RF Write active during EXECUTE when writing results
                        let rf_writing = (cpuData.lifecycle_phase === "EXECUTE" && cpuData.active_units.rf);
                        this.obj.rf_write_indicator.set({
                           opacity: rf_writing ? 1.0 : 0.3,
                           fill: rf_writing ? "#4CAF50" : "#C8E6C9"
                        });

                        // PC Update active at end of EXECUTE or when ctrl_pc_en is active
                        let pc_updating = (cpuData.lifecycle_phase === "EXECUTE" && cpuData.cycle_in_phase > 28) || 
                                          this.svSigRef(cpu+"state.o_ctrl_pc_en").asBool(false);
                        this.obj.pc_update_indicator.set({
                           opacity: pc_updating ? 1.0 : 0.3,
                           fill: pc_updating ? "#FF9800" : "#FFCC80"
                        });

                        // ===== UPDATE INSTRUCTION INFORMATION =====

                        if (cpuData.instruction_valid) {
                           let instrText = `${cpuData.instruction_asm} (0x${cpuData.instruction.toString(16).padStart(8, "0").toUpperCase()}) [${cpuData.instruction_type}]`;
                           this.obj.current_instr_text.set({
                              text: instrText,
                              fill: "#000"
                           });
                        } else {
                           this.obj.current_instr_text.set({
                              text: "No valid instruction",
                              fill: "#999"
                           });
                        }

                        // Stage indicator
                        let stageText = cpuData.is_two_stage ? "2-STAGE" : "1-STAGE";
                        let stageColor = cpuData.is_two_stage ? "#FF9800" : "#2196F3";

                        this.obj.stage_indicator.set({
                           text: stageText,
                           fill: stageColor
                        });

                        // Progress percentage
                        this.obj.progress_text.set({
                           text: `${(cpuData.instruction_progress * 100).toFixed(0)}%`
                        });

                        // ===== UPDATE BUS ACTIVITY =====

                        let busActivity = cpuData.bus_activity || {};

                        // IBUS indicator
                        this.obj.ibus_indicator.set({
                           fill: busActivity.ibus_active ? "#4CAF50" : (busActivity.ibus_cyc ? "#FFC107" : "#ccc"),
                           strokeWidth: busActivity.ibus_cyc ? 2 : 1
                        });

                        // DBUS indicator (only if memory operation)
                        let showDbus = cpuData.active_units && cpuData.active_units.mem;
                        this.obj.dbus_indicator.set({
                           opacity: showDbus ? 1.0 : 0.3,
                           fill: showDbus ? 
                                 (busActivity.dbus_active ? "#4CAF50" : (busActivity.dbus_cyc ? "#FFC107" : "#ccc")) : 
                                 "#ccc",
                           strokeWidth: (showDbus && busActivity.dbus_cyc) ? 2 : 1
                        });

                        // ===== UPDATE INSTRUCTION HISTORY =====

                        if (cpuData.instruction_history && cpuData.instruction_history.length > 0) {
                           let historyText = cpuData.instruction_history
                              .slice(1, 4) // Skip current instruction, show next 3
                              .map(instr => instr.asm || "???")
                              .join(", ");

                           this.obj.history_text.set({
                              text: historyText,
                              fill: "#666"
                           });
                        } else {
                           this.obj.history_text.set({
                              text: "No history",
                              fill: "#ccc"
                           });
                        }

                        // ===== UPDATE CYCLE INFORMATION =====

                        let cycleText = `${cpuData.total_cycles_completed}/${cpuData.total_instruction_cycles}`;
                        this.obj.cycle_text.set({
                           text: cycleText,
                           fill: cpuData.lifecycle_phase !== "IDLE" ? "#333" : "#999"
                        });

                        this.obj.bit_text.set({
                           text: `Bit: ${cpuData.current_bit}`,
                           fill: cpuData.lifecycle_phase !== "IDLE" ? "#666" : "#ccc"
                        });

                        // ===== BACKGROUND COLOR BASED ON ACTIVITY =====

                        let bgColor = "#f5f5f5";
                        if (cpuData.lifecycle_phase === "EXECUTE") {
                           bgColor = "#f0f8f0"; // Light green tint
                        } else if (cpuData.lifecycle_phase === "FETCH") {
                           bgColor = "#f0f8ff"; // Light blue tint
                        } else if (cpuData.lifecycle_phase === "INIT") {
                           bgColor = "#fffdf0"; // Light yellow tint
                        }

                        this.obj.timeline_bg.set({
                           fill: bgColor
                        });

                        // ===== INSTRUCTION BOX COLOR CODING =====

                        let instrBgColor = "#fff";
                        if (cpuData.instruction_valid) {
                           if (cpuData.lifecycle_phase === "EXECUTE") {
                              instrBgColor = "#e8f5e8"; // Light green
                           } else if (cpuData.lifecycle_phase === "FETCH") {
                              instrBgColor = "#e3f2fd"; // Light blue
                           }
                        }

                        this.obj.current_instr_bg.set({
                           fill: instrBgColor
                        });
                        // Add this debug section to see what's happening with IBUS:

                        try {
                            debugger;
                            let ibus_cyc = this.svSigRef(cpu+"state.o_ibus_cyc").asBool(false);
                            let ibus_ack = this.svSigRef(cpu+"state.i_ibus_ack").asBool(false);
                            let ibus_adr = this.svSigRef(cpu+"o_ibus_adr").asInt(0);

                            // Only log when IBUS state changes
                            this.prev_ibus_state = {
                               cyc: this.svSigRef(cpu+"state.o_ibus_cyc").step(-1).asBool(false),
                               ack: this.svSigRef(cpu+"state.i_ibus_ack").step(-1).asBool(false)
                            };

                            if (ibus_cyc !== this.prev_ibus_state.cyc || ibus_ack !== this.prev_ibus_state.ack) {
                                console.log(`=== IBUS STATE CHANGE ===`);
                                console.log(`cyc: ${this.prev_ibus_state.cyc} → ${ibus_cyc}`);
                                console.log(`ack: ${this.prev_ibus_state.ack} → ${ibus_ack}`);
                                console.log(`address: 0x${ibus_adr.toString(16)}`);
                                console.log(`phase: ${data.lifecycle_phase}`);
                            }

                        } catch(e) {
                            console.warn("IBUS debug failed:", e);
                        }
                     }
               /state  // serv_state - controls overall core state
                  \viz_js
                     box: {width: 150, height: 80, strokeWidth: 0},
                     where: {left: 50, top: 50, width: 150, height: 80},
                     lib: {
                        // Get current bit position (0-31) from SERV's counter implementation
                        getCurrentBitPosition: function () {
                           try {
                              // Get the upper 3 bits [4:2]
                              let cnt_upper = this.svSigRef("top.servant_sim.dut.cpu.cpu.state.o_cnt").asInt(0);

                              // Try to access the internal cnt_lsb shift register
                              let cnt_lsb = this.svSigRef("top.servant_sim.dut.cpu.cpu.state.gen_cnt_w_eq_1.cnt_lsb").asInt(0);

                              // Convert the shift register to position: find position of the '1' bit
                              let cnt_lower = 0;
                              if (cnt_lsb & 0x8) cnt_lower = 3; // bit 3 set
                              else if (cnt_lsb & 0x4) cnt_lower = 2; // bit 2 set  
                              else if (cnt_lsb & 0x2) cnt_lower = 1; // bit 1 set
                              else if (cnt_lsb & 0x1) cnt_lower = 0; // bit 0 set

                              // Combine: full_count = upper_bits * 4 + lower_bits
                              return (cnt_upper * 4) + cnt_lower;

                           } catch(e) {
                              // Fallback to the method we had before
                              try {
                                 let cnt_upper = this.svSigRef("top.servant_sim.dut.cpu.cpu.state.o_cnt").asInt(0);
                                 return cnt_upper * 4; // Just show groups of 4
                              } catch(e2) {
                                 return 0;
                              }
                           }
                        }
                     }
               /decode
                  \viz_js
                     box: {top: -10, width: 150, height: 80, strokeWidth: 1},
                     where: {left: 0, top: 0, width: 150, height: 80},
                     
                     init() {
                        return {
                           // Title
                           title: new fabric.Text("serv_decode", {
                              fontSize: 8,
                              fontWeight: "bold",
                              top: -5,
                              left: 75,
                              textAlign: "center",
                              originX: "center",
                              selectable: false
                           }),
                           
                           // Instruction display box
                           instr_box: new fabric.Rect({
                              width: 130,
                              height: 16,
                              top: 5,
                              left: 10,
                              fill: "lightgray",
                              stroke: "black",
                              strokeWidth: 1,
                              selectable: false
                           }),
                           
                           // Assembled instruction
                           asm_text: new fabric.Text("", {
                              fontSize: 7,
                              top: 6,
                              left: 15,
                              selectable: false
                           }),
                           
                           // Instruction format and hex
                           format_text: new fabric.Text("", {
                              fontSize: 5,
                              top: 15,
                              left: 15,
                              selectable: false
                           }),
                           
                           hex_text: new fabric.Text("", {
                              fontSize: 5,
                              top: 15,
                              left: 90,
                              fontFamily: "monospace",
                              selectable: false
                           }),
                           
                           // Progress bar background
                           progress_bar: new fabric.Rect({
                              width: 130,
                              height: 6,
                              top: 25,
                              left: 10,
                              fill: "white",
                              stroke: "black",
                              strokeWidth: 1,
                              selectable: false
                           }),
                           
                           // Progress bar fill
                           progress_fill: new fabric.Rect({
                              width: 0,
                              height: 6,
                              top: 25,
                              left: 10,
                              fill: "blue",
                              selectable: false
                           }),
                           
                           // Cycle counter
                           cycle_text: new fabric.Text("0/32", {
                              fontSize: 4,
                              top: 34,
                              left: 75,
                              textAlign: "center",
                              originX: "center",
                              selectable: false
                           }),
                           
                           // Control signal groups label
                           ctrl_label: new fabric.Text("Control Groups:", {
                              fontSize: 5,
                              top: 42,
                              left: 5,
                              fontWeight: "bold",
                              selectable: false
                           }),
                           
                           // Control signal indicators
                           alu_indicator: new fabric.Circle({
                              radius: 3,
                              left: 10,
                              top: 52,
                              fill: "#ff6b6b",
                              stroke: "black",
                              strokeWidth: 0.5,
                              selectable: false
                           }),
                           
                           alu_label: new fabric.Text("ALU", {
                              fontSize: 3,
                              top: 58,
                              left: 10,
                              textAlign: "center",
                              originX: "center",
                              selectable: false
                           }),
                           
                           mem_indicator: new fabric.Circle({
                              radius: 3,
                              left: 28,
                              top: 52,
                              fill: "#4ecdc4",
                              stroke: "black",
                              strokeWidth: 0.5,
                              selectable: false
                           }),
                           
                           mem_label: new fabric.Text("MEM", {
                              fontSize: 3,
                              top: 58,
                              left: 28,
                              textAlign: "center",
                              originX: "center",
                              selectable: false
                           }),
                           
                           csr_indicator: new fabric.Circle({
                              radius: 3,
                              left: 46,
                              top: 52,
                              fill: "#45b7d1",
                              stroke: "black",
                              strokeWidth: 0.5,
                              selectable: false
                           }),
                           
                           csr_label: new fabric.Text("CSR", {
                              fontSize: 3,
                              top: 58,
                              left: 46,
                              textAlign: "center",
                              originX: "center",
                              selectable: false
                           }),
                           
                           ctrl_indicator: new fabric.Circle({
                              radius: 3,
                              left: 64,
                              top: 52,
                              fill: "#96ceb4",
                              stroke: "black",
                              strokeWidth: 0.5,
                              selectable: false
                           }),
                           
                           ctrl_ind_label: new fabric.Text("CTRL", {
                              fontSize: 3,
                              top: 58,
                              left: 64,
                              textAlign: "center",
                              originX: "center",
                              selectable: false
                           }),
                           
                           buf_indicator: new fabric.Circle({
                              radius: 3,
                              left: 82,
                              top: 52,
                              fill: "#ffeaa7",
                              stroke: "black",
                              strokeWidth: 0.5,
                              selectable: false
                           }),
                           
                           buf_label: new fabric.Text("BUF", {
                              fontSize: 3,
                              top: 58,
                              left: 82,
                              textAlign: "center",
                              originX: "center",
                              selectable: false
                           }),
                           
                           rf_indicator: new fabric.Circle({
                              radius: 3,
                              left: 100,
                              top: 52,
                              fill: "#dda0dd",
                              stroke: "black",
                              strokeWidth: 0.5,
                              selectable: false
                           }),
                           
                           rf_label: new fabric.Text("RF", {
                              fontSize: 3,
                              top: 58,
                              left: 100,
                              textAlign: "center",
                              originX: "center",
                              selectable: false
                           }),
                           
                           stage_indicator: new fabric.Circle({
                              radius: 3,
                              left: 118,
                              top: 52,
                              fill: "#ff9ff3",
                              stroke: "black",
                              strokeWidth: 0.5,
                              selectable: false
                           }),
                           
                           stage_label: new fabric.Text("2ST", {
                              fontSize: 3,
                              top: 58,
                              left: 118,
                              textAlign: "center",
                              originX: "center",
                              selectable: false
                           }),
                           
                           // Overall validity border
                           valid_border: new fabric.Rect({
                              width: 148,
                              height: 78,
                              top: -10,
                              left: 0,
                              fill: "transparent",
                              stroke: "green",
                              strokeWidth: 2,
                              selectable: false
                           })
                        };
                     },
                     render() {
                         // Get centralized data from CPU
                         let cpuData = '/cpu'.data;
                         let cpu = "top.servant_sim.dut.cpu.cpu.";
                         
                         // Get current state signals
                         let cnt_en = this.svSigRef(cpu+"state.o_cnt_en").asBool(false);
                         let cnt_done = this.svSigRef(cpu+"state.o_cnt_done").asBool(false);
                         let init = this.svSigRef(cpu+"state.o_init").asBool(false);

                         // SET ALL DEFAULTS FIRST (objects retain state from previous render calls)

                         // Default instruction display
                         this.obj.asm_text.set({text: "---"});
                         this.obj.format_text.set({text: ""});
                         this.obj.hex_text.set({text: ""});
                         this.obj.instr_box.set({fill: "lightgray"});

                         // Default progress state  
                         this.obj.progress_bar.set({opacity: 0.3});
                         this.obj.progress_fill.set({opacity: 0.3, width: 0});
                         this.obj.cycle_text.set({text: "IDLE"});

                         // Default control indicators (all inactive)
                         this.obj.alu_indicator.set({opacity: 0.3});
                         this.obj.mem_indicator.set({opacity: 0.3});
                         this.obj.csr_indicator.set({opacity: 0.3});
                         this.obj.ctrl_indicator.set({opacity: 0.3});
                         this.obj.buf_indicator.set({opacity: 0.3});
                         this.obj.rf_indicator.set({opacity: 0.3});
                         this.obj.stage_indicator.set({opacity: 0.3});

                         // Default validity border
                         this.obj.valid_border.set({opacity: 0.3, stroke: "red"});

                         // Determine instruction execution state
                         let executing = cnt_en || init;

                         // Display instruction info from CPU data
                         if (cpuData.instruction_valid) {
                             this.obj.asm_text.set({text: cpuData.instruction_asm});
                             this.obj.format_text.set({text: cpuData.instruction_format});

                             let hex_display = "0x" + cpuData.instruction.toString(16).padStart(8, "0").toUpperCase();
                             this.obj.hex_text.set({text: hex_display});

                             // Update control indicators with active units from CPU data
                             this.obj.alu_indicator.set({opacity: cpuData.active_units.alu ? 1.0 : 0.3});
                             this.obj.mem_indicator.set({opacity: cpuData.active_units.mem ? 1.0 : 0.3});
                             this.obj.csr_indicator.set({opacity: cpuData.active_units.csr ? 1.0 : 0.3});
                             this.obj.ctrl_indicator.set({opacity: cpuData.active_units.ctrl ? 1.0 : 0.3});
                             this.obj.buf_indicator.set({opacity: cpuData.active_units.bufreg ? 1.0 : 0.3});
                             this.obj.rf_indicator.set({opacity: cpuData.active_units.rf ? 1.0 : 0.3});
                             this.obj.stage_indicator.set({opacity: cpuData.active_units.two_stage ? 1.0 : 0.3});

                             // Green border for valid instruction
                             this.obj.valid_border.set({
                                 opacity: executing ? 1.0 : 0.3,
                                 stroke: "green"
                             });
                         } else if (executing) {
                             // Executing but no valid instruction found
                             this.obj.asm_text.set({text: "UNKNOWN"});
                             this.obj.valid_border.set({
                                 opacity: 1.0,
                                 stroke: "orange"
                             });
                         }

                         // Color coding based on current execution state
                         let at_decode_now = cpuData.phase == "LOAD";
                         let fill_color = at_decode_now ? "lightblue" : 
                                         executing ? "lightyellow" : "lightgray";
                         this.obj.instr_box.set({fill: fill_color});

                         // Progress indication during execution
                         if (executing && cpuData.current_bit <= 31) {
                             let progress = Math.min(cpuData.current_bit / 31.0, 1.0);
                             this.obj.progress_fill.set({width: 130 * progress, opacity: 1.0});
                             this.obj.cycle_text.set({text: cpuData.current_bit + "/32"});
                             this.obj.progress_bar.set({opacity: 1.0});
                         } else if (cnt_done) {
                             this.obj.progress_fill.set({width: 130, opacity: 0.8});
                             this.obj.cycle_text.set({text: "DONE"});
                             this.obj.progress_bar.set({opacity: 0.8});
                         }
                         // else: keep the defaults set above (IDLE state)
                     }
               /immdec
                  \viz_js
                     box: {width: 450, height: 180, strokeWidth: 1},
                     where: {left: 0, top: 90, width: 150, height: 60},
                     init() {
                         let ret = {};
                         this.bit_size = 12;  // Parameterize bit visualization size

                         // Title
                         ret.title = new fabric.Text("serv_immdec", {
                             fontSize: 10, fontWeight: "bold",
                             left: 200, top: -15, textAlign: "center", originX: "center"
                         });

                         // ===== 1. ALL 32 INSTRUCTION BITS IN A SINGLE ROW =====

                         Object.assign(ret, '/top'.lib.initShiftRegister("instruction", {
                             bitWidth: this.bit_size, bitHeight: this.bit_size, spacing: 1, maxBitsPerRow: 32, labelSize: 6, showLabel: true,
                             left: 10, top: 10,
                             lsb: 2, width: 30, transparencyMask: 0x3FFFFFE0  // Bits 29:5 are immediate bits (opaque)
                         }));
                         ret.instruction_label.set({text: "Instruction [31:0]:"});

                         // ===== 2. IMMEDIATE FIELDS ALIGNED TO INSTRUCTION POSITIONS =====

                         let field_top = 40;
                         let bit_spacing = this.bit_size + 1;

                         // Order fields left-to-right by instruction bit position: [31], [30:25], [24:20], [19:12], [11:7]

                         // imm[31] - 1 bit, aligned to instruction bit 31 (leftmost position)
                         Object.assign(ret, '/top'.lib.initShiftRegister("imm31", {
                             bitWidth: this.bit_size, bitHeight: 10, labelSize: 4, showLabel: true,
                             left: 10 + 0 * bit_spacing, top: field_top,  // Leftmost position for highest bit
                             lsb: 31, width: 1
                         }));
                         ret.imm31_label.set({text: "imm[31]", top: field_top - 8});

                         // imm[30:25] - 6 bits, next position to the right
                         Object.assign(ret, '/top'.lib.initShiftRegister("imm30_25", {
                             bitWidth: this.bit_size, bitHeight: 10, maxBitsPerRow: 6, labelSize: 4, showLabel: true,
                             left: 10 + 1 * bit_spacing, top: field_top,
                             lsb: 25, width: 6
                         }));
                         ret.imm30_25_label.set({text: "imm[30:25]", top: field_top - 8});

                         // imm[24:20] - 5 bits, next position to the right
                         Object.assign(ret, '/top'.lib.initShiftRegister("imm24_20", {
                             bitWidth: this.bit_size, bitHeight: 10, maxBitsPerRow: 5, labelSize: 4, showLabel: true,
                             left: 10 + 7 * bit_spacing, top: field_top,
                             lsb: 20, width: 5
                         }));
                         ret.imm24_20_label.set({text: "imm[24:20]", top: field_top - 8});

                         // imm[19:12] - 8 bits from imm19_12_20, next position to the right
                         Object.assign(ret, '/top'.lib.initShiftRegister("imm19_12", {
                             bitWidth: this.bit_size, bitHeight: 10, maxBitsPerRow: 8, labelSize: 4, showLabel: true,
                             left: 10 + 12 * bit_spacing, top: field_top,
                             lsb: 12, width: 8, ignoreBits: [0]
                         }));
                         ret.imm19_12_label.set({text: "imm[19:12]", top: field_top - 8});

                         // imm[11:7] - 5 bits, rightmost position for lowest bits
                         Object.assign(ret, '/top'.lib.initShiftRegister("imm11_7", {
                             bitWidth: this.bit_size, bitHeight: 10, maxBitsPerRow: 5, labelSize: 4, showLabel: true,
                             left: 10 + 20 * bit_spacing, top: field_top,
                             lsb: 7, width: 5
                         }));
                         ret.imm11_7_label.set({text: "imm[11:7]", top: field_top - 8});

                         // ===== 3. IMMEDIATE FIELDS IN FINAL 32-BIT ORDER =====

                         let final_top = 80, final_left = 10;

                         // Labels for different immediate types (shown/hidden dynamically in render)
                         ret.i_type_label = new fabric.Text("I-type: imm[31:0] = {20{imm[31]}, imm[30:25], imm[24:20], imm[19:12], imm[11:7]}", {
                             fontSize: 5,
                             left: final_left, top: final_top, visible: false
                         });

                         ret.s_type_label = new fabric.Text("S-type: imm[31:0] = {20{imm[31]}, imm[30:25], imm[11:7]}", {
                             fontSize: 5,
                             left: final_left, top: final_top, visible: false
                         });

                         ret.b_type_label = new fabric.Text("B-type: imm[31:0] = {19{imm[31]}, imm[7], imm[30:25], imm[11:8], 1'b0}", {
                             fontSize: 5,
                             left: final_left, top: final_top, visible: false
                         });

                         ret.u_type_label = new fabric.Text("U-type: imm[31:0] = {imm[31], imm[30:25], imm[24:20], imm[19:12], 12'b0}", {
                             fontSize: 5,
                             left: final_left, top: final_top, visible: false
                         });

                         ret.j_type_label = new fabric.Text("J-type: imm[31:0] = {11{imm[31]}, imm[19:12], imm[11], imm[30:25], imm[24:21], 1'b0}", {
                             fontSize: 5,
                             left: final_left, top: final_top, visible: false
                         });

                         // Copies of immediate fields in final order - I-type (default layout)
                         // Layout: [31] [30:25] [24:20] [19:12] [11:7] from left to right
                         Object.assign(ret, '/top'.lib.initShiftRegister("final_imm31", {
                             bitWidth: this.bit_size, bitHeight: 8, labelSize: 3, showLabel: true,
                             left: final_left, top: final_top + 15,
                             lsb: 31, width: 1
                         }));
                         ret.final_imm31_label.set({text: "31"});

                         Object.assign(ret, '/top'.lib.initShiftRegister("final_imm30_25", {
                             bitWidth: this.bit_size, bitHeight: 8, maxBitsPerRow: 6, labelSize: 3, showLabel: true,
                             left: final_left + 1 * bit_spacing, top: final_top + 15,
                             lsb: 25, width: 6
                         }));
                         ret.final_imm30_25_label.set({text: "30:25"});

                         Object.assign(ret, '/top'.lib.initShiftRegister("final_imm24_20", {
                             bitWidth: this.bit_size, bitHeight: 8, maxBitsPerRow: 5, labelSize: 3, showLabel: true,
                             left: final_left + 7 * bit_spacing, top: final_top + 15,
                             lsb: 20, width: 5
                         }));
                         ret.final_imm24_20_label.set({text: "24:20"});

                         Object.assign(ret, '/top'.lib.initShiftRegister("final_imm19_12", {
                             bitWidth: this.bit_size, bitHeight: 8, maxBitsPerRow: 8, labelSize: 3, showLabel: true,
                             left: final_left + 12 * bit_spacing, top: final_top + 15,
                             lsb: 12, width: 8, ignoreBits: [0]
                         }));
                         ret.final_imm19_12_label.set({text: "19:12"});

                         Object.assign(ret, '/top'.lib.initShiftRegister("final_imm11_7", {
                             bitWidth: this.bit_size, bitHeight: 8, maxBitsPerRow: 5, labelSize: 3, showLabel: true,
                             left: final_left + 20 * bit_spacing, top: final_top + 15,
                             lsb: 7, width: 5
                         }));
                         ret.final_imm11_7_label.set({text: "11:7"});

                         // Final immediate value display
                         ret.final_imm_box = new fabric.Rect({
                             fill: "lightyellow", stroke: "black", strokeWidth: 1,
                             left: final_left, top: final_top + 35, width: 25 * bit_spacing, height: 15, visible: false
                         });

                         ret.final_imm_text = new fabric.Text("Final Immediate: 0x00000000", {
                             fontSize: 6, fontFamily: "monospace",
                             left: final_left + 5, top: final_top + 37, visible: false
                         });

                         // ===== OUTPUT BIT DISPLAY =====

                         ret.output_label = new fabric.Text("Current Output Bit:", {
                             fontSize: 6,
                             left: final_left, top: final_top + 55
                         });

                         ret.output_bit = new fabric.Circle({
                             radius: 8, fill: "white", stroke: "blue", strokeWidth: 2,
                             left: final_left + 120, top: final_top + 57
                         });

                         ret.output_value = new fabric.Text("0", {
                             fontSize: 8, textAlign: "center", originX: "center",
                             left: final_left + 120, top: final_top + 54
                         });

                         // ===== STATUS DISPLAY =====

                         ret.status_text = new fabric.Text("Status: IDLE", {
                             fontSize: 7,
                             left: final_left, top: final_top + 75
                         });

                         ret.bit_counter = new fabric.Text("Bit: 0/31", {
                             fontSize: 7,
                             left: final_left + 100, top: final_top + 75
                         });

                         return ret;
                     },
                     render() {
                         // Get centralized data from CPU
                         let data = '/cpu'.data;
                         let cpu = "top.servant_sim.dut.cpu.cpu.";
                         let immdec = "top.servant_sim.dut.cpu.cpu.immdec.";
                         let cpuData = '/cpu'.data;
                         let isActive = cpuData.active_in_phase["immdec"]; // e.g., 'alu', 'immdec'
                         let phaseColor = '/cpu'.lib.getLifecycleColor(cpuData.lifecycle_phase);

                         // Get current signals
                         let cnt_en = this.svSigRef(cpu+"state.o_cnt_en").asBool(false);
                         let i_wb_en = this.svSigRef(immdec + "i_wb_en").asBool(false);
                         let i_ctrl = this.svSigRef(immdec + "i_ctrl").asInt(0);
                         let i_immdec_en = this.svSigRef(immdec + "i_immdec_en").asInt(0);

                         // Get all shift register signals
                         let i_wb_rdt_sig = this.svSigRef(cpu+"decode.i_wb_rdt");
                         let imm31_sig = this.svSigRef(immdec + "gen_immdec_w_eq_1.imm31");
                         let imm30_25_sig = this.svSigRef(immdec + "gen_immdec_w_eq_1.imm30_25");
                         let imm24_20_sig = this.svSigRef(immdec + "gen_immdec_w_eq_1.imm24_20");
                         let imm19_12_sig = this.svSigRef(immdec + "gen_immdec_w_eq_1.imm19_12_20");
                         let imm11_7_sig = this.svSigRef(immdec + "gen_immdec_w_eq_1.imm11_7");

                         console.log(`=== IMMDEC: bit=${data.current_bit}, phase=${data.phase}, type=${data.instruction_type} ===`);

                         // Helper function to calculate final field positions based on instruction type
                         function calculateFinalPositions(instructionType, baseLeft, bitSpacing) {
                             // Position fields according to their bit positions in the final immediate value
                             // MSBs on the left, LSBs on the right (higher bit numbers = smaller left coordinates)
                             // Leave empty space for sign extension bits so data bits appear in correct absolute positions
                             let positions = {
                                 imm31: null,
                                 imm30_25: null,
                                 imm24_20: null,
                                 imm19_12: null,
                                 imm11_7: null,
                                 visible: {
                                     imm31: false,
                                     imm30_25: false,
                                     imm24_20: false,
                                     imm19_12: false,
                                     imm11_7: false
                                 }
                             };

                             // Calculate positions based on actual bit positions in 32-bit immediate
                             // baseLeft represents bit 31 position, each bitSpacing moves one bit to the right
                             switch(instructionType) {
                                 case "OP-IMM":
                                 case "LOAD":
                                 case "JALR":  // I-type: imm[11:0] = {instr[31], instr[30:20]}
                                     // imm[31:12] = sign extension (empty space), imm[11:0] = data
                                     positions.imm31 = baseLeft + (31-11) * bitSpacing;     // imm[11] ← instr[31] (bit 11 position)
                                     positions.imm30_25 = baseLeft + (31-10) * bitSpacing;  // imm[10:5] ← instr[30:25] (bits 10:5)
                                     positions.imm24_20 = baseLeft + (31-4) * bitSpacing;   // imm[4:0] ← instr[24:20] (bits 4:0)
                                     positions.visible = {imm31: true, imm30_25: true, imm24_20: true, imm19_12: false, imm11_7: false};
                                     break;

                                 case "STORE":  // S-type: imm[11:0] = {instr[31], instr[30:25], instr[11:7]}
                                     // imm[31:12] = sign extension (empty space), imm[11:0] = data
                                     positions.imm31 = baseLeft + (31-11) * bitSpacing;     // imm[11] ← instr[31] (bit 11 position)
                                     positions.imm30_25 = baseLeft + (31-10) * bitSpacing;  // imm[10:5] ← instr[30:25] (bits 10:5)
                                     positions.imm11_7 = baseLeft + (31-4) * bitSpacing;    // imm[4:0] ← instr[11:7] (bits 4:0)
                                     positions.visible = {imm31: true, imm30_25: true, imm24_20: false, imm19_12: false, imm11_7: true};
                                     break;

                                 case "BRANCH": // B-type: imm[12:0] = {instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}
                                     // imm[31:13] = sign extension (empty space), imm[12:0] = data
                                     positions.imm31 = baseLeft + (31-12) * bitSpacing;     // imm[12] ← instr[31] (bit 12 position)
                                     // Note: instr[7] → imm[11] would be at baseLeft + (31-11) * bitSpacing
                                     positions.imm30_25 = baseLeft + (31-10) * bitSpacing;  // imm[10:5] ← instr[30:25] (bits 10:5)
                                     positions.imm11_7 = baseLeft + (31-4) * bitSpacing;    // imm[4:1] ← instr[11:8] (bits 4:1, only 4 bits used)
                                     // imm[0] always 0 (empty space at rightmost position)
                                     positions.visible = {imm31: true, imm30_25: true, imm24_20: false, imm19_12: false, imm11_7: true};
                                     break;

                                 case "LUI":
                                 case "AUIPC":  // U-type: imm[31:0] = {instr[31:12], 12'b0}
                                     // imm[31:12] = data, imm[11:0] = zeros (empty space)
                                     positions.imm31 = baseLeft + (31-31) * bitSpacing;     // imm[31] ← instr[31] (bit 31 position)
                                     positions.imm30_25 = baseLeft + (31-30) * bitSpacing;  // imm[30:25] ← instr[30:25] (bits 30:25)
                                     positions.imm24_20 = baseLeft + (31-24) * bitSpacing;  // imm[24:20] ← instr[24:20] (bits 24:20)
                                     positions.imm19_12 = baseLeft + (31-19) * bitSpacing;  // imm[19:12] ← instr[19:12] (bits 19:12)
                                     // imm[11:0] = zeros (empty space)
                                     positions.visible = {imm31: true, imm30_25: true, imm24_20: true, imm19_12: true, imm11_7: false};
                                     break;

                                 case "JAL":    // J-type: imm[20:0] = {instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}
                                     // imm[31:21] = sign extension (empty space), imm[20:0] = data
                                     positions.imm31 = baseLeft + (31-20) * bitSpacing;     // imm[20] ← instr[31] (bit 20 position)
                                     positions.imm19_12 = baseLeft + (31-19) * bitSpacing;  // imm[19:12] ← instr[19:12] (bits 19:12)
                                     // Note: instr[20] → imm[11] would be at baseLeft + (31-11) * bitSpacing
                                     positions.imm30_25 = baseLeft + (31-10) * bitSpacing;  // imm[10:5] ← instr[30:25] (bits 10:5)
                                     positions.imm24_20 = baseLeft + (31-4) * bitSpacing;   // imm[4:1] ← instr[24:21] (bits 4:1, only 4 bits used)
                                     // imm[0] always 0 (empty space at rightmost position)
                                     positions.visible = {imm31: true, imm30_25: true, imm24_20: true, imm19_12: true, imm11_7: false};
                                     break;
                             }

                             return positions;
                         }

                         // Helper function to create connection lines between sections 2 and 3
                         function createConnectionLines(baseLeft, bitSpacing, finalPositions, bit_size) {
                             let lines = [];
                             let field_top = 40;
                             let final_top = 80;
                             let lineColor = "rgba(100, 100, 100, 0.5)";

                             // Calculate the actual positions of the instruction-aligned fields in row 2
                             // These should match the positions used in the init() function for row 2
                             let row2_positions = {
                                 imm31: 10 + 0 * bitSpacing,           // imm31 - 1 bit, leftmost position
                                 imm30_25: 10 + 1 * bitSpacing,       // imm30_25 - 6 bits, next position
                                 imm24_20: 10 + 7 * bitSpacing,       // imm24_20 - 5 bits, next position  
                                 imm19_12: 10 + 12 * bitSpacing,      // imm19_12 - 8 bits, next position
                                 imm11_7: 10 + 20 * bitSpacing        // imm11_7 - 5 bits, rightmost position
                             };

                             // Create lines for each field that's used in the final immediate
                             if (finalPositions.visible.imm31 && finalPositions.imm31 !== null) {
                                 lines.push(new fabric.Line([
                                     row2_positions.imm31 + bit_size/2, field_top + 10,     // From center of imm31 field
                                     finalPositions.imm31 + bit_size/2, final_top + 15      // To center of final position
                                 ], {
                                     stroke: lineColor, strokeWidth: 1, strokeDashArray: [2, 2]
                                 }));
                             }

                             if (finalPositions.visible.imm30_25 && finalPositions.imm30_25 !== null) {
                                 lines.push(new fabric.Line([
                                     row2_positions.imm30_25 + 3 * bitSpacing, field_top + 10,    // From middle of 6-bit field
                                     finalPositions.imm30_25 + 3 * bitSpacing, final_top + 15     // To middle of final field
                                 ], {
                                     stroke: lineColor, strokeWidth: 1, strokeDashArray: [2, 2]
                                 }));
                             }

                             if (finalPositions.visible.imm24_20 && finalPositions.imm24_20 !== null) {
                                 lines.push(new fabric.Line([
                                     row2_positions.imm24_20 + 2 * bitSpacing, field_top + 10,    // From middle of 5-bit field
                                     finalPositions.imm24_20 + 2 * bitSpacing, final_top + 15     // To middle of final field
                                 ], {
                                     stroke: lineColor, strokeWidth: 1, strokeDashArray: [2, 2]
                                 }));
                             }

                             if (finalPositions.visible.imm19_12 && finalPositions.imm19_12 !== null) {
                                 lines.push(new fabric.Line([
                                     row2_positions.imm19_12 + 3.5 * bitSpacing, field_top + 10,  // From middle of 8-bit field
                                     finalPositions.imm19_12 + 3.5 * bitSpacing, final_top + 15   // To middle of final field
                                 ], {
                                     stroke: lineColor, strokeWidth: 1, strokeDashArray: [2, 2]
                                 }));
                             }

                             if (finalPositions.visible.imm11_7 && finalPositions.imm11_7 !== null) {
                                 lines.push(new fabric.Line([
                                     row2_positions.imm11_7 + 2 * bitSpacing, field_top + 10,     // From middle of 5-bit field
                                     finalPositions.imm11_7 + 2 * bitSpacing, final_top + 15      // To middle of final field
                                 ], {
                                     stroke: lineColor, strokeWidth: 1, strokeDashArray: [2, 2]
                                 }));
                             }

                             return lines;
                         }

                         // ===== 1. RENDER INSTRUCTION BITS =====

                         // Get instruction value consistent with current instruction (like CPU does)
                         let instruction_value = 0;
                         try {
                             let sig_obj = {
                                 i_wb_en: this.svSigRef(immdec + "i_wb_en"),
                                 i_wb_rdt: i_wb_rdt_sig
                             };

                             let sigs = this.signalSet(sig_obj);

                             // Look for when i_wb_en was last asserted (same logic as CPU preRender)
                             for (let steps = 1; steps <= 70; steps++) {
                                 sigs.step(-1);
                                 let wb_en = sigs.sig("i_wb_en").asBool(false);

                                 if (wb_en) {
                                     instruction_value = sigs.sig("i_wb_rdt").asInt(0);
                                     break;
                                 }
                             }
                         } catch(e) {
                             // Fallback to current value
                             instruction_value = i_wb_rdt_sig.asInt(0);
                         }

                         // Create highlight mask for incoming instruction bit
                         let instruction_highlightMask = 0;
                         if (i_wb_en) {
                             // During load, highlight all immediate bits being loaded
                             instruction_highlightMask = 0x3FFFFFE0;  // Bits 29:5 are immediate bits in [31:2] signal
                         } else if (cnt_en && data.current_bit >= 7 && data.current_bit <= 31) {
                             // During execution, highlight the current bit being processed
                             if (data.current_bit >= 2 && data.current_bit <= 31) {
                                 instruction_highlightMask = 1 << (data.current_bit - 2);  // Adjust for [31:2] indexing
                             }
                         }

                         '/top'.lib.renderShiftRegister(data.i_wb_rdt, this.obj, "instruction", {
                             showHex: true, highlightMask: instruction_highlightMask
                         });

                         // ===== 2. RENDER INSTRUCTION-ALIGNED IMMEDIATE FIELDS =====

                         let shifting = cnt_en && !i_wb_en;

                         // Create highlight masks for each register based on current bit being loaded/shifted
                         let imm31_highlight = 0, imm30_25_highlight = 0, imm24_20_highlight = 0;
                         let imm19_12_highlight = 0, imm11_7_highlight = 0;

                         if (i_wb_en) {
                             // During load, highlight the specific bit being loaded
                             if (data.current_bit == 31) imm31_highlight = 1;
                             if (data.current_bit >= 25 && data.current_bit <= 30) imm30_25_highlight = 1 << (data.current_bit - 25);
                             if (data.current_bit >= 20 && data.current_bit <= 24) imm24_20_highlight = 1 << (data.current_bit - 20);
                             if (data.current_bit >= 12 && data.current_bit <= 19) imm19_12_highlight = 1 << (data.current_bit - 12);
                             if (data.current_bit >= 7 && data.current_bit <= 11) imm11_7_highlight = 1 << (data.current_bit - 7);
                         } else if (shifting) {
                             // During shifting, highlight the outgoing bit from each active register
                             if (i_immdec_en & 0x8) imm30_25_highlight = 1;  // LSB shifting out
                             if (i_immdec_en & 0x4) imm24_20_highlight = 1;  // LSB shifting out
                             if (i_immdec_en & 0x2) imm19_12_highlight = 1;  // LSB shifting out (but not bit 8)
                             if (i_immdec_en & 0x1) imm11_7_highlight = 1;   // LSB shifting out
                         }

                         // Render all immediate field registers
                         '/top'.lib.renderShiftRegister(imm31_sig, this.obj, "imm31", {showHex: false, highlightMask: imm31_highlight});
                         '/top'.lib.renderShiftRegister(imm30_25_sig, this.obj, "imm30_25", {showHex: false, highlightMask: imm30_25_highlight});
                         '/top'.lib.renderShiftRegister(imm24_20_sig, this.obj, "imm24_20", {showHex: false, highlightMask: imm24_20_highlight});
                         '/top'.lib.renderShiftRegister(imm19_12_sig, this.obj, "imm19_12", {showHex: false, highlightMask: imm19_12_highlight, ignoreBits: [0]});
                         '/top'.lib.renderShiftRegister(imm11_7_sig, this.obj, "imm11_7", {showHex: false, highlightMask: imm11_7_highlight});

                         // ===== 3. RENDER FINAL IMMEDIATE VALUE FIELDS =====

                         let connectionLines = [];
                         let final_top = 80, final_left = 10, bit_spacing = 13;  // bit_size + 1
                         let type_visible = data.instruction_valid && data.instruction_type !== "UNKNOWN";

                         // Hide all type labels first
                         this.obj.i_type_label.set({visible: false});
                         this.obj.s_type_label.set({visible: false});
                         this.obj.b_type_label.set({visible: false});
                         this.obj.u_type_label.set({visible: false});
                         this.obj.j_type_label.set({visible: false});

                         if (type_visible) {
                             // Position fields based on instruction type
                             let positions = calculateFinalPositions(data.instruction_type, final_left, bit_spacing);

                             // Show appropriate type label
                             if (data.instruction_type === "OP-IMM" || data.instruction_type === "LOAD" || data.instruction_type === "JALR") {
                                 this.obj.i_type_label.set({visible: true});
                             } else if (data.instruction_type === "STORE") {
                                 this.obj.s_type_label.set({visible: true});
                             } else if (data.instruction_type === "BRANCH") {
                                 this.obj.b_type_label.set({visible: true});
                             } else if (data.instruction_type === "LUI" || data.instruction_type === "AUIPC") {
                                 this.obj.u_type_label.set({visible: true});
                             } else if (data.instruction_type === "JAL") {
                                 this.obj.j_type_label.set({visible: true});
                             }

                             // Reposition and show/hide final immediate fields based on instruction type
                             // Position entire fields at their immediate value bit positions

                             if (this.obj.final_imm31_bit_0) {
                                 if (positions.visible.imm31 && positions.imm31 !== null) {
                                     this.obj.final_imm31_bit_0.set({left: positions.imm31, visible: true});
                                     this.obj.final_imm31_label.set({left: positions.imm31 - 5, visible: true, text: "31"});
                                 } else {
                                     this.obj.final_imm31_bit_0.set({visible: false});
                                     this.obj.final_imm31_label.set({visible: false});
                                 }
                             }

                             if (positions.visible.imm30_25 && positions.imm30_25 !== null) {
                                 // Position the entire imm30_25 field at the calculated position (MSB to LSB layout)
                                 for (let i = 0; i < 6; i++) {
                                     if (this.obj[`final_imm30_25_bit_${i}`]) {
                                         this.obj[`final_imm30_25_bit_${i}`].set({
                                             left: positions.imm30_25 + (5-i) * bit_spacing,  // i=0 is LSB (right), i=5 is MSB (left)
                                             visible: true
                                         });
                                     }
                                 }
                                 if (this.obj.final_imm30_25_label) {
                                     this.obj.final_imm30_25_label.set({left: positions.imm30_25 - 5, visible: true, text: "30:25"});
                                 }
                             } else {
                                 for (let i = 0; i < 6; i++) {
                                     if (this.obj[`final_imm30_25_bit_${i}`]) {
                                         this.obj[`final_imm30_25_bit_${i}`].set({visible: false});
                                     }
                                 }
                                 if (this.obj.final_imm30_25_label) {
                                     this.obj.final_imm30_25_label.set({visible: false});
                                 }
                             }

                             if (positions.visible.imm24_20 && positions.imm24_20 !== null) {
                                 // Position the entire imm24_20 field at the calculated position (MSB to LSB layout)
                                 for (let i = 0; i < 5; i++) {
                                     if (this.obj[`final_imm24_20_bit_${i}`]) {
                                         this.obj[`final_imm24_20_bit_${i}`].set({
                                             left: positions.imm24_20 + (4-i) * bit_spacing,  // i=0 is LSB (right), i=4 is MSB (left)
                                             visible: true
                                         });
                                     }
                                 }
                                 if (this.obj.final_imm24_20_label) {
                                     this.obj.final_imm24_20_label.set({left: positions.imm24_20 - 5, visible: true, text: "24:20"});
                                 }
                             } else {
                                 for (let i = 0; i < 5; i++) {
                                     if (this.obj[`final_imm24_20_bit_${i}`]) {
                                         this.obj[`final_imm24_20_bit_${i}`].set({visible: false});
                                     }
                                 }
                                 if (this.obj.final_imm24_20_label) {
                                     this.obj.final_imm24_20_label.set({visible: false});
                                 }
                             }

                             if (positions.visible.imm19_12 && positions.imm19_12 !== null) {
                                 // Position the entire imm19_12 field at the calculated position (MSB to LSB layout)
                                 for (let i = 0; i < 8; i++) {  // Only 8 bits for [19:12]
                                     if (this.obj[`final_imm19_12_bit_${i}`]) {
                                         this.obj[`final_imm19_12_bit_${i}`].set({
                                             left: positions.imm19_12 + (7-i) * bit_spacing,  // i=0 is LSB (right), i=7 is MSB (left)
                                             visible: true
                                         });
                                     }
                                 }
                                 if (this.obj.final_imm19_12_label) {
                                     this.obj.final_imm19_12_label.set({left: positions.imm19_12 - 5, visible: true, text: "19:12"});
                                 }
                             } else {
                                 for (let i = 0; i < 8; i++) {
                                     if (this.obj[`final_imm19_12_bit_${i}`]) {
                                         this.obj[`final_imm19_12_bit_${i}`].set({visible: false});
                                     }
                                 }
                                 if (this.obj.final_imm19_12_label) {
                                     this.obj.final_imm19_12_label.set({visible: false});
                                 }
                             }

                             if (positions.visible.imm11_7 && positions.imm11_7 !== null) {
                                 // Position the entire imm11_7 field at the calculated position (MSB to LSB layout)
                                 for (let i = 0; i < 5; i++) {
                                     if (this.obj[`final_imm11_7_bit_${i}`]) {
                                         this.obj[`final_imm11_7_bit_${i}`].set({
                                             left: positions.imm11_7 + (4-i) * bit_spacing,  // i=0 is LSB (right), i=4 is MSB (left)
                                             visible: true
                                         });
                                     }
                                 }
                                 if (this.obj.final_imm11_7_label) {
                                     this.obj.final_imm11_7_label.set({left: positions.imm11_7 - 5, visible: true, text: "11:7"});
                                 }
                             } else {
                                 for (let i = 0; i < 5; i++) {
                                     if (this.obj[`final_imm11_7_bit_${i}`]) {
                                         this.obj[`final_imm11_7_bit_${i}`].set({visible: false});
                                     }
                                 }
                                 if (this.obj.final_imm11_7_label) {
                                     this.obj.final_imm11_7_label.set({visible: false});
                                 }
                             }

                             // Create connection lines between instruction-aligned and final positions
                             connectionLines = createConnectionLines(final_left, bit_spacing, positions, 12);
                         }

                         // Render final immediate fields with current values
                         '/top'.lib.renderShiftRegister(imm31_sig, this.obj, "final_imm31", {showHex: false});
                         '/top'.lib.renderShiftRegister(imm30_25_sig, this.obj, "final_imm30_25", {showHex: false});
                         '/top'.lib.renderShiftRegister(imm24_20_sig, this.obj, "final_imm24_20", {showHex: false});
                         '/top'.lib.renderShiftRegister(imm19_12_sig, this.obj, "final_imm19_12", {showHex: false, ignoreBits: [0]});
                         '/top'.lib.renderShiftRegister(imm11_7_sig, this.obj, "final_imm11_7", {showHex: false});

                         // Show final immediate value if instruction is valid
                         if (data.instruction_valid && data.instruction !== 0) {
                             this.obj.final_imm_box.set({visible: true});
                             this.obj.final_imm_text.set({
                                 visible: true,
                                 text: `Final Immediate: 0x${data.instruction.toString(16).padStart(8, "0").toUpperCase()}`
                             });
                         } else {
                             this.obj.final_imm_box.set({visible: false});
                             this.obj.final_imm_text.set({visible: false});
                         }

                         // ===== OUTPUT BIT VISUALIZATION =====


                         // Get current output bit
                         let o_imm = this.svSigRef(immdec + "o_imm").asInt(0);
                         let out_bit = o_imm & 1;

                         // Color output bit based on current bit position
                         let outColor = '/top'.lib.getBitPositionColor(data.current_bit);

                         this.obj.output_bit.set({
                             fill: out_bit ? "gray" : "white",
                             stroke: outColor, strokeWidth: cnt_en ? 3 : 2,
                             radius: cnt_en ? 10 : 8
                         });

                         this.obj.output_value.set({
                             text: out_bit.toString(),
                             fill: cnt_en ? "white" : "black",
                             fontWeight: cnt_en ? "bold" : "normal"
                         });

                         // ===== STATUS DISPLAYS =====

                         // Update status based on current phase
                         let status_text = "IDLE";
                         if (data.phase === "LOAD") status_text = "LOADING";
                         else if (data.phase === "EXECUTE") status_text = "SHIFTING";
                         else if (data.phase === "DONE") status_text = "COMPLETE";

                         this.obj.status_text.set({text: `Status: ${status_text}`});
                         this.obj.bit_counter.set({text: `Bit: ${data.current_bit}/31`});

                         // Return connection lines to be added to canvas
                         return connectionLines;
                     }
               /ctrl  // serv_ctrl - PC control and calculation
                  \viz_js
                     box: {width: 150, height: 80, strokeWidth: 1, stroke: "blue"},
                     where: {left: 650, top: 50, width: 150, height: 80},                     
               /rf_read  // Register file read values streaming to ALU
                  \viz_js
                     box: {left: -30, width: 540, height: 90, strokeWidth: 1, stroke: "green"},
                     where: {left: -30, top: 160, width: 180, height: 30},
                     init() {
                        let ret = {};
                        
                        // Title
                        ret.title = new fabric.Text("Register File Read → ALU", {
                           fontSize: 10,
                           fontWeight: "bold",
                           top: -15,
                           left: 260,
                           textAlign: "center",
                           originX: "center",
                           selectable: false
                        });
                        
                        // RS1 register visualization - aligned with immdec
                        ret.rs1_label = new fabric.Text("RS1:", {
                           fontSize: 7,
                           top: 5,
                           left: 15,
                           fontWeight: "bold",
                           selectable: false
                        });
                        
                        ret.rs1_addr_label = new fabric.Text("x0", {
                           fontSize: 6,
                           top: 5,
                           left: 40,
                           fontFamily: "monospace",
                           selectable: false
                        });
                        
                        // RS1 arrow from RF
                        ret.rs1_arrow = new fabric.Path("M 15 20 L 55 20 M 50 17 L 55 20 L 50 23", {
                           stroke: "green",
                           strokeWidth: 2,
                           fill: "",
                           opacity: 0.3,
                           selectable: false
                        });
                        
                        ret.rs1_arrow_label = new fabric.Text("From RF", {
                           fontSize: 4,
                           top: 25,
                           left: 35,
                           textAlign: "center",
                           originX: "center",
                           fill: "green",
                           opacity: 0.3,
                           selectable: false
                        });
                        
                        // Initialize RS1 as 32-bit shift register - aligned with immdec at x=60
                        Object.assign(ret, '/top'.lib.initShiftRegister("rs1_reg", {
                           left: 70,
                           top: 10,
                           bitWidth: 12,
                           bitHeight: 12,
                           spacing: 1,
                           maxBitsPerRow: 32,
                           labelSize: 4,
                           showLabel: false,
                           lsb: 0,
                           width: 32
                        }));
                        
                        // RS2 register visualization - aligned with immdec
                        ret.rs2_label = new fabric.Text("RS2/IMM:", {
                           fontSize: 7,
                           top: 35,
                           left: 15,
                           fontWeight: "bold",
                           selectable: false
                        });
                        
                        ret.rs2_addr_label = new fabric.Text("x0", {
                           fontSize: 6,
                           top: 35,
                           left: 60,
                           fontFamily: "monospace",
                           selectable: false
                        });
                        
                        // RS2 arrow from RF/IMM
                        ret.rs2_arrow = new fabric.Path("M 15 50 L 55 50 M 50 47 L 55 50 L 50 53", {
                           stroke: "blue",
                           strokeWidth: 2,
                           fill: "",
                           opacity: 0.3,
                           selectable: false
                        });
                        
                        ret.rs2_arrow_label = new fabric.Text("From RF/IMM", {
                           fontSize: 4,
                           top: 55,
                           left: 35,
                           textAlign: "center",
                           originX: "center",
                           fill: "blue",
                           opacity: 0.3,
                           selectable: false
                        });
                        
                        // Initialize RS2 as 32-bit shift register - aligned with immdec at x=60
                        Object.assign(ret, '/top'.lib.initShiftRegister("rs2_reg", {
                           left: 70,
                           top: 40,
                           bitWidth: 12,
                           bitHeight: 12,
                           spacing: 1,
                           maxBitsPerRow: 32,
                           labelSize: 4,
                           showLabel: false,
                           lsb: 0,
                           width: 32
                        }));
                        
                        // Status information on the right
                        ret.status_label = new fabric.Text("Status:", {
                           fontSize: 6,
                           top: 60,
                           left: 15,
                           selectable: false
                        });
                        
                        ret.status_text = new fabric.Text("IDLE", {
                           fontSize: 7,
                           fontWeight: "bold",
                           top: 60,
                           left: 50,
                           fill: "gray",
                           selectable: false
                        });
                        
                        ret.bit_pos_label = new fabric.Text("Bit:", {
                           fontSize: 6,
                           top: 60,
                           left: 100,
                           selectable: false
                        });
                        
                        ret.bit_pos_text = new fabric.Text("0/31", {
                           fontSize: 7,
                           top: 60,
                           left: 120,
                           fontFamily: "monospace",
                           selectable: false
                        });
                        
                        return ret;
                     },
                     render() {
                         // Get centralized data from CPU
                         let cpuData = '/cpu'.data;
                         let cpu = "top.servant_sim.dut.cpu.cpu.";
                         let isActive = cpuData.active_in_phase["rf_read"];
                         let phaseColor = '/cpu'.lib.getLifecycleColor(cpuData.lifecycle_phase);
                         
                         // Get RF interface signals for the actual register values
                         let o_rs1 = this.svSigRef(cpu+"rf_if.o_rs1").asInt(0);
                         let o_rs2 = this.svSigRef(cpu+"rf_if.o_rs2").asInt(0);
                         
                         // Get register addresses being read
                         let rs1_addr = this.svSigRef(cpu+"immdec.o_rs1_addr").asInt(0);
                         let rs2_addr = this.svSigRef(cpu+"immdec.o_rs2_addr").asInt(0);
                         
                         // Get control signals
                         let cnt_en = this.svSigRef(cpu+"state.o_cnt_en").asBool(false);
                         let rf_rreq = this.svSigRef(cpu+"state.o_rf_rreq").asBool(false);
                         let rf_ready = this.svSigRef(cpu+"state.i_rf_ready").asBool(false);
                         
                         // Check for immediate operations (RS2 might come from immediate, not RF)
                         let op_b_sel = this.svSigRef(cpu+"bufreg2.i_op_b_sel").asBool(false);
                         
                         console.log(`=== RF_READ: bit=${cpuData.current_bit}, cnt_en=${cnt_en}, rf_rreq=${rf_rreq}, rs1_addr=${rs1_addr}, rs2_addr=${rs2_addr}, o_rs1=${o_rs1}, o_rs2=${o_rs2} ===`);
                         
                        // Get the full 32-bit register values from extension interface
                        let ext_rs1 = this.svSigRef(cpu+"o_ext_rs1");
                        let ext_rs2 = this.svSigRef(cpu+"o_ext_rs2");
                         
                         // ===== HIGHLIGHT CURRENT BIT BEING READ =====
                         
                         let rs1_highlight = 0;
                         let rs2_highlight = 0;
                         
                         /* disable highlighting. It appears the LSB is always (usually?) the ALU input.
                         if (cnt_en && cpuData.current_bit < 32) {
                             // Highlight the current bit being streamed into ALU
                             rs1_highlight = 1 << cpuData.current_bit;
                             rs2_highlight = 1 << cpuData.current_bit;
                         }
                         */
                         
                         // ===== RENDER SHIFT REGISTERS =====
                         
                         '/top'.lib.renderShiftRegister(ext_rs1, this.obj, "rs1_reg", {
                             showHex: false,
                             highlightMask: rs1_highlight
                         });
                         
                         '/top'.lib.renderShiftRegister(ext_rs2, this.obj, "rs2_reg", {
                             showHex: false,
                             highlightMask: rs2_highlight
                         });
                         
                         // ===== UPDATE REGISTER ADDRESSES =====
                         
                         this.obj.rs1_addr_label.set({
                             text: `x${rs1_addr}`,
                             fill: cnt_en ? "black" : "gray"
                         });
                         
                         this.obj.rs2_addr_label.set({
                             text: op_b_sel ? `x${rs2_addr}` : "IMM",
                             fill: cnt_en ? "black" : "gray"
                         });
                         
                         // ===== UPDATE ARROWS - SHOW WHEN RF IS BEING READ =====
                         
                         // RS1 arrow - show when reading from RF
                         let rs1_reading = rf_rreq || (cnt_en && rf_ready);
                         this.obj.rs1_arrow.set({
                             opacity: rs1_reading ? 1.0 : 0.3,
                             strokeWidth: rs1_reading ? 3 : 2
                         });
                         
                         this.obj.rs1_arrow_label.set({
                             opacity: rs1_reading ? 1.0 : 0.3,
                             fontWeight: rs1_reading ? "bold" : "normal"
                         });
                         
                         // RS2 arrow - show when reading from RF (not immediate)
                         let rs2_reading = op_b_sel && (rf_rreq || (cnt_en && rf_ready));
                         this.obj.rs2_arrow.set({
                             opacity: rs2_reading ? 1.0 : 0.3,
                             strokeWidth: rs2_reading ? 3 : 2,
                             stroke: op_b_sel ? "blue" : "orange"  // Blue for RF, orange for immediate
                         });
                         
                         this.obj.rs2_arrow_label.set({
                             text: op_b_sel ? "From RF" : "From IMM",
                             fill: op_b_sel ? "blue" : "orange",
                             opacity: rs2_reading || (!op_b_sel && cnt_en) ? 1.0 : 0.3,
                             fontWeight: (rs2_reading || (!op_b_sel && cnt_en)) ? "bold" : "normal"
                         });
                         
                         /* disabled. This is the wrong condition.
                         // ===== UPDATE REGISTER VALIDITY USING OPACITY =====
                         
                         // RS1 register validity
                         let rs1_valid = rf_ready && cnt_en;
                         for (let i = 0; i < 32; i++) {
                             if (this.obj[`rs1_reg_bit_${i}`]) {
                                 this.obj[`rs1_reg_bit_${i}`].set({
                                     opacity: rs1_valid ? 1.0 : 0.5
                                 });
                             }
                         }
                         
                         // RS2 register validity
                         let rs2_valid = rf_ready && cnt_en;
                         for (let i = 0; i < 32; i++) {
                             if (this.obj[`rs2_reg_bit_${i}`]) {
                                 this.obj[`rs2_reg_bit_${i}`].set({
                                     opacity: rs2_valid ? 1.0 : 0.5
                                 });
                             }
                         }
                         */
                         
                         // ===== UPDATE STATUS INFORMATION =====
                         
                         let status_text = "IDLE";
                         let status_color = "gray";
                         
                         if (rf_rreq) {
                             status_text = "REQ";
                             status_color = "blue";
                         } else if (cnt_en && rf_ready) {
                             status_text = "STREAMING";
                             status_color = "green";
                         } else if (cpuData.phase === "DONE") {
                             status_text = "COMPLETE";
                             status_color = "orange";
                         }
                         
                         this.obj.status_text.set({
                             text: status_text,
                             fill: status_color
                         });
                         
                         this.obj.bit_pos_text.set({
                             text: `${cpuData.current_bit}/31`,
                             fill: cnt_en ? "purple" : "gray"
                         });
                         
                         // ===== UPDATE LABELS BASED ON ACTIVITY =====
                         
                         this.obj.rs1_label.set({
                             fill: cnt_en ? "black" : "gray",
                             fontWeight: cnt_en ? "bold" : "normal"
                         });
                         
                         this.obj.rs2_label.set({
                             fill: cnt_en ? "black" : "gray",
                             fontWeight: cnt_en ? "bold" : "normal"
                         });
                         
                         this.obj.status_label.set({
                             fill: (rf_rreq || cnt_en) ? "black" : "gray"
                         });
                         
                         this.obj.bit_pos_label.set({
                             fill: cnt_en ? "black" : "gray"
                         });
                     }
               /alu
                  \viz_js
                     box: {width: 150, height: 100, strokeWidth: 1, stroke: "red"},
                     where: {left: 0, top: 200, width: 150, height: 100},
                     init() {
                        let ret = {};
                        
                        // Title
                        ret.title = new fabric.Text("serv_alu", {
                           fontSize: 10,
                           fontWeight: "bold",
                           top: -15,
                           left: 75,
                           textAlign: "center",
                           originX: "center",
                           selectable: false
                        });
                        
                        // Operation display at top
                        ret.operation_label = new fabric.Text("Operation:", {
                           fontSize: 6,
                           top: 5,
                           left: 5,
                           selectable: false
                        });
                        
                        ret.operation_text = new fabric.Text("ADD", {
                           fontSize: 8,
                           fontWeight: "bold",
                           top: 5,
                           left: 50,
                           fill: "blue",
                           selectable: false
                        });
                        
                        // Current bit operation section
                        ret.bit_op_label = new fabric.Text("Current Bit Operation:", {
                           fontSize: 6,
                           top: 20,
                           left: 5,
                           selectable: false
                        });
                        
                        // Input operands A and B (current bits)
                        ret.operand_a_label = new fabric.Text("A:", {
                           fontSize: 5,
                           top: 32,
                           left: 10,
                           selectable: false
                        });
                        
                        ret.operand_a_bit = '/top'.lib.initBit({
                           top: 30,
                           left: 20,
                           width: 12,
                           height: 12
                        });
                        
                        ret.operand_b_label = new fabric.Text("B:", {
                           fontSize: 5,
                           top: 32,
                           left: 40,
                           selectable: false
                        });
                        
                        ret.operand_b_bit = '/top'.lib.initBit({
                           top: 30,
                           left: 50,
                           width: 12,
                           height: 12
                        });
                        
                        // Carry input
                        ret.carry_in_label = new fabric.Text("Cin:", {
                           fontSize: 5,
                           top: 32,
                           left: 70,
                           selectable: false
                        });
                        
                        ret.carry_in_bit = '/top'.lib.initBit({
                           top: 30,
                           left: 90,
                           width: 12,
                           height: 12
                        });
                        
                        // Operation symbol
                        ret.op_symbol = new fabric.Text("+", {
                           fontSize: 12,
                           fontWeight: "bold",
                           top: 28,
                           left: 110,
                           textAlign: "center",
                           originX: "center",
                           fill: "red",
                           selectable: false
                        });
                        
                        // Result output
                        ret.result_label = new fabric.Text("Result:", {
                           fontSize: 5,
                           top: 50,
                           left: 10,
                           selectable: false
                        });
                        
                        ret.result_bit = '/top'.lib.initBit({
                           top: 48,
                           left: 45,
                           width: 12,
                           height: 12
                        });
                        
                        // Carry output
                        ret.carry_out_label = new fabric.Text("Cout:", {
                           fontSize: 5,
                           top: 50,
                           left: 70,
                           selectable: false
                        });
                        
                        ret.carry_out_bit = '/top'.lib.initBit({
                           top: 48,
                           left: 100,
                           width: 12,
                           height: 12
                        });
                        
                        // Operation mode indicators
                        ret.mode_label = new fabric.Text("Mode:", {
                           fontSize: 6,
                           top: 65,
                           left: 5,
                           selectable: false
                        });
                        
                        // Addition/Subtraction indicator
                        ret.add_sub_indicator = new fabric.Circle({
                           radius: 4,
                           left: 35,
                           top: 67,
                           fill: "#ff6b6b",
                           stroke: "black",
                           strokeWidth: 0.5,
                           selectable: false
                        });
                        
                        ret.add_sub_label = new fabric.Text("ADD/SUB", {
                           fontSize: 4,
                           top: 73,
                           left: 35,
                           textAlign: "center",
                           originX: "center",
                           selectable: false
                        });
                        
                        // Boolean logic indicator
                        ret.bool_indicator = new fabric.Circle({
                           radius: 4,
                           left: 70,
                           top: 67,
                           fill: "#4ecdc4",
                           stroke: "black",
                           strokeWidth: 0.5,
                           selectable: false
                        });
                        
                        ret.bool_label = new fabric.Text("BOOL", {
                           fontSize: 4,
                           top: 73,
                           left: 70,
                           textAlign: "center",
                           originX: "center",
                           selectable: false
                        });
                        
                        // Comparison indicator  
                        ret.cmp_indicator = new fabric.Circle({
                           radius: 4,
                           left: 100,
                           top: 67,
                           fill: "#45b7d1",
                           stroke: "black",
                           strokeWidth: 0.5,
                           selectable: false
                        });
                        
                        ret.cmp_label = new fabric.Text("CMP", {
                           fontSize: 4,
                           top: 73,
                           left: 100,
                           textAlign: "center",
                           originX: "center",
                           selectable: false
                        });
                        
                        // Progress and bit position
                        ret.bit_position_label = new fabric.Text("Bit Position:", {
                           fontSize: 5,
                           top: 82,
                           left: 5,
                           selectable: false
                        });
                        
                        ret.bit_position_text = new fabric.Text("0", {
                           fontSize: 8,
                           fontWeight: "bold",
                           top: 80,
                           left: 60,
                           fill: "purple",
                           selectable: false
                        });
                        
                        ret.bit_of_32_label = new fabric.Text("/31", {
                           fontSize: 6,
                           top: 82,
                           left: 70,
                           selectable: false
                        });
                        
                        // Computation accumulation indicator
                        ret.accumulation_label = new fabric.Text("Partial Result Building:", {
                           fontSize: 5,
                           top: 92,
                           left: 5,
                           selectable: false
                        });
                        
                        // Progress bar for accumulation
                        ret.progress_bar = new fabric.Rect({
                           width: 100,
                           height: 4,
                           top: 95,
                           left: 25,
                           fill: "white",
                           stroke: "black",
                           strokeWidth: 1,
                           selectable: false
                        });
                        
                        ret.progress_fill = new fabric.Rect({
                           width: 0,
                           height: 4,
                           top: 95,
                           left: 25,
                           fill: "green",
                           selectable: false
                        });
                        
                        return ret;
                     },
                     render() {
                         // Get centralized data from CPU
                         let cpuData = '/cpu'.data;
                         let cpu = "top.servant_sim.dut.cpu.cpu.";
                         let alu = cpu+"alu.";
                         let isActive = cpuData.active_in_phase["alu"];
                         let phaseColor = '/cpu'.lib.getLifecycleColor(cpuData.lifecycle_phase);
                         
                         // Get ALU control signals
                         let i_sub = this.svSigRef(alu+"i_sub").asBool(false);
                         let i_bool_op = this.svSigRef(alu+"i_bool_op").asInt(0);
                         let i_cmp_eq = this.svSigRef(alu+"i_cmp_eq").asBool(false);
                         let i_cmp_sig = this.svSigRef(alu+"i_cmp_sig").asBool(false);
                         let i_rd_sel = this.svSigRef(alu+"i_rd_sel").asInt(0);
                         let i_en = this.svSigRef(alu+"i_en").asBool(false);
                         
                         // Get ALU data signals
                         let i_rs1 = this.svSigRef(alu+"i_rs1").asInt(0);
                         let i_op_b = this.svSigRef(alu+"i_op_b").asInt(0);
                         let o_rd = this.svSigRef(alu+"o_rd").asInt(0);
                         let o_cmp = this.svSigRef(alu+"o_cmp").asBool(false);
                         
                         // Get internal ALU signals
                         let add_cy = this.svSigRef(alu+"add_cy").asBool(false);
                         let add_cy_r = this.svSigRef(alu+"add_cy_r").asInt(0);
                         let result_add = this.svSigRef(alu+"result_add").asInt(0);
                         
                         console.log(`=== ALU: bit=${cpuData.current_bit}, en=${i_en}, sub=${i_sub}, bool_op=${i_bool_op}, rd_sel=${i_rd_sel} ===`);
                         
                         // ===== DETERMINE OPERATION TYPE =====
                         
                         let operation_name = "IDLE";
                         let operation_symbol = "?";
                         let is_add_sub = false, is_bool = false, is_cmp = false;
                         
                         if (i_en) {
                             // Determine operation based on rd_sel (which result is selected)
                             if (i_rd_sel & 0x1) {  // result_add selected
                                 is_add_sub = true;
                                 if (i_sub) {
                                     operation_name = "SUB";
                                     operation_symbol = "-";
                                 } else {
                                     operation_name = "ADD";
                                     operation_symbol = "+";
                                 }
                             } else if (i_rd_sel & 0x2) {  // result_slt selected
                                 is_cmp = true;
                                 if (i_cmp_eq) {
                                     operation_name = "EQ";
                                     operation_symbol = "==";
                                 } else {
                                     operation_name = i_cmp_sig ? "SLT" : "SLTU";
                                     operation_symbol = "<";
                                 }
                             } else if (i_rd_sel & 0x4) {  // result_bool selected
                                 is_bool = true;
                                 switch(i_bool_op) {
                                     case 0: operation_name = "XOR"; operation_symbol = "^"; break;
                                     case 1: operation_name = "ZERO"; operation_symbol = "0"; break;
                                     case 2: operation_name = "OR"; operation_symbol = "|"; break;
                                     case 3: operation_name = "AND"; operation_symbol = "&"; break;
                                     default: operation_name = "BOOL"; operation_symbol = "?"; break;
                                 }
                             }
                         }
                         
                         // ===== UPDATE OPERATION DISPLAY =====
                         
                         this.obj.operation_text.set({
                             text: operation_name,
                             fill: i_en ? "blue" : "gray"
                         });
                         
                         this.obj.op_symbol.set({
                             text: operation_symbol,
                             fill: i_en ? "red" : "gray"
                         });
                         
                         // ===== UPDATE MODE INDICATORS =====
                         
                         this.obj.add_sub_indicator.set({
                             opacity: is_add_sub ? 1.0 : 0.3,
                             fill: is_add_sub ? "#ff6b6b" : "#ffcccc"
                         });
                         
                         this.obj.bool_indicator.set({
                             opacity: is_bool ? 1.0 : 0.3,
                             fill: is_bool ? "#4ecdc4" : "#cceeee"
                         });
                         
                         this.obj.cmp_indicator.set({
                             opacity: is_cmp ? 1.0 : 0.3,
                             fill: is_cmp ? "#45b7d1" : "#cce6ff"
                         });
                         
                         // ===== UPDATE CURRENT BIT OPERATION =====
                         
                         // Extract current bit values
                         let a_bit = i_rs1 & 1;
                         let b_bit = i_op_b & 1; 
                         let result_bit = o_rd & 1;
                         let carry_in = add_cy_r & 1;
                         let carry_out = add_cy ? 1 : 0;
                         
                         // Color bits based on current bit position
                         let bitColor = '/top'.lib.getBitPositionColor(cpuData.current_bit);
                         
                         // Update operand A
                         '/top'.lib.setBit(this.obj.operand_a_bit, a_bit, cpuData.current_bit);
                         this.obj.operand_a_bit.set({
                             strokeWidth: i_en ? 3 : 1,
                             stroke: i_en ? bitColor : "gray"
                         });
                         
                         // Update operand B  
                         '/top'.lib.setBit(this.obj.operand_b_bit, b_bit, cpuData.current_bit);
                         this.obj.operand_b_bit.set({
                             strokeWidth: i_en ? 3 : 1,
                             stroke: i_en ? bitColor : "gray"
                         });
                         
                         // Update carry input
                         '/top'.lib.setBit(this.obj.carry_in_bit, carry_in, Math.max(0, cpuData.current_bit - 1));
                         this.obj.carry_in_bit.set({
                             strokeWidth: (i_en && is_add_sub) ? 2 : 1,
                             stroke: (i_en && is_add_sub) ? "orange" : "gray",
                             opacity: (i_en && is_add_sub) ? 1.0 : 0.5
                         });
                         
                         // Update result bit
                         '/top'.lib.setBit(this.obj.result_bit, result_bit, cpuData.current_bit);
                         this.obj.result_bit.set({
                             strokeWidth: i_en ? 4 : 1,
                             stroke: i_en ? "green" : "gray"
                         });
                         
                         // Update carry output
                         '/top'.lib.setBit(this.obj.carry_out_bit, carry_out, cpuData.current_bit);
                         this.obj.carry_out_bit.set({
                             strokeWidth: (i_en && is_add_sub && carry_out) ? 3 : 1,
                             stroke: (i_en && is_add_sub && carry_out) ? "orange" : "gray",
                             opacity: (i_en && is_add_sub) ? 1.0 : 0.5
                         });
                         
                         // ===== UPDATE BIT POSITION AND PROGRESS =====
                         
                         this.obj.bit_position_text.set({
                             text: cpuData.current_bit.toString(),
                             fill: i_en ? "purple" : "gray"
                         });
                         
                         // Update progress bar
                         if (i_en && cpuData.current_bit <= 31) {
                             let progress = Math.min(cpuData.current_bit / 31.0, 1.0);
                             this.obj.progress_fill.set({
                                 width: 100 * progress,
                                 fill: is_add_sub ? "#ff6b6b" : is_bool ? "#4ecdc4" : is_cmp ? "#45b7d1" : "green"
                             });
                             this.obj.progress_bar.set({opacity: 1.0});
                         } else {
                             this.obj.progress_fill.set({width: 0});
                             this.obj.progress_bar.set({opacity: 0.3});
                         }
                         
                         // ===== UPDATE LABELS FOR CONTEXT =====
                         
                         // Highlight labels when ALU is active
                         this.obj.bit_op_label.set({
                             fill: i_en ? "black" : "gray",
                             fontWeight: i_en ? "bold" : "normal"
                         });
                         
                         this.obj.operand_a_label.set({fill: i_en ? "black" : "gray"});
                         this.obj.operand_b_label.set({fill: i_en ? "black" : "gray"});
                         this.obj.result_label.set({fill: i_en ? "black" : "gray"});
                         
                         this.obj.carry_in_label.set({
                             fill: (i_en && is_add_sub) ? "orange" : "gray",
                             fontWeight: (i_en && is_add_sub) ? "bold" : "normal"
                         });
                         
                         this.obj.carry_out_label.set({
                             fill: (i_en && is_add_sub) ? "orange" : "gray",
                             fontWeight: (i_en && is_add_sub) ? "bold" : "normal"
                         });
                         
                         // ===== SPECIAL HANDLING FOR COMPARISON OPERATIONS =====
                         
                         if (is_cmp && i_en) {
                             // For comparison operations, show the comparison accumulation
                             if (i_cmp_eq) {
                                 // Equality: show if all bits so far are equal (result_eq accumulation)
                                 this.obj.accumulation_label.set({
                                     text: "Equality Check Progress:",
                                     fill: "blue"
                                 });
                             } else {
                                 // Less-than: show sign bit determination
                                 this.obj.accumulation_label.set({
                                     text: "Less-Than Determination:",
                                     fill: "blue"
                                 });
                             }
                         } else if (i_en) {
                             this.obj.accumulation_label.set({
                                 text: "Partial Result Building:",
                                 fill: "black"
                             });
                         } else {
                             this.obj.accumulation_label.set({
                                 text: "Partial Result Building:",
                                 fill: "gray"
                             });
                         }
                     }
               /bufreg  // serv_bufreg - buffer register for 2-stage ops
                  \viz_js
                     box: {width: 150, height: 100, strokeWidth: 1},
                     where: {left: 450, top: 180, width: 150, height: 100}
                     
               /bufreg2  // serv_bufreg2 - 32-bit buffer with special features
                  \viz_js
                     box: {width: 150, height: 100, strokeWidth: 1},
                     where: {left: 650, top: 180, width: 150, height: 100}
                     
               /mem_if  // serv_mem_if - memory interface
                  \viz_js
                     box: {width: 200, height: 100, strokeWidth: 1},
                     where: {left: 150, top: 330, width: 200, height: 100}
                     
               /csr  // serv_csr - CSR handling (if WITH_CSR=1)
                  \viz_js
                     box: {width: 150, height: 100, strokeWidth: 1},
                     where: {left: 400, top: 330, width: 150, height: 100}
                     
               // Optional debug module (if DEBUG=1)
               /gen_debug
                  /debug  // serv_debug - debug interface
                     \viz_js
                        box: {width: 150, height: 80, strokeWidth: 1},
                        where: {left: 600, top: 330, width: 150, height: 80}
                        
            // RF implementation (serv_rf_ram + serv_rf_ram_if) - outside the core
            /rf_ram_if  // serv_rf_ram_if - adapter between SERV RF IF and RAM
               \viz_js
                  box: {width: 120, height: 80, strokeWidth: 1},
                  where: {left: 950, top: 150, width: 120, height: 80}
                  
            /rf_ram  // serv_rf_ram - SRAM-based register file
               \viz_js
                  box: {width: 120, height: 120, strokeWidth: 1},
                  where: {left: 950, top: 280, width: 120, height: 120}

\SV
   endmodule