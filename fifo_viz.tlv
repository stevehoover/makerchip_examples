\m5_TLV_version 1d: tl-x.org
\m5
   // =====================================================================
   // FIFO (First-In First-Out) buffer demo.
   //   - Classic synchronous FIFO written in plain Verilog (module `fifo`).
   //   - Wrapped in a Makerchip `top` module with a self-driving testbench.
   //   - A \viz_js Visual-Debug block animates the circular buffer so you
   //     can SEE data being pushed in, queued, and popped out.
   // =====================================================================
\SV
// ---------------------------------------------------------------------
// fifo.sv  --  Synchronous circular-buffer FIFO
// ---------------------------------------------------------------------
module fifo #(
   parameter WIDTH = 8,   // data width in bits
   parameter DEPTH = 8,   // number of storage slots (power of 2)
   parameter AW    = 3    // address width = log2(DEPTH)
) (
   input  wire             clk,
   input  wire             reset,
   input  wire             wr_en,   // request a push
   input  wire             rd_en,   // request a pop
   input  wire [WIDTH-1:0] din,     // data to push
   output wire [WIDTH-1:0] dout,    // data at the front (oldest)
   output wire             full,
   output wire             empty,
   output wire [AW:0]      count    // number of valid entries (0..DEPTH)
);
   // Storage and pointers
   reg [WIDTH-1:0] mem [0:DEPTH-1]; // the buffer memory
   reg [AW-1:0]    head;            // read  pointer -> oldest entry
   reg [AW-1:0]    tail;            // write pointer -> next free slot
   reg [AW:0]      cnt;             // occupancy count

   // A push/pop only "happens" if it is legal this cycle.
   wire do_wr = wr_en && !full;
   wire do_rd = rd_en && !empty;

   // Combinational status / outputs
   assign dout  = mem[head];
   assign full  = (cnt == DEPTH);
   assign empty = (cnt == 0);
   assign count = cnt;

   integer i;
   always @(posedge clk) begin
      if (reset) begin
         head <= 0;
         tail <= 0;
         cnt  <= 0;
         // Clear memory so the visualization starts clean.
         for (i = 0; i < DEPTH; i = i + 1)
            mem[i] <= 0;
      end else begin
         if (do_wr) begin
            mem[tail] <= din;     // store new data at the tail
            tail      <= tail + 1; // advance write pointer (wraps naturally)
         end
         if (do_rd) begin
            head <= head + 1;     // advance read pointer (wraps naturally)
         end
         // Update occupancy: +1 on push-only, -1 on pop-only, 0 if both/neither.
         case ({do_wr, do_rd})
            2'b10:   cnt <= cnt + 1;
            2'b01:   cnt <= cnt - 1;
            default: cnt <= cnt;
         endcase
      end
   end
endmodule


// ---------------------------------------------------------------------
// top  --  Makerchip wrapper: testbench + FIFO instance + Visual Debug
// ---------------------------------------------------------------------
module top(
   input  wire        clk,
   input  wire        reset,
   input  wire [31:0] cyc_cnt,
   output wire        passed,
   output wire        failed
);
   localparam WIDTH = 8;
   localparam DEPTH = 8;

   // Testbench-driven control
   reg              wr_en, rd_en;
   reg  [WIDTH-1:0] next_val;   // running value we push (1, 2, 3, ...)

   // FIFO outputs
   wire [WIDTH-1:0] dout;
   wire             full, empty;
   wire [3:0]       count;

   // Instantiate the device under test
   fifo #(.WIDTH(WIDTH), .DEPTH(DEPTH), .AW(3)) fifo_inst (
      .clk   (clk),
      .reset (reset),
      .wr_en (wr_en),
      .rd_en (rd_en),
      .din   (next_val),
      .dout  (dout),
      .full  (full),
      .empty (empty),
      .count (count)
   );

   // -----------------------------------------------------------------
   // Stimulus schedule (combinational), narrated in three phases:
   //   Phase A  cyc  3..14 : FILL   - push only, FIFO fills then blocks on full
   //   Phase B  cyc 15..19 : DRAIN  - pop only, partially empties the FIFO
   //   Phase C  cyc 20..45 : STREAM - push AND pop, data flows through steadily
   // -----------------------------------------------------------------
   always @(*) begin
      wr_en = 1'b0;
      rd_en = 1'b0;
      if (!reset) begin
         if (cyc_cnt >= 3 && cyc_cnt <= 14) begin
            wr_en = 1'b1;             // FILL
         end else if (cyc_cnt >= 15 && cyc_cnt <= 19) begin
            rd_en = 1'b1;             // DRAIN
         end else if (cyc_cnt >= 20 && cyc_cnt <= 45) begin
            wr_en = 1'b1;             // STREAM
            rd_en = 1'b1;
         end
      end
   end

   // The value we feed in increments after every successful push.
   always @(posedge clk) begin
      if (reset)
         next_val <= 8'd1;
      else if (fifo_inst.do_wr)
         next_val <= next_val + 8'd1;
   end

   // End the simulation cleanly after the demo has played out.
   assign passed = (cyc_cnt > 52);
   assign failed = 1'b0;

