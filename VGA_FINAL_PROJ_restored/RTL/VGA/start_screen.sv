// start_screen - opening screen of Gold Miner
// (c) Technion IIT, Department of Electrical Engineering 2026
//
//  After reset (KEY0) the game waits on the opening screen:
//  a plain screen with "PRESS ENTER TO START" in the middle.
//  Pressing ENTER on the keypad starts the game.
//
//  1. Screen : while waiting, RGBOut is SCREEN_COLOR with the text drawn on it, and the game
//              picture coming from objects_mux is not shown. When playing, RGBOut = gameRGB.
//  2. Text   : a 5x7 font drawn 4x bigger (20x28 per letter, one letter every 24 pixels),
//              the same way game_hud draws its digits.
//  3. Reset  : gameResetN holds the game blocks (miner, objects, HUD clock, game controller)
//              in reset while the opening screen is shown, so nothing moves and the clock
//              does not count. It is released on the clock after ENTER is pressed.
//  4. Random : the LFSR inside ObjectsMatrixBitMap has no reset and keeps running the whole
//              time. Its layout is built on the first clock after gameResetN is released,
//              which is the moment the player pressed ENTER - so even the first game after
//              programming the board gets a random layout.

module start_screen (
    input  logic        clk,          // 31.5 MHz
    input  logic        resetN,       // global reset (KEY0 / PLL locked)
    input  logic        enterKey,     // keypad ENTER, high while the key is held
    input  logic  [7:0] gameRGB,      // the game picture, from objects_mux
    input  logic [10:0] pixelX,       // current VGA pixel
    input  logic [10:0] pixelY,
    output logic  [7:0] RGBOut,       // to VGA_Controller
    output logic        gameResetN    // reset for the game blocks (low on the opening screen)
);

parameter logic [7:0] SCREEN_COLOR = 8'h00;   // opening screen color (RRRGGGBB), black
parameter logic [7:0] TEXT_COLOR   = 8'hFC;   // text color, gold yellow

//----------------------------------------------------------------------------
// state: opening screen -> playing
//----------------------------------------------------------------------------
enum logic {OPENING_ST, PLAYING_ST} state;

logic enterKey_d;     // previous value of enterKey, to find the moment it is pressed

always_ff @(posedge clk or negedge resetN)
begin
    if (!resetN) begin
        state      <= OPENING_ST;
        enterKey_d <= 1'b1;        // a key held during reset must be released and pressed again
        gameResetN <= 1'b0;
    end
    else begin
        enterKey_d <= enterKey;

        case (state)
            OPENING_ST:
                if (enterKey && !enterKey_d)       // rising edge = ENTER was just pressed
                    state <= PLAYING_ST;
            PLAYING_ST: ;                          // stay here until the next reset
        endcase

        gameResetN <= (state == PLAYING_ST);       // game runs one clock after ENTER
    end
end

//----------------------------------------------------------------------------
// "PRESS ENTER TO START"
//----------------------------------------------------------------------------
localparam int SCALE   = 4;                 // every font pixel is drawn 4x4
localparam int CHAR_W  = 5 * SCALE;         // 20
localparam int CHAR_H  = 7 * SCALE;         // 28
localparam int STEP    = 24;                // one letter every 24 pixels (4 pixels gap)
localparam int MSG_LEN = 20;
localparam int TEXT_W  = (MSG_LEN - 1) * STEP + CHAR_W;   // 476
localparam int TEXT_X  = (640 - TEXT_W) / 2;               // 82  - centered
localparam int TEXT_Y  = (480 - CHAR_H) / 2;               // 226 - centered

// 5x7 font, 7 rows per letter, bit 4 = leftmost column
// letter codes: P=0 R=1 E=2 S=3 N=4 T=5 O=6 A=7
localparam logic [0:7][0:6][4:0] LETTERS = {
	// P
	5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10000, 5'b10000, 5'b10000,
	// R
	5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10100, 5'b10010, 5'b10001,
	// E
	5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b10000, 5'b10000, 5'b11111,
	// S
	5'b01111, 5'b10000, 5'b10000, 5'b01110, 5'b00001, 5'b00001, 5'b11110,
	// N
	5'b10001, 5'b11001, 5'b10101, 5'b10011, 5'b10001, 5'b10001, 5'b10001,
	// T
	5'b11111, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b00100,
	// O
	5'b01110, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01110,
	// A
	5'b01110, 5'b10001, 5'b10001, 5'b11111, 5'b10001, 5'b10001, 5'b10001
};

localparam logic [3:0] SP = 4'd8;   // space
// P R E S S _ E N T E R _ T O _ S T A R T
localparam logic [0:MSG_LEN-1][3:0] MESSAGE = {
	4'd0, 4'd1, 4'd2, 4'd3, 4'd3, SP,
	4'd2, 4'd4, 4'd5, 4'd2, 4'd1, SP,
	4'd5, 4'd6, SP,
	4'd3, 4'd5, 4'd7, 4'd1, 4'd5 };

logic        inText;              // pixel is inside the text line
logic [10:0] relX, relY;          // pixel position inside the text line
logic  [4:0] charIdx;             // which letter of the message (0..19)
logic [10:0] colInChar;           // pixel column inside that letter's 24-pixel slot
logic  [3:0] code;                // letter code of that letter
logic  [2:0] fontCol, fontRow;    // font pixel (0..4, 0..6)
logic        textPixel;           // 1 = draw this pixel in TEXT_COLOR

assign inText    = (pixelX >= TEXT_X) && (pixelX < TEXT_X + TEXT_W) &&
                   (pixelY >= TEXT_Y) && (pixelY < TEXT_Y + CHAR_H);
assign relX      = pixelX - 11'(TEXT_X);
assign relY      = pixelY - 11'(TEXT_Y);
assign charIdx   = 5'(relX / STEP);
assign colInChar = relX - 11'(charIdx * STEP);
assign code      = MESSAGE[charIdx];
assign fontCol   = 3'(colInChar / SCALE);
assign fontRow   = 3'(relY / SCALE);

always_ff @(posedge clk or negedge resetN)
begin
    if (!resetN)
        textPixel <= 1'b0;
    else
        textPixel <= inText && (colInChar < CHAR_W) && (code != SP)
                     && LETTERS[code[2:0]][fontRow][3'd4 - fontCol];
end

//----------------------------------------------------------------------------
// output: the opening screen, or the game
//----------------------------------------------------------------------------
assign RGBOut = (state == PLAYING_ST) ? gameRGB :
                (textPixel            ? TEXT_COLOR : SCREEN_COLOR);

endmodule
