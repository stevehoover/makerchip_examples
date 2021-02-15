\m4_TLV_version 1d: tl-x.org
\SV
   // URL include paths:
   m4_define(['m4_serv_repo'], ['['https://raw.githubusercontent.com/olofk/serv/master/']'])
   m4_define(['m4_serv_rtl'], ['m4_serv_repo['rtl/']'])
   m4_define(['m4_servant_rtl'], ['m4_serv_repo['servant/']'])
   m4_define(['m4_serv_bench'], ['m4_serv_repo['bench/']'])
   m4_define(['m4_serv_hex'], ['m4_serv_repo['sw/']'])

   //Bench RTL
   //m4_sv_get_url(m4_swerv_config_src['pic_map_auto.h'])
   m4_sv_get_url(m4_serv_bench['servant_tb.v'])
   //m4_sv_include_url(m4_serv_bench['uart_decoder.v'])

   
   // Modules:
   // Core RTL
   m4_sv_get_url(m4_serv_rtl['serv_alu.v'])
   m4_sv_get_url(m4_serv_rtl['serv_bufreg.v'])
   m4_sv_get_url(m4_serv_rtl['serv_csr.v'])
   m4_sv_get_url(m4_serv_rtl['serv_ctrl.v'])
   m4_sv_get_url(m4_serv_rtl['serv_decode.v'])
   m4_sv_get_url(m4_serv_rtl['serv_immdec.v'])
   m4_sv_get_url(m4_serv_rtl['serv_mem_if.v'])
   m4_sv_get_url(m4_serv_rtl['serv_params.vh'])
   m4_sv_get_url(m4_serv_rtl['serv_rf_if.v'])
   m4_sv_get_url(m4_serv_rtl['serv_rf_ram.v'])
   m4_sv_get_url(m4_serv_rtl['serv_rf_ram_if.v'])
   m4_sv_get_url(m4_serv_rtl['serv_rf_top.v'])
   m4_sv_get_url(m4_serv_rtl['serv_state.v'])
   m4_sv_get_url(m4_serv_rtl['serv_top.v'])

   //Servant RTL
   m4_sv_get_url(m4_servant_rtl['ecppll.v'])
   m4_sv_get_url(m4_servant_rtl['servant.v'])
   m4_sv_get_url(m4_servant_rtl['servant_ac701.v'])
   m4_sv_get_url(m4_servant_rtl['servant_arbiter.v'])
   m4_sv_get_url(m4_servant_rtl['servant_clock_gen.v'])
   m4_sv_get_url(m4_servant_rtl['servant_ecp5.v'])
   m4_sv_get_url(m4_servant_rtl['servant_ecp5_clock_gen.v'])
   m4_sv_get_url(m4_servant_rtl['servant_gpio.v'])
   m4_sv_get_url(m4_servant_rtl['servant_lx9.v'])
   m4_sv_get_url(m4_servant_rtl['servant_lx9_clock_gen.v'])
   m4_sv_get_url(m4_servant_rtl['servant_mux.v'])
   m4_sv_get_url(m4_servant_rtl['servant_orangecrab.v'])
   m4_sv_get_url(m4_servant_rtl['servant_ram.v'])
   m4_sv_get_url(m4_servant_rtl['servant_ram_quartus.sv'])
   m4_sv_get_url(m4_servant_rtl['servant_timer.v'])
   m4_sv_get_url(m4_servant_rtl['servant_upduino2.v'])
   m4_sv_get_url(m4_servant_rtl['servclone10.v'])
   m4_sv_get_url(m4_servant_rtl['servclone10_clock_gen.v'])
   m4_sv_get_url(m4_servant_rtl['service.v'])
   m4_sv_get_url(m4_servant_rtl['servis.v'])
   m4_sv_get_url(m4_servant_rtl['servis_clock_gen.v'])
   m4_sv_get_url(m4_servant_rtl['servive.v'])
   m4_sv_get_url(m4_servant_rtl['servive_clock_gen.v'])
   m4_sv_get_url(m4_servant_rtl['servix.v '])
   m4_sv_get_url(m4_servant_rtl['servix_clock_gen.v'])
   m4_sv_get_url(m4_servant_rtl['servus.v'])
   m4_sv_get_url(m4_servant_rtl['servus_clock_gen.v'])

                                 
   
   // Hex files:
   m4_sv_get_url(m4_serv_hex['blinky.hex'])
   
   module servant_sim
   	(input wire  wb_clk,
   	input wire  wb_rst,
   	output wire q);
   	parameter memfile = "";
   	parameter memsize = 8192;
   	parameter with_csr = 1;
   	reg [1023:0] firmware_file;
   initial
   	begin
   	$display("Loading RAM from %0s", "./sv_url_inc/blinky.hex");
   	$readmemh("./sv_url_inc/blinky.hex", dut.ram.mem);
   	end
   servant #(.memfile  (memfile),
   	.memsize  (memsize),
   	.sim      (1),
   	.with_csr (with_csr))
   	dut(wb_clk, wb_rst, q);
   endmodule


   m4_makerchip_module   // (Expanded in Nav-TLV pane.)

   logic finished;
   servant_sim servant_sim(.wb_clk(clk), .wb_rst(reset), .q(finished));



\TLV
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 500 || finished;
   *failed = 1'b0;

   /dummy
      \viz_alpha
         initEach() {
            let led = new fabric.Text("", {
                  top: -20,
                  left: 0,
                  fontSize: 50,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
            let cycCntText = new fabric.Text("",
                              {  top: -80,
                                 left: -40,
                                 fontFamily: "monospace",
                                 fontSize: 20
                              })
            let text = new fabric.Text("", {
                  top: 70,
                  left: 0,
                  fontSize: 10,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
            let mem_text = new fabric.Text("", {
                  top: 400,
                  left: 0,
                  fontSize: 10,
                  fontWeight: 800,
                  fill: "blue",
                  fontFamily: "monospace"
               })
            
            return {objects: {led, cycCntText, text, mem_text /*result_bool, op_b */}}
         },
         renderEach() {
            // Find the last pulse of cnt0.
            let alu = `servant_sim.dut.cpu.cpu.alu`
            let $cnt0 = this.svSigRef(`${alu}.i_cnt0`)
            let bool_op = this.svSigRef(`${alu}.i_bool_op`).asInt()
            let $result_bool = this.svSigRef(`${alu}.result_bool`)
            let $op_b = this.svSigRef(`${alu}.i_op_b`)
            let cycCnt = this.svSigRef(`servant_sim.dut.genblk1.timer.mtime`).asInt()
            let led = this.svSigRef(`servant_sim.dut.gpio.i_wb_we`, 0).asBool()
            let cycCntStr = cycCnt.toString()
            this.getInitObject("cycCntText").setText(`mtime: ${cycCntStr}`)
            this.getInitObject("led").setText(led ? "🚨" : "_")
            $cnt0.backToValue(1)
            let cnt0_cyc = $cnt0.getCycle()
            $result_bool.goTo(cnt0_cyc + 4)
            $op_b.goTo(cnt0_cyc + 4)
            let result_bool_value = 0
            let op_b_value = 0
            let result_bool_str = ""
            let op_b_str = ""
            for (let b = 0; b < 32; b++) {
              $result_bool.step()
              $op_b.step()
              result_bool_value = result_bool_value | ($result_bool.asInt() << b)
              result_bool_str = `${$result_bool.asBool() ? "1" : "0"}${result_bool_str}`
              op_b_value = op_b_value | ($op_b.asInt() << b)
              op_b_str = `${$op_b.asBool() ? "1" : "0"}${op_b}`
            }
            this.getInitObject("text").setText(`cnt0_cyc: ${cnt0_cyc}\nbool_op: ${bool_op}\nresult_bool: ${result_bool_str} ${result_bool_value}\nop_b: ${result_bool_str} ${op_b_value}`)
         
            // Memory
            let ram = `servant_sim.dut.ram`
            let addr = this.svSigRef(`${ram}.addr`).asInt()
            let we = this.svSigRef(`${ram}.we`).asBool()
            let dat = this.svSigRef(`${ram}.i_wb_dat`).asInt()
            this.getInitObject("mem_text").setText(`we: ${we}\nwb_data: ${dat}\naddr: ${addr}`)
         }

\SV
   endmodule
