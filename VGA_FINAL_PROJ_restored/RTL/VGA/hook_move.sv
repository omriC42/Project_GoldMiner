// (c) Technion IIT, Department of Electrical Engineering 2025
// hook_move - Gold Miner hook motion (swing / shoot / retract).
// Based on the course smiley_move template (Alex Grinshpun, Dudy, Eyal Lev).
//
// Oct 2026 cleanup (Step 1 of hook integration):
//  * merge-conflict leftovers removed
//  * X0/Y0 are 11-bit coordinates (were 1-bit by mistake), R is now an output
//  * all speeds come from hook_params.sv (deg/s, px/s) and use fixed point x64,
//    so the hook is no longer 2.4x too fast (frames are 72.58 Hz, not 30 Hz)
//  * retract moves only on startOfFrame (old version moved every clock = 2 us)
//  * shoot_key is edge-detected: one press = one shot, holding does not re-shoot
//  * 3-degree angle table (61 entries) for a smooth swing
// Oct 2026 (Step 9): the pull-back step comes from the input retractStep (hook_block picks it:
//  empty hook or the weight of the caught object, see game_params.sv).
// Oct 2026: outputs dirCos / dirSin = 256*cos / 256*sin of the current angle (the same table values
//  used for the tip), so hook_block can hang the caught object along the rope (carried_draw).
// Oct 2026 (Step 10): input restart (1-clock pulse, new level) -> the hook is put back at the top:
//  SWING, shortest rope, pointing straight down, like after reset. It wins over freeze.
//
// Angle convention (screen coordinates, y grows downward):
//   index 0 = 0 deg = pointing right, index 30 = 90 deg = straight down,
//   index 60 = 180 deg = pointing left.

module hook_move (
    input  logic                clk,
    input  logic                resetN,
    input  logic                startOfFrame,  // 1-clock pulse, 72.58 Hz, from VGA_Controller
    input  logic                shoot_key,     // keypad 2 (level) - edge detected inside
    input  logic                tipCollision,  // hook tip touched an object -> start retract
    input  logic                freeze,        // 1 = hold everything (pause / game over)
    input  logic                restart,       // 1-clock pulse: new level -> back to the top, swinging
    input  logic        [9:0]   retractStep,   // pull-back per frame, pixels x64 (from hook_block)
    input  logic signed [10:0]  X0,            // rope origin (under the miner)
    input  logic signed [10:0]  Y0,

    output logic signed [10:0]  Xend,          // hook tip position
    output logic signed [10:0]  Yend,
    output logic        [10:0]  R,             // rope length in pixels (used by hook_draw)
    output logic        [1:0]   hookState,     // 0 = swing, 1 = shoot, 2 = retract
    output logic signed [9:0]   dirCos,        // 256*cos(angle) - rope direction (for the carried object)
    output logic signed [9:0]   dirSin         // 256*sin(angle)
);

import hook_params::*;

// ---------------- angle tables: 256*cos / 256*sin of (3*index) degrees ----------------
localparam logic signed [9:0] LUT_COS [0:60] = '{
    10'sd256, 10'sd256, 10'sd255, 10'sd253, 10'sd250, 10'sd247,
    10'sd243, 10'sd239, 10'sd234, 10'sd228, 10'sd222, 10'sd215,
    10'sd207, 10'sd199, 10'sd190, 10'sd181, 10'sd171, 10'sd161,
    10'sd150, 10'sd139, 10'sd128, 10'sd116, 10'sd104, 10'sd92,
    10'sd79,  10'sd66,  10'sd53,  10'sd40,  10'sd27,  10'sd13,
    10'sd0,  -10'sd13, -10'sd27, -10'sd40, -10'sd53, -10'sd66,
   -10'sd79, -10'sd92, -10'sd104,-10'sd116,-10'sd128,-10'sd139,
   -10'sd150,-10'sd161,-10'sd171,-10'sd181,-10'sd190,-10'sd199,
   -10'sd207,-10'sd215,-10'sd222,-10'sd228,-10'sd234,-10'sd239,
   -10'sd243,-10'sd247,-10'sd250,-10'sd253,-10'sd255,-10'sd256,
   -10'sd256
};

localparam logic signed [9:0] LUT_SIN [0:60] = '{
    10'sd0,   10'sd13,  10'sd27,  10'sd40,  10'sd53,  10'sd66,
    10'sd79,  10'sd92,  10'sd104, 10'sd116, 10'sd128, 10'sd139,
    10'sd150, 10'sd161, 10'sd171, 10'sd181, 10'sd190, 10'sd199,
    10'sd207, 10'sd215, 10'sd222, 10'sd228, 10'sd234, 10'sd239,
    10'sd243, 10'sd247, 10'sd250, 10'sd253, 10'sd255, 10'sd256,
    10'sd256, 10'sd256, 10'sd255, 10'sd253, 10'sd250, 10'sd247,
    10'sd243, 10'sd239, 10'sd234, 10'sd228, 10'sd222, 10'sd215,
    10'sd207, 10'sd199, 10'sd190, 10'sd181, 10'sd171, 10'sd161,
    10'sd150, 10'sd139, 10'sd128, 10'sd116, 10'sd104, 10'sd92,
    10'sd79,  10'sd66,  10'sd53,  10'sd40,  10'sd27,  10'sd13,
    10'sd0
};

