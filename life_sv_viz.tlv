\m5_TLV_version 1d: tl-x.org
\m5
   use(m5-1.0)
\SV

// --------------------------------------------------------------------
//
// This example implements Conway's Game of Life.
// In this "game", a grid of cells (20x20) are born and die based on the
// number of live neighbors they have in each step (clock cycle).
// A cell's neighbors are the surrounding 8 cells, which includes the
// diagonals.
//   - A cell is born if exactly 3 neighbors are alive.
//   - A cell dies from overcrowding or starvation if it have >3 or <2
//     neighbors.
//
// This example shows:
//   - Hand-coded SystemVerilog, with no TL-Verilog logic.
//   - Visual Debug (VIZ) of SystemVerilog signals (via svSigRef).
//
// (See life_viz.tlv for a TL-Verilog implementation.)
//
// --------------------------------------------------------------------


   m5_makerchip_module

   // Board size (also reflected in VIZ hierarchy, below)
   localparam X_SIZE = 20;
   localparam Y_SIZE = 20;

   // The board, as a packed vector per row.
   logic [X_SIZE-1:0] alive [Y_SIZE-1:0],
                      next_alive [Y_SIZE-1:0];

   always_ff @(posedge clk)
      alive <= next_alive;

   // Number of live neighbors of the cell at (x, y). Off-board cells are dead.
   function automatic logic [3:0] live_neighbors(int x, int y);
      live_neighbors = 4'b0;
      for (int ny = y - 1; ny <= y + 1; ny++)
         for (int nx = x - 1; nx <= x + 1; nx++)
            if (ny >= 0 && ny < Y_SIZE && nx >= 0 && nx < X_SIZE && !(ny == y && nx == x))
               live_neighbors += {3'b0, alive[ny][nx]};
   endfunction

   for (genvar y = 0; y < Y_SIZE; y++) begin : rows
      for (genvar x = 0; x < X_SIZE; x++) begin : cols
         logic [3:0] cnt;
         always_comb
            cnt = live_neighbors(x, y);

         assign next_alive[y][x] =
            reset       ? RW_rand_vect[((y * x) ^ (3 * x + y)) % 257] : // init
            alive[y][x] ? (cnt == 2 || cnt == 3) :                        // stay alive
                          (cnt == 3);                                     // born
      end
   end

   // Stop simulation.
   assign passed = cyc_cnt > 32'd20;
   assign failed = 1'b0;


// ===
// VIZ
// ===

\TLV
   /yy[19:0]
      /xx[19:0]
         \viz_js
            box: {width: 10, height: 10, strokeWidth: 0},
            renderFill() {
               let isAlive = (cycOffset) => (this.svSigRef(`alive[${this.getIndex("yy")}]`, cycOffset).asInt() >> this.getIndex("xx")) & 1
               let alive = isAlive(0)
               let brightness = isAlive(-1) ? 0.8 : 1
               return `rgb(${(alive ? 0 : 255) * brightness}, 0, ${(alive ? 255 : 0) * brightness})`
            }

\SV
   endmodule