\TLV
   // -----------------------------------------------------------------
   // Visual Debug: two synchronized views of the SAME FIFO.
   //   LEFT  - CIRCULAR BUFFER: the mental model. A ring of slots with
   //           no beginning and no end; only the Write (W) and Read (R)
   //           locations matter, and they simply wrap around.
   //   RIGHT - PHYSICAL MEMORY: the reality. The same slots laid out as
   //           a linear array[0..7] the way they actually live in RAM.
   // Watch W and R chase each other around the ring while the identical
   // data fills the flat memory array on the right.
   // -----------------------------------------------------------------
   \viz_js
      box: {width: 100, height: 36, fill: "#0c1021", strokeWidth: 0},
      init() {
         const DEPTH = 8;
         let objs = {};

         // ---- Titles -------------------------------------------------
         objs.title = new fabric.Text("FIFO  (First In, First Out)", {
            left: 50, top: 1.5, originX: "center",
            fontSize: 2.4, fontFamily: "monospace", fill: "#e8eef7"
         });
         objs.phase = new fabric.Text("", {
            left: 50, top: 4.2, originX: "center",
            fontSize: 1.9, fontFamily: "monospace", fill: "#7fd1ff"
         });

         // ================= LEFT: CIRCULAR BUFFER ====================
         const CX = 23, CY = 21, RAD = 9;           // ring geometry
         const angRad = (i) => (-90 + i * 45) * Math.PI / 180;
         const ringPos = (i, r) => ({
            x: CX + r * Math.cos(angRad(i)),
            y: CY + r * Math.sin(angRad(i))
         });

         objs.cheading = new fabric.Text("CIRCULAR BUFFER  (the concept)", {
            left: CX, top: 7, originX: "center",
            fontSize: 1.6, fontFamily: "monospace", fill: "#cfd8e6"
         });
         objs.cnote = new fabric.Text("no beginning, no end - pointers just wrap", {
            left: CX, top: 9.3, originX: "center",
            fontSize: 1.15, fontFamily: "monospace", fill: "#7a8aa0"
         });
         // The loop itself - a faint ring to show "no start, no end".
         objs.ring = new fabric.Circle({
            left: CX, top: CY, radius: RAD, originX: "center", originY: "center",
            fill: "", stroke: "#33405c", strokeWidth: 0.4
         });
         // Circular slots (bubbles around the ring).
         for (let i = 0; i < DEPTH; i++) {
            const p = ringPos(i, RAD);
            objs["cbox" + i] = new fabric.Circle({
               left: p.x, top: p.y, radius: 2.7, originX: "center", originY: "center",
               fill: "#f0f0f0", stroke: "#888", strokeWidth: 0.12
            });
            objs["ctxt" + i] = new fabric.Text("", {
               left: p.x, top: p.y, originX: "center", originY: "center",
               fontSize: 2.0, fontFamily: "monospace", fill: "#222"
            });
            const li = ringPos(i, RAD + 3.9);
            objs["cidx" + i] = new fabric.Text("" + i, {
               left: li.x, top: li.y, originX: "center", originY: "center",
               fontSize: 1.0, fontFamily: "monospace", fill: "#5b6b82"
            });
         }
         // W points inward from OUTSIDE the ring; R points outward from
         // INSIDE, so the two never collide even when head == tail.
         objs.cwtri = new fabric.Triangle({
            left: CX, top: CY - RAD - 2.6, width: 2.4, height: 2.4,
            originX: "center", originY: "center", fill: "#ffb74d"
         });
         objs.cwlbl = new fabric.Text("W", {
            left: CX, top: CY - RAD - 4.8, originX: "center", originY: "center",
            fontSize: 1.7, fontFamily: "monospace", fill: "#ffb74d"
         });
         objs.crtri = new fabric.Triangle({
            left: CX, top: CY - RAD + 2.9, width: 2.4, height: 2.4,
            originX: "center", originY: "center", fill: "#4fc3f7"
         });
         objs.crlbl = new fabric.Text("R", {
            left: CX, top: CY - RAD + 5.1, originX: "center", originY: "center",
            fontSize: 1.7, fontFamily: "monospace", fill: "#4fc3f7"
         });

         // ================= RIGHT: PHYSICAL MEMORY ===================
         const X0 = 45, PITCH = 6.6, BOXW = 5.2, BOXH = 6.2, Y0 = 15;
         objs.mheading = new fabric.Text("PHYSICAL MEMORY  (the reality)", {
            left: 71, top: 7, originX: "center",
            fontSize: 1.6, fontFamily: "monospace", fill: "#cfd8e6"
         });
         objs.mwlbl = new fabric.Text("W (tail)", {
            left: X0, top: 10.0, originX: "center",
            fontSize: 1.35, fontFamily: "monospace", fill: "#ffb74d"
         });
         objs.mwtri = new fabric.Triangle({
            left: X0, top: Y0 - 0.4, width: 2.4, height: 2.4, angle: 180,
            originX: "center", originY: "bottom", fill: "#ffb74d"
         });
         for (let i = 0; i < DEPTH; i++) {
            const x = X0 + i * PITCH;
            objs["mbox" + i] = new fabric.Rect({
               left: x, top: Y0, width: BOXW, height: BOXH,
               fill: "#f0f0f0", stroke: "#888", strokeWidth: 0.12, rx: 0.3, ry: 0.3
            });
            objs["mtxt" + i] = new fabric.Text("", {
               left: x + BOXW / 2, top: Y0 + BOXH / 2, originX: "center", originY: "center",
               fontSize: 2.1, fontFamily: "monospace", fill: "#222"
            });
            objs["midx" + i] = new fabric.Text("[" + i + "]", {
               left: x + BOXW / 2, top: Y0 + BOXH + 0.5, originX: "center",
               fontSize: 1.0, fontFamily: "monospace", fill: "#7a8aa0"
            });
         }
         objs.mrtri = new fabric.Triangle({
            left: X0, top: Y0 + BOXH + 1.9, width: 2.4, height: 2.4, angle: 0,
            originX: "center", fill: "#4fc3f7"
         });
         objs.mrlbl = new fabric.Text("R (head)", {
            left: X0, top: Y0 + BOXH + 4.1, originX: "center",
            fontSize: 1.35, fontFamily: "monospace", fill: "#4fc3f7"
         });

         // ================= BOTTOM-RIGHT: narration ==================
         objs.status = new fabric.Text("", {
            left: 71, top: 27.5, originX: "center",
            fontSize: 1.6, fontFamily: "monospace", fill: "#e8eef7"
         });
         objs.prod = new fabric.Text("", {
            left: 45, top: 30.3, fontSize: 1.35, fontFamily: "monospace", fill: "#a5d6a7"
         });
         objs.cons = new fabric.Text("", {
            left: 45, top: 32.8, fontSize: 1.35, fontFamily: "monospace", fill: "#ef9a9a"
         });
         return objs;
      },
      render() {
         const DEPTH = 8;
         const CX = 23, CY = 21, RAD = 9;
         const angDeg = (i) => -90 + i * 45;
         const angRad = (i) => angDeg(i) * Math.PI / 180;
         const ringPos = (i, r) => ({
            x: CX + r * Math.cos(angRad(i)),
            y: CY + r * Math.sin(angRad(i))
         });
         const X0 = 45, PITCH = 6.6, BOXW = 5.2;
         const memCenter = (i) => X0 + i * PITCH + BOXW / 2;

         let head  = this.sigVal("fifo_inst.head").asInt();
         let tail  = this.sigVal("fifo_inst.tail").asInt();
         let cnt   = this.sigVal("fifo_inst.cnt").asInt();
         let full  = this.sigVal("fifo_inst.full").asBool();
         let empty = this.sigVal("fifo_inst.empty").asBool();
         let din   = this.sigVal("fifo_inst.din").asInt();
         let dout  = this.sigVal("fifo_inst.dout").asInt();
         let wr_en = this.sigVal("fifo_inst.wr_en").asBool();
         let rd_en = this.sigVal("fifo_inst.rd_en").asBool();
         let do_wr = this.sigVal("fifo_inst.do_wr").asBool();
         let do_rd = this.sigVal("fifo_inst.do_rd").asBool();

         // Which physical slots are occupied, and how old is each entry?
         let occ = new Array(DEPTH).fill(false);
         let age = new Array(DEPTH).fill(-1);   // 0 = oldest (front, next out)
         for (let k = 0; k < cnt; k++) {
            let p = (head + k) % DEPTH;
            occ[p] = true;
            age[p] = k;
         }

         // Colour helper shared by both views (oldest = dark, newest = light).
         const shadeFor = (i) => {
            let frac  = cnt > 1 ? age[i] / (cnt - 1) : 0;
            let s = Math.round(120 + 90 * frac);
            return "rgb(46," + s + ",78)";
         };

         for (let i = 0; i < DEPTH; i++) {
            let v = this.sigVal("fifo_inst.mem[" + i + "]").asInt();
            let cbox = this.obj["cbox" + i];
            let ctxt = this.obj["ctxt" + i];
            let mbox = this.obj["mbox" + i];
            let mtxt = this.obj["mtxt" + i];

            if (occ[i]) {
               let fill = shadeFor(i);
               cbox.set({ fill: fill, stroke: "#1b5e20" });
               ctxt.set({ text: "" + v, fill: "#ffffff" });
               mbox.set({ fill: fill, stroke: "#1b5e20" });
               mtxt.set({ text: "" + v, fill: "#ffffff" });
            } else {
               cbox.set({ fill: "#f0f0f0", stroke: "#888" });
               ctxt.set({ text: "", fill: "#222" });
               mbox.set({ fill: "#f0f0f0", stroke: "#888" });
               mtxt.set({ text: "", fill: "#222" });
            }
         }

         // ---- Circular pointers -------------------------------------
         // W: sits outside the ring, apex pointing IN toward its slot.
         let wp = ringPos(tail, RAD + 2.6);
         this.obj.cwtri.set({ left: wp.x, top: wp.y, angle: angDeg(tail) - 90 });
         let wl = ringPos(tail, RAD + 4.8);
         this.obj.cwlbl.set({ left: wl.x, top: wl.y });
         // R: sits inside the ring, apex pointing OUT toward its slot.
         let rp = ringPos(head, RAD - 2.9);
         this.obj.crtri.set({ left: rp.x, top: rp.y, angle: angDeg(head) + 90 });
         let rl = ringPos(head, RAD - 5.1);
         this.obj.crlbl.set({ left: rl.x, top: rl.y });

         // ---- Physical pointers -------------------------------------
         this.obj.mwtri.set({ left: memCenter(tail) });
         this.obj.mwlbl.set({ left: memCenter(tail) });
         this.obj.mrtri.set({ left: memCenter(head) });
         this.obj.mrlbl.set({ left: memCenter(head) });

         // ---- Phase label -------------------------------------------
         let cyc = this.sigVal("cyc_cnt").asInt();
         let phase = "idle";
         if (cyc >= 3 && cyc <= 14)       phase = "PHASE A: FILL  (push only)";
         else if (cyc >= 15 && cyc <= 19) phase = "PHASE B: DRAIN (pop only)";
         else if (cyc >= 20 && cyc <= 45) phase = "PHASE C: STREAM (push + pop)";
         this.obj.phase.set({ text: phase });

         // ---- Producer / Consumer narration -------------------------
         let prodTxt = "PUSH din=" + din + "  ";
         if (do_wr)              prodTxt += "-> stored at slot " + tail;
         else if (wr_en && full) prodTxt += "-> BLOCKED (FIFO full!)";
         else                    prodTxt += "(idle)";
         this.obj.prod.set({
            text: prodTxt,
            fill: do_wr ? "#a5d6a7" : (wr_en && full ? "#ff5252" : "#5b6b82")
         });

         let consTxt = "POP  dout=" + dout + "  ";
         if (do_rd)               consTxt += "<- removed from slot " + head;
         else if (rd_en && empty) consTxt += "<- BLOCKED (FIFO empty!)";
         else                     consTxt += "(idle)";
         this.obj.cons.set({
            text: consTxt,
            fill: do_rd ? "#ef9a9a" : (rd_en && empty ? "#ff5252" : "#5b6b82")
         });

         this.obj.status.set({
            text: "count = " + cnt + " / " + DEPTH +
                  "    full=" + (full ? "1" : "0") +
                  "    empty=" + (empty ? "1" : "0"),
            fill: full ? "#ff5252" : (empty ? "#7a8aa0" : "#e8eef7")
         });
      }
\SV
endmodule
