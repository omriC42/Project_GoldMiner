// carried_draw - draws the caught gold/rock hanging on the claw while the hook pulls it back.
// Gold Miner project, Oct 2026. Lives inside hook_block (its pixels go out on hookDR / hookRGB).
//
//  * The pictures are the SAME 6 sprites as the objects field (object_sprites.svh, shared with
//    ObjectsMatrixBitMap) - small 16x16, medium 32x32, large 64x64, 8'hFF = transparent.
//  * Position (Oct 25 2026 fix - the object is now IN the claw at every rope angle):
//    the claw sprite (hook_draw) never rotates - its prongs always open DOWN - so the object hangs
//    straight down under the claw, centred on the tip in X:
//        left = Xend - size/2
//        top  = Yend + CARRY_OFFSET_PX - topPad
//    topPad = the transparent rows at the top of each picture (object_sprites.svh), so the FIRST
//    VISIBLE row of the object is CARRY_OFFSET_PX (4) px below the tip = under the claw's bottom bar
//    (claw rows Yend+4..+5, drawn on top) -> the claw grips the object with no gap.
//    (Before: the centre was pushed along the rope, so at 15/165 deg the object sat BESIDE the claw,
//     and the transparent rows left a gap of up to 7 px under it.)
//    dirCos / dirSin are no longer used; the ports stay so hook_block and the .bsf do not change.
//  * show = 1 only while something is on the hook AND the hook is pulling back (hook_block).
//  * Timing: the centre is registered once per clock (it only changes at startOfFrame), then the
//    pixel test + sprite read are registered -> 1 clock latency, the same as hook_draw.
//  * It never catches anything: it is not part of tipDR.

module carried_draw (
    input  logic               clk,
    input  logic               resetN,
    input  logic        [10:0] pixelX,      // current VGA pixel
    input  logic        [10:0] pixelY,
    input  logic signed [10:0] Xend,        // claw tip (hook_move)
    input  logic signed [10:0] Yend,
    input  logic signed  [9:0] dirCos,      // 256*cos / 256*sin of the rope angle (hook_move)
    input  logic signed  [9:0] dirSin,
    input  logic               show,        // something is on the hook and it is being pulled back
    input  logic         [2:0] objType,     // what is on the hook: 1..3 gold S/M/L, 4..6 rock S/M/L
    output logic               drawingRequest,
    output logic         [7:0] RGBout
);
import hook_params::*;
import game_params::*;

localparam logic [7:0] TRANSPARENT_ENCODING = 8'hFF;

// the 6 colour tables (gold_small_colors ... rock_large_colors), shared with ObjectsMatrixBitMap
`include "object_sprites.svh"

// ---------------- size of the sprite on the hook + its empty rows at the top ----------------
// topPad = first non-transparent row of each picture in object_sprites.svh.
// If a picture is changed, update its number here (tb_carried_draw finds it by itself and will FAIL
// if this table is wrong).
object_t     obj;
logic [6:0]  size;          // 16 / 32 / 64
logic [5:0]  half;          //  8 / 16 / 32
logic [3:0]  topPad;        // transparent rows above the picture
assign obj = object_t'(objType);
always_comb begin
    case (obj)
        GOLD_SMALL:  begin size = 7'd16; half = 6'd8;  topPad = 4'd1; end
        GOLD_MEDIUM: begin size = 7'd32; half = 6'd16; topPad = 4'd3; end
        GOLD_LARGE:  begin size = 7'd64; half = 6'd32; topPad = 4'd3; end
        ROCK_SMALL:  begin size = 7'd16; half = 6'd8;  topPad = 4'd2; end
        ROCK_MEDIUM: begin size = 7'd32; half = 6'd16; topPad = 4'd4; end
        ROCK_LARGE:  begin size = 7'd64; half = 6'd32; topPad = 4'd7; end
        default:     begin size = 7'd0;  half = 6'd0;  topPad = 4'd0; end
    endcase
end

// ---------------- top-left corner of the sprite, registered ----------------

logic signed [11:0] boxX, boxY;       // sprite top-left on the screen
logic        [6:0]  boxSize;
logic               boxOn;
object_t            boxObj;           // the object type, registered together with the box
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        boxX    <= 12'sd0;
        boxY    <= 12'sd0;
        boxSize <= 7'd0;
        boxOn   <= 1'b0;
        boxObj  <= OBJ_NONE;
    end
    else begin
        boxX    <= 12'(Xend) - 12'(half);                                // centred under the tip
        boxY    <= 12'(Yend) + 12'(CARRY_OFFSET_PX) - 12'(topPad);      // top visible row in the claw
        boxSize <= size;
        boxOn   <= show && (size != 7'd0);
        boxObj  <= obj;
    end
end

// ---------------- is the current pixel inside the sprite? which sprite pixel? ----------------
logic signed [12:0] sx, sy;           // pixel position inside the sprite box
logic               inBox;
assign sx    = $signed({2'b0, pixelX}) - 13'(boxX);
assign sy    = $signed({2'b0, pixelY}) - 13'(boxY);
assign inBox = boxOn && (sx >= 0) && (sy >= 0) && (sx < $signed({6'b0, boxSize})) && (sy < $signed({6'b0, boxSize}));

// ---------------- read the sprite (registered, like every bitmap in the game) ----------------
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN)
        RGBout <= TRANSPARENT_ENCODING;
    else begin
        RGBout <= TRANSPARENT_ENCODING;                      // default: nothing to draw
        if (inBox) begin
            case (boxObj)
                GOLD_SMALL:  RGBout <= gold_small_colors [sy[3:0]][sx[3:0]];
                GOLD_MEDIUM: RGBout <= gold_medium_colors[sy[4:0]][sx[4:0]];
                GOLD_LARGE:  RGBout <= gold_large_colors [sy[5:0]][sx[5:0]];
                ROCK_SMALL:  RGBout <= rock_small_colors [sy[3:0]][sx[3:0]];
                ROCK_MEDIUM: RGBout <= rock_medium_colors[sy[4:0]][sx[4:0]];
                ROCK_LARGE:  RGBout <= rock_large_colors [sy[5:0]][sx[5:0]];
                default:     RGBout <= TRANSPARENT_ENCODING;
            endcase
        end
    end
end

assign drawingRequest = (RGBout != TRANSPARENT_ENCODING);

endmodule
