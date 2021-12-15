\m4_TLV_version 1d: tl-x.org
\SV
   // URL include paths:
   m4_define(['m4_serv_repo'], ['['https://raw.githubusercontent.com/olofk/serv/b845507e32d5d8e6ec43e4a760359096b074ec11/']'])
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
                 let box = new fabric.Rect({
                  width : 80, 
                  height: 80,  
                  top: 20 , 
                  fill: "lightgray",
                  left : 0 
               })
               
                let ALU = new fabric.Text("ALU" , {
                  top: 50,
                  left: 30,
                  fontSize: 12,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })  
               
                let rs1 = new fabric.Rect({
                  width : 120, 
                  height: 8,  
                  top: 30 , 
                  fill: "lightgray",
                  left : -125 
               })
               
                 let op_b = new fabric.Rect({
                  width : 120, 
                  height: 8,  
                  top: 58 , 
                  fill: "lightgray",
                  left : -125 
               })
                 
                 let buf = new fabric.Rect({
                  width : 120, 
                  height: 8,  
                  top: 85 , 
                  fill: "lightgray",
                  left : -125 
               })
               
                 let rd = new fabric.Rect({
                  width : 120, 
                  height: 8,  
                  top: 45 , 
                  fill: "lightgray",
                  left : 85
               })
               
                 let cmp = new fabric.Rect({
                  width : 120, 
                  height: 8,  
                  top: 75 , 
                  fill: "lightgray",
                  left : 85
               })
                 
                let rs1_value = new fabric.Text("rs1" , {
                  top: 30,
                  left: -125,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
                let op_b_value = new fabric.Text("op_b", {
                  top: 58 , 
                  left : -125, 
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
                 
                let buf_value = new fabric.Text("buf" , { 
                  top: 85 , 
                  left : -125 , 
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
                 let rd_value = new fabric.Text("rd" , {
                  top: 45 , 
                  left : 85 , 
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
                let cmp_value = new fabric.Text("cmp" , {
                  top: 75 , 
                  left : 85 ,
                  fontSize: 6,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
               
                let clock_cycle = new fabric.Text("Clock_Cycle" , {
                  top: -10,
                  left: -10,
                  fontSize: 12,
                  fontWeight: 800,
                  fill: "black",
                  fontFamily: "monospace"
               })
                
                  return {objects: {box , ALU, rs1 , op_b , buf , rd , cmp , rs1_value , op_b_value , buf_value , rd_value , cmp_value , clock_cycle}}
               }, 
               layout: "horizontal",
               renderEach() {
                 debugger
                   let alu = `servant_sim.dut.cpu.cpu.alu`
                   let $rs1 = this.svSigRef(`${alu}.i_rs1`)
                   let $op_b = this.svSigRef(`${alu}.i_op_b`)
                   let $buf = this.svSigRef(`${alu}.i_buf`)
                   let $rd = this.svSigRef(`${alu}.o_rd`)
                   let $cmp = this.svSigRef(`${alu}.o_cmp`)
                   let $cycCnt = this.svSigRef(`servant_sim.dut.genblk1.timer.mtime`)
                   let cycCnt_value = $cycCnt.asInt() 
                   /*$rs1.goTo(cycCnt_value*32)
                   $cycCnt.goTo(cycCnt_value*32)
                   $op_b.goTo(cycCnt_value*32)
                   $buf.goTo(cycCnt_value*32)
                   $rd.goTo(cycCnt_value*32)
                   $cmp.goTo(cycCnt_value*32)*/
                   let cycCnt_string = cycCnt_value.toString()
                   this.getInitObject("clock_cycle").set({text: `Clock_Cycle: ${cycCnt_string}`})
                   let rs1_value_32 = ""
                   let buf_value_32 = ""
                   let rd_value_32 = ""
                   let op_b_value_32 = ""
                   let cmp_value_32 = ""
                   
                   let iterator = cycCnt_value/32 
                   for(let i=iterator*32 ; i<=iterator*32 + cycCnt_value%32 ; i++){
                      let rs1_val = $rs1.asInt()
                      let rs1_val_string = rs1_val.toString()
                      rs1_value_32 = `${rs1_val_string}${rs1_value_32}`
                      
                      op_b_val = $op_b.asInt()
                      op_b_val_string = op_b_val.toString()
                      op_b_value_32 = `${op_b_val_string}${op_b_value_32}`
                      
                      buf_val = $buf.asInt()
                      buf_val_string = buf_val.toString()
                      buf_value_32 = `${buf_val_string}${buf_value_32}`
                      
                      rd_val = $rd.asInt()
                      rd_val_string = rd_val.toString()
                      rd_value_32 = `${rd_val_string}${rd_value_32}`
                      
                      cmp_val = $cmp.asInt()
                      cmp_val_string = cmp_val.toString()
                      cmp_value_32 = `${cmp_val_string}${cmp_value_32}`
                      
                      $rs1.step() 
                      $op_b.step() 
                      $buf.step() 
                      $rd.step() 
                      $cmp.step()
                   }
                 
                   this.getInitObject("rs1_value").set({text: `${rs1_value_32}`})
                   this.getInitObject("op_b_value").set({text: `${op_b_value_32}`})
                   this.getInitObject("buf_value").set({text: `${buf_value_32}`})
                   this.getInitObject("rd_value").set({text: `${rd_value_32}`})
                   this.getInitObject("cmp_value").set({text: `${cmp_value_32}`})
               }


\SV
   endmodule
