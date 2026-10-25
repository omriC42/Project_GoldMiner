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
//  * Oct 2026: CARRY + SCORE AT THE TOP. While the hook pulls something back, carried_draw hangs
//    the caught sprite on the claw, along the rope (its pixels go out on hookDR/hookRGB, the claw
//    is drawn on top of it, and it is NOT part of tipDR - it never catches anything).
//    When the pull-back ends (RETRACT -> SWING) with something on the hook, deliverPulse (1 clock)
//    + deliverValue (its dollars, game_params.sv) go to game_hud -> the score goes up at the TOP.
//    An empty pull-back (border / floor) delivers nothing.
//  * Oct 2026 (Step 10): GAME OVER + NEW LEVEL.
//    freeze (= game_hud gameOver): the hook stops where it is (hook_move) AND cannot catch
//    (hookCatch is blocked), so nothing disappears from the gold field on the frozen screen.
//    newLevel (1-clock pulse from game_hud): the hook goes straight back to the top, empty
//    (hook_move restart). Whatever was on it is dropped WITHOUT a deliverPulse - an object
//    still on the rope when the level ends is lost (decided with the user).
//  * Oct 2026 (Step 14): input difficulty (from the settings screen) picks the column of the
//    pull-back table below - before, it was the fixed DIFFICULTY of game_params.sv.

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
    input  logic               freeze,        // game over (game_hud gameOver): hold + no catching
    input  logic               newLevel,      // 1-clock pulse (game_hud): hook back to the top, empty
    input  logic        [2:0]  catchType,     // Gold_DISPLAY.collectType: code of the object just taken
    input  logic        [1:0]  difficulty,    // settings: 0 EASY, 1 NORMAL, 2 HARD -> pull-back speeds

    output logic               hookDR,        // rope or claw pixel   -> objects_mux
    output logic        [7:0]  hookRGB,       //                      -> objects_mux
    output logic               tipDR,         // claw pixel only      -> collision
    output logic               hookBusy,      // hook is out          -> lock the miner
    output logic        [1:0]  hookState,     // 0 SWING, 1 SHOOT, 2 RETRACT
    output logic               hookCatch,     // 1-clock pulses: claw on gold/rock while shooting -> Objects_DISPLAY
    output logic               deliverPulse,  // 1 clock when a caught object reaches the top -> game_hud
    output logic        [5:0]  deliverValue   // its value in dollars                          -> game_hud
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
        hookCatch <= tipDR_d && goldDR && (hookState == 2'd1) && !freeze;   // registered: clean for timing
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

// The difficulty in use = the input from the settings screen (Step 14)
difficulty_t diffNow;
assign diffNow = difficulty_t'(difficulty);

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
        if (newLevel || hookState == 2'd0) begin  // back to swinging / new level -> hook is empty again
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
        case (diffNow)
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
logic signed  [9:0] dirCos, dirSin;   // rope direction (for the carried object)

hook_move u_move (
    .clk, .resetN, .startOfFrame,
    .shoot_key(shoot_req), .tipCollision(tipCollision || hookCatch), .freeze, .restart(newLevel),
    .retractStep,
    .X0, .Y0, .Xend, .Yend, .R, .hookState, .dirCos, .dirSin
);

logic       drawDR;                   // rope or claw (hook_draw)
logic [7:0] drawRGB;
hook_draw u_draw (
    .clk, .resetN, .pixelX, .pixelY,
    .X0, .Y0, .Xend, .Yend, .R,
    .drawingRequest(drawDR), .RGBout(drawRGB), .tipDR
);

// ---------------- the caught object on the claw (Oct 2026) ----------------
logic       carryShow;                // something on the hook AND being pulled back
logic       carryDR;
logic [7:0] carryRGB;
assign carryShow = caught && (hookState == 2'd2);
carried_draw u_carry (
    .clk, .resetN, .pixelX, .pixelY,
    .Xend, .Yend, .dirCos, .dirSin,
    .show(carryShow), .objType(caughtType),
    .drawingRequest(carryDR), .RGBout(carryRGB)
);
// all three are 1 clock after their pixel. Order on the screen: claw > carried object > rope.
assign hookDR  = drawDR || carryDR;
assign hookRGB = tipDR   ? drawRGB  :      // claw pixel (tipDR = claw only)
                 carryDR ? carryRGB :      // the object
                           drawRGB;        // rope (or nothing)

// ---------------- score at the top (Oct 2026) ----------------
// the object's value, from game_params.sv (plain case, no function)
logic [5:0] caughtValue;
always_comb begin
    case (caughtType)
        GOLD_SMALL:  caughtValue = 6'(GOLD_SMALL_VALUE);
        GOLD_MEDIUM: caughtValue = 6'(GOLD_MEDIUM_VALUE);
        GOLD_LARGE:  caughtValue = 6'(GOLD_LARGE_VALUE);
        ROCK_SMALL:  caughtValue = 6'(ROCK_SMALL_VALUE);
        ROCK_MEDIUM: caughtValue = 6'(ROCK_MEDIUM_VALUE);
        ROCK_LARGE:  caughtValue = 6'(ROCK_LARGE_VALUE);
        default:     caughtValue = 6'd0;
    endcase
end
// RETRACT -> SWING with something on the hook = it arrived at the top -> one pulse with its value.
// (on that clock 'caught' is still 1; it is cleared on the next clock because the state is SWING)
// A new level also ends RETRACT, but it clears 'caught' on the same clock -> no pulse (object lost).
logic [1:0] hookState_d;
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        hookState_d  <= 2'd0;
        deliverPulse <= 1'b0;
        deliverValue <= 6'd0;
    end
    else begin
        hookState_d  <= hookState;
        deliverPulse <= 1'b0;
        if (hookState_d == 2'd2 && hookState == 2'd0 && caught) begin
            deliverPulse <= 1'b1;
            deliverValue <= caughtValue;
        end
    end
end

assign hookBusy = (hookState != 2'd0);

endmodule
