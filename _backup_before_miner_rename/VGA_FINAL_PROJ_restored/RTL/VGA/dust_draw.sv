// dust_draw - dust puffs behind the mine cart while it is driving
// (c) Technion IIT, Department of Electrical Engineering 2026
//
// How it works:
//  1. Direction: once per frame (startOfFrame) the cart's X is compared with the X of the
//     previous frame. X went down -> driving LEFT  -> dust on the RIGHT side of the cart.
//                           X went up   -> driving RIGHT -> dust on the LEFT  side of the cart.
//     The cart moves less than 1 pixel per frame, so X does not change every frame.
//     holdCnt keeps the dust alive for HOLD_FRAMES frames after the last change, and the
//     dust fades out (checkerboard) during the last FADE_FRAMES frames.
//  2. Drawing: 3 round puffs start at the bottom of the trailing wheel. Every puff has its
//     own phase (0..15) that moves it outward, up, and makes it bigger. The phases are spread
//     out (0, 5, 10) so there is always a small, a medium and a big puff.
//  3. Output: like every other object - RGBout is transparent (8'hFF) outside the dust and
//     drawingRequest = (RGBout != transparent). It goes to objects_mux under the miner, and it
//     is NOT connected to the collision logic.

module dust_draw (
    input  logic               clk,
    input  logic               resetN,
    input  logic               startOfFrame,
    input  logic        [10:0] pixelX,      // current VGA pixel
    input  logic        [10:0] pixelY,
    input  logic signed [10:0] minerX,      // miner top-left (from smiley_move)
    input  logic signed [10:0] minerY,
    output logic               drawingRequest,
    output logic         [7:0] RGBout
);

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF;
localparam logic [7:0] DUST_LIGHT = 8'hFA;  // 111 110 10  cream
localparam logic [7:0] DUST_DARK  = 8'hD6;  // 110 101 10  tan (rim of each puff)

localparam int HOLD_FRAMES = 12;  // frames the dust stays after the last movement
localparam int FADE_FRAMES = 4;   // last frames are drawn half-transparent
localparam int NUM_PUFFS   = 3;
localparam int PUFF_SPACING = 5;  // phase difference between puffs

// where the dust starts, relative to the miner's top-left corner (64x64 sprite)
localparam int RIGHT_WHEEL_X = 55;  // outer edge of the right wheel
localparam int LEFT_WHEEL_X  = 8;   // outer edge of the left wheel
localparam int WHEEL_BOTTOM_Y = 61; // just above the rail

typedef enum logic [1:0] {DIR_NONE, DIR_LEFT, DIR_RIGHT} dir_t;

dir_t               dir;
logic signed [10:0] prevX;
logic               prevValid;  // first frame after reset only samples X
logic         [4:0] holdCnt;
logic         [4:0] anim;       // frame counter, anim[4:1] = phase step every 2 frames

//----------------------------------------------------------------------------
// 1. direction + timers, updated once per frame
//----------------------------------------------------------------------------
always_ff @(posedge clk or negedge resetN)
begin
    if (!resetN) begin
        dir       <= DIR_NONE;
        prevX     <= 11'sd0;
        prevValid <= 1'b0;
        holdCnt   <= 5'd0;
        anim      <= 5'd0;
    end
    else if (startOfFrame) begin
        prevX     <= minerX;
        prevValid <= 1'b1;
        anim      <= anim + 5'd1;

        if (prevValid && (minerX < prevX)) begin
            dir     <= DIR_LEFT;
            holdCnt <= 5'(HOLD_FRAMES);
        end
        else if (prevValid && (minerX > prevX)) begin
            dir     <= DIR_RIGHT;
            holdCnt <= 5'(HOLD_FRAMES);
        end
        else if (holdCnt != 5'd0)
            holdCnt <= holdCnt - 5'd1;
    end
end

//----------------------------------------------------------------------------
// 2. is the current pixel inside one of the puffs?
//----------------------------------------------------------------------------
logic insidePuff;  // pixel is inside a puff
logic onRim;       // pixel is on the outer ring of a puff

always_comb
begin
    insidePuff = 1'b0;
    onRim      = 1'b0;

    for (int i = 0; i < NUM_PUFFS; i++) begin : puffs
        automatic logic [3:0] phase = anim[4:1] + 4'(i * PUFF_SPACING); // wraps 15 -> 0
        automatic int p     = int'(phase);
        automatic int out   = 2 + p;          // how far out from the wheel
        automatic int rise  = p >> 1;         // how high it floated
        automatic int r     = 2 + (p >> 2);   // radius 2..5
        automatic int cx    = (dir == DIR_LEFT) ? int'(minerX) + RIGHT_WHEEL_X + out
                                                : int'(minerX) + LEFT_WHEEL_X  - out;
        automatic int cy    = int'(minerY) + WHEEL_BOTTOM_Y - rise;
        automatic int dx    = int'(pixelX) - cx;
        automatic int dy    = int'(pixelY) - cy;
        automatic int adx   = (dx < 0) ? -dx : dx;
        automatic int ady   = (dy < 0) ? -dy : dy;
        // only used when |dx|,|dy| <= r <= 5, so 3 bits are enough -> tiny multipliers
        automatic logic [2:0] ax = adx[2:0];
        automatic logic [2:0] ay = ady[2:0];
        automatic logic [2:0] r3 = r[2:0];
        automatic logic [5:0] d2   = (ax * ax) + (ay * ay);   // distance^2 from puff center
        automatic logic [5:0] r2   = r3 * r3;                 // radius^2
        automatic logic [5:0] rIn2 = (r3 - 3'd1) * (r3 - 3'd1); // (radius-1)^2

        if ((adx <= r) && (ady <= r) && (d2 <= r2)) begin
            insidePuff = 1'b1;
            if (d2 > rIn2)
                onRim = 1'b1;
        end
    end
end

//----------------------------------------------------------------------------
// 3. registered color output (same style as the other objects)
//----------------------------------------------------------------------------
logic fading;
assign fading = (holdCnt <= 5'(FADE_FRAMES));

always_ff @(posedge clk or negedge resetN)
begin
    if (!resetN)
        RGBout <= TRANSPARENT_ENCODING;
    else begin
        RGBout <= TRANSPARENT_ENCODING;  // default
        if ((dir != DIR_NONE) && (holdCnt != 5'd0) && insidePuff) begin
            // while fading, draw only every other pixel (checkerboard)
            if (!fading || (pixelX[0] ^ pixelY[0]))
                RGBout <= onRim ? DUST_DARK : DUST_LIGHT;
        end
    end
end

assign drawingRequest = (RGBout != TRANSPARENT_ENCODING);

endmodule
