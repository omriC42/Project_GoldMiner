// game_hud - numbers at the top of the screen, levels, and GAME OVER
// (c) Technion IIT, Department of Electrical Engineering 2026
//
//  1. Clock   : counts down the level time -> 0:00 (one step every CLOCK_HZ clocks = 1 second).
//     Oct 2026 (Step 14): the time (30/60/90 s, timeSel), the difficulty (targets) and cheats on/off
//     are INPUTS from the settings screen; the numbers for each choice are in game_params.sv.
//  2. Dollars : every collectPulse adds collectValue (the value of what the hook took).
//  3. Target  : level 1 needs TARGET_START, every won level adds TARGET_STEP (max 999), both
//               chosen by the difficulty input (game_params.sv).   Level: starts at 1.
//  4. When the clock reaches 0:00:
//        dollars >= target -> next level: level + 1, clock back to the start, dollars back to 0,
//                             newLevel pulse (the gold field builds a new random layout).
//        (keypad * jumps straight to GAME OVER at any time, keypad + to the next level - cheats,
//         only when cheatsOn = 1)
//        otherwise         -> GAME OVER: the game stops and "GAME OVER" is shown in the
//                             middle of the screen until the reset button is pressed.
//  5. Drawing : red text. Digits use a 5x7 font drawn 4x bigger (20x28 per digit, hud_digit.sv),
//               "GAME OVER" uses the same kind of font drawn 8x bigger (40x56 per letter).
//
//  Oct 2026 (Step 12) NO DIVIDERS, NO FUNCTIONS:
//   * every number is kept TWICE: as a binary number (to compare: score >= target, time = 0)
//     and as decimal digits (to draw). The digits are counted directly in decimal:
//       dollars  dolH dolT dolO : + collectValue, digit by digit with carries (like on paper)
//       target   tgtH tgtT tgtO : + TARGET_STEP at every new level (was already like this)
//       level    lvlT lvlO      : + 1 at every new level
//       clock    minD secT secO : - 1 every second (9 -> 8 ... 0 -> 9 with a borrow, 0 -> 5 for tens)
//     The only "/" and "%" left are on constants (the start values), worked out by Quartus.
//  Oct 2026 (Step 14) START VALUES: on the first clock after reset (loadStart) the clock, the target
//   and their digits are loaded from the chosen time / difficulty (tables of constants). The game
//   is held in reset while the player is on the opening / settings screen, so the choice is stable.
//   * the old drawing functions (digitAt / numberAt / gameOverTextAt) became 11 instances of the
//     small module hud_digit (one per digit place) and one always_comb block for GAME OVER.

module game_hud (
    input  logic        clk,            // 31.5 MHz
    input  logic        resetN,
    input  logic [10:0] pixelX,         // current VGA pixel
    input  logic [10:0] pixelY,
    input  logic        collectPulse,   // one clock pulse when an object is collected
    input  logic  [5:0] collectValue,   // its value in dollars
    input  logic        gameOverKey,    // shortcut: keypad * ends the game
    input  logic        nextLevelKey,   // shortcut: keypad + jumps to next level
    input  logic  [1:0] difficulty,     // settings: 0 EASY, 1 NORMAL, 2 HARD (game_params::difficulty_t)
    input  logic  [1:0] timeSel,        // settings: 0 short, 1 normal, 2 long (LEVEL_TIME_* in game_params)
    input  logic        cheatsOn,       // settings: 1 = keypad + and * work
    output logic        drawingRequest,
    output logic  [7:0] RGBout,
    output logic        timeUp,         // clock shows 0:00
    output logic        gameOver,       // 1 from game over until reset (LEDR3)
    output logic        levelWon,       // 1 for 2 seconds after moving to a new level (LEDR4)
    output logic        newLevel        // one clock pulse when a level is won
);

import game_params::*;

parameter int CLOCK_HZ      = 31_500_000;

// where things are drawn (top-left corner)
localparam int DOLLAR_X = 56,  DOLLAR_Y = 14;   // right of the $ icon
localparam int TARGET_X = 56,  TARGET_Y = 60;   // right of the target icon
localparam int LEVEL_X  = 522, LEVEL_Y  = 12;   // right of the word "Level"
localparam int CLOCK_X  = 530, CLOCK_Y  = 52;   // right of the stopwatch
localparam int GO_X     = 108, GO_Y     = 212;  // "GAME OVER", centered on the screen

