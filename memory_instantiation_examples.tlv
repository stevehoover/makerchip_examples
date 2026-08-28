\m5_TLV_version 1d: tl-x.org
\SV
   // =========================================================================
   // Instantiating a Verilog memory / array (BRAM, FIFO RAM, register file)
   // in TL-Verilog via \SV_plus.
   //
   // The array module (below) is a synchronous 1-write / 1-read memory with:
   //   - Registered reads: read DATA appears the cycle AFTER the read INDEX.
   //   - No bypass: written data is visible to reads only on the NEXT cycle.
   //
   // Reads and writes for a given port live at different points in a pipeline,
   // so the port connections use TLV's ahead (<<) / behind (>>) operators to
   // line each port up with the correct pipeline stage.  The instance is placed
   // in the context of the primary WRITE inputs, and the reads reach out from
   // there:
   //   - <<N  reaches an EARLIER pipe stage  (the read is BEFORE the write)
   //   - >>N  reaches a LATER   pipe stage   (the read is AFTER  the write)
   // $$ marks module OUTPUTS.
   //
   // There is no surrounding control logic: read/write inputs are left undriven
   // so Makerchip randomizes them, and explicit bit ranges on each use supply
   // the signal widths.  Outputs are consumed with `BOGUS_USE`.
   // =========================================================================
   module my_array #(
      parameter WIDTH = 8,      // data width
      parameter ELEMS = 16,     // number of entries
      parameter INDEX = $clog2(ELEMS)
   ) (
      input  logic             clk,
      // Write port
      input  logic             wr,
      input  logic [INDEX-1:0] wr_index,
      input  logic [WIDTH-1:0] wr_data,
      // Read port
      input  logic             rd,
      input  logic [INDEX-1:0] rd_index,
      output logic [WIDTH-1:0] rd_data
   );
      logic [WIDTH-1:0] mem [0:ELEMS-1];
      always_ff @(posedge clk) begin
         if (wr) mem[wr_index] <= wr_data;   // write visible to reads NEXT cycle
         if (rd) rd_data <= mem[rd_index];   // read data delayed one cycle
      end
   endmodule

   // Makerchip top module (provides clk, reset, cyc_cnt, random stimulus, ...).
   m5_makerchip_module
\TLV

   //
   // 1) FIFO written and read in the SAME pipeline.
   //
   //    Empty-FIFO data flow, no bypass: a value written at |fifo@1 is visible
   //    the next cycle, so the read INDEX for it is presented one stage later
   //    (@2) and the read DATA returns one more cycle later (@3).  The read is
   //    LATER than the write, so the read port reaches FORWARD with the behind
   //    operator >>.
   //
   |fifo
      @1
         \SV_plus
            my_array #(.WIDTH(8), .ELEMS(16)) fifo_ram (
               .clk(*clk),
               // Write port @1.
               .wr($wr),
               .wr_index($wr_index[3:0]),
               .wr_data($wr_data[7:0]),
               // Read port: index one stage later (@2), data two stages later (@3).
               .rd(>>1$rd_en),
               .rd_index(>>1$rd_index[3:0]),
               .rd_data(>>2$$rd_data[7:0])
            );
      @3
         `BOGUS_USE($rd_data)

   //
   // 2) Memory in a transaction pipeline (independent 1R1W per cycle).
   //
   //    Every cycle performs an independent write AND read (separate indices).
   //    The memory stores whole transaction records: the write payload flows in
   //    as a record via $ANY and the stored record flows back out via $$ANY
   //    (the same field set is "pulled through" both ports).  The read and write
   //    are presented together at |mem@1; a write is seen by a read one stage
   //    behind, so the read record is captured one stage later (@2) with >>1.
   //
   |mem
      @1
         /st_trans
            // Random write payload, bundled and connected whole via $ANY.
            // ($rand_data is undriven, so Makerchip randomizes it.)
            $data[7:0] = $rand_data[7:0];
         \SV_plus
            my_array #(.WIDTH(8), .ELEMS(16)) mem_ram (
               .clk(*clk),
               // Write port @1: whole payload record in via $ANY.
               .wr($wr_en),
               .wr_index($wr_index[3:0]),
               .wr_data(/st_trans$ANY),
               // Read port @1, concurrent with the write (independent index);
               // stored record out one stage behind (@2) via $$ANY.
               .rd($rd_en),
               .rd_index($rd_index[3:0]),
               .rd_data(/ld_trans>>1$$ANY)
            );
      @2
         /ld_trans
            `BOGUS_USE($data)

   //
   // 3) Register file (single read port used).
   //
   //    Read inputs are presented early (|rf@1) while writes commit late
   //    (|rf@3), so the instance sits in the write context (@3) and reaches
   //    BACK to the read stage with the ahead operator <<:  read INDEX at @1
   //    (<<2), read DATA one cycle later at @2 (<<1).
   //
   |rf
      @3
         \SV_plus
            my_array #(.WIDTH(8), .ELEMS(16)) rf_ram (
               .clk(*clk),
               // Write port @3.
               .wr($wr_en),
               .wr_index($wr_index[3:0]),
               .wr_data($wr_data[7:0]),
               // Read port: index at @1 (<<2), data at @2 (<<1).
               .rd(<<2$rd_en),
               .rd_index(<<2$rd_index[3:0]),
               .rd_data(<<1$$rd_data[7:0])
            );
      @2
         `BOGUS_USE($rd_data)

   *passed = *cyc_cnt > 40;
\SV
   endmodule