// ---------------- state ----------------
localparam logic [1:0] S_SWING   = 2'd0;
localparam logic [1:0] S_SHOOT   = 2'd1;
localparam logic [1:0] S_RETRACT = 2'd2;

logic [1:0]  state;
logic [12:0] angle_fp;     // angle index * 64   (0 .. 3840)
logic        swing_right;  // 1 = index growing (towards 180 deg / left side of screen)
logic [17:0] R_fp;         // rope length * 64
logic        shoot_key_d;  // for edge detection
logic        shoot_pulse;
logic        hitBorder;
logic [5:0]  angle_idx;

assign shoot_pulse = shoot_key && !shoot_key_d;
assign angle_idx   = angle_fp[FP_BITS+5:FP_BITS]; // integer part = LUT index 0..60 (angle_fp <= 3840 < 4096)
assign R           = R_fp[FP_BITS+10:FP_BITS];  // integer part = pixels
assign hookState   = state;

// tip outside the play area?
assign hitBorder = (Xend <= X_MIN) || (Xend >= X_MAX) || (Yend >= Y_MAX);

always_ff @(posedge clk or negedge resetN) begin
    if (!resetN) begin
        state       <= S_SWING;
        angle_fp    <= 13'(30 * FP);   // start pointing straight down
        swing_right <= 1'b0;
        R_fp        <= 18'(MIN_R_FP);
        shoot_key_d <= 1'b0;
    end
    else begin
        shoot_key_d <= shoot_key;

        if (restart) begin                     // new level: back to the start (like reset)
            state       <= S_SWING;
            angle_fp    <= 13'(30 * FP);
            swing_right <= 1'b0;
            R_fp        <= 18'(MIN_R_FP);
        end
        else if (!freeze) begin
            case (state)

            // ---------- swing back and forth between 0 and 180 degrees ----------
            S_SWING: begin
                if (startOfFrame) begin
                    if (swing_right) begin
                        if (angle_fp + 13'(SWING_STEP_FP) >= 13'(SWING_MAX_FP)) begin
                            angle_fp    <= 13'(SWING_MAX_FP);   // clamp at 180 deg and turn
                            swing_right <= 1'b0;
                        end
                        else
                            angle_fp <= angle_fp + 13'(SWING_STEP_FP);
                    end
                    else begin
                        if (angle_fp <= 13'(SWING_MIN_FP + SWING_STEP_FP)) begin
                            angle_fp    <= 13'(SWING_MIN_FP);               // clamp at 0 deg and turn
                            swing_right <= 1'b1;
                        end
                        else
                            angle_fp <= angle_fp - 13'(SWING_STEP_FP);
                    end
                end
                if (shoot_pulse)
                    state <= S_SHOOT;                            // angle is frozen from now on
            end

            // ---------- rope gets longer until border or object ----------
            S_SHOOT: begin
                if (tipCollision || hitBorder)
                    state <= S_RETRACT;                          // react on the same clock
                else if (startOfFrame)
                    R_fp <= R_fp + 18'(SHOOT_STEP_FP);
            end

            // ---------- rope gets shorter back to MIN_R ----------
            S_RETRACT: begin
                if (startOfFrame) begin
                    if (R_fp <= 18'(MIN_R_FP) + 18'(retractStep)) begin
                        R_fp  <= 18'(MIN_R_FP);                  // never undershoot
                        state <= S_SWING;
                    end
                    else
                        R_fp <= R_fp - 18'(retractStep);
                end
            end

            default: state <= S_SWING;
            endcase
        end
    end
end

// ---------------- tip position (combinational) ----------------
// dx = R * 256cos >> 8  (R up to 11 bits, LUT 10 bits signed -> 22-bit product)
logic signed [21:0] dx_full, dy_full;
assign dx_full = $signed({1'b0, R}) * LUT_COS[angle_idx];
assign dy_full = $signed({1'b0, R}) * LUT_SIN[angle_idx];
assign Xend    = X0 + 11'(dx_full >>> 8);
assign Yend    = Y0 + 11'(dy_full >>> 8);
// rope direction (Oct 2026): the same table values as above
assign dirCos  = LUT_COS[angle_idx];
assign dirSin  = LUT_SIN[angle_idx];

endmodule
