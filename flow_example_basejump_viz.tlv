\m4_TLV_version 1d: tl-x.org
\SV
/*
Copyright (c) 2018, Steve Hoover
All rights reserved.

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

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//m4_include_url(['http://localhost:8080/wip/viz.tlv'])
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!

m4_include_url(['https://raw.githubusercontent.com/stevehoover/tlv_flow_lib/5a8c0387be80b2deccfcd1506299b36049e0663e/fundamentals_lib.tlv'])
m4_include_url(['https://raw.githubusercontent.com/stevehoover/tlv_flow_lib/5a8c0387be80b2deccfcd1506299b36049e0663e/pipeflow_lib.tlv'])

// Include BaseJump STL FIFO files.
/* verilator lint_off CMPCONST */
/* verilator lint_off WIDTH */
m4_sv_include_url(['https://bitbucket.org/taylor-bsg/bsg_ip_cores/raw/0c76d71f1e06cf844f767448e4df376b112b831f/bsg_misc/bsg_defines.v'])
m4_sv_include_url(['https://bitbucket.org/taylor-bsg/bsg_ip_cores/raw/0c76d71f1e06cf844f767448e4df376b112b831f/bsg_dataflow/bsg_fifo_tracker.v'])
m4_sv_include_url(['https://bitbucket.org/taylor-bsg/bsg_ip_cores/raw/0c76d71f1e06cf844f767448e4df376b112b831f/bsg_misc/bsg_circular_ptr.v'])
m4_sv_include_url(['https://bitbucket.org/taylor-bsg/bsg_ip_cores/raw/0c76d71f1e06cf844f767448e4df376b112b831f/bsg_dataflow/bsg_fifo_1r1w_small.v'])
m4_sv_include_url(['https://bitbucket.org/taylor-bsg/bsg_ip_cores/raw/0c76d71f1e06cf844f767448e4df376b112b831f/bsg_mem/bsg_mem_1r1w.v'])
m4_sv_include_url(['https://bitbucket.org/taylor-bsg/bsg_ip_cores/raw/0c76d71f1e06cf844f767448e4df376b112b831f/bsg_mem/bsg_mem_1r1w_synth.v'])
/* verilator lint_on WIDTH */
/* verilator lint_on CMPCONST */


m4_makerchip_module()

m4_define_hier(M4_RING_STOP, 4, 0)

\TLV
   $reset = *reset;
   
   
   // DUT
   
   /M4_RING_STOP_HIER
      m4+stall_pipeline(/ring_stop, |stall, 0, 3, /trans)
      m4+flop_fifo_v2(/ring_stop, |stall3, @1, |bp0, @1, 4, /trans)
      //m4+simple_bypass_fifo_v2(/ring_stop, |stall3, @1, |bp0, @1, 4, 100, /trans)
      m4+bp_pipeline(/ring_stop, |bp, 0, 3, /trans)
      |bp3
         @1
            $local = /trans$dest == #ring_stop;
      m4+opportunistic_flow(/ring_stop, |bp3, @1, |bypass, @1, $local, |ring_in, @1, /trans)
   m4+simple_ring(/ring_stop, |ring_in, @1, |ring_out, @1, /top<>0$reset, |rg, /trans)
   
   /ring_stop[*]
      m4+arb2(/ring_stop, |ring_out, @4, |bypass, @1, |arb_out, @1, /trans)
      // FIFO2
      // To use BaseJump STL, this line:
      //m4+simple_bypass_fifo_v2(/ring_stop, |arb_out, @1, |fifo2_out, @1, 4, 100, /trans)        
      // Becomes:
      //----------------
      |arb_out
         @1
            \SV_plus
               bsg_fifo_1r1w_small #(.width_p(100)) my_fifo(
                  *clk, $reset,
                  $avail, $$ready, /trans$ANY,
                  /ring_stop|fifo2_out<>0$$avail, /ring_stop|fifo2_out/trans<>0$$ANY, /ring_stop|fifo2_out<>0$accepted
               );
            $blocked = ! $ready;
      //----------------
   
   
   m4+trans()
   
   
   // Testbench
   m4+router_testbench(/top, /ring_stop, |stall0, @1, |fifo2_out, @1, /trans, /top<>0$reset)
   
   
   // Simulation control.
   *passed = & /top/tb/ring_stop[*]|passed>>1$passed;
   *failed = *cyc_cnt > 80;
\SV
endmodule
