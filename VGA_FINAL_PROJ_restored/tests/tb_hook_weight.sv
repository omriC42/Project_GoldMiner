// tb_hook_weight.sv - Step 9: weight + game_params.sv (the moved parameters still work)
//
// Run:  ModelSim -> cd <project>/tests -> do run_hook_weight.do        (expect VERSION 9.8)
// Checklist: tests/CHECKLIST_step9_weight.md
//
// Every expected number below is read from game_params.sv / hook_params.sv, so after you change
// a number there, this test checks the NEW number (and that it still fits in the hardware).
//
// T1 the numbers in game_params.sv fit the hardware (values 1..63, time 1..119 s, target 0..999,
//    every pull-back step 1..1023, difficulty 0..2)
// T2 the gold field (real ObjectsMatrixBitMap) gives each object the value from game_params.sv
// T3 hook_block's STEP_* table = game_params.sv speeds x difficulty percent (all 3 difficulties)
// T4 real hook_block, shot straight down by timing into a gold band, once for EACH object type:
//    the hook latches the type, the pull-back speed is MEASURED and compared with game_params.sv,
//    the hook comes back and forgets the object. Then one shot with no gold: empty speed.
//    Oct 2026 (9.5) SCORE AT THE TOP: a game_hud (real clock, so its time never runs out here) gets
//    its score from hook_block deliverPulse/deliverValue exactly like the game: the score must NOT
//    change at the catch, and must go up by the object's value (game_params.sv) when the hook is
//    back up - ONE pulse per catch, none for the empty shot.
// T5 game_hud: the default time and the level targets from game_params.sv, for EASY, NORMAL and HARD
//    (one HUD per difficulty, fast clock: 1 "second" = 100 clocks). Each HUD plays 4 levels:
//    level 1 target = TARGET_START, every won level adds TARGET_STEP (max 999), the screen digits
//    match the target. Rule (game_hud): the level is won when score >= target, so levels 1-3 are won
//    with EXACTLY the target, and at level 4 a score of target-1 -> GAME OVER.
// T6 cheat: keypad + (nextLevelKey) jumps to the next level - once per press, even when held;
//    ignored in GAME OVER. 9.7: with the cheatsOn input = 0 (settings screen) + does nothing.
// Oct 2026 (9.7, Step 14) SETTINGS INPUTS: difficulty / time / cheats are inputs now.
// T7 the hook's pull-back speed follows the difficulty input while running (gold large, EASY + HARD)
// T8 the share of gold in new layouts follows the difficulty: 300 layouts each,
//    gold share = round(GOLD_PERCENT x 16 / 100) / 16 (+-5%).
//
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_hook_weight;
import hook_params::*;

localparam int DOWN_IDX = 90 / ANGLE_STEP_DEG;   // 30 = straight down
localparam real FPS = FRAME_RATE_X100 / 100.0;
localparam int  HUD_CLOCK_HZ = 100;              // game_hud: 1 second = 100 clocks in this test

logic clk = 0, resetN = 0, sof = 0;
always #5 clk = ~clk;

// =====================================================================================
// HOOK with a test gold band (y 300..330, whole width). The band's drawing request is delayed
// 2 clocks like the real gold field. catchType = the object type of the current test.
// =====================================================================================
logic [10:0] pixelX = 0, pixelY = 0;
logic signed [10:0] minerX = 11'sd288, minerY = 11'sd100;     // rope origin (320,164)
logic shoot_key = 0;
logic [2:0] catchType = 0;
bit   band_on = 0;
logic band_p1 = 0, band_p2 = 0;
always @(posedge clk) begin
    band_p1 <= band_on && pixelY >= 300 && pixelY <= 330;
    band_p2 <= band_p1;
end
logic goldDR; assign goldDR = band_p2;
logic hookDR, tipDR, hookBusy, hookCatch; logic [7:0] hookRGB; logic [1:0] hookState;
logic dPulse; logic [5:0] dValue;             // 9.5: deliverPulse / deliverValue (score at the top)
logic [1:0] hbDiff = 2'(game_params::DIFFICULTY);   // 9.7: the hook's difficulty input (T7 changes it)
localparam logic [1:0] DEF_TIME = 2'(game_params::DEFAULT_TIME_SEL);
hook_block hb (.clk, .resetN, .startOfFrame(sof), .pixelX, .pixelY, .minerX, .minerY,
               .minerMoving(1'b0), .shoot_key, .tipCollision(1'b0), .goldDR, .freeze(1'b0), .newLevel(1'b0),
               .catchType, .difficulty(hbDiff), .hookDR, .hookRGB, .tipDR, .hookBusy, .hookState, .hookCatch,
               .deliverPulse(dPulse), .deliverValue(dValue));
