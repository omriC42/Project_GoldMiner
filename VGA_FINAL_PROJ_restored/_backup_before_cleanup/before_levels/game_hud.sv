// game_hud - the numbers at the top of the screen + the end-of-game decision
// (c) Technion IIT, Department of Electrical Engineering 2026
//
//  1. Clock   : counts down 1:00 -> 0:00 (one step every CLOCK_HZ clocks = 1 second).
//  2. Dollars : every collectPulse adds collectValue (value of the gold/rock the hook took).
//               Collecting stops when the time is up.
//  3. Target  : a fixed goal, TARGET = 48.
//  4. End     : when the clock reaches 0:00
//                  levelWon = 1  if dollars >= TARGET
//                  gameOver = 1  if dollars <  TARGET
//               Both are 0 while the clock is still running.
//  5. Drawing : red digits (5x7 font, every font pixel = 4x4 screen pixels -> 20x28 per digit)
//                  dollars next to the $ icon, target next to the target icon, clock next to
//                  the stopwatch. Numbers are left-aligned, no leading zeros.

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
    output logic        gameOver,       // time is up and the target was NOT reached
    output logic        levelWon        // time is up and the target WAS reached
);

parameter int CLOCK_HZ      = 31_500_000;
parameter int START_SECONDS = 60;
parameter int TARGET        = 48;

// where the numbers are drawn (top-left of the first digit)
localparam int DOLLAR_X = 56,  DOLLAR_Y = 14;   // right of the $ icon
localparam int TARGET_X = 56,  TARGET_Y = 60;   // right of the target icon
localparam int CLOCK_X  = 530, CLOCK_Y  = 52;   // right of the stopwatch

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF;
localparam logic [7:0] TEXT_COLOR = 8'hE0;       // red

localparam int CHAR_W = 20;                      // 5 font pixels * 4
localparam int CHAR_H = 28;                      // 7 font pixels * 4
localparam int STEP   = 24;                      // digit width + 4 pixels space

// 5x7 font, 7 rows per digit, bit 4 = leftmost column
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

//----------------------------------------------------------------------------
// 1. clock: one-second tick and countdown
//----------------------------------------------------------------------------
logic [24:0] tickCnt;
logic  [6:0] secondsLeft;

always_ff @(posedge clk or negedge resetN)
begin
    if (!resetN) begin
        tickCnt     <= 25'd0;
        secondsLeft <= 7'(START_SECONDS);
    end
    else if (secondsLeft != 7'd0) begin
        if (tickCnt == 25'(CLOCK_HZ - 1)) begin
            tickCnt     <= 25'd0;
            secondsLeft <= secondsLeft - 7'd1;
        end
        else
            tickCnt <= tickCnt + 25'd1;
    end
end

assign timeUp = (secondsLeft == 7'd0);

//----------------------------------------------------------------------------
// 2. dollars
//----------------------------------------------------------------------------
logic [9:0] dollars;   // 0..999

always_ff @(posedge clk or negedge resetN)
begin
    if (!resetN)
        dollars <= 10'd0;
    else if (collectPulse && !timeUp) begin
        if (11'(dollars) + 11'(collectValue) > 11'd999)   // 11 bits so the sum can't overflow
            dollars <= 10'd999;
        else
            dollars <= dollars + collectValue;
    end
end

//----------------------------------------------------------------------------
// 4. end of game
//----------------------------------------------------------------------------
assign levelWon = timeUp && (dollars >= 10'(TARGET));
assign gameOver = timeUp && (dollars <  10'(TARGET));

//----------------------------------------------------------------------------
// 5. drawing
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
    if (n >= 10'd100)      // 3 digits
        hit = digitAt(x, y, X, Y, h) || digitAt(x, y, X + STEP, Y, t) || digitAt(x, y, X + 2*STEP, Y, o);
    else if (n >= 10'd10)  // 2 digits
        hit = digitAt(x, y, X, Y, t) || digitAt(x, y, X + STEP, Y, o);
    else                   // 1 digit
        hit = digitAt(x, y, X, Y, o);
    return hit;
endfunction

logic [3:0] minDigit, tensDigit, onesDigit;
logic [6:0] secPart;
assign minDigit  = (secondsLeft >= 7'd60) ? 4'd1 : 4'd0;
assign secPart   = (secondsLeft >= 7'd60) ? (secondsLeft - 7'd60) : secondsLeft;
assign tensDigit = 4'(secPart / 7'd10);
assign onesDigit = 4'(secPart % 7'd10);

int x, y;
logic onClock, onColon, onDollars, onTarget;
assign x = int'(pixelX);
assign y = int'(pixelY);

// clock layout:  M : S S
assign onClock   = digitAt(x, y, CLOCK_X, CLOCK_Y, minDigit)
                || digitAt(x, y, CLOCK_X + CHAR_W + 16, CLOCK_Y, tensDigit)
                || digitAt(x, y, CLOCK_X + CHAR_W + 16 + STEP, CLOCK_Y, onesDigit);
assign onColon   = (x >= CLOCK_X + CHAR_W + 6) && (x < CLOCK_X + CHAR_W + 10)
                && (((y >= CLOCK_Y + 4)  && (y < CLOCK_Y + 12))      // upper dot (font rows 1-2)
                 || ((y >= CLOCK_Y + 16) && (y < CLOCK_Y + 24)));    // lower dot (font rows 4-5)
assign onDollars = numberAt(x, y, DOLLAR_X, DOLLAR_Y, dollars);
assign onTarget  = numberAt(x, y, TARGET_X, TARGET_Y, 10'(TARGET));

always_ff @(posedge clk or negedge resetN)
begin
    if (!resetN)
        RGBout <= TRANSPARENT_ENCODING;
    else
        RGBout <= (onClock || onColon || onDollars || onTarget) ? TEXT_COLOR : TRANSPARENT_ENCODING;
end

assign drawingRequest = (RGBout != TRANSPARENT_ENCODING);

endmodule
