\m4_TLV_version 1d: tl-x.org
\SV
// ===========================================================================
// mandel_fp_makerchip.v
//
// Single-file, self-contained model of the binary32 Mandelbrot escape-time
// engine, with a self-checking testbench.  Paste the whole thing into
// Makerchip (Verilog/SystemVerilog mode) and run.
//
// ---------------------------------------------------------------------------
// WHAT THIS IS, AND WHAT IT IS NOT
// ---------------------------------------------------------------------------
// This file is a SIMULATION MODEL for bring-up and for reading the whole
// pipeline in one place.  Two blocks differ from the real design:
//
//  1. mandel_seq_model -- the escape-time sequencer.
//     In the real design this is a Hotstate block (blocks/state-machines/
//     Hotstate) programmed by escape_time_sequencer.c and compiled by hotc
//     into hotstate.sv + four .mem files loaded with $readmemh.  Makerchip
//     has no filesystem, so those loads cannot work there.  The FSM below
//     emits the IDENTICAL cycle-by-cycle strobe sequence as the C program:
//     the same mul_sel/as_sel ordering, the same one_shot pulse semantics,
//     and the same polling points (while(!start), while(scan_busy),
//     while(!out_ready), while(start)).  It is a stand-in for simulation.
//     DO NOT paste it back into the project as the sequencer block: control
//     logic in this design is C on a Hotstate engine, by rule.
//
//  2. fp_mult / fp_fused_addsub -- behavioural models of hotc's
//     blocks/math/fp_mult and blocks/math/fp_fused_addsub.  Same contract
//     (binary32 in/out, round-to-nearest-even, flush-to-zero on denormal
//     input and on subnormal result, one quiet NaN 0x7FC00000, purely
//     combinational, no exception flags), implemented with $bitstoshortreal
//     rather than a Booth/Dadda array.  The real blocks are verified
//     against numpy vectors in their own benches; reproducing their
//     internals here would obscure the integration logic this file exists
//     to show.
//
// Everything else -- config_registers, raster_coordinate_generator,
// iteration_datapath, pixel_depth_output -- is the real RTL, written to the
// specs on the canvas.
//
// ---------------------------------------------------------------------------
// THE PIPELINE
// ---------------------------------------------------------------------------
//   AXI4-Lite host -> config_registers -> (x0,y0,dx,dy,esc_r2,w,h,max_iter)
//                                      -> raster_coordinate_generator -> cx,cy
//                                      -> iteration_datapath  (z = z^2 + c)
//                                      -> pixel_depth_output -> AXI4-Stream
//
// Two shared arithmetic blocks serve the whole engine:
//   fp_mult          : zx*zx, zy*zy, zx*zy          (mul_sel)
//   fp_fused_addsub  : xx+yy / xx-yy, 2xy, t+cx, w+cy, and the scanner's
//                      coordinate step                (as_sel / scanner)
//
// NOTE ON THE SHARED ADDER: the canvas gives the scanner its own
// fp_fused_addsub instance (block b4, "Coordinate adder") separate from the
// iteration adder (block b7).  That is what is instantiated here.  They
// could be merged behind a mux, at the cost of an arbitration state in the
// sequencer; they are kept separate to match the canvas.
// ===========================================================================

