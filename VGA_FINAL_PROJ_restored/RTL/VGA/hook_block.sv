// hook_block - the complete Gold Miner hook: hook_move + hook_draw + carried_draw in one block.
// Symbol for the top-level schematic: hook_block.bsf

module hook_block (
    input  logic               clk,
    input  logic               resetN,
    input  logic               startOfFrame,
    input  logic        [10:0] pixelX,
    input  logic        [10:0] pixelY,
    input  logic signed [10:0] minerX,        // miner top-left corner (Miner_Block_T)
    input  logic signed [10:0] minerY,
    input  logic               minerMoving,   // key 4 or key 6 held
    input  logic               shoot_key,     // key 2 (level, straight from the keyboard)
    input  logic               tipCollision,  // extra 'caught' input (tests); GND in the game
    input  logic               goldDR,        // drawing request of the gold field, Objects_DISPLAY (2 clocks after its pixel)
    input  logic               freeze,        // game over (game_hud gameOver): hold + no catching
    input  logic               newLevel,      // 1-clock pulse (game_hud): hook back to the top, empty
    input  logic        [2:0]  catchType,     // Objects_DISPLAY collectType: code of the object just taken
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

// ---------------- catching ----------------
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

// ---------------- weight ----------------
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

// The difficulty in use = the input from the settings screen
difficulty_t diffNow;
assign diffNow = difficulty_t'(difficulty);

// What is on the hook. catchType is valid one clock after hookCatch (the gold field registers it).
logic    hookCatch_d;
logic    caught;         
object_t caughtType;
always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        hookCatch_d <= 1'b0;
        caught      <= 1'b0;
        caughtType  <= OBJ_NONE;
    end
    else begin
        hookCatch_d <= hookCatch;
        if (newLevel || hookState == 2'd0) begin  // back to swinging / new level 
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
    retractStep = 10'(RETRACT_EMPTY_STEP_FP);                 // empty hook speed
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
logic signed  [9:0] dirCos, dirSin;   // rope direction (carried_draw does not use it any more)

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

// ---------------- the caught object in the claw ----------------
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

// ---------------- score at the top ----------------
// the object's value, from game_params.sv
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
// handle score pulse
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
