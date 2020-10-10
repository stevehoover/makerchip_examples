\m4_TLV_version 1d: tl-x.org
\SV
   // URL include paths:
   m4_define(['m4_swerv_repo'], ['['https://raw.githubusercontent.com/stevehoover/Cores-SweRV/master/']'])
   m4_define(['m4_swerv_src'], ['m4_swerv_repo['design/']'])
   m4_define(['m4_swerv_config_src'], ['m4_swerv_repo['configs/snapshots/default/']'])

   // Headers:
   m4_sv_get_url(m4_swerv_config_src['pic_map_auto.h'])
   m4_sv_get_url(m4_swerv_config_src['pic_ctrl_verilator_unroll.sv'])
   // Headers not explicitly included by SweRV source code:
   m4_sv_include_url(m4_swerv_config_src['common_defines.vh'])
   m4_sv_include_url(m4_swerv_src['include/build.h'])
   m4_sv_include_url(m4_swerv_src['include/global.h'])
   m4_sv_include_url(m4_swerv_src['include/swerv_types.sv'])
   
   // Modules:
   m4_sv_include_url(m4_swerv_repo['testbench/tb_top.sv'])
   m4_sv_include_url(m4_swerv_repo['testbench/ahb_sif.sv'])
   m4_sv_include_url(m4_swerv_src['swerv_wrapper.sv'])
   m4_sv_include_url(m4_swerv_src['mem.sv'])
   m4_sv_include_url(m4_swerv_src['pic_ctrl.sv'])
   m4_sv_include_url(m4_swerv_src['swerv.sv'])
   m4_sv_include_url(m4_swerv_src['dma_ctrl.sv'])
   m4_sv_include_url(m4_swerv_src['ifu/ifu_aln_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['ifu/ifu_compress_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['ifu/ifu_ifc_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['ifu/ifu_bp_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['ifu/ifu_ic_mem.sv'])
   m4_sv_include_url(m4_swerv_src['ifu/ifu_mem_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['ifu/ifu_iccm_mem.sv'])
   m4_sv_include_url(m4_swerv_src['ifu/ifu.sv'])
   m4_sv_include_url(m4_swerv_src['dec/dec_decode_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['dec/dec_gpr_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['dec/dec_ib_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['dec/dec_tlu_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['dec/dec_trigger.sv'])
   m4_sv_include_url(m4_swerv_src['dec/dec.sv'])
   m4_sv_include_url(m4_swerv_src['exu/exu_alu_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['exu/exu_mul_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['exu/exu_div_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['exu/exu.sv'])
   m4_sv_include_url(m4_swerv_src['lsu/lsu.sv'])
   m4_sv_include_url(m4_swerv_src['lsu/lsu_clkdomain.sv'])
   m4_sv_include_url(m4_swerv_src['lsu/lsu_addrcheck.sv'])
   m4_sv_include_url(m4_swerv_src['lsu/lsu_lsc_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['lsu/lsu_stbuf.sv'])
   m4_sv_include_url(m4_swerv_src['lsu/lsu_bus_buffer.sv'])
   m4_sv_include_url(m4_swerv_src['lsu/lsu_bus_intf.sv'])
   m4_sv_include_url(m4_swerv_src['lsu/lsu_ecc.sv'])
   m4_sv_include_url(m4_swerv_src['lsu/lsu_dccm_mem.sv'])
   m4_sv_include_url(m4_swerv_src['lsu/lsu_dccm_ctl.sv'])
   m4_sv_include_url(m4_swerv_src['lsu/lsu_trigger.sv'])
   m4_sv_include_url(m4_swerv_src['dbg/dbg.sv'])
   m4_sv_include_url(m4_swerv_src['dmi/dmi_wrapper.v'])
   m4_sv_include_url(m4_swerv_src['dmi/dmi_jtag_to_core_sync.v'])
   m4_sv_include_url(m4_swerv_src['dmi/rvjtag_tap.sv'])
   m4_sv_include_url(m4_swerv_src['lib/beh_lib.sv'])
   m4_sv_include_url(m4_swerv_src['lib/mem_lib.sv'])
   m4_sv_include_url(m4_swerv_src['lib/ahb_to_axi4.sv'])
   m4_sv_include_url(m4_swerv_src['lib/axi4_to_ahb.sv'])
   
   // Hex files:
   m4_sv_get_url(m4_swerv_repo['testbench/hex/data.hex'])
   m4_sv_get_url(m4_swerv_repo['testbench/hex/program.hex'])

   m4_makerchip_module   // (Expanded in Nav-TLV pane.)

   logic finished;
   tb_top tb_top(.core_clk(clk), .reset_l(! reset), .finished(finished));



\TLV
   // Assert these to end simulation (before Makerchip cycle limit).
   *passed = *cyc_cnt > 100 || finished;
   *failed = 1'b0;

   /dummy
      \viz
         initEach: function() {
            debugger;
            let cycCntText = new fabric.Text("",
                              {  top: 0,
                                 left: 0,
                                 fontFamily: "monospace",
                                 fontSize: 20
                              });
            global.canvas.add(cycCntText);
         
            return {cycCntText};
         },
         renderEach: function() {
            debugger;
         
            let cycCnt = this.svSigRef(`cyc_cnt`, 0).asInt();
            let cycCntStr = cycCnt.toString();
            this.fromInit().cycCntText.setText(cycCntStr);
         }

\SV
   endmodule
