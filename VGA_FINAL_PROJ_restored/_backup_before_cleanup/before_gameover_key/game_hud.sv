// game_hud - numbers at the top of the screen, levels, and GAME OVER
// (c) Technion IIT, Department of Electrical Engineering 2026
//
//  1. Clock   : counts down 1:00 -> 0:00 (one step every CLOCK_HZ clocks = 1 second).
//  2. Dollars : every collectPulse adds collectValue (the value of what the hook took).
//  3. Target  : TARGET = 48.   Level: starts at 1.
//  4. When the clock reaches 0:00:
//        dollars > TARGET -> next level: level + 1, clock back to 1:00, dollars back to 0,
//                            newLevel pulse (the gold field builds a new random layout).
//        otherwise        -> GAME OVER: the game stops and "GAME OVER" is shown in the
//                            middle of the screen until the reset button is pressed.
//  5. Drawing : red text. Digits use a 5x7 font drawn 4x bigger (20x28 per digit),
//               "GAME OVER" uses the same kind of font drawn 8x bigger (40x56 per letter).

module game_hud (
    input  logic        clk,            // 31.5 MHz
    input  logic        resetN,
    input  logic [10:0] pixelX,         // current VGA pixel
    input  logic [10:0] pixelY,
    input  logic        collectPulse,   // one clock pulse when an object is collected
    input  logic  [5:0] collectValue,   // its value in dollars
    output logic        drawingRequest,
    output logic  [7:0] RGBout,
    output logic        timeUp,         // clock shows 0:00
    output logic        gameOver,       // 1 from game over until reset (LEDR3)
    output logic        levelWon,       // 1 for 2 seconds after moving to a new level (LEDR4)
    output logic        newLevel        // one clock pulse when a level is won
);

parameter int CLOCK_HZ      = 31_500_000;
parameter int START_SECONDS = 60;
parameter int TARGET        = 48;

// where things are drawn (top-left corner)
localparam int DOLLAR_X = 56,  DOLLAR_Y = 14;   // right of the $ icon
localparam int TARGET_X = 56,  TARGET_Y = 60;   // right of the target icon
localparam int LEVEL_X  = 522, LEVEL_Y  = 12;   // right of the word "Level"
localparam int CLOCK_X  = 530, CLOCK_Y  = 52;   // right of the stopwatch
localparam int GO_X     = 108, GO_Y     = 212;  // "GAME OVER", centered on the screen

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF;
localparam logic [7:0] TEXT_COLOR = 8'hE0;       // red

localparam int CHAR_W = 20, CHAR_H = 28, STEP = 24;      // small digits (x4)
localparam int BIG_W  = 40, BIG_H  = 56, BIG_STEP = 48;  // GAME OVER letters (x8)
localparam int MSG_LEN = 9;

// 5x7 fonts, 7 rows per character, bit 4 = leftmost column
localparam logic [0:9][0:6][4:0] FONT = {
	// 0
	5'b01110, 5'b10001, 5'b10011, 5'b10101, 5'b11001, 5'b10001, 5'b01110,
	// 1
	5'b00100, 5'b01100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b01110,
	// 2
	5'b01110, 5'b10001, 5'b00001, 5'b00010, 5'b00100, 5'b01000, 5'b11111,
	// 3
	5'b11111, 5'b00010, 5'b00100, 5'b00010, 5'b00001, 5'b10001, 5'b01110,
	// 4
	5'b00010, 5'b00110, 5'b01010, 5'b10010, 5'b11111, 5'b00010, 5'b00010,
	// 5
	5'b11111, 5'b10000, 5'b11110, 5'b00001, 5'b00001, 5'b10001, 5'b01110,
	// 6
	5'b00110, 5'b01000, 5'b10000, 5'b11110, 5'b10001, 5'b10001, 5'b01110,
	// 7
	5'b11111, 5'b00001, 5'b00010, 5'b00100, 5'b01000, 5'b01000, 5'b01000,
	// 8
	5'b01110, 5'b10001, 5'b10001, 5'b01110, 5'b10001, 5'b10001, 5'b01110,
	// 9
	5'b01110, 5'b10001, 5'b10001, 5'b01111, 5'b00001, 5'b00010, 5'b01100
};

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

logic [24:0] tickCnt;       // counts clocks inside one second
logic  [6:0] secondsLeft;   // 60 .. 0
logic  [9:0] dollars;       // 0 .. 999
logic  [6:0] level;         // 1 .. 99

