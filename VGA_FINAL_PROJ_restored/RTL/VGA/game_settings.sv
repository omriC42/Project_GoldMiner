// game_settings - the screens of Gold Miner and the player's settings (Step 14, Oct 2026)
// (c) Technion IIT, Department of Electrical Engineering 2026
//
//  Screens (screen output, drawn by start_screen.sv):
//
//      OPENING ──ENTER──► PLAYING            (gameResetN = 1 only while PLAYING: the game blocks
//         │                  ▲                 are held in reset on the other screens, so every
//         └──+──► SETTINGS ──┘ ENTER           game starts clean with the chosen settings)
//      PLAYING + GAME OVER ──ENTER──► OPENING  (a new game without KEY0; the settings are kept)
//
//  Settings screen (rows in the order of settings_screen.png):
//      row 0 DIFFICULTY  EASY / NORMAL / HARD      -> difficulty  0 / 1 / 2
//      row 1 TIME        30 S / 60 S / 90 S        -> timeSel     0 / 1 / 2 (LEVEL_TIME_* in game_params)
//      row 2 SOUND       ON / OFF                  -> soundOn     1 / 0
//      row 3 CHEATS      ON / OFF                  -> cheatsOn    1 / 0
//    keypad 8 / 2 = cursor up / down (stops at the first / last row),
//    keypad 4 / 6 = the value to the left / right (stops at the ends), + does nothing here.
//    The cursor starts on row 0 every time the settings screen is opened.
//  * Every key acts ONCE per press (rising edge). A key held while KEY0 is released is ignored
//    until it is pressed again (the "previous" values reset to 1, like the old start_screen).
//  * The settings are reset ONLY by KEY0 (resetN), to the defaults of game_params.sv.

module game_settings (
    input  logic       clk,
    input  logic       resetN,        // KEY0 / PLL locked
    input  logic       enterKey,      // keypad ENTER (level: 1 while held)
    input  logic       plusKey,       // keypad +
    input  logic       upKey,         // keypad 8
    input  logic       downKey,       // keypad 2
    input  logic       leftKey,       // keypad 4
    input  logic       rightKey,      // keypad 6
    input  logic       gameOver,      // game_hud: 1 from game over until the game is reset

    output logic [1:0] screen,        // 0 OPENING, 1 SETTINGS, 2 PLAYING   -> start_screen
    output logic [1:0] cursor,        // selected row on the settings screen -> start_screen
    output logic [1:0] difficulty,    // 0 EASY, 1 NORMAL, 2 HARD           -> game_hud, hook_block, gold field
    output logic [1:0] timeSel,       // 0 short, 1 normal, 2 long          -> game_hud
    output logic       soundOn,       //                                     -> game_sound
    output logic       cheatsOn,      //                                     -> game_hud
    output logic       gameResetN     // reset of the game blocks: 1 only while PLAYING
);

import game_params::*;

localparam logic [1:0] S_OPENING  = 2'd0;
localparam logic [1:0] S_SETTINGS = 2'd1;
localparam logic [1:0] S_PLAYING  = 2'd2;

localparam logic [1:0] ROW_DIFFICULTY = 2'd0;
localparam logic [1:0] ROW_TIME       = 2'd1;
localparam logic [1:0] ROW_SOUND      = 2'd2;
localparam logic [1:0] ROW_CHEATS     = 2'd3;

// ---------------- one-press detection for every key ----------------
logic enter_d, plus_d, up_d, down_d, left_d, right_d;     // the keys one clock ago
logic enterP, plusP, upP, downP, leftP, rightP;           // 1 for ONE clock when the key is pressed
assign enterP = enterKey && !enter_d;
assign plusP  = plusKey  && !plus_d;
assign upP    = upKey    && !up_d;
assign downP  = downKey  && !down_d;
assign leftP  = leftKey  && !left_d;
assign rightP = rightKey && !right_d;

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        // 1 = "was held": a key held during reset must be released and pressed again
        enter_d <= 1'b1;  plus_d <= 1'b1;  up_d <= 1'b1;  down_d <= 1'b1;  left_d <= 1'b1;  right_d <= 1'b1;
    end
    else begin
        enter_d <= enterKey;  plus_d <= plusKey;  up_d <= upKey;
        down_d  <= downKey;   left_d <= leftKey;  right_d <= rightKey;
    end
end

// ---------------- screens + settings ----------------
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        screen     <= S_OPENING;
        cursor     <= ROW_DIFFICULTY;
        difficulty <= 2'(DIFFICULTY);          // the defaults of game_params.sv
        timeSel    <= 2'(DEFAULT_TIME_SEL);
        soundOn    <= SOUND_ON;
        cheatsOn   <= CHEATS_ON;
        gameResetN <= 1'b0;
    end
    else begin
        case (screen)
            S_OPENING: begin
                if (enterP)
                    screen <= S_PLAYING;
                else if (plusP) begin
                    screen <= S_SETTINGS;
                    cursor <= ROW_DIFFICULTY;          // always start on the first row
                end
            end

            S_SETTINGS: begin
                if (enterP)
                    screen <= S_PLAYING;
                else begin
                    // cursor: 8 = up, 2 = down
                    if (upP && cursor != ROW_DIFFICULTY)
                        cursor <= cursor - 2'd1;
                    else if (downP && cursor != ROW_CHEATS)
                        cursor <= cursor + 2'd1;
                    // value of the selected row: 4 = left, 6 = right
                    case (cursor)
                        ROW_DIFFICULTY: begin
                            if (leftP && difficulty != 2'd0)       difficulty <= difficulty - 2'd1;
                            else if (rightP && difficulty != 2'd2) difficulty <= difficulty + 2'd1;
                        end
                        ROW_TIME: begin
                            if (leftP && timeSel != 2'd0)          timeSel <= timeSel - 2'd1;
                            else if (rightP && timeSel != 2'd2)    timeSel <= timeSel + 2'd1;
                        end
                        ROW_SOUND: begin                           // ON is on the left, OFF on the right
                            if (leftP)       soundOn <= 1'b1;
                            else if (rightP) soundOn <= 1'b0;
                        end
                        default: begin                             // ROW_CHEATS
                            if (leftP)       cheatsOn <= 1'b1;
                            else if (rightP) cheatsOn <= 1'b0;
                        end
                    endcase
                end
            end

            S_PLAYING: begin
                if (gameOver && enterP)
                    screen <= S_OPENING;                   // new game: back to the opening screen
            end

            default: screen <= S_OPENING;
        endcase
        gameResetN <= (screen == S_PLAYING);               // the game runs one clock after ENTER
    end
end

endmodule