///`timescale 1ns / 1ps
`default_nettype none
// ===========================================================================
// f32 -- binary32 arithmetic on bit patterns, computed in real (double)
// ===========================================================================
// Makerchip's Verilator treats shortreal as real and lacks $bitstoshortreal /
// $shortrealtobits, so binary32 <-> real conversion is explicit here.
// Contract (shared by fp_mult, fp_fused_addsub and the bench reference):
// round-to-nearest-even, flush-to-zero in and out, single quiet NaN
// 0x7FC00000, no flags.  A double holds a binary32 product exactly; a sum is
// exact unless exponents differ by > 29 (then it may double-round -- harmless
// in this model).
// ===========================================================================
package f32;
    localparam [31:0] QNAN = 32'h7FC00000;
    function automatic bit is_nan(input [31:0] v); return v[30:23] == 8'hFF && v[22:0] != 0; endfunction
    function automatic bit is_inf(input [31:0] v); return v[30:23] == 8'hFF && v[22:0] == 0; endfunction
    // denormal (exp==0) reads as a zero of the same sign
    function automatic [31:0] ftz(input [31:0] v); return v[30:23] == 0 ? {v[31], 31'd0} : v; endfunction

    // finite, flushed binary32 -> real (exact)
    function automatic real to_real(input [31:0] v);
        return $bitstoreal(v[30:0] == 0 ? {v[31], 63'd0}
                                        : {v[31], 11'(v[30:23]) + 11'd896, v[22:0], 29'd0});
    endfunction

    // finite real -> binary32, RNE, FTZ on underflow, Inf on overflow
    function automatic [31:0] from_real(input real r);
        reg [63:0] d;  reg [24:0] m;  integer e;
        d = $realtobits(r);
        e = int'(d[62:52]) - 896;
        m = {2'b01, d[51:29]} + {24'd0, d[28] & (d[29] | (|d[27:0]))};
        if (m[24]) begin m = m >> 1; e = e + 1; end
        if (e <= 0)   return {d[63], 31'd0};
        if (e >= 255) return {d[63], 8'hFF, 23'd0};
        return {d[63], e[7:0], m[22:0]};
    endfunction

    function automatic [31:0] mul(input [31:0] a, input [31:0] b);
        reg [31:0] x, y;
        x = ftz(a);  y = ftz(b);
        if (is_nan(x) || is_nan(y)) return QNAN;
        if (is_inf(x) || is_inf(y))
            return (x[30:0] == 0 || y[30:0] == 0) ? QNAN                    // 0 * inf
                                                  : {x[31]^y[31], 8'hFF, 23'd0};
        return from_real(to_real(x) * to_real(y));
    endfunction

    function automatic [31:0] add(input [31:0] a, input [31:0] b);
        reg [31:0] x, y, s;
        x = ftz(a);  y = ftz(b);
        if (is_nan(x) || is_nan(y) || (is_inf(x) && is_inf(y) && x[31] != y[31])) return QNAN;
        if (is_inf(x)) return x;
        if (is_inf(y)) return y;
        s = from_real(to_real(x) + to_real(y));
        return s[30:0] == 0 ? 32'h0 : s;                   // cancellation -> +0
    endfunction

    function automatic [31:0] neg(input [31:0] v); return {~v[31], v[30:0]}; endfunction
endpackage


// ===========================================================================
// fp_mult -- BEHAVIOURAL MODEL of blocks/math/fp_mult
// ===========================================================================
// Combinational binary32 multiply.  Round-to-nearest-even, flush-to-zero in
// both directions, single quiet NaN, no exception flags.
// ===========================================================================
module fp_mult (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] y
);
    assign y = f32::mul(a, b);
endmodule


// ===========================================================================
// fp_fused_addsub -- BEHAVIOURAL MODEL of blocks/math/fp_fused_addsub
// ===========================================================================
// s = a + b and d = a - b from one exponent compare and one alignment shift.
// Round-to-nearest-even, flush-to-zero, single quiet NaN, no flags.
// An exact cancellation gives +0, never -0 (RNE requires it).
// ===========================================================================
module fp_fused_addsub (
    input  wire [31:0] a,
    input  wire [31:0] b,
    output wire [31:0] s,
    output wire [31:0] d
);
    assign s = f32::add(a, b);
    assign d = f32::add(a, f32::neg(b));
endmodule


// ===========================================================================
// config_registers -- AXI4-Lite CSR block (real RTL, from the canvas)
// ===========================================================================
// 0x00 X0   0x04 Y0   0x08 DX   0x0C DY
// 0x10 WIDTH  0x14 HEIGHT  0x18 MAX_ITER  0x1C ESC_R2
// 0x20 CTRL   bit0 START (level; cleared by this block on rising done)
// 0x24 STATUS bit0 BUSY (RO)  bit1 DONE (sticky, W1C)
// Config registers are frozen while BUSY.
// ===========================================================================
module config_registers (
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,

    input  wire [5:0]  s_axi_awaddr,
    input  wire [2:0]  s_axi_awprot,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,

    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,

    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,

    input  wire [5:0]  s_axi_araddr,
    input  wire [2:0]  s_axi_arprot,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,

    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    input  wire        busy_i,
    input  wire        done_i,

    output wire [31:0] x0,
    output wire [31:0] y0,
    output wire [31:0] dx,
    output wire [31:0] dy,
    output wire [31:0] esc_r2,
    output wire [15:0] width,
    output wire [15:0] height,
    output wire [15:0] max_iter,
    output wire        start,
    output wire        irq_out
);
    localparam [3:0] A_X0=4'h0, A_Y0=4'h1, A_DX=4'h2, A_DY=4'h3,
                     A_WIDTH=4'h4, A_HEIGHT=4'h5, A_MAXITER=4'h6,
                     A_ESCR2=4'h7, A_CTRL=4'h8, A_STATUS=4'h9;
    localparam [1:0] RESP_OKAY=2'b00, RESP_SLVERR=2'b10;

    reg [31:0] x0_r, y0_r, dx_r, dy_r, esc_r2_r;
    reg [15:0] width_r, height_r, max_iter_r;
    reg        start_r, done_sticky_r, done_q;
    wire       done_rise = done_i & ~done_q;

    reg [5:0]  awaddr_q;  reg awaddr_v;
    reg [31:0] wdata_q;   reg wdata_v;
    reg        bvalid_r;  reg [1:0] bresp_r;

    wire aw_accept = s_axi_awvalid & s_axi_awready;
    wire w_accept  = s_axi_wvalid  & s_axi_wready;

    assign s_axi_awready = ~awaddr_v & ~bvalid_r;
    assign s_axi_wready  = ~wdata_v  & ~bvalid_r;
    assign s_axi_bresp   = bresp_r;
    assign s_axi_bvalid  = bvalid_r;

    wire [5:0]  wr_addr   = awaddr_v ? awaddr_q : s_axi_awaddr;
    wire [31:0] wr_data   = wdata_v  ? wdata_q  : s_axi_wdata;
    wire        wr_fire   = ~bvalid_r & (awaddr_v | aw_accept)
                                      & (wdata_v  | w_accept);
    wire        wr_mapped = (wr_addr[1:0]==2'b00) && (wr_addr[5:2] <= A_STATUS);

    reg [31:0] rdata_r;  reg [1:0] rresp_r;  reg rvalid_r;
    assign s_axi_arready = ~rvalid_r;
    assign s_axi_rdata   = rdata_r;
    assign s_axi_rresp   = rresp_r;
    assign s_axi_rvalid  = rvalid_r;

    wire ar_accept = s_axi_arvalid & s_axi_arready;
    wire rd_mapped = (s_axi_araddr[1:0]==2'b00) && (s_axi_araddr[5:2] <= A_STATUS);

    reg [31:0] rd_mux;
    always @* begin
        case (s_axi_araddr[5:2])
            A_X0      : rd_mux = x0_r;
            A_Y0      : rd_mux = y0_r;
            A_DX      : rd_mux = dx_r;
            A_DY      : rd_mux = dy_r;
            A_WIDTH   : rd_mux = {16'h0, width_r};
            A_HEIGHT  : rd_mux = {16'h0, height_r};
            A_MAXITER : rd_mux = {16'h0, max_iter_r};
            A_ESCR2   : rd_mux = esc_r2_r;
            A_CTRL    : rd_mux = {31'd0, start_r};
            A_STATUS  : rd_mux = {30'd0, done_sticky_r, busy_i};
            default   : rd_mux = 32'h0;
        endcase
    end

    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            x0_r<=0; y0_r<=0; dx_r<=0; dy_r<=0;
            esc_r2_r <= 32'h40800000;            // 4.0
            width_r<=1; height_r<=1; max_iter_r<=255;
            start_r<=0; done_sticky_r<=0; done_q<=0;
            awaddr_q<=0; awaddr_v<=0; wdata_q<=0; wdata_v<=0;
            bvalid_r<=0; bresp_r<=RESP_OKAY;
            rdata_r<=0; rresp_r<=RESP_OKAY; rvalid_r<=0;
        end else begin
            done_q <= done_i;

            if (aw_accept) begin awaddr_q <= s_axi_awaddr; awaddr_v <= 1'b1; end
            if (w_accept)  begin wdata_q  <= s_axi_wdata;  wdata_v  <= 1'b1; end

            if (wr_fire) begin
                awaddr_v <= 1'b0;  wdata_v <= 1'b0;
                bvalid_r <= 1'b1;
                bresp_r  <= wr_mapped ? RESP_OKAY : RESP_SLVERR;
                if (wr_mapped) begin
                    case (wr_addr[5:2])
                        A_X0      : if (!busy_i) x0_r       <= wr_data;
                        A_Y0      : if (!busy_i) y0_r       <= wr_data;
                        A_DX      : if (!busy_i) dx_r       <= wr_data;
                        A_DY      : if (!busy_i) dy_r       <= wr_data;
                        A_WIDTH   : if (!busy_i) width_r    <= (wr_data[15:0]==0) ? 16'd1 : wr_data[15:0];
                        A_HEIGHT  : if (!busy_i) height_r   <= (wr_data[15:0]==0) ? 16'd1 : wr_data[15:0];
                        A_MAXITER : if (!busy_i) max_iter_r <= wr_data[15:0];
                        A_ESCR2   : if (!busy_i) esc_r2_r   <= wr_data;
                        A_CTRL    : start_r <= wr_data[0];
                        A_STATUS  : if (wr_data[1]) done_sticky_r <= 1'b0;
                        default   : ;
                    endcase
                end
            end
            if (bvalid_r && s_axi_bready) bvalid_r <= 1'b0;

            // the done edge wins over a host write in the same cycle
            if (done_rise) begin
                start_r       <= 1'b0;
                done_sticky_r <= 1'b1;
            end

            if (ar_accept) begin
                rdata_r  <= rd_mapped ? rd_mux : 32'h0;
                rresp_r  <= rd_mapped ? RESP_OKAY : RESP_SLVERR;
                rvalid_r <= 1'b1;
            end else if (rvalid_r && s_axi_rready) begin
                rvalid_r <= 1'b0;
            end
        end
    end

    assign x0=x0_r; assign y0=y0_r; assign dx=dx_r; assign dy=dy_r;
    assign esc_r2=esc_r2_r; assign width=width_r; assign height=height_r;
    assign max_iter=max_iter_r; assign start=start_r; assign irq_out=done_sticky_r;
endmodule


// ===========================================================================
// raster_coordinate_generator -- mandel_fp_scan (real RTL, written to spec)
// ===========================================================================
// Walks a width x height raster producing (cx, cy) by repeated addition on
// the shared coordinate adder.  Rounding accumulates along a row; the exact
// form x0 + col*dx would need a second multiplier and is not taken.
//
// scan_busy asserts COMBINATIONALLY with scan_rst/scan_step, so the
// sequencer's "while (scan_busy) {}" cannot fall straight through.
// ===========================================================================
module raster_coordinate_generator #(
    parameter integer ADD_LATENCY = 0      // 0 = combinational adder
)(
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] x0,
    input  wire [31:0] y0,
    input  wire [31:0] dx,
    input  wire [31:0] dy,
    input  wire [15:0] width,
    input  wire [15:0] height,

    input  wire        scan_rst,
    input  wire        scan_step,

    input  wire [31:0] add_s,
    output reg  [31:0] add_a,
    output reg  [31:0] add_b,

    output reg  [31:0] cx,
    output reg  [31:0] cy,

    output wire        scan_busy,
    output wire        frame_done
);
    reg [15:0] col, row;
    reg        pend, adv_row;
    reg [7:0]  cnt;

    wire last_col = (col == (width  - 16'd1));
    wire last_row = (row == (height - 16'd1));

    assign frame_done = last_row & last_col;
    assign scan_busy  = scan_rst | scan_step | pend;

    always @(posedge clk) begin
        if (rst) begin
            cx<=0; cy<=0; col<=0; row<=0;
            add_a<=0; add_b<=0; pend<=0; adv_row<=0; cnt<=0;
        end else if (scan_rst) begin
            cx<=x0; cy<=y0; col<=0; row<=0;
            pend<=0; adv_row<=0; cnt<=0;
        end else if (scan_step && !pend) begin
            adv_row <= last_col;
            add_a   <= last_col ? cy : cx;
            add_b   <= last_col ? dy : dx;
            pend    <= 1'b1;
            cnt     <= ADD_LATENCY[7:0];
        end else if (pend) begin
            if (cnt != 8'd0) cnt <= cnt - 8'd1;
            else begin
                pend <= 1'b0;
                if (adv_row) begin
                    cy <= add_s; cx <= x0; col <= 16'd0; row <= row + 16'd1;
                end else begin
                    cx <= add_s; col <= col + 16'd1;
                end
            end
        end
    end
endmodule


// ===========================================================================
// iteration_datapath -- mandel_fp_iter_dp (real RTL, from the canvas)
// ===========================================================================
// z' = z^2 + c through one shared multiplier and one shared fused add/sub.
// Operand registers are reloaded every clock from the current select, so the
// combinational float path sits between two flip-flops.
//
// The escape test is an UNSIGNED integer compare of two non-negative
// binary32 patterns -- ordered like the reals, with +Inf and NaN above every
// finite value, which is exactly the escape we want.
// ===========================================================================
module iteration_datapath (
    input  wire        clk,
    input  wire        rst,

    input  wire [31:0] cx,
    input  wire [31:0] cy,
    input  wire [31:0] esc_r2,
    input  wire [15:0] max_iter,

    input  wire [31:0] mul_p,
    input  wire [31:0] as_s,
    input  wire [31:0] as_d,

    input  wire        z_clear,
    input  wire [1:0]  mul_sel,
    input  wire [1:0]  as_sel,
    input  wire        ld_xx,
    input  wire        ld_yy,
    input  wire        ld_xy,
    input  wire        ld_mag,
    input  wire        ld_w,
    input  wire        ld_zx,
    input  wire        ld_zy,
    input  wire        iter_tick,

    output wire [31:0] mul_a,
    output wire [31:0] mul_b,
    output wire [31:0] as_a,
    output wire [31:0] as_b,

    output wire [15:0] iter_count,
    output wire        escaped,
    output wire        iter_limit
);
    reg [31:0] zx_r, zy_r, cx_lr, cy_lr;
    reg [31:0] xx_r, yy_r, xy_r, t_r, w_r, mag_r;
    reg [15:0] iter_r;
    reg        esc_r;
    reg [31:0] mul_a_r, mul_b_r, as_a_r, as_b_r;

    reg [31:0] mul_a_nxt, mul_b_nxt, as_a_nxt, as_b_nxt;

    always @* begin
        case (mul_sel)
            2'd0: begin mul_a_nxt=zx_r; mul_b_nxt=zx_r; end   // zx*zx
            2'd1: begin mul_a_nxt=zy_r; mul_b_nxt=zy_r; end   // zy*zy
            default: begin mul_a_nxt=zx_r; mul_b_nxt=zy_r; end // zx*zy
        endcase
    end

    always @* begin
        case (as_sel)
            2'd0: begin as_a_nxt=xx_r; as_b_nxt=yy_r;  end    // xx+yy / xx-yy
            2'd1: begin as_a_nxt=xy_r; as_b_nxt=xy_r;  end    // 2*xy
            2'd2: begin as_a_nxt=t_r;  as_b_nxt=cx_lr; end    // t + cx
            default: begin as_a_nxt=w_r; as_b_nxt=cy_lr; end  // w + cy
        endcase
    end

    wire esc_now = (as_s > esc_r2);        // unsigned pattern compare

    always @(posedge clk) begin
        if (rst) begin
            zx_r<=0; zy_r<=0; cx_lr<=0; cy_lr<=0;
            xx_r<=0; yy_r<=0; xy_r<=0; t_r<=0; w_r<=0; mag_r<=0;
            iter_r<=0; esc_r<=0;
            mul_a_r<=0; mul_b_r<=0; as_a_r<=0; as_b_r<=0;
        end else begin
            mul_a_r <= mul_a_nxt;  mul_b_r <= mul_b_nxt;
            as_a_r  <= as_a_nxt;   as_b_r  <= as_b_nxt;

            if (z_clear) begin
                zx_r<=0; zy_r<=0; iter_r<=0; esc_r<=0;
                cx_lr <= cx;  cy_lr <= cy;
            end else begin
                if (ld_xx) xx_r <= mul_p;
                if (ld_yy) yy_r <= mul_p;
                if (ld_xy) xy_r <= mul_p;
                if (ld_mag) begin
                    mag_r <= as_s;   // xx + yy
                    t_r   <= as_d;   // xx - yy
                    esc_r <= esc_now;
                end
                if (ld_w)  w_r  <= as_s;
                if (ld_zx) zx_r <= as_s;
                if (ld_zy) zy_r <= as_s;
                if (iter_tick) iter_r <= iter_r + 16'd1;
            end
        end
    end

    assign mul_a=mul_a_r; assign mul_b=mul_b_r;
    assign as_a=as_a_r;   assign as_b=as_b_r;
    assign iter_count=iter_r;
    assign escaped=esc_r;
    assign iter_limit=(iter_r == max_iter);
endmodule


// ===========================================================================
// pixel_depth_output -- mandel_px_out (real RTL, from the canvas)
// ===========================================================================
// 32 x 17 FIFO of {last, iter_count}, first-word fall-through, AXI4-Stream
// master out.  out_ready is a registered !full computed from the NEXT
// occupancy, so it is never optimistic.
// ===========================================================================
module pixel_depth_output (
    input  wire        clk,
    input  wire        rst,

    input  wire [15:0] iter_count,
    input  wire        px_valid,
    input  wire        px_last,
    output reg         out_ready,

    output wire [15:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast
);
    localparam integer DEPTH = 32;
    localparam integer AW    = 5;
    localparam integer DW    = 17;

    reg [DW-1:0] mem [0:DEPTH-1];
    reg [AW-1:0] wr_ptr, rd_ptr;
    reg [AW:0]   count;

    wire full  = (count == DEPTH[AW:0]);
    wire empty = (count == {(AW+1){1'b0}});

    wire do_push = px_valid & ~full;
    wire do_pop  = m_axis_tvalid & m_axis_tready;

    reg [AW:0] count_nxt;
    always @* begin
        case ({do_push, do_pop})
            2'b10:   count_nxt = count + 1'b1;
            2'b01:   count_nxt = count - 1'b1;
            default: count_nxt = count;
        endcase
    end

    always @(posedge clk) if (do_push) mem[wr_ptr] <= {px_last, iter_count};

    always @(posedge clk) begin
        if (rst) begin
            wr_ptr<=0; rd_ptr<=0; count<=0; out_ready<=1'b0;
        end else begin
            if (do_push) wr_ptr <= wr_ptr + 1'b1;
            if (do_pop)  rd_ptr <= rd_ptr + 1'b1;
            count     <= count_nxt;
            out_ready <= (count_nxt != DEPTH[AW:0]);
        end
    end

    wire [DW-1:0] head = mem[rd_ptr];
    assign m_axis_tvalid = ~empty;
    assign m_axis_tdata  = head[15:0];
    assign m_axis_tlast  = head[16];
endmodule


// ===========================================================================
// mandel_seq_model -- SIMULATION STAND-IN for the Hotstate sequencer
// ===========================================================================
// Reproduces escape_time_sequencer.c cycle for cycle.  The C, for reference:
//
//   void iterate() {
//     while (1) {
//       mul_sel = 0;                 // operands <= (zx,zx)
//       mul_sel = 1, ld_xx = 1;      // xx <= zx*zx,  operands <= (zy,zy)
//       mul_sel = 2, ld_yy = 1;      // yy <= zy*zy,  operands <= (zx,zy)
//       as_sel  = 0, ld_xy = 1;      // xy <= zx*zy,  add/sub <= (xx,yy)
//       as_sel  = 1, ld_mag = 1;     // mag,t,escape; add/sub <= (xy,xy)
//       as_sel  = 2, ld_w   = 1;     // w <= 2*zx*zy, add/sub <= (t,cx)
//       if (escaped)    { break; }   // (escaped is loaded by ld_mag, one
//       if (iter_limit) { break; }   //  statement back, not the one before)
//       as_sel = 3, ld_zx = 1;       // zx <= t+cx,   add/sub <= (w,cy)
//       iter_tick = 1, ld_zy = 1;    // zy <= w+cy,   iter++
//     }
//   }
//
//   void main() {
//     while (1) {
//       busy = 0, done = 0;
//       while (!start) {}
//       busy = 1;
//       scan_rst = 1;
//       while (scan_busy) {}
//       while (1) {
//         z_clear = 1;
//         iterate();
//         while (!out_ready) {}
//         if (frame_done) { px_valid = 1, px_last = 1; break; }
//         px_valid = 1;
//         scan_step = 1;
//         while (scan_busy) {}
//       }
//       busy = 0, done = 1;
//       while (start) {}
//     }
//   }
//
// Every one_shot output below is driven from a single always block and
// defaults to 0 each cycle, matching hotc's ONE_SHOT_MASK behaviour.
// ===========================================================================
module mandel_seq_model (
    input  wire       clk,
    input  wire       rst,

    input  wire       start,
    input  wire       escaped,
    input  wire       iter_limit,
    input  wire       frame_done,
    input  wire       scan_busy,
    input  wire       out_ready,

    output reg        busy,
    output reg        done,

    output reg        scan_rst,
    output reg        scan_step,
    output reg        z_clear,
    output reg        ld_xx,
    output reg        ld_yy,
    output reg        ld_xy,
    output reg        ld_mag,
    output reg        ld_w,
    output reg        ld_zx,
    output reg        ld_zy,
    output reg        iter_tick,
    output reg        px_valid,
    output reg        px_last,

    output reg [1:0]  mul_sel,
    output reg [1:0]  as_sel
);
    localparam [4:0]
        S_IDLE      = 5'd0,   // busy=0,done=0; while(!start)
        S_SCANRST   = 5'd1,   // scan_rst=1
        S_SCANW0    = 5'd2,   // while(scan_busy) after reset
        S_ZCLEAR    = 5'd3,   // z_clear=1
        S_M0        = 5'd4,   // mul_sel=0
        S_M1        = 5'd5,   // mul_sel=1, ld_xx
        S_M2        = 5'd6,   // mul_sel=2, ld_yy
        S_A0        = 5'd7,   // as_sel=0,  ld_xy
        S_A1        = 5'd8,   // as_sel=1,  ld_mag
        S_A2        = 5'd9,   // as_sel=2,  ld_w
        S_TEST      = 5'd10,  // if(escaped) / if(iter_limit)
        S_A3        = 5'd11,  // as_sel=3,  ld_zx
        S_TICK      = 5'd12,  // iter_tick, ld_zy
        S_WOUT      = 5'd13,  // while(!out_ready)
        S_EMIT      = 5'd14,  // px_valid (+px_last on the last pixel)
        S_STEP      = 5'd15,  // scan_step=1
        S_SCANW1    = 5'd16,  // while(scan_busy) after a step
        S_DONE      = 5'd17;  // busy=0,done=1; while(start)

    reg [4:0] st;

    always @(posedge clk) begin
        // one_shot defaults -- every pulse output clears unless driven below
        scan_rst<=0; scan_step<=0; z_clear<=0;
        ld_xx<=0; ld_yy<=0; ld_xy<=0; ld_mag<=0;
        ld_w<=0; ld_zx<=0; ld_zy<=0; iter_tick<=0;
        px_valid<=0; px_last<=0;

        if (rst) begin
            st<=S_IDLE; busy<=0; done<=0; mul_sel<=0; as_sel<=0;
        end else begin
            case (st)
            S_IDLE: begin
                busy <= 1'b0; done <= 1'b0;
                if (start) begin busy <= 1'b1; st <= S_SCANRST; end
            end
            S_SCANRST: begin scan_rst <= 1'b1; st <= S_SCANW0; end
            S_SCANW0 : if (!scan_busy) st <= S_ZCLEAR;
            S_ZCLEAR : begin z_clear <= 1'b1; st <= S_M0; end

            S_M0: begin mul_sel <= 2'd0;                 st <= S_M1; end
            S_M1: begin mul_sel <= 2'd1; ld_xx  <= 1'b1; st <= S_M2; end
            S_M2: begin mul_sel <= 2'd2; ld_yy  <= 1'b1; st <= S_A0; end
            S_A0: begin as_sel  <= 2'd0; ld_xy  <= 1'b1; st <= S_A1; end
            S_A1: begin as_sel  <= 2'd1; ld_mag <= 1'b1; st <= S_A2; end
            // Outputs are registered, so ld_mag takes effect while in S_A2,
            // and esc_r is valid in S_TEST.
            S_A2: begin as_sel  <= 2'd2; ld_w   <= 1'b1; st <= S_TEST; end

            S_TEST: if (escaped || iter_limit) st <= S_WOUT;
                    else                       st <= S_A3;

            S_A3  : begin as_sel <= 2'd3; ld_zx <= 1'b1; st <= S_TICK; end
            S_TICK: begin iter_tick <= 1'b1; ld_zy <= 1'b1; st <= S_M0; end

            S_WOUT: if (out_ready) st <= S_EMIT;

            S_EMIT: begin
                px_valid <= 1'b1;
                if (frame_done) begin px_last <= 1'b1; st <= S_DONE; end
                else                                   st <= S_STEP;
            end

            S_STEP  : begin scan_step <= 1'b1; st <= S_SCANW1; end
            S_SCANW1: if (!scan_busy) st <= S_ZCLEAR;

            S_DONE: begin
                busy <= 1'b0; done <= 1'b1;
                if (!start) st <= S_IDLE;     // CSR clears START on done
            end

            default: st <= S_IDLE;
            endcase
        end
    end
endmodule


// ===========================================================================
// mandel_fp_top -- the whole engine wired as the canvas has it
// ===========================================================================
module mandel_fp_top (
    input  wire        clk,
    input  wire        rst,          // synchronous, active high

    input  wire [5:0]  s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output wire        s_axi_awready,
    input  wire [31:0] s_axi_wdata,
    input  wire        s_axi_wvalid,
    output wire        s_axi_wready,
    output wire [1:0]  s_axi_bresp,
    output wire        s_axi_bvalid,
    input  wire        s_axi_bready,
    input  wire [5:0]  s_axi_araddr,
    input  wire        s_axi_arvalid,
    output wire        s_axi_arready,
    output wire [31:0] s_axi_rdata,
    output wire [1:0]  s_axi_rresp,
    output wire        s_axi_rvalid,
    input  wire        s_axi_rready,

    output wire [15:0] m_axis_tdata,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire        m_axis_tlast,

    output wire        irq_out
);
    wire [31:0] x0, y0, dx, dy, esc_r2;
    wire [15:0] width, height, max_iter;
    wire        start, busy, done;

    wire        scan_rst, scan_step, scan_busy, frame_done;
    wire [31:0] cx, cy;
    wire [31:0] sc_add_a, sc_add_b, sc_add_s, sc_add_d;

    wire        z_clear, ld_xx, ld_yy, ld_xy, ld_mag, ld_w, ld_zx, ld_zy;
    wire        iter_tick, px_valid, px_last, out_ready;
    wire [1:0]  mul_sel, as_sel;
    wire        escaped, iter_limit;
    wire [15:0] iter_count;

    wire [31:0] mul_a, mul_b, mul_p;
    wire [31:0] as_a, as_b, as_s, as_d;

    // b1 : config registers
    config_registers u_csr (
        .s_axi_aclk(clk), .s_axi_aresetn(~rst),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awprot(3'b000),
        .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(4'hF),
        .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arprot(3'b000),
        .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .busy_i(busy), .done_i(done),
        .x0(x0), .y0(y0), .dx(dx), .dy(dy), .esc_r2(esc_r2),
        .width(width), .height(height), .max_iter(max_iter),
        .start(start), .irq_out(irq_out)
    );

    // b2 : escape-time sequencer (Hotstate in the real design)
    mandel_seq_model u_seq (
        .clk(clk), .rst(rst),
        .start(start), .escaped(escaped), .iter_limit(iter_limit),
        .frame_done(frame_done), .scan_busy(scan_busy), .out_ready(out_ready),
        .busy(busy), .done(done),
        .scan_rst(scan_rst), .scan_step(scan_step), .z_clear(z_clear),
        .ld_xx(ld_xx), .ld_yy(ld_yy), .ld_xy(ld_xy), .ld_mag(ld_mag),
        .ld_w(ld_w), .ld_zx(ld_zx), .ld_zy(ld_zy), .iter_tick(iter_tick),
        .px_valid(px_valid), .px_last(px_last),
        .mul_sel(mul_sel), .as_sel(as_sel)
    );

    // b3 : raster coordinate generator
    raster_coordinate_generator #(.ADD_LATENCY(0)) u_scan (
        .clk(clk), .rst(rst),
        .x0(x0), .y0(y0), .dx(dx), .dy(dy),
        .width(width), .height(height),
        .scan_rst(scan_rst), .scan_step(scan_step),
        .add_s(sc_add_s), .add_a(sc_add_a), .add_b(sc_add_b),
        .cx(cx), .cy(cy),
        .scan_busy(scan_busy), .frame_done(frame_done)
    );

    // b4 : coordinate adder (its d output is unused -- DX/DY carry sign)
    fp_fused_addsub u_coord_add (
        .a(sc_add_a), .b(sc_add_b), .s(sc_add_s), .d(sc_add_d)
    );

    // b5 : iteration datapath
    iteration_datapath u_dp (
        .clk(clk), .rst(rst),
        .cx(cx), .cy(cy), .esc_r2(esc_r2), .max_iter(max_iter),
        .mul_p(mul_p), .as_s(as_s), .as_d(as_d),
        .z_clear(z_clear), .mul_sel(mul_sel), .as_sel(as_sel),
        .ld_xx(ld_xx), .ld_yy(ld_yy), .ld_xy(ld_xy), .ld_mag(ld_mag),
        .ld_w(ld_w), .ld_zx(ld_zx), .ld_zy(ld_zy), .iter_tick(iter_tick),
        .mul_a(mul_a), .mul_b(mul_b), .as_a(as_a), .as_b(as_b),
        .iter_count(iter_count), .escaped(escaped), .iter_limit(iter_limit)
    );

    // b6 : shared float multiplier
    fp_mult u_mul (.a(mul_a), .b(mul_b), .y(mul_p));

    // b7 : shared fused add/sub
    fp_fused_addsub u_as (.a(as_a), .b(as_b), .s(as_s), .d(as_d));

    // b8 : pixel depth output FIFO + AXI4-Stream master
    pixel_depth_output u_out (
        .clk(clk), .rst(rst),
        .iter_count(iter_count), .px_valid(px_valid), .px_last(px_last),
        .out_ready(out_ready),
        .m_axis_tdata(m_axis_tdata), .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready), .m_axis_tlast(m_axis_tlast)
    );
endmodule

module top (
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] cyc_cnt,
    output wire        passed,
    output wire        failed
);

   // ---- engine under test -------------------------------------------------
   // AXI4-Lite config port
   reg  [5:0]  awaddr;  reg        awvalid;  wire awready;
   reg  [31:0] wdata;   reg        wvalid;   wire wready;
   wire [1:0]  bresp;   wire       bvalid;   reg  bready;
   reg  [5:0]  araddr;  reg        arvalid;  wire arready;
   wire [31:0] rdata;   wire [1:0] rresp;    wire rvalid;  reg rready;

   // AXI4-Stream pixel output
   wire [15:0] tdata;   wire       tvalid;   reg  tready;  wire tlast;
   wire        irq;

   mandel_fp_top dut (
      .clk(clk), .rst(reset),
      .s_axi_awaddr(awaddr), /*.s_axi_awprot(3'b000),*/ .s_axi_awvalid(awvalid), .s_axi_awready(awready),
      .s_axi_wdata(wdata),   /*.s_axi_wstrb(4'hF),*/    .s_axi_wvalid(wvalid),   .s_axi_wready(wready),
      .s_axi_bresp(bresp),   .s_axi_bvalid(bvalid), .s_axi_bready(bready),
      .s_axi_araddr(araddr), /*.s_axi_arprot(3'b000),*/ .s_axi_arvalid(arvalid), .s_axi_arready(arready),
      .s_axi_rdata(rdata),   .s_axi_rresp(rresp),   .s_axi_rvalid(rvalid),   .s_axi_rready(rready),
      .m_axis_tdata(tdata),  .m_axis_tvalid(tvalid),.m_axis_tready(tready),  .m_axis_tlast(tlast),
      .irq_out(irq)
   );

   // ---- frame geometry ----------------------------------------------------
   localparam integer W    = 8;
   localparam integer H    = 6;
   localparam integer MAXI = 20;
   localparam integer NP   = W*H;
   localparam integer IW   = $clog2(NP+1);
   localparam [31:0] F_X0  = 32'hC0000000;  // -2.0
   localparam [31:0] F_Y0  = 32'h3FA00000;  //  1.25
   localparam [31:0] F_DX  = 32'h3EC00000;  //  0.375
   localparam [31:0] F_DY  = 32'hBF000000;  // -0.5
   localparam [31:0] F_ER2 = 32'h40800000;  //  4.0

   // ---- reference model: the same binary32 recurrence and escape test -----
   reg [15:0] expect_d [0:NP-1];
   integer    r, c, k;
   reg [31:0] rx, ry, zx, zy, xx, yy, xy;
   initial begin
      ry = F_Y0;
      for (r = 0; r < H; r = r + 1) begin
         rx = F_X0;
         for (c = 0; c < W; c = c + 1) begin
            zx = 0; zy = 0; k = 0;
            forever begin
               xx = f32::mul(zx, zx);  yy = f32::mul(zy, zy);  xy = f32::mul(zx, zy);
               if (f32::add(xx, yy) > F_ER2) break;   // unsigned pattern compare, as in hardware
               if (k == MAXI)                break;
               zx = f32::add(f32::add(xx, f32::neg(yy)), rx);
               zy = f32::add(f32::add(xy, xy), ry);
               k  = k + 1;
            end
            expect_d[r*W + c] = k[15:0];
            rx = f32::add(rx, F_DX);               // same repeated-addition drift as the scanner
         end
         ry = f32::add(ry, F_DY);
      end
   end

   // ---- bench sequencer ---------------------------------------------------
   localparam S_CFG = 0, S_RUN = 1, S_DRAIN = 2, S_CHECK = 3, S_DONE = 4, S_FAIL = 5;
   reg [2:0]    st;
   reg [3:0]    cfg_i;     // which config register we are writing
   reg [15:0]   got_d [0:NP-1];
   reg [IW-1:0] np;        // pixels collected
   reg [IW-1:0] ci;        // check index
   reg          saw_last;
   reg          bp_done;   // back-pressure stall released
   reg [31:0]   guard;

   reg [5:0]  cfg_a; reg [31:0] cfg_v;
   always @* begin
      case (cfg_i)
         4'd0: begin cfg_a = 6'h00; cfg_v = F_X0;              end
         4'd1: begin cfg_a = 6'h04; cfg_v = F_Y0;              end
         4'd2: begin cfg_a = 6'h08; cfg_v = F_DX;              end
         4'd3: begin cfg_a = 6'h0C; cfg_v = F_DY;              end
         4'd4: begin cfg_a = 6'h10; cfg_v = W;                 end
         4'd5: begin cfg_a = 6'h14; cfg_v = H;                 end
         4'd6: begin cfg_a = 6'h18; cfg_v = MAXI;              end
         4'd7: begin cfg_a = 6'h1C; cfg_v = F_ER2;             end
         default: begin cfg_a = 6'h20; cfg_v = 32'h00000001;   end // CTRL.START
      endcase
   end

   wire w_done = awvalid && awready && wvalid && wready;

   always @(posedge clk) begin
      if (reset) begin
         st <= S_CFG; cfg_i <= 0; np <= 0; ci <= 0;
         awvalid <= 0; wvalid <= 0; bready <= 1;
         arvalid <= 0; rready <= 1; tready <= 0;
         saw_last <= 0; bp_done <= 0; guard <= 0;
      end else begin
         guard <= guard + 1;
         if (guard > 32'd100000) st <= S_FAIL;   // engine never finished

         case (st)
         S_CFG: begin
            awaddr <= cfg_a; wdata <= cfg_v;
            awvalid <= 1; wvalid <= 1;
            if (w_done) begin
               awvalid <= 0; wvalid <= 0;
               if (cfg_i == 4'd8) begin st <= S_RUN; tready <= 1; end
               else cfg_i <= cfg_i + 1;
            end
         end
         S_RUN: begin
            // Stall the stream at pixel 10 until the FIFO fills (out_ready
            // drops) or the frame ends, so FIFO full / out_ready are exercised.
            tready <= !(np == IW'(10) && !bp_done);
            if (!dut.out_ready || irq) bp_done <= 1;
            if (tvalid && tready) begin
               got_d[np] <= tdata;
               np <= np + 1;
               if (tlast) saw_last <= 1;
            end
            if (np == IW'(NP)) begin tready <= 0; st <= S_DRAIN; end
         end
         S_DRAIN: begin
            if (irq) st <= S_CHECK;          // DONE went sticky
         end
         S_CHECK: begin
            if (!saw_last)                         st <= S_FAIL;
            else if (got_d[ci] !== expect_d[ci])   st <= S_FAIL;
            else if (ci == IW'(NP-1))              st <= S_DONE;
            else                                   ci <= ci + 1;
         end
         default: ;
         endcase
      end
   end

   // "!clk ||" lets the simulation run past Makerchip's default cycle limit.
   assign passed = !clk || st == S_DONE;
   assign failed = !clk || st == S_FAIL;

\TLV
   // VIZ: hardware image (from the AXI-Stream) vs. an independent JS binary32
   // reference, the z orbit of the pixel in flight, and the iteration datapath.
   \viz_js
      box: {left: -10, top: -40, width: 1030, height: 700, strokeWidth: 0},
      onTraceData() {
         this.frame = null  // (re)built lazily by render()
      },
      render() {
         const dv = new DataView(new ArrayBuffer(4))
         const f32 = (bits) => { dv.setUint32(0, bits); return dv.getFloat32(0) }
         const sv = (name, off = 0) => this.sigVal(name, off)
         const fv = (name, off = 0) => f32(sv(name, off).asInt())
         const bv = (name, off = 0) => sv(name, off).asBool(false)
         const fmt = (v) => !isFinite(v) ? String(v) :
                            (v != 0 && (Math.abs(v) >= 1e4 || Math.abs(v) < 1e-3)) ? v.toExponential(2) : v.toFixed(4)
         const ret = []
         const txt = (str, left, top, opts = {}) =>
            ret.push(new fabric.Text(str, {left, top, fontSize: 12, fontFamily: "monospace", ...opts}))
         const rect = (left, top, width, height, opts = {}) =>
            ret.push(new fabric.Rect({left, top, width, height, fill: "white", stroke: "#888", strokeWidth: 1, ...opts}))

         // ---- once per trace: frame config, hardware image, reference image ----
         if (!this.frame) {
            const end = (name) => sv(name).goToSimEnd().asInt()
            const fr = {W: end("dut.width"), H: end("dut.height"), MI: end("dut.max_iter"),
                        x0: f32(end("dut.x0")), y0: f32(end("dut.y0")),
                        dx: f32(end("dut.dx")), dy: f32(end("dut.dy")), er2: f32(end("dut.esc_r2"))}
            // Hardware: walk the stream handshakes.
            fr.hw = []
            const tv = sv("tvalid").goToSimStart(), tr = sv("tready").goToSimStart(), td = sv("tdata").goToSimStart()
            for (; !tv.offEnd(); tv.step(), tr.step(), td.step()) {
               if (tv.asBool(false) && tr.asBool(false)) fr.hw.push({depth: td.asInt(), cyc: tv.getCycle()})
            }
            // Reference: binary32 via Math.fround, coordinates by repeated addition like the scanner.
            const f = Math.fround
            fr.ref = []
            let cy = f(fr.y0)
            for (let r = 0; r < fr.H; r++) {
               let cx = f(fr.x0)
               for (let c = 0; c < fr.W; c++) {
                  let zx = 0, zy = 0, k = 0
                  for (;; k++) {
                     const xx = f(zx * zx), yy = f(zy * zy)
                     if (!(f(xx + yy) <= fr.er2) || k == fr.MI) break
                     const xy = f(zx * zy)
                     zx = f(f(xx - yy) + cx)
                     zy = f(f(xy + xy) + cy)
                  }
                  fr.ref.push({cx, cy, depth: k})
                  cx = f(cx + fr.dx)
               }
               cy = f(cy + fr.dy)
            }
            this.frame = fr
         }
         const fr = this.frame
         const cyc = this.getCycle()
         const color = (d) => d >= fr.MI ? "#111" : `hsl(${(210 + d * 47) % 360}, 75%, ${40 + 35 * d / fr.MI}%)`

         // ---- images ----
         const S = Math.min(320 / fr.W, 240 / fr.H)
         const busy = bv("dut.busy")
         const col = sv("dut.u_scan.col").asInt(), row = sv("dut.u_scan.row").asInt()
         let nRx = 0, nBad = 0
         const image = (left, title, cell) => {
            txt(title, left, -30, {fontSize: 14, fontWeight: "bold"})
            for (let i = 0; i < fr.W * fr.H; i++) {
               const x = left + (i % fr.W) * S, y = Math.floor(i / fr.W) * S
               const c = cell(i)
               rect(x, y, S, S, {fill: c.fill, stroke: c.bad ? "red" : "#666", strokeWidth: c.bad ? 4 : 1})
               if (c.depth !== undefined)
                  txt(String(c.depth), x + S / 2, y + S / 2, {originX: "center", originY: "center",
                      fontSize: S / 3, fill: c.depth >= fr.MI ? "#ccc" : "black"})
            }
            if (busy)
               rect(left + col * S, row * S, S, S, {fill: "", stroke: "orange", strokeWidth: 4})
         }
         image(0, "Hardware (AXI-Stream)", (i) => {
            const h = fr.hw[i]
            if (!h || h.cyc > cyc) return {fill: "#e8e8e8"}
            const bad = h.depth != fr.ref[i].depth
            nRx++; if (bad) nBad++
            return {fill: color(h.depth), depth: h.depth, bad}
         })
         image(350, "Reference (JS binary32)", (i) => ({fill: color(fr.ref[i].depth), depth: fr.ref[i].depth}))
         txt(`received ${nRx}/${fr.W * fr.H}   mismatches ${nBad}` + (fr.hw.length > fr.W * fr.H ? `   EXTRA PIXELS ${fr.hw.length - fr.W * fr.H}` : ""),
             0, fr.H * S + 8, {fill: nBad ? "red" : "black"})

         // ---- complex plane: pixel c's and the z orbit of the pixel in flight ----
         const PX = 700, PS = 300
         const reLo = Math.min(-2.2, fr.x0, fr.x0 + (fr.W - 1) * fr.dx), reHi = Math.max(2.2, fr.x0, fr.x0 + (fr.W - 1) * fr.dx)
         const imLo = Math.min(-2.2, fr.y0, fr.y0 + (fr.H - 1) * fr.dy), imHi = Math.max(2.2, fr.y0, fr.y0 + (fr.H - 1) * fr.dy)
         const sc = PS / Math.max(reHi - reLo, imHi - imLo)
         const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v))
         const map = (re, im) => [PX + clamp((re - reLo) * sc, 0, PS), clamp((imHi - im) * sc, 0, PS)]
         txt("z orbit of current pixel", PX, -30, {fontSize: 14, fontWeight: "bold"})
         rect(PX, 0, PS, PS, {fill: "#fafafa"})
         ret.push(new fabric.Line([...map(reLo, 0), ...map(reHi, 0)], {stroke: "#ccc"}))
         ret.push(new fabric.Line([...map(0, imLo), ...map(0, imHi)], {stroke: "#ccc"}))
         const [ox, oy] = map(0, 0)
         ret.push(new fabric.Circle({left: ox, top: oy, radius: Math.sqrt(fr.er2) * sc, originX: "center", originY: "center",
                                     fill: "", stroke: "#aaa", strokeDashArray: [4, 4]}))
         fr.ref.forEach((p) => {
            const [x, y] = map(p.cx, p.cy)
            rect(x - 3, y - 3, 6, 6, {fill: color(p.depth), strokeWidth: 0})
         })
         // Orbit: back up to this pixel's z_clear, then collect z after each iter_tick.
         let start = 0
         while (start > -400 && !bv("dut.z_clear", start) && sv("dut.z_clear", start - 1).inTrace()) start--
         const orbit = [[0, 0]]
         for (let o = start; o < 0; o++)
            if (bv("dut.iter_tick", o)) orbit.push([fv("dut.u_dp.zx_r", o + 1), fv("dut.u_dp.zy_r", o + 1)])
         if (busy) {
            const pts = orbit.map(([re, im]) => map(re, im))
            if (pts.length > 1)
               ret.push(new fabric.Polyline(pts.map(([x, y]) => ({x, y})), {fill: "", stroke: "orange", strokeWidth: 1.5}))
            pts.forEach(([x, y]) => ret.push(new fabric.Circle({left: x, top: y, radius: 2.5, originX: "center", originY: "center", fill: "orange"})))
            const [cx, cy] = map(fv("dut.u_dp.cx_lr"), fv("dut.u_dp.cy_lr"))
            ret.push(new fabric.Circle({left: cx, top: cy, radius: 6, originX: "center", originY: "center", fill: "", stroke: "red", strokeWidth: 2}))
         }
         // Iteration table.
         txt(" k        zx        zy     |z|^2\n" +
             orbit.map(([re, im], k) => `${String(k).padStart(2)} ${fmt(re).padStart(9)} ${fmt(im).padStart(9)} ${fmt(Math.fround(re * re + im * im)).padStart(9)}`).join("\n"),
             PX, 330, {fontSize: 11})

         // ---- datapath (values as of the current cycle) ----
         const DY = 290
         const states = ["IDLE", "SCANRST", "SCANW0", "ZCLEAR", "M0", "M1", "M2", "A0", "A1", "A2", "TEST",
                         "A3", "TICK", "WOUT", "EMIT", "STEP", "SCANW1", "DONE"]
         const mulSel = ["zx*zx", "zy*zy", "zx*zy", "zx*zy"], asSel = ["xx,yy", "xy,xy", "t,cx", "w,cy"]
         txt(`cycle ${cyc}   sequencer: S_${states[sv("dut.u_seq.st").asInt()]}   busy=${+busy} done=${+bv("dut.done")}`,
             0, DY, {fontSize: 14, fontWeight: "bold"})
         const strobes = ["scan_rst", "scan_step", "z_clear", "ld_xx", "ld_yy", "ld_xy", "ld_mag", "ld_w",
                          "ld_zx", "ld_zy", "iter_tick", "px_valid", "px_last"]
         strobes.forEach((s, i) => {
            const on = bv(`dut.${s}`)
            rect(i * 51, DY + 24, 49, 18, {fill: on ? "gold" : "#eee", stroke: on ? "black" : "#ccc"})
            txt(s, i * 51 + 24.5, DY + 33, {fontSize: 8.5, originX: "center", originY: "center"})
         })
         const reg = (left, top, name, val, load) => {
            rect(left, top, 80, 36, {fill: load ? "gold" : "white"})
            txt(name, left + 3, top + 2, {fontSize: 10, fill: "#555"})
            txt(val, left + 3, top + 17, {fontSize: 12})
         }
         const RY = DY + 60
         const zc = bv("dut.z_clear")
         reg(0,   RY, "zx",    fmt(fv("dut.u_dp.zx_r")),  zc || bv("dut.ld_zx"))
         reg(85,  RY, "zy",    fmt(fv("dut.u_dp.zy_r")),  zc || bv("dut.ld_zy"))
         reg(170, RY, "cx",    fmt(fv("dut.u_dp.cx_lr")), zc)
         reg(255, RY, "cy",    fmt(fv("dut.u_dp.cy_lr")), zc)
         reg(340, RY, "iter",  String(sv("dut.iter_count").asInt()) + (bv("dut.iter_limit") ? " LIM" : ""), bv("dut.iter_tick"))
         reg(425, RY, "esc",   bv("dut.escaped") ? "1 ESC" : "0", bv("dut.ld_mag"))
         reg(0,   RY + 45, "xx",  fmt(fv("dut.u_dp.xx_r")),  bv("dut.ld_xx"))
         reg(85,  RY + 45, "yy",  fmt(fv("dut.u_dp.yy_r")),  bv("dut.ld_yy"))
         reg(170, RY + 45, "xy",  fmt(fv("dut.u_dp.xy_r")),  bv("dut.ld_xy"))
         reg(255, RY + 45, "mag", fmt(fv("dut.u_dp.mag_r")), bv("dut.ld_mag"))
         reg(340, RY + 45, "t",   fmt(fv("dut.u_dp.t_r")),   bv("dut.ld_mag"))
         reg(425, RY + 45, "w",   fmt(fv("dut.u_dp.w_r")),   bv("dut.ld_w"))
         const unit = (top, title, lines) => {
            rect(0, top, 505, 58, {fill: "#eef4ff"})
            txt(title, 5, top + 4, {fontSize: 11, fontWeight: "bold"})
            txt(lines, 5, top + 20, {fontSize: 11})
         }
         const s = fv("dut.as_s")
         unit(RY + 95, `fp_mult   (next operands: ${mulSel[sv("dut.mul_sel").asInt()]})`,
              `${fmt(fv("dut.mul_a"))} * ${fmt(fv("dut.mul_b"))} = ${fmt(fv("dut.mul_p"))}`)
         unit(RY + 160, `fp_fused_addsub   (next operands: ${asSel[sv("dut.as_sel").asInt()]})`,
              `a=${fmt(fv("dut.as_a"))}  b=${fmt(fv("dut.as_b"))}\n` +
              `s=${fmt(s)}  d=${fmt(fv("dut.as_d"))}   s > esc_r2: ${+(sv("dut.as_s").asInt() > sv("dut.esc_r2").asInt())}`)
         txt(`scanner: col ${col} row ${row}  cx ${fmt(fv("dut.cx"))} cy ${fmt(fv("dut.cy"))}  scan_busy=${+bv("dut.scan_busy")}\n` +
             `FIFO: count ${sv("dut.u_out.count").asInt()}  out_ready=${+bv("dut.out_ready")}  ` +
             `tvalid=${+bv("tvalid")} tready=${+bv("tready")} tdata=${sv("tdata").asInt()}`,
             0, RY + 228, {fontSize: 11})
         return ret
      }
\SV
endmodule
