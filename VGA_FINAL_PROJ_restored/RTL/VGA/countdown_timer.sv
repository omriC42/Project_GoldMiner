// countdown_timer - simple red 1:00 -> 0:00 countdown clock
// (c) Technion IIT, Department of Electrical Engineering 2026
//
//  1. Counting: tickCnt counts clock cycles. Every CLOCK_HZ cycles (1 second at 31.5 MHz)
//     secondsLeft goes down by 1. It starts at 60 after reset and stops at 0.
//     timeUp = 1 at 0:00 (can be used later to end the game).
//  2. Digits: secondsLeft is shown as M:SS.
//  3. Drawing: each digit is a 5x7 font (FONT table), every font pixel drawn as a 4x4 block,
//     so a digit is 20x28 screen pixels. Text is red, everything else transparent (8'hFF).

module countdown_timer (
    input  logic        clk,          // 31.5 MHz
    input  logic        resetN,
    input  logic [10:0] pixelX,       // current VGA pixel
    input  logic [10:0] pixelY,
    output logic        drawingRequest,
    output logic  [7:0] RGBout,
    output logic        timeUp        // 1 when the clock shows 0:00
);

parameter int CLOCK_HZ      = 31_500_000; // clock cycles per second
parameter int START_SECONDS = 60;
parameter int POS_X = 530;                // top-left corner of the text
parameter int POS_Y = 52;

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF;
localparam logic [7:0] TEXT_COLOR = 8'hE0;    // red

localparam int CHAR_W  = 20;                  // 5 font pixels * 4
localparam int CHAR_H  = 28;                  // 7 font pixels * 4
localparam int X_MIN   = POS_X;               // layout:  M : S S
localparam int X_COLON = X_MIN + CHAR_W + 6;
localparam int X_TENS  = X_COLON + 10;
localparam int X_ONES  = X_TENS + CHAR_W + 4;

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

// ---------------- 1. one-second tick and countdown ----------------
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

// ---------------- 2. split into M : S S ----------------
logic [3:0] minDigit, tensDigit, onesDigit;
logic [6:0] secPart;

assign minDigit  = (secondsLeft >= 7'd60) ? 4'd1 : 4'd0;
assign secPart   = (secondsLeft >= 7'd60) ? (secondsLeft - 7'd60) : secondsLeft;
assign tensDigit = 4'(secPart / 7'd10);
assign onesDigit = 4'(secPart % 7'd10);

// ---------------- 3. draw ----------------
int x, y, ry, row, col;
logic onText;

assign x   = int'(pixelX);
assign y   = int'(pixelY);
assign ry  = y - POS_Y;
assign row = ry >> 2;          // font row 0..6

always_comb
begin
    onText = 1'b0;
    col    = 0;
    if ((ry >= 0) && (ry < CHAR_H)) begin
        if ((x >= X_MIN) && (x < X_MIN + CHAR_W)) begin
            col    = (x - X_MIN) >> 2;
            onText = FONT[minDigit][row][4 - col];
        end
        else if ((x >= X_TENS) && (x < X_TENS + CHAR_W)) begin
            col    = (x - X_TENS) >> 2;
            onText = FONT[tensDigit][row][4 - col];
        end
        else if ((x >= X_ONES) && (x < X_ONES + CHAR_W)) begin
            col    = (x - X_ONES) >> 2;
            onText = FONT[onesDigit][row][4 - col];
        end
        else if ((x >= X_COLON) && (x < X_COLON + 4))       // colon = two dots
            onText = (row == 1) || (row == 2) || (row == 4) || (row == 5);
    end
end

always_ff @(posedge clk or negedge resetN)
begin
    if (!resetN)
        RGBout <= TRANSPARENT_ENCODING;
    else
        RGBout <= onText ? TEXT_COLOR : TRANSPARENT_ENCODING;
end

assign drawingRequest = (RGBout != TRANSPARENT_ENCODING);

endmodule
