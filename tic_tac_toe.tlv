\m5_TLV_version 1d: tl-x.org
\SV
   m5_makerchip_module
\TLV
   
   // =============================================
   // Tic-Tac-Toe Game
   // =============================================
   // Interactive tic-tac-toe game with AI opponent
   // Player X moves are simulated with incrementing position
   // Player O (AI) makes random valid moves
   
   |game
      @0
         $reset = *reset;
         
         // =============================================
         // Board State - 9 cells, 2 bits each
         // 00 = empty, 01 = X, 10 = O
         // =============================================
         
         // Initialize board state
         $board_init[17:0] = 18'b0;  // All cells empty
         
         // Position selector - cycles through positions 0-8 slowly
         $cycle_count[15:0] = $reset ? 16'b0 : >>1$cycle_count + 16'b1;
         $slow_count[7:0] = $cycle_count[10:3];  // Divide by 8 for slower movement
         
         // Current position being considered (0-8)
         $position[3:0] = $slow_count % 4'd9;
         
         // Game state tracking
         $game_over_prev = $reset ? 1'b0 : >>1$game_over;
         $current_player = $reset ? 1'b0 : >>1$current_player;  // 0=X, 1=O
         
         // Make move when counter hits specific values and game not over
         $make_move = !$game_over_prev && ($cycle_count[2:0] == 3'b111);
         
         // Check if selected position is empty
         // Extract 2-bit cell value for current position
         $cell_0[1:0] = >>1$board[1:0];
         $cell_1[1:0] = >>1$board[3:2];
         $cell_2[1:0] = >>1$board[5:4];
         $cell_3[1:0] = >>1$board[7:6];
         $cell_4[1:0] = >>1$board[9:8];
         $cell_5[1:0] = >>1$board[11:10];
         $cell_6[1:0] = >>1$board[13:12];
         $cell_7[1:0] = >>1$board[15:14];
         $cell_8[1:0] = >>1$board[17:16];
         
         $selected_cell[1:0] = 
            ($position == 4'd0) ? $cell_0 :
            ($position == 4'd1) ? $cell_1 :
            ($position == 4'd2) ? $cell_2 :
            ($position == 4'd3) ? $cell_3 :
            ($position == 4'd4) ? $cell_4 :
            ($position == 4'd5) ? $cell_5 :
            ($position == 4'd6) ? $cell_6 :
            ($position == 4'd7) ? $cell_7 :
            $cell_8;
         
         $position_empty = ($selected_cell == 2'b00);
         
         // Valid move = make_move flag && position is empty
         $valid_move = $make_move && $position_empty;
         
         // Player marker: 01 for X, 10 for O
         $marker[1:0] = $current_player ? 2'b10 : 2'b01;
         
         // Update board with new move
         $new_board[17:0] =
            $valid_move ?
               (($position == 4'd0) ? {>>1$board[17:2], $marker} :
                ($position == 4'd1) ? {>>1$board[17:4], $marker, >>1$board[1:0]} :
                ($position == 4'd2) ? {>>1$board[17:6], $marker, >>1$board[3:0]} :
                ($position == 4'd3) ? {>>1$board[17:8], $marker, >>1$board[5:0]} :
                ($position == 4'd4) ? {>>1$board[17:10], $marker, >>1$board[7:0]} :
                ($position == 4'd5) ? {>>1$board[17:12], $marker, >>1$board[9:0]} :
                ($position == 4'd6) ? {>>1$board[17:14], $marker, >>1$board[11:0]} :
                ($position == 4'd7) ? {>>1$board[17:16], $marker, >>1$board[13:0]} :
                {$marker, >>1$board[15:0]}) :
            >>1$board;
         
         $board[17:0] = $reset ? $board_init : $new_board;
         
         // =============================================
         // Win Detection Logic
         // =============================================
         
         // Check all winning combinations
         // Rows
         $win_row0 = ($cell_0 != 2'b00) && ($cell_0 == $cell_1) && ($cell_1 == $cell_2);
         $win_row1 = ($cell_3 != 2'b00) && ($cell_3 == $cell_4) && ($cell_4 == $cell_5);
         $win_row2 = ($cell_6 != 2'b00) && ($cell_6 == $cell_7) && ($cell_7 == $cell_8);
         
         // Columns
         $win_col0 = ($cell_0 != 2'b00) && ($cell_0 == $cell_3) && ($cell_3 == $cell_6);
         $win_col1 = ($cell_1 != 2'b00) && ($cell_1 == $cell_4) && ($cell_4 == $cell_7);
         $win_col2 = ($cell_2 != 2'b00) && ($cell_2 == $cell_5) && ($cell_5 == $cell_8);
         
         // Diagonals
         $win_diag0 = ($cell_0 != 2'b00) && ($cell_0 == $cell_4) && ($cell_4 == $cell_8);
         $win_diag1 = ($cell_2 != 2'b00) && ($cell_2 == $cell_4) && ($cell_4 == $cell_6);
         
         $win = $win_row0 || $win_row1 || $win_row2 || 
                $win_col0 || $win_col1 || $win_col2 || 
                $win_diag0 || $win_diag1;
         
         // Check for draw (all cells filled)
         $all_filled = ($cell_0 != 2'b00) && ($cell_1 != 2'b00) && ($cell_2 != 2'b00) &&
                       ($cell_3 != 2'b00) && ($cell_4 != 2'b00) && ($cell_5 != 2'b00) &&
                       ($cell_6 != 2'b00) && ($cell_7 != 2'b00) && ($cell_8 != 2'b00);
         
         $draw = $all_filled && !$win;
         $game_over = $win || $draw;
         
         // Winner (if any): 0=X won, 1=O won
         $winner = >>1$current_player;
         
         // Toggle player after valid move
         $next_player = $valid_move ? !>>1$current_player : >>1$current_player;
         
         // Highlight winning line
         $highlight_row0 = $win_row0;
         $highlight_row1 = $win_row1;
         $highlight_row2 = $win_row2;
         $highlight_col0 = $win_col0;
         $highlight_col1 = $win_col1;
         $highlight_col2 = $win_col2;
         $highlight_diag0 = $win_diag0;
         $highlight_diag1 = $win_diag1;
         
   // =============================================
   // Visualization
   // =============================================
   \viz_js
      box: {strokeWidth: 0},
      init() {
         let ret = {};
         
         // Game title
         ret.title = new fabric.Text("TIC-TAC-TOE", {
            left: 300,
            top: 30,
            fontSize: 36,
            fontWeight: "bold",
            fill: "#2c3e50",
            originX: "center",
            fontFamily: "Arial"
         });
         
         // Game board background
         ret.board_bg = new fabric.Rect({
            left: 150,
            top: 100,
            width: 300,
            height: 300,
            fill: "#ecf0f1",
            stroke: "#34495e",
            strokeWidth: 3,
            rx: 10,
            ry: 10
         });
         
         // Grid lines
         // Vertical lines
         ret.vline1 = new fabric.Line([250, 110, 250, 390], {
            stroke: "#34495e",
            strokeWidth: 3
         });
         ret.vline2 = new fabric.Line([350, 110, 350, 390], {
            stroke: "#34495e",
            strokeWidth: 3
         });
         
         // Horizontal lines
         ret.hline1 = new fabric.Line([160, 200, 440, 200], {
            stroke: "#34495e",
            strokeWidth: 3
         });
         ret.hline2 = new fabric.Line([160, 300, 440, 300], {
            stroke: "#34495e",
            strokeWidth: 3
         });
         
         // Create cell objects for X's and O's (9 cells)
         for (let i = 0; i < 9; i++) {
            let row = Math.floor(i / 3);
            let col = i % 3;
            let x = 205 + col * 100;
            let y = 155 + row * 100;
            
            // X marks (two diagonal lines)
            ret[`x_line1_${i}`] = new fabric.Line([x-30, y-30, x+30, y+30], {
               stroke: "#e74c3c",
               strokeWidth: 8,
               strokeLineCap: "round",
               visible: false
            });
            ret[`x_line2_${i}`] = new fabric.Line([x-30, y+30, x+30, y-30], {
               stroke: "#e74c3c",
               strokeWidth: 8,
               strokeLineCap: "round",
               visible: false
            });
            
            // O marks (circle)
            ret[`o_circle_${i}`] = new fabric.Circle({
               left: x,
               top: y,
               radius: 35,
               fill: "transparent",
               stroke: "#3498db",
               strokeWidth: 8,
               originX: "center",
               originY: "center",
               visible: false
            });
         }
         
         // Winning line highlight
         ret.win_line = new fabric.Line([0, 0, 0, 0], {
            stroke: "#27ae60",
            strokeWidth: 6,
            visible: false
         });
         
         // Status text
         ret.status = new fabric.Text("X's Turn", {
            left: 300,
            top: 430,
            fontSize: 24,
            fontWeight: "bold",
            fill: "#2c3e50",
            originX: "center",
            fontFamily: "Arial"
         });
         
         // Next move indicator
         ret.next_move = new fabric.Text("", {
            left: 300,
            top: 470,
            fontSize: 18,
            fill: "#7f8c8d",
            originX: "center",
            fontFamily: "Arial"
         });
         
         return ret;
      },
      render() {
         let cells = [
            '/game|game>>1$cell_0',
            '/game|game>>1$cell_1',
            '/game|game>>1$cell_2',
            '/game|game>>1$cell_3',
            '/game|game>>1$cell_4',
            '/game|game>>1$cell_5',
            '/game|game>>1$cell_6',
            '/game|game>>1$cell_7',
            '/game|game>>1$cell_8'
         ];
         
         // Update each cell
         for (let i = 0; i < 9; i++) {
            let cell_val = parseInt(this.getSignalsValue(cells[i]));
            
            // Show/hide X marks
            this.getObjects()[`x_line1_${i}`].set({visible: cell_val === 1});
            this.getObjects()[`x_line2_${i}`].set({visible: cell_val === 1});
            
            // Show/hide O marks
            this.getObjects()[`o_circle_${i}`].set({visible: cell_val === 2});
         }
         
         // Update status text
         let game_over = parseInt(this.getSignalsValue('/game|game$game_over'));
         let win = parseInt(this.getSignalsValue('/game|game$win'));
         let current_player = parseInt(this.getSignalsValue('/game|game>>1$current_player'));
         let position = parseInt(this.getSignalsValue('/game|game$position'));
         
         let status_text = "";
         if (game_over && win) {
            let winner = parseInt(this.getSignalsValue('/game|game$winner'));
            status_text = winner === 0 ? "X WINS!" : "O WINS!";
            this.getObjects().status.set({fill: "#27ae60"});
         } else if (game_over) {
            status_text = "DRAW!";
            this.getObjects().status.set({fill: "#f39c12"});
         } else {
            status_text = current_player === 0 ? "X's Turn" : "O's Turn";
            this.getObjects().status.set({fill: "#2c3e50"});
         }
         this.getObjects().status.set({text: status_text});
         
         // Show next move indicator
         if (!game_over) {
            this.getObjects().next_move.set({
               text: `Considering position ${position}`,
               visible: true
            });
         } else {
            this.getObjects().next_move.set({visible: false});
         }
         
         // Draw winning line
         let win_line = this.getObjects().win_line;
         if (win) {
            let coords = null;
            
            // Check which line won
            if (parseInt(this.getSignalsValue('/game|game$highlight_row0'))) {
               coords = [160, 155, 440, 155];  // Top row
            } else if (parseInt(this.getSignalsValue('/game|game$highlight_row1'))) {
               coords = [160, 255, 440, 255];  // Middle row
            } else if (parseInt(this.getSignalsValue('/game|game$highlight_row2'))) {
               coords = [160, 355, 440, 355];  // Bottom row
            } else if (parseInt(this.getSignalsValue('/game|game$highlight_col0'))) {
               coords = [205, 110, 205, 390];  // Left column
            } else if (parseInt(this.getSignalsValue('/game|game$highlight_col1'))) {
               coords = [305, 110, 305, 390];  // Middle column
            } else if (parseInt(this.getSignalsValue('/game|game$highlight_col2'))) {
               coords = [405, 110, 405, 390];  // Right column
            } else if (parseInt(this.getSignalsValue('/game|game$highlight_diag0'))) {
               coords = [175, 130, 425, 380];  // Top-left to bottom-right
            } else if (parseInt(this.getSignalsValue('/game|game$highlight_diag1'))) {
               coords = [425, 130, 175, 380];  // Top-right to bottom-left
            }
            
            if (coords) {
               win_line.set({
                  x1: coords[0],
                  y1: coords[1],
                  x2: coords[2],
                  y2: coords[3],
                  visible: true
               });
            }
         } else {
            win_line.set({visible: false});
         }
      }

\SV
   endmodule
