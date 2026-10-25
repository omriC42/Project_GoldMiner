// hook_draw - draws the hook rope (origin -> tip) and a claw sprite at the tip.
// Gold Miner project.
//
// Oct 2026 cleanup (Step 2 of hook integration):
//  * merge-conflict leftovers removed
//  * port names match hook_move (X0,Y0,Xend,Yend,R)
//  * rope test works at every angle, including horizontal 0/180 deg
//    (old version only drew when the tip was BELOW the origin)
//  * NEW claw sprite (16x16) centred on the tip, with its own output tipDR.
//    Only tipDR is used for catching gold/rocks - the rope itself never catches.
//  * rope width and colors come from hook_params.sv
//
// How the rope test works (no division, no square root):
//   For a pixel P and the rope from O=(X0,Y0) to T=(Xend,Yend):
//     crossProd = (Py-Y0)*(Xend-X0) - (Px-X0)*(Yend-Y0)
//   |crossProd| = (distance of P from the rope line) * (rope length R).
//   So "distance <= w" is the same as "|crossProd| <= w*R"  -> one compare.
//   A bounding box (O..T, +1 px) stops the line from continuing past its ends.
//
// Output timing: 1 clock latency (registered), like the other drawing modules.

module hook_draw (
    input  logic               clk,
    input  logic               resetN,
    input  logic        [10:0] pixelX,   // current VGA pixel
    input  logic        [10:0] pixelY,
    input  logic signed [10:0] X0,       // rope origin
    input  logic signed [10:0] Y0,
    input  logic signed [10:0] Xend,     // hook tip (from hook_move)
    input  logic signed [10:0] Yend,
    input  logic        [10:0] R,        // rope length in px (from hook_move)

    output logic               drawingRequest, // rope OR claw pixel
    output logic        [7:0]  RGBout,
    output logic               tipDR           // claw pixel only (for collisions)
);

import hook_params::*;

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF;

// ---------------- claw sprite 16x16, 1 = claw pixel ----------------
// centred on the tip: covers x = Xend-7 .. Xend+8, y = Yend-7 .. Yend+8
localparam int CLAW_SIZE = 16;
localparam int CLAW_HALF = 7;
localparam logic [15:0] CLAW_BITMAP [0:15] = '{
    16'b0000000000000000,
    16'b0000001111000000,   //   ring where the rope is tied
    16'b0000010000100000,
    16'b0000010000100000,
    16'b0000001111000000,
    16'b0000000110000000,   //   shaft
    16'b0000000110000000,
    16'b0010000110000100,   //   prongs start
    16'b0010000110000100,
    16'b0011000110001100,
    16'b0001100110011000,
    16'b0000111111110000,
    16'b0000011111100000,
    16'b0000000000000000,
    16'b0000000000000000,
    16'b0000000000000000
};

// ---------------- signed working copies ----------------
logic signed [11:0] px, py;
assign px = $signed({1'b0, pixelX});
assign py = $signed({1'b0, pixelY});

// ---------------- rope ----------------
logic signed [11:0] dxp, dyp, Lx, Ly;      // pixel-origin and tip-origin vectors
logic signed [23:0] prod1, prod2;
logic signed [24:0] crossProd;
logic        [24:0] absCross;
logic        [24:0] limit;
logic signed [11:0] xmin, xmax, ymin, ymax;
logic               inBox, nearLine, ropePixel;

assign dxp   = px - X0;
assign dyp   = py - Y0;
assign Lx    = Xend - X0;
assign Ly    = Yend - Y0;
assign prod1 = dyp * Lx;
assign prod2 = dxp * Ly;
assign crossProd = prod1 - prod2;
assign absCross = crossProd[24] ? 25'(-crossProd) : 25'(crossProd);
assign limit    = 25'((R * ROPE_HALF_WIDTH_X4) >> 2);     // w * R, w in px

assign xmin  = ((X0 < Xend) ? X0 : Xend) - 12'sd1;
assign xmax  = ((X0 < Xend) ? Xend : X0) + 12'sd1;
assign ymin  = ((Y0 < Yend) ? Y0 : Yend) - 12'sd1;
assign ymax  = ((Y0 < Yend) ? Yend : Y0) + 12'sd1;
assign inBox = (px >= xmin) && (px <= xmax) && (py >= ymin) && (py <= ymax);

assign nearLine  = (absCross <= limit);
assign ropePixel = inBox && nearLine;

// ---------------- claw ----------------
logic signed [11:0] cx, cy;                // pixel offset inside the claw box
logic               inClawBox, clawPixel;
assign cx = px - (Xend - 12'sd7);
assign cy = py - (Yend - 12'sd7);
assign inClawBox = (cx >= 0) && (cx < CLAW_SIZE) && (cy >= 0) && (cy < CLAW_SIZE);
assign clawPixel = inClawBox && CLAW_BITMAP[cy[3:0]][15 - cx[3:0]];

// ---------------- registered outputs ----------------
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        drawingRequest <= 1'b0;
        tipDR          <= 1'b0;
        RGBout         <= TRANSPARENT_ENCODING;
    end
    else begin
        tipDR          <= clawPixel;
        drawingRequest <= clawPixel || ropePixel;
        if (clawPixel)       RGBout <= CLAW_COLOR;   // claw is drawn over the rope
        else if (ropePixel)  RGBout <= ROPE_COLOR;
        else                 RGBout <= TRANSPARENT_ENCODING;
    end
end

endmodule
