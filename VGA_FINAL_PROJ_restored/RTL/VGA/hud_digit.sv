// hud_digit - one digit place of the HUD (Step 12, Oct 2026): is the current pixel on the digit?
// Replaces the old digitAt() function of game_hud (no functions in the RTL).
//
//  * The digit is drawn with a 5x7 font, every font pixel 4x4 screen pixels -> 20x28 pixels.
//  * (X, Y) = top-left corner of the digit place on the screen (parameters, fixed per instance).
//  * show = 0 -> nothing (used for leading zeros: "7" instead of "007").
//  * Combinational, like the old function: game_hud registers the final colour.

module hud_digit #(
    parameter int X = 0,      // top-left corner of this digit place
    parameter int Y = 0
) (
    input  logic [10:0] pixelX,
    input  logic [10:0] pixelY,
    input  logic  [3:0] digit,    // 0..9
    input  logic        show,     // 1 = draw this place
    output logic        hit       // 1 = the pixel is on the digit
);

localparam int CHAR_W = 20, CHAR_H = 28;     // 5x7 font drawn 4x bigger

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

int relX, relY;                               // pixel position inside the 20x28 place
logic inPlace;
assign relX   = int'(pixelX) - X;
assign relY   = int'(pixelY) - Y;
assign inPlace = show && (digit <= 4'd9) && (relX >= 0) && (relX < CHAR_W) && (relY >= 0) && (relY < CHAR_H);
assign hit    = inPlace ? FONT[digit][relY >> 2][4 - (relX >> 2)] : 1'b0;   // /4 = >> 2 (font pixel)

endmodule
