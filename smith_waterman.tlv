\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV
/*
BSD 3-Clause License

Copyright (c) 2022, Yeshu Jain

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice,
  this list of conditions and the following disclaimer in the documentation
  and/or other materials provided with the distribution.

* Neither the name of the copyright holder nor the names of its
  contributors may be used to endorse or promote products derived from
  this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

// TODO: This version of the Smith-Waterman kernel runs in Makerchip, but was not kept in sync w/ the overall 1st-CLaaS project.
//       The two must be merged and tested.
m4_include_lib(['https://raw.githubusercontent.com/TL-X-org/tlv_lib/3543cfd9d7ef9ae3b1e5750614583959a672084d/fundamentals_lib.tlv'])

\m5
  // Model parameters. (TODO: By newer conventions, these should be lower-case.)
  vars(
    SCORE_WIDTH, 20,
    N_SIZE, 2,
    ALPHA, 2,
    BETA, 2,
    DIAG_INC, 3,    /// Score increment along diagonal for matches
    DIAG_DEC, 3,    /// Score decrement along diagonal for mismatches
    /// Back arrow encoding:
    BACK_BELOW_MAX, 0,   /// Special back arrow value indicating that the cell *above* has a max-value (and this cell will not be along backtrack)
    BACK_LEFT, 1,   /// Back-arrow from left
    BACK_ABOVE, 2,  /// Back-arrow from above
    BACK_DIAG, 3)   /// Back-arrow along diagonal,
  define_hier(PE, 10)
  // VIZ parameters.
  vars(
    DETAILS_VISIBLE, false,   /// Show VIZ details (0-present/1-debug)
    FUTURE_OPACITY, 0.3,  /// Opacity of information from the future (nominal value 0.3)
    PAST_FADE, 0.3)   /// Amount to fade the past (nominal value 0.3)

  // Testbench parameters.
  vars(
    SEED, 16,   /// Seed for random
    S_GENOME, CTAGCATCAT,   /// S Genome (Wikipedia: TGTTACGG (8 PEs), Tag-a-Cat: CTAGCATCAT (10 PEs))
    T_GENOME, TAGACATGCG)   /// T Genome (Wikipedia: GGTTGACT (8 PEs), Tag-a-Cat: TAGACATGCG (10 PEs))

  // Computed parameters.
  vars(
    SCORE_RANGE, m5_calc(m5_SCORE_WIDTH-1):0,
    N_RANGE, m5_calc(m5_N_SIZE-1):0)

\SV
// The algorithm works in three phases. In each phase, the full matrix is processed, where in
//   each cycle the PEs are processing an anti-diagonal of the matrix.
// Phase 1: ➡️ Forward propagate max
//          Performs forward propagation of scoring to compute max score for matrix.
// Phase 2: ⏩ Forward propagate arrows
//          Repeats the forward propagation of scoring to retain arrows for the entire matrix
//          and to tag cells containing the max value. A max value shadows all cells to the right
//          and below. These are not marked max-value. This filtering is necessary to correctly
//          identify a single strand in the next phase.
// Phase 3: ⬅️ Backtrack
//          Follow arrows backward, characterizing nucleotide alignment, keeping the characterization of
//          the strand from the right-most unshadowed max-valued cell.
//
// Inputs:
//    /_name
//       |pipe
//          @-1
//             $reset
//             $start  // Asserts for the computation of [0,0].
//             /pe[*]
//                $nucleotide_s[m5_N_RANGE]  // Nucleotide S (/pe[0] gets nucleotide[0])
//             $nucleotide_t[m5_N_RANGE]  // Nucleotide T, shifted in, starting from index 0.

\TLV smith_waterman(/_top, /_name)
   /_name
      |pipe
         
         // =====
         // SHIFT
         // =====
         @-1
            // $count_down:
            
            //    PE_CNT * 6 + 0: forward-max-prop of top-left (start)
            //    PE_CNT * 5 + 1: forward-max-prop of anti-diagonal
            //    PE_CNT * 4 + 2: forward-max-prop of bottom-right corner
            //    PE_CNT * 4 + 1: no computation (just shifting nucleotide)
            //    PE_CNT * 4 + 0: forward-prop of top-left
            //    PE_CNT * 3 + 1: forward-prop of anti-diagonal
            //    PE_CNT * 2 + 2: forward-prop of bottom-right corner
            //    PE_CNT * 2 + 1: no computation (just shifting nucleotide)
            //    PE_CNT * 2 + 0: backtrack of bottom-right corner
            //    PE_CNT * 1 + 1: backtrack of anti-diagonal
            //    PE_CNT * 0 + 2: backtrack of top-left
            //    PE_CNT * 0 + 1: no computation (just shifting nucleotide)
            //    PE_CNT * 0 + 0: all done
            $count_down[m5_PE_INDEX_MAX+3:0] =
                 $reset              ? 0 :
                 $start              ? m5_PE_CNT * 6 + 0 :
                 >>1$count_down == 0 ? 0 :
                                       >>1$count_down - 1;
            $start_again = $count_down == m5_PE_CNT * 4 + 0;
            $start_back  = $count_down == m5_PE_CNT * 2 + 0;
            {$max_prop, $arrow_prop, $backtrack, $active} =
                 |pipe$reset  ? 4'b0000 :
                 |pipe$start  ? 4'b1001 :
                 $start_again ? 4'b0101 :
                 $start_back  ? 4'b0011 :
                 $count_down == 0
                              ? 4'b0000 :
                                {>>1$max_prop, >>1$arrow_prop, >>1$backtrack, >>1$active};
            $forward_prop = $max_prop || $arrow_prop;
            
         @0
            // Capture max after max propagation phase.
            $max[m5_SCORE_RANGE] =
                 ! $active    ? 0 :
                 $start_again ? /pe[m5_PE_MAX]>>2$max :
                                $RETAIN;
            /pe[m5_PE_RANGE]
               $nuc_s[m5_N_RANGE] = |pipe$start ? $nucleotide_s : $RETAIN;  // capture
               $nuc_t[m5_N_RANGE] = |pipe$forward_prop ? /left$nuc_t : |pipe$backtrack ? /cyclic_right$nuc_t : $RETAIN;
               $valid_fwd = |pipe$reset ? 1'b0 : /left$valid_fwd;
               //$valid_max_fwd = $valid_fwd && |pipe$max_prop;
               $valid_arrow_fwd = $valid_fwd && |pipe$arrow_prop;
               
         // =====
         // SCORE
         // =====
         @0
            // Values around all edges.
            /default
               // Assert with $start and hold until the last PE has asserted.
               $valid_fwd = |pipe$reset       ? 1'b0 :
                            |pipe$start       ? 1'b1 :
                            |pipe$start_again ? 1'b1 :
                            ! >>1$valid_fwd   ? 1'b0 :
                                                ! |pipe/pe[m5_PE_MAX]>>1$valid_fwd;
               $nuc_t[m5_N_RANGE] = $valid_fwd ? |pipe$nucleotide_t : |pipe/pe[m5_PE_MAX]>>1$nuc_t;
               //$stall = $shift_s; // TODO : implement stall
               $score_f[m5_SCORE_RANGE] = 0;
               $score_v[m5_SCORE_RANGE] = 0;
               $score_e[m5_SCORE_RANGE] = 0;
               $max[m5_SCORE_RANGE] = 0;
               $max_or_shadow = 1'b0;
         @0
            /pe[m5_PE_RANGE]
               /* verilator lint_save */
               /* verilator lint_off UNSIGNED */
               // update genome
               /left
                  $ANY = #pe != 0 ? /pe[(#pe + m5_PE_MAX) % m5_PE_CNT]>>1$ANY : |pipe/default$ANY;
               /above
                  $ANY = /pe>>1$valid_fwd ? /pe>>1$ANY : |pipe/default$ANY;
               /diag
                  $ANY = ((#pe != 0) && /pe>>1$valid_fwd) ? /pe[(#pe + m5_PE_MAX) % m5_PE_CNT]>>2$ANY :
                                                            |pipe/default$ANY;
         @1
            \viz_js
               box: {left: -145},
               template() {
                  this.toLetter = function(nuc) {
                     return (nuc == 0) ? "A" : (nuc == 1) ? "C" : (nuc == 2) ? "T" : (nuc == 3) ? "G" : "?"
                  }
                  return {}
               },
               render() {
                  let ret = []
                  let str = ""
                  let color = "orange"
                  if ('$backtrack'.asBool()) {
                     str += "⬅️"
                     color = "#C0B0F0"
                  }
                  if ('$forward_prop'.asBool()) {
                     if ('$max_prop'.asBool()) {
                        str += "➡️"
                        color = "#B0F0B0"
                     } else {
                        str += "⏩"
                        color = "#F0F0B0"
                     }
                  }
                  if (! '$active'.asBool()) {
                     str += "❎"
                     color = "darkgray"
                  }
                  this.getBox().set({fill: color})
                  ret.push(new fabric.Text(str, {
                       left: -25, top: -25,
                       angle: '$active'.asBool() ? 45 : 0,
                       fontSize: 40,
                       originX: "center", originY: "center",
                  }))
                  let max = '$max'.asInt()
                  ret.push(new fabric.Text("Max:", {
                       left: -135, top: -80,
                       fill: "black",
                       fontSize: 30,
                  }))
                  ret.push(new fabric.Text(max.toString(), {
                       left: -120, top: -55,
                       fill: max ? "black" : "gray",
                       fontSize: 50,
                  }))
                  ret.push(new fabric.Text("PEs:", {
                       left: -55, top: -105,
                       fill: "black",
                       fontSize: 25,
                  }))
                  ret.push(
                       new fabric.Text(
                            '$max_prop'.asBool()   ? "Determine\nMax Score" :
                            '$arrow_prop'.asBool() ? "Propagate\nto Max" :
                            '$backtrack'.asBool()  ? "Backtrack\nfrom Max" :
                                                     "Idle",
                            {    left: -132, top: -205,
                                 fill: "darkblue",
                                 fontSize: 30,
                            }
                       )
                  )
                  return ret
               }
            /output
               /nuc_s_workaround[m5_PE_RANGE]
                  $ANY = |pipe/pe[#nuc_s_workaround]/nuc_s$ANY;
               /nuc_t_workaround[m5_PE_RANGE]
                  $ANY = |pipe/pe[#nuc_t_workaround]/nuc_t$ANY;
               \viz_js
                  box: {width: m5_PE_CNT * 2 * 32, height: 300 + m5_PE_CNT * 50, strokeWidth: 0},
                  render() {
                     // Put all sigs into sig_obj.
                     let sig_obj = {$max: '|pipe$max'}
                     for (let i = 0; i < m5_PE_CNT; i++) {
                        sig_obj[`$nuc_s${i}`] = '|pipe/pe[i]$nuc_s'
                        sig_obj[`$match_s${i}`] = '/nuc_s_workaround[i]$match'
                        sig_obj[`$exclude_s${i}`] = '/nuc_s_workaround[i]$exclude'
                        sig_obj[`$in_strand_s${i}`] = '/nuc_s_workaround[i]$in_strand'
                        sig_obj[`$nuc_t${m5_PE_MAX - i}`] = '|pipe/pe[i]$nuc_t'
                        sig_obj[`$match_t${m5_PE_MAX - i}`] = '/nuc_t_workaround[i]$match'
                        sig_obj[`$exclude_t${m5_PE_MAX - i}`] = '/nuc_t_workaround[i]$exclude'
                        sig_obj[`$is_max_t${m5_PE_MAX - i}`] = '/nuc_t_workaround[i]$is_max'
                     }
                     let sigs = this.signalSet(sig_obj)
                     // Step sigs to the first inactive cycle of the next or current inactive period.
                     let $active = '|pipe$active'
                     let active = $active.asBool()
                     $active.step(-1)  // (1 cycle behind sigs)
                     sigs.forwardToValue($active, 0)
                     sigs.backToValue($active, 1)
                     
                     // Extract signal values.
                     let nuc_s = []
                     let match_s = []
                     let exclude_s = []
                     let in_strand_s = []
                     let nuc_t = []
                     let match_t = []
                     let exclude_t = []
                     let is_max_t = []
                     for (let i = 0; i < m5_PE_CNT; i++) {
                        nuc_s[i] = this.getScope("pipe").context.toLetter(sig_obj[`$nuc_s${i}`].asInt())
                        match_s[i] = sig_obj[`$match_s${i}`].asBool()
                        exclude_s[i] = sig_obj[`$exclude_s${i}`].asBool()
                        in_strand_s[i] = sig_obj[`$in_strand_s${i}`].asBool()
                        nuc_t[i] = this.getScope("pipe").context.toLetter(sig_obj[`$nuc_t${i}`].asInt())
                        match_t[i] = sig_obj[`$match_t${i}`].asBool()
                        exclude_t[i] = sig_obj[`$exclude_t${i}`].asBool()
                        is_max_t[i] = sig_obj[`$is_max_t${i}`].asBool()
                     }
               
                     // Step max->0 through strand, rescoring it to determine when score == 0 and the strand begins.
                     //
                     // Initialize s and t to index the max end of strand.
                     let s = m5_PE_MAX
                     let t = 0
                     while (! in_strand_s[s] && s >= 0) {s--}
                     while (! is_max_t[t] && t <= m5_PE_MAX) {t++}
                     // Walk strand.
                     let score = sig_obj[`$max`].step(-1).asInt(); sig_obj[`$max`].step()
                     let score_delta = null
                     let beta = false  // true indicates previous score assumed to be BETA, which might need to be adjusted to ALPHA.
                     str_s = ""
                     str_t = ""
                     while (score > 0 && s >= 0 && t >= 0) {
                        if (exclude_s[s]) {
                           str_s = nuc_s[s].toLowerCase() + str_s
                           str_t = "-" + str_t
                           s--
                           score_delta = m5_BETA
                        } else if (exclude_t[t]) {
                           str_t = nuc_t[t].toLowerCase() + str_t
                           str_s = "-" + str_s
                           t--
                           score_delta = m5_BETA
                        } else {
                           // Diagonal
               
                           // Correct previous BETA to ALPHA
                           if (score_delta === m5_BETA) {
                              score -= score_delta - m5_ALPHA
                           }
                           
                           if (match_s[s] != match_t[t]) {
                              // Error, match_s and match_t should match.
                              debugger
                              str_s = "?" + str_s
                              str_t = "?" + str_t
                              score_delta = 0
                           } else if (match_s[s]) {
                              // Match
                              str_s = nuc_s[s] + str_s
                              str_t = nuc_t[t] + str_t
                              score_delta = -m5_DIAG_INC
                           } else {
                              // Mismatching nucleotides (not excluded)
                              str_s = nuc_s[s].toLowerCase() + str_s
                              str_t = nuc_t[s].toLowerCase() + str_t
                              score_delta = m5_DIAG_DEC
                           }
                           s--
                           t--
                        }
                        score += score_delta
                     }
                     return [
                          new fabric.Text(
                               str_s,
                               {fill: active ? "darkgray" : "black", left: 4, top: 10,
                                fontSize: 40, fontFamily: "monospace"}
                          ),
                          new fabric.Text(
                               str_t,
                               {fill: active ? "darkgray" : "black", left: 4, top: 65,
                                fontSize: 40, fontFamily: "monospace"}
                          )
                     ]
                  },
                  where: {left: 0, top: -240}
         @1
            /pe[*]
               ?$valid_fwd
                  $vdiag[m5_SCORE_RANGE]   = $nuc_s == $nuc_t ? /diag$score_v + m5_DIAG_INC : decr(/diag$score_v, m5_DIAG_DEC);
                  $score_f[m5_SCORE_RANGE] = max(decr(/left$score_v,  m5_ALPHA), decr(/left$score_f,  m5_BETA));
                  $score_e[m5_SCORE_RANGE] = max(decr(/above$score_v, m5_ALPHA), decr(/above$score_e, m5_BETA));
                  $score_v[m5_SCORE_RANGE] = max(max($score_e, $score_f), $vdiag);
                  $max[m5_SCORE_RANGE]     = max(max(/above$max, /left$max), $score_v);
                  //*output_scores[#pe] = >>(m5_PE_CNT - #pe)$max;
                  //*valid = >>(m5_PE_CNT - #pe)$valid_fwd;
                  /* verilator lint_restore */
               ?$valid_arrow_fwd
                  // The max shadow excludes max values to the left or below other max values.
                  $max_shadow = /left$max_or_shadow || /above$max_or_shadow;
                  $is_max = ! $max_shadow && $score_v == |pipe$max;
                  $max_or_shadow = $is_max || $max_shadow;
         
         // ================
         // For Backtracking
         // ================
         @0
            /default
               $valid_bwd = |pipe$reset      ? 1'b0 :
                            |pipe$start_back ? 1'b1 :
                            ! >>1$valid_bwd  ? 1'b0 :
                                               ! |pipe/pe[0]>>1$valid_bwd;
               $back_arrow_bwd[1:0] = m5_BACK_DIAG;
               $in_a_strand = 1'b0;
         @0
            /pe[*]
               /right
                  $ANY = (#pe != (m5_PE_CNT-1)) ? /pe[(#pe + 1) % m5_PE_CNT]>>1$ANY : |pipe/default$ANY;
               /cyclic_right
                  $ANY = /pe[(#pe + 1) % m5_PE_CNT]>>1$ANY;
               /below
                  $ANY = /pe>>1$valid_bwd ? /pe>>1$ANY : |pipe/default$ANY;
               /back_diag
                  $ANY = ((#pe != m5_PE_MAX) && /pe>>1$valid_bwd) ? /pe[(#pe + 1) % m5_PE_CNT]>>2$ANY :
                                                                    |pipe/default$ANY;
               // Is this PE computing for backtracking.
               $valid_bwd = ! |pipe$active ? 1'b0 : /right$valid_bwd;
         @1
            /pe[*]
               ?$valid_arrow_fwd
                  // TODO: This comparison is redundant with the max comparison. Not clear how good a job synthesis will do with this.
                  $back_arrow_fwd[1:0] =
                       $score_v == $vdiag   ? 2'd['']m5_BACK_DIAG :
                       $score_v == $score_f ? 2'd['']m5_BACK_LEFT :
                       $score_v == $score_e ? 2'd['']m5_BACK_ABOVE :
                                              2'bXX;  // Shouldn't happen.
               // Vector of all 2-bit back-arrows in the column as well as max value tags of BACK_BELOW_MAX on
               // entries below max values. One extra entry may hold BACK_BELOW_MAX values off the bottom.
               // [1:0] is $back_arrow_fwd during forward propagation and $back_arrow_bwd during
               // backtracking and [3:2] is above that in the matrix, etc.
               $back_arrow_for_history[1:0] =
                    >>1$valid_arrow_fwd && >>1$is_max
                                        ? 2'd['']m5_BACK_BELOW_MAX :
                    $valid_arrow_fwd    ? $back_arrow_fwd :
                    >>1$valid_arrow_fwd ? 2'd['']m5_BACK_DIAG :   // (not m5_BACK_BELOW_MAX)
                                          2'bXX;
               $back_arrows[2 * m5_PE_CNT + 1 : 0] =
                    |pipe$reset         ? {m5_PE_CNT{2'b00}} :
                    $valid_arrow_fwd ||
                    >>1$valid_arrow_fwd ? {>>1$back_arrows[2 * m5_PE_CNT - 1 : 0], $back_arrow_for_history} :
                    $valid_bwd          ? {2'bXX, >>1$back_arrows[2 * m5_PE_CNT + 1 : 2]} :
                                          $RETAIN;
               $back_arrow_bwd[1:0] = $back_arrows[1:0];
               
               // Backtracking calculation.
               ?$valid_bwd
                  $found_max = >>1$back_arrow_bwd == m5_BACK_BELOW_MAX;
                  $from_back_diag = /back_diag$in_a_strand && /back_diag$back_arrow_bwd == m5_BACK_DIAG;
                  $from_right  = ! $from_back_diag && (
                                    /right$in_a_strand     && /right$back_arrow_bwd     == m5_BACK_LEFT);
                  $from_below  = ! ($from_back_diag || $from_right) && (
                                    /below$in_a_strand     && /below$back_arrow_bwd     == m5_BACK_ABOVE);
                  $from_somewhere = $from_back_diag || $from_right || $from_below;
                  $in_a_strand = $from_somewhere || $found_max;
               
               // Resulting characterization data (remains valid after calculation).
               // /nuc_s$in_strand, and /nuc_t$is_max identify the max cell (end of strands) in the resulting output data.
               // /nuc_s$in_strand remains false for PEs to the right of the right-most MAX.
               // /nuc_t$is_max is asserted (sticky) for any t-nucleotide that is the max of any strand. The earliest
               // one in the strand corresponds to the chosen strand.
               // (Note that neither /nuc_s$in_strand nor /nuc_t$is_max identifies the start of the strands.
               //  This determination is left to post-processing.)
               /nuc_s
                  // /default and /in_a_strand for the $ANY assignment, below.
                  /default
                     $in_strand = 1'b0;
                     $exclude = 1'b0;
                     $match = 1'b0;
                  /in_a_strand
                     $in_strand = 1'b1;
                     $exclude = /pe$back_arrow_bwd == m5_BACK_LEFT;
                     $match = /pe/nuc_t$match;
                  $ANY =
                       ! |pipe$active
                       // Retain while inactive.
                            ? >>1$ANY :
                       // Set to default prior to backtracking.
                       ! |pipe$backtrack
                            ? /default$ANY :
                       // Assign for cells in a strand (with the last assignment, which is the rightmost strand, taking priority).
                       /pe$valid_bwd && /pe$in_a_strand
                            ? /in_a_strand$ANY :
                       // Retain
                              >>1$ANY;
               $in_rightmost_strand = $in_a_strand && ! /nuc_t$already_in_a_strand;
               /nuc_t
                  // Assert (sticky) for the final cell processing this nucleotide in its first strand.
                  // This is used to mask off strands to the left of the first encountered, so resulting
                  // output nucleotide data reflects the left-most strand for the nucleotide.
                  $already_in_a_strand = /pe[(#pe + 1) % m5_PE_CNT]/nuc_t>>1$in_a_strand;
                  $in_a_strand =
                       ! |pipe$active
                       // Retain while inactive.
                            ? $RETAIN :
                       ! |pipe$backtrack
                            ? 1'b0 :
                       /pe$valid_bwd && (/pe$in_a_strand && ! /pe/nuc_s$exclude)
                            ? 1'b1 :
                              $already_in_a_strand;
                  // /default and /in_rightmost_strand for the $ANY assignment, below.
                  /default
                     $is_max = 1'b0;
                     $match = 1'b0;
                     $exclude = 1'b0;
                  /in_rightmost_strand
                     $is_max = /pe$found_max;
                     $match = /pe$nuc_s == /pe$nuc_t;
                     $exclude = /pe$back_arrow_bwd == m5_BACK_ABOVE;
                  $ANY =
                       ! |pipe$active
                       // Retain while inactive.
                            ? >>1$ANY :
                       // Set to default prior to backtracking.
                       ! |pipe$backtrack
                            ? /default$ANY :
                       // Assign for cells in the rightmost strand.
                       /pe$valid_bwd && /pe$in_rightmost_strand
                            ? /in_rightmost_strand$ANY :
                       // Retain
                              /pe[(#pe + 1) % m5_PE_CNT]/nuc_t>>1$ANY;
         
         // ===
         // VIZ
         // ===
         @1
            /pe[m5_PE_RANGE]
               \viz_js
                  box: {left: 0, top: -100, width: 50, height: 100 + m5_PE_CNT * 50, strokeWidth: 0},
                  layout: "horizontal",
                  init() {
                     return {
                        pe_background: new fabric.Rect({
                             left: 0, top: -100, width: 50, height: 90, fill: "gray"
                        }),
                        letter_t: new fabric.Text("", {
                             left: 20, top: -82,
                             fontSize: 15, fontFamily: "monospace", fontWeight: 800,
                        }),
                        letter_s: new fabric.Text("", {
                             left: 15, top: -58,
                             fontSize: 30, fontFamily: "monospace", fontWeight: 800,
                        }),
                        scores: new fabric.Text("", {
                             left: 0, top: -46, fontSize: 3,
                             fill: "white",
                             visible: m5_DETAILS_VISIBLE,
                        }),
                     }
                  },
                  render() {
                     this.obj.pe_background.set({
                          fill: '$valid_fwd'.asBool() ? "blue" :
                                '$valid_bwd'.asBool() ? "blue" :
                                                        "#505050",
                     })
                     this.obj.letter_t.set({
                          text: this.getScope("pipe").context.toLetter('$nuc_t'.asInt()),
                          fill: '/nuc_t$is_max'.asBool() ? "red" : ! '/nuc_t$in_a_strand'.asBool() ? "black" : '/nuc_t$exclude'.asBool() ? "darkgray" : '/nuc_t$match'.asBool() ? "orange" : "gray",
                     })
                     this.obj.letter_s.set({
                          text: this.getScope("pipe").context.toLetter('$nuc_s'.asInt()),
                          fill: ! '/nuc_s$in_strand'.asBool() ? "black" : '/nuc_s$exclude'.asBool() ? "darkgray" : '/nuc_s$match'.asBool() ? "orange" : "gray",
                     })
                     this.obj.scores.set({
                          text: `e:${'$score_e'.asInt()}\nf:${'$score_f'.asInt()}\nv:${'$score_v'.asInt()}\ndiag:${'$vdiag'.asInt()}\n${'$back_arrows'.asBinaryStr()}`
                     })
                  },
                  where: {top: -100}
               /vert[m5_PE_RANGE]
                  \viz_js
                     box: {width: 50, height: 50, stroke: "black"},
                     layout: "vertical",
                     init() {
                        // fabric.Color.overlayWith doesn't work as desired. This replaces it.
                        // This gives the color resulting from two color layers (considering their alpha,
                        // where fabric seems to assume 1 and 0.5).
                        //   color1: a fabric.Color
                        //   rgba2: [r, g, b, a] E.g. fabric.Color("blue").getSource()
                        this.overlayWith = function(color1, rgba2) {
                           let rgba1 = color1.getSource()
                           let transparency2 = (1 - rgba2[3])
                           let alpha = rgba2[3] + transparency2 * rgba1[3]
                           let multiplier = 1 / alpha
                           let contrib1 = transparency2 * rgba1[3]
                           color1.setSource([
                              (rgba2[3] * rgba2[0] + contrib1 * rgba1[0]) * multiplier,
                              (rgba2[3] * rgba2[1] + contrib1 * rgba1[1]) * multiplier,
                              (rgba2[3] * rgba2[2] + contrib1 * rgba1[2]) * multiplier,
                              alpha
                           ])
                        }
                        
                        // Determine color based on up to two events, each with an associated color, happening at a given cycle-delta from the current cycle.
                        // color1 is transparent if future (cycle > 0), opaque if now (cycle == 0), faded if past (cycle < 0).
                        // color2 is overlayed, transparent in future, slightly faded (opaquely) if past.
                        this.cellColor = function(color1, cycle1, color2, cycle2) {
                           color1 = new fabric.Color(color1)
                           if (cycle1 > 0) {  // future
                              color1.setAlpha(m5_FUTURE_OPACITY)
                           } else if (cycle1 < 0) {  // past
                              this.overlayWith(color1, [160, 160, 160, m5_PAST_FADE])
                           }
                           if (color2) {
                              color2 = new fabric.Color(color2)
                              if (cycle2 > 0) {  // future
                                 color2.setAlpha(m5_FUTURE_OPACITY)
                              } else if (cycle2 < 0) {  // past
                                 this.overlayWith(color2, [160, 160, 160, m5_PAST_FADE])
                              }
                              this.overlayWith(color1, color2.getSource())
                           }
                           return color1.toRgba()
                        }
                        
                        // Make arrow from one cell to another and push it into 'objects' if 'from_value' and 'to_value'
                        // match and at least one is non-zero (matching the diagram in wikipedia). Arrow is
                        // centered at 'top','left' with 'angle' 0 pointing up.
                        this.makeArrow = function (objects, from_value, to_value, backtrack_arrow, diff, left, top, length, angle) {
                           if (from_value == to_value && (from_value != 0 || to_value != 0)) {
                              let color = backtrack_arrow === true  ? "red" :
                                          backtrack_arrow === false ? "purple" :
                                                                      "magenta"
                              color = this.cellColor(color, diff)
                              objects.push(
                                 new fabric.Group([
                                    new fabric.Line([0, 0, 0, -(length - 8)], {stroke: color, strokeWidth: 4, originX: "center", originY: "bottom"}),
                                    new fabric.Triangle({left: 0, top: -(length - 9), width: 10, height: 9, fill: color, originX: "center", originY: "bottom"})
                                 ], {top, left, angle, originX: "center", originY: "center"})
                              )
                           }
                        }
                        return {
                           text: new fabric.Text("", {
                                left: 2, top: 2.5,
                                fontSize: 4,
                                visible: m5_DETAILS_VISIBLE,
                           }),
                           back_text: new fabric.Text("", {
                                left: 25, top: 2.5,
                                fontSize: 4,
                                visible: m5_DETAILS_VISIBLE,
                           }),
                           score: new fabric.Text("", {
                                left: 25, top: 27,
                                fontSize: 26, fontFamily: "monospace", fontWeight: 700,
                                originX: "center", originY: "center",
                           }),
                           max: new fabric.Text("", {
                                left: 50, top: 50,
                                fontSize: 13, fontFamily: "monospace", fontWeight: 700,
                                originX: "right", originY: "bottom",
                           }),
                        }
                     },
                     render() {
                        
                        //
                        // Signals
                        //
                        
                        // This signalSet is carried through all phases.
                        
                        let max_prop = '|pipe$max_prop'.asBool()
                        let arrow_prop = '|pipe$arrow_prop'.asBool()
                        let sigs = this.signalSet(
                             {$vdiag: '/pe[this.getIndex("pe")]$vdiag',   // Explicit indexing required due to Issue #467.
                              $score_e: '/pe[this.getIndex("pe")]$score_e',
                              $score_f: '/pe[this.getIndex("pe")]$score_f',
                              $score_v: '/pe[this.getIndex("pe")]$score_v',
                              $nuc_t: '/pe[this.getIndex("pe")]$nuc_t',
                              $nuc_s: '/pe[this.getIndex("pe")]$nuc_s',
                              $max: '/pe[this.getIndex("pe")]$max',
                              $is_max: '/pe[this.getIndex("pe")]$is_max',
                              $max_shadow: '/pe[this.getIndex("pe")]$max_shadow',
                              $back_arrow_fwd: '/pe[this.getIndex("pe")]$back_arrow_fwd',
                              $back_arrow_bwd: '/pe[this.getIndex("pe")]$back_arrow_bwd',
                              $valid_bwd: '/pe[this.getIndex("pe")]$valid_bwd',
                              $found_max: '/pe[this.getIndex("pe")]$found_max',
                              $in_a_strand: '/pe[this.getIndex("pe")]$in_a_strand',
                              $in_rightmost_strand: '/pe[this.getIndex("pe")]$in_rightmost_strand',
                              $match: '/pe[this.getIndex("pe")]/nuc_t$match',
                             })
                        
                        
                        //
                        // Max Phase
                        //
                        
                        // Step back to assertion of |pipe$start, which is starts the first forward-propogation
                        // phase and is the cycle computing [0,0].
                        sigs.step()
                        let started = sigs.backToValue('|pipe$start'.step(), 1)
                        if (! started) {
                           // We haven't started analysis. Show nothing.
                           this.obj.text.set({text: ""})
                           this.obj.back_text.set({text: ""})
                           this.obj.score.set({text: ""})
                           this.obj.max.set({text: ""})
                           this.getBox().set({
                                stroke: "gray",
                                fill: "transparent",
                           })
                           return []
                        }
                        sigs.step(this.getIndex() + this.getIndex("pe"))    // Adjust for indices to set to cycle computing this cell.
                        // Get values.
                        let score_v = sigs.sig("$score_v").asInt()
                        let score_e = sigs.sig("$score_e").asInt()
                        let score_f = sigs.sig("$score_f").asInt()
                        let max     = sigs.sig("$max").asInt()
                        let is_max  = sigs.sig("$is_max").asBool()
                        let vdiag   = sigs.sig("$vdiag").asInt()
                        let back_arrow = sigs.sig("$back_arrow_fwd").asInt()

                        let max_prop_diff = sigs.sig("$vdiag").getCycle() - this.getCycle()
                        
                        
                        //
                        // Arrows Phase
                        //
                        
                        // Step to arrow_prop phase.
                        
                        sigs.step(2 * m5_PE_CNT)
                        let max_shadow = sigs.sig("$max_shadow").asBool()
                        
                        let arrow_prop_diff = sigs.sig("$vdiag").getCycle() - this.getCycle()
                        
                        // Draw arrows.
                        let ret = []
                        let arrow_diff = max_prop ? max_prop_diff : arrow_prop_diff
                        this.makeArrow(ret, vdiag,   score_v, back_arrow == m5_BACK_DIAG,  arrow_diff, 0,  0,  25, 135)
                        this.makeArrow(ret, score_e, score_v, back_arrow == m5_BACK_ABOVE, arrow_diff, 25, 0,  20, 180)
                        this.makeArrow(ret, score_f, score_v, back_arrow == m5_BACK_LEFT,  arrow_diff, 0,  25, 20, 90)
                        
                        
                        //
                        // Backtracking Phase
                        //
                        
                        // Step to backtracking cycle.
                        
                        sigs.forwardToValue(sigs.sig("$valid_bwd"), 1)
                        sigs.step(m5_PE_MAX - this.getIndex())
                        let backtrack_diff = sigs.sig("$vdiag").getCycle() - this.getCycle()
                        let back_arrow_bwd = sigs.sig("$back_arrow_bwd").asInt()
                        let match = sigs.sig("$match").asBool()
                        // Confirm arrows are the same for max and arrow phase.
                        let back_arrow2 = sigs.sig("$back_arrow_fwd").asInt()
                        /*
                        if (back_arrow2 != back_arrow) {
                           console.log("Back arrow mismatch between max phase and arrow phase.")
                           debugger
                        }
                        if (back_arrow_bwd != back_arrow) {
                           console.log("Back arrow mismatch between max phase and backtrack phase.")
                           debugger
                        }
                        */
                        
                        // Set backtrack text.
                        this.obj.back_text.set({text: ``})
                        
                        // Backtrack signals.
                        let found_max    = sigs.sig("$found_max").asBool()
                        let in_strand = sigs.sig("$in_a_strand").asBool()
                        let in_rightmost_strand = sigs.sig("$in_rightmost_strand").asBool()
                        
                        // Set init() object properties.
                        let stroke_color =
                        //     max_prop_diff == 0 || arrow_prop_diff == 0 || backtrack_diff == 0 ? "white" :
                        //     max_prop_diff > 0 || arrow_prop_diff > 0
                        //          "black"
                             this.cellColor(
                                   "black",
                                   max_prop ? max_prop_diff : arrow_prop_diff
                             )
                        let text_color = stroke_color
                        if (max_prop_diff == 0 || arrow_prop_diff == 0 || backtrack_diff == 0) {
                           stroke_color = "white"
                        }
                        let strand_color =
                             !in_strand ? null :
                             !in_rightmost_strand ? "#404060" :
                             found_max ? (match ? "red" : "#AF5050") :
                             !match ? "gray" :
                             score_v == m5_DIAG_INC ? "yellow" :
                                    "orange"
                        let blend_value = max_prop ? max : score_v
                        let cell_color = this.cellColor(
                             !max_prop && found_max ? "red" : `rgb(0,${(blend_value * 5) % 255},255)`,
                             max_prop ? max_prop_diff : arrow_prop_diff,
                             strand_color ? strand_color : max_shadow ? "gray" : null,
                             strand_color ? backtrack_diff : arrow_prop_diff)
                        this.obj.text.set({
                             fill: text_color,
                             text: `nuc_t:${this.getScope("pipe").context.toLetter(sigs.sig("$nuc_t").asInt())}\nnuc_s:${this.getScope("pipe").context.toLetter(sigs.sig("$nuc_s").asInt())}\ne:${score_e}\nf:${score_f}\ndiag:${vdiag}\nmax:${max}${is_max ? "*" : ""}`
                        })
                        this.obj.score.set({fill: text_color, text: `${score_v}`})
                        this.obj.max.set({fill: text_color, text: `${max}`, visible: max_prop})
                        this.getBox().set({
                             stroke: stroke_color,
                             fill: cell_color
                        })
                        
                        return ret
                     },
                     where: {left: 0, top: 0, scale: 1}
            /vert_label[m5_PE_RANGE]
               \viz_js
                  box: {left: 0, top: 0, width: 50, height: 50, strokeWidth: 0},
                  layout: "vertical",
                  init() {
                     return {
                        letter_t: new fabric.Text("", {
                             left: 15, top: 10,
                             fontSize: 30, fontFamily: "monospace", fontWeight: 800,
                        }),
                     }
                  },
                  render() {
                     // Find $nuc_t at time of [0,0] computation (as in /vert\viz_js).
                     let sigs = this.signalSet({$nuc_t: '|pipe/pe[0]$nuc_t'})
                     sigs.step()
                     sigs.backToValue('|pipe$start'.step(), 1)
                     sigs.step(this.getIndex())
                     
                     this.obj.letter_t.set({text: this.getScope("pipe").context.toLetter(sigs.sig("$nuc_t").asInt())})
                  },
                  where: {left: -50, top: 0}

\TLV smith_waterman_example(/_top, _where)
   /_top
      \viz_js
         box: {strokeWidth: 0},
         where: {_where}
      \SV_plus
         // Character to nucleotide value.
         function logic [1:0] nuc (logic [7:0] ch);
            return ch == "A" ? 0 : ch == "C" ? 1 : ch == "T" ? 2 : 3;
         endfunction
         // Max score.
         function logic [m5_SCORE_RANGE] max (logic [m5_SCORE_RANGE] a, logic [m5_SCORE_RANGE] b);
            return (a > b) ? a : b;
         endfunction
         // Decrement, saturating at 0 to avoid wrap.
         function logic [m5_SCORE_RANGE] decr (logic [m5_SCORE_RANGE] val, logic [m5_SCORE_RANGE] dec);
            return (dec > val) ? 0 : val - dec;
         endfunction
      /sw
         |pipe
            @-1
               $reset = *reset;
               $start = *cyc_cnt == 10;  // Asserts for the computation of [0,0].
            @0
               /tb
                  m5+ifelse(1, 1,
                     \TLV
                        // Fixed sequences.
                        $genome_s[8 * m5_PE_CNT - 1 : 0] = "m5_S_GENOME";
                        $genome_t[8 * m5_PE_CNT - 1 : 0] = "m5_T_GENOME";
                        /pe[m5_PE_RANGE]
                           $nuc_s_char[7:0] = /tb$genome_s[((m5_PE_MAX - #pe) + 1) * 8 - 1 : (m5_PE_MAX - #pe) * 8];
                           $nuc_t_char[7:0] = /tb$genome_t[((m5_PE_MAX - #pe) + 1) * 8 - 1 : (m5_PE_MAX - #pe) * 8];
                           $nuc_s[m5_PE_RANGE] = nuc($nuc_s_char);
                           $nuc_t[m5_PE_RANGE] = nuc($nuc_t_char);
                     , 1, 1,
                     \TLV
                        // Random sequences.
                        /pe[m5_PE_RANGE]
                           m4_rand($rand0, m5_N_SIZE - 1, 0, pe + m5_SEED)
                           m4_rand($rand1, m5_N_SIZE - 1, 0, pe + m5_SEED)
                           m4_rand($rand2, m5_N_SIZE - 1, 0, pe + m5_SEED)
                           m4_rand($rand3, m5_N_SIZE - 1, 0, pe + m5_SEED)
                           $nuc_t[m5_N_SIZE-1:0] = $rand0 | ($rand1 & 2'b01);
                           $nuc_s[m5_N_SIZE-1:0] = $rand2 | ($rand1 & 2'b01);
                     ,
                     \TLV
                        // (Unassigned) random sequences.
                        /pe[m5_PE_RANGE]
                           `BOGUS_USE($nuc_s[m5_PE_RANGE] $nuc_t[m5_PE_RANGE])
                     )
                  /pe[m5_PE_RANGE]
                     $shifted_nuc_t[7:0] =
                          // reset
                          |pipe$reset ? $nuc_t :
                          // cyclic left shift
                          |pipe/pe[0]>>1$valid_fwd
                                      ? /pe[(#pe + 1) % m5_PE_CNT]>>1$shifted_nuc_t :
                          // retain
                                    $RETAIN;

      // Inputs:
      /sw
         |pipe
            @0
               /pe[m5_PE_RANGE]
                  $nucleotide_s[m5_N_RANGE] = |pipe/tb/pe$nuc_s;
               $nucleotide_t[m5_N_RANGE] = /tb/pe[0]$shifted_nuc_t;
      m5+smith_waterman(/_top, /sw, $reset)

\SV
   m5_makerchip_module
\TLV
   m5+smith_waterman_example(/example,)
   *passed = cyc_cnt > 80;
\SV
   endmodule
