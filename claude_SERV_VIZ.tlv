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
         // name: base name for the register (used in object keys)
         // label: optional label text to display above the register
         // left, top: position of the top-left corner of the register
         // bitWidth, bitHeight: dimensions of each bit rectangle (default 8x8)
         // spacing: space between bits (default 1)
         // maxBitsPerRow: maximum bits to display per row (default 32)
         // showLabel: whether to show the label (default true)
         // labelSize: font size for the label (default 5)
         // lsb: the bit position of the LSB of this register (default 0)
         // width: the total width of the register in bits (required)
         // transparencyMask: optional bitmask to control bit transparency
         // ignoreBits: array of bit positions to ignore (default: [])
         initShiftRegister: function(name, {label, left = 0, top = 0, bitWidth = 8, bitHeight = 8, spacing = 1, maxBitsPerRow = 32, showLabel = true, labelSize = 5, lsb = 0, width, transparencyMask = null, ignoreBits = []}) {
             let ret = {};

             if (width === undefined) {
                 throw new Error("width parameter is required");
             }

             // Create label if requested
             if (showLabel) {
                 ret[`${name}_label`] = new fabric.Text(label ? label : name, {
                     fontSize: labelSize, left: left, top: top - labelSize - 4
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
                     top: top + row * (bitHeight + spacing) - 2, originY: "center", originX: "center",
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
                      // Define 8 phases as an object: 6 single-cycle + 2 multi-cycle (all lowercase names)
                      phases: {
                         fetch1:     {name: "fetch1", color: "#4FC3F7", is_multi: false},
                         fetch2:     {name: "fetch2", color: "#4FC3F7", is_multi: false},
                         decode:     {name: "decode", color: "#B39DDB", is_multi: false},
                         setup:      {name: "setup", color: "#9C27B0", is_multi: false},
                         init:       {name: "init", color: "#FFD54F", is_multi: true},
                         writeback:  {name: "writeback", color: "#FF7043", is_multi: false},
                         pc_update:  {name: "pc_update", color: "#FFA726", is_multi: false},
                         execute:    {name: "execute", color: "#81C784", is_multi: true}
                      },

                      getLifecycleColor: function(phase) {
                          switch(phase) {
                              case "FETCH1": return "#4FC3F7";       // Light blue
                              case "FETCH2": return "#4FC3F7";       // Light blue  
                              case "DECODE": return "#B39DDB";       // Light purple
                              case "SETUP": return "#9C27B0";        // Purple
                              case "INIT": return "#FFD54F";         // Yellow  
                              case "WRITEBACK": return "#FF7043";    // Orange
                              case "PC_UPDATE": return "#FFA726";    // Amber
                              case "EXECUTE": return "#81C784";      // Green
                              case "IDLE": return "#BDBDBD";         // Gray
                              default: return "#FF5722";             // Red for error
                          }
                      },

                      isComponentActiveInPhase: function(component, phase, active_in_phase) {
                          return active_in_phase[component] || false;
                      },

                      formatInstructionHistory: function(history, maxCount = 5) {
                          return history.slice(0, maxCount).map(instr => 
                              `${instr.asm} (${instr.cycles_executing}cy)`
                          ).join(", ");
                      },
                      history_depth: 8, // Number of cycles to look back for history

                      // Categorization of instruction types, including:
                      //    immLabel: Describe immediate fields (shown/hidden dynamically in immdec render)
                      //    fieldPositions: Map immediate field names to their bit positions in the final immediate value
                      instrTypes: {
                            i: {immLabel: "I-type: imm[31:0] = {21{imm[31]}, imm[30:25], imm[24:20]}",
                                fieldPositions: {
                                    imm31: 11,        // instr[31] → imm[11]
                                    imm30_25: 10,     // instr[30:25] → imm[10:5]
                                    imm24_20: 4       // instr[24:20] → imm[4:0]
                                }
                            },
                            s: {immLabel: "S-type: imm[31:0] = {21{imm[31]}, imm[30:25], imm[11:7]}",
                                fieldPositions: {
                                    imm31: 11,        // instr[31] → imm[11]
                                    imm30_25: 10,     // instr[30:25] → imm[10:5]
                                    imm11_7: 4        // instr[11:7] → imm[4:0]
                                }
                            },
                            b: {immLabel: "B-type: imm[31:0] = {20{imm[31]}, imm[7], imm[30:25], imm[11:8], 1''b0}",
                                fieldPositions: {
                                    imm31: 12,        // instr[31] → imm[12]
                                    // instr[7] → imm[11] (not included here, handled specially)
                                    imm30_25: 10,     // instr[30:25] → imm[10:5]
                                    imm11_7: 4        // instr[11:8] → imm[4:1] (only 4 bits used, see comment)
                                    // Note: imm[0] is always 0 (not mapped to any field)
                                }
                            },
                            u: {immLabel: "U-type: imm[31:0] = {imm[31], imm[30:25], imm[24:20], imm[19:12], 12''b0}",
                                fieldPositions: {
                                    imm31: 31,        // instr[31] → imm[31]
                                    imm30_25: 30,     // instr[30:25] → imm[30:25]
                                    imm24_20: 24,     // instr[24:20] → imm[24:20]
                                    imm19_12: 19      // instr[19:12] → imm[19:12]
                                    // imm[11:0] = 0 (not mapped)
                                }
                            },
                            j: {immLabel: "J-type: imm[31:0] = {11{imm[31]}, imm[19:12], imm[20], imm[30:25], imm[24:21], 1''b0}",
                                fieldPositions: {
                                    imm31: 20,       // instr[31] → imm[20]
                                    imm19_12: 19,    // instr[19:12] → imm[19:12]
                                    // instr[20] → imm[11] (not included here, handled specially)
                                    imm30_25: 10,    // instr[30:25] → imm[10:5]
                                    imm24_20: 4      // instr[24:21] → imm[4:1] (only 4 bits used, see comment)
                                    // imm[0] is always 0 (not mapped)
                                }
                            },
                            r: {immLabel: "R-type: no immediate value",
                                fieldPositions: {}
                            },
                            f: {immLabel: "F-type: no immediate value",
                                fieldPositions: {}
                            },
                            unknown: {immLabel: "Unknown instruction type, no immediate fields defined",
                                      fieldPositions: {}
                            },
                      },
                      // Characterize immediate fields (shift registers).
                      // Centralized definition of all immediate fields for refactoring
                      immFields: {
                          imm31:     {label: "31",     lsb: 31, msb: 31, width: 1,  top: 0, color: "#FFB300", field: "imm31", args: {}},
                          imm30_25:  {label: "30:25",  lsb: 25, msb: 30, width: 6,  top: 0, color: "#F4511E", field: "imm30_25", args: {}},
                          imm24_20:  {label: "24:20",  lsb: 20, msb: 24, width: 5,  top: 0, color: "#43A047", field: "imm24_20", args: {}},
                          imm19_12:  {label: "19:12",  lsb: 12, msb: 19, width: 8,  top: 0, color: "#1E88E5", field: "imm19_12", args: {ignoreBits: [0]}},
                          imm11_7:   {label: "11:7",   lsb: 7,  msb: 11, width: 5,  top: 0, color: "#8E24AA", field: "imm11_7", args: {}},
                          imm6_0:    {label: "6:0",    lsb: 0,  msb: 6,  width: 7,  top: 0, color: "#757575", field: "imm6_0", args: {}},
                          // For refactoring: add any additional properties needed for layout, mapping, or visualization here.
                          // Example: x position, y position, ignoreBits, etc.
                          // Example: x: 0, y: 0, ignoreBits: []
                      },

                        // Input/Output arrows indicating buffers loaded to/from external dest/source in parallel.
                        // Args:
                        //   ret: object to populate with arrow and label
                        //   name: base name for arrow/label keys
                        //   top: vertical position of arrow
                        //   pointLeft: whether arrow points left (true) or right (false)
                        //   color: color of arrow and label
                        //   label: text label to display near arrow
                        initLoadArrow: function(ret, name, top, leftSide, pointLeft, color, label) {
                            let left = leftSide ? -50 : 443;
                            ret[name + "_arrow"] = new fabric.Path(`M ${left} ${top} L ${left + 45} ${top} M ${left + 37.5} ${top - 4.5} L ${left + 45} ${top} L ${left + 37.5} ${top + 4.5}`, {
                                stroke: color, fill: "", strokeWidth: 4, opacity: 0.3, angle: pointLeft ? 0 : 180, originX: "center", originY: "center"
                            });

                            ret[name + "_arrow_label"] = new fabric.Text(label, {
                                fontSize: 9, top: top + 5, left: left - 0,
                                fill: color
                            });
                        },

                        // For flow connections.
                        initDataFlowConnection: function(name, desc, srcLeft, srcTop, destLeft, destTop) {
                            return {
                                [`${name}_line`]: new fabric.Line([srcLeft, srcTop, destLeft, destTop], {
                                    stroke: "#BDBDBD", strokeWidth: 1, opacity: 0.3
                                }),
                            };
                        },

                        renderDataFlowConnection: function(lineObj, active) {
                            let color = active ? "#4CAF50" : "#BDBDBD";
                            let width = active ? 2 : 1;
                            let opacity = active ? 1.0 : 0.3;
                        
                            // Update line
                            lineObj.set({
                                stroke: color, strokeWidth: width, opacity: opacity,
                            });
                        },
                        
                        // ===== CONNECTION ENDPOINT DEFINITIONS =====

                        // Endpoints
                        connectionPoints: function() {
                            // Constants characterizing endpoint positions
                            let scale = 1/3;  // Scale of sub-viz
                            let bit_width = 13 * scale;
                            let bit0_right = 10 * scale + 32 * bit_width;
                            let bit31_left = 10 * scale;
                            let pc_top = 65;
                            let imm_top = 105;
                            let rs1_top = 167;
                            let rs2_top = 177;
                            let buf1_top = 207;
                            let buf2_top = 232;
                            let aluAB_top = 196; let aluA_left = 180; let aluB_left = 210;
                            let aluOut_top = 230; let aluOut_left = 200;

                            return {
                                // Register File (left side) - using rs1/rs2 tops
                                rf_rs1_out: {x: bit0_right, y: rs1_top},
                                rf_rs2_out: {x: bit0_right, y: rs2_top}, 
                                
                                // Immediate Decoder - using imm_top
                                immdec_out: {x: bit31_left, y: rs1_top},
                                
                                // ALU - using your ALU coordinate constants
                                alu_a_in: {x: aluA_left, y: aluAB_top},
                                alu_b_in: {x: aluB_left, y: aluAB_top},
                                alu_result_out: {x: aluOut_left, y: aluOut_top},
                                
                                // BUFREG1 - using buf1_top
                                bufreg1_in: {x: bit31_left, y: buf1_top},
                                bufreg1_out: {x: bit0_right, y: buf1_top},
                                
                                // BUFREG2 - using buf2_top  
                                bufreg2_in: {x: bit31_left, y: buf2_top},
                                bufreg2_out: {x: bit0_right, y: buf2_top},
                                
                                // Control - using pc_top
                                ctrl_pc_in: {x: bit31_left, y: pc_top}, // Offset right for ctrl module
                                ctrl_pc_out: {x: bit0_right, y: pc_top},
                                ctrl_rf_out: {x: bit31_left + 90, y: pc_top + 10}, // PC+4 to RF for JAL/JALR
                                
                                // CSR (right side)
                                csr_rf_out: {x: bit0_right + 100, y: (rs1_top + rs2_top) / 2},
                                
                                // Memory Interface (right side - wire endpoints)
                                mem_addr_in: {x: bit0_right + 150, y: buf1_top + 20},
                                mem_data_in: {x: bit0_right + 150, y: buf2_top + 20},
                                mem_data_out: {x: bit0_right + 180, y: buf2_top + 20},
                                
                                // Immediate Decoder Mux Points (using imm_top for field selection)
                                immdec_mux_imm31: {x: bit0_right - bit_width * 31.5, y: imm_top},
                                immdec_mux_imm30_25: {x: bit0_right - bit_width * 25.5, y: imm_top},
                                immdec_mux_imm24_20: {x: bit0_right - bit_width * 20.5, y: imm_top},
                                immdec_mux_imm19_12: {x: bit0_right - bit_width * 12.5, y: imm_top},
                                immdec_mux_imm11_7: {x: bit0_right - bit_width * 7.5, y: imm_top},

                                // CTRL arithmetic inputs
                                ctrl_zero_gen: {x: bit31_left + 150, y: pc_top + 50},
                                ctrl_const4: {x: bit31_left + 180, y: pc_top + 50},
                                ctrl_a_in: {x: bit31_left + 200, y: pc_top + 50},
                                ctrl_b_in: {x: bit31_left + 220, y: pc_top + 50},

                                // RD register
                                rd_write_in: {x: bit31_left, y: rs1_top + 60},
                                rd_to_rd: {x: bit0_right, y: rs1_top + 60},
                            };
                        },

                        // ===== CONNECTION DEFINITIONS =====
                        connections: {
                            // ALU Input Connections
                            rs1_to_alu_a: {from: "rf_rs1_out", to: "alu_a_in", desc: "RS1→ALU_A"},
                            rs2_to_alu_b: {from: "rf_rs2_out", to: "alu_b_in", desc: "RS2→ALU_B"},
                            imm_to_alu_b: {from: "immdec_out", to: "alu_b_in", desc: "IMM→ALU_B"},
                            bufreg2_to_alu_b: {from: "bufreg2_out", to: "alu_b_in", desc: "BUF2→ALU_B"},
                            
                            // Register File to Buffer Connections
                            rs1_to_bufreg1: {from: "rf_rs1_out", to: "bufreg1_in", desc: "RS1→BUF1"},
                            rs2_to_bufreg2: {from: "rf_rs2_out", to: "bufreg2_in", desc: "RS2→BUF2"},
                            
                            // Immediate to Buffer Connections
                            imm_to_bufreg1: {from: "immdec_out", to: "bufreg1_in", desc: "IMM→BUF1"},
                            
                            // Buffer Output Connections
                            bufreg1_to_mem_addr: {from: "bufreg1_out", to: "mem_addr_in", desc: "BUF1→ADDR"},
                            bufreg1_to_pc: {from: "bufreg1_out", to: "ctrl_pc_in", desc: "BUF1→PC"},
                            bufreg2_to_mem_data: {from: "bufreg2_out", to: "mem_data_in", desc: "BUF2→DATA"},
                            
                            // Memory Connections
                            mem_to_bufreg2: {from: "mem_data_out", to: "bufreg2_in", desc: "MEM→BUF2"},
                            // ===== IMMEDIATE DECODER MUX CONNECTIONS =====
                            imm31_to_mux: {from: "immdec_mux_imm31", to: "immdec_out", desc: "IMM31"},
                            imm30_25_to_mux: {from: "immdec_mux_imm30_25", to: "immdec_out", desc: "IMM30:25"},
                            imm24_20_to_mux: {from: "immdec_mux_imm24_20", to: "immdec_out", desc: "IMM24:20"},
                            imm19_12_to_mux: {from: "immdec_mux_imm19_12", to: "immdec_out", desc: "IMM19:12"},
                            imm11_7_to_mux: {from: "immdec_mux_imm11_7", to: "immdec_out", desc: "IMM11:7"},

                            // CTRL arithmetic inputs
                            pc_to_ctrl_a: {from: "ctrl_pc_out", to: "ctrl_a_in", desc: "PC→CTRL_A"},
                            zero_to_ctrl_a: {from: "ctrl_zero_gen", to: "ctrl_a_in", desc: "0→CTRL_A"},
                            imm_to_ctrl_b: {from: "immdec_out", to: "ctrl_b_in", desc: "IMM→CTRL_B"},
                            const4_to_ctrl_b: {from: "ctrl_const4", to: "ctrl_b_in", desc: "4→CTRL_B"},

                            // RD connections (replace the old rf_write_in connections)
                            alu_to_rd: {from: "alu_result_out", to: "rd_write_in", desc: "ALU→RD"},
                            bufreg2_to_rd: {from: "bufreg2_out", to: "rd_write_in", desc: "BUF2→RD"}, 
                            csr_to_rd: {from: "csr_rf_out", to: "rd_write_in", desc: "CSR→RD"},
                            ctrl_to_rd: {from: "ctrl_rf_out", to: "rd_write_in", desc: "CTRL→RD"},
                        },
                        
                        // ===== HELPER FUNCTIONS =====
                        initAllConnections: function() {
                            let ret = {};
                            let connections = this.connections;
                            let points = this.connectionPoints();
                            
                            Object.keys(connections).forEach(connId => {
                                let conn = connections[connId];
                                let fromPt = points[conn.from];
                                let toPt = points[conn.to];

                                if (!fromPt || !toPt) {
                                    console.warn(`Connection ${connId} has invalid endpoints (${conn ? conn.from : 'undefined'}→${conn ? conn.to : 'undefined'})`);
                                    return;
                                }
                                
                                Object.assign(ret, this.initDataFlowConnection(
                                    connId, conn.desc, fromPt.x, fromPt.y, toPt.x, toPt.y
                                ));
                            });
                            
                            return ret;
                        },
                        
                        renderAllConnections: function(objContainer, activeConnections) {
                            Object.keys(this.connections).forEach(connId => {
                            let active = activeConnections[connId] || false;
                            this.renderDataFlowConnection(objContainer[`${connId}_line`], active);
                            });
                        }
                  },
                  init() {
                     let ret = {};
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

                    // Initialize all connections
                    Object.assign(ret, '/cpu'.lib.initAllConnections());
                    
                    
                    // ===== DEBUG: ENDPOINT LABELS =====
                    // Set to false to disable in production
                    let DEBUG_ENDPOINTS = true;
                    
                    if (DEBUG_ENDPOINTS) {
                        let points = '/cpu'.lib.connectionPoints();
                        
                        Object.keys(points).forEach(pointId => {
                            let point = points[pointId];
                            
                            // Create a small circle marker at each endpoint
                            ret[`debug_${pointId}_marker`] = new fabric.Circle({
                                radius: 3,
                                left: point.x,
                                top: point.y,
                                fill: "red",
                                stroke: "black",
                                strokeWidth: 1,
                                opacity: 0.8,
                                originX: "center",
                                originY: "center",
                                selectable: false
                            });
                            
                            // Create a text label for each endpoint
                            ret[`debug_${pointId}_label`] = new fabric.Text(pointId, {
                                fontSize: 6,
                                left: point.x + 5,  // Offset slightly to avoid overlap
                                top: point.y - 8,
                                fill: "red",
                                fontWeight: "bold",
                                opacity: 0.9,
                                selectable: false,
                                backgroundColor: "white"  // White background for readability
                            });
                        });
                        
                    }
                    
                    return ret;
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

                      // ===== GET CURRENT INSTRUCTION AND HISTORY =====

                      let history_depth = '/cpu'.lib.history_depth;

                      // Expose these:
                      data.instruction = 0;
                      data.instruction_valid = false;
                      data.instruction_asm = "---";
                      data.instruction_format = "---";
                      data.i_wb_rdt = this.svSigRef(cpu+"decode.i_wb_rdt");
                      data.total_cycles_completed = 0;
                      
                      // Initialize history
                      data.instruction_history = [];
                      let current = true;  // Flag to indicate if we are looking at the current instruction
                      try {
                          // Find when i_wb_en was last asserted (instruction load cycle)
                          let sig_obj = {
                              i_wb_en: this.svSigRef(cpu+"immdec.i_wb_en"),
                              i_wb_rdt: this.svSigRef(cpu+"decode.i_wb_rdt")
                          };

                          let sigs = this.signalSet(sig_obj);

                          // Look for when i_wb_en was last asserted
                          for (let step = 0; step <= 70 * history_depth; step++) {
                              // Step back.
                              sigs.step(-1);
                              if (current) {
                                data.i_wb_rdt.step(-1);
                              }

                              let wb_en = sigs.sig("i_wb_en").asBool(false);

                              if (wb_en) {
                                  // Found when instruction was loaded
                                  // Update history.
                                  let i_wb_rdt_partial = sigs.sig("i_wb_rdt").asInt(0);
                                  // Try to decode the instruction if we have the decoder available (loaded asynchronously)
                                  let instruction = {
                                      asInt: (i_wb_rdt_partial << 2) | 0x3,
                                      asm: "LOADING DISASSEMBLER...",
                                      format: "?"
                                  };
                                  if (this.Decoder) {
                                      try {
                                          let instruction_obj = new this.Decoder(instruction.asInt.toString(2).padStart(32, "0"), {});
                                          instruction.asm = instruction_obj.asm || "DECODED";
                                          instruction.format = instruction_obj.fmt || "?";
                                      } catch(e) {
                                          // Leave defaults.
                                      }
                                  }
                                  data.instruction_history.push(instruction);
                                  if (data.instruction_history.length > history_depth) {
                                      // Filled the history. All done.
                                      break;
                                  }
                                  if (current) {
                                    if (this.svSigRef(cpu+"state.o_ibus_cyc").asBool(true)) {
                                        // Show no instruction during FETCH.
                                        data.instruction = 0;
                                        data.instruction_asm = "---";
                                        data.instruction_format = "---";
                                        data.instruction_valid = false;
                                        data.total_cycles_completed = 0;
                                    } else {
                                        // Current instruction.
                                        data.instruction = instruction.asInt;
                                        data.instruction_asm = instruction.asm;
                                        data.instruction_format = instruction.format;
                                        data.instruction_valid = true;
                                       data.total_cycles_completed = step;
                                    }

                                     current = false; // Done with the current instruction
                                  }
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

                          // Get additional signals for new 8-phase lifecycle phases
                          data.ibus_cyc = this.svSigRef(cpu+"state.o_ibus_cyc").asBool(false);
                          data.ibus_ack = this.svSigRef(cpu+"state.i_ibus_ack").asBool(false);
                          data.rf_rreq = this.svSigRef(cpu+"state.o_rf_rreq").asBool(false);
                          data.rf_ready = this.svSigRef(cpu+"state.i_rf_ready").asBool(false);
                          data.init_done = this.svSigRef(cpu+"state.init_done").asBool(false);
                          data.o_ctrl_jump = this.svSigRef(cpu+"state.o_ctrl_jump").asBool(false);

                      } catch(e) {
                          data.cnt_en = false;
                          data.cnt_done = false;
                          data.init = false;
                          data.wb_en = false;
                          data.ibus_cyc = false;
                          data.ibus_ack = false;
                          data.rf_rreq = false;
                          data.rf_ready = false;
                          data.init_done = false;
                          data.o_ctrl_jump = false;
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

                      let types = ["UNKNOWN", "unknown"]; // Default to unknown type
                      if (data.instruction_valid) {
                          let instr = data.instruction;
                          let opcode = (instr >> 2) & 0x1F; // bits [6:2]

                          // Determine opcode type and instruction type based on opcode
                          types = (opcode == 0x0D) ? ["LUI", "u"] :
                                  (opcode == 0x05) ? ["AUIPC", "u"] :
                                  (opcode == 0x1B) ? ["JAL", "j"] :
                                  (opcode == 0x19) ? ["JALR", "i"] :
                                  (opcode == 0x18) ? ["BRANCH", "b"] :
                                  (opcode == 0x00) ? ["LOAD", "i"] :
                                  (opcode == 0x08) ? ["STORE", "s"] :
                                  (opcode == 0x04) ? ["OP-IMM", "i"] :
                                  (opcode == 0x0C) ? ["OP", "r"] :
                                  (opcode == 0x03) ? ["FENCE", "f"] :
                                  (opcode == 0x1C) ? ["SYSTEM", "f"] :
                                                     ["UNKNOWN", "unknown"];
                      }
                      // Expose.
                      data.opcodeType = types[0];
                      data.instrType = types[1];

                      // ===== NEW: ENHANCED INSTRUCTION LIFECYCLE ANALYSIS (8-PHASE MODEL) =====

                      try {
                          // Determine if this is a two-stage operation
                          data.is_two_stage = data.active_units.two_stage || 
                                            ["LOAD", "STORE", "BRANCH", "JAL", "JALR"].includes(data.opcodeType) ||
                                            data.opcodeType === "SYSTEM"; // shifts and SLT are also two-stage

                           // Enhanced lifecycle phase determination with new 8-phase model
                           data.lifecycle_phase = "UNKNOWN";

                           try {
                               // Get previous cycle state using signalSet for transitions
                               let prev_cnt_done = false;
                               let prev_init = false;
                               let prev_ibus_cyc = false;
                               let prev_ibus_ack = false;
                               let prev_rf_rreq = false;
                               let prev_rf_ready = false;

                               try {
                                   let sig_obj = {
                                       cnt_done: this.svSigRef(cpu+"state.o_cnt_done"),
                                       init: this.svSigRef(cpu+"state.o_init"),
                                       ibus_cyc: this.svSigRef(cpu+"state.o_ibus_cyc"),
                                       ibus_ack: this.svSigRef(cpu+"state.i_ibus_ack"),
                                       rf_rreq: this.svSigRef(cpu+"state.o_rf_rreq"),
                                       rf_ready: this.svSigRef(cpu+"state.i_rf_ready")
                                   };
                                   let sigs = this.signalSet(sig_obj);
                                   sigs.step(-1);  // Go back 1 cycle
                                   prev_cnt_done = sigs.sig("cnt_done").asBool(false);
                                   prev_init = sigs.sig("init").asBool(false);
                                   prev_ibus_cyc = sigs.sig("ibus_cyc").asBool(false);
                                   prev_ibus_ack = sigs.sig("ibus_ack").asBool(false);
                                   prev_rf_rreq = sigs.sig("rf_rreq").asBool(false);
                                   prev_rf_ready = sigs.sig("rf_ready").asBool(false);
                               } catch(e) {
                                   // If we can't look back, just use defaults
                               }

                               // 8-Phase RTL-accurate phase detection
                               // Based on SERV state machine and signal transitions

                               // Debug current state
                               console.log(`=== PHASE DETECTION DEBUG ===`);
                               console.log(`ibus_cyc=${data.ibus_cyc}, ibus_ack=${data.ibus_ack}, rf_rreq=${data.rf_rreq}, rf_ready=${data.rf_ready}`);
                               console.log(`cnt_en=${data.cnt_en}, init=${data.init}, cnt_done=${data.cnt_done}, init_done=${data.init_done}`);
                               console.log(`prev_rf_rreq=${prev_rf_rreq}`);

                               // Priority order is critical - check most specific conditions first

                               // 5&8. INIT & EXECUTE
                               if (data.cnt_en) {
                                   data.lifecycle_phase = data.init ? "INIT" : "EXECUTE";

                               // 6&7. WRITEBACK & PC_UPDATE
                               } else if (data.init_done) {
                                   data.lifecycle_phase = data.rf_ready ? "PC_UPDATE" : "WRITEBACK";
                               
                               // 1&2. FETCH1&2
                               } else if (data.ibus_cyc) {
                                   data.lifecycle_phase = data.ibus_ack ? "FETCH2" : "FETCH1";
                               
                               // 3&4. DECODE & SETUP
                               } else if (true) {
                                   data.lifecycle_phase = data.rf_ready ? "SETUP" : "DECODE";

                               // Default to IDLE
                               } else {
                                   data.lifecycle_phase = "IDLE";
                               }

                               console.log(`=== PHASE RESULT: ${data.lifecycle_phase} ===`);

                           } catch(e) {
                               console.warn("Error in phase detection:", e);
                               data.lifecycle_phase = "IDLE";
                           }

                        // Calculate total instruction cycles and progress for 8-phase model
                        if (data.is_two_stage) {
                            data.total_instruction_cycles = 70; // FETCH1(1) + FETCH2(1) + DECODE(1) + SETUP(1) + INIT(32) + WRITEBACK(1) + PC_UPDATE(1) + EXECUTE(32)
                        } else {
                            data.total_instruction_cycles = 36; // FETCH1(1) + FETCH2(1) + DECODE(1) + SETUP(1) + EXECUTE(32)
                        }

                        // Calculate progress percentage
                        data.instruction_progress = Math.min(data.total_cycles_completed / data.total_instruction_cycles, 1.0);

                        // Determine which components should be active in current phase
                        data.active_in_phase = {
                            fetch: data.lifecycle_phase === "FETCH1" || data.lifecycle_phase === "FETCH2",
                            decode: data.lifecycle_phase === "DECODE",
                            immdec: data.lifecycle_phase === "INIT" || data.lifecycle_phase === "EXECUTE",
                            rf_read: data.lifecycle_phase === "INIT" || data.lifecycle_phase === "EXECUTE",
                            alu: data.lifecycle_phase === "EXECUTE" && data.active_units.alu,
                            bufreg: data.lifecycle_phase === "INIT" && data.active_units.bufreg,
                            bufreg2: data.active_units.mem || data.opcodeType.includes("SHIFT"),
                            mem_if: data.lifecycle_phase === "EXECUTE" && data.active_units.mem,
                            ctrl: (data.lifecycle_phase === "EXECUTE" && data.active_units.ctrl) || data.lifecycle_phase === "PC_UPDATE",
                            csr: data.active_units.csr,
                            rf_write: data.lifecycle_phase === "EXECUTE" || data.lifecycle_phase === "WRITEBACK"
                        };

                      } catch(e) {
                          console.warn("Error in lifecycle analysis:", e);
                          data.lifecycle_phase = "ERROR";
                          data.is_two_stage = false;
                      }


                      // ===== BUS ACTIVITY TRACKING =====

                      try {
                          data.bus_activity = {
                              ibus_cyc: data.ibus_cyc,
                              ibus_ack: data.ibus_ack,
                              ibus_active: data.ibus_cyc && !data.ibus_ack,
                              fetch_in_progress: data.ibus_cyc
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
                          data.bus_activity = {
                              ibus_cyc: false,
                              ibus_ack: false,
                              ibus_active: false,
                              fetch_in_progress: false
                          };
                      }

                      // ===== SUMMARY DEBUG OUTPUT (8-PHASE MODEL) =====

                      console.log("=== CPU CENTRAL DATA (8-PHASE MODEL) ===");
                      console.log(`Lifecycle: ${data.lifecycle_phase}`);
                      console.log(`Signals: ibus_cyc=${data.ibus_cyc}, ibus_ack=${data.ibus_ack}, rf_rreq=${data.rf_rreq}, rf_ready=${data.rf_ready}`);
                      console.log(`Control: cnt_en=${data.cnt_en}, init=${data.init}, cnt_done=${data.cnt_done}, init_done=${data.init_done}`);
                      console.log(`Bit: ${data.current_bit}/31, Cycle in phase: ${data.current_bit}`);
                      console.log(`Progress: ${(data.instruction_progress * 100).toFixed(1)}% (${data.total_cycles_completed}/${data.total_instruction_cycles})`);
                      console.log(`Instruction: 0x${data.instruction.toString(16).padStart(8, "0")} (${data.opcodeType})`);
                      console.log(`ASM: ${data.instruction_asm} [${data.is_two_stage ? "2-STAGE" : "1-STAGE"}]`);
                      console.log(`Active units:`, data.active_units);
                      console.log(`Bus activity:`, data.bus_activity);

                      if (data.instruction_history && data.instruction_history.length > 0) {
                          console.log(`Recent instructions: ${data.instruction_history.slice(0, 3).map(i => i.asm).join(", ")}`);
                      }
                  },
                  render() {
                                            
                        // Get all signal values
                        let cpu = "top.servant_sim.dut.cpu.cpu.";
                        let cnt_en = this.svSigRef(cpu+"state.o_cnt_en").asBool(false);
                        let op_b_sel = this.svSigRef(cpu+"bufreg2.i_op_b_sel").asBool(false);
                        let rd_alu_en = this.svSigRef(cpu+"decode.o_rd_alu_en").asBool(false);
                        let init = this.svSigRef(cpu+"state.o_init").asBool(false);
                        let dbus_en = this.svSigRef(cpu+"decode.o_dbus_en").asBool(false);
                        let dbus_we = this.svSigRef(cpu+"o_dbus_we").asBool(false);
                        let dbus_ack = this.svSigRef(cpu+"i_dbus_ack").asBool(false);
                        let bufreg_rs1_en = this.svSigRef(cpu+"decode.o_bufreg_rs1_en").asBool(false);
                        let bufreg_imm_en = this.svSigRef(cpu+"decode.o_bufreg_imm_en").asBool(false);
                        let branch_op = this.svSigRef(cpu+"decode.o_branch_op").asBool(false);
                        let jal_or_jalr = this.svSigRef(cpu+"decode.o_ctrl_jal_or_jalr").asBool(false);
                        let rd_mem_en = this.svSigRef(cpu+"decode.o_rd_mem_en").asBool(false);
                        let csr_en = this.svSigRef(cpu+"decode.o_csr_en").asBool(false);
                        let rd_csr_en = this.svSigRef(cpu+"decode.o_rd_csr_en").asBool(false);
                        let shift_op = this.svSigRef(cpu+"decode.o_shift_op").asBool(false);
                        let immdec_en = this.svSigRef(cpu+"immdec.i_immdec_en").asInt(0);
                        let i_ctrl = this.svSigRef(cpu+"immdec.i_ctrl").asInt(0);
                        // Get CTRL-specific signals
                        /*
                        let ctrl_pc_en = this.svSigRef(cpu+"state.o_ctrl_pc_en").asBool(false);
                        let ctrl_jump = this.svSigRef(cpu+"state.o_ctrl_jump").asBool(false);
                        let utype = this.svSigRef(cpu+"decode.o_ctrl_utype").asBool(false);
                        let pc_rel = this.svSigRef(cpu+"decode.o_ctrl_pc_rel").asBool(false);
                        let trap = this.svSigRef(cpu+"state.o_ctrl_trap").asBool(false);
                        let mret = this.svSigRef(cpu+"decode.o_ctrl_mret").asBool(false);
                        */

                        // Evaluate all connection conditions
                        let activeConnections = {
                            // ALU Input Connections
                            rs1_to_alu_a: cnt_en,
                            rs2_to_alu_b: cnt_en && op_b_sel,
                            imm_to_alu_b: cnt_en && !op_b_sel,
                            bufreg2_to_alu_b: cnt_en && shift_op,
                            
                            // PC to CTRL operand A (for PC+4, PC+immediate, AUIPC)
                            pc_to_ctrl_a: ctrl_pc_en && (jal_or_jalr || branch_op || !utype),
                            
                            // Zero to CTRL operand A (for LUI instructions)
                            zero_to_ctrl_a: ctrl_pc_en && utype && (cpuData.opcodeType === "LUI"),
                            
                            // Immediate to CTRL operand B (for PC+immediate, AUIPC, LUI)
                            imm_to_ctrl_b: ctrl_pc_en && (branch_op || jal_or_jalr || utype),
                            
                            // Constant 4 to CTRL operand B (for PC+4 increment)
                            const4_to_ctrl_b: ctrl_pc_en && !(branch_op || jal_or_jalr || utype),

                            // ALU Output Connections
                            alu_to_rd: cnt_en && rd_alu_en,
                            
                            // Register File to Buffer Connections
                            rs1_to_bufreg1: init && bufreg_rs1_en,
                            rs2_to_bufreg2: init && dbus_en && dbus_we,
                            
                            // Immediate to Buffer Connections
                            imm_to_bufreg1: init && bufreg_imm_en,
                            
                            // Buffer Output Connections
                            bufreg1_to_mem_addr: dbus_en,
                            bufreg1_to_pc: branch_op || jal_or_jalr,
                            bufreg2_to_mem_data: dbus_en && dbus_we,
                            
                            // Memory Connections
                            mem_to_bufreg2: dbus_ack && !dbus_we,
                            bufreg2_to_rd: rd_mem_en,
                            
                            // CSR and Control Connections
                            csr_to_rd: csr_en && rd_csr_en,
                            ctrl_to_rd: jal_or_jalr,
                            
                            // RD register to actual RF write
                            rd_to_register_file: cnt_en && (rd_alu_en || rd_mem_en || rd_csr_en) || 
                                    (ctrl_pc_en && (jal_or_jalr || utype)),
                            
                            // Immediate Decoder Mux Connections
                            imm31_to_mux: (immdec_en & 0x8) && (i_ctrl & 0x8),
                            imm30_25_to_mux: (immdec_en & 0x8) !== 0,
                            imm24_20_to_mux: (immdec_en & 0x4) !== 0,
                            imm19_12_to_mux: (immdec_en & 0x2) !== 0,
                            imm11_7_to_mux: (immdec_en & 0x1) !== 0
                        };
                        
                        // Render all connections
                        '/cpu'.lib.renderAllConnections(this.obj, activeConnections);

                  }
                  
               // SERV core main modules arranged in logical data flow order

               /history
                  \viz_js
                     box: {width: 150, height: 110, top: -110, strokeWidth: 1},
                     where: {left: 0, top: -150, width: 150, height: 110},
                     init() {
                        this.history_depth = '/cpu'.lib.history_depth;
                        let ret = {};
                        ret.title = new fabric.Text("Instruction History", {fontSize: 12, fontWeight: "bold", top: -(15 + this.history_depth * 10), left: 150 / 2, originY: "center", originX: "center"});
                        for(let i = 0; i < this.history_depth; i++) {
                            ret[`inst_${i}`] = new fabric.Text("", {fontSize: 8, fontWeight: i ? "normal" : "bold", top: -(12 + i * 10), left: 25});
                        }
                        return ret;
                     },
                     render() {
                        // Update history text dynamically
                        let history = '/cpu'.data.instruction_history;
                        for(let i = 0; i < this.history_depth; i++) {
                           if(history[i]) {
                              this.obj[`inst_${i}`].set("text", history[i].asm);
                           } else {
                              this.obj[`inst_${i}`].set("text", "");
                           }
                        }
                     }
               /lifecycle  // Global instruction lifecycle visualization
                  \viz_js
                     box: {width: 685, height: 120, strokeWidth: 1},
                     where: {left: 0, top: -30, width: 150, height: 30},
                     init() {
                        let ret = {};

                        // ===== MAIN TITLE =====
                        ret.title = new fabric.Text("SERV Instruction Lifecycle", {fontSize: 14, fontWeight: "bold", top: -20, left: 25 + 635 / 2, originY: "center", originX: "center"});

                        // ===== LIFECYCLE PHASE VISUALIZATION =====

                        // Background timeline
                        ret.timeline_bg = new fabric.Rect({width: 635, height: 50, top: 10, left: 25, fill: "#f5f5f5", stroke: "#333", strokeWidth: 2});

                        // Define 8 phases as an object: 6 single-cycle + 2 multi-cycle (all lowercase names)
                        let phases = '/cpu'.lib.phases;

                        // Create phase boxes with calculated positions and
                        // store positions in phases object.
                        let currentLeft = 25;
                        Object.keys(phases).forEach((key) => {
                           let phase = phases[key];
                           let phaseWidth = phase.is_multi ? 120 : 60;
                           ret[`${phase.name}_phase`] = new fabric.Rect({width: phaseWidth, height: 50, top: 10, left: currentLeft, fill: phase.color, stroke: "#333", strokeWidth: 1, opacity: 0.3});
                           
                           // Use smaller font for longer names to fit in narrow boxes
                           let fontSize = phase.is_multi ? 18 : (phase.name.length > 7 ? 12 : 16);
                           ret[`${phase.name}_label`] = new fabric.Text(phase.name, {fontSize: fontSize, fontWeight: "bold", top: 35, left: currentLeft + phaseWidth/2, originX: "center", originY: "center", fill: "#333"});
                           phases[key].left = currentLeft;
                           currentLeft += phaseWidth;
                           phases[key].right = currentLeft;
                           currentLeft += 5; // Add 5px spacing between phases
                        });
                        
                        // Current phase indicator (animated arrow)
                        ret.phase_pointer = new fabric.Triangle({width: 20, height: 15, top: 65, left: 100, fill: "#FF5722", stroke: "#333", strokeWidth: 1, angle: 180});

                        // Progress bar within current multi-cycle phase (only shown for INIT/EXECUTE)
                        ret.progress_bar = new fabric.Rect({width: 0, height: 8, top: 15, left: 25, fill: "rgba(255, 87, 34, 0.8)"});

                        // ===== INSTRUCTION INFORMATION =====

                        // Current instruction box
                        ret.current_instr_bg = new fabric.Rect({width: 615, height: 25, top: 75, left: 35, fill: "#fff", stroke: "#666", strokeWidth: 1});
                        ret.current_instr_label = new fabric.Text("Current:", {fontSize: 8, fontWeight: "bold", top: 78, left: 40});
                        ret.current_instr_text = new fabric.Text("No instruction", {fontSize: 10, fontFamily: "monospace", top: 85, left: 85});
                        ret.stage_indicator = new fabric.Text("1-STAGE", {fontSize: 8, fontWeight: "bold", top: 78, left: 550, fill: "#666"});
                        ret.progress_text = new fabric.Text("0%", {fontSize: 10, fontWeight: "bold", top: 82, left: 620, fill: "#FF5722"});

                        // ===== STATUS/BUS ACTIVITY INDICATORS =====

                        ret.status_indicators_label = new fabric.Text("Status:", {fontSize: 8, fontWeight: "bold", top: 70, left: 25});
                        ret.rf_write_indicator = new fabric.Circle({radius: 5, left: 70, top: 72, originY: "center", originX: "center", fill: "#4CAF50", stroke: "#333", strokeWidth: 1, opacity: 0.3});
                        ret.rf_write_label = new fabric.Text("RF Write", {fontSize: 6, top: 82, left: 70, originY: "center", originX: "center"});
                        ret.pc_update_indicator = new fabric.Circle({radius: 5, left: 140, top: 72, originY: "center", originX: "center", fill: "#FF9800", stroke: "#333", strokeWidth: 1, opacity: 0.3});
                        ret.pc_update_labelx = new fabric.Text("PC Update", {fontSize: 6, top: 82, left: 140, originY: "center", originX: "center"});

                        ret.bus_label = new fabric.Text("Bus:", {fontSize: 8, top: 95, left: 40});
                        ret.ibus_indicator = new fabric.Circle({radius: 5, left: 70, top: 97, originY: "center", originX: "center", fill: "#ccc", stroke: "#333", strokeWidth: 1});
                        ret.ibus_label = new fabric.Text("IBUS", {fontSize: 6, top: 105, left: 70, originY: "center", originX: "center"});
                        ret.dbus_indicator = new fabric.Circle({radius: 5, left: 100, top: 97, originY: "center", originX: "center", fill: "#ccc", stroke: "#333", strokeWidth: 1});
                        ret.dbus_label = new fabric.Text("DBUS", {fontSize: 6, top: 105, left: 100, originY: "center", originX: "center"});

                        // ===== INSTRUCTION HISTORY =====

                        ret.history_label = new fabric.Text("Recent:", {fontSize: 8, top: 95, left: 140});
                        ret.history_text = new fabric.Text("", {fontSize: 8, fontFamily: "monospace", top: 95, left: 180});

                        // ===== CYCLE COUNTER =====

                        ret.cycle_label = new fabric.Text("Cycle:", {fontSize: 8, top: 95, left: 550});
                        ret.cycle_text = new fabric.Text("0/32", {fontSize: 10, fontWeight: "bold", fontFamily: "monospace", top: 93, left: 585, fill: "#666"});
                        ret.bit_text = new fabric.Text("Bit: 0", {fontSize: 8, top: 105, left: 585, fontFamily: "monospace", fill: "#666"});

                        return ret;
                     },
                     render() {
                        // Get centralized data from CPU
                        let cpuData = '/cpu'.data;
                        let cpuLib = '/cpu'.lib;
                        cpu = "top.servant_sim.dut.cpu.cpu.";

                        console.log("=== LIFECYCLE RENDER (8-PHASE) ===");
                        console.log(`Phase: ${cpuData.lifecycle_phase}, Progress: ${(cpuData.instruction_progress * 100).toFixed(1)}%`);

                        // ===== UPDATE PHASE HIGHLIGHTING =====

                        // Phase highlighting and pointer/progress positions
                        let phases = Object.keys(cpuLib.phases);
                        phases.forEach(phase => {
                           let isActive = cpuData.lifecycle_phase.toLowerCase() === phase;
                           let phaseObj = this.obj[`${phase}_phase`];
                           let labelObj = this.obj[`${phase}_label`];

                           if (phaseObj && labelObj) {
                              phaseObj.set({opacity: isActive ? 1.0 : 0.3, strokeWidth: isActive ? 3 : 1});
                              labelObj.set({fontWeight: isActive ? "bold" : "normal", fill: isActive ? "#000" : "#666"});
                           }
                        });

                        // ===== UPDATE PHASE POINTER =====

                        // Use center of phase box for pointer position
                        let currentPhase = cpuData.lifecycle_phase.toLowerCase();
                        let pointerPosition = 105; // default
                        if (cpuLib.phases[currentPhase]) {
                           let phase = cpuLib.phases[currentPhase];
                           pointerPosition = phase.left + (phase.right - phase.left) / 2;
                        }
                        this.obj.phase_pointer.set({left: pointerPosition, fill: '/cpu'.lib.getLifecycleColor(cpuData.lifecycle_phase)});

                        // ===== UPDATE PROGRESS BAR =====

                        let progressWidth = 0;
                        let progressLeft = 25;
                        let showProgressBar = false;

                        // Position progress bars
                        const phase = cpuLib.phases[currentPhase];
                        if (phase && phase.is_multi) {
                           progressLeft = phase.left;
                           progressWidth = (phase.right - phase.left) * ((cpuData.current_bit + 1) / 32.0);
                           showProgressBar = true;
                        }

                        this.obj.progress_bar.set({
                           left: progressLeft,
                           width: Math.max(0, progressWidth),
                           opacity: showProgressBar ? 0.8 : 0.0
                        });

                        // Only show progress bar for multi-cycle phases (INIT and EXECUTE)
                        if (currentPhase === "init" || currentPhase === "execute") {
                           progressLeft = cpuLib.phases[currentPhase].left; // Phase start position
                           progressWidth = 120 * ((cpuData.current_bit + 1) / 32.0);
                           showProgressBar = true;
                        }

                        this.obj.progress_bar.set({
                           left: progressLeft,
                           width: Math.max(0, progressWidth),
                           opacity: showProgressBar ? 0.8 : 0.0
                        });

                        // ===== UPDATE STATUS/BUS INDICATORS =====

                        // RF Write active during EXECUTE when writing results
                        let rf_writing = (cpuData.lifecycle_phase === "EXECUTE" && cpuData.active_units.rf);
                        this.obj.rf_write_indicator.set({opacity: rf_writing ? 1.0 : 0.3, fill: rf_writing ? "#4CAF50" : "#C8E6C9"});

                        // PC Update active during PC_UPDATE phase or when ctrl_pc_en is active
                        let pc_updating = (cpuData.lifecycle_phase === "PC_UPDATE") || this.svSigRef(cpu+"state.o_ctrl_pc_en").asBool(false);
                        this.obj.pc_update_indicator.set({opacity: pc_updating ? 1.0 : 0.3, fill: pc_updating ? "#FF9800" : "#FFCC80"});

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
                           fill: showDbus ? (busActivity.dbus_active ? "#4CAF50" : (busActivity.dbus_cyc ? "#FFC107" : "#ccc")) : "#ccc",
                           strokeWidth: (showDbus && busActivity.dbus_cyc) ? 2 : 1
                        });

                        // ===== UPDATE INSTRUCTION INFORMATION =====

                        if (cpuData.instruction_valid) {
                           let instrText = `${cpuData.instruction_asm} (0x${cpuData.instruction.toString(16).padStart(8, "0").toUpperCase()}) [${cpuData.opcodeType}]`;
                           this.obj.current_instr_text.set({text: instrText, fill: "#000"});
                        } else {
                           this.obj.current_instr_text.set({text: "No valid instruction", fill: "#999"});
                        }

                        // Stage indicator
                        let stageText = cpuData.is_two_stage ? "2-STAGE" : "1-STAGE";
                        let stageColor = cpuData.is_two_stage ? "#FF9800" : "#2196F3";
                        this.obj.stage_indicator.set({text: stageText, fill: stageColor});

                        // Progress percentage
                        this.obj.progress_text.set({text: `${(cpuData.instruction_progress * 100).toFixed(0)}%`});

                        // ===== UPDATE INSTRUCTION HISTORY =====

                        if (cpuData.instruction_history && cpuData.instruction_history.length > 0) {
                           let historyText = cpuData.instruction_history.slice(1, 4).map(instr => instr.asm || "???").join(", ");
                           this.obj.history_text.set({text: historyText, fill: "#666"});
                        } else {
                           this.obj.history_text.set({text: "No history", fill: "#ccc"});
                        }

                        // ===== UPDATE CYCLE INFORMATION =====

                        let cycleText = `${cpuData.total_cycles_completed}/${cpuData.total_instruction_cycles}`;
                        this.obj.cycle_text.set({text: cycleText, fill: cpuData.lifecycle_phase !== "IDLE" ? "#333" : "#999"});
                        this.obj.bit_text.set({text: `Bit: ${cpuData.current_bit}`, fill: cpuData.lifecycle_phase !== "IDLE" ? "#666" : "#ccc"});

                        // ===== BACKGROUND COLOR BASED ON ACTIVITY =====

                        let bgColor = "#f5f5f5";
                        if (currentPhase === "execute" || currentPhase === "init") {
                           bgColor = "#f0f8f0"; // Light green tint for multi-cycle phases
                        } else if (currentPhase === "fetch1" || currentPhase === "fetch2") {
                           bgColor = "#f0f8ff"; // Light blue tint for fetch phases
                        } else if (currentPhase === "decode" || currentPhase === "setup") {
                           bgColor = "#fffdf0"; // Light yellow tint for decode/setup
                        }

                        this.obj.timeline_bg.set({fill: bgColor});

                        // ===== INSTRUCTION BOX COLOR CODING =====

                        let instrBgColor = "#fff";
                        if (cpuData.instruction_valid) {
                           if (currentPhase === "execute" || currentPhase === "init") {
                              instrBgColor = "#e8f5e8"; // Light green
                           } else if (currentPhase === "fetch1" || currentPhase === "fetch2") {
                              instrBgColor = "#e3f2fd"; // Light blue
                           }
                        }

                        this.obj.current_instr_bg.set({fill: instrBgColor});

                        // ===== DEBUG BUS STATE =====
                        try {
                            let ibus_cyc = this.svSigRef(cpu+"state.o_ibus_cyc").asBool(false);
                            let ibus_ack = this.svSigRef(cpu+"state.i_ibus_ack").asBool(false);
                            let ibus_adr = this.svSigRef(cpu+"o_ibus_adr").asInt(0);

                            // Only log when IBUS state changes
                            this.prev_ibus_state = this.prev_ibus_state || {};
                            let prev_cyc = this.prev_ibus_state.cyc || false;
                            let prev_ack = this.prev_ibus_state.ack || false;

                            if (ibus_cyc !== prev_cyc || ibus_ack !== prev_ack) {
                                console.log(`=== IBUS STATE CHANGE ===`);
                                console.log(`cyc: ${prev_cyc} → ${ibus_cyc}`);
                                console.log(`ack: ${prev_ack} → ${ibus_ack}`);
                                console.log(`address: 0x${ibus_adr.toString(16)}`);
                                console.log(`phase: ${cpuData.lifecycle_phase}`);
                            }

                            this.prev_ibus_state = {cyc: ibus_cyc, ack: ibus_ack};

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
                     box: {top: -10, width: 150, height: 60, strokeWidth: 1},
                     where: {left: 0, top: -10, width: 150, height: 60},
                     
                     init() {
                        ret = {
                           // Title
                           title: new fabric.Text("serv_decode", {fontSize: 8, fontWeight: "bold", top: -5, left: 75, originY: "center", originX: "center", selectable: false}),
                           
                           // Instruction display box
                           instr_box: new fabric.Rect({width: 130, height: 16, top: 5, left: 10, fill: "lightgray", stroke: "black", strokeWidth: 1, selectable: false}),
                           
                           // Assembled instruction
                           asm_text: new fabric.Text("", {fontSize: 7, top: 6, left: 15, selectable: false}),
                           
                           // Instruction format and hex
                           format_text: new fabric.Text("", {fontSize: 5, top: 15, left: 15, selectable: false}),
                           
                           hex_text: new fabric.Text("", {fontSize: 5, top: 15, left: 90, fontFamily: "monospace", selectable: false}),
                           
                           // Progress bar background
                           progress_bar: new fabric.Rect({width: 130, height: 6, top: 25, left: 10, fill: "white", stroke: "black", strokeWidth: 1, selectable: false}),
                           
                           // Progress bar fill
                           progress_fill: new fabric.Rect({width: 0, height: 6, top: 25, left: 10, fill: "blue", selectable: false}),
                           
                           // Cycle counter
                           cycle_text: new fabric.Text("0/32", {fontSize: 4, top: 34, left: 75, originY: "center", originX: "center", selectable: false}),
                           
                           // Control signal groups label
                           ctrl_label: new fabric.Text("Control Groups:", {fontSize: 5, top: 42, left: 5, fontWeight: "bold", selectable: false}),
                        };

                        // Helper to create an indicator circle and label, added to ret.
                        this.indicators = {
                            alu: ["ALU", "#ff6b6b", 10],
                            mem: ["MEM", "#4ecdc4", 28],
                            csr: ["CSR", "#45b7d1", 46],
                            ctrl: ["CTRL", "#96ceb4", 64],
                            buf: ["BUF", "#ffeaa7", 82],
                            rf: ["RF", "#dda0dd", 100],
                            stage: ["2ST", "#ff9ff3", 118]
                        }
                        makeIndicator = (key, label, color, left) => {
                           ret[`${key}_indicator`] = new fabric.Circle({
                              radius: 3, left: left, top: 37, originY: "center", originX: "center",
                              fill: color, stroke: "black", strokeWidth: 0.5, selectable: false
                           });
                           ret[`${key}_label`] = new fabric.Text(label, {
                              fontSize: 3, top: 43, left: left, originY: "center", originX: "center", selectable: false
                           });
                        }
                        // Use a loop to create all indicators using the indicators object
                        Object.entries(this.indicators).forEach(([key, [label, color, left]]) => {
                           makeIndicator(key, label, color, left);
                        });

                        // Overall validity border
                        ret.valid_border = new fabric.Rect({
                           width: 148, height: 60, top: -10, left: 0, fill: "transparent", stroke: "green", strokeWidth: 2, selectable: false
                        });

                        return ret;
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

                         // Default control indicators (all inactive) using this.indicators
                         Object.keys(this.indicators).forEach(key => {
                             this.obj[`${key}_indicator`].set({opacity: 0.3});
                         });

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
                             left: 200, top: -15, originY: "center", originX: "center"
                         });

                         // ===== 1. ALL 32 INSTRUCTION BITS IN A SINGLE ROW =====

                         Object.assign(ret, '/top'.lib.initShiftRegister("instruction", {
                             bitWidth: this.bit_size, bitHeight: this.bit_size, spacing: 1, labelSize: 6, showLabel: true,
                             left: 10, top: 10,
                             lsb: 2, width: 30, transparencyMask: 0x3FFFFFE0  // Bits 29:5 are immediate bits (opaque)
                         }));
                         ret.instruction_label.set({text: "Instruction [31:2]:"});

                         // ===== 2. IMMEDIATE FIELDS: ALIGNED TO INSTRUCTION POSITIONS AND IMMEDIATE VALUE POSITIONS =====

                         let bit_spacing = this.bit_size + 1;
                         let field_top = 40;
                         let final_top = 80, final_left = 10;

                         immFields = '/cpu'.lib.immFields;
                         // Helper to add a field with standard layout, and also add a corresponding "final" field for the final immediate value row
                         addImmField = (name) => {
                            let immField = immFields[name];
                            let left = 10 + (31 - immField.msb) * bit_spacing;
                            let lsb = immField.lsb;
                            let width = immField.width;
                            let label = immField.label;
                             // Instruction-aligned field (row 2)
                             props = {
                                [name]: {top: field_top},
                                ["final_"+name]: {top: final_top + 15},
                             };
                             for (let id in props) {
                                Object.assign(ret, '/top'.lib.initShiftRegister(id, {
                                    bitWidth: this.bit_size, bitHeight: 10, labelSize: 4, showLabel: true, label: label,
                                    left: left, lsb: lsb, width: width,
                                    ...props[id],
                                    ...immField.args
                                }));
                                ret[`${id}_left_edge`] = new fabric.Line([left - 0.5, props[id].top - 5, left - 0.5, props[id].top + 15], {
                                    stroke: "black", strokeWidth: 1, selectable: false
                                });
                                let right = left + width * bit_spacing;
                                ret[`${id}_right_edge`] = new fabric.Line([right - 0.5, props[id].top - 5, right - 0.5, props[id].top + 15], {
                                    stroke: "black", strokeWidth: 1, selectable: false
                                });
                             }
                         }

                         // Order fields left-to-right by instruction bit position: [31], [30:25], [24:20], [19:12], [11:7]
                         Object.keys(immFields).forEach(addImmField);

                         // ===== 3. IMMEDIATE FIELDS BY TYPE =====

                        instrTypes = '/cpu'.lib.instrTypes;
                        Object.entries(instrTypes).forEach(([key, {immLabel}]) =>
                            ret[key + "_type_label"] = new fabric.Text(immLabel, {
                                fontSize: 5,
                                left: final_left,
                                top: final_top,
                                visible: false
                            })
                        );


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
                             left: final_left + 120, top: final_top + 57, originY: "center", originX: "center"
                         });

                         ret.output_value = new fabric.Text("0", {
                             fontSize: 8, originY: "center", originX: "center",
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
                         let lib = '/cpu'.lib;
                         let cpu = "top.servant_sim.dut.cpu.cpu.";
                         let immdec = "top.servant_sim.dut.cpu.cpu.immdec.";
                         let fields = lib.instrTypes[data.instrType];
                         let isActive = data.active_in_phase["immdec"]; // e.g., 'alu', 'immdec'
                         let phaseColor = lib.getLifecycleColor(data.lifecycle_phase);

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

                         console.log(`=== IMMDEC: bit=${data.current_bit}, phase=${data.phase}, type=${data.opcodeType} ===`);

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

                        // ===== 3. RENDER FINAL IMMEDIATE VALUE FIELDS AND CONNECTION LINES =====

                        // Display the immediate format text for this instruction type.

                        // Hide all type labels first
                        this.obj.i_type_label.set({visible: false});
                        this.obj.s_type_label.set({visible: false});
                        this.obj.b_type_label.set({visible: false});
                        this.obj.u_type_label.set({visible: false});
                        this.obj.j_type_label.set({visible: false});

                        const instrType = data.instrType;

                        // Show the correct type label if determined
                        if (instrType && this.obj[`${instrType}_type_label`]) {
                            this.obj[`${instrType}_type_label`].set({visible: true});
                        }

                        let connectionLines = [];
                        let final_left = 10, bit_spacing = 13;  // bit_size + 1
                        let field_top = 40;
                        let final_top = 80;
                        let lineColor = "rgba(100, 100, 100, 0.5)";
                        let immFields = '/cpu'.lib.immFields;
                        let fieldNames = Object.keys(immFields);
                        let offset = 0;

                        // Cache fieldPositions for current instruction type
                        let fieldPositions = fields.fieldPositions || {};

                        fieldNames.forEach(field => {
                            let fieldInfo = immFields[field];
                            let isVisible = Object.prototype.hasOwnProperty.call(fieldPositions, field);
                            let bitPos = isVisible ? fieldPositions[field] : 0;
                            let left = final_left + (31 - bitPos) * bit_spacing;

                            // Update left position for all objects for this field
                            
                            // Bits
                            for (let i = 0; i < fieldInfo.width; i++) {
                                let bitObj = this.obj[`final_${field}_bit_${i}`];
                                if (bitObj) {
                                    bitObj.set({
                                        visible: isVisible,
                                        left: isVisible ? left + (fieldInfo.width - 1 - i) * bit_spacing : bitObj.left
                                    });
                                }
                            }
                            // Label and edge
                            ["label", "left_edge", "right_edge"].forEach(suffix => {
                                let obj = this.obj[`final_${field}_${suffix}`];
                                if (obj) {
                                    if (suffix === "label") {
                                        obj.set({left: left, visible: isVisible});
                                    } else if (suffix === "left_edge") {
                                        obj.set({left: left - 0.5, visible: isVisible});
                                    } else if (suffix === "right_edge") {
                                        obj.set({left: left + fieldInfo.width * bit_spacing - 0.5, visible: isVisible});
                                    }
                                }
                            });

                            // Create connection line
                            if (isVisible) {
                                let fieldWidth = fieldInfo.width;
                                let row2_mid = 10 + offset * bit_spacing + ((fieldWidth - 1) / 2) * bit_spacing + 6; // 6 = bitWidth/2
                                let final_mid = left + ((fieldWidth - 1) / 2) * bit_spacing + 6;
                                connectionLines.push(new fabric.Line([
                                    row2_mid, field_top + 10,
                                    final_mid, final_top + 15
                                ], {
                                    stroke: lineColor, strokeWidth: 1, strokeDashArray: [2, 2]
                                }));
                            }
                            offset += fieldInfo.width;
                        });

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
                        box: {width: 450, height: 180, strokeWidth: 1},  // Match immdec dimensions
                        where: {left: 0, top: 50, width: 150, height: 60},  // Adjust position accordingly                        
                        init() {
                            let ret = {};
                            
                            // Title
                            ret.title = new fabric.Text("serv_ctrl", {
                                fontSize: 10, fontWeight: "bold", 
                                top: -15, left: 75, originY: "center", originX: "center"
                            });
                            
                            // ===== PC REGISTER VISUALIZATION =====
                            
                            // Current PC display
                            ret.pc_label = new fabric.Text("Current PC:", {
                                fontSize: 7, top: 5, left: 5, fontWeight: "bold"
                            });
                            
                            ret.pc_value = new fabric.Text("0x00000000", {
                                fontSize: 8, fontFamily: "monospace", 
                                top: 15, left: 5, fill: "blue"
                            });
                            
                            // Replace the small PC shift register with:
                            Object.assign(ret, '/top'.lib.initShiftRegister("pc_reg", {
                                bitWidth: 12, bitHeight: 12, spacing: 1, labelSize: 6, showLabel: true,  // Match immdec bit size
                                left: 10, top: 32,
                                lsb: 0, width: 32, label: "Program Counter [31:0]:",
                                maxBitsPerRow: 32  // Single row like immdec instruction
                            }));
                            
                            // ===== PC CALCULATION SOURCES =====
                            
                            ret.calc_label = new fabric.Text("Next PC Source:", {
                                fontSize: 6, top: 55, left: 5, fontWeight: "bold"
                            });
                            
                            // PC increment (+4)
                            ret.increment_indicator = new fabric.Circle({
                                radius: 4, left: 20, top: 67, originY: "center", originX: "center",
                                fill: "#4CAF50", stroke: "black", strokeWidth: 0.5, opacity: 0.3
                            });
                            ret.increment_label = new fabric.Text("+4", {
                                fontSize: 5, top: 74, left: 20, originY: "center", originX: "center"
                            });
                            
                            // Branch/Jump target (from bufreg)
                            ret.branch_indicator = new fabric.Circle({
                                radius: 4, left: 50, top: 67, originY: "center", originX: "center",
                                fill: "#FF9800", stroke: "black", strokeWidth: 0.5, opacity: 0.3
                            });
                            ret.branch_label = new fabric.Text("BRANCH", {
                                fontSize: 4, top: 74, left: 50, originY: "center", originX: "center"
                            });
                            
                            // Exception/interrupt target (from CSR)
                            ret.trap_indicator = new fabric.Circle({
                                radius: 4, left: 85, top: 67, originY: "center", originX: "center",
                                fill: "#F44336", stroke: "black", strokeWidth: 0.5, opacity: 0.3
                            });
                            ret.trap_label = new fabric.Text("TRAP", {
                                fontSize: 4, top: 74, left: 85, originY: "center", originX: "center"
                            });
                            
                            // Return from exception (mret)
                            ret.mret_indicator = new fabric.Circle({
                                radius: 4, left: 115, top: 67, originY: "center", originX: "center",
                                fill: "#9C27B0", stroke: "black", strokeWidth: 0.5, opacity: 0.3
                            });
                            ret.mret_label = new fabric.Text("MRET", {
                                fontSize: 4, top: 74, left: 115, originY: "center", originX: "center"
                            });
                            
                            // ===== PC UPDATE STATUS =====
                            
                            ret.status_label = new fabric.Text("Status:", {
                                fontSize: 6, top: 82, left: 5
                            });
                            
                            ret.status_text = new fabric.Text("IDLE", {
                                fontSize: 7, fontWeight: "bold", top: 82, left: 35, fill: "gray"
                            });
                            
                            // PC enable indicator
                            ret.pc_en_indicator = new fabric.Circle({
                                radius: 3, left: 80, top: 85, originY: "center", originX: "center",
                                fill: "#ccc", stroke: "black", strokeWidth: 1
                            });
                            ret.pc_en_label = new fabric.Text("PC_EN", {
                                fontSize: 5, top: 92, left: 80, originY: "center", originX: "center"
                            });
                            
                            // Jump indicator
                            ret.jump_indicator = new fabric.Circle({
                                radius: 3, left: 110, top: 85, originY: "center", originX: "center",
                                fill: "#ccc", stroke: "black", strokeWidth: 1
                            });
                            ret.jump_label = new fabric.Text("JUMP", {
                                fontSize: 5, top: 92, left: 110, originY: "center", originX: "center"
                            });
                            
                            // ===== INTERNAL ARITHMETIC =====
                            ret.arithmetic_label = new fabric.Text("Internal Calculation:", {
                            fontSize: 6, top: 140, left: 5, fontWeight: "bold"
                            });

                            ret.operand_a_label = new fabric.Text("A:", {fontSize: 10, top: 72, left: 180});
                            ret.operand_a_bit = '/top'.lib.initBit({top: 70, left: 200, width: 16, height: 16});

                            ret.operand_b_label = new fabric.Text("+ B:", {fontSize: 10, top: 72, left: 230});
                            ret.operand_b_bit = '/top'.lib.initBit({top: 70, left: 260, width: 16, height: 16});

                            ret.result_label = new fabric.Text("=", {fontSize: 16, top: 70, left: 290});
                            ret.result_bit = '/top'.lib.initBit({top: 70, left: 310, width: 16, height: 16});
                        
                            // Internally-generated A/B sources
                            ret.zero = new fabric.Text("0", {fontSize: 6, top: 50, left: 235});
                            ret.const4 = new fabric.Text("+4", {fontSize: 6, top: 50, left: 255});

                            return ret;
                        },
                        
                        render() {
                            // Get centralized data from CPU
                            let cpuData = '/cpu'.data;
                            let cpuLib = '/cpu'.lib;
                            let cpu = "top.servant_sim.dut.cpu.cpu.";
                            let ctrl = cpu + "ctrl.";
                            let isActive = cpuData.active_in_phase["ctrl"];
                            let phaseColor = cpuLib.getLifecycleColor(cpuData.lifecycle_phase);

                            // Get control signals
                            let ctrl_pc_en = this.svSigRef(cpu+"state.o_ctrl_pc_en").asBool(false);
                            let ctrl_jump = this.svSigRef(cpu+"state.o_ctrl_jump").asBool(false);
                            let branch_op = this.svSigRef(cpu+"decode.o_branch_op").asBool(false);
                            let jal_or_jalr = this.svSigRef(cpu+"decode.o_ctrl_jal_or_jalr").asBool(false);
                            let pc_rel = this.svSigRef(cpu+"decode.o_ctrl_pc_rel").asBool(false);
                            let utype = this.svSigRef(cpu+"decode.o_ctrl_utype").asBool(false);
                            let mret = this.svSigRef(cpu+"decode.o_ctrl_mret").asBool(false);
                            
                            // Get trap/interrupt signals
                            let trap = this.svSigRef(cpu+"state.o_ctrl_trap").asBool(false);
                            let new_irq = false;
                            try {
                                new_irq = this.svSigRef(cpu+"state.i_new_irq").asBool(false);
                            } catch(e) {
                                // Signal might not exist in all configurations
                            }
                            
                            // Get PC value and related signals
                            let pc_value = 0;
                            let bad_pc = 0;
                            try {
                                pc_value = this.svSigRef(cpu+"o_ibus_adr").asInt(0);
                                bad_pc = this.svSigRef(ctrl+"o_bad_pc").asInt(0);
                            } catch(e) {
                                // Use default values if signals not accessible
                            }
                            
                            console.log(`=== CTRL: pc_en=${ctrl_pc_en}, jump=${ctrl_jump}, branch=${branch_op}, jal=${jal_or_jalr}, trap=${trap} ===`);
                            
                            // ===== UPDATE PC VALUE DISPLAY =====
                            
                            let pc_hex = "0x" + pc_value.toString(16).padStart(8, "0").toUpperCase();
                            this.obj.pc_value.set({
                                text: pc_hex,
                                fill: ctrl_pc_en ? "blue" : "gray"
                            });
                            
                            // ===== RENDER PC SHIFT REGISTER =====
                            
                            // Create a synthetic signal object for the PC register
                            let pc_sig = {
                                signal: { width: 32 },
                                asInt: function() { return pc_value; }
                            };
                            
                            // Highlight current bit being updated during PC operations
                            let pc_highlight = 0;
                            if (ctrl_pc_en && cpuData.current_bit < 32) {
                                pc_highlight = 1 << cpuData.current_bit;
                            }
                            
                            '/top'.lib.renderShiftRegister(pc_sig, this.obj, "pc_reg", {
                                showHex: false,
                                highlightMask: pc_highlight
                            });
                            
                            // ===== UPDATE PC SOURCE INDICATORS =====
                            
                            // Normal increment (+4) - active when no jump/branch/trap
                            let is_increment = ctrl_pc_en && !ctrl_jump && !trap && !mret;
                            this.obj.increment_indicator.set({
                                opacity: is_increment ? 1.0 : 0.3,
                                fill: is_increment ? "#4CAF50" : "#C8E6C9"
                            });
                            
                            // Branch/Jump target - active when jump signal is set
                            let is_branch_jump = ctrl_jump && (branch_op || jal_or_jalr);
                            this.obj.branch_indicator.set({
                                opacity: is_branch_jump ? 1.0 : 0.3,
                                fill: is_branch_jump ? "#FF9800" : "#FFCC80"
                            });
                            
                            // Trap/exception - active when trap is asserted
                            this.obj.trap_indicator.set({
                                opacity: (trap || new_irq) ? 1.0 : 0.3,
                                fill: (trap || new_irq) ? "#F44336" : "#FFCDD2"
                            });
                            
                            // Return from exception (mret)
                            this.obj.mret_indicator.set({
                                opacity: mret ? 1.0 : 0.3,
                                fill: mret ? "#9C27B0" : "#E1BEE7"
                            });
                            
                            // ===== UPDATE STATUS DISPLAY =====
                            
                            let status_text = "IDLE";
                            let status_color = "gray";
                            
                            if (ctrl_pc_en) {
                                if (trap || new_irq) {
                                status_text = "TRAP";
                                status_color = "#F44336";
                                } else if (mret) {
                                status_text = "MRET";
                                status_color = "#9C27B0";
                                } else if (ctrl_jump) {
                                if (branch_op) {
                                    status_text = "BRANCH";
                                } else if (jal_or_jalr) {
                                    status_text = "JUMP";
                                } else {
                                    status_text = "CALC";
                                }
                                status_color = "#FF9800";
                                } else {
                                status_text = "INCREMENT";
                                status_color = "#4CAF50";
                                }
                            } else if (cpuData.lifecycle_phase === "PC_UPDATE") {
                                status_text = "UPDATING";
                                status_color = "#2196F3";
                            }
                            
                            this.obj.status_text.set({
                                text: status_text,
                                fill: status_color
                            });
                            
                            // ===== UPDATE CONTROL INDICATORS =====
                            
                            // PC enable indicator
                            this.obj.pc_en_indicator.set({
                                fill: ctrl_pc_en ? "#4CAF50" : "#ccc",
                                strokeWidth: ctrl_pc_en ? 2 : 1
                            });
                            
                            // Jump indicator  
                            this.obj.jump_indicator.set({
                                fill: ctrl_jump ? "#FF9800" : "#ccc",
                                strokeWidth: ctrl_jump ? 2 : 1
                            });
                            
                            // ===== UPDATE LABELS BASED ON ACTIVITY =====
                            
                            let isActiveNow = ctrl_pc_en || (cpuData.lifecycle_phase === "PC_UPDATE");
                            
                            this.obj.pc_label.set({
                                fill: isActiveNow ? "black" : "gray",
                                fontWeight: isActiveNow ? "bold" : "normal"
                            });
                            
                            this.obj.calc_label.set({
                                fill: ctrl_pc_en ? "black" : "gray"
                            });
                            
                            this.obj.status_label.set({
                                fill: isActiveNow ? "black" : "gray"
                            });
                            
                            // ===== SPECIAL HANDLING FOR INSTRUCTION TYPES =====
                            
                            // Update source labels based on instruction type
                            if (cpuData.instruction_valid) {
                                if (cpuData.opcodeType === "JAL") {
                                this.obj.branch_label.set({text: "JAL"});
                                } else if (cpuData.opcodeType === "JALR") {
                                this.obj.branch_label.set({text: "JALR"});
                                } else if (cpuData.opcodeType === "BRANCH") {
                                this.obj.branch_label.set({text: "BRANCH"});
                                } else {
                                this.obj.branch_label.set({text: "BRANCH"});
                                }
                            }
                            
                            // ===== DEBUG OUTPUT =====
                            
                            if (ctrl_pc_en || ctrl_jump) {
                                console.log(`CTRL Activity: PC=0x${pc_hex}, jump=${ctrl_jump}, phase=${cpuData.lifecycle_phase}`);
                            }

                            // Show internal arithmetic when active
                            if (ctrl_pc_en || jal_or_jalr || utype) {
                            // For PC+4: A=PC, B=4
                            // For PC+IMM: A=PC, B=immediate
                            // For LUI: A=0, B=immediate
                            
                            let a_val = (cpuData.opcodeType === "LUI") ? 0 : ((pc_value >> cpuData.current_bit) & 1);
                            let b_val = 0; // Would need to get immediate or constant 4
                            let result_val = ((ctrl_rd >> cpuData.current_bit) & 1);
                            
                            '/top'.lib.setBit(this.obj.operand_a_bit, a_val, cpuData.current_bit);
                            '/top'.lib.setBit(this.obj.operand_b_bit, b_val, cpuData.current_bit);
                            '/top'.lib.setBit(this.obj.result_bit, result_val, cpuData.current_bit);
                            }
                        }
               /rf_read  // Register file read values streaming to ALU
                  \viz_js
                     box: {left: -90, width: 540, height: 90, strokeWidth: 1, stroke: "green"},
                     where: {left: -30, top: 160, width: 180, height: 30},
                     init() {
                        let ret = {};
                        
                        // Title
                        ret.title = new fabric.Text("Register File Read → ALU", {fontSize: 10, fontWeight: "bold", top: -15, left: 260, originY: "center", originX: "center", selectable: false});
                        
                        // RS1 register visualization - aligned with immdec
                        ret.rs1_label = new fabric.Text("RS1:", {fontSize: 7, top: 0, left: 10, fontWeight: "bold", selectable: false});
                        
                        ret.rs1_addr_label = new fabric.Text("x0", {fontSize: 6, top: 0, left: 28, fontFamily: "monospace", selectable: false});
                        
                        // RS1 arrow from RF
                        '/cpu'.lib.initLoadArrow(ret, "rs1", 17, true, true, "green", "From RF");
                        
                        // Initialize RS1 as 32-bit shift register - aligned with immdec at x=60
                        Object.assign(ret, '/top'.lib.initShiftRegister("rs1_reg", {left: 10, top: 10, bitWidth: 12, bitHeight: 12, spacing: 1, labelSize: 4, showLabel: false, lsb: 0, width: 32}));
                        
                        // RS2 register visualization - aligned with immdec
                        ret.rs2_label = new fabric.Text("RS2/IMM:", {fontSize: 7, top: 30, left: 10, fontWeight: "bold", selectable: false});
                        
                        ret.rs2_addr_label = new fabric.Text("x0", {fontSize: 6, top: 30, left: 45, fontFamily: "monospace", selectable: false});
                        
                        // RS2 arrow from RF/IMM
                        '/cpu'.lib.initLoadArrow(ret, "rs2", 47, true, true, "orange", "From RF/IMM");
                        
                        // Initialize RS2 as 32-bit shift register - aligned with immdec at x=60
                        Object.assign(ret, '/top'.lib.initShiftRegister("rs2_reg", {left: 10, top: 40, bitWidth: 12, bitHeight: 12, spacing: 1, labelSize: 4, showLabel: false, lsb: 0, width: 32}));
                        
                        // Status information on the right
                        ret.status_label = new fabric.Text("Status:", {fontSize: 6, top: 60, left: 15, selectable: false});
                        
                        ret.status_text = new fabric.Text("IDLE", {fontSize: 7, fontWeight: "bold", top: 60, left: 50, fill: "gray", selectable: false});
                        
                        ret.bit_pos_label = new fabric.Text("Bit:", {fontSize: 6, top: 60, left: 100, selectable: false});
                        
                        ret.bit_pos_text = new fabric.Text("0/31", {fontSize: 7, top: 60, left: 120, fontFamily: "monospace", selectable: false});
                        
                        ret.write_source_label = new fabric.Text("Write Source:", {fontSize: 6, top: 70, left: 200});
                        ret.write_source_text = new fabric.Text("--",
                            {fontSize: 8, fontWeight: "bold", top: 70, left: 270}
                        );
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
                             strokeWidth: rs1_reading ? 6 : 4
                         });
                         
                         this.obj.rs1_arrow_label.set({
                             opacity: rs1_reading ? 1.0 : 0.3,
                             fontWeight: rs1_reading ? "bold" : "normal"
                         });
                         
                         // RS2 arrow - show when reading from RF (not immediate)
                         let rs2_reading = op_b_sel && (rf_rreq || (cnt_en && rf_ready));
                         this.obj.rs2_arrow.set({
                             opacity: rs2_reading ? 1.0 : 0.3,
                             strokeWidth: rs2_reading ? 6 : 4,
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
                         
                        let rd_alu_en = this.svSigRef(cpu+"decode.o_rd_alu_en").asBool(false);
                        let rd_mem_en = this.svSigRef(cpu+"decode.o_rd_mem_en").asBool(false);
                        let rd_csr_en = this.svSigRef(cpu+"decode.o_rd_csr_en").asBool(false);

                        this.obj.write_source_text.set({
                            text: rd_alu_en ? "ALU" : rd_mem_en ? "MEM" : rd_csr_en ? "CSR" : "CTRL"
                        });
                     }
               /rd_register  // Write-back register
                  \viz_js
                        box: {left: -90, width: 540, height: 75, strokeWidth: 1, stroke: "purple"},
                        where: {left: -30, top: 250, width: 180, height: 25},
                        
                        init() {
                            let ret = {};
                            
                            // Title
                            ret.title = new fabric.Text("RD Write-Back Register", {
                                fontSize: 10, fontWeight: "bold", 
                                top: -15, left: 270, originY: "center", originX: "center"
                            });
                            
                            // RD register visualization - full 32-bit like other registers
                            Object.assign(ret, '/top'.lib.initShiftRegister("rd_reg", {
                                left: 10, top: 10, bitWidth: 12, bitHeight: 12, spacing: 1,
                                lsb: 0, width: 32, label: "RD [31:0]:", showLabel: true, labelSize: 6
                            }));
                            
                            // RD arrow from RF
                            '/cpu'.lib.initLoadArrow(ret, "rd", 17, true, false, "orange", "To RF");

                            // Source indicators showing what's feeding RD
                            ret.source_label = new fabric.Text("Source:", {
                                fontSize: 6, top: 35, left: 10, fontWeight: "bold"
                            });
                            
                            ret.alu_source = new fabric.Circle({
                                radius: 4, left: 50, top: 37, originY: "center", originX: "center",
                                fill: "#ff6b6b", opacity: 0.3
                            });
                            ret.alu_label = new fabric.Text("ALU", {
                                fontSize: 5, top: 45, left: 50, originY: "center", originX: "center"
                            });
                            
                            ret.mem_source = new fabric.Circle({
                                radius: 4, left: 80, top: 37, originY: "center", originX: "center",
                                fill: "#4ecdc4", opacity: 0.3
                            });
                            ret.mem_label = new fabric.Text("MEM", {
                                fontSize: 5, top: 45, left: 80, originY: "center", originX: "center"
                            });
                            
                            ret.ctrl_source = new fabric.Circle({
                                radius: 4, left: 110, top: 37, originY: "center", originX: "center",
                                fill: "#45b7d1", opacity: 0.3
                            });
                            ret.ctrl_label = new fabric.Text("CTRL", {
                                fontSize: 5, top: 45, left: 110, originY: "center", originX: "center"
                            });
                            
                            ret.csr_source = new fabric.Circle({
                                radius: 4, left: 140, top: 37, originY: "center", originX: "center",
                                fill: "#96ceb4", opacity: 0.3
                            });
                            ret.csr_label = new fabric.Text("CSR", {
                                fontSize: 5, top: 45, left: 140, originY: "center", originX: "center"
                            });
                            
                            // Current bit indicator
                            ret.current_bit_label = new fabric.Text("Current Bit:", {
                                fontSize: 6, top: 60, left: 10
                            });
                            
                            ret.current_bit_value = new fabric.Text("0", {
                                fontSize: 8, fontWeight: "bold", top: 58, left: 70, fill: "purple"
                            });
                            
                            ret.hex_value_label = new fabric.Text("Hex Value:", {
                                fontSize: 6, top: 60, left: 200
                            });
                            
                            ret.hex_value = new fabric.Text("0x00000000", {
                                fontSize: 8, fontFamily: "monospace", top: 58, left: 270, fill: "purple"
                            });
                            
                            return ret;
                        },
                        
                        render() {
                            // Get centralized data from CPU
                            let cpuData = '/cpu'.data;
                            let cpu = "top.servant_sim.dut.cpu.cpu.";
                            
                            // Get write-back control signals
                            let rd_alu_en = this.svSigRef(cpu+"decode.o_rd_alu_en").asBool(false);
                            let rd_mem_en = this.svSigRef(cpu+"decode.o_rd_mem_en").asBool(false);
                            let rd_csr_en = this.svSigRef(cpu+"decode.o_rd_csr_en").asBool(false);
                            let jal_or_jalr = this.svSigRef(cpu+"decode.o_ctrl_jal_or_jalr").asBool(false);
                            let utype = this.svSigRef(cpu+"decode.o_ctrl_utype").asBool(false);
                            
                            // Get the actual RD values from different sources
                            let alu_rd = 0, mem_rd = 0, ctrl_rd = 0, csr_rd = 0;
                            try {
                                alu_rd = this.svSigRef(cpu+"alu.o_rd").asInt(0);
                                mem_rd = this.svSigRef(cpu+"mem_if.o_rd").asInt(0);
                                ctrl_rd = this.svSigRef(cpu+"ctrl.o_rd").asInt(0);
                                csr_rd = this.svSigRef(cpu+"csr.o_csr").asInt(0);
                            } catch(e) {
                                // Use defaults if signals not accessible
                            }
                            
                            // Determine which source is active and get the final RD value
                            let final_rd_value = 0;
                            let active_source = "none";
                            
                            if (rd_alu_en) {
                                final_rd_value = alu_rd;
                                active_source = "alu";
                            } else if (rd_mem_en) {
                                final_rd_value = mem_rd;
                                active_source = "mem";
                            } else if (jal_or_jalr || utype) {
                                final_rd_value = ctrl_rd;
                                active_source = "ctrl";
                            } else if (rd_csr_en) {
                                final_rd_value = csr_rd;
                                active_source = "csr";
                            }
                            
                            console.log(`=== RD: source=${active_source}, value=0x${final_rd_value.toString(16)}, bit=${cpuData.current_bit} ===`);
                            
                            // Create synthetic signal for RD register
                            let rd_sig = {
                                signal: { width: 32 },
                                asInt: function() { return final_rd_value; }
                            };
                            
                            // Highlight current bit being written
                            let rd_highlight = 0;
                            if (active_source !== "none" && cpuData.current_bit < 32) {
                                rd_highlight = 1 << cpuData.current_bit;
                            }
                            
                            '/top'.lib.renderShiftRegister(rd_sig, this.obj, "rd_reg", {
                                showHex: false,
                                highlightMask: rd_highlight
                            });
                            
                            // RD arrow - show when writing to RF
                            let rd_writing = rf_wreq || (cnt_en && rf_ready);
                            this.obj.rd_arrow.set({
                                opacity: rd_writing ? 1.0 : 0.3,
                                strokeWidth: rd_writing ? 6 : 4
                            });

                            this.obj.rd_arrow_label.set({
                                opacity: rd_writing ? 1.0 : 0.3,
                                fontWeight: rd_writing ? "bold" : "normal"
                            });
                         
                            // Update source indicators
                            this.obj.alu_source.set({
                                opacity: (active_source === "alu") ? 1.0 : 0.3,
                                fill: (active_source === "alu") ? "#ff6b6b" : "#ffcccc"
                            });
                            
                            this.obj.mem_source.set({
                                opacity: (active_source === "mem") ? 1.0 : 0.3,
                                fill: (active_source === "mem") ? "#4ecdc4" : "#cceeee"
                            });
                            
                            this.obj.ctrl_source.set({
                                opacity: (active_source === "ctrl") ? 1.0 : 0.3,
                                fill: (active_source === "ctrl") ? "#45b7d1" : "#cce6ff"
                            });
                            
                            this.obj.csr_source.set({
                                opacity: (active_source === "csr") ? 1.0 : 0.3,
                                fill: (active_source === "csr") ? "#96ceb4" : "#cceecc"
                            });
                            
                            // Update current bit and hex displays
                            let current_bit_val = (final_rd_value >> cpuData.current_bit) & 1;
                            this.obj.current_bit_value.set({
                                text: current_bit_val.toString(),
                                fill: (active_source !== "none") ? "purple" : "gray"
                            });
                            
                            this.obj.hex_value.set({
                                text: "0x" + final_rd_value.toString(16).padStart(8, "0").toUpperCase(),
                                fill: (active_source !== "none") ? "purple" : "gray"
                            });
                        }
               /alu
                  \viz_js
                     box: {width: 150, height: 100, strokeWidth: 1, stroke: "red"},
                     where: {left: 160, top: 136, width: 90, height: 60},
                     init() {
                        let ret = {};
                        
                        // Title
                        ret.title = new fabric.Text("serv_alu", {fontSize: 10, fontWeight: "bold", top: -15, left: 75, originY: "center", originX: "center", selectable: false});
                        
                        // Operation display at top
                        ret.operation_label = new fabric.Text("Operation:", {fontSize: 6, top: 5, left: 5, selectable: false});
                        ret.operation_text = new fabric.Text("ADD", {fontSize: 8, fontWeight: "bold", top: 5, left: 50, fill: "blue", selectable: false});
                        
                        // Current bit operation section
                        ret.bit_op_label = new fabric.Text("Current Bit Operation:", {fontSize: 6, top: 20, left: 5, selectable: false});
                        
                        // Input operands A and B (current bits)
                        ret.operand_a_label = new fabric.Text("A:", {fontSize: 5, top: 32, left: 10, selectable: false});
                        ret.operand_a_bit = '/top'.lib.initBit({top: 30, left: 20, width: 12, height: 12});
                        ret.operand_b_label = new fabric.Text("B:", {fontSize: 5, top: 32, left: 40, selectable: false});
                        ret.operand_b_bit = '/top'.lib.initBit({top: 30, left: 50, width: 12, height: 12});

                        // Carry input
                        ret.carry_in_label = new fabric.Text("Cin:", {fontSize: 5, top: 32, left: 70, selectable: false});
                        ret.carry_in_bit = '/top'.lib.initBit({top: 30, left: 90, width: 12, height: 12});
                        
                        // Operation symbol
                        ret.op_symbol = new fabric.Text("+", {fontSize: 12, fontWeight: "bold", top: 28, left: 110, originY: "center", originX: "center", fill: "red", selectable: false});
                        
                        // Result output
                        ret.result_label = new fabric.Text("Result:", {fontSize: 5, top: 50, left: 10, selectable: false});
                        ret.result_bit = '/top'.lib.initBit({top: 48, left: 45, width: 12, height: 12});
                        
                        // Carry output
                        ret.carry_out_label = new fabric.Text("Cout:", {fontSize: 5, top: 50, left: 70, selectable: false});
                        ret.carry_out_bit = '/top'.lib.initBit({top: 48, left: 100, width: 12, height: 12});
                        
                        // Operation mode indicators
                        ret.mode_label = new fabric.Text("Mode:", {fontSize: 6, top: 65, left: 5, selectable: false});
                        
                        // Addition/Subtraction indicator
                        ret.add_sub_indicator = new fabric.Circle({radius: 4, left: 35, top: 67, originY: "center", originX: "center", fill: "#ff6b6b", stroke: "black", strokeWidth: 0.5, selectable: false});
                        ret.add_sub_label = new fabric.Text("ADD/SUB", {fontSize: 4, top: 73, left: 35, originY: "center", originX: "center", selectable: false});
                        
                        // Boolean logic indicator
                        ret.bool_indicator = new fabric.Circle({radius: 4, left: 70, top: 67, originY: "center", originX: "center", fill: "#4ecdc4", stroke: "black", strokeWidth: 0.5, selectable: false});
                        ret.bool_label = new fabric.Text("BOOL", {fontSize: 4, top: 73, left: 70, originY: "center", originX: "center", selectable: false});
                        
                        // Comparison indicator  
                        ret.cmp_indicator = new fabric.Circle({radius: 4, left: 100, top: 67, originY: "center", originX: "center", fill: "#45b7d1", stroke: "black", strokeWidth: 0.5, selectable: false});
                        ret.cmp_label = new fabric.Text("CMP", {fontSize: 4, top: 73, left: 100, originY: "center", originX: "center", selectable: false});
                        
                        // Progress and bit position
                        ret.bit_position_label = new fabric.Text("Bit Position:", {fontSize: 5, top: 82, left: 5, selectable: false});
                        ret.bit_position_text = new fabric.Text("0", {fontSize: 8, fontWeight: "bold", top: 80, left: 60, fill: "purple", selectable: false});
                        ret.bit_of_32_label = new fabric.Text("/31", {fontSize: 6, top: 82, left: 70, selectable: false});
                        
                        // Computation accumulation indicator
                        ret.accumulation_label = new fabric.Text("Partial Result Building:", {fontSize: 5, top: 92, left: 5, selectable: false});
                        
                        // Progress bar for accumulation
                        ret.progress_bar = new fabric.Rect({width: 100, height: 4, top: 95, left: 25, fill: "white", stroke: "black", strokeWidth: 1, selectable: false});
                        ret.progress_fill = new fabric.Rect({width: 0, height: 4, top: 95, left: 25, fill: "green", selectable: false});
                        
                        // Op B source label
                        ret.op_b_source_indicator = new fabric.Text("--", {fontSize: 6, top: 35, left: 65, fill: "black"});
                        
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

                             // Op B source indicator
                             let op_b_sel = this.svSigRef(cpu+"bufreg2.i_op_b_sel").asBool(false);
                             this.obj.op_b_source_indicator.set({
                                 text: op_b_sel ? "RS2" : "IMM",
                                 fill: op_b_sel ? "blue" : "orange"
                             });
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
               /bufreg[2:1]
                  \viz_js
                    box: {width: 450, height: 75, strokeWidth: 1},
                    where: {left: 0, top: 200, width: 150, height: 50},
                    init() {
                        let bufId = this.getIndex(); // 1 or 2
                        let ret = {};
                        
                        ret.title = new fabric.Text(`serv_bufreg${bufId}`, {
                            fontSize: 10, fontWeight: "bold", top: -15, left: 75, originY: "center", originX: "center"
                        });
                        
                        // Common 32-bit shift register
                        Object.assign(ret, '/top'.lib.initShiftRegister(`bufreg${bufId}_data`, {
                            left: 10, top: 10, bitWidth: 12, 
                            bitHeight: 12, spacing: 1,
                            lsb: 0, width: 32, 
                            label: bufId === 1 ? "Address/Shift Buffer" : "Data Buffer",
                        }));

                        
                        /*
                        // Bufreg1-specific indicators
                        if (bufId === 1) {
                            ret.rs1_input = new fabric.Circle({radius: 5, left: 20, top: 40, fill: "#4CAF50", opacity: 0.3});
                            ret.imm_input = new fabric.Circle({radius: 5, left: 50, top: 40, fill: "#FF9800", opacity: 0.3});
                            ret.sum_input = new fabric.Circle({radius: 5, left: 80, top: 40, fill: "#2196F3", opacity: 0.3});
                        } else {
                            // Bufreg2-specific indicators
                            ret.shift_mode = new fabric.Circle({radius: 4, left: 20, top: 40, fill: "#FF5722", opacity: 0.3});
                            ret.load_mode = new fabric.Circle({radius: 4, left: 50, top: 40, fill: "#4CAF50", opacity: 0.3});
                            ret.store_mode = new fabric.Circle({radius: 4, left: 80, top: 40, fill: "#2196F3", opacity: 0.3});
                        }
                        */

                        // To memory.
                        // BUFREG1 -> ADDRESS
                        // BUFREG2 -> DATA
                        '/cpu'.lib.initLoadArrow(ret, "bufreg" + this.getIndex(), 15, false, true, "blue", "To MEM " + (this.getIndex() ? "ADDR" : "DATA"));

                        
                        return ret;
                    }
                     
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
