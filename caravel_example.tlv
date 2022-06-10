\m4_TLV_version 1d: tl-x.org
\SV
  // SPDX-FileCopyrightText: 2022 Steve Hoover & Efabless Corporation
  //
  // Licensed under the Apache License, Version 2.0 (the "License");
  // you may not use this file except in compliance with the License.
  // You may obtain a copy of the License at
  //
  //      http://www.apache.org/licenses/LICENSE-2.0
  //
  // Unless required by applicable law or agreed to in writing, software
  // distributed under the License is distributed on an "AS IS" BASIS,
  // WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  // See the License for the specific language governing permissions and
  // limitations under the License.
  // SPDX-License-Identifier: Apache-2.0

   // A simple demo of what might be done to provide a Makerchip template for Skywater shuttle development.
   // It uses the Efabless Caravel example from https://github.com/efabless/caravel_user_project/tree/main/verilog/rtl
   // It adds random inputs and simple visualization for the Caravel counter example.

   m4_def(caravel_rtl, ['['https://raw.githubusercontent.com/efabless/caravel/main/verilog/rtl']'])

   //m4_sv_get_url(m4_caravel_rtl/caravan_netlists.v)
   //m4_sv_get_url(m4_caravel_rtl/caravan_openframe.v)
   //m4_sv_get_url(m4_caravel_rtl/caravan.v)
   //m4_sv_get_url(m4_caravel_rtl/caravel_clocking.v)
   //m4_sv_get_url(m4_caravel_rtl/caravel_netlists.v)
   //m4_sv_get_url(m4_caravel_rtl/caravel_openframe.v)
   //m4_sv_get_url(m4_caravel_rtl/caravel.v)
   //m4_sv_get_url(m4_caravel_rtl/chip_io_alt.v)
   //m4_sv_get_url(m4_caravel_rtl/chip_io.v)
   //m4_sv_get_url(m4_caravel_rtl/clock_div.v)
   m4_sv_include_url(m4_caravel_rtl/defines.v)
   //m4_sv_get_url(m4_caravel_rtl/digital_pll_controller.v)
   //m4_sv_get_url(m4_caravel_rtl/digital_pll.v)
   //m4_sv_get_url(m4_caravel_rtl/gpio_control_block.v)
   //m4_sv_get_url(m4_caravel_rtl/gpio_defaults_block.v)
   //m4_sv_get_url(m4_caravel_rtl/gpio_logic_high.v)
   //m4_sv_get_url(m4_caravel_rtl/housekeeping_spi.v)
   //m4_sv_get_url(m4_caravel_rtl/housekeeping.v)
   //m4_sv_get_url(m4_caravel_rtl/mgmt_protect_hv.v)
   //m4_sv_get_url(m4_caravel_rtl/mgmt_protect.v)
   //m4_sv_get_url(m4_caravel_rtl/mprj2_logic_high.v)
   //m4_sv_get_url(m4_caravel_rtl/mprj_io.v)
   //m4_sv_get_url(m4_caravel_rtl/mprj_logic_high.v)
   //m4_sv_get_url(m4_caravel_rtl/pads.v)
   //m4_sv_get_url(m4_caravel_rtl/ring_osc2x13.v)
   //m4_sv_get_url(m4_caravel_rtl/simple_por.v)
   //m4_sv_get_url(m4_caravel_rtl/spare_logic_block.v)
   //m4_sv_get_url(m4_caravel_rtl/__uprj_analog_netlists.v)
   //m4_sv_get_url(m4_caravel_rtl/__uprj_netlists.v)
   //m4_sv_get_url(m4_caravel_rtl/__user_analog_project_wrapper.v)
   //m4_sv_get_url(m4_caravel_rtl/user_defines.v)
   //m4_sv_get_url(m4_caravel_rtl/user_id_programming.v)
   //m4_sv_get_url(m4_caravel_rtl/__user_project_wrapper.v)
   //m4_sv_get_url(m4_caravel_rtl/xres_buf.v)

   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v/9a8c337a678779a34bca774b84ad4a0d3c8517a6/warp-v.tlv'])
   
   // =========================================
   // Welcome!  Try the tutorials via the menu.
   // =========================================

   // Default Makerchip TL-Verilog Code Template
   
   // Macro providing required top-level module definition, random
   // stimulus support, and Verilator config.
   
   m4_makerchip_module   // (Expanded in Nav-TLV pane.)
\TLV
   $reset = *reset;
   
   $addr[31:0] = >>1$reset ? 0 : >>1$addr + 1;
   
   \viz_js
      box: {width: 100, height: 100, strokeWidth: 0},
      init() {
         return {
            caravel_img: this.newImageFromURL(
               "https://github.com/stevehoover/makerchip_examples/blob/7829b5bd8be361988d430d56b96727611a4046d3/viz_imgs/caravel_block_diagram.jpg",
               { left: 0,
                 top: 0,
                 width: 100,
                 height: 100
               }),
         }
      },
      render() {
      }
   /counter[3:0]
      \viz_js
         box: {width: 72, height: 30},
         layout: {left: -72},
         init() {
            return {
               wdata_box: new fabric.Rect({left: 0, top: 0, width: 72, height: 15}),
               wdata: new fabric.Text("", {left: 0, top: 0, fill: "blue", fontSize: 15}),
               count_box: new fabric.Rect({left: 0, top: 15, width: 72, height: 15}),
               count: new fabric.Text("", {left: 0, top: 15, fill: "blue", fontSize: 15}),
            }
         },
         render() {
            let i = this.getIndex()
            this.getObjects().wdata_box.set({
               fill: this.sigVal("mprj.counter.ready").asBool() ? "orange" : "transparent"})
            this.getObjects().wdata.set({
                text: this.sigVal("mprj.wdata").asBinaryStr().substring(8 * (3 - i), 8 * (4 - i)),
                fill: this.sigVal("mprj.valid").asBool() ? "blue" : "gray"})
            this.getObjects().count_box.set({
               fill: ((this.sigVal("mprj.wstrb").asInt() >> this.getIndex()) & 1) ? "#ffd0d0" : "transparent"})
            this.getObjects().count.set(
               {text: this.sigVal("mprj.count").asBinaryStr().substring(8 * (3 - i), 8 * (4 - i))})
         },
         where: {left: 67, top: 45, width: 15, height: 1}
   
   \SV_plus
      /*--------------------------------------*/
      /* User project is instantiated  here   */
      /*--------------------------------------*/
      
      user_proj_example mprj (
      
          .wb_clk_i(*clk),
          .wb_rst_i(*reset),
      
          // MGMT SoC Wishbone Slave
      
          .wbs_cyc_i($wbs_cyc_i),
          .wbs_stb_i(1'b1),
          .wbs_we_i($wbs_we_i),
          .wbs_sel_i($wbs_sel_i[3:0]),
          .wbs_adr_i($wbs_adr_i[31:0]),
          .wbs_dat_i($wbs_dat_i[31:0]),
          .wbs_ack_o($$wbs_ack_o),
          .wbs_dat_o($$wbs_dat_o[31:0]),
      
          // Logic Analyzer
      
          .la_data_in($la_data_in[127:0]),
          .la_data_out($$la_data_out[127:0]),
          .la_oenb ({128{1'b1}}),
      
          // IO Pads
      
          .io_in ($io_in[`MPRJ_IO_PADS-1:0]),
          .io_out($$io_out[`MPRJ_IO_PADS-1:0]),
          .io_oeb($io_oeb[`MPRJ_IO_PADS-1:0]),
      
          // IRQ
          .irq($$user_irq[2:0])
      );


   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 40;
   *failed = 1'b0;
\SV
   endmodule




`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;

    //wire [`MPRJ_IO_PADS-1:0] io_in;
    //wire [`MPRJ_IO_PADS-1:0] io_out;
    //wire [`MPRJ_IO_PADS-1:0] io_oeb;

    wire [31:0] rdata; 
    wire [31:0] wdata;
    wire [BITS-1:0] count;

    wire valid;
    wire [3:0] wstrb;
    wire [31:0] la_write;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i; 
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o = rdata;
    assign wdata = wbs_dat_i;

    // IO
    assign io_out = count;
    assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    // IRQ
    assign irq = 3'b000;	// Unused

    // LA
    assign la_data_out = {{(127-BITS){1'b0}}, count};
    // Assuming LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:32] & ~{BITS{valid}};
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;

    counter #(
        .BITS(BITS)
    ) counter(
        .clk(clk),
        .reset(rst),
        .ready(wbs_ack_o),
        .valid(valid),
        .rdata(rdata),
        .wdata(wbs_dat_i),
        .wstrb(wstrb),
        .la_write(la_write),
        .la_input(la_data_in[63:32]),
        .count(count)
    );

endmodule

module counter #(
    parameter BITS = 32
)(
    input clk,
    input reset,
    input valid,
    input [3:0] wstrb,
    input [BITS-1:0] wdata,
    input [BITS-1:0] la_write,
    input [BITS-1:0] la_input,
    output reg ready,
    output reg [BITS-1:0] rdata,
    output reg [BITS-1:0] count
);
    //reg ready;
    //reg [BITS-1:0] count;
    //reg [BITS-1:0] rdata;

    always @(posedge clk) begin
        if (reset) begin
            count <= 0;
            ready <= 0;
        end else begin
            ready <= 1'b0;
            if (~|la_write) begin
                count <= count + 1;
            end
            if (valid && !ready) begin
                ready <= 1'b1;
                rdata <= count;
                if (wstrb[0]) count[7:0]   <= wdata[7:0];
                if (wstrb[1]) count[15:8]  <= wdata[15:8];
                if (wstrb[2]) count[23:16] <= wdata[23:16];
                if (wstrb[3]) count[31:24] <= wdata[31:24];
            end else if (|la_write) begin
                count <= la_write & la_input;
            end
        end
    end

endmodule
`default_nettype wire