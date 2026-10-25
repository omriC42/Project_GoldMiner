// game_params.sv - ALL tunable GAME settings in one place: level rules, what the objects are worth,
// how fast the hook pulls each object back, and the difficulty settings.
// Gold Miner project, Oct 2026 (hook integration Step 9).
//
// HOW TO CHANGE SOMETHING:
//   1. Change a number in the "EDIT HERE" section.
//   2. Recompile. Nothing else needs to change - the modules read these numbers and Quartus
//      converts them at compile time (no extra hardware).
//   3. Optional: run  tests/run_hook_weight.do  - it checks that every number here is used and
//      still fits in the hardware (values max 63, speeds max ~1100 px/s, time max 119 s).
//
// The hook's own settings (swing, shooting speed, EMPTY pull-back, rope) are in hook_params.sv.

package game_params;

  // ---------------- names used below and by the modules (do not edit) ----------------
  // object codes = the same numbers the gold field (GoldsMatrixBitMap) stores in its grid
  typedef enum logic [2:0] {
      OBJ_NONE    = 3'd0,   // empty cell / nothing on the hook
      GOLD_SMALL  = 3'd1,
      GOLD_MEDIUM = 3'd2,
      GOLD_LARGE  = 3'd3,
      ROCK_SMALL  = 3'd4,
      ROCK_MEDIUM = 3'd5,
      ROCK_LARGE  = 3'd6
  } object_t;

  typedef enum logic [1:0] {
      EASY   = 2'd0,
      NORMAL = 2'd1,
      HARD   = 2'd2
  } difficulty_t;


  // ======================= EDIT HERE =======================

  // ---------------- level rules (game_hud) ----------------
  localparam int START_SECONDS = 60;   // time per level in seconds          (1 .. 119)

  // dollars needed to win a level (the level is won when the score is MORE than the target):
  //   level 1 needs TARGET_START, every next level needs TARGET_STEP more (it stops at 999).
  //   e.g. NORMAL 48, 30  ->  level 1: 48, level 2: 78, level 3: 108, ...
  //                                      (0 .. 999 each)
  localparam int TARGET_START_EASY   = 40;
  localparam int TARGET_START_NORMAL = 48;
  localparam int TARGET_START_HARD   = 60;
  localparam int TARGET_STEP_EASY    = 20;
  localparam int TARGET_STEP_NORMAL  = 30;
  localparam int TARGET_STEP_HARD    = 40;

  // ---------------- what each object is worth (dollars) ----------------   (1 .. 63 each)
  localparam int GOLD_SMALL_VALUE  = 12;
  localparam int GOLD_MEDIUM_VALUE = 24;
  localparam int GOLD_LARGE_VALUE  = 36;
  localparam int ROCK_SMALL_VALUE  = 4;
  localparam int ROCK_MEDIUM_VALUE = 8;
  localparam int ROCK_LARGE_VALUE  = 12;

  // ---------------- pull-back speed with that object on the hook (pixels per second) ----------------
  // (these are the NORMAL speeds; EASY/HARD scale them with PULL_SPEED_PERCENT below)
  localparam int RETRACT_GOLD_SMALL_PX_PER_SEC  = 240;
  localparam int RETRACT_GOLD_MEDIUM_PX_PER_SEC = 170;
  localparam int RETRACT_GOLD_LARGE_PX_PER_SEC  = 110;
  localparam int RETRACT_ROCK_SMALL_PX_PER_SEC  = 200;
  localparam int RETRACT_ROCK_MEDIUM_PX_PER_SEC = 130;
  localparam int RETRACT_ROCK_LARGE_PX_PER_SEC  =  70;

   // ---------------- cheats ----------------
  localparam bit CHEATS_ON = 1;   // 1 = keypad + jumps to the next level, 0 = cheats disabled

 // ---------------- difficulty ----------------
  // EASY, NORMAL or HARD.
  // PREPARED for a later step: switching difficulty while playing is not built yet, so the game
  // always uses DIFFICULTY below. Changing it here and recompiling already works for the
  // pull-back speeds and the level targets.
  localparam difficulty_t DIFFICULTY = NORMAL;

  // all pull-back speeds WITH an object are multiplied by this percent (100 = as written above)
  localparam int PULL_SPEED_PERCENT_EASY   = 120;
  localparam int PULL_SPEED_PERCENT_NORMAL = 100;
  localparam int PULL_SPEED_PERCENT_HARD   =  80;

  // share of GOLD among the objects of a new layout, in percent (the rest are rocks).
  // NOT USED YET - the gold field is still 50/50. It is used when the difficulty step is built.
  localparam int GOLD_PERCENT_EASY   = 70;
  localparam int GOLD_PERCENT_NORMAL = 50;
  localparam int GOLD_PERCENT_HARD   = 30;

  // =========================================================

endpackage
