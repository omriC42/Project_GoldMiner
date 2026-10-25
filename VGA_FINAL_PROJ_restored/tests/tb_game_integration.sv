// tb_game_integration.sv - Step 8.5: the hook inside the GAME, played like a player would.
//
// Run:  ModelSim -> cd <project>/tests -> do run_game_integration.do      (expect VERSION 8.11)
// Checklist: tests/CHECKLIST_step85_integration.md
//
// The REAL modules, wired exactly like TOP_VGA_DEMO_KBD.bdf / Miner_Block_T.bdf / Objects_DISPLAY.bdf:
//   miner      : miner_move (initial_x 280, initial_x_speed 60) + square_object 64x64 + minerBitMap + dust_draw
//   hook       : hook_block (minerX/minerY/minerMoving from the miner, hookBusy back to the miner,
//                goldDR from the gold field, hookCatch to the gold field, catchType = goldType)
//   gold field : square_object 512x256 at (64,224) + ObjectsMatrixBitMap (newLevel from game_hud)
//   score      : game_hud (collectPulse / collectValue = hook_block deliverPulse / deliverValue:
//                the score is added when the hook is back at the TOP with the object - Oct 2026 8.5.9)
//   screen     : objects_mux (for the images)
// Not included: VGA_Controller (the testbench makes the pixels + startOfFrame), keyboard (keys are
// driven directly: key2 = shoot, key4 = left, key6 = right), audio, the background picture ROM
// (a plain brown is used instead), back_ground_draw (its border output is always 0 in this project,
// so the miner's collision input is 0 here too - same as on the board).
//
// NO forcing: the testbench walks the miner with keys 4/6 and SHOOTS BY TIMING (presses 2 when the
// swing passes 90 deg), exactly what you do on the board.
//
// T1 start of the game          T2 walking: hook follows the miner, no shot while moving
// T3 walk above a target        T4 aim by timing + shoot -> catch, score, object gone
// T5 miner locked while the hook is out (key 4 held the whole time)
// T6 hook back -> miner free again (the same held key 4 now moves it)
// T7 a second catch: score adds up, key 2 during the pull-back is ignored
// 8.5.9 CARRY: the caught object is drawn on the rope during the pull-back (T5: every carried
//    pixel reaches the screen), and the score is added only when the
//    hook is back at the top (T5/T7: unchanged at the catch, +value on arrival, ONE deliverPulse).
// 8.10 (hook fix, Oct 25 2026): the carried object hangs STRAIGHT DOWN in the claw - centred on the
//    tip in x, first visible row CARRY_OFFSET_PX below the tip (carried_draw.sv), at every rope angle.
// 8.6 (Step 10) wired like TOP_VGA_DEMO_KBD: game_hud gameOver -> hook_block freeze and (OR hookBusy)
//    -> miner lock; game_hud newLevel -> hook_block newLevel. Keys * (gameOverKey) and + (nextLevelKey).
// T9  keypad + while pulling an object back: new level -> hook home empty at once, object NOT counted,
//     score 0, level 2, new layout of 8 objects, the miner stays where it is.
// 8.7 (Step 11) game_sound wired like the TOP (catch = gold field collectPulse, money = deliverPulse,
//     newLevel, gameOver). Checked: T5 catch then money in that order, T9 only the level sound (the
//     dropped object makes no money sound), T10 the game over sound exactly once.
// T10 keypad * in the middle of a shot: GAME OVER -> hook, miner and dust frozen; keys 2/4 do nothing;
//     score and gold field unchanged.
// Step 9: every catch also MEASURES the pull-back speed and compares it with game_params.sv
// Dust (Oct 2026, partner's 6-picture dust): T2 dust on the correct side while walking and gone after
//   the round ends, T5 NO dust round starts while the hook is out, T6 dust again when free,
//   T8 (8.5.8) key 6 held against the right wall: the dust stops (the cart does not move).
// Images: frames/game_1_start.bmp ... game_6_second.bmp
//
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_game_integration;
import hook_params::*;

localparam int RIGHT_DEG_IDX = 90 / ANGLE_STEP_DEG;   // 30 = straight down

logic clk = 0, resetN = 0, sof = 0;
always #5 clk = ~clk;

logic [10:0] pixelX = 0, pixelY = 0;
logic key2 = 0, key4 = 0, key6 = 0;            // keypad keys (keyIsPressed[2], [4], [6])
logic keyStar = 0, keyPlus = 0;               // keypad * (game over shortcut) and + (next level cheat)
logic gameOver;                               // game_hud -> hook freeze + miner lock (Step 10)
// the settings (Step 14): here the defaults of game_params.sv (the settings screen is tested in Part B)
logic [1:0] setDiff = 2'(game_params::DIFFICULTY), setTime = 2'(game_params::DEFAULT_TIME_SEL);
logic       setCheats = game_params::CHEATS_ON, setSound = game_params::SOUND_ON;

// =====================================================================================
// MINER  (= Smiley_Block_T)
// =====================================================================================
logic signed [10:0] minerX, minerY;
logic minerMoving, hookBusy;
logic minerLock;                          // = hookBusy OR gameOver (OR2 inst43 in the TOP)
logic dustLeftKey, dustRightKey;          // = miner movingLeft / movingRight -> dust_draw leftKey / rightKey
logic [2:0] HitEdgeCode;
logic [10:0] smOffX, smOffY; logic smRecDR; logic [7:0] smRecRGB;
logic smileyDR; logic [7:0] smileyRGB;
logic dustDR;   logic [7:0] dustRGB;

