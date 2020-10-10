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


module top(input logic clk, input logic reset, input logic [31:0] cyc_cnt, output logic passed, output logic failed);    /* verilator lint_off UNOPTFLAT */  bit [256:0] RW_rand_raw; bit [256+63:0] RW_rand_vect; pseudo_rand #(.WIDTH(257)) pseudo_rand (clk, reset, RW_rand_raw[256:0]); assign RW_rand_vect[256+63:0] = {RW_rand_raw[62:0], RW_rand_raw};  /* verilator lint_on UNOPTFLAT */
\TLV
\SV
// -------------------------
// Parameters

// Board size


localparam X_SIZE = 20;  // Note: There's a hardcoded X_SIZE in $display statement.
localparam Y_SIZE = 20;
 // viz_alpha cell size (width & height) in user units.

/* verilator lint_off UNOPTFLAT */  // To silence Verilator warnings.


//
// Signals declared top-level.
//

// For |default$cnt.
logic [31:0] DEFAULT_cnt_a2,
             DEFAULT_cnt_a3;

// For |default$reset.
logic DEFAULT_reset_a1,
      DEFAULT_reset_a2;

// For |default>yy>xx$row_cnt.
logic [1:0] DEFAULT_Yy_Xx_row_cnt_a1 [19:0][19:0];



generate


   //
   // Scope: |default
   //

      // For $cnt.
      always_ff @(posedge clk) DEFAULT_cnt_a3[31:0] <= DEFAULT_cnt_a2[31:0];

      // For $reset.
      always_ff @(posedge clk) DEFAULT_reset_a2 <= DEFAULT_reset_a1;


      //
      // Scope: >yy[19:0]
      //
      for (yy = 0; yy <= 19; yy++) begin : L1gen_DEFAULT_Yy

         //
         // Scope: >xx[19:0]
         //
         for (xx = 0; xx <= 19; xx++) begin : L2gen_Xx
            // For $alive.
            always_ff @(posedge clk) L1_DEFAULT_Yy[yy].L1_Xx_alive_a2[xx] <= L1_DEFAULT_Yy[yy].L1_Xx_alive_a1[xx];

         end
      end




   // -------------------------
   // Design

   //_|default
      //_@1
         assign DEFAULT_reset_a1 = reset;
      //_@2
         assign DEFAULT_cnt_a2[31:0] = DEFAULT_reset_a2 ? 32'b0 : DEFAULT_cnt_a3 + 32'b1;
 

      for (yy = 0; yy <= 19; yy++) begin : L1_DEFAULT_Yy
         logic L1_Xx_alive_a1 [19:0],
         L1_Xx_alive_a2 [19:0]; //_>yy
         //_@0
            /* viz_alpha omitted here */
            //_\viz_alpha
         for (xx = 0; xx <= 19; xx++) begin : L2_Xx
            logic [3:0] L2_cnt_a1;
            logic [0:0] L2_init_alive_a1; //_>xx
            //_@1
               // Cell logic

               // ===========
               // Population count ($cnt) of 3x3 square (with edge logic).
               
               // Sum left + me + right.
               assign DEFAULT_Yy_Xx_row_cnt_a1[yy][xx][1:0] = {1'b0, (L1_Xx_alive_a2[(xx + X_SIZE-1) % X_SIZE] & (xx > 0))} +
                               {1'b0, L1_Xx_alive_a2[xx]} +
                               {1'b0, (L1_Xx_alive_a2[(xx + 1) % X_SIZE] & (xx < X_SIZE-1))};
               // Sum three $row_cnt's: above + mine + below.
               assign L2_cnt_a1[3:0] = {2'b00, (DEFAULT_Yy_Xx_row_cnt_a1[(yy + Y_SIZE-1) % Y_SIZE][xx] & {2{(yy > 0)}})} +
                           {2'b00, DEFAULT_Yy_Xx_row_cnt_a1[yy][xx][1:0]} +
                           {2'b00, (DEFAULT_Yy_Xx_row_cnt_a1[(yy + 1) % Y_SIZE][xx] & {2{(yy < Y_SIZE-1)}})};


               // ===========
               // Init state.
               
               assign L2_init_alive_a1[0:0] = RW_rand_vect[(0 + ((yy * xx) ^ ((3 * xx) + yy))) % 257 +: 1];


               // ===========
               // Am I alive?
               
               assign L1_Xx_alive_a1[xx] = DEFAULT_reset_a1    ? L2_init_alive_a1 :                // init
                        L1_Xx_alive_a2[xx] ? (L2_cnt_a1 >= 3 && L2_cnt_a1 <= 4) :   // stay alive
                                    (L2_cnt_a1 == 3);                 // born
         end
      end //_\viz_alpha

   assign passed = cyc_cnt > 32'd20;
endgenerate

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
               });
               let shadow = null;
               shadow = new fabric.Rect({
                  width: 10,
                  height: 10,
                  fill: "green",
                  left: this.scopes.xx.index * 10,
                  top: this.scopes.yy.index * 10
               })
               return {objects: {rect: rect, shadow: shadow}};
            },
            renderEach() {
               let alive_sig_name =
                   `L1_DEFAULT_Yy[${this.scopes.yy.index}]` +
                   `.L1_Xx_alive_a2(${this.scopes.xx.index})`;
               let background =
                    (this.svSigRef(alive_sig_name, 0).asInt() == 1)
                         ? "blue" : "red";
               let background2 =
                    (this.svSigRef(alive_sig_name, -1).asInt() == 1)
                         ? "black" : null;
               let opacity2 =
                    (this.svSigRef(alive_sig_name, -1).asInt() == 1)
                         ? 0.2 : 0;
               this.fromInit().objects.rect.set("fill", background);
               this.fromInit().objects.shadow.set("fill", background2);
               this.fromInit().objects.shadow.set("opacity", opacity2);
            }

   *passed = *cyc_cnt > 32'd20;

\SV
   endmodule


