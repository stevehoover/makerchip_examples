\m5_TLV_version 1d: tl-x.org
\m5
   // Copyright: Apache 2.0: https://github.com/bogibso15/efabless-tt06-verilog-template/blob/main/LICENSE

   use(m5-1.0)

   //================================
   // Logic created by Lee Stockwell, Bo Gibson, and Brent Hall in the course "ChipCraft: The Art of Chip Design (Crane, IN)".
   // VIZ code by Steve Hoover.
   // Copied from https://github.com/bogibso15/efabless-tt06-verilog-template.
   //================================

   //-------------------------------------------------------
   // Build Target Configuration
   //
   // To build within Makerchip for the FPGA or ASIC:
   //   o Use first line of file: \m5_TLV_version 1d --inlineGen --noDirectiveComments --noline --clkAlways --bestsv --debugSigsYosys: tl-x.org
   //   o set(MAKERCHIP, 0)  // (below)
   //   o For ASIC, set my_design (below) to match the configuration of your repositoy:
   //       - tt_um_fpga_hdl_demo for tt_fpga_hdl_demo repo
   //       - tt_um_example for tt06_verilog_template repo
   //   o var(target, FPGA)  // or ASIC (below)
   set(MAKERCHIP, 1)   /// 1 for simulating in Makerchip.
   var(my_design, tt_um_template)   /// The name of your top-level TT module, to match your info.yml.
   var(target, FPGA)  /// FPGA or ASIC
   //-------------------------------------------------------
   
   var(debounce_inputs, 1)         /// 1: Provide synchronization and debouncing on all input signals.
                                   /// 0: Don't provide synchronization and debouncing.
                                   /// m5_neq(m5_MAKERCHIP, 1): Debounce unless in Makerchip.
   
   // ======================
   // Computed From Settings
   // ======================
   
   // If debouncing, a user's module is within a wrapper, so it has a different name.
   var(user_module_name, m5_if(m5_debounce_inputs, my_design, m5_my_design))
   var(debounce_cnt, m5_if_eq(m5_MAKERCHIP, 1, 8'h03, 8'hff))
   
   var(repo_content_url, ['https://raw.githubusercontent.com/stevehoover/efabless-tt-fpga-dl-demo-AES/main'])

\SV
   m4_include_lib(https:/['']/raw.githubusercontent.com/efabless/chipcraft---mest-course/main/tlv_lib/calculator_shell_lib.tlv)
   // Include Tiny Tapeout Lab.
   m4_include_lib(https:/['']/raw.githubusercontent.com/os-fpga/Virtual-FPGA-Lab/62d6e18bc3d0ca8af451ccaff6d63974a69e645b/tlv_lib/tiny_tapeout_lib.tlv)


