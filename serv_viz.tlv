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

   |default 
      @1
         /dummy
            \viz_alpha
               initEach() {
               debugger
               let serv_immdec = new fabric.Rect({
                  width : 40, 
                  height: 8,  
                  top: -100, 
                  fill: "lightgray",
                  left : -250 
               })
               
               let serv_immdec_text = new fabric.Text("serv_immdec", {
                  top: -100,
                  left: -250,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               }) 
               
               let serv_rf_if = new fabric.Rect({
                  width : 40, 
                  height: 8,  
                  top: -25, 
                  fill: "lightgray",
                  left : -250 
               })
               
               let serv_rf_if_text = new fabric.Text("serv_rf_if", {
                  top: -25,
                  left: -250,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let serv_buffreg = new fabric.Rect({
                  width : 80, 
                  height: 8,  
                  top: -45, 
                  fill: "lightgray",
                  left : -150 
               })
               
               let serv_buffreg_text = new fabric.Text("serv_buffreg", {
                  top: -45,
                  left: -130,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let op_b_source = new fabric.Rect({
                  width : 80, 
                  height: 8,  
                  top: 25, 
                  fill: "lightgray",
                  left : -150 
               })
               
               let op_b_source_text = new fabric.Text("op_b_source", {
                  top: 25,
                  left: -130,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let serv_ctrl = new fabric.Rect({
                  width : 80, 
                  height: 8,  
                  top: -100, 
                  fill: "lightgray",
                  left : 0 
               })
               
               let serv_ctrl_text = new fabric.Text("serv_ctrl", {
                  top: -100,
                  left: 20,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let serv_csr = new fabric.Rect({
                  width : 80, 
                  height: 8,  
                  top: -40, 
                  fill: "lightgray",
                  left : 0 
               })
               
               let serv_csr_text = new fabric.Text("serv_csr", {
                  top: -40,
                  left: 20,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let serv_alu = new fabric.Rect({
                  width : 80, 
                  height: 8,  
                  top: 20 , 
                  fill: "lightgray",
                  left : 0 
               })
               
               let serv_alu_text = new fabric.Text("serv_alu", {
                  top: 20,
                  left: 20,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let serv_mem_if = new fabric.Rect({
                  width : 80, 
                  height: 8,  
                  top: 80, 
                  fill: "lightgray",
                  left : 0 
               })
               
               let serv_mem_if_text = new fabric.Text("serv_mem_if", {
                  top: 80,
                  left: 20,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let serv_rf_if_out = new fabric.Rect({
                  width : 60, 
                  height: 8,  
                  top: -80, 
                  fill: "lightgray",
                  left : 150 
               })
               
               let serv_rf_if_out_text = new fabric.Text("serv_rf_if_out", {
                  top: -80,
                  left: 150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_imm = new fabric.Text("o_imm" , {
                  top: -92,
                  left: -250,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_csr_imm = new fabric.Text("o_csr_imm" , {
                  top: -84,
                  left: -250,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_csr_pc = new fabric.Text("o_csr_pc" , {
                  top: -17,
                  left: -250,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_csr = new fabric.Text("o_csr" , {
                  top: -9,
                  left: -250,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_rs1 = new fabric.Text("o_rs1" , {
                  top: -1,
                  left: -250,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_rs2 = new fabric.Text("o_rs2" , {
                  top: 7,
                  left: -250,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_imm = new fabric.Text("i_imm" , {
                  top: -37,
                  left: -150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_rs1 = new fabric.Text("i_rs1" , {
                  top: -29,
                  left: -150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_q = new fabric.Text("o_q" , {
                  top: -37,
                  left: -110,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let imm = new fabric.Text("imm" , {
                  top: 33,
                  left: -150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let rs2 = new fabric.Text("rs2" , {
                  top: 41,
                  left: -150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let op_b = new fabric.Text("op_b" , {
                  top: 33,
                  left: -110,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_imm_ctrl = new fabric.Text("i_imm" , {
                  top: -92,
                  left: 0,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_csr_pc_ctrl = new fabric.Text("i_csr_pc" , {
                  top: -84,
                  left: 0,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_buf_ctrl = new fabric.Text("i_buf" , {
                  top: -76,
                  left: 0,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_rd_ctrl = new fabric.Text("o_rd" , {
                  top: -92,
                  left: 40,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_bad_pc_ctrl = new fabric.Text("o_bad_pc" , {
                  top: -84,
                  left: 40,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_ibus_addr0_ctrl = new fabric.Text("o_ibus_adr[0]" , {
                  top: -76,
                  left: 40,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_csr_imm_csr = new fabric.Text("i_csr_imm" , {
                  top: -32,
                  left: 0,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_rf_csr_out_csr = new fabric.Text("i_rf_csr_out" , {
                  top: -24,
                  left: 0,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_rs1_csr = new fabric.Text("i_rs1" , {
                  top: -16,
                  left: 0,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_q_csr = new fabric.Text("o_q" , {
                  top: -32,
                  left: 40,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_csr_in_csr = new fabric.Text("o_csr_in" , {
                  top: -24,
                  left: 40,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_buf_alu = new fabric.Text("i_buf" , {
                  top: 28,
                  left: 0,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_rs1_alu = new fabric.Text("i_rs1" , {
                  top: 36,
                  left: 0,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_op_b_alu = new fabric.Text("i_op_b" , {
                  top: 44,
                  left: 0,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_rd_alu = new fabric.Text("o_rd" , {
                  top: 28,
                  left: 40,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_op_b_mem_if = new fabric.Text("i_op_b" , {
                  top: 88,
                  left: 0,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let o_rd_mem_if = new fabric.Text("o_rd" , {
                  top: 88,
                  left: 40,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_ctrl_rd_rf_if = new fabric.Text("i_ctrl_rd" , {
                  top: -72,
                  left: 150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_bad_pc_rf_if = new fabric.Text("i_bad_pc" , {
                  top: -64,
                  left: 150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_mepc_rf_if = new fabric.Text("i_mepc" , {
                  top: -56,
                  left: 150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_csr_rd_rf_if = new fabric.Text("i_csr_rd" , {
                  top: -48,
                  left: 150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_csr_rf_if = new fabric.Text("i_csr" , {
                  top: -40,
                  left: 150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_buf_rf_if = new fabric.Text("i_buf" , {
                  top: -32,
                  left: 150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_alu_rd_rf_if = new fabric.Text("i_alu_rd" , {
                  top: -24,
                  left: 150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               let i_mem_rd_rf_if = new fabric.Text("i_mem_rd" , {
                  top: -16,
                  left: 150,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
               return {objects: {serv_immdec , serv_immdec_text , serv_rf_if , serv_rf_if_text , serv_buffreg , serv_buffreg_text , op_b_source , op_b_source_text , serv_ctrl , serv_ctrl_text, serv_csr , serv_csr_text , serv_alu , serv_alu_text , serv_mem_if , serv_mem_if_text , serv_rf_if_out , serv_rf_if_out_text , o_imm , o_csr_imm, o_csr_pc , o_csr , o_rs1 , o_rs2 , i_imm , i_rs1 , o_q, imm , rs2 , op_b , i_imm_ctrl , i_csr_pc_ctrl , i_buf_ctrl , o_rd_ctrl ,o_bad_pc_ctrl , o_ibus_addr0_ctrl , i_csr_imm_csr , i_rf_csr_out_csr ,i_rs1_csr , o_q_csr , o_csr_in_csr , i_buf_alu ,i_rs1_alu , i_op_b_alu , o_rd_alu , i_op_b_mem_if , o_rd_mem_if , i_ctrl_rd_rf_if , i_bad_pc_rf_if , i_mepc_rf_if , i_csr_rd_rf_if , i_csr_rf_if , i_buf_rf_if , i_alu_rd_rf_if , i_mem_rd_rf_if }};  
               }, 
               layout: "horizontal",
               renderEach() {
                  debugger
                 let o_imm_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.immdec.o_imm`).asInt()
                 let o_imm_decode_string = o_imm_decode.toString()
                 this.getInitObject("o_imm").setText(`${o_imm_decode_string}`)
                 
                 let o_csr_imm_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.immdec.o_csr_imm`).asInt()
                 let o_csr_imm_decode_string = o_csr_imm_decode.toString()
                 this.getInitObject("o_csr_imm").setText(`${o_csr_imm_decode_string}`)
                 
                 let o_csr_pc_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.o_csr_pc`).asInt()
                 let o_csr_pc_decode_string = o_csr_pc_decode.toString()
                 this.getInitObject("o_csr_pc").setText(`${o_csr_pc_decode_string}`)
                 
                 let o_csr_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.o_csr`).asInt()
                 let o_csr_decode_string = o_csr_decode.toString()
                 this.getInitObject("o_csr").setText(`${o_csr_decode_string}`)
                 
                 let o_rs1_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.o_rs1`).asInt()
                 let o_rs1_decode_string = o_rs1_decode.toString()
                 this.getInitObject("o_rs1").setText(`${o_rs1_decode_string}`)
                 
                 let o_rs2_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.o_rs2`).asInt()
                 let o_rs2_decode_string = o_rs2_decode.toString()
                 this.getInitObject("o_rs2").setText(`${o_rs2_decode_string}`)
                 
                 let i_imm_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.bufreg.i_imm`).asInt()
                 let i_imm_decode_string = i_imm_decode.toString()
                 this.getInitObject("i_imm").setText(`${i_imm_decode_string}`)
                 
                 let i_rs1_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.bufreg.i_rs1`).asInt()
                 let i_rs1_decode_string = i_rs1_decode.toString()
                 this.getInitObject("i_rs1").setText(`${i_rs1_decode_string}`)
                 
                 let o_q_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.bufreg.o_q`).asInt()
                 let o_q_decode_string = o_q_decode.toString()
                 this.getInitObject("o_q").setText(`${o_q_decode_string}`)
                 
                 let imm_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.immdec.o_imm`).asInt()
                 let imm_decode_string = imm_decode.toString()
                 this.getInitObject("imm").setText(`${imm_decode_string}`)
                 
                 let rs2_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.o_rs2`).asInt()
                 let rs2_decode_string = rs2_decode.toString()
                 this.getInitObject("rs2").setText(`${rs2_decode_string}`)
                 
                 let op_b_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.op_b`).asInt()
                 let op_b_decode_string = op_b_decode.toString()
                 this.getInitObject("op_b").setText(`${op_b_decode_string}`)
                 
                 let i_imm_ctrl_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.ctrl.i_imm`).asInt()
                 let i_imm_ctrl_decode_string = i_imm_ctrl_decode.toString()
                 this.getInitObject("i_imm_ctrl").setText(`${i_imm_ctrl_decode_string}`)
                 
                 let i_csr_pc_ctrl_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.ctrl.i_csr_pc`).asInt()
                 let i_csr_pc_ctrl_decode_string = i_csr_pc_ctrl_decode.toString()
                 this.getInitObject("i_csr_pc_ctrl").setText(`${i_csr_pc_ctrl_decode_string}`)
                 
                 let i_buf_ctrl_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.ctrl.i_buf`).asInt()
                 let i_buf_ctrl_decode_string = i_buf_ctrl_decode.toString()
                 this.getInitObject("i_buf_ctrl").setText(`${i_buf_ctrl_decode_string}`)
                 
                 let o_rd_ctrl_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.ctrl.o_rd`).asInt()
                 let o_rd_ctrl_decode_string = o_rd_ctrl_decode.toString()
                 this.getInitObject("o_rd_ctrl").setText(`${o_rd_ctrl_decode_string}`)
                 
                 let o_bad_pc_ctrl_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.ctrl.o_bad_pc`).asInt()
                 let o_bad_pc_ctrl_decode_string = o_bad_pc_ctrl_decode.toString()
                 this.getInitObject("o_bad_pc_ctrl").setText(`${o_bad_pc_ctrl_decode_string}`)
                 
                 let o_ibus_addr0_ctrl_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.ctrl.o_ibus_adr`).asInt()
                 let o_ibus_addr0_ctrl_decode_string = o_ibus_addr0_ctrl_decode.toString()
                 this.getInitObject("o_ibus_addr0_ctrl").setText(`${o_ibus_addr0_ctrl_decode_string}`)
               
                 /*let i_csr_imm_csr_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.csr.i_csr_imm`).asInt()
                 let i_csr_imm_csr_decode_string = i_csr_imm_csr_decode.toString()
                 this.getInitObject("i_csr_imm_csr").setText(`${i_csr_imm_csr_decode_string}`)
               
                 let i_rf_csr_out_csr_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.csr.i_rf_csr_out`).asInt()
                 let i_rf_csr_out_csr_decode_string = i_rf_csr_out_csr_decode.toString()
                 this.getInitObject("i_rf_csr_out_csr").setText(`${i_rf_csr_out_csr_decode_string}`)
                 
                 let i_rs1_csr_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.csr.i_rs1`).asInt()
                 let i_rs1_csr_decode_string = i_rs1_csr_decode.toString()
                 this.getInitObject("i_rs1_csr").setText(`${i_rs1_csr_decode_string}`)
                 
                 let o_q_csr_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.csr.o_q`).asInt()
                 let o_q_csr_decode_string = o_q_csr_decode.toString()
                 this.getInitObject("o_q_csr").setText(`${o_q_csr_decode_string}`)
                 
                 let o_csr_in_csr_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.csr.o_csr_in`).asInt()
                 let o_csr_in_csr_decode_string = o_csr_in_csr_decode.toString()
                 this.getInitObject("o_csr_in_csr").setText(`${o_csr_in_csr_decode_string}`)
                 */
                 let i_buf_alu_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.alu.i_buf`).asInt()
                 let i_buf_alu_decode_string = i_buf_alu_decode.toString()
                 this.getInitObject("i_buf_alu").setText(`${i_buf_alu_decode_string}`)
                 
                 let i_rs1_alu_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.alu.i_rs1`).asInt()
                 let i_rs1_alu_decode_string = i_rs1_alu_decode.toString()
                 this.getInitObject("i_rs1_alu").setText(`${i_rs1_alu_decode_string}`)
                 
                 let i_op_b_alu_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.alu.i_op_b`).asInt()
                 let i_op_b_alu_decode_string = i_op_b_alu_decode.toString()
                 this.getInitObject("i_op_b_alu").setText(`${i_op_b_alu_decode_string}`)
                 
                 let o_rd_alu_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.alu.o_rd`).asInt()
                 let o_rd_alu_decode_string = o_rd_alu_decode.toString()
                 this.getInitObject("o_rd_alu").setText(`${o_rd_alu_decode_string}`)
                 
                 let i_op_b_mem_if_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.mem_if.i_op_b`).asInt()
                 let i_op_b_mem_if_decode_string = i_op_b_mem_if_decode.toString()
                 this.getInitObject("i_op_b_mem_if").setText(`${i_op_b_mem_if_decode_string}`)
                 
                 let o_rd_mem_if_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.mem_if.o_rd`).asInt()
                 let o_rd_mem_if_decode_string = o_rd_mem_if_decode.toString()
                 this.getInitObject("o_rd_mem_if").setText(`${o_rd_mem_if_string}`)
                 
                 let i_ctrl_rd_rf_if_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.i_ctrl_rd`).asInt()
                 let i_ctrl_rd_rf_if_decode_string = i_ctrl_rd_rf_if_decode.toString()
                 this.getInitObject("i_ctrl_rd_rf_if").setText(`${i_ctrl_rd_rf_if_string}`)
                 
                 let i_bad_pc_rf_if_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.i_bad_pc`).asInt()
                 let i_bad_pc_rf_if_decode_string = i_bad_pc_rf_if_decode.toString()
                 this.getInitObject("i_bad_pc_rf_if").setText(`${i_bad_pc_rf_if_string}`)
                 
                 let i_mepc_rf_if_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.i_mepc`).asInt()
                 let i_mepc_rf_if_decode_string = i_mepc_rf_if_decode.toString()
                 this.getInitObject("i_mepc_rf_if").setText(`${i_mepc_rf_if_string}`)
                 
                 let i_csr_rd_rf_if_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.i_csr_rd`).asInt()
                 let i_csr_rd_rf_if_decode_string = i_csr_rd_rf_if_decode.toString()
                 this.getInitObject("i_csr_rd_rf_if").setText(`${i_csr_rd_rf_if_string}`)
                 
                 let i_csr_rf_if_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.i_csr`).asInt()
                 let i_csr_rf_if_decode_string = i_csr_rf_if_decode.toString()
                 this.getInitObject("i_csr_rf_if").setText(`${i_csr_rf_if_string}`)
                 
                 let i_buf_rf_if_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.i_bufreg_q`).asInt()
                 let i_buf_rf_if_decode_string = i_buf_rf_if_decode.toString()
                 this.getInitObject("i_buf_rf_if").setText(`${i_buf_rf_if_string}`)
                 
                 let i_alu_rd_rf_if_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.i_alu_rd`).asInt()
                 let i_alu_rd_rf_if_decode_string = i_alu_rd_rf_if_decode.toString()
                 this.getInitObject("i_alu_rd_rf_if").setText(`${i_alu_rd_rf_if_string}`)
                 
                 let i_mem_rd_rf_if_decode = this.svSigRef(`servant_sim.dut.cpu.cpu.rf_if.i_mem_rd`).asInt()
                 let i_mem_rd_rf_if_decode_string = i_mem_rd_rf_if_decode.toString()
                 this.getInitObject("i_mem_rd_rf_if").setText(`${i_mem_rd_rf_if_string}`)
                 
               }


\SV
   endmodule
