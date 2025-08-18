\m5_TLV_version 1d: tl-x.org
\m5
   
   // ============================================
   // Welcome, new visitors! Try the "Learn" menu.
   // ============================================
   
   //use(m5-1.0)   /// uncomment to use M5 macro library.
\SV
// uart.sv - Simple UART (8N1)
// Fixed baud rate, 8 data bits, no parity, 1 stop bit.
// Transmit and receive logic.

module uart #(
    parameter CLOCK_FREQ = 50_000_000,
    parameter BAUD_RATE  = 115_200
) (
    input  logic        clk,
    input  logic        rst,

    // TX interface
    input  logic [7:0]  tx_data,
    input  logic        tx_start,
    output logic        tx_busy,
    output logic        tx_serial,

    // RX interface
    output logic [7:0]  rx_data,
    output logic        rx_ready,
    input  logic        rx_serial
);
    localparam integer BAUD_DIV = CLOCK_FREQ / BAUD_RATE;
    logic [$clog2(BAUD_DIV)-1:0] baud_cnt;
    logic baud_tick;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            baud_cnt <= 0;
            baud_tick <= 0;
        end else if (baud_cnt == BAUD_DIV - 1) begin
            baud_cnt <= 0;
            baud_tick <= 1;
        end else begin
            baud_cnt <= baud_cnt + 1;
            baud_tick <= 0;
        end
    end

    typedef enum logic [1:0] { TX_IDLE, TX_START, TX_DATA, TX_STOP } tx_state_t;
    tx_state_t tx_state;
    logic [3:0] tx_bit_cnt;
    logic [7:0] tx_shift_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            tx_state <= TX_IDLE;
            tx_serial <= 1'b1;
            tx_busy <= 1'b0;
            tx_bit_cnt <= 0;
            tx_shift_reg <= 0;
        end else if (baud_tick) begin
            case (tx_state)
                TX_IDLE: begin
                    tx_serial <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        tx_shift_reg <= tx_data;
                        tx_state <= TX_START;
                        tx_busy <= 1'b1;
                    end
                end
                TX_START: begin
                    tx_serial <= 1'b0;
                    tx_state <= TX_DATA;
                    tx_bit_cnt <= 0;
                end
                TX_DATA: begin
                    tx_serial <= tx_shift_reg[0];
                    tx_shift_reg <= tx_shift_reg >> 1;
                    if (tx_bit_cnt == 7) tx_state <= TX_STOP;
                    tx_bit_cnt <= tx_bit_cnt + 1;
                end
                TX_STOP: begin
                    tx_serial <= 1'b1;
                    tx_state <= TX_IDLE;
                end
            endcase
        end
    end

    typedef enum logic [1:0] { RX_IDLE, RX_START, RX_DATA, RX_STOP } rx_state_t;
    rx_state_t rx_state;
    logic [3:0] rx_bit_cnt;
    logic [7:0] rx_shift_reg;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_state <= RX_IDLE;
            rx_bit_cnt <= 0;
            rx_ready <= 0;
            rx_shift_reg <= 0;
            rx_data <= 0;
        end else if (baud_tick) begin
            case (rx_state)
                RX_IDLE: begin
                    rx_ready <= 0;
                    if (!rx_serial) rx_state <= RX_START;
                end
                RX_START: begin
                    rx_state <= RX_DATA;
                    rx_bit_cnt <= 0;
                end
                RX_DATA: begin
                    rx_shift_reg <= {rx_serial, rx_shift_reg[7:1]};
                    if (rx_bit_cnt == 7) rx_state <= RX_STOP;
                    rx_bit_cnt <= rx_bit_cnt + 1;
                end
                RX_STOP: begin
                    if (rx_serial) begin
                        rx_data <= rx_shift_reg;
                        rx_ready <= 1;
                    end
                    rx_state <= RX_IDLE;
                end
            endcase
        end
    end
endmodule

// ----------------------------------------------------------------
// Makerchip-compatible top-level with UART loopback test
// ----------------------------------------------------------------
module top(
    input  wire        clk,
    input  wire        reset,
    input  wire [31:0] cyc_cnt,
    output wire        passed,
    output wire        failed
);

    // UART signals
    logic [7:0] tx_data;
    logic       tx_start, tx_busy;
    logic       tx_serial, rx_serial;
    logic [7:0] rx_data;
    logic       rx_ready;

    // Loopback
    assign rx_serial = tx_serial;

    // Instantiate UART
    uart #(
        .CLOCK_FREQ(50_000_000),
        .BAUD_RATE(5_000_000)  // much faster for simulation
    ) uart_inst (
        .clk       (clk),
        .rst       (reset),
        .tx_data   (tx_data),
        .tx_start  (tx_start),
        .tx_busy   (tx_busy),
        .tx_serial (tx_serial),
        .rx_data   (rx_data),
        .rx_ready  (rx_ready),
        .rx_serial (rx_serial)
    );

    // Test sequence: send 0x55 at cyc_cnt == 10
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            tx_data <= 8'h00;
            tx_start <= 0;
        end else if (cyc_cnt == 10) begin
            tx_data <= 8'h55;
            tx_start <= 1;
        end else begin
            tx_start <= 0;
        end
    end

    // Pass/fail conditions
    assign passed = rx_ready && (rx_data == 8'h55);
    assign failed = 1'b0;

\TLV
   \viz_js
      template: {
          tx_box:  ["Rect", {width: 5, height: 2, fill: "gray", left: 0, top: 0}],
          tx_text: ["Text", "TX", {fill: "black", fontSize: 1, fontFamily: "monospace", left: 0.5, top: 0.5}],
          rx_box:  ["Rect", {width: 5, height: 2, fill: "gray", left: 8, top: 0}],
          rx_text: ["Text", "RX", {fill: "black", fontSize: 1, fontFamily: "monospace", left: 8.5, top: 0.5}],
          link:    ["Line", [5, 1, 8, 1], {stroke: "black", strokeWidth: 0.1}],
          tx_bit:  ["Text", "T=0", {fill: "black", fontSize: 0.8, fontFamily: "monospace", left: 5.2, top: 0.2}],
          rx_bit:  ["Text", "R=0", {fill: "black", fontSize: 0.8, fontFamily: "monospace", left: 6.5, top: 0.2}]
      },
      render() {
          let tx_busy    = this.sigVal("uart_inst.tx_busy").asBool();
          let tx_data    = this.sigVal("uart_inst.tx_data").asHexStr();
          let rx_ready   = this.sigVal("uart_inst.rx_ready").asBool();
          let rx_data    = this.sigVal("uart_inst.rx_data").asHexStr();
          let tx_serial  = this.sigVal("uart_inst.tx_serial").asInt();
          let rx_serial  = this.sigVal("uart_inst.rx_serial").asInt();

          let objs = this.getObjects();

          // TX box & text
          objs.tx_box.set("fill", tx_busy ? "orange" : "gray");
          objs.tx_text.set("text", `TX ${tx_data}`);

          // RX box & text
          objs.rx_box.set("fill", rx_ready ? "lightgreen" : "gray");
          objs.rx_text.set("text", `RX ${rx_data}`);

          // Link color based on activity
          if (tx_busy) {
              objs.link.set("stroke", "orange");
          } else if (rx_ready) {
              objs.link.set("stroke", "green");
          } else {
              objs.link.set("stroke", "black");
          }

          // Live bit values
          objs.tx_bit.set("text", `T=${tx_serial}`);
          objs.rx_bit.set("text", `R=${rx_serial}`);
      }
\SV
endmodule