miner_move #(.INITIAL_X(280), .INITIAL_Y(32), .INITIAL_X_SPEED(60), .INITIAL_Y_SPEED(50), .Y_ACCEL(-2)) miner (
    .clk, .resetN, .startOfFrame(sof),
    .Y_direction_key(key4), .toggle_x_key(key6),
    .collision(1'b0), .HitEdgeCode,
    .hookBusy(minerLock), .minerMoving, .movingLeft(dustLeftKey), .movingRight(dustRightKey),
    .topLeftX(minerX), .topLeftY(minerY));
square_object #(.OBJECT_WIDTH_X(64), .OBJECT_HEIGHT_Y(64), .OBJECT_COLOR(8'h00)) minerBox (
    .clk, .resetN, .pixelX, .pixelY, .topLeftX(minerX), .topLeftY(minerY),
    .offsetX(smOffX), .offsetY(smOffY), .drawingRequest(smRecDR), .RGBout(smRecRGB));
minerBitMap minerBmp (
    .clk, .resetN, .offsetX(smOffX), .offsetY(smOffY), .InsideRectangle(smRecDR),
    .drawingRequest(smileyDR), .RGBout(smileyRGB), .HitEdgeCode);
// dust exactly like Miner_Block_T.bdf (Oct 2026): the REAL motion from miner_move
dust_draw dust (
    .clk, .resetN, .startOfFrame(sof), .pixelX, .pixelY, .minerX, .minerY,
    .leftKey(dustLeftKey), .rightKey(dustRightKey),
    .drawingRequest(dustDR), .RGBout(dustRGB));

// =====================================================================================
// GOLD FIELD  (= Gold_DISPLAY)
// =====================================================================================
logic [10:0] gOffX, gOffY; logic gBoxDR; logic [7:0] gBoxRGB;
logic goldDR; logic [7:0] goldRGB;
logic goldCollected; logic [5:0] goldValue; logic [2:0] goldType;
logic hookCatch, newLevel;
square_object #(.OBJECT_WIDTH_X(512), .OBJECT_HEIGHT_Y(256)) goldBox (
    .clk, .resetN, .pixelX, .pixelY, .topLeftX(11'sd64), .topLeftY(11'sd224),
    .offsetX(gOffX), .offsetY(gOffY), .drawingRequest(gBoxDR), .RGBout(gBoxRGB));
ObjectsMatrixBitMap gbm (
    .clk, .resetN, .offsetX(gOffX), .offsetY(gOffY), .InsideRectangle(gBoxDR),
    .collision_Hook_Object(hookCatch), .newLevel, .difficulty(setDiff),
    .drawingRequest(goldDR), .RGBout(goldRGB), .collectPulse(goldCollected), .collectValue(goldValue),
    .collectType(goldType));

