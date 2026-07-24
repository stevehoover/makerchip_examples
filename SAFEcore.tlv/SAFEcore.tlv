\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
   
   // SAFEcore dual-accumulator execute slice.
   // Scope per conversation 1 (SC_b0n.pdf, SAFEcore Architectural Reference Manual v0.8.0):
   //   - 12 GPRs: r0-r3 (shared), x0-x3 (AccX), y0-y3 (AccY); value + carried type byte.
   //   - Directive decode: binary vs. unary ([15:12]==[11:8] aliasing) vs. move/ld-st/set-flag escapes (deferred as NOPs).
   //   - Common binary ops 0-10 except Divide (3); common unary ops 0-3.
   //   - Accumulator forward-feed (ax/ay targets 14/15, vv source 14).
   //   - Per-accumulator state flags Z/N/C/V.
   
   var(W, 128)              /// Value width (spec: 128-bit registers, Table 48).
   var(T, 8)                /// Type field width (Table 48, byte 16).
   var(WT, m5_calc(m5_W + m5_T))   /// {type, value} register width.
\SV
   m5_makerchip_module
\TLV
   $reset = *reset;
   
   // Instruction sequencing (test harness for the execute slice).
   $pc[7:0] = $reset ? 8'b0 : >>1$pc + 8'b1;
   
   // Directed test program. Instruction format (Table 47): [31:16] Directive Y, [15:0] Directive X.
   // Directive format (Table 74): [15:12] L, [11:8] R, [7:4] T, [3:0] op.
   $instr[31:0] =
       $pc == 8'd1 ? 32'h4400_4400 :  // X: x0 = inc(r0) = 1           Y: y0 = inc(r0) = 1
       $pc == 8'd2 ? 32'hF410_F410 :  // X: x1 = lv{u8:5} + r0 = 5     Y: y1 = lv{u16:0x1234} + r0 (dual dequeue)
       $pc == 8'd3 ? 32'hF021_F12A :  // X: x2 = lv{u4:0xF} ^ x1 = 0xA Y: y2 = lv{u8:3} - y0 = 2 (dual dequeue)
       $pc == 8'd4 ? 32'h1258_20E4 :  // X: ax = x2 << x0 = 0x14 (FF)  Y: r1 = y1 | y2 = 0x1236
       $pc == 8'd5 ? 32'hF430_E030 :  // X: x3 = vv + x0 = 0x15        Y: y3 = lv{u32:0xEFBEADDE} + r0
       $pc == 8'd6 ? 32'h2270_3161 :  // X: r2 = x3 - x1 = 0x10 (C)    Y: r3 = inc(y2) = 3
       $pc == 8'd7 ? 32'h000E_000E :  // NOP
       $pc == 8'd8 ? 32'h0170_0170 :  // Both: r3 = ... -- dual write: Programming Exception
       $pc == 8'd9 ? 32'hF410_0000 :  // Suppressed (halted): X inc x0; Y lv read at Pad
                     32'h000E_000E;   // NOP (move, deferred)
   
   // ============================================================
   // Directive field extraction (Table 74).
   // ============================================================
   $dir_x[15:0] = $instr[15:0];
   $dir_y[15:0] = $instr[31:16];
   
   $l_x[3:0]  = $dir_x[15:12];
   $r_x[3:0]  = $dir_x[11:8];
   $t_x[3:0]  = $dir_x[7:4];
   $op_x[3:0] = $dir_x[3:0];
   
   $l_y[3:0]  = $dir_y[15:12];
   $r_y[3:0]  = $dir_y[11:8];
   $t_y[3:0]  = $dir_y[7:4];
   $op_y[3:0] = $dir_y[3:0];
   
   // Directive class decode (Figure 23 / Table 74).
   // op == 14: Move (deferred: NOP); op == 15: Load/Store (X) / Set Flag (Y) (deferred: NOP).
   // Otherwise, L == R aliases to a unary directive; else binary.
   $escape_x = $op_x[3:1] == 3'b111;   // Move or Load/Store: NOP in this slice.
   $reserved_x = $dir_x[15:8] == 8'hFF;   // RESERVED row of Table 74: NOP.
   $unary_x  = ! $escape_x && ! $reserved_x && ($l_x == $r_x);
   $binary_x = ! $escape_x && ! $reserved_x && ! $unary_x;
   
   $escape_y = $op_y[3:1] == 3'b111;   // Move or Set Flag: NOP in this slice.
   $reserved_y = $dir_y[15:8] == 8'hFF;   // RESERVED row of Table 74: NOP.
   $unary_y  = ! $escape_y && ! $reserved_y && ($l_y == $r_y);
   $binary_y = ! $escape_y && ! $reserved_y && ! $unary_y;
   
   // Implemented operations only (others are NOPs in this slice):
   //   Binary (Table 76): 0 Add, 1 Sub, 2 Mul, 4 LSL, 5 LSR, 6 LSL-fill, 7 ASR; 8 OR, 9 AND, 10 XOR.
   //     (3 Divide, 11 Cast, 12+ accumulator-specific: deferred.)
   //   Unary (Table 79): 0 Inc, 1 Dec, 2 Negate, 3 Complement. (4+ accumulator-specific: deferred.)
   $bin_impl_x = $binary_x && ($op_x != 4'd3) && ($op_x <= 4'd10);
   $un_impl_x  = $unary_x && ($op_x <= 4'd3);
   $exec_x     = $bin_impl_x || $un_impl_x;
   
   $bin_impl_y = $binary_y && ($op_y != 4'd3) && ($op_y <= 4'd10);
   $un_impl_y  = $unary_y && ($op_y <= 4'd3);
   $exec_y     = $bin_impl_y || $un_impl_y;
   
   // ============================================================
   // Literal Vector (LV). Architecturally, an LV is a self-describing byte stream placed
   // in the Transaction after the IV and consumed in reverse byte order. This slice has no
   // Transaction memory, so the LV is modeled as the spec's "Literal Queue": a byte stream
   // in dequeue order. Each tuple is a header type byte followed by its value bytes
   // (LSB first in stream order -- recorded assumption). Supported headers (Table 43):
   // {uX} bit-vectors (bit 7 set; X = [6:0], 0 meaning 128; value = ceil(X/8) bytes,
   // masked to X bits). Header 0xFF is the Pad marking the end of the LV; an lv read at
   // the Pad (or beyond) is a Programming Exception (recorded assumption). Standard 6-bit
   // type headers (bit 7 clear) are deferred: they halt the slice via $unsup_halt.
   // An lv source is dequeued only by an executing binary directive (a unary directive
   // cannot reference lv: L == R == 15 is the RESERVED encoding). When both directives
   // reference lv in one instruction, Directive X dequeues first (recorded assumption).
   // ============================================================
   $lv_rom[383:0] = {224'b0, 160'h00000000_00FF_EFBE_ADDE_A003_88FF_8412_3490_0588};
   
   $use_lv_x = $bin_impl_x && (($l_x == 4'd15) || ($r_x == 4'd15));
   $use_lv_y = $bin_impl_y && (($l_y == 4'd15) || ($r_y == 4'd15));
   
   // Directive X dequeue unit.
   $lv_rdptr_x[5:0] = >>1$lv_ptr;
   $lv_base_x[8:0] = {3'b0, $lv_rdptr_x} * 9'd8;
   $lv_hdr_x[7:0] = $lv_rom[$lv_base_x +: 8];
   $lv_pad_x = $lv_hdr_x == 8'hFF;
   $lv_bits_x[7:0] = ($lv_hdr_x[6:0] == 7'b0) ? 8'd128 : {1'b0, $lv_hdr_x[6:0]};
   $lv_nbyt_x[4:0] = ($lv_bits_x + 8'd7) >> 3;
   $lv_raw_x[m5_calc(m5_W-1):0] = m5_W'b0
      | ((5'd0 < $lv_nbyt_x) ? {120'b0, $lv_rom[$lv_base_x + 9'd8 +: 8]} : m5_W'b0)
      | ((5'd1 < $lv_nbyt_x) ? {112'b0, $lv_rom[$lv_base_x + 9'd16 +: 8], 8'b0} : m5_W'b0)
      | ((5'd2 < $lv_nbyt_x) ? {104'b0, $lv_rom[$lv_base_x + 9'd24 +: 8], 16'b0} : m5_W'b0)
      | ((5'd3 < $lv_nbyt_x) ? {96'b0, $lv_rom[$lv_base_x + 9'd32 +: 8], 24'b0} : m5_W'b0)
      | ((5'd4 < $lv_nbyt_x) ? {88'b0, $lv_rom[$lv_base_x + 9'd40 +: 8], 32'b0} : m5_W'b0)
      | ((5'd5 < $lv_nbyt_x) ? {80'b0, $lv_rom[$lv_base_x + 9'd48 +: 8], 40'b0} : m5_W'b0)
      | ((5'd6 < $lv_nbyt_x) ? {72'b0, $lv_rom[$lv_base_x + 9'd56 +: 8], 48'b0} : m5_W'b0)
      | ((5'd7 < $lv_nbyt_x) ? {64'b0, $lv_rom[$lv_base_x + 9'd64 +: 8], 56'b0} : m5_W'b0)
      | ((5'd8 < $lv_nbyt_x) ? {56'b0, $lv_rom[$lv_base_x + 9'd72 +: 8], 64'b0} : m5_W'b0)
      | ((5'd9 < $lv_nbyt_x) ? {48'b0, $lv_rom[$lv_base_x + 9'd80 +: 8], 72'b0} : m5_W'b0)
      | ((5'd10 < $lv_nbyt_x) ? {40'b0, $lv_rom[$lv_base_x + 9'd88 +: 8], 80'b0} : m5_W'b0)
      | ((5'd11 < $lv_nbyt_x) ? {32'b0, $lv_rom[$lv_base_x + 9'd96 +: 8], 88'b0} : m5_W'b0)
      | ((5'd12 < $lv_nbyt_x) ? {24'b0, $lv_rom[$lv_base_x + 9'd104 +: 8], 96'b0} : m5_W'b0)
      | ((5'd13 < $lv_nbyt_x) ? {16'b0, $lv_rom[$lv_base_x + 9'd112 +: 8], 104'b0} : m5_W'b0)
      | ((5'd14 < $lv_nbyt_x) ? {8'b0, $lv_rom[$lv_base_x + 9'd120 +: 8], 112'b0} : m5_W'b0)
      | ((5'd15 < $lv_nbyt_x) ? {$lv_rom[$lv_base_x + 9'd128 +: 8], 120'b0} : m5_W'b0);
   $lv_val_x[m5_calc(m5_W-1):0] = $lv_raw_x & ~ ({m5_W{1'b1}} << $lv_bits_x);
   $lv_full_x[m5_calc(m5_WT-1):0] = {$lv_hdr_x, $lv_val_x};
   
   // Directive Y dequeue unit (chained after X's dequeue, if any).
   $lv_rdptr_y[5:0] = $use_lv_x ? >>1$lv_ptr + 6'd1 + {1'b0, $lv_nbyt_x} : >>1$lv_ptr;
   $lv_base_y[8:0] = {3'b0, $lv_rdptr_y} * 9'd8;
   $lv_hdr_y[7:0] = $lv_rom[$lv_base_y +: 8];
   $lv_pad_y = $lv_hdr_y == 8'hFF;
   $lv_bits_y[7:0] = ($lv_hdr_y[6:0] == 7'b0) ? 8'd128 : {1'b0, $lv_hdr_y[6:0]};
   $lv_nbyt_y[4:0] = ($lv_bits_y + 8'd7) >> 3;
   $lv_raw_y[m5_calc(m5_W-1):0] = m5_W'b0
      | ((5'd0 < $lv_nbyt_y) ? {120'b0, $lv_rom[$lv_base_y + 9'd8 +: 8]} : m5_W'b0)
      | ((5'd1 < $lv_nbyt_y) ? {112'b0, $lv_rom[$lv_base_y + 9'd16 +: 8], 8'b0} : m5_W'b0)
      | ((5'd2 < $lv_nbyt_y) ? {104'b0, $lv_rom[$lv_base_y + 9'd24 +: 8], 16'b0} : m5_W'b0)
      | ((5'd3 < $lv_nbyt_y) ? {96'b0, $lv_rom[$lv_base_y + 9'd32 +: 8], 24'b0} : m5_W'b0)
      | ((5'd4 < $lv_nbyt_y) ? {88'b0, $lv_rom[$lv_base_y + 9'd40 +: 8], 32'b0} : m5_W'b0)
      | ((5'd5 < $lv_nbyt_y) ? {80'b0, $lv_rom[$lv_base_y + 9'd48 +: 8], 40'b0} : m5_W'b0)
      | ((5'd6 < $lv_nbyt_y) ? {72'b0, $lv_rom[$lv_base_y + 9'd56 +: 8], 48'b0} : m5_W'b0)
      | ((5'd7 < $lv_nbyt_y) ? {64'b0, $lv_rom[$lv_base_y + 9'd64 +: 8], 56'b0} : m5_W'b0)
      | ((5'd8 < $lv_nbyt_y) ? {56'b0, $lv_rom[$lv_base_y + 9'd72 +: 8], 64'b0} : m5_W'b0)
      | ((5'd9 < $lv_nbyt_y) ? {48'b0, $lv_rom[$lv_base_y + 9'd80 +: 8], 72'b0} : m5_W'b0)
      | ((5'd10 < $lv_nbyt_y) ? {40'b0, $lv_rom[$lv_base_y + 9'd88 +: 8], 80'b0} : m5_W'b0)
      | ((5'd11 < $lv_nbyt_y) ? {32'b0, $lv_rom[$lv_base_y + 9'd96 +: 8], 88'b0} : m5_W'b0)
      | ((5'd12 < $lv_nbyt_y) ? {24'b0, $lv_rom[$lv_base_y + 9'd104 +: 8], 96'b0} : m5_W'b0)
      | ((5'd13 < $lv_nbyt_y) ? {16'b0, $lv_rom[$lv_base_y + 9'd112 +: 8], 104'b0} : m5_W'b0)
      | ((5'd14 < $lv_nbyt_y) ? {8'b0, $lv_rom[$lv_base_y + 9'd120 +: 8], 112'b0} : m5_W'b0)
      | ((5'd15 < $lv_nbyt_y) ? {$lv_rom[$lv_base_y + 9'd128 +: 8], 120'b0} : m5_W'b0);
   $lv_val_y[m5_calc(m5_W-1):0] = $lv_raw_y & ~ ({m5_W{1'b1}} << $lv_bits_y);
   $lv_full_y[m5_calc(m5_WT-1):0] = {$lv_hdr_y, $lv_val_y};
   
   // Exceptions and pointer state.
   $lv_exc = ($use_lv_x && $lv_pad_x) || ($use_lv_y && $lv_pad_y);
   $lv_unsup = ($use_lv_x && ! $lv_pad_x && ! $lv_hdr_x[7]) || ($use_lv_y && ! $lv_pad_y && ! $lv_hdr_y[7]);
   $unsup_halt = ! $reset && (>>1$unsup_halt || $lv_unsup);   // Slice limitation, not architectural.
   $lv_ptr[5:0] = $reset ? 6'b0
                : $halt ? >>1$lv_ptr
                : $use_lv_y ? $lv_rdptr_y + 6'd1 + {1'b0, $lv_nbyt_y}
                :            $lv_rdptr_y;
   
   // ============================================================
   // Source reads (Tables 50-55). GPR indices: 0-3 = r0-r3, 4-7 = x0-x3, 8-11 = y0-y3.
   //   enc[3:2] == 01: shared rN.  enc[3:2] == 00: accumulator-specific xN/yN.
   //   enc == 14: vv (forward-feed; wired in a later step).  Others (queues, lv): deferred, read as 0.
   // ============================================================
   $src_l_x[m5_calc(m5_WT-1):0] =
        $l_x[3:2] == 2'b01 ? ($l_x[1:0] == 2'd0 ? >>1$rf_r0 : $l_x[1:0] == 2'd1 ? >>1$rf_r1 : $l_x[1:0] == 2'd2 ? >>1$rf_r2 : >>1$rf_r3)
      : $l_x[3:2] == 2'b00 ? ($l_x[1:0] == 2'd0 ? >>1$rf_x0 : $l_x[1:0] == 2'd1 ? >>1$rf_x1 : $l_x[1:0] == 2'd2 ? >>1$rf_x2 : >>1$rf_x3)
      : $l_x == 4'd15 ? $lv_full_x
      : $l_x == 4'd14 ? $vv_x
      : m5_WT'b0;
   $src_r_x[m5_calc(m5_WT-1):0] =
        $r_x[3:2] == 2'b01 ? ($r_x[1:0] == 2'd0 ? >>1$rf_r0 : $r_x[1:0] == 2'd1 ? >>1$rf_r1 : $r_x[1:0] == 2'd2 ? >>1$rf_r2 : >>1$rf_r3)
      : $r_x[3:2] == 2'b00 ? ($r_x[1:0] == 2'd0 ? >>1$rf_x0 : $r_x[1:0] == 2'd1 ? >>1$rf_x1 : $r_x[1:0] == 2'd2 ? >>1$rf_x2 : >>1$rf_x3)
      : $r_x == 4'd15 ? $lv_full_x
      : $r_x == 4'd14 ? $vv_x
      : m5_WT'b0;
   $src_l_y[m5_calc(m5_WT-1):0] =
        $l_y[3:2] == 2'b01 ? ($l_y[1:0] == 2'd0 ? >>1$rf_r0 : $l_y[1:0] == 2'd1 ? >>1$rf_r1 : $l_y[1:0] == 2'd2 ? >>1$rf_r2 : >>1$rf_r3)
      : $l_y[3:2] == 2'b00 ? ($l_y[1:0] == 2'd0 ? >>1$rf_y0 : $l_y[1:0] == 2'd1 ? >>1$rf_y1 : $l_y[1:0] == 2'd2 ? >>1$rf_y2 : >>1$rf_y3)
      : $l_y == 4'd15 ? $lv_full_y
      : $l_y == 4'd14 ? $vv_y
      : m5_WT'b0;
   $src_r_y[m5_calc(m5_WT-1):0] =
        $r_y[3:2] == 2'b01 ? ($r_y[1:0] == 2'd0 ? >>1$rf_r0 : $r_y[1:0] == 2'd1 ? >>1$rf_r1 : $r_y[1:0] == 2'd2 ? >>1$rf_r2 : >>1$rf_r3)
      : $r_y[3:2] == 2'b00 ? ($r_y[1:0] == 2'd0 ? >>1$rf_y0 : $r_y[1:0] == 2'd1 ? >>1$rf_y1 : $r_y[1:0] == 2'd2 ? >>1$rf_y2 : >>1$rf_y3)
      : $r_y == 4'd15 ? $lv_full_y
      : $r_y == 4'd14 ? $vv_y
      : m5_WT'b0;
   
   // Value and type components. For unary directives, the operand is the R source.
   $lval_x[m5_calc(m5_W-1):0] = $src_l_x[m5_calc(m5_W-1):0];
   $rval_x[m5_calc(m5_W-1):0] = $src_r_x[m5_calc(m5_W-1):0];
   $ltype_x[m5_calc(m5_T-1):0] = $src_l_x[m5_calc(m5_WT-1):m5_W];
   $rtype_x[m5_calc(m5_T-1):0] = $src_r_x[m5_calc(m5_WT-1):m5_W];
   
   $lval_y[m5_calc(m5_W-1):0] = $src_l_y[m5_calc(m5_W-1):0];
   $rval_y[m5_calc(m5_W-1):0] = $src_r_y[m5_calc(m5_W-1):0];
   $ltype_y[m5_calc(m5_T-1):0] = $src_l_y[m5_calc(m5_WT-1):m5_W];
   $rtype_y[m5_calc(m5_T-1):0] = $src_r_y[m5_calc(m5_WT-1):m5_W];
   
   // ============================================================
   // ALU (one per directive).
   // ============================================================
   // Add/Subtract with carry-out (C) and signed overflow (V).
   $is_sub_x = $op_x == 4'd1;
   {$carry_x, $sum_x[m5_calc(m5_W-1):0]} = $is_sub_x ? ({1'b0, $lval_x} + {1'b0, ~ $rval_x} + m5_calc(m5_W+1)'b1)
                                                     : ({1'b0, $lval_x} + {1'b0, $rval_x});
   $ovfl_x = $is_sub_x ? (($lval_x[m5_calc(m5_W-1)] != $rval_x[m5_calc(m5_W-1)]) && ($sum_x[m5_calc(m5_W-1)] != $lval_x[m5_calc(m5_W-1)]))
                       : (($lval_x[m5_calc(m5_W-1)] == $rval_x[m5_calc(m5_W-1)]) && ($sum_x[m5_calc(m5_W-1)] != $lval_x[m5_calc(m5_W-1)]));
   
   $is_sub_y = $op_y == 4'd1;
   {$carry_y, $sum_y[m5_calc(m5_W-1):0]} = $is_sub_y ? ({1'b0, $lval_y} + {1'b0, ~ $rval_y} + m5_calc(m5_W+1)'b1)
                                                     : ({1'b0, $lval_y} + {1'b0, $rval_y});
   $ovfl_y = $is_sub_y ? (($lval_y[m5_calc(m5_W-1)] != $rval_y[m5_calc(m5_W-1)]) && ($sum_y[m5_calc(m5_W-1)] != $lval_y[m5_calc(m5_W-1)]))
                       : (($lval_y[m5_calc(m5_W-1)] == $rval_y[m5_calc(m5_W-1)]) && ($sum_y[m5_calc(m5_W-1)] != $lval_y[m5_calc(m5_W-1)]));
   
   // Shifts (ops 4-7). R is cast to a signed scalar; a negative amount is complemented and the
   // direction reversed (Table 76; see tracking notes on interpretation). Amounts >= 256
   // (rotate / instance-shift semantics) are deferred. Effective kinds: 0 LSL, 1 LSR, 2 LSL-fill, 3 ASR.
   $shamt_neg_x = $rval_x[m5_calc(m5_W-1)];
   $shamt_x[7:0] = $shamt_neg_x ? ~ $rval_x[7:0] : $rval_x[7:0];
   $shkind_x[1:0] = ! $shamt_neg_x ? $op_x[1:0]
                  : $op_x[1:0] == 2'd0 ? 2'd3   // LSL, neg -> ASR
                  : $op_x[1:0] == 2'd1 ? 2'd0   // LSR, neg -> (arithmetic) left shift
                  : $op_x[1:0] == 2'd2 ? 2'd3   // LSL-fill, neg -> right shift w/ extend
                  :                      2'd2;  // ASR, neg -> left shift w/ fill
   $shres_x[m5_calc(m5_W-1):0] =
        $shkind_x == 2'd0 ? $lval_x << $shamt_x
      : $shkind_x == 2'd1 ? $lval_x >> $shamt_x
      : $shkind_x == 2'd2 ? ($lval_x[0] ? ~ (~ $lval_x << $shamt_x) : $lval_x << $shamt_x)
      :                     ($lval_x[m5_calc(m5_W-1)] ? ~ (~ $lval_x >> $shamt_x) : $lval_x >> $shamt_x);
   
   $shamt_neg_y = $rval_y[m5_calc(m5_W-1)];
   $shamt_y[7:0] = $shamt_neg_y ? ~ $rval_y[7:0] : $rval_y[7:0];
   $shkind_y[1:0] = ! $shamt_neg_y ? $op_y[1:0]
                  : $op_y[1:0] == 2'd0 ? 2'd3
                  : $op_y[1:0] == 2'd1 ? 2'd0
                  : $op_y[1:0] == 2'd2 ? 2'd3
                  :                      2'd2;
   $shres_y[m5_calc(m5_W-1):0] =
        $shkind_y == 2'd0 ? $lval_y << $shamt_y
      : $shkind_y == 2'd1 ? $lval_y >> $shamt_y
      : $shkind_y == 2'd2 ? ($lval_y[0] ? ~ (~ $lval_y << $shamt_y) : $lval_y << $shamt_y)
      :                     ($lval_y[m5_calc(m5_W-1)] ? ~ (~ $lval_y >> $shamt_y) : $lval_y >> $shamt_y);
   
   // Result. Unary (Table 79): 0 Inc, 1 Dec, 2 Negate, 3 Complement, all on the R source.
   $result_x[m5_calc(m5_W-1):0] =
        $un_impl_x ? ( $op_x == 4'd0 ? $rval_x + m5_W'b1
                     : $op_x == 4'd1 ? $rval_x - m5_W'b1
                     : $op_x == 4'd2 ? m5_W'b0 - $rval_x
                     :                 ~ $rval_x)
      : ($op_x == 4'd0) || ($op_x == 4'd1) ? $sum_x
      : $op_x == 4'd2 ? $lval_x * $rval_x
      : $op_x[3:2] == 2'b01 ? $shres_x
      : $op_x == 4'd8 ? $lval_x | $rval_x
      : $op_x == 4'd9 ? $lval_x & $rval_x
      :                 $lval_x ^ $rval_x;
   $result_y[m5_calc(m5_W-1):0] =
        $un_impl_y ? ( $op_y == 4'd0 ? $rval_y + m5_W'b1
                     : $op_y == 4'd1 ? $rval_y - m5_W'b1
                     : $op_y == 4'd2 ? m5_W'b0 - $rval_y
                     :                 ~ $rval_y)
      : ($op_y == 4'd0) || ($op_y == 4'd1) ? $sum_y
      : $op_y == 4'd2 ? $lval_y * $rval_y
      : $op_y[3:2] == 2'b01 ? $shres_y
      : $op_y == 4'd8 ? $lval_y | $rval_y
      : $op_y == 4'd9 ? $lval_y & $rval_y
      :                 $lval_y ^ $rval_y;
   
   // Result type: L's type for binary, R's type for unary (see tracking notes).
   $res_type_x[m5_calc(m5_T-1):0] = $un_impl_x ? $rtype_x : $ltype_x;
   $res_type_y[m5_calc(m5_T-1):0] = $un_impl_y ? $rtype_y : $ltype_y;
   
   $res_full_x[m5_calc(m5_WT-1):0] = {$res_type_x, $result_x};
   $res_full_y[m5_calc(m5_WT-1):0] = {$res_type_y, $result_y};
   
   // ============================================================
   // Write-back (Tables 56-61). Target enc[3:2] == 00: xN/yN; == 01: rN;
   //   14/15: forward-feed (later step); 8-13 (queues): deferred, write dropped.
   // GPR index space: 0-3 = rN, 4-7 = xN, 8-11 = yN.
   // ============================================================
   $wr_gpr_x = $exec_x && ! $t_x[3] && ! $halt;
   $wr_idx_x[3:0] = $t_x[2] ? {2'b00, $t_x[1:0]} : {2'b01, $t_x[1:0]};
   $wr_gpr_y = $exec_y && ! $t_y[3] && ! $halt;
   $wr_idx_y[3:0] = $t_y[2] ? {2'b00, $t_y[1:0]} : {2'b10, $t_y[1:0]};
   
   // ============================================================
   // Programming Exception (architect guidance): execution is synchronous, so both
   // directives targeting the same register in one cycle is an obvious error. It raises
   // a Programming Exception, which architecturally terminates the associated Thread.
   // This slice has no Thread/Strand context, so the exception halts the slice: the
   // offending instruction is fully suppressed (both directives) and all state freezes.
   // The same rule is applied to both directives loading the same forward-feed register
   // in one cycle (extrapolation from the same principle; flagged for review).
   // ============================================================
   $collide_gpr = $exec_x && $exec_y && ! $t_x[3] && ! $t_y[3]
                  && (($t_x[2] ? {2'b00, $t_x[1:0]} : {2'b01, $t_x[1:0]})
                      == ($t_y[2] ? {2'b00, $t_y[1:0]} : {2'b10, $t_y[1:0]}));
   $collide_ff = $exec_x && $exec_y && ($t_x[3:1] == 3'b111) && ($t_x == $t_y);
   $prog_exc = ! $reset && (>>1$prog_exc || $collide_gpr || $collide_ff || $lv_exc);
   $halt = $prog_exc || $unsup_halt;   // The exception cycle itself is suppressed.
   
   $rf_r0[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd0))  ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd0))  ? $res_full_x : >>1$rf_r0;
   $rf_r1[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd1))  ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd1))  ? $res_full_x : >>1$rf_r1;
   $rf_r2[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd2))  ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd2))  ? $res_full_x : >>1$rf_r2;
   $rf_r3[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd3))  ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd3))  ? $res_full_x : >>1$rf_r3;
   $rf_x0[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd4))  ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd4))  ? $res_full_x : >>1$rf_x0;
   $rf_x1[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd5))  ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd5))  ? $res_full_x : >>1$rf_x1;
   $rf_x2[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd6))  ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd6))  ? $res_full_x : >>1$rf_x2;
   $rf_x3[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd7))  ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd7))  ? $res_full_x : >>1$rf_x3;
   $rf_y0[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd8))  ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd8))  ? $res_full_x : >>1$rf_y0;
   $rf_y1[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd9))  ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd9))  ? $res_full_x : >>1$rf_y1;
   $rf_y2[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd10)) ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd10)) ? $res_full_x : >>1$rf_y2;
   $rf_y3[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($wr_gpr_y && ($wr_idx_y == 4'd11)) ? $res_full_y : ($wr_gpr_x && ($wr_idx_x == 4'd11)) ? $res_full_x : >>1$rf_y3;
   
   // ============================================================
   // Forward-feed (Table 57). Target 14 loads AccX's forward-feed register; target 15
   // loads AccY's (either directive can load either). Source vv (14) in an accumulator's
   // directive reads that accumulator's forward-feed register if its flag is set, clearing
   // the flag (Tables 53/55); otherwise the deferred queue-tag behavior reads as 0.
   // A load takes effect the next cycle ("used any time after it has been loaded");
   // a load overwrites and re-arms even if consumed in the same cycle.
   // Sequence-boundary clearing is deferred (no Sequence context in this slice).
   // ============================================================
   $ld_ffx = ! $halt && ($exec_y && ($t_y == 4'd14)) || ($exec_x && ($t_x == 4'd14));
   $ld_ffy = ! $halt && ($exec_y && ($t_y == 4'd15)) || ($exec_x && ($t_x == 4'd15));
   
   // vv is consumed if it is a used source of an executing directive (R always; L only for binary).
   $use_vv_x = ! $halt && $exec_x && (($bin_impl_x && ($l_x == 4'd14)) || ($r_x == 4'd14));
   $use_vv_y = ! $halt && $exec_y && (($bin_impl_y && ($l_y == 4'd14)) || ($r_y == 4'd14));
   
   $vv_x[m5_calc(m5_WT-1):0] = >>1$ffx_act ? >>1$ffx : m5_WT'b0;
   $vv_y[m5_calc(m5_WT-1):0] = >>1$ffy_act ? >>1$ffy : m5_WT'b0;
   
   $ffx[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($ld_ffx && $exec_y && ($t_y == 4'd14)) ? $res_full_y : ($ld_ffx && $exec_x && ($t_x == 4'd14)) ? $res_full_x : >>1$ffx;
   $ffy[m5_calc(m5_WT-1):0] = $reset ? m5_WT'b0 : ($ld_ffy && $exec_y && ($t_y == 4'd15)) ? $res_full_y : ($ld_ffy && $exec_x && ($t_x == 4'd15)) ? $res_full_x : >>1$ffy;
   $ffx_act = $reset ? 1'b0 : $ld_ffx ? 1'b1 : $use_vv_x ? 1'b0 : >>1$ffx_act;
   $ffy_act = $reset ? 1'b0 : $ld_ffy ? 1'b1 : $use_vv_y ? 1'b0 : >>1$ffy_act;
   
   // ============================================================
   // Accumulator state flags Z/N/C/V (Section 6.2): most-recent-directive metadata,
   // updated by each executing operational directive of the respective accumulator.
   // C/V are meaningful for Add/Subtract; other operations clear them (recorded assumption).
   // ============================================================
   $upd_cv_x = $bin_impl_x && ($op_x <= 4'd1);
   $flags_x[3:0] = $reset ? 4'b0
                 : ($exec_x && ! $halt) ? { $upd_cv_x && $ovfl_x,            // [3] V
                               $upd_cv_x && $carry_x,           // [2] C
                               $result_x[m5_calc(m5_W-1)],      // [1] N
                               $result_x == m5_W'b0 }           // [0] Z
                 : >>1$flags_x;
   $upd_cv_y = $bin_impl_y && ($op_y <= 4'd1);
   $flags_y[3:0] = $reset ? 4'b0
                 : ($exec_y && ! $halt) ? { $upd_cv_y && $ovfl_y,
                               $upd_cv_y && $carry_y,
                               $result_y[m5_calc(m5_W-1)],
                               $result_y == m5_W'b0 }
                 : >>1$flags_y;
   
   // ============================================================
   // Self-check (test harness). Checkpoint A (pc==8): state after the literal-driven
   // program (pc 1-7), all five LV tuples dequeued (lv_ptr at the Pad), no exception.
   // Checkpoint B (pc==11): the pc==8 dual-write of r3 raised the Programming Exception
   // and all state has frozen (pc 8-10 have no architectural effect).
   // ============================================================
   $ckpt_a_ok = ! >>1$prog_exc && ! >>1$unsup_halt
      && (>>1$rf_r0 == m5_WT'b0)
      && (>>1$rf_r1 == {8'h90, 128'h1236})
      && (>>1$rf_r2 == {8'h84, 128'h10})
      && (>>1$rf_r3 == {8'h88, 128'd3})
      && (>>1$rf_x0 == m5_WT'd1)
      && (>>1$rf_x1 == {8'h88, 128'd5})
      && (>>1$rf_x2 == {8'h84, 128'hA})
      && (>>1$rf_x3 == {8'h84, 128'h15})
      && (>>1$rf_y0 == m5_WT'd1)
      && (>>1$rf_y1 == {8'h90, 128'h1234})
      && (>>1$rf_y2 == {8'h88, 128'd2})
      && (>>1$rf_y3 == {8'hA0, 128'hEFBEADDE})
      && (! >>1$ffx_act) && (! >>1$ffy_act)
      && (>>1$lv_ptr == 6'd14)
      && (>>1$flags_x == 4'b0100) && (>>1$flags_y == 4'b0000);
   $ckpt_a = $reset ? 1'b0 : ($pc == 8'd8) ? $ckpt_a_ok : >>1$ckpt_a;
   
   $ckpt_b_ok = >>1$prog_exc && ! >>1$unsup_halt
      && (>>1$rf_r3 == {8'h88, 128'd3})
      && (>>1$rf_x0 == m5_WT'd1)
      && (>>1$lv_ptr == 6'd14)
      && (>>1$flags_x == 4'b0100);
   $ckpt_b = $reset ? 1'b0 : ($pc == 8'd11) ? $ckpt_b_ok : >>1$ckpt_b;
   
   $done = $pc == 8'd12;
   *passed = $done && $ckpt_a && $ckpt_b;
   *failed = $done && ! ($ckpt_a && $ckpt_b);
   
   // ============================================================
   // Visual Debug.
   // ============================================================
   \viz_js
      box: {left: 0, top: 0, width: 760, height: 560, strokeWidth: 1, stroke: "gray", fill: "#FDFDF8"},
      init() {
         let ret = {}
         ret.title = new fabric.Text("SAFEcore Dual-Accumulator Execute Slice", {
            left: 380, top: 10, originX: "center", fontSize: 18, fontFamily: "roboto", fill: "black"})
         ret.instr = new fabric.Text("", {
            left: 380, top: 36, originX: "center", fontSize: 14, fontFamily: "roboto mono", fill: "black"})
         // Per-accumulator panels (X left, Y right).
         let panel = (pfx, left, label) => {
            ret[pfx + "_hdr"] = new fabric.Text(label, {
               left: left + 110, top: 66, originX: "center", fontSize: 16, fontFamily: "roboto", fill: "black"})
            ret[pfx + "_dir"] = new fabric.Text("", {
               left: left, top: 90, fontSize: 13, fontFamily: "roboto mono", fill: "black"})
            ret[pfx + "_res"] = new fabric.Text("", {
               left: left, top: 130, fontSize: 13, fontFamily: "roboto mono", fill: "black"})
            ret[pfx + "_flags"] = new fabric.Text("", {
               left: left, top: 170, fontSize: 14, fontFamily: "roboto mono", fill: "black"})
            ret[pfx + "_ff_box"] = new fabric.Rect({
               left: left, top: 200, width: 220, height: 40, fill: "white", stroke: "gray", strokeWidth: 1})
            ret[pfx + "_ff"] = new fabric.Text("", {
               left: left + 8, top: 210, fontSize: 13, fontFamily: "roboto mono", fill: "black"})
         }
         panel("x", 20, "Accumulator X")
         panel("y", 520, "Accumulator Y")
         // GPR file: 12 rows, grouped r / x / y.
         ret.gpr_hdr = new fabric.Text("GPRs", {
            left: 380, top: 66, originX: "center", fontSize: 16, fontFamily: "roboto", fill: "black"})
         for (let i = 0; i < 12; i++) {
            let top = 90 + i * 30 + Math.floor(i / 4) * 10
            ret["gpr_box_" + i] = new fabric.Rect({
               left: 270, top: top, width: 220, height: 26, fill: "white", stroke: "gray", strokeWidth: 1})
            ret["gpr_" + i] = new fabric.Text("", {
               left: 278, top: top + 5, fontSize: 13, fontFamily: "roboto mono", fill: "black"})
         }
         ret.note = new fabric.Text("", {
            left: 380, top: 520, originX: "center", fontSize: 13, fontFamily: "roboto", fill: "black"})
         ret.lv_box = new fabric.Rect({
            left: 20, top: 255, width: 720, height: 60, fill: "white", stroke: "gray", strokeWidth: 1})
         ret.lv_txt = new fabric.Text("", {
            left: 28, top: 262, fontSize: 13, fontFamily: "roboto mono", fill: "black"})
         ret.exc = new fabric.Text("", {
            left: 380, top: 490, originX: "center", fontSize: 16, fontFamily: "roboto", fill: "red"})
         return ret
      },
      render() {
         let objs = this.obj
         const gprNames = ["r0", "r1", "r2", "r3", "x0", "x1", "x2", "x3", "y0", "y1", "y2", "y3"]
         const binOps = ["Add", "Subtract", "Multiply", "Divide", "LSL", "LSR", "LSL-fill", "ASR",
                         "OR", "AND", "XOR", "Cast", "AccOp12", "AccOp13", "?", "?"]
         const unOps = ["Increment", "Decrement", "Negate", "Complement"]
         let trim = (hex) => {
            let v = hex.replace(/^0+/, "")
            return v == "" ? "0" : v
         }
         let srcName = (enc, acc) => {
            if (enc < 4) return acc + enc
            if (enc < 8) return "r" + (enc - 4)
            if (enc < 12) return "i" + (enc - 8)
            return ["mi", "ld", "vv", "lv"][enc - 12]
         }
         let tgtName = (enc, acc) => {
            if (enc < 4) return acc + enc
            if (enc < 8) return "r" + (enc - 4)
            if (enc < 12) return "o" + (enc - 8)
            return ["mo", "st", "ax", "ay"][enc - 12]
         }
         objs.instr.set({text: "pc=" + '$pc'.asInt() + "  instr=0x" + '$instr'.asHexStr()})
         let side = (pfx, acc, l, r, t, op, exec, unary, escape, result, flags, ff, ffAct, useVv, ldFf) => {
            let dirTxt, resTxt
            if (escape) {
               dirTxt = "escape (op " + op + "): NOP in slice"
               resTxt = ""
            } else if (unary) {
               dirTxt = tgtName(t, acc) + " = " + (op < 4 ? unOps[op] : "AccUnary" + op) + "(" + srcName(r, acc) + ")"
               resTxt = exec ? "result: 0x" + trim(result) : "(deferred op: NOP)"
            } else {
               dirTxt = tgtName(t, acc) + " = " + srcName(l, acc) + " " + binOps[op] + " " + srcName(r, acc)
               resTxt = exec ? "result: 0x" + trim(result) : "(deferred op: NOP)"
            }
            objs[pfx + "_dir"].set({text: dirTxt, fill: exec ? "black" : "gray"})
            objs[pfx + "_res"].set({text: resTxt, fill: exec ? "darkgreen" : "gray"})
            objs[pfx + "_flags"].set({text: "flags: " +
               (flags & 8 ? "V" : "-") + (flags & 4 ? "C" : "-") +
               (flags & 2 ? "N" : "-") + (flags & 1 ? "Z" : "-")})
            objs[pfx + "_ff_box"].set({fill: ffAct ? "#FFF3C0" : "white",
               stroke: ldFf ? "green" : useVv ? "blue" : "gray", strokeWidth: (ldFf || useVv) ? 2 : 1})
            objs[pfx + "_ff"].set({text: "fwd-feed (" + (pfx == "x" ? "ax" : "ay") + "): " +
               (ffAct ? "0x" + trim(ff) : "inactive") +
               (ldFf ? "  <load" : "") + (useVv ? "  >vv" : "")})
         }
         side("x", "x", '$l_x'.asInt(), '$r_x'.asInt(), '$t_x'.asInt(), '$op_x'.asInt(),
              '$exec_x'.asBool(), '$unary_x'.asBool(), '$escape_x'.asBool(),
              '$result_x'.asHexStr(), '$flags_x'.asInt(), '$ffx'.asHexStr(), '>>1$ffx_act'.asBool(),
              '$use_vv_x'.asBool(), '$ld_ffx'.asBool())
         side("y", "y", '$l_y'.asInt(), '$r_y'.asInt(), '$t_y'.asInt(), '$op_y'.asInt(),
              '$exec_y'.asBool(), '$unary_y'.asBool(), '$escape_y'.asBool(),
              '$result_y'.asHexStr(), '$flags_y'.asInt(), '$ffy'.asHexStr(), '>>1$ffy_act'.asBool(),
              '$use_vv_y'.asBool(), '$ld_ffy'.asBool())
         const gprSigs = [ '$rf_r0', '$rf_r1', '$rf_r2', '$rf_r3',
                           '$rf_x0', '$rf_x1', '$rf_x2', '$rf_x3',
                           '$rf_y0', '$rf_y1', '$rf_y2', '$rf_y3' ]
         let wrX = '$wr_gpr_x'.asBool() ? '$wr_idx_x'.asInt() : -1
         let wrY = '$wr_gpr_y'.asBool() ? '$wr_idx_y'.asInt() : -1
         for (let i = 0; i < 12; i++) {
            let hex = gprSigs[i].asHexStr()
            let type = hex.substr(0, 2)
            let val = trim(hex.substr(2))
            let fill = (i == wrY) ? "#C8E4FF" : (i == wrX) ? "#C8FFC8" : "white"
            objs["gpr_box_" + i].set({fill: fill})
            objs["gpr_" + i].set({text: gprNames[i] + "  t:" + type + "  0x" + val})
         }
         let lvPtr = '$lv_rdptr_x'.asInt()
         let lvHdr = '$lv_hdr_x'.asInt()
         let lvNext
         if (lvHdr == 255) {
            lvNext = "Pad (end of LV)"
         } else if (lvHdr >= 128) {
            let bits = '$lv_bits_x'.asInt()
            lvNext = "{u" + bits + "} = 0x" + trim('$lv_val_x'.asHexStr())
         } else {
            lvNext = "hdr 0x" + '$lv_hdr_x'.asHexStr() + " (standard type: unsupported in slice)"
         }
         let dqX = '$use_lv_x'.asBool()
         let dqY = '$use_lv_y'.asBool()
         objs.lv_box.set({stroke: (dqX || dqY) ? "blue" : "gray", strokeWidth: (dqX || dqY) ? 2 : 1})
         objs.lv_txt.set({text: "Literal Vector (queue order)  ptr=" + lvPtr + "  next: " + lvNext +
            "\ndequeue this cycle:" + (dqX ? " X" : "") + (dqY ? " Y" : "") + ((dqX || dqY) ? "" : " none")})
         let exc = '$prog_exc'.asBool()
         let uns = '$unsup_halt'.asBool()
         objs.exc.set({text: exc ? "PROGRAMMING EXCEPTION - Thread terminated (slice halted)"
                           : uns ? "Unsupported LV header - slice halted" : ""})
         objs.note.set({text: "green: X write   blue: Y write   yellow: forward-feed active"})
         return []
      }
\SV
   endmodule
