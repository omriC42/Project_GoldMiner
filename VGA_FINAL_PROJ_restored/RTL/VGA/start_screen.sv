// start_screen - draws the opening screen and the settings screen of Gold Miner
// (c) Technion IIT, Department of Electrical Engineering 2026

module start_screen (
    input  logic        clk,          // 31.5 MHz
    input  logic        resetN,       // global reset (KEY0 / PLL locked)
    input  logic  [1:0] screen,       // game_settings: 0 OPENING, 1 SETTINGS, 2 PLAYING
    input  logic  [1:0] cursor,       // game_settings: selected row (0..3)
    input  logic  [1:0] difficulty,   // game_settings: the chosen values (for the frames)
    input  logic  [1:0] timeSel,
    input  logic        soundOn,
    input  logic        cheatsOn,
    input  logic  [7:0] gameRGB,      // the game picture, from objects_mux
    input  logic [10:0] pixelX,       // current VGA pixel
    input  logic [10:0] pixelY,
    output logic  [7:0] RGBOut        // to VGA_Controller
);

// the picture files: Quartus reads them relative to the project folder; the testbench passes
// its own paths ("../RTL/VGA/...", because ModelSim runs inside tests/)
parameter IMAGE_FILE    = "RTL/VGA/start_screen.hex";
parameter SETTINGS_FILE = "RTL/VGA/settings_screen.hex";

// where the rows / value words are on the screen (written by make_menu_pictures.py)
`include "settings_layout.svh"

localparam logic [1:0] S_SETTINGS = 2'd1;
localparam logic [1:0] S_PLAYING  = 2'd2;
localparam logic [7:0] ARROW_COLOR = 8'hFC;   // yellow
localparam logic [7:0] FRAME_COLOR = 8'h1C;   // green
localparam int ARROW_W = 16;                  // arrow size (the text is SET_TEXT_H = 28 high)
localparam int PAD     = 6;                   // frame distance from the word
localparam int THICK   = 2;                   // frame thickness

//----------------------------------------------------------------------------
// the pictures: ROMs in FPGA memory blocks, one byte (RRRGGGBB) per stored pixel
//----------------------------------------------------------------------------
logic [7:0] image    [0:320*240-1];           // opening screen, 320x240
logic [7:0] setImage [0:160*120-1];           // settings screen, 160x120
initial $readmemh(IMAGE_FILE, image);
initial $readmemh(SETTINGS_FILE, setImage);

// addresses: opening (y/2)*320 + x/2, settings (y/4)*160 + x/4 -> 320 = 256 + 64, 160 = 128 + 32,
// so only shifts and adders. Outside the visible 640x480 area the address is 0.
logic        visible;
logic  [8:0] imgX;   logic [7:0] imgY;        // 0..319, 0..239
logic  [7:0] setX;   logic [6:0] setY;        // 0..159, 0..119
logic [16:0] imgAddr;
logic [14:0] setAddr;
assign visible = (pixelX < 11'd640) && (pixelY < 11'd480);
assign imgX    = pixelX[9:1];
assign imgY    = pixelY[8:1];
assign setX    = pixelX[9:2];
assign setY    = pixelY[8:2];
assign imgAddr = visible ? ({1'b0, imgY, 8'b0} + {3'b0, imgY, 6'b0} + {8'b0, imgX}) : 17'd0;
assign setAddr = visible ? ({1'b0, setY, 7'b0} + {3'b0, setY, 5'b0} + {7'b0, setX}) : 15'd0;

// registered reads (1 clock). No reset on purpose: a plain registered read lets Quartus put the
// pictures in memory blocks instead of logic.
logic [7:0] imagePixel, setPixel;
always_ff @(posedge clk) begin
    imagePixel <= image[imgAddr];
    setPixel   <= setImage[setAddr];
end

//----------------------------------------------------------------------------
// settings screen: the arrow and the frames (on the current pixel)
//----------------------------------------------------------------------------
int x, y;
assign x = int'(pixelX);
assign y = int'(pixelY);

// the chosen value (0, 1, 2) of every row, in the order of the rows
logic [1:0] chosen [0:SET_ROWS-1];
assign chosen[0] = difficulty;                // DIFFICULTY: EASY NORMAL HARD
assign chosen[1] = timeSel;                   // TIME: 30 S, 60 S, 90 S
assign chosen[2] = soundOn  ? 2'd0 : 2'd1;    // SOUND: ON OFF
assign chosen[3] = cheatsOn ? 2'd0 : 2'd1;    // CHEATS: ON OFF

logic onFrame, onArrow;
int   fx0, fx1, fy0, fy1;                     // the frame of one row (loop variables)
int   ay, relX, relY, halfW;
always_comb begin
    // frames: a hollow rectangle around the chosen word of each row
    onFrame = 1'b0;
    for (int r = 0; r < SET_ROWS; r++) begin
        fx0 = SET_VAL_X0[r][chosen[r]] - PAD;
        fx1 = SET_VAL_X1[r][chosen[r]] + PAD - 1;
        fy0 = SET_ROW_Y[r] - PAD;
        fy1 = SET_ROW_Y[r] + SET_TEXT_H + PAD - 1;
        if ((x >= fx0) && (x <= fx1) && (y >= fy0) && (y <= fy1) &&
            ((x < fx0 + THICK) || (x > fx1 - THICK) || (y < fy0 + THICK) || (y > fy1 - THICK)))
            onFrame = 1'b1;
    end
    // arrow: a triangle pointing right, at the LABEL line of the selected row.
    // Row dy of the triangle (0..27) is min(dy, 27-dy) + 2 pixels wide (at most ARROW_W).
    ay    = SET_ROW_Y[cursor] - SET_LABEL_DY;
    relX  = x - SET_ARROW_X;
    relY  = y - ay;
    halfW = ((relY < SET_TEXT_H / 2) ? relY : (SET_TEXT_H - 1 - relY)) + 2;
    onArrow = (relX >= 0) && (relX < ARROW_W) && (relY >= 0) && (relY < SET_TEXT_H) && (relX < halfW);
end

// registered with the picture read, so both describe the same pixel
logic       overlayOn;
logic [7:0] overlayRGB;
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        overlayOn  <= 1'b0;
        overlayRGB <= 8'h00;
    end
    else begin
        overlayOn  <= onArrow || onFrame;
        overlayRGB <= onArrow ? ARROW_COLOR : FRAME_COLOR;
    end
end

//----------------------------------------------------------------------------
// output: the game, the settings screen, or the opening screen
//----------------------------------------------------------------------------
assign RGBOut = (screen == S_PLAYING)  ? gameRGB :
                (screen == S_SETTINGS) ? (overlayOn ? overlayRGB : setPixel) :
                                         imagePixel;

endmodule
