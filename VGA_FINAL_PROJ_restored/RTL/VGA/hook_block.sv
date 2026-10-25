// hook_block - the complete Gold Miner hook: hook_move + hook_draw in one block.
// Replaces Hook_Block_T.bdf (Step 4 of hook integration, Oct 2026).
// Symbol for the top-level schematic: hook_block.bsf
//
// Rules decided with the user:
//  * the rope starts under the miner: X0 = minerX + HOOK_DX, Y0 = minerY + HOOK_DY (hook_params.sv)
//  * NO shooting while the miner moves: a shot needs a FRESH press of key 2 while minerMoving = 0.
//    Holding 2 while moving and then stopping does NOT shoot - press 2 again.
//  * hookBusy = 1 while the hook is out (SHOOT or RETRACT) -> used in Step 5 to lock the miner.
//  * Step 7: CATCHING. hookCatch = claw pixel AND gold/rock pixel, only while SHOOTING.
//    It goes to the gold field (object disappears, score) and back into hook_move (pull back).
//    Pixel alignment: tipDR is 1 clock after its pixel, GoldDrawingRequest is 2 clocks after
//    its pixel (square_object + GoldsMatrixBitMap registers), so tipDR is delayed 1 clock here.
//  * Step 9: WEIGHT. The gold field reports the code of the object it removed (catchType,
//    1..3 gold small/medium/large, 4..6 rock small/medium/large). It is latched one clock after
//    hookCatch (when the gold field has updated it) and chooses the pull-back speed from
//    game_params.sv. Empty hook (border / floor) -> RETRACT_EMPTY from hook_params.sv.
//    The speeds are converted to per-frame steps at compile time (the STEP_* table below).

module hook_block (
    input  logic               clk,
    input  logic               resetN,
    input  logic               startOfFrame,
    input  logic        [10:0] pixelX,
    input  logic        [10:0] pixelY,
    input  logic signed [10:0] minerX,        // miner top-left corner (Smiley_Block_T, Step 5)
    input  logic signed [10:0] minerY,
    input  logic               minerMoving,   // key 4 or key 6 held
    input  logic               shoot_key,     // key 2 (level, straight from the keyboard)
    input  logic               tipCollision,  // extra 'caught' input (tests); GND in the game
    input  logic               goldDR,        // GoldDrawingRequest from Gold_DISPLAY (2 clocks after its pixel)
    input  logic               freeze,        // game over / time up (Step 10)
    input  logic        [2:0]  catchType,     // Gold_DISPLAY.collectType: code of the object just taken

    output logic               hookDR,        // rope or claw pixel   -> objects_mux
    output logic        [7:0]  hookRGB,       //                      -> objects_mux
    output logic               tipDR,         // claw pixel only      -> collision
    output logic               hookBusy,      // hook is out          -> lock the miner
    output logic        [1:0]  hookState,     // 0 SWING, 1 SHOOT, 2 RETRACT
    output logic               hookCatch      // 1-clock pulses: claw on gold/rock while shooting -> Gold_DISPLAY
);

import hook_params::*;
import game_params::*;

// ---------------- rope origin under the miner ----------------
logic signed [10:0] X0, Y0;
assign X0 = minerX + 11'(HOOK_DX);
assign Y0 = minerY + 11'(HOOK_DY);

// ---------------- shoot only on a fresh press while not moving ----------------
logic shoot_key_d;
logic shoot_req;          // one-clock pulse = a valid shot request
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) shoot_key_d <= 1'b0;
    else         shoot_key_d <= shoot_key;
end
assign shoot_req = shoot_key && !shoot_key_d && !minerMoving;

