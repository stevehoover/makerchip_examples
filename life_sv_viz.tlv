\m4_TLV_version 1d: tl-x.org
\SV

// --------------------------------------------------------------------
//
// This example implements Conway's Game of Life.
// In this "game", a grid of cells (10x10) are born and die based on the
// number of live neighbors they have in each step (clock cycle).
// A cell's neighbors are the surrounding 8 cells, which includes the
// diagonals.
//   - A cell is born if exactly 3 neighbors are alive.
//   - A cell dies from overcrowding or starvation if it have >3 or <2
//     neighbors.
//
// Output shows the grid in each step of simulation.
//
// This example shows:
//   - Use of SystemVerilog constants.
//   - Use of TL-Verilog "behavioral hierarchy".  (Eg, >xx[X_SIZE-1:0])
//   - That TL-Verilog is not just for pipelines!
//
// --------------------------------------------------------------------


`include "sp_default.vh" //_\SV

// --------------------------------------------------------------------
//
// This example implements Conway's Game of Life.
// In this "game", a grid of cells (10x10) are born and die based on the
// number of live neighbors they have in each step (clock cycle).
// A cell's neighbors are the surrounding 8 cells, which includes the
// diagonals.
//   - A cell is born if exactly 3 neighbors are alive.
//   - A cell dies from overcrowding or starvation if it have >3 or <2
//     neighbors.
//
// Output shows the grid in each step of simulation.
//
// This example shows:
//   - Use of SystemVerilog constants.
//   - Use of TL-Verilog "behavioral hierarchy".  (Eg, >xx[X_SIZE-1:0])
//   - That TL-Verilog is not just for pipelines!
//
// --------------------------------------------------------------------


module top(input logic clk,
           input logic reset,
           input logic [31:0] cyc_cnt,
           output logic passed,
           output logic failed);
   /* verilator lint_off UNOPTFLAT */
   
   // Random stimulus.
   bit [256:0] RW_rand_raw;
   bit [256+63:0] RW_rand_vect;
   pseudo_rand #(.WIDTH(257)) pseudo_rand (clk, reset, RW_rand_raw[256:0]);
   assign RW_rand_vect[256+63:0] = {RW_rand_raw[62:0], RW_rand_raw};

   // -------------------------
   // Parameters

   // Board size
   localparam X_SIZE = 20;  // Note: There's a hardcoded X_SIZE in $display statement.
   localparam Y_SIZE = 20;


   // Signal Declarations
   logic reset_a2;
   logic [31:0] cnt_a2,
                cnt_a3;
   // Alive count of a cell and its left and right neighbors.
   logic [1:0] row_cnt_a1 [19:0][19:0];


   always_ff @(posedge clk) begin
      cnt_a3[31:0] <= cnt_a2[31:0];
      reset_a2 <= reset;
   end


   // -------------------------
   // Design

   assign cnt_a2[31:0] = reset_a2 ? 32'b0 : cnt_a3 + 32'b1;

   for (yy = 0; yy <= 19; yy++) begin : L1_Yy
      logic alive_a1 [19:0],
            alive_a2 [19:0];
      for (xx = 0; xx <= 19; xx++) begin : L2_Xx
         logic [3:0] neighborhood_cnt_a1;
         logic L2_init_alive_a1;

         always_ff @(posedge clk)
            alive_a2[xx] <= alive_a1[xx];

         // ===========
         // Population count ($cnt) of 3x3 square (with edge logic).

         // Sum left + me + right.
         assign row_cnt_a1[yy][xx][1:0] = {1'b0, (alive_a2[(xx + X_SIZE-1) % X_SIZE] & (xx > 0))} +
                         {1'b0, alive_a2[xx]} +
                         {1'b0, (alive_a2[(xx + 1) % X_SIZE] & (xx < X_SIZE-1))};
         // Sum three $row_cnt's: above + mine + below.
         assign neighborhood_cnt_a1[3:0] = {2'b00, (row_cnt_a1[(yy + Y_SIZE-1) % Y_SIZE][xx] & {2{(yy > 0)}})} +
                     {2'b00, row_cnt_a1[yy][xx][1:0]} +
                     {2'b00, (row_cnt_a1[(yy + 1) % Y_SIZE][xx] & {2{(yy < Y_SIZE-1)}})};


         // ===========
         // Init state.

         assign L2_init_alive_a1 = RW_rand_vect[(0 + ((yy * xx) ^ ((3 * xx) + yy))) % 257 +: 1];


         // ===========
         // Am I alive?

         assign alive_a1[xx] =
                   reset        ? L2_init_alive_a1 :                                       // init
                   alive_a2[xx] ? (neighborhood_cnt_a1 >= 3 && neighborhood_cnt_a1 <= 4) : // stay alive
                                  (neighborhood_cnt_a1 == 3);                              // born
      end
   end

   assign passed = cyc_cnt > 32'd20;

\TLV
   /yy[19:0]
      /xx[19:0]
         \viz_alpha
            initEach() {
               let rect = new fabric.Rect({
                  width: 10,
                  height: 10,
                  fill: "green",
                  left: this.scopes.xx.index * 10,
                  top: this.scopes.yy.index * 10
               })
               let shadow = new fabric.Rect({
                  width: 10,
                  height: 10,
                  fill: "green",
                  left: this.scopes.xx.index * 10,
                  top: this.scopes.yy.index * 10
               })
               return {objects: {rect, shadow}}
            },
            renderEach() {
               let alive_sig_name = `L1_Yy[${this.scopes.yy.index}]` + `.alive_a2(${this.scopes.xx.index})`
               let background = (this.svSigRef(alive_sig_name, 0).asInt() == 1) ? "blue" : "red"
               let background2 = (this.svSigRef(alive_sig_name, -1).asInt() == 1) ? "black" : null
               let opacity2 = (this.svSigRef(alive_sig_name, -1).asInt() == 1) ? 0.2 : 0
               let objects = this.fromInit().objects
               objects.rect.set("fill", background)
               objects.shadow.set("fill", background2)
               objects.shadow.set("opacity", opacity2)
            }

\SV
endmodule
