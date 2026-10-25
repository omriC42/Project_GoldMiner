// hook_params.sv - ALL tunable settings of the hook in one place.
// Gold Miner project, Oct 2026.
//
// HOW TO CHANGE A SPEED:
//   1. Change a number in the "EDIT HERE" section (real-world units: deg/s, px/s).
//   2. Recompile (the small hook_speed_test project compiles in a few minutes).
//   Nothing else needs to change - the per-frame steps below are computed by
//   Quartus at compile time (no extra hardware).
//
// WHY "PER SECOND" AND NOT "PER FRAME":
//   startOfFrame comes from VGA_Controller at 72.58 Hz (31.5 MHz / (833*521)),
//   NOT 30 Hz as old comments in the project say. Writing speeds per second and
//   converting here keeps them correct if the frame rate ever changes.

package hook_params;

  // ======================= EDIT HERE =======================
  localparam int SWING_DEG_PER_SEC        = 120; // swing speed. 220 -> 0..180 deg in ~0.8 s (full back-and-forth ~1.65 s)
  localparam int SHOOT_PX_PER_SEC         = 200; // hook going down/out
  localparam int RETRACT_EMPTY_PX_PER_SEC = 300; // pull-back with nothing caught (weights are added in Step 9)

  localparam int MIN_R      = 40;  // rope length while swinging [px]
  localparam int X_MIN      = 2;   // hook tip may not go left of this x  -> retract
  localparam int X_MAX      = 637; // hook tip may not go right of this x -> retract
  localparam int Y_MAX      = 477; // hook tip may not go below this y    -> retract

  localparam int SWING_MIN_DEG = 15;    // swing stops here on the right side (0 = horizontal right)
  localparam int SWING_MAX_DEG = 165;   // swing stops here on the left side (180 = horizontal left)
  // where the rope starts, relative to the miner's top-left corner (miner is 64x64):
  // 32,64 = middle of the miner's bottom edge (rail height, y = 164 in the game)
  localparam int HOOK_DX    = 32;
  localparam int HOOK_DY    = 64;

  // drawing (hook_draw.sv). Colors are 8-bit RGB as used by objects_mux / VGA_Controller
  localparam int          ROPE_HALF_WIDTH_X4 = 4;      // rope half-width in 1/4 px: 4 -> 1 px each side (about 3 px wide)
  localparam logic [7:0]  ROPE_COLOR         = 8'h49;  // dark grey
  localparam logic [7:0]  CLAW_COLOR         = 8'hB6;  // light grey (metal)
  // =========================================================


  // ---------------- do not edit below this line ----------------
  localparam int FRAME_RATE_X100 = 7258; // measured: 72.58 Hz (see tests/clock_check.py)
  localparam int FP              = 64;   // fixed point: values kept x64 (same trick as smiley_move)
  localparam int FP_BITS         = 6;    // log2(FP)

  localparam int ANGLE_STEP_DEG  = 3;            // one LUT entry = 3 degrees
  localparam int ANGLE_LAST_IDX  = 180 / ANGLE_STEP_DEG; // 60 -> indices 0..60 (0=right, 30=down, 60=left)
  localparam int ANGLE_MAX_FP    = ANGLE_LAST_IDX * FP;  // 3840
  localparam int SWING_MIN_FP = (SWING_MIN_DEG / ANGLE_STEP_DEG) * FP;   // 15 -> 320
  localparam int SWING_MAX_FP = (SWING_MAX_DEG / ANGLE_STEP_DEG) * FP;   // 165 -> 3520
  // per-frame steps in fixed point (rounded):  value_per_sec * FP / frames_per_sec
  localparam int SWING_STEP_FP   = (SWING_DEG_PER_SEC * FP * 100 + (ANGLE_STEP_DEG * FRAME_RATE_X100) / 2)
                                  / (ANGLE_STEP_DEG * FRAME_RATE_X100);                          // 220 -> 65 (1.02 idx/frame)
  localparam int SHOOT_STEP_FP   = (SHOOT_PX_PER_SEC * FP * 100 + FRAME_RATE_X100 / 2) / FRAME_RATE_X100;          // 200 -> 176 (2.75 px/frame)
  localparam int RETRACT_EMPTY_STEP_FP = (RETRACT_EMPTY_PX_PER_SEC * FP * 100 + FRAME_RATE_X100 / 2) / FRAME_RATE_X100; // 300 -> 265

  localparam int MIN_R_FP        = MIN_R * FP;

endpackage
