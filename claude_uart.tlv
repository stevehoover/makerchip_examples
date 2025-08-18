\m5_TLV_version 1d: tl-x.org
\m5
   // UART Library in TL-Verilog for Makerchip
   // Coded by Claude AI, September 2023, with the help of Steve Hoover.
   // Features: Configurable baud rate, 8N1 format, Visual Debug support
   
   use(m5-1.0)
   
   // Configuration parameters
   var(CLOCK_FREQ, 100000000)    // 100MHz system clock
   var(BAUD_RATE, 9600)          // Standard baud rate
   var(BAUD_DIV, m5_calc(m5_CLOCK_FREQ / m5_BAUD_RATE))  // Clock divider for baud rate = 10417
   
   if_defined_as(MAKERCHIP, 1, ['m5_set(BAUD_DIV, 5)'])              // For Makerchip testing only
   
   // Calculate bit range for counters
   var(COUNTER_WIDTH, 16)

\SV
   // M4_MAKERCHIP, m5_MAKERCHIP: m5_BAUD_DIV
   // Top-level module for Makerchip
   module top(input wire clk, input wire reset, input wire [31:0] cyc_cnt, output wire passed, output wire failed);

\TLV uart_with_viz()
   // UART Transceiver with Visual Debug
   //
   // USAGE:
   //   This macro provides a complete UART transceiver with visualization.
   //   Must be instantiated within a pipeline context.
   //
   // INTERFACE SIGNALS (all in same pipeline as macro instantiation):
   //   INPUTS:
   //     $tx_valid - Assert high to transmit $tx_data
   //     $tx_data[7:0] - Data byte to transmit when $tx_valid is high
   //     $rx_in - Serial input line (connect to external RX pin or TX output for loopback)
   //
   //   OUTPUTS:
   //     $tx_out - Serial output line (connect to external TX pin)
   //     $tx_ready - High when transmitter is ready for new data
   //     $rx_data_valid - Pulses high for one cycle when byte received
   //     $rx_data[7:0] - Received data byte (valid when $rx_data_valid is high)
   //
   // CONFIGURATION:
   //   Set m5_BAUD_DIV before instantiation to configure baud rate
   //   BAUD_DIV = CLOCK_FREQ / BAUD_RATE
   //
   // EXAMPLE:
   //   |uart_pipe
   //      @0
   //         $tx_valid = some_condition;
   //         $tx_data[7:0] = some_data;
   //         $rx_in = external_rx_pin;
   //      m4+uart_with_viz()
   //      @1
   //         external_tx_pin = $tx_out;
   //         process_received_data = $rx_data_valid ? $rx_data : 8'b0;

   @0
      // Baud rate generation using state signals
      // Count down from BAUD_DIV-1 to 0, then reload
      $BaudCounter[m5_COUNTER_WIDTH-1:0] <= *reset ? (m5_BAUD_DIV - 1) : 
                                            ($BaudCounter == 16'b0) ? (m5_BAUD_DIV - 1) :
                                            $BaudCounter - 16'b1;
      $baud_tick = ($BaudCounter == 16'b0);
      
      // For RX start bit detection - sample at half baud rate  
      $half_baud_tick = ($BaudCounter == (m5_BAUD_DIV >> 1));
      
   @1
      // === TRANSMITTER LOGIC ===
      
      // TX state machine control using state signals
      $start_tx = $tx_valid && !$TxBusy;
      $TxBusy <= *reset ? 1'b0 : 
                $start_tx ? 1'b1 : 
                $tx_done ? 1'b0 : 
                $TxBusy;
      
      $TxState[3:0] <= *reset ? 4'b0 :
                       $start_tx ? 4'b1 :  // Start bit state
                       ($TxBusy && $baud_tick && ($TxState < 4'd10)) ? $TxState + 4'b1 :
                       $TxState;
      
      $tx_done = ($TxState == 4'd10) && $baud_tick;
      
      // TX shift register - using state signal
      $TxShiftReg[9:0] <= $start_tx ? {1'b1, $tx_data, 1'b0} :  // Stop bit, data, start bit
                         ($baud_tick && $TxBusy) ? {1'b1, $TxShiftReg[9:1]} :
                         $TxShiftReg;
      
      // Output serial data (idle high when not transmitting)
      $tx_out = $TxBusy ? $TxShiftReg[0] : 1'b1;
      $tx_ready = !$TxBusy;
      
      // === RECEIVER LOGIC ===
      
      // Edge detection for start bit using state signal
      $RxInPrev <= *reset ? 1'b1 : $rx_in;
      $start_bit_detected = $RxInPrev && !$rx_in && !$RxBusy;
      
      // RX state machine control using state signals
      $start_rx = $start_bit_detected;
      $RxBusy <= *reset ? 1'b0 : 
                $start_rx ? 1'b1 : 
                $rx_done ? 1'b0 : 
                $RxBusy;
      
      $RxState[3:0] <= *reset ? 4'b0 :
                       $start_rx ? 4'b1 :
                       ($RxBusy && $baud_tick && ($RxState < 4'd10)) ? $RxState + 4'b1 :
                       $RxState;
      
      $rx_done = ($RxState == 4'd10) && $baud_tick;
      
      // Sample data bits using state signal - sample in middle of bit period
      $sample_bit = $RxBusy && $half_baud_tick && ($RxState >= 4'd2) && ($RxState <= 4'd9);
      $RxShiftReg[7:0] <= *reset ? 8'b0 :
                         $sample_bit ? {$rx_in, $RxShiftReg[7:1]} :
                         $RxShiftReg;
      
      // Output interface
      $rx_data_valid = $rx_done;
      $rx_data[7:0] = $rx_done ? $RxShiftReg : 8'b0;
      
      // Remove unused signals to clean up warnings
      `BOGUS_USE($tx_ready)

      // === VISUAL DEBUG ===
      \viz_js
         box: {width: 600, height: 380, strokeWidth: 1},
         init() {
            // Return object of Objects for the implicit fabric.Group
            return {
               title: new fabric.Text("UART Transceiver", {
                  left: 0, top: 0, fontSize: 20, fontWeight: "bold"
               }),
               tx_label: new fabric.Text("Transmitter", {
                  left: 0, top: 40, fontSize: 16, fontWeight: "bold", fill: "blue"
               }),
               tx_data_label: new fabric.Text("TX Data:", {
                  left: 0, top: 70, fontSize: 12
               }),
               tx_data_text: new fabric.Text("--", {
                  left: 80, top: 70, fontSize: 12, fontFamily: "monospace"
               }),
               tx_state_label: new fabric.Text("TX State:", {
                  left: 0, top: 90, fontSize: 12
               }),
               tx_state_text: new fabric.Text("IDLE", {
                  left: 80, top: 90, fontSize: 12, fontFamily: "monospace"
               }),
               serial_label: new fabric.Text("Serial Line:", {
                  left: 0, top: 130, fontSize: 14, fontWeight: "bold"
               }),
               serial_line: new fabric.Rect({
                  left: 0, top: 150, width: 400, height: 20,
                  fill: "lightgray", stroke: "black", strokeWidth: 1
               }),
               serial_bit: new fabric.Circle({
                  left: 10, top: 155, radius: 8,
                  fill: "red"
               }),
               rx_label: new fabric.Text("Receiver", {
                  left: 0, top: 200, fontSize: 16, fontWeight: "bold", fill: "green"
               }),
               rx_data_label: new fabric.Text("RX Data:", {
                  left: 0, top: 230, fontSize: 12
               }),
               rx_data_text: new fabric.Text("--", {
                  left: 80, top: 230, fontSize: 12, fontFamily: "monospace"
               }),
               rx_state_label: new fabric.Text("RX State:", {
                  left: 0, top: 250, fontSize: 12
               }),
               rx_state_text: new fabric.Text("IDLE", {
                  left: 80, top: 250, fontSize: 12, fontFamily: "monospace"
               }),
               rx_chars_label: new fabric.Text("Received:", {
                  left: 0, top: 280, fontSize: 12
               }),
               rx_chars_text: new fabric.Text("", {
                  left: 80, top: 280, fontSize: 12, fontFamily: "monospace"
               }),
               // Counter displays
               counters_label: new fabric.Text("Debug Info:", {
                  left: 0, top: 320, fontSize: 14, fontWeight: "bold"
               }),
               baud_counter_label: new fabric.Text("Baud:", {
                  left: 0, top: 340, fontSize: 12
               }),
               baud_counter_text: new fabric.Text("0x0000", {
                  left: 50, top: 340, fontSize: 12, fontFamily: "monospace"
               }),
               tx_ready_label: new fabric.Text("TX Ready:", {
                  left: 120, top: 340, fontSize: 12
               }),
               tx_ready_text: new fabric.Text("Yes", {
                  left: 180, top: 340, fontSize: 12, fontFamily: "monospace"
               })
            };
         },
         render() {
            // Get all signal values with defaults
            let tx_data = '$tx_data'.asInt(0);
            let tx_valid = '$tx_valid'.asBool(0);
            let tx_state = '$TxState'.asInt(0);
            let tx_busy = '$TxBusy'.asBool(0);
            let tx_out = '$tx_out'.asBool(1);
            let tx_ready = '$tx_ready'.asBool(1);

            let rx_data = '$rx_data'.asInt(0);
            let rx_valid = '$rx_data_valid'.asBool(0);
            let rx_state = '$RxState'.asInt(0);

            let baud_counter = '$BaudCounter'.asInt(0);

            // State name lookup
            let state_names = ["IDLE", "START", "D0", "D1", "D2", "D3", "D4", "D5", "D6", "D7", "STOP"];

            // ALWAYS update ALL text objects - never leave any unchanged

            // TX data display
            if (tx_valid && tx_data >= 32 && tx_data <= 126) {
               this.obj.tx_data_text.set("text", "0x" + tx_data.toString(16).toUpperCase().padStart(2, "0") + " (''" + String.fromCharCode(tx_data) + "'')");
            } else if (tx_valid) {
               this.obj.tx_data_text.set("text", "0x" + tx_data.toString(16).toUpperCase().padStart(2, "0") + " (ctrl)");
            } else {
               this.obj.tx_data_text.set("text", "--");
            }

            // TX state
            this.obj.tx_state_text.set("text", state_names[tx_state] || ("0x" + tx_state.toString(16)));

            // Serial line bit
            this.obj.serial_bit.set("fill", tx_out ? "green" : "red");

            // RX data display
            if (rx_valid && rx_data >= 32 && rx_data <= 126) {
               this.obj.rx_data_text.set("text", "0x" + rx_data.toString(16).toUpperCase().padStart(2, "0") + " (''" + String.fromCharCode(rx_data) + "'')");
            } else if (rx_valid) {
               this.obj.rx_data_text.set("text", "0x" + rx_data.toString(16).toUpperCase().padStart(2, "0") + " (ctrl)");
            } else {
               this.obj.rx_data_text.set("text", "--");
            }

            // RX state
            this.obj.rx_state_text.set("text", state_names[rx_state] || ("0x" + rx_state.toString(16)));

            // RX characters accumulation - ALWAYS set by scanning back in time
            let rx_chars = "";

            // Create a signal set for time stepping
            let sig_obj = {
               rx_valid: '$rx_data_valid',
               rx_data: '$rx_data'
            };
            let sigs = this.signalSet(sig_obj);

            // Collect received characters by stepping backwards
            let max_steps = 200;

            try {
               for (let i = 0; i < max_steps; i++) {
                  if (sigs.sig("rx_valid").asBool(false) && 
                      sigs.sig("rx_data").asInt(0) >= 32 && 
                      sigs.sig("rx_data").asInt(0) <= 126) {
                     rx_chars = String.fromCharCode(sigs.sig("rx_data").asInt(0)) + rx_chars;
                  }
                  sigs.step(-1);  // Step backwards one cycle
               }
            } catch (e) {
               // Stop if we go beyond available history
            }

            this.obj.rx_chars_text.set("text", rx_chars);

            // Debug info - ALWAYS update
            this.obj.baud_counter_text.set("text", "0x" + baud_counter.toString(16).toUpperCase().padStart(4, "0"));
            this.obj.tx_ready_text.set("text", tx_ready ? "Yes" : "No");
         }

\TLV
   // Example usage / testbench
   
   // Test bench logic
   |testbench
      @0
         // Test pattern generation using state signals (PascalCase)
         $TestCounter[7:0] <= *reset ? 8'b0 : 
                              ($tx_done && ($TestCounter < 8'd10)) ? $TestCounter + 8'b1 : 
                              $TestCounter;
         
         $test_data[7:0] = 8'h41 + ($TestCounter % 8'd26);  // ASCII A-Z cycle
         $send_data = ($TestCounter < 8'd10) && !$tx_busy && ($ResetCounter > 8'd20);
         
         // Reset counter to delay start
         $ResetCounter[7:0] <= *reset ? 8'b0 : 
                              ($ResetCounter < 8'd30) ? $ResetCounter + 8'b1 : 
                              $ResetCounter;
         
         // Signals from UART
         $tx_busy = /top|uart>>1$TxBusy;
         $tx_done = /top|uart>>1$tx_done;

   // UART instantiation example
   |uart
      @0
         // Connect testbench signals to UART inputs
         $tx_valid = /top|testbench>>0$send_data;
         $tx_data[7:0] = /top|testbench>>0$test_data;
      @1
         $rx_in = $tx_out;  // Loopback for testing
         
      // Instantiate UART with visualization
      m4+uart_with_viz()

   // Simulation control
   *passed = *cyc_cnt > 500;
   *failed = 1'b0;

\SV
   endmodule
