// game_params.sv - ALL tunable GAME settings in one place: level rules, what the objects are worth,
// how fast the hook pulls each object back, and the difficulty settings.
// Gold Miner project.
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
  // object codes = the same numbers the gold field (ObjectsMatrixBitMap) stores in its grid
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

  // game sounds: the number game_sound sends to melody_player_1 (= GameJukeBox slot)
  typedef enum logic [3:0] {
      SND_NONE     = 4'd0,   // silence
      SND_CATCH    = 4'd1,   // claw grabbed something
      SND_MONEY    = 4'd2,   // the object reached the top, score goes up
      SND_LEVEL    = 4'd3,   // level won (new level)
      SND_GAMEOVER = 4'd4    // game over
  } sound_t;


  // ======================= EDIT HERE =======================

  // ---------------- level rules (game_hud) ----------------
  // time per level: the 3 choices of the settings screen   (1 .. 119 s each)
  localparam int LEVEL_TIME_SHORT  = 30;
  localparam int LEVEL_TIME_NORMAL = 60;
  localparam int LEVEL_TIME_LONG   = 90;

  // dollars needed to win a level (the level is won when the score is at least the target):
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

  // ---------------- DEFAULT SETTINGS ----------------
  // What the game uses after power-up / KEY0. The player changes them on the settings screen
  // (keypad + on the opening screen); the game then follows the player's choice, not these.
  localparam difficulty_t DIFFICULTY = NORMAL;   // EASY, NORMAL or HARD
  localparam int DEFAULT_TIME_SEL    = 1;        // 0 = LEVEL_TIME_SHORT, 1 = NORMAL, 2 = LONG
  localparam bit CHEATS_ON           = 1;        // 1 = keypad + (next level) and * (game over) work
  localparam bit SOUND_ON            = 1;        // 1 = game sounds on
  // the default time in seconds (worked out from DEFAULT_TIME_SEL - do not edit)
  localparam int DEFAULT_SECONDS = (DEFAULT_TIME_SEL == 0) ? LEVEL_TIME_SHORT :
                                   (DEFAULT_TIME_SEL == 2) ? LEVEL_TIME_LONG  : LEVEL_TIME_NORMAL;

 // ---------------- difficulty: what EASY / NORMAL / HARD change ----------------
  // the level targets are above (TARGET_START_* / TARGET_STEP_*)

  // all pull-back speeds WITH an object are multiplied by this percent (100 = as written above)
  localparam int PULL_SPEED_PERCENT_EASY   = 120;
  localparam int PULL_SPEED_PERCENT_NORMAL = 100;
  localparam int PULL_SPEED_PERCENT_HARD   =  80;

  // share of GOLD among the objects of a new layout, in percent (the rest are rocks).
  // Used by the gold field. It draws a random number 0..15 per object and makes it gold
  // when the number is below round(PERCENT x 16 / 100): 70% -> 11/16 (69%), 50% -> 8/16, 30% -> 5/16 (31%).
  localparam int GOLD_PERCENT_EASY   = 70;
  localparam int GOLD_PERCENT_NORMAL = 50;
  localparam int GOLD_PERCENT_HARD   = 30;

  // ---------------- sounds (game_sound + GameJukeBox) ----------------
  // 1 = the sound plays, 0 = that event is silent
  localparam bit SOUND_CATCH_ON    = 1;
  localparam bit SOUND_MONEY_ON    = 1;
  localparam bit SOUND_LEVEL_ON    = 1;
  localparam bit SOUND_GAMEOVER_ON = 1;
  // tempo: length of ONE beat in 1/100 s (the notes themselves are in GameJukeBox.sv, in beats)
  localparam int SOUND_BEAT_FAST_CS = 3;   // catch + money       (1 .. 63)
  localparam int SOUND_BEAT_SLOW_CS = 6;   // level won + game over (1 .. 63)
  localparam int SOUND_GAP_CS       = 2;   // silence after every note, 1/100 s (0 .. 31)

  // =========================================================

endpackage
