// start_screen - opening screen of Gold Miner
// (c) Technion IIT, Department of Electrical Engineering 2026
//
//  After reset (KEY0) the game waits on the opening screen - a PICTURE - until ENTER is pressed.
//
//  1. Screen : while waiting, RGBOut shows the picture start_screen.hex and the game picture
//              coming from objects_mux is not shown. When playing, RGBOut = gameRGB.
//  2. Picture: stored at 320x240 (8-bit RRRGGGBB, 76,800 bytes in FPGA memory blocks) and drawn
//              2x2 -> full 640x480 screen. To change it: RTL/VGA/make_start_screen_hex.py
//              (picture -> start_screen.hex), recompile. No logic changes needed.
//              Oct 2026: replaces the old drawn text (font tables + dividers); the current picture
//              (start_screen.png) is exactly what the old version drew: "PRESS ENTER TO START".
//  3. Reset  : gameResetN holds the game blocks (miner, objects, HUD clock, game controller, hook)
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

// the picture file: Quartus reads it relative to the project folder; the testbench passes
// its own path ("../RTL/VGA/start_screen.hex", because ModelSim runs inside tests/)
parameter IMAGE_FILE = "RTL/VGA/start_screen.hex";

localparam int IMG_W = 320;           // stored picture size (drawn 2x2)
localparam int IMG_H = 240;

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
// the picture: a ROM in FPGA memory blocks, one byte per stored pixel
//----------------------------------------------------------------------------
logic [7:0] image [0:IMG_W*IMG_H-1];
initial $readmemh(IMAGE_FILE, image);

// address = (y/2)*320 + x/2. 320 = 256 + 64, so only shifts and adders (no multiplier/divider).
// Outside the visible 640x480 area the address is 0 (the VGA controller blanks those pixels).
logic        visible;
logic  [8:0] imgX;            // 0..319
logic  [7:0] imgY;            // 0..239
logic [16:0] imgAddr;         // 0..76,799
assign visible = (pixelX < 11'd640) && (pixelY < 11'd480);
assign imgX    = pixelX[9:1];
assign imgY    = pixelY[8:1];
assign imgAddr = visible ? ({1'b0, imgY, 8'b0} + {3'b0, imgY, 6'b0} + {8'b0, imgX}) : 17'd0;

// registered read (1 clock, like every bitmap in the game). No reset on purpose:
// a plain registered read lets Quartus put the picture in memory blocks instead of logic.
logic [7:0] imagePixel;
always_ff @(posedge clk)
    imagePixel <= image[imgAddr];

//----------------------------------------------------------------------------
// output: the opening picture, or the game
//----------------------------------------------------------------------------
assign RGBOut = (state == PLAYING_ST) ? gameRGB : imagePixel;

endmodule
