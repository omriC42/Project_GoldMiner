// carried_draw - draws the caught gold/rock hanging on the claw while the hook pulls it back.
// Gold Miner project, Oct 2026. Lives inside hook_block (its pixels go out on hookDR / hookRGB).
//
//  * The pictures are the SAME 6 sprites as the objects field (object_sprites.svh, shared with
//    ObjectsMatrixBitMap) - small 16x16, medium 32x32, large 64x64, 8'hFF = transparent.
//  * Position: along the rope. The sprite centre is  tip + D * (cos, sin)  of the rope angle,
//    with D = CARRY_OFFSET_PX + half the sprite size (hook_params.sv):
//        small D = 4+8 = 12 px, medium 4+16 = 20 px, large 4+32 = 36 px.
//    The sprite itself stays upright; only its position follows the rope.
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

// ---------------- size of the sprite on the hook ----------------
localparam int D_SMALL  = CARRY_OFFSET_PX + 8;    // tip -> centre distance along the rope
localparam int D_MEDIUM = CARRY_OFFSET_PX + 16;
localparam int D_LARGE  = CARRY_OFFSET_PX + 32;

object_t     obj;
logic [6:0]  size;          // 16 / 32 / 64
logic [5:0]  half;          //  8 / 16 / 32
logic [6:0]  carryDist;          // D_SMALL / D_MEDIUM / D_LARGE
assign obj = object_t'(objType);
always_comb begin
    case (obj)
        GOLD_SMALL,  ROCK_SMALL:  begin size = 7'd16; half = 6'd8;  carryDist = 7'(D_SMALL);  end
        GOLD_MEDIUM, ROCK_MEDIUM: begin size = 7'd32; half = 6'd16; carryDist = 7'(D_MEDIUM); end
        GOLD_LARGE,  ROCK_LARGE:  begin size = 7'd64; half = 6'd32; carryDist = 7'(D_LARGE);  end
        default:                  begin size = 7'd0;  half = 6'd0;  carryDist = 7'd0;         end
    endcase
end

// ---------------- top-left corner of the sprite, registered ----------------
// centre = tip + carryDist * (cos, sin) / 256      (carryDist <= 36, |cos|,|sin| <= 256)
logic signed [17:0] offX_full, offY_full;
assign offX_full = $signed({1'b0, carryDist}) * dirCos;
assign offY_full = $signed({1'b0, carryDist}) * dirSin;

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
        boxX    <= 12'(Xend) + 12'(offX_full >>> 8) - 12'(half);
        boxY    <= 12'(Yend) + 12'(offY_full >>> 8) - 12'(half);
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