always_ff @(posedge clk or negedge resetN)
begin
    if (!resetN) begin
        state       <= PLAYING;
        tickCnt     <= 25'd0;
        secondsLeft <= 7'(START_SECONDS);
        dollars     <= 10'd0;
        level       <= 7'd1;
        newLevel    <= 1'b0;
    end
    else begin
        newLevel <= 1'b0;                       // default: no pulse

        if (state == PLAYING) begin
            if (secondsLeft == 7'd0) begin      // time is up - decide
                if (dollars > 10'(TARGET)) begin
                    // level won -> start the next level
                    if (level != 7'd99)
                        level <= level + 7'd1;
                    secondsLeft <= 7'(START_SECONDS);
                    tickCnt     <= 25'd0;
                    dollars     <= 10'd0;
                    newLevel    <= 1'b1;
                end
                else
                    state <= GAME_OVER_ST;      // stays here until reset
            end
            else begin
                // one-second tick
                if (tickCnt == 25'(CLOCK_HZ - 1)) begin
                    tickCnt     <= 25'd0;
                    secondsLeft <= secondsLeft - 7'd1;
                end
                else
                    tickCnt <= tickCnt + 25'd1;

                // collect dollars (stop at 999)
                if (collectPulse) begin
                    if (11'(dollars) + 11'(collectValue) > 11'd999)
                        dollars <= 10'd999;
                    else
                        dollars <= dollars + 10'(collectValue);
                end
            end
        end
    end
end

assign timeUp   = (secondsLeft == 7'd0);
assign gameOver = (state == GAME_OVER_ST);
assign levelWon = (state == PLAYING) && (level > 7'd1) && (secondsLeft >= 7'(START_SECONDS - 2));

//----------------------------------------------------------------------------
// drawing helpers
//----------------------------------------------------------------------------
// is screen point (x,y) on digit d whose top-left corner is (X,Y)?
function automatic logic digitAt(input int x, input int y, input int X, input int Y,
                                 input logic [3:0] d);
    logic hit;
    hit = 1'b0;
    if ((x >= X) && (x < X + CHAR_W) && (y >= Y) && (y < Y + CHAR_H))
        hit = FONT[d][(y - Y) >> 2][4 - ((x - X) >> 2)];
    return hit;
endfunction

// is (x,y) on the number n (0..999) drawn left-aligned from (X,Y), without leading zeros?
function automatic logic numberAt(input int x, input int y, input int X, input int Y,
                                  input logic [9:0] n);
    logic [3:0] h, t, o;
    logic hit;
    h = 4'(n / 10'd100);
    t = 4'((n / 10'd10) % 10'd10);
    o = 4'(n % 10'd10);
    if (n >= 10'd100)
        hit = digitAt(x, y, X, Y, h) || digitAt(x, y, X + STEP, Y, t) || digitAt(x, y, X + 2*STEP, Y, o);
    else if (n >= 10'd10)
        hit = digitAt(x, y, X, Y, t) || digitAt(x, y, X + STEP, Y, o);
    else
        hit = digitAt(x, y, X, Y, o);
    return hit;
endfunction

// is (x,y) on the big "GAME OVER" text?
function automatic logic gameOverTextAt(input int x, input int y);
    logic hit;
    int X;
    hit = 1'b0;
    if ((y >= GO_Y) && (y < GO_Y + BIG_H)) begin
        for (int i = 0; i < MSG_LEN; i++) begin
            X = GO_X + i * BIG_STEP;
            if ((x >= X) && (x < X + BIG_W) && (MESSAGE[i] != 3'd7))
                hit = LETTERS[MESSAGE[i]][(y - GO_Y) >> 3][4 - ((x - X) >> 3)];
        end
    end
    return hit;
endfunction

//----------------------------------------------------------------------------
// what to draw on the current pixel
//----------------------------------------------------------------------------
logic [3:0] minDigit, tensDigit, onesDigit;
logic [6:0] secPart;
assign minDigit  = (secondsLeft >= 7'd60) ? 4'd1 : 4'd0;
assign secPart   = (secondsLeft >= 7'd60) ? (secondsLeft - 7'd60) : secondsLeft;
assign tensDigit = 4'(secPart / 7'd10);
assign onesDigit = 4'(secPart % 7'd10);

int x, y;
logic onClock, onColon, onDollars, onTarget, onLevel, onGameOver;
assign x = int'(pixelX);
assign y = int'(pixelY);

// clock layout:  M : S S
assign onClock    = digitAt(x, y, CLOCK_X, CLOCK_Y, minDigit)
                 || digitAt(x, y, CLOCK_X + CHAR_W + 16, CLOCK_Y, tensDigit)
                 || digitAt(x, y, CLOCK_X + CHAR_W + 16 + STEP, CLOCK_Y, onesDigit);
assign onColon    = (x >= CLOCK_X + CHAR_W + 6) && (x < CLOCK_X + CHAR_W + 10)
                 && (((y >= CLOCK_Y + 4)  && (y < CLOCK_Y + 12))
                  || ((y >= CLOCK_Y + 16) && (y < CLOCK_Y + 24)));
assign onDollars  = numberAt(x, y, DOLLAR_X, DOLLAR_Y, dollars);
assign onTarget   = numberAt(x, y, TARGET_X, TARGET_Y, 10'(TARGET));
assign onLevel    = numberAt(x, y, LEVEL_X, LEVEL_Y, 10'(level));
assign onGameOver = gameOver && gameOverTextAt(x, y);

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
