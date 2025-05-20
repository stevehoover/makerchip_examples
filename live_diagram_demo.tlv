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

m4_include_url(['https:/']['/raw.githubusercontent.com/stevehoover/tlv_flow_lib/5a8c0387be80b2deccfcd1506299b36049e0663e/fundamentals_lib.tlv'])
m4_include_url(['https:/']['/raw.githubusercontent.com/stevehoover/tlv_flow_lib/5a8c0387be80b2deccfcd1506299b36049e0663e/pipeflow_lib.tlv'])
m4_makerchip_module()

///m4_define_hier(M4_RING_STOP, 4, 0)

\TLV
   
   //-------------
   // DUT
   
   /ring_stop
      |stall0
         @1
            $reset = *reset;
            m4_rand($avail, 0, 0)
            /trans
               m4_rand($input, 3, 0)
               $dest[1:0] = 2'b0;
      m4+stall_pipeline(/ring_stop, |stall, 0, 2, /trans)
      m4+simple_bypass_fifo_v2(/ring_stop, |stall2, @1, |bp0, @1, 4, 100, /trans)
      m4+bp_pipeline(/ring_stop, |bp, 0, 2, /trans)
      |bp2
         @1
            $local = /trans$dest == 2'b0;
            /trans
               `BOGUS_USE($input)
               $data[7:0] = 8'h55;
         @-4
            /trans
               m4_rand($color, 23, 0)
      m4+opportunistic_flow(/ring_stop, |bp2, @1, |bypass, @1, $local, |ring_in, @1, /trans)
   /ring_stop
      m4+flop_fifo_v2(/ring_stop, |ring_in, @1, |ring_out, @1, 5, /trans)
   
   /ring_stop
      m4+arb2(/ring_stop, |ring_out, @1, |bypass, @1, |arb_out, @1, /trans)
      m4_define(['m4_plus_inst_id'], 100)
      m4+flop_fifo_v2(/ring_stop, |arb_out, @1, |stop_out, @1, 4, /trans)
      |stop_out
         @1
            m4_rand($blocked, 0, 0)
            /trans
               $dummy[31:0] = {$data, $color};
            
   
   //--------------
   // Testbench
   ///m4+router_testbench(/top, /ring_stop, |stall0, @1, |fifo2_out, @1, /trans, /top<>0$reset)
   
   
   // Simulation control.
   *passed = *cyc_cnt > 80; //& /top/tb/ring_stop[*]|passed>>1$passed;
   *failed = *cyc_cnt > 80;
   
\SV
endmodule 