// =====================================================================================
// HOOK  (= hook_block inst41)
// =====================================================================================
logic hookDR, tipDR; logic [7:0] hookRGB; logic [1:0] hookState;
logic hookDeliver; logic [5:0] hookDeliverValue;     // score at the top (TOP: hook_block -> game_hud)
hook_block hb (
    .clk, .resetN, .startOfFrame(sof), .pixelX, .pixelY,
    .minerX, .minerY, .minerMoving, .shoot_key(key2),
    .tipCollision(1'b0), .goldDR, .freeze(gameOver), .newLevel, .catchType(goldType), .difficulty(setDiff),
    .hookDR, .hookRGB, .tipDR, .hookBusy, .hookState, .hookCatch,
    .deliverPulse(hookDeliver), .deliverValue(hookDeliverValue));

// =====================================================================================
// SCORE  (= game_hud inst28)
// =====================================================================================
logic hudDR; logic [7:0] hudRGB; logic levelWon;
game_hud hud (
    .clk, .resetN, .pixelX, .pixelY,
    .collectPulse(hookDeliver), .collectValue(hookDeliverValue), .gameOverKey(keyStar), .nextLevelKey(keyPlus),
    .difficulty(setDiff), .timeSel(setTime), .cheatsOn(setCheats),
    .drawingRequest(hudDR), .RGBout(hudRGB), .gameOver, .levelWon, .newLevel);
// Step 10: the miner stands still while the hook is out OR the game is over (OR2 inst43 in the TOP)
assign minerLock = hookBusy || gameOver;

// =====================================================================================
// SOUND EVENTS  (= game_sound inst44; melody_player_1 + AUDIO are tested in tb_game_sound)
// =====================================================================================
logic soundStart; logic [3:0] soundSelect;
game_sound gsnd (.clk, .resetN, .catchPulse(goldCollected), .moneyPulse(hookDeliver), .newLevel, .gameOver, .soundOn(setSound),
                 .startSound(soundStart), .soundSelect);
int  snd_log [0:15];        // sounds started since the last snd_clear (game_params::sound_t numbers)
int  snd_n = 0;
always @(posedge clk) if (soundStart) begin snd_log[snd_n] = soundSelect; if (snd_n < 15) snd_n++; end

// =====================================================================================
// SCREEN  (= objects_mux inst9)
// =====================================================================================
logic [7:0] RGBOut;
objects_mux mux (.clk, .resetN,
    .minerDrawingRequest(smileyDR), .minerRGB(smileyRGB),
    .hookDrawingRequest(hookDR), .hookRGB,
    .dustDrawingRequest(dustDR), .dustRGB,
    .timerDrawingRequest(hudDR), .timerRGB(hudRGB),
    .objectsDrawingRequest(goldDR), .objectsRGB(goldRGB),
    .backGroundRGB(8'h00), .BGDrawingRequest(1'b0), .RGB_MIF(8'h88),
    .RGBOut);

// =====================================================================================
// wave helpers
// =====================================================================================
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
logic [8*16:1] scan_kind = "idle";
int  frame_no = 0;
int  angle_deg;  assign angle_deg = hb.u_move.angle_idx * ANGLE_STEP_DEG;
int  ropeX0;     assign ropeX0    = hb.X0;
int  ropeY0;     assign ropeY0    = hb.Y0;
int  minerXspeed; assign minerXspeed = miner.Xspeed;
int  score;      assign score     = hud.dolH * 100 + hud.dolT * 10 + hud.dolO;   // B10: from the digits
int  n_hookCatch = 0, n_collect = 0, last_value = -1, type_at_collect = -1;
int  n_deliver = 0, last_deliver = -1;          // 8.5.9: hook_block deliverPulse (score at the top)
real meas_pull_px_s = 0, exp_pull_px_s = 0;     // pull-back speed with the object (Step 9)
int  tgt_row = -1, tgt_col = -1, tgt_obj = 0, tgt_value = 0, tgt_cx = 0, tgt_cy = 0, tgt_r = 0;
bit  hook_followed = 1;                        // X0/Y0 always = miner + (HOOK_DX, HOOK_DY)
int  n_dust_start_busy = 0;                    // dust rounds that START while the hook is out (must stay 0)
bit  dust_on_prev = 0;
always @(posedge clk) begin
    if (sof) begin
        if (hookBusy && dust.dustOn && !dust_on_prev) n_dust_start_busy++;
        dust_on_prev <= dust.dustOn;
    end
end
always @(posedge clk) begin
    if (hookCatch)     n_hookCatch++;
    if (goldCollected) begin n_collect++; last_value = goldValue; type_at_collect = goldType; end
    if (hookDeliver)   begin n_deliver++; last_deliver = hookDeliverValue; end
end
// carried object on the screen (8.5.9): counted during the full-frame images.
// carryDR belongs to the pixel of one clock earlier; RGBOut (objects_mux) is one more clock later.
int  n_carry_px = 0, n_carry_seen = 0, carry_x0, carry_x1, carry_y0, carry_y1;
logic carry_d = 0; logic [7:0] carryRGB_d = 0; int pxd1 = 0, pyd1 = 0, pxd2 = 0, pyd2 = 0;
always @(posedge clk) begin
    pxd1 <= pixelX; pyd1 <= pixelY;
    carry_d <= hb.carryDR && !hb.tipDR && (scan_kind == "FULL FRAME"); carryRGB_d <= hookRGB;   // only pixels drawn IN the full scan
    if (scan_kind == "FULL FRAME") begin
        if (hb.carryDR && !hb.tipDR) begin
            n_carry_px++;
            if (pxd1 < carry_x0) carry_x0 = pxd1;  if (pxd1 > carry_x1) carry_x1 = pxd1;
            if (pyd1 < carry_y0) carry_y0 = pyd1;  if (pyd1 > carry_y1) carry_y1 = pyd1;
        end
        if (carry_d && RGBOut == carryRGB_d) n_carry_seen++;
    end
end
task automatic carry_reset();
    n_carry_px = 0; n_carry_seen = 0; carry_x0 = 9999; carry_x1 = -1; carry_y0 = 9999; carry_y1 = -1;
endtask
function automatic int carry_top(input int t);    // tip -> first visible row of the hanging object
    // carried_draw (hook fix): top = tip + CARRY_OFFSET_PX - topPad, so the first VISIBLE row is
    // always CARRY_OFFSET_PX below the tip, for every object
    return (t >= 1 && t <= 6) ? CARRY_OFFSET_PX : 0;
endfunction
realtime t_start [0:15];
realtime t_end   [0:15];
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

// ---------------- frames ----------------
// One game frame: a startOfFrame pulse (everything moves once, like the 72.58 Hz pulse on the
// board), then the pixels around the claw are scanned, one per clock - that is where a catch
// can happen. The rest of the screen is only scanned for the images.
task automatic scan_rect(input int ax, input int ay, input int bx, input int by);
    int w, total;
    if (ax < 0) ax = 0; if (ay < 0) ay = 0; if (bx > 639) bx = 639; if (by > 479) by = 479;
    w = bx - ax + 1; total = w * (by - ay + 1);
    for (int n = 0; n < total; n++) begin
        @(negedge clk); pixelX = ax + n % w; pixelY = ay + n / w;
    end
    repeat (4) @(negedge clk);
endtask
task automatic game_frame();
    @(negedge clk) sof = 1; @(negedge clk) sof = 0;
    frame_no++;
    repeat (8) @(negedge clk);                    // miner state machine finishes its frame update
    if (hb.X0 != minerX + HOOK_DX || hb.Y0 != minerY + HOOK_DY) hook_followed = 0;
    $sformat(scan_kind, "%s", "CLAW WINDOW");
    scan_rect(hb.Xend - 10, hb.Yend - 10, hb.Xend + 10, hb.Yend + 10);
    $sformat(scan_kind, "%s", "idle");
endtask
task automatic frames(input int n);
    repeat (n) game_frame();
endtask

// ---------------- images (full 640x480 through objects_mux) ----------------
logic [7:0] img [0:479][0:639];
task automatic put32(input int fd, input int v);
    $fwrite(fd, "%c%c%c%c", v[7:0], v[15:8], v[23:16], v[31:24]);
endtask
task automatic snapshot(input string fname);
    int qx [0:2], qy [0:2], fd; byte r, g, b; logic [7:0] c;
    $sformat(scan_kind, "%s", "FULL FRAME");
    qx = '{-1,-1,-1}; qy = '{0,0,0};
    for (int n = 0; n <= 640*480 + 2; n++) begin
        @(negedge clk);
        if (qx[2] >= 0) img[qy[2]][qx[2]] = RGBOut;     // gold: 2 clocks + mux 1 clock
        qx[2] = qx[1]; qy[2] = qy[1]; qx[1] = qx[0]; qy[1] = qy[0];
        if (n < 640*480) begin pixelX = n % 640; pixelY = n / 640; qx[0] = n % 640; qy[0] = n / 640; end
        else qx[0] = -1;
    end
    fd = $fopen(fname, "wb");
    $fwrite(fd, "BM"); put32(fd, 54 + 640*480*3); put32(fd, 0); put32(fd, 54);
    put32(fd, 40); put32(fd, 640); put32(fd, 480);
    $fwrite(fd, "%c%c%c%c", 8'd1, 8'd0, 8'd24, 8'd0);
    put32(fd, 0); put32(fd, 640*480*3); put32(fd, 2835); put32(fd, 2835); put32(fd, 0); put32(fd, 0);
    for (int y = 479; y >= 0; y--) for (int x = 0; x < 640; x++) begin
        c = img[y][x];
        r = {c[7:5], c[7:5], c[7:6]}; g = {c[4:2], c[4:2], c[4:3]}; b = {c[1:0], c[1:0], c[1:0], c[1:0]};
        $fwrite(fd, "%c%c%c", b, g, r);
    end
    $fclose(fd);
    $sformat(scan_kind, "%s", "idle");
    $display("   image %s  (miner x %0d, hook %s, tip %0d,%0d, score %0d)", fname, minerX,
             (hookState==0)?"SWING":(hookState==1)?"SHOOT":"RETRACT", hb.Xend, hb.Yend, score);
endtask

// ---------------- the gold field ----------------
function automatic int value_of(input int t);
    case (t)   // expected values = game_params.sv
        1: return game_params::GOLD_SMALL_VALUE;  2: return game_params::GOLD_MEDIUM_VALUE; 3: return game_params::GOLD_LARGE_VALUE;
        4: return game_params::ROCK_SMALL_VALUE;  5: return game_params::ROCK_MEDIUM_VALUE; 6: return game_params::ROCK_LARGE_VALUE;
        default: return 0;
    endcase
endfunction
function automatic int radius_of(input int t);
    case (t) 1, 4: return 8; 2, 5: return 16; 3, 6: return 28; default: return 0; endcase
endfunction
// sprite edges measured from ObjectsMatrixBitMap's bitmaps (cell is 64x64, centre at 32,32):
//   left_of = first opaque pixel on the centre row, as a distance left of the centre
//   top_of  = first opaque pixel from the top within +-5 px of the centre column (the claw width)
function automatic int left_of(input int t);
    case (t) 1: return 8; 2: return 15; 3: return 28; 4: return 7; 5: return 13; 6: return 25; default: return 0; endcase
endfunction
function automatic int top_of(input int t);
    case (t) 1: return 7; 2: return 13; 3: return 29; 4: return 6; 5: return 12; 6: return 25; default: return 0; endcase
endfunction
// expected pull-back speed with object t (game_params.sv, scaled by the difficulty percent)
function automatic real expected_pull(input int t);
    int px, pct;
    case (t)
        1: px = game_params::RETRACT_GOLD_SMALL_PX_PER_SEC;  2: px = game_params::RETRACT_GOLD_MEDIUM_PX_PER_SEC;
        3: px = game_params::RETRACT_GOLD_LARGE_PX_PER_SEC;  4: px = game_params::RETRACT_ROCK_SMALL_PX_PER_SEC;
        5: px = game_params::RETRACT_ROCK_MEDIUM_PX_PER_SEC; 6: px = game_params::RETRACT_ROCK_LARGE_PX_PER_SEC;
        default: px = RETRACT_EMPTY_PX_PER_SEC;
    endcase
    case (int'(game_params::DIFFICULTY))
        0: pct = game_params::PULL_SPEED_PERCENT_EASY;  2: pct = game_params::PULL_SPEED_PERCENT_HARD;
        default: pct = game_params::PULL_SPEED_PERCENT_NORMAL;
    endcase
    return (t >= 1 && t <= 6) ? real'(px) * pct / 100.0 : real'(px);
endfunction
// pull the hook back while measuring its speed over 20 frames; returns frames used
task automatic pull_back_measured(output int frames_used, output bit miner_still);
    int r_a, r_b, x0;
    frames_used = 0; miner_still = 1; x0 = minerX; r_a = -1; r_b = -1;
    while (hookState != 2'd0 && frames_used < 1500) begin
        game_frame(); frames_used++;
        if (minerX != x0) miner_still = 0;
        if (frames_used == 1)  r_a = hb.u_move.R_fp;   // fixed point x64 = exact
        if (frames_used == 21) r_b = hb.u_move.R_fp;
    end
    meas_pull_px_s = (r_b >= 0) ? real'(r_a - r_b) / 64.0 / 20.0 * (FRAME_RATE_X100 / 100.0) : -1.0;
endtask

function automatic int count_objects();
    int c = 0;
    for (int row = 1; row < 4; row++) for (int col = 0; col < 8; col++)
        if (gbm.MazeBitMapMask[row][col] != 0) c++;
    return c;
endfunction
// A shot straight down only reaches the TOP object of a column (it would hit that one first).
// Pick the best reachable one: gold before rock, bigger before smaller.
task automatic pick_target();
    int best, t, sc;
    best = -1; tgt_row = -1; tgt_col = -1; tgt_obj = 0;
    for (int col = 0; col < 8; col++) begin
        for (int row = 1; row < 4; row++) begin
            t = gbm.MazeBitMapMask[row][col];
            if (t != 0) begin
                sc = (t <= 3 ? 100 : 0) + radius_of(t);
                if (sc > best) begin best = sc; tgt_row = row; tgt_col = col; tgt_obj = t; end
                break;                                // lower objects of this column are hidden
            end
        end
    end
    tgt_value = value_of(tgt_obj); tgt_r = top_of(tgt_obj);   // top edge of the sprite above its centre
    tgt_cx = 64 + tgt_col*64 + 32; tgt_cy = 224 + tgt_row*64 + 32;
    $display("   target: row %0d col %0d, %s radius %0d, value %0d, centre (%0d,%0d)",
             tgt_row, tgt_col, (tgt_obj <= 3) ? "GOLD" : "ROCK", tgt_r, tgt_value, tgt_cx, tgt_cy);
endtask

// ---------------- playing ----------------
// Walk with key 4/6 until the rope origin will STOP above x = cx. The miner glides after the
// key is released (speed drops by X_ACCEL per frame), so the key is released as soon as the
// predicted stopping point reaches cx - the same thing a player learns to do.
task automatic walk_to(input int cx, output int frames_used);
    int dir, s, p, g;
    frames_used = 0;
    dir = (cx > hb.X0) ? 1 : -1;
    if ((cx - hb.X0) * dir <= 2) return;
    @(negedge clk) if (dir > 0) key6 = 1; else key4 = 1;
    while (frames_used < 1500) begin
        game_frame(); frames_used++;
        s = miner.Xspeed; p = miner.Xposition;       // predict the glide if released now
        for (int k = 0; k < 40; k++) begin
            s = s - miner.X_ACCEL * dir;
            if (s * dir <= 0) break;
            p = p + s;
        end
        if ((p / 64 + HOOK_DX - cx) * dir >= 0) break;
    end
    @(negedge clk) begin key4 = 0; key6 = 0; end
    g = 0; while (miner.Xspeed != 0 && g < 100) begin game_frame(); g++; end
    frames_used += g;
endtask
// wait until the swing passes straight down, then press 2 (a short press, 3 clocks)
task automatic shoot_when_down(output int waited);
    waited = 0;
    while (int'(hb.u_move.angle_idx) != RIGHT_DEG_IDX && waited < 600) begin game_frame(); waited++; end
    @(negedge clk) key2 = 1; repeat (3) @(negedge clk); key2 = 0;
    @(negedge clk);
endtask

game_params::difficulty_t diff_now = game_params::DIFFICULTY;   // copy: enum name for the Transcript
int  f, w, x_before, x_at_shot, r_peak, score_before, r_a2, r_b2, mask_copy [1:3][0:7];
bit  x_constant, x_still, others_same, r_down;

initial begin
    $display("\n##### tb_game_integration VERSION 8.11 (2026-10-25, B10: game_hud keeps decimal digits only) - if not the version Claude announced, run the full  do run_game_integration.do  #####");
    $display("   hook_params: swing %0d deg/s (%0d..%0d deg), shoot %0d px/s, empty pull-back %0d px/s",
             SWING_DEG_PER_SEC, SWING_MIN_DEG, SWING_MAX_DEG, SHOOT_PX_PER_SEC, RETRACT_EMPTY_PX_PER_SEC);
    $display("   game_params: difficulty %s, level 1 target %0h (+%0h per level), %0d s per level", diff_now.name(),
             hud.targetStart, hud.targetStep, game_params::DEFAULT_SECONDS);   // decimal digits: %h shows them
    repeat (3) @(negedge clk); resetN = 1;
    repeat (5) @(negedge clk);

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 start of the game");
    frames(3);
    check(minerX == 280 && minerY == 100, $sformatf("miner at (280,100): (%0d,%0d)", minerX, minerY));
    check(hb.X0 == 312 && hb.Y0 == 164, $sformatf("rope starts under the miner at (312,164): (%0d,%0d)", hb.X0, hb.Y0));
    check(hookState == 2'd0 && !hookBusy && hb.R == MIN_R, "hook swinging, R = MIN_R, hookBusy = 0");
    check(score == 0 && count_objects() == 8, $sformatf("score 0, %0d objects in the gold field (expected 8)", count_objects()));
    for (int row = 1; row < 4; row++) for (int col = 0; col < 8; col++)
        if (gbm.MazeBitMapMask[row][col] != 0)
            $display("   object row %0d col %0d : type %0d (%s, value %0d)", row, col, gbm.MazeBitMapMask[row][col],
                     (gbm.MazeBitMapMask[row][col] <= 3) ? "gold" : "rock", value_of(gbm.MazeBitMapMask[row][col]));
    snapshot("frames/game_1_start.bmp");

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 walking + no shot while moving");
    hook_followed = 1;
    @(negedge clk) key6 = 1;
    frames(20);
    check(minerMoving && minerX > 280, $sformatf("key 6: miner walks right (x %0d), minerMoving = 1", minerX));
    check(dust.dustOn && dust.dustOnLeftSide, $sformatf("key 6: dust is on, on the LEFT of the cart (picture %0d)", int'(dust.pictureNum) + 1));
    @(negedge clk) key2 = 1;                      // try to shoot while walking
    frames(10);
    check(hookState == 2'd0, "key 2 pressed while walking -> NO shot");
    @(negedge clk) key6 = 0;                      // stop walking, key 2 still held
    frames(10);
    check(hookState == 2'd0, "stopped walking but key 2 is an OLD press -> still no shot");
    @(negedge clk) key2 = 0;
    w = 0; while (miner.Xspeed != 0 && w < 100) begin game_frame(); w++; end
    check(hook_followed, "every frame: rope origin = miner + (32,64) (the hook walks with the miner)");
    w = 0; while (dust.dustOn && w < 60) begin game_frame(); w++; end
    check(!dust.dustOn, $sformatf("keys released: dust finished its round and disappeared (%0d more frames, max 36)", w));

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 walk above a target");
    pick_target();
    check(tgt_obj != 0, $sformatf("reachable target found: row %0d col %0d value %0d", tgt_row, tgt_col, tgt_value));
    walk_to(tgt_cx, f);
    $display("   walked %0d frames, rope origin now x = %0d (target centre %0d)", f, hb.X0, tgt_cx);
    check((hb.X0 - tgt_cx) <= 4 && (tgt_cx - hb.X0) <= 4,
          $sformatf("miner stopped with the rope above the target: x %0d vs %0d (+-4)", hb.X0, tgt_cx));
    check(hook_followed && hookState == 2'd0, "hook followed the miner and kept swinging during the walk");

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 aim by timing + shoot = catch");
    mask_copy = '{default:0};
    for (int row = 1; row < 4; row++) for (int col = 0; col < 8; col++) mask_copy[row][col] = gbm.MazeBitMapMask[row][col];
    n_hookCatch = 0; n_collect = 0; n_deliver = 0; score_before = score; snd_n = 0;
    shoot_when_down(w);
    check(hookState == 2'd1 && hookBusy, $sformatf("waited %0d frames for 90 deg, key 2 -> SHOOT at %0d deg, hookBusy = 1", w, angle_deg));
    snapshot("frames/game_2_shot.bmp");

    // ------------------------------------------------------------ T5 (runs during the shot)
    begin_test(5, "T5 miner locked while hook is out");
    @(negedge clk) key4 = 1;                      // try to walk left during the whole shot
    x_at_shot = minerX; x_constant = 1; r_peak = 0;
    f = 0; while (hookState == 2'd1 && f < 400) begin
        game_frame(); f++;
        if (minerX != x_at_shot) x_constant = 0;
        if (hb.R > r_peak) r_peak = hb.R;
    end
    check(n_hookCatch > 0 && hookState == 2'd2,
          $sformatf("claw reached the object after %0d frames -> hookCatch (%0d pulse(s)) -> RETRACT", f, n_hookCatch));
    check(hb.Yend < tgt_cy && hb.Yend > tgt_cy - tgt_r - 16,
          $sformatf("claw stopped AT the object: tip y %0d, object top y %0d", hb.Yend, tgt_cy - tgt_r));
    repeat (10) @(negedge clk);
    check(gbm.MazeBitMapMask[tgt_row][tgt_col] == 0, "the caught object is gone from the gold field");
    others_same = 1;
    for (int row = 1; row < 4; row++) for (int col = 0; col < 8; col++)
        if (!(row == tgt_row && col == tgt_col) && gbm.MazeBitMapMask[row][col] != mask_copy[row][col]) others_same = 0;
    check(others_same, "all other objects are unchanged");
    check(n_collect == 1 && last_value == tgt_value,
          $sformatf("ONE collectPulse, value %0d (expected %0d)", last_value, tgt_value));
    check(score == score_before && n_deliver == 0,
          $sformatf("score NOT changed at the catch (still %0d, no deliverPulse) - it is added at the top", score));
    check(type_at_collect == tgt_obj && hb.caughtType == tgt_obj,
          $sformatf("gold field reported type %0d, hook latched type %0d (expected %0d)", type_at_collect, hb.caughtType, tgt_obj));
    carry_reset();
    snapshot("frames/game_3_caught.bmp");
    check(n_carry_px > 0 && n_carry_seen == n_carry_px,
          $sformatf("the caught object is drawn in the claw: %0d pixels, %0d of them on the screen (RGBOut)", n_carry_px, n_carry_seen));
    // (the bottom may be cut by the screen edge for a low large object, so the TOP edge is checked)
    check(n_carry_px > 0 && (carry_x0 + carry_x1) / 2 - hb.Xend <= 3 && hb.Xend - (carry_x0 + carry_x1) / 2 <= 3 &&
          carry_y0 - (hb.Yend + carry_top(tgt_obj)) <= 1 && (hb.Yend + carry_top(tgt_obj)) - carry_y0 <= 1,
          $sformatf("object hangs straight down in the claw: x centre %0d (claw %0d +-3), top y %0d (expected %0d = tip + %0d)",
                    (carry_x0 + carry_x1) / 2, hb.Xend, carry_y0, hb.Yend + carry_top(tgt_obj), carry_top(tgt_obj)));
    exp_pull_px_s = expected_pull(tgt_obj);
    pull_back_measured(f, x_still);
    if (!x_still || minerX != x_at_shot) x_constant = 0;
    check(meas_pull_px_s > 0.97*exp_pull_px_s && meas_pull_px_s < 1.03*exp_pull_px_s,
          $sformatf("pull-back with %s: %0.1f px/s (game_params: %0.1f px/s +-3%%)",
                    (tgt_obj <= 3) ? "gold" : "rock", meas_pull_px_s, exp_pull_px_s));
    check(x_constant, $sformatf("key 4 held during SHOOT + RETRACT: miner did not move (x stayed %0d)", x_at_shot));
    check(n_dust_start_busy == 0, $sformatf("key 4 held while the hook was out: NO dust round started (%0d)", n_dust_start_busy));
    check(hookState == 2'd0 && !hookBusy && hb.R == MIN_R, $sformatf("hook back after %0d frames: SWING, R = %0d, hookBusy = 0", f, hb.R));
    repeat (5) @(negedge clk);
    check(n_deliver == 1 && last_deliver == tgt_value && score == score_before + tgt_value,
          $sformatf("hook at the top: ONE deliverPulse, value %0d -> score %0d -> %0d on the HUD", last_deliver, score_before, score));
    check(snd_n == 2 && snd_log[0] == int'(game_params::SND_CATCH) && snd_log[1] == int'(game_params::SND_MONEY),
          $sformatf("sounds of this catch: %0d started - first %0d (CATCH = 1), then %0d (MONEY = 2)", snd_n, snd_log[0], snd_log[1]));

    // ------------------------------------------------------------ T6
    begin_test(6, "T6 miner free again");
    x_before = minerX;
    frames(30);                                   // key 4 is STILL held
    check(minerX < x_before - 5, $sformatf("same held key 4 now walks left: x %0d -> %0d", x_before, minerX));
    check(dust.dustOn && !dust.dustOnLeftSide, "walking left: dust is back, on the RIGHT of the cart");
    @(negedge clk) key4 = 0;
    w = 0; while (miner.Xspeed != 0 && w < 100) begin game_frame(); w++; end
    snapshot("frames/game_4_after.bmp");

    // ------------------------------------------------------------ T7
    begin_test(7, "T7 second catch, key 2 ignored when busy");
    pick_target();
    walk_to(tgt_cx, f);
    check((hb.X0 - tgt_cx) <= 4 && (tgt_cx - hb.X0) <= 4,
          $sformatf("walked %0d frames, rope above target 2: x %0d vs %0d", f, hb.X0, tgt_cx));
    n_hookCatch = 0; n_collect = 0; n_deliver = 0; score_before = score;
    shoot_when_down(w);
    f = 0; while (hookState == 2'd1 && f < 400) begin game_frame(); f++; end
    repeat (10) @(negedge clk);
    check(n_collect == 1 && last_value == tgt_value && score == score_before && n_deliver == 0,
          $sformatf("second catch: value %0d, score still %0d until the hook is home", last_value, score));
    exp_pull_px_s = expected_pull(tgt_obj);
    r_a2 = hb.u_move.R_fp; frames(10); r_b2 = hb.u_move.R_fp;
    meas_pull_px_s = real'(r_a2 - r_b2) / 64.0 / 10.0 * (FRAME_RATE_X100 / 100.0);
    check(meas_pull_px_s > 0.97*exp_pull_px_s && meas_pull_px_s < 1.03*exp_pull_px_s,
          $sformatf("second pull-back with %s: %0.1f px/s (game_params: %0.1f px/s +-3%%)",
                    (tgt_obj <= 3) ? "gold" : "rock", meas_pull_px_s, exp_pull_px_s));
    frames(5);
    r_peak = hb.R;
    @(negedge clk) key2 = 1; repeat (3) @(negedge clk); key2 = 0;   // fresh press during the pull-back
    frames(3);
    check(hookState == 2'd2 && hb.R < r_peak, $sformatf("key 2 during RETRACT ignored: still RETRACT, R %0d -> %0d", r_peak, hb.R));
    snapshot("frames/game_5_second.bmp");
    f = 0; while (hookState != 2'd0 && f < 1500) begin game_frame(); f++; end
    check(hookState == 2'd0 && count_objects() == 6, $sformatf("hook back, %0d objects left (expected 6)", count_objects()));
    repeat (5) @(negedge clk);
    check(n_deliver == 1 && last_deliver == tgt_value && score == score_before + tgt_value,
          $sformatf("second object at the top: ONE deliverPulse -> score %0d -> %0d (+%0d)", score_before, score, tgt_value));
    snapshot("frames/game_6_end.bmp");

    // ------------------------------------------------------------ T8
    begin_test(8, "T8 no dust against the wall");
    @(negedge clk) key6 = 1;
    f = 0; x_before = -1;
    while (minerX != x_before && f < 1500) begin x_before = minerX; frames(5); f += 5; end
    check(minerX == 573, $sformatf("key 6 held: miner reached the right border x = 573 after %0d frames (x %0d)", f, minerX));
    w = 0; while (dust.dustOn && w < 60) begin game_frame(); w++; end
    check(!dust.dustOn && !dustRightKey, $sformatf("key 6 STILL held at the wall: dust finished its round and stopped (%0d frames)", w));
    frames(20);
    check(!dust.dustOn, "20 more frames against the wall: still no dust");
    @(negedge clk) key6 = 0;

    // ------------------------------------------------------------ T9 (Step 10)
    begin_test(9, "T9 new level drops the object");
    pick_target();
    walk_to(tgt_cx, f);
    n_hookCatch = 0; n_deliver = 0;
    shoot_when_down(w);
    f = 0; while (hookState == 2'd1 && f < 400) begin game_frame(); f++; end
    frames(3);                                    // pulling the object back now
    x_before = minerX; r_peak = hb.R; score_before = score; snd_n = 0;
    @(negedge clk) keyPlus = 1; repeat (3) @(negedge clk); keyPlus = 0;   // keypad + = next level
    repeat (5) @(negedge clk);
    check(n_hookCatch > 0 && r_peak > MIN_R && hookState == 2'd0 && hb.R == MIN_R && !hb.caught && !hookBusy,
          $sformatf("keypad + while pulling back (R %0d): hook at once back at the top, empty, hookBusy 0", r_peak));
    frames(10);
    check(n_deliver == 0 && score == 0 && (hud.lvlT * 10 + hud.lvlO) == 2 && count_objects() == 8 && minerX == x_before,
          $sformatf("object LOST (no deliverPulse, score %0d -> %0d), level %0d, %0d new objects, miner stayed at x %0d (%0d)",
                    score_before, score, hud.lvlT * 10 + hud.lvlO, count_objects(), x_before, minerX));
    check(snd_n == 1 && snd_log[0] == int'(game_params::SND_LEVEL),
          $sformatf("sound: only the level fanfare (%0d sound(s), first %0d, LEVEL = 3) - no money sound for the lost object", snd_n, snd_log[0]));
    snapshot("frames/game_7_newlevel.bmp");

    // ------------------------------------------------------------ T10 (Step 10)
    begin_test(10, "T10 game over freezes everything");
    shoot_when_down(w);
    frames(5);                                    // in the middle of a shot
    mask_copy = '{default:0};
    for (int row = 1; row < 4; row++) for (int col = 0; col < 8; col++) mask_copy[row][col] = gbm.MazeBitMapMask[row][col];
    snd_n = 0;
    @(negedge clk) keyStar = 1; repeat (3) @(negedge clk); keyStar = 0;   // keypad * = game over
    repeat (3) @(negedge clk);
    r_peak = hb.R; w = hb.u_move.angle_fp; x_before = minerX; score_before = score; n_hookCatch = 0;
    @(negedge clk) key4 = 1;                      // try to walk ...
    frames(10);
    @(negedge clk) key2 = 1; repeat (3) @(negedge clk); key2 = 0;   // ... and to shoot again
    frames(30);
    check(hud.gameOver && hookState == 2'd1 && hb.R == r_peak && hb.u_move.angle_fp == w,
          $sformatf("GAME OVER: hook frozen in the middle of the shot (R stays %0d, angle unchanged, still SHOOT)", hb.R));
    check(minerX == x_before && miner.Xspeed == 0 && !dust.dustOn,
          $sformatf("key 4 held for 40 frames: miner stays at x %0d, speed 0, no dust", minerX));
    others_same = 1;
    for (int row = 1; row < 4; row++) for (int col = 0; col < 8; col++)
        if (gbm.MazeBitMapMask[row][col] != mask_copy[row][col]) others_same = 0;
    check(score == score_before && n_hookCatch == 0 && others_same,
          $sformatf("score stays %0d, no catch, gold field unchanged", score));
    check(snd_n == 1 && snd_log[0] == int'(game_params::SND_GAMEOVER),
          $sformatf("sound: the game over tune exactly once in 40 frames (%0d sound(s), first %0d, GAMEOVER = 4)", snd_n, snd_log[0]));
    snapshot("frames/game_8_gameover.bmp");
    @(negedge clk) key4 = 0;

    // ------------------------------------------------------------ end
    t_end[10] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(10);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Images: tests/frames/game_*.bmp   Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #400_000_000;
    $display("WATCHDOG: not finished after 400 ms sim time - paused here, check test_name");
    $stop;
end
endmodule