// score at the top (9.5): the score HUD gets its dollars from the hook, like TOP_VGA_DEMO_KBD
logic hsDR, hsGameOver, hsLevelWon, hsNewLevel; logic [7:0] hsRGB;
game_hud hudScore (.clk, .resetN, .pixelX(11'd0), .pixelY(11'd0),
    .collectPulse(dPulse), .collectValue(dValue), .gameOverKey(1'b0), .nextLevelKey(1'b0),
    .difficulty(2'(game_params::DIFFICULTY)), .timeSel(DEF_TIME), .cheatsOn(1'b0),
    .drawingRequest(hsDR), .RGBout(hsRGB), .gameOver(hsGameOver), .levelWon(hsLevelWon),
    .newLevel(hsNewLevel));
int top_score; assign top_score = hudScore.dollars;
int n_deliver = 0, sum_deliver = 0, n_hsLevel = 0;
int seen [1:6], val_found [1:6], n_layouts;      // T2 (9.6)
always @(posedge clk) begin
    if (dPulse) begin n_deliver++; sum_deliver += dValue; end
    if (hsNewLevel) n_hsLevel++;      // must stay 0: levels change only when the clock runs out
end

// =====================================================================================
// GOLD FIELD (only its value table is used, T2)
// Step 12 (9.6): the old objectValue() function is gone - T2 now reads the value (cellValue) of the
// object in each cell of real random layouts, until all 6 kinds were seen.
// =====================================================================================
logic gDR, gPulse; logic [7:0] gRGB; logic [5:0] gValue; logic [2:0] gType;
logic [10:0] gOffX = 0, gOffY = 0;  logic gNew = 0;
logic [1:0]  gDiff = 2'(game_params::DIFFICULTY);   // 9.7: the gold field's difficulty input (T8)
ObjectsMatrixBitMap gbm (.clk, .resetN, .offsetX(gOffX), .offsetY(gOffY), .InsideRectangle(1'b0),
    .collision_Hook_Object(1'b0), .newLevel(gNew), .difficulty(gDiff),
    .drawingRequest(gDR), .RGBout(gRGB), .collectPulse(gPulse), .collectValue(gValue), .collectType(gType));

// =====================================================================================
// HUDs (T5): hud = the game's (default difficulty of game_params.sv), hudE/hudN/hudH = one per
// difficulty input. The times and the targets are NOT given here: they must come from game_params.sv.
// =====================================================================================
logic hp [0:2] = '{0, 0, 0};                 // collectPulse per difficulty HUD
logic [5:0] hv [0:2] = '{0, 0, 0};           // collectValue per difficulty HUD
logic ck [0:2] = '{0, 0, 0};                 // cheat key (keypad +) per difficulty HUD
logic cheatN = 1;                            // 9.7: hudN's cheatsOn input (T6 turns it off)
logic hudDR, gameOver, levelWon, newLevel; logic [7:0] hudRGB;
game_hud #(.CLOCK_HZ(HUD_CLOCK_HZ)) hud (.clk, .resetN, .pixelX(11'd0), .pixelY(11'd0),
    .collectPulse(1'b0), .collectValue(6'd0), .gameOverKey(1'b0), .nextLevelKey(1'b0),
    .difficulty(2'(game_params::DIFFICULTY)), .timeSel(DEF_TIME), .cheatsOn(1'b0),
    .drawingRequest(hudDR), .RGBout(hudRGB), .gameOver, .levelWon, .newLevel);
logic nlE, nlN, nlH, goE, goN, goH;
game_hud #(.CLOCK_HZ(HUD_CLOCK_HZ)) hudE (.clk, .resetN,
    .pixelX(11'd0), .pixelY(11'd0), .collectPulse(hp[0]), .collectValue(hv[0]), .gameOverKey(1'b0),
    .nextLevelKey(ck[0]), .difficulty(2'd0), .timeSel(DEF_TIME), .cheatsOn(1'b1),
    .drawingRequest(), .RGBout(), .gameOver(goE), .levelWon(), .newLevel(nlE));
game_hud #(.CLOCK_HZ(HUD_CLOCK_HZ)) hudN (.clk, .resetN,
    .pixelX(11'd0), .pixelY(11'd0), .collectPulse(hp[1]), .collectValue(hv[1]), .gameOverKey(1'b0),
    .nextLevelKey(ck[1]), .difficulty(2'd1), .timeSel(DEF_TIME), .cheatsOn(cheatN),
    .drawingRequest(), .RGBout(), .gameOver(goN), .levelWon(), .newLevel(nlN));
game_hud #(.CLOCK_HZ(HUD_CLOCK_HZ)) hudH (.clk, .resetN,
    .pixelX(11'd0), .pixelY(11'd0), .collectPulse(hp[2]), .collectValue(hv[2]), .gameOverKey(1'b0),
    .nextLevelKey(ck[2]), .difficulty(2'd2), .timeSel(DEF_TIME), .cheatsOn(1'b1),
    .drawingRequest(), .RGBout(), .gameOver(goH), .levelWon(), .newLevel(nlH));

// =====================================================================================
// wave helpers
// =====================================================================================
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
int  frame_no = 0;
int  angle_deg;   assign angle_deg = hb.u_move.angle_idx * ANGLE_STEP_DEG;
int  R;           assign R = hb.R;
int  caughtType;  assign caughtType = hb.caughtType;
int  retractStep; assign retractStep = hb.retractStep;
int  cur_diff = 0;                            // T5: which HUD is being played (0 EASY 1 NORMAL 2 HARD)
int  seconds;     assign seconds = (cur_diff == 0) ? hudE.secondsLeft : (cur_diff == 1) ? hudN.secondsLeft : hudH.secondsLeft;
int  score;       assign score   = (cur_diff == 0) ? hudE.dollars     : (cur_diff == 1) ? hudN.dollars     : hudH.dollars;
int  level;       assign level   = (cur_diff == 0) ? hudE.level       : (cur_diff == 1) ? hudN.level       : hudH.level;
int  target;      assign target  = (cur_diff == 0) ? hudE.target      : (cur_diff == 1) ? hudN.target      : hudH.target;
int  target_digits;                           // what the screen shows: hundreds*100 + tens*10 + ones
assign target_digits = (cur_diff == 0) ? hudE.tgtH*100 + hudE.tgtT*10 + hudE.tgtO :
                       (cur_diff == 1) ? hudN.tgtH*100 + hudN.tgtT*10 + hudN.tgtO :
                                         hudH.tgtH*100 + hudH.tgtT*10 + hudH.tgtO;
logic cur_newLevel; assign cur_newLevel = (cur_diff == 0) ? nlE : (cur_diff == 1) ? nlN : nlH;
logic cur_gameOver; assign cur_gameOver = (cur_diff == 0) ? goE : (cur_diff == 1) ? goN : goH;
int  cur_type = 0;
real meas_pull_px_s = 0, exp_pull_px_s = 0;
int  n_catch = 0, n_newLevel = 0;
always @(posedge clk) begin
    if (hookCatch) n_catch++;
    if (cur_newLevel) n_newLevel++;
end
realtime t_start [0:8];
realtime t_end   [0:8];
task automatic begin_test(input int n, input string name);
    if (test_no > 0) t_end[test_no] = $realtime;
    test_no = n; $sformat(test_name, "%s", name); t_start[n] = $realtime;
    $display("\n[%0t] ---- T%0d %s ----", $time, n, name);
endtask
task automatic check(input bit ok, input string what);
    $sformat(chk_name, "%s", what);
    if (ok) begin nPass++; chk_pass = 1; $display("[%0t]   PASS  %s", $time, what); end
    else    begin nFail++; chk_fail = 1; $display("[%0t]   FAIL  %s   <-----", $time, what); end
    #20; chk_pass = 0; chk_fail = 0;
endtask
task automatic write_windows_file(input int last);
    int fd;
    fd = $fopen("test_windows.do", "w");
    $fdisplay(fd, "set TW(0) {0 %0d}", longint'($realtime));
    for (int i = 1; i <= last; i++) begin
        $fdisplay(fd, "set TW(%0d) {%0d %0d}", i, longint'(t_start[i]), longint'(t_end[i]));
        $fdisplay(fd, "catch {wave cursor add -time %0dns -name T%0d}", longint'(t_start[i]), i);
    end
    $fclose(fd);
endtask

// one frame: startOfFrame, then the pixels around the claw (that is where a catch happens)
task automatic game_frame();
    int ax, ay;
    @(negedge clk) sof = 1; @(negedge clk) sof = 0;
    frame_no++;
    ax = hb.Xend - 10; ay = hb.Yend - 10;
    for (int n = 0; n < 21*21; n++) begin
        @(negedge clk);
        pixelX = (ax + n % 21 < 0) ? 0 : ax + n % 21;
        pixelY = (ay + n / 21 < 0) ? 0 : ay + n / 21;
    end
    repeat (4) @(negedge clk);
endtask

// ---------------- independent reference (written again here, not taken from the RTL) ----------------
function automatic string type_name(input int t);
    case (t)
        1: return "gold small";  2: return "gold medium"; 3: return "gold large";
        4: return "rock small";  5: return "rock medium"; 6: return "rock large";
        default: return "nothing";
    endcase
endfunction
function automatic int value_param(input int t);
    case (t)
        1: return game_params::GOLD_SMALL_VALUE;  2: return game_params::GOLD_MEDIUM_VALUE;
        3: return game_params::GOLD_LARGE_VALUE;  4: return game_params::ROCK_SMALL_VALUE;
        5: return game_params::ROCK_MEDIUM_VALUE; 6: return game_params::ROCK_LARGE_VALUE;
        default: return 0;
    endcase
endfunction
function automatic int speed_param(input int t);
    case (t)
        1: return game_params::RETRACT_GOLD_SMALL_PX_PER_SEC;  2: return game_params::RETRACT_GOLD_MEDIUM_PX_PER_SEC;
        3: return game_params::RETRACT_GOLD_LARGE_PX_PER_SEC;  4: return game_params::RETRACT_ROCK_SMALL_PX_PER_SEC;
        5: return game_params::RETRACT_ROCK_MEDIUM_PX_PER_SEC; 6: return game_params::RETRACT_ROCK_LARGE_PX_PER_SEC;
        default: return RETRACT_EMPTY_PX_PER_SEC;
    endcase
endfunction
function automatic int percent_param(input int d);
    case (d)
        0: return game_params::PULL_SPEED_PERCENT_EASY;
        2: return game_params::PULL_SPEED_PERCENT_HARD;
        default: return game_params::PULL_SPEED_PERCENT_NORMAL;
    endcase
endfunction
function automatic int px_to_step(input int px);       // round(px * 64 / 72.58)
    return (px * 64 * 100 + FRAME_RATE_X100 / 2) / FRAME_RATE_X100;
endfunction
function automatic int expected_step(input int d, input int t);
    if (t >= 1 && t <= 6) return px_to_step(speed_param(t) * percent_param(d) / 100);
    return RETRACT_EMPTY_STEP_FP;
endfunction
function automatic int hook_step(input int d, input int t);   // read hook_block's STEP_* table
    case (d*8 + t)
         1: return hb.STEP_GOLD_S_EASY;    2: return hb.STEP_GOLD_M_EASY;    3: return hb.STEP_GOLD_L_EASY;
         4: return hb.STEP_ROCK_S_EASY;    5: return hb.STEP_ROCK_M_EASY;    6: return hb.STEP_ROCK_L_EASY;
         9: return hb.STEP_GOLD_S_NORMAL; 10: return hb.STEP_GOLD_M_NORMAL; 11: return hb.STEP_GOLD_L_NORMAL;
        12: return hb.STEP_ROCK_S_NORMAL; 13: return hb.STEP_ROCK_M_NORMAL; 14: return hb.STEP_ROCK_L_NORMAL;
        17: return hb.STEP_GOLD_S_HARD;   18: return hb.STEP_GOLD_M_HARD;   19: return hb.STEP_GOLD_L_HARD;
        20: return hb.STEP_ROCK_S_HARD;   21: return hb.STEP_ROCK_M_HARD;   22: return hb.STEP_ROCK_L_HARD;
        default: return -1;
    endcase
endfunction
function automatic real expected_px_s(input int t);
    if (t >= 1 && t <= 6) return real'(speed_param(t)) * percent_param(int'(hbDiff)) / 100.0;
    return real'(RETRACT_EMPTY_PX_PER_SEC);
endfunction

// shoot straight down by timing, catch in the band (or hit the floor), measure the pull-back
task automatic shot_test(input int t, input bit with_gold);
    int f, ra, rb, s0, d0, v0, l0;
    cur_type = t;
    s0 = top_score; d0 = n_deliver; v0 = sum_deliver; l0 = n_hsLevel;
    @(negedge clk) begin catchType = 3'(t); band_on = with_gold; end
    n_catch = 0;
    f = 0; while (int'(hb.u_move.angle_idx) != DOWN_IDX && f < 600) begin game_frame(); f++; end
    @(negedge clk) shoot_key = 1; repeat (3) @(negedge clk); shoot_key = 0;
    f = 0; while (hookState != 2'd2 && f < 600) begin game_frame(); f++; end
    repeat (5) @(negedge clk);
    if (with_gold)
        check(n_catch > 0 && hb.caught && caughtType == t,
              $sformatf("%s: caught in the band at tip y %0d, hook latched type %0d", type_name(t), hb.Yend, caughtType));
    if (with_gold)
        check(top_score == s0 && n_deliver == d0,
              $sformatf("%s: score NOT changed at the catch (still %0d) - it counts at the top", type_name(t), top_score));
    else
        check(n_catch == 0 && !hb.caught && hb.Yend >= Y_MAX,
              $sformatf("no gold: hook reached the floor (tip y %0d), nothing latched", hb.Yend));
    // speed over 15 frames, measured on the exact fixed-point length R_fp (x64)
    exp_pull_px_s = expected_px_s(t);
    game_frame(); ra = hb.u_move.R_fp;
    repeat (15) game_frame();
    rb = hb.u_move.R_fp;
    meas_pull_px_s = real'(ra - rb) / 64.0 / 15.0 * FPS;
    check(meas_pull_px_s > 0.97 * exp_pull_px_s && meas_pull_px_s < 1.03 * exp_pull_px_s,
          $sformatf("%s: pull-back %0.1f px/s, game_params says %0.1f px/s (+-3%%)", type_name(t), meas_pull_px_s, exp_pull_px_s));
    f = 0; while (hookState != 2'd0 && f < 1500) begin game_frame(); f++; end
    if (with_gold)
        check(hookState == 2'd0 && hb.R == MIN_R && !hb.caught,
              $sformatf("%s: back after %0d frames (%0.1f s), hook empty again", type_name(t), f, f / FPS));
    repeat (5) @(negedge clk);
    if (with_gold)
        check(n_deliver == d0 + 1 && sum_deliver - v0 == value_param(t) && n_hsLevel == l0 &&
              top_score == s0 + value_param(t),
              $sformatf("%s: at the top ONE delivery of %0d (game_params %0d) -> score %0d -> %0d", type_name(t),
                        sum_deliver - v0, value_param(t), s0, top_score));
    else
        check(n_deliver == d0 && top_score == s0,
              $sformatf("empty shot back at the top: no delivery, score stays %0d", top_score));
    @(negedge clk) band_on = 0;
endtask

task automatic hud_wait_level_end(output int clocks);
    clocks = 0;
    while (!cur_newLevel && !cur_gameOver && clocks < (game_params::DEFAULT_SECONDS + 2) * HUD_CLOCK_HZ + 100) begin
        @(negedge clk); clocks++;
    end
    repeat (3) @(negedge clk);
endtask
task automatic hud_add(input int amount);              // collectPulses that add up to amount
    int left, v;
    left = amount;
    while (left > 0) begin
        v = (left > 63) ? 63 : left;
        @(negedge clk) begin hp[cur_diff] = 1; hv[cur_diff] = 6'(v); end
        @(negedge clk) hp[cur_diff] = 0;
        left -= v;
    end
endtask
// expected targets (game_params.sv)
function automatic int tgt_start(input int d);
    case (d) 0: return game_params::TARGET_START_EASY; 2: return game_params::TARGET_START_HARD;
             default: return game_params::TARGET_START_NORMAL; endcase
endfunction
function automatic int tgt_step(input int d);
    case (d) 0: return game_params::TARGET_STEP_EASY; 2: return game_params::TARGET_STEP_HARD;
             default: return game_params::TARGET_STEP_NORMAL; endcase
endfunction
function automatic int expected_target(input int d, input int lvl);   // level 1, 2, 3, ...
    int t; t = tgt_start(d) + (lvl - 1) * tgt_step(d);
    return (t > 999) ? 999 : t;
endfunction
function automatic string diff_name(input int d);
    case (d) 0: return "EASY"; 1: return "NORMAL"; default: return "HARD"; endcase
endfunction

// play one difficulty HUD: 3 levels won with EXACTLY the target (rule: score >= target),
// then level 4 with target-1 -> GAME OVER
task automatic hud_play(input int d);
    int c, lv;
    cur_diff = d;
    @(negedge clk) resetN = 0; repeat (3) @(negedge clk); resetN = 1; @(negedge clk);
    n_newLevel = 0;
    check(seconds == game_params::DEFAULT_SECONDS && target == tgt_start(d) && target_digits == tgt_start(d) && level == 1,
          $sformatf("%s level 1: %0d s, target %0d, screen digits %0d (game_params: %0d s, target %0d)",
                    diff_name(d), seconds, target, target_digits, game_params::DEFAULT_SECONDS, tgt_start(d)));
    for (lv = 1; lv <= 3; lv++) begin
        hud_add(target);                                      // exactly the target = enough
        hud_wait_level_end(c);
        check(n_newLevel == lv && level == lv + 1 && !cur_gameOver && score == 0 &&
              target == expected_target(d, lv + 1) && target_digits == target,
              $sformatf("%s: score %0d -> level %0d won -> level %0d target %0d, screen %0d (expected %0d)",
                        diff_name(d), expected_target(d, lv), lv, level, target, target_digits, expected_target(d, lv + 1)));
    end
    if (target == 0)
        check(1, $sformatf("%s level 4: target is 0, a level can never be lost (skipped)", diff_name(d)));
    else begin
        hud_add(target - 1);                                  // one dollar short
        hud_wait_level_end(c);
        check(cur_gameOver && level == 4,
              $sformatf("%s level 4: score %0d = target-1 -> GAME OVER (target %0d)", diff_name(d), target - 1, target));
    end
endtask

// T6: the + cheat on the NORMAL test HUD
task automatic cheat_test();
    int lv0, tg0, nl0;
    bit on;
    on = cheatN;
    cur_diff = 1;
    @(negedge clk) resetN = 0; repeat (3) @(negedge clk); resetN = 1;
    repeat (350) @(negedge clk);                       // 3.5 "seconds" pass: the clock is not at the start
    hud_add(5);                                        // some score
    n_newLevel = 0; lv0 = level; tg0 = target;
    @(negedge clk) ck[1] = 1;                          // press + ...
    repeat (3) @(negedge clk);
    if (on)
        check(level == lv0 + 1 && target == expected_target(1, lv0 + 1) && target_digits == target &&
              seconds == game_params::DEFAULT_SECONDS && score == 0 && n_newLevel == 1,
              $sformatf("CHEATS_ON = 1: + -> level %0d -> %0d, target %0d -> %0d, clock back to %0d s, score 0, one newLevel",
                        lv0, level, tg0, target, seconds));
    else
        check(level == lv0 && target == tg0 && n_newLevel == 0, "CHEATS_ON = 0: + does nothing");
    repeat (1000) @(negedge clk);                      // ... and HOLD it for 10 "seconds"
    check(level == lv0 + (on ? 1 : 0) && n_newLevel == (on ? 1 : 0),
          $sformatf("+ held for 1000 clocks -> still only %0d level jump (level %0d)", on ? 1 : 0, level));
    @(negedge clk) ck[1] = 0; repeat (5) @(negedge clk);
    lv0 = level;
    @(negedge clk) ck[1] = 1; repeat (3) @(negedge clk); ck[1] = 0;   // second press
    repeat (3) @(negedge clk);
    check(level == lv0 + (on ? 1 : 0), $sformatf("a second press -> level %0d -> %0d", lv0, level));
    // let the time run out with score 0 -> GAME OVER, then + must not bring the game back
    if (target == 0)
        check(1, "target is 0: GAME OVER cannot happen (skipped)");
    else begin
        nl0 = 0;
        while (!cur_gameOver && nl0 < (game_params::DEFAULT_SECONDS + 2) * HUD_CLOCK_HZ) begin @(negedge clk); nl0++; end
        lv0 = level;
        @(negedge clk) ck[1] = 1; repeat (3) @(negedge clk); ck[1] = 0; repeat (3) @(negedge clk);
        check(cur_gameOver && level == lv0, $sformatf("in GAME OVER + does nothing (still GAME OVER, level %0d)", level));
    end
endtask

game_params::difficulty_t diff_now = game_params::DIFFICULTY;   // copy: enum name for the Transcript
int  n_gold, n_obj;  real exp_share, meas_share;                  // T8
function automatic int gold_pct(input int d);
    case (d) 0: return game_params::GOLD_PERCENT_EASY; 2: return game_params::GOLD_PERCENT_HARD;
             default: return game_params::GOLD_PERCENT_NORMAL; endcase
endfunction
bit ok_all;
int c;

initial begin
    $display("\n##### tb_hook_weight VERSION 9.8 (2026-10-25, Step 13.2: timeUp output removed) - if not the version Claude announced, run the full  do run_hook_weight.do  #####");
    $display("   game_params: difficulty %s, %0d s per level, targets EASY %0d+%0d, NORMAL %0d+%0d, HARD %0d+%0d per level",
             diff_now.name(), game_params::DEFAULT_SECONDS,
             game_params::TARGET_START_EASY, game_params::TARGET_STEP_EASY, game_params::TARGET_START_NORMAL,
             game_params::TARGET_STEP_NORMAL, game_params::TARGET_START_HARD, game_params::TARGET_STEP_HARD);
    repeat (3) @(negedge clk); resetN = 1;
    repeat (5) @(negedge clk);

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 game_params fit the hardware");
    ok_all = 1; for (int t = 1; t <= 6; t++) if (value_param(t) < 1 || value_param(t) > 63) ok_all = 0;
    check(ok_all, "every object value is 1..63 (the score input is 6 bits)");
    check(game_params::LEVEL_TIME_SHORT >= 1 && game_params::LEVEL_TIME_SHORT <= 119 &&
          game_params::LEVEL_TIME_NORMAL >= 1 && game_params::LEVEL_TIME_NORMAL <= 119 &&
          game_params::LEVEL_TIME_LONG >= 1 && game_params::LEVEL_TIME_LONG <= 119 &&
          game_params::DEFAULT_TIME_SEL >= 0 && game_params::DEFAULT_TIME_SEL <= 2,
          $sformatf("LEVEL_TIME_SHORT/NORMAL/LONG = %0d/%0d/%0d s are 1..119 (the clock shows up to 1:59), DEFAULT_TIME_SEL %0d is 0..2",
                    game_params::LEVEL_TIME_SHORT, game_params::LEVEL_TIME_NORMAL, game_params::LEVEL_TIME_LONG, game_params::DEFAULT_TIME_SEL));
    ok_all = 1; for (int d = 0; d < 3; d++) if (tgt_start(d) < 0 || tgt_start(d) > 999 || tgt_step(d) < 0 || tgt_step(d) > 999) ok_all = 0;
    check(ok_all, "every TARGET_START and TARGET_STEP is 0..999 (3 digits on the HUD)");
    ok_all = 1;
    for (int d = 0; d < 3; d++) for (int t = 1; t <= 6; t++)
        if (expected_step(d, t) < 1 || expected_step(d, t) > 1023) ok_all = 0;
    check(ok_all, "every pull-back speed x difficulty percent gives a step of 1..1023 (about 1..1160 px/s)");
    check(int'(game_params::DIFFICULTY) >= 0 && int'(game_params::DIFFICULTY) <= 2,
          $sformatf("DIFFICULTY = %s is EASY, NORMAL or HARD", diff_now.name()));

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 gold field values");
    seen = '{default:0}; val_found = '{default:-1}; n_layouts = 0;
    while (n_layouts < 60 && !(seen[1] && seen[2] && seen[3] && seen[4] && seen[5] && seen[6])) begin
        @(negedge clk) gNew = 1; @(negedge clk) gNew = 0;      // a new random layout
        repeat (2) @(negedge clk);
        n_layouts++;
        for (int row = 1; row < 4; row++) for (int col = 0; col < 8; col++) begin
            @(negedge clk) begin gOffX = 11'(col * 64 + 32); gOffY = 11'(row * 64 + 32); end
            @(negedge clk);
            if (gbm.MazeBitMapMask[row][col] != 0) begin
                seen[gbm.MazeBitMapMask[row][col]] = 1;
                if (val_found[gbm.MazeBitMapMask[row][col]] == -1 || int'(gbm.cellValue) != value_param(gbm.MazeBitMapMask[row][col]))
                    val_found[gbm.MazeBitMapMask[row][col]] = gbm.cellValue;
            end
        end
    end
    $display("   %0d random layouts scanned to see all 6 kinds", n_layouts);
    for (int t = 1; t <= 6; t++)
        check(seen[t] && val_found[t] == value_param(t),
              $sformatf("%s is worth %0d in the gold field (game_params: %0d)", type_name(t), val_found[t], value_param(t)));

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 pull-back table");
    ok_all = 1;
    for (int d = 0; d < 3; d++) for (int t = 1; t <= 6; t++)
        if (hook_step(d, t) != expected_step(d, t)) begin
            ok_all = 0;
            $display("   d %0d type %0d: hook_block %0d, expected %0d", d, t, hook_step(d, t), expected_step(d, t));
        end
    for (int d = 0; d < 3; d++)
        $display("   difficulty %0d: steps (x64 px/frame) gS %0d gM %0d gL %0d rS %0d rM %0d rL %0d, empty %0d", d,
                 expected_step(d,1), expected_step(d,2), expected_step(d,3), expected_step(d,4), expected_step(d,5),
                 expected_step(d,6), expected_step(d,0));
    check(ok_all, "hook_block STEP_* = game_params speeds x percent for EASY, NORMAL and HARD (18 values)");

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 each object pulls back at its speed");
    for (int t = 1; t <= 6; t++) shot_test(t, 1'b1);
    shot_test(0, 1'b0);

    // ------------------------------------------------------------ T5
    begin_test(5, "T5 game_hud: seconds + level targets");
    check(hud.tStart == tgt_start(int'(game_params::DIFFICULTY)) && hud.tStep == tgt_step(int'(game_params::DIFFICULTY)),
          $sformatf("the game's HUD (difficulty input %s): start %0d, step %0d", diff_now.name(), hud.tStart, hud.tStep));
    for (int d = 0; d < 3; d++) hud_play(d);

    // ------------------------------------------------------------ T6
    begin_test(6, "T6 cheat: keypad + = next level");
    cheat_test();
    // 9.7: cheats OFF (settings screen) -> + does nothing
    @(negedge clk) begin resetN = 0; cheatN = 0; end
    repeat (3) @(negedge clk); resetN = 1;
    repeat (50) @(negedge clk);
    cur_diff = 1; n_newLevel = 0;
    @(negedge clk) ck[1] = 1; repeat (3) @(negedge clk); ck[1] = 0; repeat (3) @(negedge clk);
    check(level == 1 && n_newLevel == 0, $sformatf("cheatsOn = 0: + does nothing (level %0d, %0d newLevel)", level, n_newLevel));
    @(negedge clk) cheatN = 1;

    // ------------------------------------------------------------ T7 (9.7)
    begin_test(7, "T7 pull-back follows the difficulty input");
    @(negedge clk) hbDiff = 2'd0;                        // EASY: objects come back faster
    shot_test(3, 1'b1);
    @(negedge clk) hbDiff = 2'd2;                        // HARD: slower
    shot_test(3, 1'b1);
    @(negedge clk) hbDiff = 2'(game_params::DIFFICULTY);

    // ------------------------------------------------------------ T8 (9.7)
    begin_test(8, "T8 share of gold follows the difficulty");
    for (int d = 0; d < 3; d++) begin
        @(negedge clk) gDiff = 2'(d);
        n_gold = 0; n_obj = 0;
        for (int l = 0; l < 300; l++) begin
            @(negedge clk) gNew = 1; @(negedge clk) gNew = 0;     // a new random layout
            repeat (37) @(negedge clk);                            // let the random bits move on
            for (int row = 1; row < 4; row++) for (int col = 0; col < 8; col++)
                if (gbm.MazeBitMapMask[row][col] != 0) begin
                    n_obj++;
                    if (gbm.MazeBitMapMask[row][col] <= 3) n_gold++;
                end
        end
        exp_share = real'((gold_pct(d) * 16 + 50) / 100) / 16.0;
        meas_share = real'(n_gold) / real'(n_obj);
        check(n_obj == 300 * 8 && meas_share > exp_share - 0.05 && meas_share < exp_share + 0.05,
              $sformatf("%s: %0d of %0d objects are gold = %0.1f%% (game_params %0d%% -> %0d/16 = %0.1f%%, +-5%%)",
                        diff_name(d), n_gold, n_obj, 100.0 * meas_share, gold_pct(d), (gold_pct(d) * 16 + 50) / 100, 100.0 * exp_share));
    end
    @(negedge clk) gDiff = 2'(game_params::DIFFICULTY);

    // ------------------------------------------------------------ end
    t_end[8] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(8);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #200_000_000;
    $display("WATCHDOG: not finished after 200 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
