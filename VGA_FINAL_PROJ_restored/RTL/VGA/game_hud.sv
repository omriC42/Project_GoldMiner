// game_hud - numbers at the top of the screen, levels, and GAME OVER

module game_hud (
    input  logic        clk,            // 31.5 MHz
    input  logic        resetN,
    input  logic [10:0] pixelX,         // current VGA pixel
    input  logic [10:0] pixelY,
    input  logic        collectPulse,   // one clock pulse when an object reaches the top
    input  logic  [5:0] collectValue,   // its value in dollars
    input  logic        gameOverKey,    // cheat: keypad * ends the game
    input  logic        nextLevelKey,   // cheat: keypad + jumps to next level
    input  logic  [1:0] difficulty,     // settings: 0 EASY, 1 NORMAL, 2 HARD 
    input  logic  [1:0] timeSel,        // settings: 0 short, 1 normal, 2 long 
    input  logic        cheatsOn,       // settings: 1 = keypad + and * work
    output logic        drawingRequest,
    output logic  [7:0] RGBout,
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

//----------------------------------------------------------------------------
// the start values of every setting, as decimal digits - CONSTANTS from game_params.sv
//----------------------------------------------------------------------------
// targets {H, T, O}
localparam logic [11:0] TSTART_EASY   = {4'(TARGET_START_EASY   / 100), 4'((TARGET_START_EASY   / 10) % 10), 4'(TARGET_START_EASY   % 10)};
localparam logic [11:0] TSTART_NORMAL = {4'(TARGET_START_NORMAL / 100), 4'((TARGET_START_NORMAL / 10) % 10), 4'(TARGET_START_NORMAL % 10)};
localparam logic [11:0] TSTART_HARD   = {4'(TARGET_START_HARD   / 100), 4'((TARGET_START_HARD   / 10) % 10), 4'(TARGET_START_HARD   % 10)};
localparam logic [11:0] TSTEP_EASY    = {4'(TARGET_STEP_EASY    / 100), 4'((TARGET_STEP_EASY    / 10) % 10), 4'(TARGET_STEP_EASY    % 10)};
localparam logic [11:0] TSTEP_NORMAL  = {4'(TARGET_STEP_NORMAL  / 100), 4'((TARGET_STEP_NORMAL  / 10) % 10), 4'(TARGET_STEP_NORMAL  % 10)};
localparam logic [11:0] TSTEP_HARD    = {4'(TARGET_STEP_HARD    / 100), 4'((TARGET_STEP_HARD    / 10) % 10), 4'(TARGET_STEP_HARD    % 10)};
// level time {M, T, O} (M:TO), and "2 seconds after the start" (levelWon shows until then)
localparam logic [11:0] TIME_SHORT  = {4'(LEVEL_TIME_SHORT  / 60), 4'((LEVEL_TIME_SHORT  % 60) / 10), 4'(LEVEL_TIME_SHORT  % 10)};
localparam logic [11:0] TIME_NORMAL = {4'(LEVEL_TIME_NORMAL / 60), 4'((LEVEL_TIME_NORMAL % 60) / 10), 4'(LEVEL_TIME_NORMAL % 10)};
localparam logic [11:0] TIME_LONG   = {4'(LEVEL_TIME_LONG   / 60), 4'((LEVEL_TIME_LONG   % 60) / 10), 4'(LEVEL_TIME_LONG   % 10)};
localparam logic [11:0] WON_SHORT   = {4'((LEVEL_TIME_SHORT  - 2) / 60), 4'(((LEVEL_TIME_SHORT  - 2) % 60) / 10), 4'((LEVEL_TIME_SHORT  - 2) % 10)};
localparam logic [11:0] WON_NORMAL  = {4'((LEVEL_TIME_NORMAL - 2) / 60), 4'(((LEVEL_TIME_NORMAL - 2) % 60) / 10), 4'((LEVEL_TIME_NORMAL - 2) % 10)};
localparam logic [11:0] WON_LONG    = {4'((LEVEL_TIME_LONG   - 2) / 60), 4'(((LEVEL_TIME_LONG   - 2) % 60) / 10), 4'((LEVEL_TIME_LONG   - 2) % 10)};

// the values of THIS game (picked by the settings inputs)
logic [11:0] targetStart, targetStep;   // level-1 target, target step
logic [11:0] timeStart, wonUntil;       // level time, and the time 2 seconds after the start
always_comb begin
    case (difficulty_t'(difficulty))
        EASY:    begin targetStart = TSTART_EASY;   targetStep = TSTEP_EASY;   end
        HARD:    begin targetStart = TSTART_HARD;   targetStep = TSTEP_HARD;   end
        default: begin targetStart = TSTART_NORMAL; targetStep = TSTEP_NORMAL; end
    endcase
    case (timeSel)
        2'd0:    begin timeStart = TIME_SHORT;  wonUntil = WON_SHORT;  end
        2'd2:    begin timeStart = TIME_LONG;   wonUntil = WON_LONG;   end
        default: begin timeStart = TIME_NORMAL; wonUntil = WON_NORMAL; end
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
logic  [3:0] minD, secT, secO;   // time left       M:TO
logic  [3:0] dolH, dolT, dolO;   // dollars          0 .. 999
logic  [3:0] lvlT, lvlO;         // level            1 .. 99
logic  [3:0] tgtH, tgtT, tgtO;   // target dollars   (0 .. 999)

logic timeUp, enoughDollars;
assign timeUp        = ({minD, secT, secO} == 12'h000);
assign enoughDollars = ({dolH, dolT, dolO} >= {tgtH, tgtT, tgtO});

// next values, column by column (stop at 999)
logic [11:0] dollarsNext, targetNext;
logic  [3:0] valT, valO;         // collectValue (0..63) as decimal digits
bcd_add3 addDollars (.a({dolH, dolT, dolO}), .b({4'd0, valT, valO}),   .sum(dollarsNext));
bcd_add3 addTarget  (.a({tgtH, tgtT, tgtO}), .b(targetStep),           .sum(targetNext));

// collectValue (0..63) split into tens and ones by comparing (no divider): 0..6 tens
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

// cheat key + : one step per press
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
        loadStart <= 1'b1;
        state     <= PLAYING;
        tickCnt   <= 25'd0;
        {minD, secT, secO} <= 12'h000;          // all 0 in reset; the start values are loaded
        {dolH, dolT, dolO} <= 12'h000;          // on the first clock after reset (loadStart)
        {lvlT, lvlO}       <= 8'h01;
        {tgtH, tgtT, tgtO} <= 12'h000;
        newLevel  <= 1'b0;
    end
    else if (loadStart) begin                  // first clock: the start values of the chosen settings
        loadStart          <= 1'b0;
        {minD, secT, secO} <= timeStart;
        {tgtH, tgtT, tgtO} <= targetStart;
    end
    else begin
        newLevel <= 1'b0;                       // default: no pulse

        if (state == PLAYING) begin
            if (gameOverKey && cheatsOn)
                state <= GAME_OVER_ST;          // cheat key (keypad *)
            else if (timeUp && enoughDollars || cheatNextLevel) begin
                // level won -> start the next level, which needs the target step more
                if ({lvlT, lvlO} != 8'h99) begin
                    if (lvlO == 4'd9) begin lvlO <= 4'd0; lvlT <= lvlT + 4'd1; end
                    else                    lvlO <= lvlO + 4'd1;
                end
                {tgtH, tgtT, tgtO} <= targetNext;
                {minD, secT, secO} <= timeStart;
                tickCnt            <= 25'd0;
                {dolH, dolT, dolO} <= 12'h000;
                newLevel           <= 1'b1;
            end
            else if (timeUp) begin
                state <= GAME_OVER_ST;          // stays here until reset
            end
            else begin
                // one-second tick: M:TO goes down by one second
                if (tickCnt == 25'(CLOCK_HZ - 1)) begin
                    tickCnt <= 25'd0;
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
                if (collectPulse)
                    {dolH, dolT, dolO} <= dollarsNext;
            end
        end
    end
end

assign gameOver = (state == GAME_OVER_ST);
// "level won" sign: from level 2 on, during the first 2 seconds of the level
assign levelWon = (state == PLAYING) && ({lvlT, lvlO} > 8'h01) && ({minD, secT, secO} >= wonUntil);

//----------------------------------------------------------------------------
// drawing
//----------------------------------------------------------------------------
logic onDollars, onTarget, onLevel;
hud_number #(.X(DOLLAR_X), .Y(DOLLAR_Y), .STEP(STEP)) numDollars (.pixelX, .pixelY, .value({dolH, dolT, dolO}), .hit(onDollars));
hud_number #(.X(TARGET_X), .Y(TARGET_Y), .STEP(STEP)) numTarget  (.pixelX, .pixelY, .value({tgtH, tgtT, tgtO}), .hit(onTarget));
hud_number #(.X(LEVEL_X),  .Y(LEVEL_Y),  .STEP(STEP)) numLevel   (.pixelX, .pixelY, .value({4'd0, lvlT, lvlO}), .hit(onLevel));

// clock layout:  M : S S  (always all 3 digits)
logic onMin, onSecT, onSecO;
hud_digit #(.X(CLOCK_X),                      .Y(CLOCK_Y)) dMin  (.pixelX, .pixelY, .digit(minD), .show(1'b1), .hit(onMin));
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

logic onClock, onGameOver;
assign onClock    = onMin || onSecT || onSecO;
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