// ---------------- catching (Step 7) ----------------
logic tipDR_d;            // tipDR delayed to line up with goldDR (same pixel)
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        tipDR_d   <= 1'b0;
        hookCatch <= 1'b0;
    end
    else begin
        tipDR_d   <= tipDR;
        hookCatch <= tipDR_d && goldDR && (hookState == 2'd1);   // registered: clean for timing
    end
end

// ---------------- weight (Step 9) ----------------
// Pull-back step per frame (pixels x64) for every object and difficulty.
// All numbers come from game_params.sv; Quartus works them out at compile time:
//     step = (object px/s  x  difficulty percent / 100)  x 64 / 72.58 frames per second  (rounded)
localparam int FR = FRAME_RATE_X100;   // 7258 = 72.58 frames per second x 100

// EASY
localparam int STEP_GOLD_S_EASY   = (RETRACT_GOLD_SMALL_PX_PER_SEC  * PULL_SPEED_PERCENT_EASY   / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_GOLD_M_EASY   = (RETRACT_GOLD_MEDIUM_PX_PER_SEC * PULL_SPEED_PERCENT_EASY   / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_GOLD_L_EASY   = (RETRACT_GOLD_LARGE_PX_PER_SEC  * PULL_SPEED_PERCENT_EASY   / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_ROCK_S_EASY   = (RETRACT_ROCK_SMALL_PX_PER_SEC  * PULL_SPEED_PERCENT_EASY   / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_ROCK_M_EASY   = (RETRACT_ROCK_MEDIUM_PX_PER_SEC * PULL_SPEED_PERCENT_EASY   / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_ROCK_L_EASY   = (RETRACT_ROCK_LARGE_PX_PER_SEC  * PULL_SPEED_PERCENT_EASY   / 100 * FP * 100 + FR / 2) / FR;

// NORMAL
localparam int STEP_GOLD_S_NORMAL = (RETRACT_GOLD_SMALL_PX_PER_SEC  * PULL_SPEED_PERCENT_NORMAL / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_GOLD_M_NORMAL = (RETRACT_GOLD_MEDIUM_PX_PER_SEC * PULL_SPEED_PERCENT_NORMAL / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_GOLD_L_NORMAL = (RETRACT_GOLD_LARGE_PX_PER_SEC  * PULL_SPEED_PERCENT_NORMAL / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_ROCK_S_NORMAL = (RETRACT_ROCK_SMALL_PX_PER_SEC  * PULL_SPEED_PERCENT_NORMAL / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_ROCK_M_NORMAL = (RETRACT_ROCK_MEDIUM_PX_PER_SEC * PULL_SPEED_PERCENT_NORMAL / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_ROCK_L_NORMAL = (RETRACT_ROCK_LARGE_PX_PER_SEC  * PULL_SPEED_PERCENT_NORMAL / 100 * FP * 100 + FR / 2) / FR;

// HARD
localparam int STEP_GOLD_S_HARD   = (RETRACT_GOLD_SMALL_PX_PER_SEC  * PULL_SPEED_PERCENT_HARD   / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_GOLD_M_HARD   = (RETRACT_GOLD_MEDIUM_PX_PER_SEC * PULL_SPEED_PERCENT_HARD   / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_GOLD_L_HARD   = (RETRACT_GOLD_LARGE_PX_PER_SEC  * PULL_SPEED_PERCENT_HARD   / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_ROCK_S_HARD   = (RETRACT_ROCK_SMALL_PX_PER_SEC  * PULL_SPEED_PERCENT_HARD   / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_ROCK_M_HARD   = (RETRACT_ROCK_MEDIUM_PX_PER_SEC * PULL_SPEED_PERCENT_HARD   / 100 * FP * 100 + FR / 2) / FR;
localparam int STEP_ROCK_L_HARD   = (RETRACT_ROCK_LARGE_PX_PER_SEC  * PULL_SPEED_PERCENT_HARD   / 100 * FP * 100 + FR / 2) / FR;

// The difficulty in use. Fixed for now (game_params.sv); a later step will drive it from the game.
difficulty_t difficulty;
assign difficulty = DIFFICULTY;

// What is on the hook. catchType is valid one clock after hookCatch (the gold field registers it).
logic    hookCatch_d;
logic    caught;          // 1 = something is on the hook (this shot)
object_t caughtType;
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        hookCatch_d <= 1'b0;
        caught      <= 1'b0;
        caughtType  <= OBJ_NONE;
    end
    else begin
        hookCatch_d <= hookCatch;
        if (hookState == 2'd0) begin              // back to swinging -> hook is empty again
            caught     <= 1'b0;
            caughtType <= OBJ_NONE;
        end
        else if (hookCatch_d && !caught) begin    // first catch of this shot
            caught     <= 1'b1;
            caughtType <= object_t'(catchType);
        end
    end
end

// Pick the pull-back step: empty hook, or the caught object at the current difficulty.
logic [9:0] retractStep;
always_comb begin
    retractStep = 10'(RETRACT_EMPTY_STEP_FP);                 // empty hook (hook_params.sv)
    if (caught) begin
        case (difficulty)
            EASY:   case (caughtType)
                         GOLD_SMALL:  retractStep = 10'(STEP_GOLD_S_EASY);
                         GOLD_MEDIUM: retractStep = 10'(STEP_GOLD_M_EASY);
                         GOLD_LARGE:  retractStep = 10'(STEP_GOLD_L_EASY);
                         ROCK_SMALL:  retractStep = 10'(STEP_ROCK_S_EASY);
                         ROCK_MEDIUM: retractStep = 10'(STEP_ROCK_M_EASY);
                         ROCK_LARGE:  retractStep = 10'(STEP_ROCK_L_EASY);
                         default:     retractStep = 10'(RETRACT_EMPTY_STEP_FP);
                     endcase
            NORMAL: case (caughtType)
                         GOLD_SMALL:  retractStep = 10'(STEP_GOLD_S_NORMAL);
                         GOLD_MEDIUM: retractStep = 10'(STEP_GOLD_M_NORMAL);
                         GOLD_LARGE:  retractStep = 10'(STEP_GOLD_L_NORMAL);
                         ROCK_SMALL:  retractStep = 10'(STEP_ROCK_S_NORMAL);
                         ROCK_MEDIUM: retractStep = 10'(STEP_ROCK_M_NORMAL);
                         ROCK_LARGE:  retractStep = 10'(STEP_ROCK_L_NORMAL);
                         default:     retractStep = 10'(RETRACT_EMPTY_STEP_FP);
                     endcase
            HARD:   case (caughtType)
                         GOLD_SMALL:  retractStep = 10'(STEP_GOLD_S_HARD);
                         GOLD_MEDIUM: retractStep = 10'(STEP_GOLD_M_HARD);
                         GOLD_LARGE:  retractStep = 10'(STEP_GOLD_L_HARD);
                         ROCK_SMALL:  retractStep = 10'(STEP_ROCK_S_HARD);
                         ROCK_MEDIUM: retractStep = 10'(STEP_ROCK_M_HARD);
                         ROCK_LARGE:  retractStep = 10'(STEP_ROCK_L_HARD);
                         default:     retractStep = 10'(RETRACT_EMPTY_STEP_FP);
                     endcase
            default: retractStep = 10'(RETRACT_EMPTY_STEP_FP);
        endcase
    end
end

// ---------------- the hook ----------------
logic signed [10:0] Xend, Yend;
logic        [10:0] R;

hook_move u_move (
    .clk, .resetN, .startOfFrame,
    .shoot_key(shoot_req), .tipCollision(tipCollision || hookCatch), .freeze,
    .retractStep,
    .X0, .Y0, .Xend, .Yend, .R, .hookState
);

hook_draw u_draw (
    .clk, .resetN, .pixelX, .pixelY,
    .X0, .Y0, .Xend, .Yend, .R,
    .drawingRequest(hookDR), .RGBout(hookRGB), .tipDR
);

assign hookBusy = (hookState != 2'd0);

endmodule
