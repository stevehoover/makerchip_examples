\m5_TLV_version 1d: tl-x.org
\m5
   / This example shows a WARP-V (TL-Verilog RISC-V core) implemented in Tiny Tapeout.
   / See warp-v.org for information about WARP-V.
   / Requires 8 tiles.

   use(m5-1.0)

   / WARP-V configuration settings.
   var(ISA, RISCV)
   var(EXT_E, 0)
   var(EXT_M, 0)
   var(EXT_F, 0)
   var(EXT_B, 0)
   var(NUM_CORES, 1)
   var(NUM_VCS, 2)
   var(NUM_PRIOS, 2)
   var(MAX_PACKET_SIZE, 8)
   var(soft_reset, 1'b0)
   var(cpu_blocked, 1'b0)
   var(BRANCH_PRED, fallthrough)
   var(EXTRA_REPLAY_BUBBLE, 0)
   var(EXTRA_PRED_TAKEN_BUBBLE, 0)
   var(EXTRA_JUMP_BUBBLE, 0)
   var(EXTRA_BRANCH_BUBBLE, 0)
   var(EXTRA_INDIRECT_JUMP_BUBBLE, 0)
   var(EXTRA_NON_PIPELINED_BUBBLE, 1)
   var(EXTRA_TRAP_BUBBLE, 1)
   var(NEXT_PC_STAGE, 0)
   var(FETCH_STAGE, 0)
   var(DECODE_STAGE, 0)
   var(BRANCH_PRED_STAGE, 0)
   var(REG_RD_STAGE, 0)
   var(EXECUTE_STAGE, 0)
   var(RESULT_STAGE, 0)
   var(REG_WR_STAGE, 0)
   var(MEM_WR_STAGE, 0)
   var(LD_RETURN_ALIGN, 1)

   /var(DMEM_STYLE, SRAM)
   var(IMPLEMENT_REG0, 1)
\SV
   // Include WARP-V.
   
   m4_include_lib(['https://raw.githubusercontent.com/stevehoover/warp-v/bc141b721d1c863dc10305d6e3e4ba38a81dd2eb/warp-v.tlv'])

//`default_nettype none

module tt_um_warpv (
    input  wire [7:0] ui_in,    // Dedicated inputs - connected to the input switches
    output wire [7:0] uo_out,   // Dedicated outputs - connected to the 7 segment display
    input  wire [7:0] uio_in,   // IOs: Bidirectional Input path
    output wire [7:0] uio_out,  // IOs: Bidirectional Output path
    output wire [7:0] uio_oe,   // IOs: Bidirectional Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

   wire reset = ! rst_n;
   wire passed, failed;
   wire [31:0] cyc_cnt = 32'd0;  // Used by test bench (default WARP-V Makerchip test bench). Don't actually count. Never fail due to timeout by this mechanism.
\TLV
   /* verilator lint_off UNOPTFLAT */
   m5+warpv_top()
   m5+warpv_makerchip_tb()
   m5+makerchip_pass_fail()

   // Connect IOs.
   *uo_out = {6'b0, *failed, *passed};
   *uio_out = 8'b0;
   *uio_oe = 8'b0;

\SV
endmodule