localparam int T_MAX   = 999;
// the choices of the settings screen as numbers AND as decimal digits - all CONSTANTS from
// game_params.sv, so the "/" and "%" here are done by Quartus while compiling (no hardware)
localparam int TS_E = TARGET_START_EASY, TS_N = TARGET_START_NORMAL, TS_H = TARGET_START_HARD;
localparam int TP_E = TARGET_STEP_EASY,  TP_N = TARGET_STEP_NORMAL,  TP_H = TARGET_STEP_HARD;
localparam int LT_S = LEVEL_TIME_SHORT,  LT_N = LEVEL_TIME_NORMAL,   LT_L = LEVEL_TIME_LONG;

// ---------------- this game's start values (from the settings inputs) ----------------
logic [9:0] tStart, tStep;            // level-1 target, target step
logic [3:0] tStartH, tStartT, tStartO, tStepH, tStepT, tStepO;
logic [6:0] startSeconds;             // time per level
logic [3:0] sStartM, sStartT, sStartO;
always_comb begin
    case (difficulty_t'(difficulty))
        EASY: begin
            tStart = 10'(TS_E); tStartH = 4'(TS_E / 100); tStartT = 4'((TS_E / 10) % 10); tStartO = 4'(TS_E % 10);
            tStep  = 10'(TP_E); tStepH  = 4'(TP_E / 100); tStepT  = 4'((TP_E / 10) % 10); tStepO  = 4'(TP_E % 10);
        end
        HARD: begin
            tStart = 10'(TS_H); tStartH = 4'(TS_H / 100); tStartT = 4'((TS_H / 10) % 10); tStartO = 4'(TS_H % 10);
            tStep  = 10'(TP_H); tStepH  = 4'(TP_H / 100); tStepT  = 4'((TP_H / 10) % 10); tStepO  = 4'(TP_H % 10);
        end
        default: begin                // NORMAL
            tStart = 10'(TS_N); tStartH = 4'(TS_N / 100); tStartT = 4'((TS_N / 10) % 10); tStartO = 4'(TS_N % 10);
            tStep  = 10'(TP_N); tStepH  = 4'(TP_N / 100); tStepT  = 4'((TP_N / 10) % 10); tStepO  = 4'(TP_N % 10);
        end
    endcase
    case (timeSel)
        2'd0:    begin startSeconds = 7'(LT_S); sStartM = 4'(LT_S / 60); sStartT = 4'((LT_S % 60) / 10); sStartO = 4'(LT_S % 10); end
        2'd2:    begin startSeconds = 7'(LT_L); sStartM = 4'(LT_L / 60); sStartT = 4'((LT_L % 60) / 10); sStartO = 4'(LT_L % 10); end
        default: begin startSeconds = 7'(LT_N); sStartM = 4'(LT_N / 60); sStartT = 4'((LT_N % 60) / 10); sStartO = 4'(LT_N % 10); end
    endcase
end

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF;
localparam logic [7:0] TEXT_COLOR = 8'hE0;       // red

localparam int CHAR_W = 20, CHAR_H = 28, STEP = 24;      // small digits (x4)
localparam int BIG_W  = 40, BIG_H  = 56, BIG_STEP = 48;  // GAME OVER letters (x8)
localparam int MSG_LEN = 9;

// 5x7 font for the GAME OVER letters (the digit font is in hud_digit.sv), bit 4 = leftmost column

localparam logic [0:6][0:6][4:0] LETTERS = {
	// G
	5'b01110, 5'b10001, 5'b10000, 5'b10111, 5'b10001, 5'b10001, 5'b01111,
	// A
	5'b01110, 5'b10001, 5'b10001, 5'b11111, 5'b10001, 5'b10001, 5'b10001,
	// M
	5'b10001, 5'b11011, 5'b10101, 5'b10101, 5'b10001, 5'b10001, 5'b10001,
	// E
	5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b10000, 5'b10000, 5'b11111,
	// O
	5'b01110, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01110,
	// V
	5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01010, 5'b00100,
	// R
	5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10100, 5'b10010, 5'b10001
};

// "GAME OVER" as letter codes: G=0 A=1 M=2 E=3 O=4 V=5 R=6, 7 = space
localparam logic [0:MSG_LEN-1][2:0] MESSAGE = {3'd0, 3'd1, 3'd2, 3'd3, 3'd7, 3'd4, 3'd5, 3'd3, 3'd6};

//----------------------------------------------------------------------------
// game state
//----------------------------------------------------------------------------
enum logic {PLAYING, GAME_OVER_ST} state;

logic [24:0] tickCnt;            // counts clocks inside one second
logic  [6:0] secondsLeft;        // level time .. 0      (binary: for "time is up")
logic  [3:0] minD, secT, secO;   // the same time as digits M:TO (for the screen)
logic  [9:0] dollars;            // 0 .. 999             (binary: for "score >= target")
logic  [3:0] dolH, dolT, dolO;   // the same score as digits
logic  [6:0] level;              // 1 .. 99
logic  [3:0] lvlT, lvlO;         // the same level as digits
logic  [9:0] target;             // dollars needed in this level (to compare with the score)
logic  [3:0] tgtH, tgtT, tgtO;   // the same target as decimal digits (to draw it)

// ---------------- next target = target + tStep (stops at 999), as a number and as digits ----------------
logic [10:0] targetSum;
logic  [9:0] targetNext;
logic  [4:0] sumO, sumT, sumH;   // decimal digit addition with carry
logic  [3:0] nextH, nextT, nextO;
always_comb begin
    targetSum = 11'(target) + 11'(tStep);
    sumO = 5'(tgtO) + 5'(tStepO);
    sumT = 5'(tgtT) + 5'(tStepT) + ((sumO > 5'd9) ? 5'd1 : 5'd0);
    sumH = 5'(tgtH) + 5'(tStepH) + ((sumT > 5'd9) ? 5'd1 : 5'd0);
    nextO = (sumO > 5'd9) ? 4'(sumO - 5'd10) : 4'(sumO);
    nextT = (sumT > 5'd9) ? 4'(sumT - 5'd10) : 4'(sumT);
    nextH = 4'(sumH);
    if (targetSum > 11'(T_MAX)) begin              // stop at 999
        targetNext = 10'(T_MAX);
        nextH = 4'd9; nextT = 4'd9; nextO = 4'd9;
    end
    else
        targetNext = 10'(targetSum);
end

// ---------------- dollars + collectValue, as a number and as digits ----------------
// collectValue (0..63) split into tens and ones by comparing (no divider): 0..6 tens
logic [3:0] valT, valO;
always_comb begin
    if      (collectValue >= 6'd60) valT = 4'd6;
    else if (collectValue >= 6'd50) valT = 4'd5;
    else if (collectValue >= 6'd40) valT = 4'd4;
    else if (collectValue >= 6'd30) valT = 4'd3;
    else if (collectValue >= 6'd20) valT = 4'd2;
    else if (collectValue >= 6'd10) valT = 4'd1;
    else                            valT = 4'd0;
    valO = 4'(collectValue - 6'({valT, 3'b000}) - 6'({valT, 1'b0}));   // value - 8*tens - 2*tens
end
logic [10:0] dolSum;
logic  [4:0] dSumO, dSumT, dSumH;
logic  [3:0] dNextH, dNextT, dNextO;
logic  [9:0] dollarsNext;
always_comb begin
    dolSum = 11'(dollars) + 11'(collectValue);
    dSumO  = 5'(dolO) + 5'(valO);
    dSumT  = 5'(dolT) + 5'(valT) + ((dSumO > 5'd9) ? 5'd1 : 5'd0);
    dSumH  = 5'(dolH)            + ((dSumT > 5'd9) ? 5'd1 : 5'd0);
    dNextO = (dSumO > 5'd9) ? 4'(dSumO - 5'd10) : 4'(dSumO);
    dNextT = (dSumT > 5'd9) ? 4'(dSumT - 5'd10) : 4'(dSumT);
    dNextH = 4'(dSumH);
    if (dolSum > 11'd999) begin                    // stop at 999
        dollarsNext = 10'd999;
        dNextH = 4'd9; dNextT = 4'd9; dNextO = 4'd9;
    end
    else
        dollarsNext = 10'(dolSum);
end

//handles cheat key
logic nextLevelKey_d;          // the key one clock ago
logic cheatNextLevel;          // 1 for ONE clock when + is pressed
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) nextLevelKey_d <= 1'b0;
    else         nextLevelKey_d <= nextLevelKey;
end
assign cheatNextLevel = nextLevelKey && !nextLevelKey_d && cheatsOn;

logic loadStart;               // 1 on the first clock after reset: load the start values
always_ff @(posedge clk or negedge resetN)
begin
    if (!resetN) begin
        loadStart   <= 1'b1;
        state       <= PLAYING;
        tickCnt     <= 25'd0;
        secondsLeft <= 7'd0;                    // all 0 in reset; the start values are loaded
        minD        <= 4'd0;
        secT        <= 4'd0;
        secO        <= 4'd0;
        dollars     <= 10'd0;
        dolH        <= 4'd0;
        dolT        <= 4'd0;
        dolO        <= 4'd0;
        level       <= 7'd1;
        lvlT        <= 4'd0;
        lvlO        <= 4'd1;
        target      <= 10'd0;                   // on the first clock after reset (loadStart)
        tgtH        <= 4'd0;
        tgtT        <= 4'd0;
        tgtO        <= 4'd0;
        newLevel    <= 1'b0;
    end
    else if (loadStart) begin                  // first clock: the start values of the chosen settings
        loadStart   <= 1'b0;
        secondsLeft <= startSeconds;
        minD        <= sStartM;
        secT        <= sStartT;
        secO        <= sStartO;
        target      <= tStart;
        tgtH        <= tStartH;
        tgtT        <= tStartT;
        tgtO        <= tStartO;
    end
    else begin
        newLevel <= 1'b0;                       // default: no pulse

        if (state == PLAYING) begin
            if (gameOverKey && cheatsOn)
                state <= GAME_OVER_ST;          // shortcut key (keypad *)
            else if (secondsLeft == 7'd0 && dollars >= target || cheatNextLevel) begin      // time is up - decide
                    // level won -> start the next level, which needs TARGET_STEP more
                    if (level != 7'd99) begin
                        level <= level + 7'd1;
                        if (lvlO == 4'd9) begin lvlO <= 4'd0; lvlT <= lvlT + 4'd1; end
                        else                    lvlO <= lvlO + 4'd1;
                    end
                    target      <= targetNext;
                    tgtH        <= nextH;
                    tgtT        <= nextT;
                    tgtO        <= nextO;
                    secondsLeft <= startSeconds;
                    minD        <= sStartM;
                    secT        <= sStartT;
                    secO        <= sStartO;
                    tickCnt     <= 25'd0;
                    dollars     <= 10'd0;
                    dolH        <= 4'd0;
                    dolT        <= 4'd0;
                    dolO        <= 4'd0;
                    newLevel    <= 1'b1;
                end
            else if (secondsLeft == 7'd0) begin
                state <= GAME_OVER_ST;          // stays here until reset
            end
            else begin
                // one-second tick: the number and its digits go down together
                if (tickCnt == 25'(CLOCK_HZ - 1)) begin
                    tickCnt     <= 25'd0;
                    secondsLeft <= secondsLeft - 7'd1;
                    if (secO != 4'd0)
                        secO <= secO - 4'd1;
                    else begin
                        secO <= 4'd9;                   // x0 -> (x-1)9
                        if (secT != 4'd0)
                            secT <= secT - 4'd1;
                        else begin
                            secT <= 4'd5;               // 1:00 -> 0:59
                            minD <= minD - 4'd1;
                        end
                    end
                end
                else
                    tickCnt <= tickCnt + 25'd1;

                // collect dollars (stop at 999)
                if (collectPulse) begin
                    dollars <= dollarsNext;
                    dolH    <= dNextH;
                    dolT    <= dNextT;
                    dolO    <= dNextO;
                end
            end
        end
    end
end

assign timeUp   = (secondsLeft == 7'd0);
assign gameOver = (state == GAME_OVER_ST);
assign levelWon = (state == PLAYING) && (level > 7'd1) && (secondsLeft + 7'd2 >= startSeconds);

//----------------------------------------------------------------------------
// drawing: one hud_digit per digit place (no leading zeros: numbers are left-aligned)
//----------------------------------------------------------------------------
// which digit goes in place 0/1/2 of a left-aligned number, and is the place used
logic [3:0] dolP0, dolP1, dolP2;  logic dolU1, dolU2;
assign dolP0 = (dolH != 4'd0) ? dolH : (dolT != 4'd0) ? dolT : dolO;
assign dolP1 = (dolH != 4'd0) ? dolT : dolO;
assign dolP2 = dolO;
assign dolU1 = (dolH != 4'd0) || (dolT != 4'd0);
assign dolU2 = (dolH != 4'd0);
logic [3:0] tgtP0, tgtP1, tgtP2;  logic tgtU1, tgtU2;
assign tgtP0 = (tgtH != 4'd0) ? tgtH : (tgtT != 4'd0) ? tgtT : tgtO;
assign tgtP1 = (tgtH != 4'd0) ? tgtT : tgtO;
assign tgtP2 = tgtO;
assign tgtU1 = (tgtH != 4'd0) || (tgtT != 4'd0);
assign tgtU2 = (tgtH != 4'd0);
logic [3:0] lvlP0, lvlP1;  logic lvlU1;
assign lvlP0 = (lvlT != 4'd0) ? lvlT : lvlO;
assign lvlP1 = lvlO;
assign lvlU1 = (lvlT != 4'd0);

logic onDol0, onDol1, onDol2, onTgt0, onTgt1, onTgt2, onLvl0, onLvl1, onMin, onSecT, onSecO;
hud_digit #(.X(DOLLAR_X),            .Y(DOLLAR_Y)) dDol0 (.pixelX, .pixelY, .digit(dolP0), .show(1'b1),  .hit(onDol0));
hud_digit #(.X(DOLLAR_X + STEP),     .Y(DOLLAR_Y)) dDol1 (.pixelX, .pixelY, .digit(dolP1), .show(dolU1), .hit(onDol1));
hud_digit #(.X(DOLLAR_X + 2*STEP),   .Y(DOLLAR_Y)) dDol2 (.pixelX, .pixelY, .digit(dolP2), .show(dolU2), .hit(onDol2));
hud_digit #(.X(TARGET_X),            .Y(TARGET_Y)) dTgt0 (.pixelX, .pixelY, .digit(tgtP0), .show(1'b1),  .hit(onTgt0));
hud_digit #(.X(TARGET_X + STEP),     .Y(TARGET_Y)) dTgt1 (.pixelX, .pixelY, .digit(tgtP1), .show(tgtU1), .hit(onTgt1));
hud_digit #(.X(TARGET_X + 2*STEP),   .Y(TARGET_Y)) dTgt2 (.pixelX, .pixelY, .digit(tgtP2), .show(tgtU2), .hit(onTgt2));
hud_digit #(.X(LEVEL_X),             .Y(LEVEL_Y))  dLvl0 (.pixelX, .pixelY, .digit(lvlP0), .show(1'b1),  .hit(onLvl0));
hud_digit #(.X(LEVEL_X + STEP),      .Y(LEVEL_Y))  dLvl1 (.pixelX, .pixelY, .digit(lvlP1), .show(lvlU1), .hit(onLvl1));
// clock layout:  M : S S
hud_digit #(.X(CLOCK_X),                     .Y(CLOCK_Y)) dMin  (.pixelX, .pixelY, .digit(minD), .show(1'b1), .hit(onMin));
hud_digit #(.X(CLOCK_X + CHAR_W + 16),        .Y(CLOCK_Y)) dSecT (.pixelX, .pixelY, .digit(secT), .show(1'b1), .hit(onSecT));
hud_digit #(.X(CLOCK_X + CHAR_W + 16 + STEP), .Y(CLOCK_Y)) dSecO (.pixelX, .pixelY, .digit(secO), .show(1'b1), .hit(onSecO));

int x, y;
assign x = int'(pixelX);
assign y = int'(pixelY);

logic onColon;
assign onColon = (x >= CLOCK_X + CHAR_W + 6) && (x < CLOCK_X + CHAR_W + 10)
              && (((y >= CLOCK_Y + 4)  && (y < CLOCK_Y + 12))
               || ((y >= CLOCK_Y + 16) && (y < CLOCK_Y + 24)));

// "GAME OVER": 9 letter places, BIG_STEP apart; the font is drawn 8x bigger (>> 3)
logic onGameOverText;
always_comb begin
    onGameOverText = 1'b0;
    if ((y >= GO_Y) && (y < GO_Y + BIG_H)) begin
        for (int i = 0; i < MSG_LEN; i++) begin
            if ((x >= GO_X + i * BIG_STEP) && (x < GO_X + i * BIG_STEP + BIG_W) && (MESSAGE[i] != 3'd7))
                onGameOverText = LETTERS[MESSAGE[i]][(y - GO_Y) >> 3][4 - ((x - (GO_X + i * BIG_STEP)) >> 3)];
        end
    end
end

logic onClock, onDollars, onTarget, onLevel, onGameOver;
assign onClock    = onMin || onSecT || onSecO;
assign onDollars  = onDol0 || onDol1 || onDol2;
assign onTarget   = onTgt0 || onTgt1 || onTgt2;
assign onLevel    = onLvl0 || onLvl1;
assign onGameOver = gameOver && onGameOverText;

always_ff @(posedge clk or negedge resetN)
begin
    if (!resetN)
        RGBout <= TRANSPARENT_ENCODING;
    else
        RGBout <= (onClock || onColon || onDollars || onTarget || onLevel || onGameOver)
                  ? TEXT_COLOR : TRANSPARENT_ENCODING;
end

assign drawingRequest = (RGBout != TRANSPARENT_ENCODING);

endmodule