// Click ▼ on next line to hide VIZ code (in Makerchip).
\TLV aes_viz()
   |encrypt
      @0
         m5_fn(stroke_for_row_val, i, ['stroke: function (row) {return row == 0 ? "red" : row == 1 ? "#2040ff" : row == 2 ? "#00dd00" : "#ff00ff"}(m5_i)'])
         m5_fn(stroke_for_row, i, ['m5_stroke_for_row_val(this.getIndex("m5_i"))'])
         \viz_js
            box: {left: -70, top: 0, width: 960, height: 960, strokeWidth: 0},
            init() {
               return {
                  bg: this.newImageFromURL(
                        "m5_repo_content_url/viz/AES_(Rijndael)_Round_Function.png",
                        "John Savard - CC0",
                        {width: 640, height: 960, fill: "#FFF1", strokeWidth: 0,},
                        {strokeWidth: 0}
                  ),
                  round: new fabric.Text("Round: -", {left: 320, top: 20, fontFamily: "roboto", fontSize: 35, fill: "white"}),
                  back_to_top: new fabric.Text("Back to top...", {left: 180, top: 900, fontFamily: "roboto", fontSize: 20, fill: "white"})
               }
            },
            render() {
               $round = '$round'
               this.obj.round.set({text: `Round: ${$round.v}`, fill: $round.isValid() ? "white" : "gray"})
            },
            where: {left: 0, top: 0, height: 100}
         /subbytes
            /legend
               \viz_js
                  box: {strokeWidth: 0},
                  init() {
                     return {
                        circle: new fabric.Circle({
                           fill: "#FFD8D8D0", radius: 40,
                           strokeWidth: 2, stroke: "gray",
                        }),
                        text: new fabric.Text(
                           "State In\nSbox out",
                           {originX: "center", originY: "center", textAlign: "center", left: 40, top: 40,
                            fontFamily: "roboto", fontSize: 14, lineHeight: 1.4})
                     }
                  },
                  render() {
                     this.obj.text.set({
                        fill: '|encrypt$not_round0'.asBool() ? "black" : "lightgray"
                     })
                     return [];
                  },
                  where: {left: 30, top: 30}
            /xx[*]
               \viz_js
                  box: {strokeWidth: 0},
                  layout: {left: 43, top: -24},
                  where: {left: 57, top: 60}
               /yy[*]
                  \viz_js
                     box: {strokeWidth: 0},
                     layout: {left: 56, top: 32},
                     init() {
                        test = this
                        let circ = new fabric.Circle({
                            fill: "#FFD8D8D0", radius: 24,
                            strokeWidth: 2, m5_stroke_for_row(yy)
                        })
                        let text = new fabric.Text("--\n--", {originX: "center", originY: "center", textAlign: "center", left: 25, top: 25, fontFamily: "roboto mono", fontSize: 12.5})
                        return {circ, text}
                     },
                     render() {
                        this.obj.text.set({
                           text: `${'$word_idx'.asHexStr()}\n${'$sb_out'.asHexStr()}`,
                           fill: '|encrypt$not_round0'.asBool() ? "black" : "lightgray"
                        })
                        return [];
                     },
            /map
               \viz_js
                  box: {strokeWidth: 0},
                  init() {
                     this.sbox_cyc = -1   // Indicate that sbox_prop must be updated.
                     return {
                        img: this.newImageFromURL(
                           "m5_repo_content_url/viz/1920px-AES-SubBytes.svg.png",
                           "Matt Crypto -- CC0",
                           {left: 0, top: 20, width: 300, height: 162, fill: "#FFF1", strokeWidth: 0,},
                           {strokeWidth: 0}
                        ),
                        label1: new fabric.Text("State In\n($word_idx)", {
                           originX: "center", textAlign: "center", left: 56, top: -17, fill: "white",
                           fontFamily: "roboto mono", fontSize: 15
                        }),
                        label2: new fabric.Text("Sbox Out\n($sb_out)", {
                           originX: "center", textAlign: "center", left: 244, top: -17, fill: "white",
                           fontFamily: "roboto mono", fontSize: 15
                        }),
                        S: new fabric.Text("Sbox", {
                           left: 130, top: 107, fill: "white",
                           fontFamily: "roboto mono", fontSize: 17
                        }),
                        legend: new fabric.Text("* Gray squares map RotWord to SubWord\n  in key schedule (lower right).", {
                           left: 143, top: 191, fill: "white",
                           fontFamily: "roboto mono", fontSize: 1.5
                        }),
                     }
                  },
                  where: {left: 460, top: 75}
               /sbox_x[15:0]
                  \viz_js
                     box: {width: 10, height: 160, fill: "white"},
                     where: {left: 120, top: 130, width: 60, height: 60}
                  /sbox_y[15:0]
                     \viz_js
                        box: {width: 10, height: 10},
                        layout: "vertical",
                        render() {
                           let index = this.getIndex("sbox_y") * 16 + this.getIndex("sbox_x")
                           let val = '|encrypt$sbox_vec'.asHexStr().substr((255 - index) * 2, 2)
                           ret = [
                              new fabric.Text(index.toString(16), {
                                   fontFamily: "roboto mono", fontSize: 3.5,
                                   originX: "center", left: 5, top: 0.5,
                              }),
                              new fabric.Text(val.toString(16).padStart(2, "0"), {
                                   fontFamily: "roboto mono", fontSize: 3.5,
                                   originX: "center", left: 5, top: 5
                              }),
                           ]
                           // Sbox properties (only once), as sparse array sbox_prop[0..255].
                           let ctx = this.getScope("map").context
                           if (this.getScope("map").context.sbox_cyc != this.getCycle()) {
                              this.getScope("map").context.sbox_cyc = this.getCycle()
                              ctx.sbox_prop = {}
                              let rot_word = '|encrypt/keyschedule$rot'+0
                              for (let y = 0; y < 4; y++) {
                                 let row_prop = {m5_stroke_for_row_val(y)}
                                 for (let x = 0; x < 4; x++) {
                                    let idx = '/subbytes/xx[x]/yy[y]$word_idx'+0
                                    ctx.sbox_prop[idx] = {stroke: row_prop.stroke}
                                    if (x == 2 && y == 2) {
                                       ctx.sbox_prop[idx].rect_fill = "#fdd58a"
                                    }
                                 }
                                 // Also, highlight the mapping of RotWord.
                                 let i = (rot_word >> (y * 8)) & 0xFF;
                                 ctx.sbox_prop[i] = {stroke: row_prop.stroke, rect_fill: "lightgray"}
                              }
                           }
                           // Colored circle for row, yellow box for highlighted cell, and gray box for key mapping.
                           if (index in ctx.sbox_prop) {
                              let prop = ctx.sbox_prop[index]
                              ret.unshift(new fabric.Circle({left: 0, top: 0, radius: 4.5, strokeWidth: 1, stroke: prop.stroke, fill: "transparent"}))
                              if ("rect_fill" in prop) {
                                 ret.unshift(new fabric.Rect({left: 0, top: 0, width: 9, height: 9, fill: prop.rect_fill, strokeWidth: 1, stroke: "black"}))
                              }
                           }
                           return ret
                        },
               /ax[3:0]
                  /ay[3:0]
                     $ANY = /subbytes/xx[#ax]/yy[#ay]$ANY;
                     \viz_js
                        box: {strokeWidth: 0},
                        layout: "vertical",
                        init() {
                           let circ = new fabric.Circle({
                               fill: "#FFD8D8D0", radius: 13,
                               strokeWidth: 1, m5_stroke_for_row(ay)
                           })
                           let text = new fabric.Text(
                                    "--", {originX: "center", originY: "center", textAlign: "center", left: 13, top: 13,
                                    fontFamily: "roboto mono", fontSize: 12.5})
                           return {circ, text}
                        },
                        render() {
                           this.obj.text.set({
                              text: '$word_idx'.asHexStr(),
                              fill: '|encrypt$not_round0'.asBool() ? "black" : "lightgray"
                           })
                           return [];
                        },
                        where: {left: 3, top: 26}
               /bx[3:0]
                  /by[3:0]
                     $ANY = /subbytes/xx[#bx]/yy[#by]$ANY;
                     \viz_js
                        box: {strokeWidth: 0},
                        layout: "vertical",
                        init() {
                           let circ = new fabric.Circle({
                               fill: "#FFD8D8D0", radius: 13,
                               strokeWidth: 1, m5_stroke_for_row(by)
                           })
                           let text = new fabric.Text("--", {originX: "center", originY: "center", textAlign: "center", left: 13, top: 13, fontFamily: "roboto mono", fontSize: 12.5})
                           return {circ, text}
                        },
                        render() {
                           this.obj.text.set({
                              text: '$sb_out'.asHexStr(),
                              fill: '|encrypt$not_round0'.asBool() ? "black" : "lightgray"
                           })
                           return [];
                        },
                        where: {left: 191, top: 26}
         /shift_row
            /map
               \viz_js
                  box: {strokeWidth: 0},
                  init() {
                     let img = this.newImageFromURL(
                        "m5_repo_content_url/viz/1920px-AES-ShiftRows.svg.png",
                        "Matt Crypto -- CC0",
                        {left: -30, top: 34, width: 331, height: 150, fill: "#FFF1", strokeWidth: 0,},
                        {strokeWidth: 0}
                     )
                     let label1 = new fabric.Text("Sbox Out\n($sb_out)", {originX: "center", textAlign: "center", left: 56, top: -7, fill: "white", fontFamily: "roboto mono", fontSize: 15})
                     let label2 = new fabric.Text("Shifted\n($ssr_out)", {originX: "center", textAlign: "center", left: 244, top: -7, fill: "white", fontFamily: "roboto mono", fontSize: 15})
                     return {img, label1, label2}
                  },
                  where: {left: 430, top: 255}
               /ax[3:0]
                  /ay[3:0]
                     $ANY = |encrypt/subbytes/xx[#ax]/yy[#ay]$ANY;
                     \viz_js
                        box: {strokeWidth: 0},
                        layout: "vertical",
                        init() {
                           let circ = new fabric.Circle({
                               fill: "#FFD8D8D0", radius: 13,
                               strokeWidth: 1, m5_stroke_for_row(ay)
                           })
                           let text = new fabric.Text("--", {originX: "center", originY: "center", textAlign: "center", left: 13, top: 13, fontFamily: "roboto mono", fontSize: 12.5})
                           return {circ, text}
                        },
                        render() {
                           this.obj.text.set({
                              text: '$sb_out'.asHexStr(),
                              fill: '|encrypt$not_round0'.asBool() ? "black" : "lightgray"
                           })
                           return [];
                        },
                        where: {left: 3, top: 36}
               /bx[3:0]
                  /by[3:0]
                     $ssr_out_byte[7:0] = |encrypt/subbytes$ssr_out[((#bx * 4) + #by) * 8 +: 8];
                     \viz_js
                        box: {strokeWidth: 0},
                        layout: "vertical",
                        init() {
                           let circ = new fabric.Circle({
                               fill: "#D8D8FFD0", radius: 13,
                               strokeWidth: 1, m5_stroke_for_row(by)
                           })
                           let text = new fabric.Text("--", {originX: "center", originY: "center", textAlign: "center", left: 13, top: 13, fontFamily: "roboto mono", fontSize: 12.5})
                           return {circ, text}
                        },
                        render() {
                           this.obj.text.set({
                              text: '$ssr_out_byte'.asHexStr(),
                              fill: '|encrypt$not_round0'.asBool() ? "black" : "lightgray"
                           })
                           return [];
                        },
                        where: {left: 191, top: 36}
         /mixcolumn
            /legend
               \viz_js
                  box: {strokeWidth: 0},
                  init() {
                     return {
                        circle: new fabric.Circle({
                           fill: "#D8D8FFD0", radius: 40,
                           strokeWidth: 2, stroke: "gray",
                        }),
                        text: new fabric.Text(
                           "Shifted\nMixed",
                           {originX: "center", originY: "center", textAlign: "center", left: 40, top: 40,
                            fontFamily: "roboto", fontSize: 14, lineHeight: 1.4})
                     }
                  },
                  render() {
                     this.obj.text.set({text: '|encrypt$not_round0'.asBool() ? "Shifted\nMixed" : "State In\nMixed",
                                                 fill: '|encrypt$do_mixcolumn'.asBool() ? "black" : "lightgray"
                     })
                  },
                  where: {left: 30, top: 400}
            /xx[*]
               \viz_js
                  box: {strokeWidth: 0},
                  layout: {left: 43, top: -24},
                  where: {left: 57, top: 430}
               /yy[*]
                  // $ss, $cc, $oo
                  \viz_js
                     box: {strokeWidth: 0},
                     layout: {left: 56, top: 32},
                     init() {
                        let circ = new fabric.Circle({
                            fill: "#D8D8FFD0", radius: 24,
                            strokeWidth: 2, m5_stroke_for_row(yy)
                        })
                        let text = new fabric.Text("--\n--\n--", {originX: "center", originY: "center", textAlign: "center", left: 25, top: 25, fontFamily: "roboto mono", fontSize: 12.5})
                        return {circ, text}
                     },
                     render() {
                        this.obj.text.set({
                           text: `${'$ss'.asHexStr()}\n${'$oo'.asHexStr()}`,
                           fill: '|encrypt$do_mixcolumn'.asBool() ? "black" : "lightgray"
                        })
                        return [];
                     }
            /map
               \viz_js
                  box: {strokeWidth: 0},
                  init() {
                     let img = this.newImageFromURL(
                        "m5_repo_content_url/viz/1920px-AES-MixColumns.svg.png",
                        "Matt Crypto -- CC0",
                        {left: 1, top: 16, width: 300, height: 160, fill: "#FFF1", strokeWidth: 0,},
                        {strokeWidth: 0}
                     )
                     let label1 = new fabric.Text("Shifted\n($ssr_out)", {originX: "center", textAlign: "center", left: 104, top: -6, fill: "white", fontFamily: "roboto mono", fontSize: 15})
                     let label2 = new fabric.Text("Mixed\n($oo)", {originX: "center", textAlign: "center", left: 274, top: -6, fill: "white", fontFamily: "roboto mono", fontSize: 15})
                     return {img, label1, label2}
                  },
                  render() {
                     this.obj.label1.set({text: '|encrypt$not_round0'.asBool() ? "Shifted\n($ssr_out)" : "State In\n($state_i)"})
                  },
                  where: {left: 460, top: 425}
               /ax[3:0]
                  /ay[3:0]
                     $ANY = /mixcolumn/xx[#ax]/yy[#ay]$ANY;
                     \viz_js
                        box: {strokeWidth: 0},
                        layout: "vertical",
                        init() {
                           let circ = new fabric.Circle({
                               fill: "#D8D8FFD0", radius: 13,
                               strokeWidth: 1, m5_stroke_for_row(ay)
                           })
                           let text = new fabric.Text("--", {originX: "center", originY: "center", textAlign: "center", left: 13, top: 13, fontFamily: "roboto mono", fontSize: 12.5})
                           return {circ, text}
                        },
                        render() {
                           this.obj.text.set({
                              text: '$ss'.asHexStr(),
                              fill: '|encrypt$do_mixcolumn'.asBool() ? "black" : "lightgray"
                           })
                           return [];
                        },
                        where: {left: 3, top: 36}
               /bx[3:0]
                  /by[3:0]
                     $ANY = /mixcolumn/xx[#bx]/yy[#by]$ANY;
                     \viz_js
                        box: {strokeWidth: 0},
                        layout: "vertical",
                        init() {
                           let color = {m5_stroke_for_row(by)}
                           let circ = new fabric.Circle({
                               fill: "#D8D8FFD0", radius: 13,
                               strokeWidth: 1, stroke: color.stroke
                           })
                           let text = new fabric.Text("--", {
                                originX: "center", originY: "center", textAlign: "center", left: 13, top: 13,
                                fill: color.stroke, fontFamily: "roboto mono", fontSize: 12.5
                           })
                           return {circ, text}
                        },
                        render() {
                           this.obj.text.set({
                              text: '$oo'.asHexStr(),
                              fill: '|encrypt$do_mixcolumn'.asBool() ? "black" : "lightgray"
                           })
                           return [];
                        },
                        where: {left: 191, top: 36}
               /matmul
                  \viz_js
                     box: {width: 80, height: 80, fill: "#fdd58a", stroke: "black"},
                     init() {
                        return {
                           x: new fabric.Text("x", {
                                originX: "center", originY: "center", left: 50, top: 25,
                                fontFamily: "roboto mono", fontSize: 7
                           }),
                           sum: new fabric.Text("=Σ", {
                                originX: "center", originY: "center", left: 25, top: 50,
                                fontFamily: "roboto mono", fontSize: 7
                           }),
                           a: new fabric.Text("a", {
                                left: 22, top: 10, fontFamily: "roboto mono", fontSize: 7
                           }),
                           b: new fabric.Text("b", {
                                left: 12, top: 20, fontFamily: "roboto mono", fontSize: 7
                           })
                        }
                     },
                     where: {left: 110, top: 146, width: 80, height: 80}
                  /bb[3:0]
                     $ANY = /mixcolumn/xx[1]/yy[#bb]$ANY;
                     \viz_js
                        box: {width: 10, height: 10, fill: "#fdd58a", stroke: "black", strokeWidth: 0.5},
                        layout: "vertical",
                        init() {
                           let color = {m5_stroke_for_row(bb)}
                           return {
                              circ: new fabric.Circle({
                                    fill: "#D8D8FFD0", radius: 4.75,
                                    strokeWidth: 1, stroke: color.stroke, strokeWidth: 0.5,
                              }),
                              text: new fabric.Text("--", {
                                    originX: "center", originY: "center", textAlign: "center", left: 5, top: 5,
                                    fill: color.stroke, fontFamily: "roboto mono", fontSize: 7
                              })
                           }
                        },
                        render() {
                           this.obj.text.set({text: '$oo'.asHexStr(), fill: '|encrypt$do_mixcolumn'.asBool() ? "black" : "lightgray"})
                        },
                        where: {left: 10, top: 30, width: 10}
                  /aa[3:0]
                     $ANY = /mixcolumn/xx[1]/yy[#aa]$ANY;
                     \viz_js
                        box: {width: 10, height: 10, fill: "#fdd58a", stroke: "black", strokeWidth: 0.5},
                        layout: "vertical",
                        init() {
                           return {
                              circ: new fabric.Circle({
                                    fill: "#D8D8FFD0", radius: 4.75,
                                    strokeWidth: 1, m5_stroke_for_row(aa), strokeWidth: 0.5
                              }),
                              text: new fabric.Text("--", {
                                   originX: "center", originY: "center", textAlign: "center", left: 5, top: 5,
                                   fontFamily: "roboto mono", fontSize: 7
                              })
                           }
                        },
                        render() {
                           this.obj.text.set({text: '$ss'.asHexStr(), fill: '|encrypt$do_mixcolumn'.asBool() ? "black" : "lightgray"})
                        },
                        where: {left: 30, top: 20, width: 10, angle: -90}
                  /cx[3:0]
                     /cy[3:0]
                        $ANY = /mixcolumn/xx[#cx]/yy[#cy]$ANY;
                        \viz_js
                           box: {width: 10, height: 10, strokeWidth: 0, fill: "white", stroke: "black", strokeWidth: 0.5},
                           layout: "vertical",
                           init() {
                              let color = {m5_stroke_for_row(cy)}
                              let circ = new fabric.Circle({
                                    fill: "#D8D8FFD0", radius: 4.75,
                                    strokeWidth: 1, m5_stroke_for_row(cx), strokeWidth: 0.5
                              })
                              let text = new fabric.Text("-", {
                                   originX: "center", originY: "center", textAlign: "center", left: 5, top: 5,
                                   fill: color.stroke, fontFamily: "roboto mono", fontSize: 3.4, lineHeight: 0.9,
                              })
                              return {circ, text}
                           },
                           render() {
                              let color = {m5_stroke_for_row(cy)}
                              this.obj.text.set({
                                 text: '/mixcolumn/xx[1]/yy[this.getIndex("cx")]$ss'.asHexStr() + "×" + '$cc'.v.toString(16) + "\n=" + '/mixcolumn/xx[1]/yy[this.getIndex("cy")]/exp[this.getIndex("cx")]$op'.asHexStr(),
                                 fill: '|encrypt$do_mixcolumn'.asBool() ? color.stroke : "lightgray"
                              })
                              return [];
                           },
                           where: {left: 30, top: 30, width: 10}
         /keyschedule
            /legend
               \viz_js
                  box: {strokeWidth: 0},
                  init() {
                     return {
                        circle: new fabric.Circle({
                           fill: "#D8FFD8D0", radius: 40,
                           strokeWidth: 2, stroke: "gray",
                        }),
                        text: new fabric.Text(
                           "Mixed\nKey\nState Out",
                           {originX: "center", originY: "center", textAlign: "center", left: 40, top: 40,
                            fontFamily: "roboto", fontSize: 14
                        }),
                     }
                  },
                  render() {
                     this.obj.text.set({text: `${('|encrypt$not_round0'.asBool() ? ('|encrypt$do_mixcolumn'.asBool() ? "Mixed" : "Shifted") : "State In") + "\nKey\nState Out"}`})
                  },
                  where: {left: 30, top: 625}
            /sbox_k[*]
               \viz_js
                  box: {strokeWidth: 0},
                  layout: {left: 43, top: -24},
                  where: {left: 57, top: 655}
               /yy[3:0]
                  $oo[7:0] = |encrypt/mixcolumn/xx[#sbox_k]/yy[#yy]$oo;
                  $key_byte[7:0] = |encrypt/keyschedule$key[((#sbox_k * 4) + #yy) * 8 +: 8];
                  $state_ark_byte[7:0] = |encrypt$state_ark[((#sbox_k * 4) + #yy) * 8 +: 8];
                  
                  \viz_js
                     box: {strokeWidth: 0},
                     layout: {left: 56, top: 32},
                     init() {
                        let circ = new fabric.Circle({
                            fill: "#D8FFD8D0", radius: 24,
                            strokeWidth: 2, m5_stroke_for_row(yy)
                        })
                        let text = new fabric.Text("--\n--\n--", {originX: "center", originY: "center", textAlign: "center", left: 25, top: 25, fontFamily: "roboto mono", fontSize: 12.5})
                        return {circ, text}
                     },
                     render() {
                        this.obj.text.set({
                           text: `${'|encrypt$state_mc'.asHexStr().substr((15 - (this.getIndex("sbox_k") * 4 + this.getIndex("yy"))) * 2, 2)}\n${'$key_byte'.asHexStr()}\n${'$state_ark_byte'.asHexStr()}`,
                           fill: '|encrypt$valid_blk'.asBool() ? "black" : "lightgray"
                        })
                        return [];
                     }
            
            /key
               \viz_js
                  box: {width: 100, height: 100, strokeWidth: 0},
                  init() {
                     return {
                        img: this.newImageFromURL(
                              "m5_repo_content_url/viz/AES-Key_Schedule_128-bit_key.png",
                              "\"AES key schedule for a 128-bit key\", by Sissssou, CC BY-SA 4.0, https://en.wikipedia.org/wiki/AES_key_schedule",
                              {left: 0, top: 0, width: 100, height: 100, fill: "#FFF1", strokeWidth: 0,},
                              {strokeWidth: 0}
                        ),
                        key: new fabric.Text("Key\n($key)", {
                              left: 19.5, top: 12.5, angle: -90, fill: "white", textAlign: "center", originX: "center",
                              fontFamily: "roboto mono", fontSize: 3
                        }),
                        next_key: new fabric.Text("Next Key\n($next_key)", {
                              left: 19.5, top: 56.4, angle: -90, fill: "white", textAlign: "center", originX: "center",
                              fontFamily: "roboto mono", fontSize: 3
                        }),
                        sbox: new fabric.Text("Sbox", {
                              left: 3.28, top: 31.68, fill: "black",
                              fontFamily: "roboto mono", fontSize: 2.7
                        }),
                        rot: new fabric.Text("--------", {
                              left: 1, top: 23, fill: "white",
                              fontFamily: "roboto mono", fontSize: 3.5
                        }),
                        sb_out_word: new fabric.Text("--------", {
                              left: 1, top: 33.7, fill: "white",
                              fontFamily: "roboto mono", fontSize: 3.5
                        }),
                        rcon: new fabric.Text("--------", {
                              left: 1, top: 44.4, fill: "white",
                              fontFamily: "roboto mono", fontSize: 3.5
                        }),
                        xor_con: new fabric.Text("--------",
                              {left: 1, top: 53.4, fill: "white",
                              fontFamily: "roboto mono", fontSize: 3.5
                        }),
                     }
                  },
                  render() {
                     let duration = (this.steppedBy() == 1) ? 500 : 1
                     let format_key = function (sig) {
                        let hex = sig.asHexStr()
                        let ret = hex.substr(0, 8)
                        for (let i = 1; i < 4; i++) {
                           ret = hex.substr(8 * i, 8) + "_" + ret
                        }
                        return ret
                     }
                     let obj = this.obj
                     
                     let computed = '/keyschedule>>1$compute_next_key'.asBool()
                     obj.key.set({text: computed ? "Key\n($key)" : "Start Key\n($key)"})
                     
                     obj.img.        set({top: 0})  // Reset animation in case we're mid-animation.
                     obj.rot.        set({visible: false, text: '/keyschedule$rot'.        asHexStr()})
                     obj.sb_out_word.set({visible: false, text: '/keyschedule$sb_out_word'.asHexStr()})
                     obj.rcon.       set({visible: false, text: "000000" +
                                                '/keyschedule$rcon'.       asHexStr()})
                     obj.xor_con. set({visible: false, text: '/keyschedule$xor_con'.       asHexStr()})
                     
                     // Animate. Some elements are not visible, animate others upward. Then unhide all.
                     obj.img.animate({top: -43.5}, {
                          duration
                     }).then( () => {
                          obj.img.set({top: 0})
                          obj.rot.        set({visible: true})
                          obj.sb_out_word.set({visible: true})
                          obj.rcon.       set({visible: true})
                          obj.xor_con.    set({visible: true})
                     })
                  },
                  where: {left: 630, top: 800, width: 160, height: 160}
               /row[1:0]
                  \viz_js
                     box: {strokeWidth: 0},
                     layout: {left: 0, top: 63.5},
                     where: {left: 29.4, top: 0, height: 70.4}
                  /word[3:0]
                     $ANY = /keyschedule/word$ANY;
                     \viz_js
                        box: {strokeWidth: 0},
                        layout: {left: 27.5, top: 0}
                     /kbyte[3:0]
                        \viz_js
                           box: {width: 10, height: 10, strokeWidth: 0},
                           layout: "vertical",
                           init() {
                              return {
                                 circ: new fabric.Circle({
                                    left: 0, top: 0, fill: this.getIndex("row") == 0 ? "#D8FFD8D0" : "#D8D8D8D0", radius: 4.5,
                                    strokeWidth: 1, m5_stroke_for_row(kbyte)
                                 }),
                                 text: new fabric.Text("--", {
                                     originX: "center", originY: "center", textAlign: "center",
                                     left: 5, top: 5,
                                     fontFamily: "roboto", fontSize: 6
                                 }),
                              }
                           },
                           render() {
                              let word = (this.getIndex("row") ? '/word[this.getIndex("word")]$next_word' : '/word[this.getIndex("word")]$term2').v
                              let obj = this.obj
                              obj.text.set({top: 5, text: ((word >> (this.getIndex() * 8)) & 0xFF).toString(16).padStart(2, "0")})
                              obj.circ.set({top: 0})
                              // Animate the next key becoming the key, only when stepping forward.
                              let duration = (this.steppedBy() == 1) ? 500 : 1
                              if (this.getIndex("row") == 0) {
                                 let visible = '/keyschedule>>1$compute_next_key'.asBool()
                                 obj.text.set({top: 68.5, visible})
                                         .animate({top: 5}, {duration})
                                         .thenSet({visible: true})
                                 obj.circ.set({top: 63.5, visible})
                                         .animate({top: 0}, {duration})
                                         .thenSet({visible: true})
                              } else {
                                 let compute = '/keyschedule$compute_next_key'.asBool()
                                 obj.text.set({visible: false})
                                         .wait(duration)
                                         .thenSet({visible: true, fill: compute ? "black" : "lightgray"})
                                 obj.circ.set({visible: false})
                                         .wait(duration)
                                         .thenSet({visible: true})
                              }
                           },
            /map
               \viz_js
                  box: {strokeWidth: 0},
                  init() {
                     let img = this.newImageFromURL(
                        "m5_repo_content_url/viz/1024px-AES-AddRoundKey.svg.png",
                        "Matt Crypto -- CC0",
                        {left: 0, top: 30, width: 300, height: 300, fill: "#FFF1", strokeWidth: 0,},
                        {strokeWidth: 0}
                     )
                     let label1 = new fabric.Text("Mixed\n($oo)", {textAlign: "center", originX: "center", left: 56, top: -9, fill: "white", fontFamily: "roboto mono", fontSize: 15})
                     let label2 = new fabric.Text("State Out\n($state_ark)", {textAlign: "center", originX: "center", left: 244, top: -9, fill: "white", fontFamily: "roboto mono", fontSize: 15})
                     let label3 = new fabric.Text("Key ($key)", {originX: "center", left: 56, top: 139, fill: "white", fontFamily: "roboto mono", fontSize: 15})
                     return {img, label1, label2, label3}
                  },
                  render() {
                     this.obj.label1.set({text: '|encrypt$not_round0'.asBool() ? ('|encrypt$do_mixcolumn'.asBool() ? "Mixed\n($oo)" : "Shifted\n($ssr_out)") : "State In\n($state_i)"})
                  },
                  where: {left: 460, top: 630}
               /ax[3:0]
                  /ay[3:0]
                     \viz_js
                        box: {strokeWidth: 0},
                        layout: "vertical",
                        init() {
                           let circ = new fabric.Circle({
                               fill: "#D8FFD8D0", radius: 13,
                               strokeWidth: 1, m5_stroke_for_row(ay)
                           })
                           let text = new fabric.Text("--", {originX: "center", originY: "center", textAlign: "center", left: 13, top: 13, fontFamily: "roboto mono", fontSize: 12.5})
                           return {circ, text}
                        },
                        render() {
                           this.obj.text.set({
                              text: '|encrypt$state_mc'.asHexStr().substr((15 - (this.getIndex("ax") * 4 + this.getIndex("ay"))) * 2, 2),
                              fill: '|encrypt$valid_blk'.asBool() ? "black" : "lightgray"
                           })
                           return [];
                        },
                        where: {left: 2, top: 31}
               /bx[3:0]
                  /by[3:0]
                     $ANY = /keyschedule/sbox_k[#bx]/yy[#by]$ANY;
                     \viz_js
                        box: {strokeWidth: 0},
                        layout: "vertical",
                        init() {
                           let circ = new fabric.Circle({
                               fill: "#D8FFD8D0", radius: 13,
                               strokeWidth: 1, m5_stroke_for_row(by)
                           })
                           let text = new fabric.Text("--", {originX: "center", originY: "center", textAlign: "center", left: 13, top: 13, fontFamily: "roboto mono", fontSize: 12.5})
                           return {circ, text}
                        },
                        render() {
                           this.obj.text.set({
                              text: '$state_ark_byte'.asHexStr(),
                              fill: '|encrypt$valid_blk'.asBool() ? "black" : "lightgray"
                           })
                           return [];
                        },
                        where: {left: 190, top: 31}
               /kx[3:0]
                  /ky[3:0]
                     $ANY = /keyschedule/sbox_k[#kx]/yy[#ky]$ANY;
                     \viz_js
                        box: {strokeWidth: 0},
                        layout: "vertical",
                        init() {
                           let circ = new fabric.Circle({
                               fill: "#D8FFD8D0", radius: 13,
                               strokeWidth: 1, m5_stroke_for_row(ky)
                           })
                           let text = new fabric.Text("--", {originX: "center", originY: "center", textAlign: "center", left: 13, top: 13, fontFamily: "roboto mono", fontSize: 12.5})
                           return {circ, text}
                        },
                        render() {
                           this.obj.text.set({
                              text: '$key_byte'.asHexStr(),
                              fill: '|encrypt$valid_blk'.asBool() ? "black" : "lightgray"
                           })
                           return [];
                        },
                        where: {left: 2, top: 155}

//Macro to perform the Subbytes AND Shift Rows subroutines.
//It is trivial to combine these subroutines, and so we combine
//them into one macro.
//See Sections 5.1.1 and 5.1.2 (pages 15-17) of the NIST AES Specification for more details.
//https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf
\TLV subbytes(/_top, /_name, $_state_in)
   /_name
      /xx[3:0]
         $word[31:0] = /_top$_state_in[32 * #xx +: 32];
         m5+sbox(/xx, /yy, $word)
      // Shift rows
      $ssr_out[127:0] = {/xx[2]/yy[3]$sb_out, /xx[1]/yy[2]$sb_out, /xx[0]/yy[1]$sb_out, /xx[3]/yy[0]$sb_out,
                         /xx[1]/yy[3]$sb_out, /xx[0]/yy[2]$sb_out, /xx[3]/yy[1]$sb_out, /xx[2]/yy[0]$sb_out,
                         /xx[0]/yy[3]$sb_out, /xx[3]/yy[2]$sb_out, /xx[2]/yy[1]$sb_out, /xx[1]/yy[0]$sb_out,
                         /xx[3]/yy[3]$sb_out, /xx[2]/yy[2]$sb_out, /xx[1]/yy[1]$sb_out, /xx[0]/yy[0]$sb_out};
   
\TLV sbox(/_top, /_name, $_word)
   /_name[3:0]
      $word_idx[7:0] = /_top$_word[8 * #m5_strip_prefix(/_name) +: 8];
      $sb_out[7:0] = |encrypt$sbox_vec[ {$word_idx, 3'b0} +: 8];

//Module to verify that the AES encryption has been performed successfully
//The check module can only be run if in ECB
\TLV check(/_top, /_name, $_state_f, $_ui_in)
   /_name
      // Constant values we have are in reverse order.
      // (Can't clean this up because of a Yosys limitation.)
      $reversed_state_f[127:0] =
          {/_top$_state_f[7:0],    /_top$_state_f[15:8],    /_top$_state_f[23:16],   /_top$_state_f[31:24],
           /_top$_state_f[39:32],  /_top$_state_f[47:40],   /_top$_state_f[55:48],   /_top$_state_f[63:56],
           /_top$_state_f[71:64],  /_top$_state_f[79:72],   /_top$_state_f[87:80],   /_top$_state_f[95:88],
           /_top$_state_f[103:96], /_top$_state_f[111:104], /_top$_state_f[119:112], /_top$_state_f[127:120]
          };
      $pass[0:0] = /_top$_ui_in == 1 ? ($reversed_state_f == 128'hb6768473ce9843ea66a81405dd50b345) :
                   /_top$_ui_in == 2 ? ($reversed_state_f == 128'hcb2f430383f9084e03a653571e065de6) :
                   /_top$_ui_in == 4 ? ($reversed_state_f == 128'hff4e66c07bae3e79fb7d210847a3b0ba) :
                   /_top$_ui_in == 8 ? ($reversed_state_f == 128'h7b90785125505fad59b13c186dd66ce3) :
                                       ($reversed_state_f == 128'h8b527a6aebdaec9eaef8eda2cb7783e5);

//Module to perform the mix columns subroutine. See Section
//5.1.3 (page 17) of the NIST AES Specification for more details.
//https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf
\TLV mixcolumn(/_top, /_name, $_block_in)
   /_name
      $const_matrix[127:0] = 128'h02030101_01020301_01010203_03010102; //constant matrix for column multiplicaiton in the form of a vector
      /xx[3:0]
         /yy[3:0]
            $ss[7:0] = /_top$_block_in[(#yy * 8 + #xx * 32) + 7 : (#yy * 8 + #xx * 32)];     //breaks the input vector and
            $cc[7:0] = /_name$const_matrix[(#yy * 8 + #xx * 32) + 7 : (#yy * 8 + #xx * 32)]; //constant matrix into matrices
            /exp[3:0]
               ///xx[#xx]/yy[#exp]$ss * /xx[#exp]/yy[#yy]$cc
               $reduce_check[7:0] = (/xx[#xx]/yy[#exp]$ss[7] == 1) && (/xx[#exp]/yy[#yy]$cc != 8'h01) ? 8'h1b : 8'h00; //check if a reduction by the irreducibly polynomial is necessary
               $three_check[7:0] = /xx[#exp]/yy[#yy]$cc == 8'h03 ? /xx[#xx]/yy[#exp]$ss : 8'h00; //check if a multiplication by 3 is being done
               $op[7:0] = /xx[#exp]/yy[#yy]$cc == 8'h01 ? /xx[#xx]/yy[#exp]$ss : ((/xx[#xx]/yy[#exp]$ss << 1) ^ $three_check ^ $reduce_check); //if 1, identity. otherwise, bitshift & other operations.
            $oo[7:0] = /exp[0]$op ^ /exp[1]$op ^ /exp[2]$op ^ /exp[3]$op; //xor the bytes together
         $out_matrix[31:0] = {/yy[3]$oo, /yy[2]$oo, /yy[1]$oo, /yy[0]$oo} ; //concat matrix rows
      $block_out[127:0] = {/xx[3]$out_matrix, /xx[2]$out_matrix, /xx[1]$out_matrix, /xx[0]$out_matrix}; //concat matrix columns

//Module to perform the key schedule, or key expansion, subroutine. 
//See Section 5.2(page 19) of the NIST AES Specification for more details.
//https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf
\TLV keyschedule(/_top, /_name, $_start_key, $_finished, $_reset, $_round, $_ld_key)
   /_name
      
      //KEY is the exposed output to main. The current key to use will be displayed.
      //After ARK is done on main, it should pulse the keyschedule which will cause
      //it to calculate the next key and have it ready for use.
      $key[127:0] = /_top$_reset ?  '0 : //resets key (loads dummy for testing)
                    /_top$_ld_key ? /_top$_start_key :  //pulls in initial key
                    >>1$next_key; //loads next key
      $compute_next_key = ! /_top$_finished && (/_top$_round < 10);
      ?$compute_next_key
         $rot[31:0] = {$key[103:96], $key[127:104]}; // rotate word
         
         m5+sbox(/_name, /sbox_k, $rot)
         
         $sb_out_word[31:0] = {/sbox_k[3]$sb_out, /sbox_k[2]$sb_out, /sbox_k[1]$sb_out, /sbox_k[0]$sb_out};
         $rcon[7:0] = /_top$_round == 0 ? 8'h01 : //round constant
                      >>1$rcon <  8'h80 ? (2 * >>1$rcon) :
                                 ((2 * >>1$rcon) ^ 8'h1B);
         $xor_con[31:0] = $sb_out_word[31:0] ^ {24'b0, $rcon}; // xor with the round constant
         /word[3:0]
            // ripple solve for next words
            $term1[31:0] = ((#word == 0) ? /_name$xor_con : /word[(#word - 1) % 4]$next_word);
            $term2[31:0] = /_name$key[#word * 32 + 31 : #word * 32];
            $next_word[31:0] = $term1 ^
                               $term2;
         $next_key[127:0] = {/word[3]$next_word, /word[2]$next_word, /word[1]$next_word, /word[0]$next_word};
         
\TLV calc()
   |encrypt
      @0
         $sbox_vec[2047:0] = {
            128'h16bb54b00f2d99416842e6bf0d89a18c,
            128'hdf2855cee9871e9b948ed9691198f8e1,
            128'h9e1dc186b95735610ef6034866b53e70,
            128'h8a8bbd4b1f74dde8c6b4a61c2e2578ba,
            128'h08ae7a65eaf4566ca94ed58d6d37c8e7,
            128'h79e4959162acd3c25c2406490a3a32e0,
            128'hdb0b5ede14b8ee4688902a22dc4f8160,
            128'h73195d643d7ea7c41744975fec130ccd,
            128'hd2f3ff1021dab6bcf5389d928f40a351,
            128'ha89f3c507f02f94585334d43fbaaefd0,
            128'hcf584c4a39becb6a5bb1fc20ed00d153,
            128'h842fe329b3d63b52a05a6e1b1a2c8309,
            128'h75b227ebe28012079a059618c323c704,
            128'h1531d871f1e5a534ccf73f362693fdb7,
            128'hc072a49cafa2d4adf04759fa7dc982ca,
            128'h76abd7fe2b670130c56f6bf27b777c63
            };
         
         $ui_in[7:0] = *ui_in;   //Input to determine mode/keys
         $ofb = $ui_in[7];             //Switch to determine mode
         $blocks_to_run[22:0] = 2000000;     //Blocks of AES to run if in OFB
         
         //Initial State or IV
         $test_state[127:0] =  128'h00000000000000000000000000000000;
                   // 128'hffeeddccbbaa99887766554433221100;
         
         //Initial Key
         $start_key[127:0] =  $ui_in[0] ? 128'h00000000_00000000_0080ffff_ffffffff :
                              $ui_in[1] ? 128'h00000000_00000000_00c0ffff_ffffffff :
                              $ui_in[2] ? 128'h00000000_00000000_00e0ffff_ffffffff :
                              $ui_in[3] ? 128'h00000000_00000000_00f0ffff_ffffffff :
                                          128'h00000000_00000000_00f8ffff_ffffffff;
                                          // 128'h0f0e0d0c_0b0a0908_07060504_03020100;
         
         $valid_blk = ($ofb && ($blk_counter <= $blocks_to_run)) || !$ofb;
         //Counter to count the number of AES blocks performed
         $blk_counter[22:0] = !$reset && >>1$reset ? 0 :
                              !$ld_key && >>1$ld_key && $valid_blk ? >>1$blk_counter + 1 :
                              >>1$blk_counter;
         
         //Reset if *reset or if the ofb_count reaches 12 when in OFB
         $reset = *reset;
         $valid_check = $valid && !$ofb;
         $valid = >>1$round == 10;
         $not_round0 = $valid_blk && $round != 0;
         $do_mixcolumn = $valid_blk && $round != 0 && $round < 10;
         ?$valid_blk
            
            //If in ECB, this checks to see if the AES block if completed
            
            $ld_key = ((!$reset && >>1$reset) || >>1$last_round) ? 1 : 0;
            
            $ld_init = !$reset && >>1$reset ? 1 : 0;
            //round counter
            $round[4:0] = >>1$reset ? 0 :
                          >>1$round >= 10 ? 0 :
                          >>1$valid_blk ? >>1$round + 1 :
                          0;
            $last_round = $round == 10;
            $finishing = $ofb && $last_round && $blk_counter >= $blocks_to_run;
            $finished = $reset ? 0 :
                        >>1$finishing ? 1 :
                        >>1$finished;
            
            //Perform the key schedule subroutine
            m5+keyschedule(|encrypt, /keyschedule, $start_key, $finished, $reset, $round, $ld_key)
            //set the initial state
            $state_i[127:0] = $reset ? '0:
                              $ld_init ? $test_state :
                              >>1$valid_blk ? >>1$state_ark :
                              >>1$state_i;
                              
            //Perform the subbytes and shift row subroutines
            ?$not_round0
               m5+subbytes(|encrypt, /subbytes, $state_i)
            $state_ssr[127:0] = $round == 0 ? $state_i : /subbytes$ssr_out;
            
            //Perform the mixcolumn subroutine
            ?$do_mixcolumn
               m5+mixcolumn(|encrypt, /mixcolumn, $state_ssr)
            $state_mc[127:0] = $do_mixcolumn ? /mixcolumn$block_out : $state_ssr;
            
            //Perform the add round key subroutine
            $state_ark[127:0] = $state_mc ^ /keyschedule$key;
            
            //If in ECB, check for a correct encryption
            
         ?$valid_check
            m5+check(|encrypt, /check, $state_i, $ui_in)
         
         // Capture and drive pass/fail on 7-seg.
         $passed = $reset       ? 1'b0 :
                   $valid_check ? /check$pass :
                                  $RETAIN;
         *uo_out = $passed ? 8'b00111111 :
                             8'b01110110;

   m5_if(m5_MAKERCHIP, ['m5+aes_viz()'])
   
   // Connect Tiny Tapeout outputs. Note that uio_ outputs are not available in the Tiny-Tapeout-3-based FPGA boards.
   //*uo_out = 8'b0;
   m5_if_neq(m5_target, FPGA, ['*uio_out = 8'b0;'])
   m5_if_neq(m5_target, FPGA, ['*uio_oe = 8'b0;'])
   
\SV

// ================================================
// A simple Makerchip Verilog test bench driving random stimulus.
// Modify the module contents to your needs.
// ================================================

module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed);

   /* verilator lint_off UNOPTFLAT */
   // Tiny tapeout I/O signals.
   logic [7:0] ui_in, uo_out;
   m5_if_neq(m5_target, FPGA, ['logic [7:0]uio_in,  uio_out, uio_oe;'])
   logic [31:0] r;
   always @(posedge clk) r <= m5_if(m5_MAKERCHIP, ['$urandom()'], ['0']);
   assign ui_in = 8'b00000001;
   m5_if_neq(m5_target, FPGA, ['assign uio_in = 8'b0;'])
   logic ena = 1'b0;
   logic rst_n = ! reset;
   
   // Instantiate the Tiny Tapeout module.
   m5_user_module_name tt(.*);
   
   assign passed = top.cyc_cnt > 60;
   assign failed = 1'b0;
endmodule


// Provide a wrapper module to debounce input signals if requested.
m5_if(m5_debounce_inputs, ['m5_tt_top(m5_my_design)'])
\SV



// =======================
// The Tiny Tapeout module
// =======================

module m5_user_module_name (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    m5_if_eq(m5_target, FPGA, ['/']['*'])   // The FPGA is based on TinyTapeout 3 which has no bidirectional I/Os (vs. TT6 for the ASIC).
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    m5_if_eq(m5_target, FPGA, ['*']['/'])
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);
   wire reset = ! rst_n;
   
\TLV
   /* verilator lint_off UNOPTFLAT */
   // Connect Tiny Tapeout I/Os to Virtual FPGA Lab.
   m5+tt_connections()
   
   // Instantiate the Virtual FPGA Lab.
   m5+board(/top, /fpga, 7, $, , calc)
   // Label the switch inputs [0..7] (1..8 on the physical switch panel) (top-to-bottom).
   m5+tt_input_labels_viz(['"Value[0]", "Value[1]", "Value[2]", "Value[3]", "Op[0]", "Op[1]", "Op[2]", "="'])

\SV
endmodule
