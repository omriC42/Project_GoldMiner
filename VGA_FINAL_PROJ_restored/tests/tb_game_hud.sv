// tb_game_hud.sv - Step 12: game_hud without dividers and without functions
//
// Run:  ModelSim -> cd <project>/tests -> do run_game_hud.do        (expect VERSION 12.3)
// Checklist: tests/CHECKLIST_step12_hud.md
//
// B10 (Oct 2026): game_hud keeps every number ONLY as decimal digits (dolH dolT dolO, lvlT lvlO,
// tgtH tgtT tgtO, minD secT secO). The test turns them back into numbers (dollars_i = 100*H + 10*T + O ...)
// and checks them against its own models. This test checks:
//  * a MONITOR on every clock: every digit is a real decimal digit (0..9, tens of seconds 0..5)
//  * the PICTURE: the HUD band (and the GAME OVER band) is scanned pixel by pixel and compared with
//    the OLD drawing code (digitAt / numberAt / gameOverTextAt with / and %), copied into this file
//    as an independent reference model.
// T1 after reset: digits + picture (score 0, target, level 1, clock = default time)
// T2 score: 400 random values 1..63 -> binary = the model's sum (stops at 999), digits, 6 pictures
// T3 clock: a second HUD with the LONG time (90 s) and a 5000-clock "second": counts 90 -> 0,
//    digits every clock, 6 pictures of the clock area (1:30, 1:00, 0:59, 0:10, 0:09, 0:00)
// T4 level: keypad + 100 times -> level 1..99 (stops at 99), target digits, 5 pictures
// T5 GAME OVER: keypad * -> the GAME OVER band picture
// T6 (Step 14) settings inputs: all 9 difficulty x time choices -> start target, start time, digits
//    and picture, all from game_params.sv
// T7 (Step 14) cheatsOn = 0: keypad + and * do nothing
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_game_hud;

logic clk = 0, resetN = 0;
always #5 clk = ~clk;

logic [10:0] pixelX = 0, pixelY = 0;
logic        collectPulse = 0, gameOverKey = 0, nextLevelKey = 0;
logic  [5:0] collectValue = 0;
logic  [1:0] hDiff = 2'(game_params::DIFFICULTY), hTime = 2'(game_params::DEFAULT_TIME_SEL);   // settings (Step 14)
logic        hCheats = 1;
logic        hudDR, gameOver, levelWon, newLevel;
logic  [7:0] hudRGB;
// the game's HUD (real clock: its time does not run out in this test)
game_hud hud (.clk, .resetN, .pixelX, .pixelY, .collectPulse, .collectValue, .gameOverKey, .nextLevelKey,
              .difficulty(hDiff), .timeSel(hTime), .cheatsOn(hCheats),
              .drawingRequest(hudDR), .RGBout(hudRGB), .gameOver, .levelWon, .newLevel);
// T3: the LONG time (timeSel 2 = 90 s), 1 "second" = 5000 clocks (long enough to scan the clock area); no score / keys
logic        cDR, cGameOver, cLevelWon, cNewLevel;
logic  [7:0] cRGB;
logic        clockRun = 0;                      // its reset: held until T3
game_hud #(.CLOCK_HZ(5000)) hudC (.clk, .resetN(clockRun), .pixelX, .pixelY,
              .collectPulse(1'b0), .collectValue(6'd0), .gameOverKey(1'b0), .nextLevelKey(1'b0),
              .difficulty(2'd1), .timeSel(2'd2), .cheatsOn(1'b0),
              .drawingRequest(cDR), .RGBout(cRGB), .gameOver(cGameOver),
              .levelWon(cLevelWon), .newLevel(cNewLevel));

// ---------------- wave helpers ----------------
logic [8*32:1] test_name = "start";
int            test_no = 0;
logic [8*64:1] chk_name = "";
logic          chk_pass = 0, chk_fail = 0;
int            nPass = 0, nFail = 0;
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

// ---------------- MONITOR: every digit is a real decimal digit (every clock) ----------------
int dig_checks = 0, dig_bad = 0;
int dollars_i, level_i, target_i, secs_i, csecs_i;        // the numbers, made from the digits (int)
int ctarget_i;
assign dollars_i = hud.dolH * 100 + hud.dolT * 10 + hud.dolO;
assign level_i   = hud.lvlT * 10 + hud.lvlO;
assign target_i  = hud.tgtH * 100 + hud.tgtT * 10 + hud.tgtO;
assign secs_i    = hud.minD * 60 + hud.secT * 10 + hud.secO;
assign csecs_i   = hudC.minD * 60 + hudC.secT * 10 + hudC.secO;
assign ctarget_i = hudC.tgtH * 100 + hudC.tgtT * 10 + hudC.tgtO;
always @(posedge clk) if (resetN) begin
    dig_checks++;
    if (hud.dolH > 9 || hud.dolT > 9 || hud.dolO > 9 || hud.lvlT > 9 || hud.lvlO > 9 ||
        hud.tgtH > 9 || hud.tgtT > 9 || hud.tgtO > 9 || hud.minD > 9 || hud.secT > 5 || hud.secO > 9) begin
        if (dig_bad < 5) $display("   [%0t] DIGITS WRONG: $%0d%0d%0d  level %0d%0d  target %0d%0d%0d  time %0d:%0d%0d",
            $time, hud.dolH, hud.dolT, hud.dolO, hud.lvlT, hud.lvlO,
            hud.tgtH, hud.tgtT, hud.tgtO, hud.minD, hud.secT, hud.secO);
        dig_bad++;
    end
    if (clockRun && (hudC.minD > 9 || hudC.secT > 5 || hudC.secO > 9)) begin
        if (dig_bad < 5) $display("   [%0t] CLOCK DIGITS WRONG: %0d:%0d%0d", $time, hudC.minD, hudC.secT, hudC.secO);
        dig_bad++;
    end
end

// ---------------- REFERENCE: the OLD drawing code (with / and %), unchanged ----------------
localparam int DOLLAR_X = 56,  DOLLAR_Y = 14, TARGET_X = 56, TARGET_Y = 60;
localparam int LEVEL_X  = 522, LEVEL_Y  = 12, CLOCK_X  = 530, CLOCK_Y = 52, GO_X = 108, GO_Y = 212;
localparam int CHAR_W = 20, CHAR_H = 28, STEP = 24, BIG_W = 40, BIG_H = 56, BIG_STEP = 48, MSG_LEN = 9;
localparam logic [0:9][0:6][4:0] FONT = {
    5'b01110, 5'b10001, 5'b10011, 5'b10101, 5'b11001, 5'b10001, 5'b01110,
    5'b00100, 5'b01100, 5'b00100, 5'b00100, 5'b00100, 5'b00100, 5'b01110,
    5'b01110, 5'b10001, 5'b00001, 5'b00010, 5'b00100, 5'b01000, 5'b11111,
    5'b11111, 5'b00010, 5'b00100, 5'b00010, 5'b00001, 5'b10001, 5'b01110,
    5'b00010, 5'b00110, 5'b01010, 5'b10010, 5'b11111, 5'b00010, 5'b00010,
    5'b11111, 5'b10000, 5'b11110, 5'b00001, 5'b00001, 5'b10001, 5'b01110,
    5'b00110, 5'b01000, 5'b10000, 5'b11110, 5'b10001, 5'b10001, 5'b01110,
    5'b11111, 5'b00001, 5'b00010, 5'b00100, 5'b01000, 5'b01000, 5'b01000,
    5'b01110, 5'b10001, 5'b10001, 5'b01110, 5'b10001, 5'b10001, 5'b01110,
    5'b01110, 5'b10001, 5'b10001, 5'b01111, 5'b00001, 5'b00010, 5'b01100 };
localparam logic [0:6][0:6][4:0] LETTERS = {
    5'b01110, 5'b10001, 5'b10000, 5'b10111, 5'b10001, 5'b10001, 5'b01111,
    5'b01110, 5'b10001, 5'b10001, 5'b11111, 5'b10001, 5'b10001, 5'b10001,
    5'b10001, 5'b11011, 5'b10101, 5'b10101, 5'b10001, 5'b10001, 5'b10001,
    5'b11111, 5'b10000, 5'b10000, 5'b11110, 5'b10000, 5'b10000, 5'b11111,
    5'b01110, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01110,
    5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b10001, 5'b01010, 5'b00100,
    5'b11110, 5'b10001, 5'b10001, 5'b11110, 5'b10100, 5'b10010, 5'b10001 };
localparam logic [0:MSG_LEN-1][2:0] MESSAGE = {3'd0, 3'd1, 3'd2, 3'd3, 3'd7, 3'd4, 3'd5, 3'd3, 3'd6};
function automatic bit digitAt(int x, int y, int X, int Y, int d);
    if ((x >= X) && (x < X + CHAR_W) && (y >= Y) && (y < Y + CHAR_H)) return FONT[d][(y - Y) >> 2][4 - ((x - X) >> 2)];
    return 0;
endfunction
function automatic bit numberAt(int x, int y, int X, int Y, int n);
    int h, t, o;
    h = n / 100; t = (n / 10) % 10; o = n % 10;
    if (n >= 100)     return digitAt(x, y, X, Y, h) || digitAt(x, y, X + STEP, Y, t) || digitAt(x, y, X + 2*STEP, Y, o);
    else if (n >= 10) return digitAt(x, y, X, Y, t) || digitAt(x, y, X + STEP, Y, o);
    else              return digitAt(x, y, X, Y, o);
endfunction
function automatic bit gameOverTextAt(int x, int y);
    bit hit; int X;
    hit = 0;
    if ((y >= GO_Y) && (y < GO_Y + BIG_H))
        for (int i = 0; i < MSG_LEN; i++) begin
            X = GO_X + i * BIG_STEP;
            if ((x >= X) && (x < X + BIG_W) && (MESSAGE[i] != 3'd7)) hit = LETTERS[MESSAGE[i]][(y - GO_Y) >> 3][4 - ((x - X) >> 3)];
        end
    return hit;
endfunction
// the old picture for these values -> 8'hE0 (red text) or 8'hFF (transparent)
function automatic logic [7:0] old_hud(int x, int y, int dol, int tgt, int lvl, int secs, bit go);
    int m, s;
    bit on;
    m = (secs >= 60) ? 1 : 0;  s = (secs >= 60) ? secs - 60 : secs;
    on = digitAt(x, y, CLOCK_X, CLOCK_Y, m) || digitAt(x, y, CLOCK_X + CHAR_W + 16, CLOCK_Y, s / 10)
      || digitAt(x, y, CLOCK_X + CHAR_W + 16 + STEP, CLOCK_Y, s % 10)
      || ((x >= CLOCK_X + CHAR_W + 6) && (x < CLOCK_X + CHAR_W + 10) &&
          (((y >= CLOCK_Y + 4) && (y < CLOCK_Y + 12)) || ((y >= CLOCK_Y + 16) && (y < CLOCK_Y + 24))))
      || numberAt(x, y, DOLLAR_X, DOLLAR_Y, dol) || numberAt(x, y, TARGET_X, TARGET_Y, tgt)
      || numberAt(x, y, LEVEL_X, LEVEL_Y, lvl) || (go && gameOverTextAt(x, y));
    return on ? 8'hE0 : 8'hFF;
endfunction

// ---------------- picture compare: rows y0..y1, all 640 columns (RGBout = 1 clock after its pixel) ----------------
int pix_bad = 0, pix_red = 0;
task automatic compare_band(input bit which_c, input int y0, input int y1, input int dol, input int tgt,
                            input int lvl, input int secs, input bit go);
    compare_region(which_c, 0, 639, y0, y1, dol, tgt, lvl, secs, go);
endtask
task automatic compare_region(input bit which_c, input int x0, input int x1, input int y0, input int y1,
                              input int dol, input int tgt, input int lvl, input int secs, input bit go);
    int px, py, total, w; logic [7:0] got, expv;
    w = x1 - x0 + 1; px = -1; py = 0; total = w * (y1 - y0 + 1);
    for (int n = 0; n <= total; n++) begin
        @(negedge clk);
        if (px >= 0) begin
            got  = which_c ? cRGB : hudRGB;
            expv = old_hud(px, py, dol, tgt, lvl, secs, go);
            if (got !== expv) begin
                if (pix_bad < 5) $display("   pixel (%0d,%0d): got %h, old code %h", px, py, got, expv);
                pix_bad++;
            end
            if (got == 8'hE0) pix_red++;
        end
        if (n < total) begin px = x0 + n % w; py = y0 + n / w; pixelX = px; pixelY = py; end
        else px = -1;
    end
endtask
// the game's HUD as it is now, top band (y 0..95)
task automatic picture_now(output int bad, output int red);
    pix_bad = 0; pix_red = 0;
    compare_band(0, 0, 95, dollars_i, target_i, level_i, secs_i, hud.gameOver);
    bad = pix_bad; red = pix_red;
endtask

// ---------------- stimulus helpers ----------------
task automatic collect(input int v);
    @(negedge clk) begin collectPulse = 1; collectValue = 6'(v); end
    @(negedge clk) begin collectPulse = 0; collectValue = 0; end
endtask
task automatic press_plus();
    @(negedge clk) nextLevelKey = 1; repeat (2) @(negedge clk); nextLevelKey = 0; repeat (2) @(negedge clk);
endtask

int  bad, red, model, v, pics, pics_bad, red_total, bin_bad, seed, c, sat_seen;
int  pic_at [0:5];
int  vals_bad, exp_t, exp_s, n_nl = 0;
always @(posedge clk) if (newLevel) n_nl++;

initial begin
    $display("\n##### tb_game_hud VERSION 12.3 (2026-10-25, B10: game_hud keeps decimal digits only) - if not the version Claude announced, run the full  do run_game_hud.do  #####");
    repeat (3) @(negedge clk);
    resetN = 1;
    repeat (5) @(negedge clk);

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 after reset");
    picture_now(bad, red);
    check(dig_bad == 0 && hud.dolO == 0 && hud.lvlO == 1 && hud.minD == game_params::DEFAULT_SECONDS / 60,
          $sformatf("digits after reset: $%0d%0d%0d, level %0d%0d, target %0d%0d%0d, clock %0d:%0d%0d",
                    hud.dolH, hud.dolT, hud.dolO, hud.lvlT, hud.lvlO, hud.tgtH, hud.tgtT, hud.tgtO, hud.minD, hud.secT, hud.secO));
    check(bad == 0 && red > 0, $sformatf("HUD band = the old drawing code: %0d mismatches, %0d red pixels", bad, red));

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 score: 400 values");
    model = 0; bin_bad = 0; pics = 0; pics_bad = 0; red_total = 0; sat_seen = 0; seed = 12;
    pic_at = '{0, 1, 7, 20, 150, 399};               // $9 (1 digit), $19 (2), $100 (3), then 999
    for (int i = 0; i < 400; i++) begin
        v = 1 + ($urandom(seed + i) % 63);            // 1..63
        if (i < 10) v = 9 + i;                        // the first ones cross the tens: 9, 10, 11 ...
        collect(v);
        model = (model + v > 999) ? 999 : model + v;
        if (model == 999) sat_seen++;
        @(negedge clk);
        if (dollars_i != model) begin
            if (bin_bad < 3) $display("   after +%0d: dollars %0d, model %0d", v, dollars_i, model);
            bin_bad++;
        end
        for (int k = 0; k < 6; k++) if (pic_at[k] == i) begin
            picture_now(bad, red); pics++; if (bad != 0) pics_bad++; red_total += red;
            $display("   picture at $%0d: %0d mismatches", dollars_i, bad);
        end
    end
    check(bin_bad == 0 && sat_seen > 0, $sformatf("400 values: dollars = the model's sum every time (%0d wrong), reached and kept 999 (%0d times)", bin_bad, sat_seen));
    check(dig_bad == 0, $sformatf("all digits are real decimal digits on all %0d clocks so far (%0d wrong)", dig_checks, dig_bad));
    check(pics_bad == 0, $sformatf("%0d pictures of the score (1, 2 and 3 digits, 999) = the old drawing code (%0d with mismatches)", pics, pics_bad));

    // ------------------------------------------------------------ T3
    begin_test(3, "T3 clock 90 -> 0");
    @(negedge clk) clockRun = 1;                      // the 90-second HUD starts now
    pics = 0; pics_bad = 0; c = 0; v = -1;
    // the clock area (x 520..639, y 48..84 = 4440 pixels) is scanned right after the chosen seconds
    // start, so the scan ends before the next second (5000 clocks)
    while (c < 700000) begin
        @(negedge clk); c++;
        if (csecs_i != v) begin
            v = csecs_i;
            if (v inside {90, 60, 59, 10, 9, 0}) begin
                pix_bad = 0; pix_red = 0;
                compare_region(1, 520, 639, 48, 84, 0, ctarget_i, 1, v, 1'b0);
                pics++; if (pix_bad != 0) pics_bad++;
                $display("   clock picture at %0d s (%0d:%0d%0d): %0d mismatches, %0d red px", v, hudC.minD, hudC.secT, hudC.secO, pix_bad, pix_red);
            end
            if (v == 0) break;
        end
    end
    check(csecs_i == 0 && hudC.minD == 0 && hudC.secT == 0 && hudC.secO == 0 && dig_bad == 0,
          $sformatf("90 s (LONG) counted down to 0:00 in %0d clocks, digits right on every clock (%0d wrong)", c, dig_bad));
    check(pics == 6 && pics_bad == 0, $sformatf("%0d clock pictures (1:30 ... 0:00) = the old drawing code (%0d with mismatches)", pics, pics_bad));

    // ------------------------------------------------------------ T4
    begin_test(4, "T4 level 1 -> 99");
    pics = 0; pics_bad = 0;
    for (int l = 2; l <= 101; l++) begin
        press_plus();
        if (l inside {2, 9, 10, 11, 42, 99, 101}) begin
            picture_now(bad, red); pics++; if (bad != 0) pics_bad++;
            $display("   picture at level %0d (target %0d): %0d mismatches", level_i, target_i, bad);
        end
    end
    check(level_i == 99 && hud.lvlT == 9 && hud.lvlO == 9 && dig_bad == 0,
          $sformatf("+ pressed 100 times: level %0d (stops at 99), digits %0d%0d, target %0d = %0d%0d%0d, all digits right (%0d wrong)",
                    level_i, hud.lvlT, hud.lvlO, target_i, hud.tgtH, hud.tgtT, hud.tgtO, dig_bad));
    check(pics_bad == 0, $sformatf("%0d pictures of level + target = the old drawing code (%0d with mismatches)", pics, pics_bad));

    // ------------------------------------------------------------ T5
    begin_test(5, "T5 GAME OVER text");
    @(negedge clk) gameOverKey = 1; @(negedge clk) gameOverKey = 0;
    repeat (3) @(negedge clk);
    pix_bad = 0; pix_red = 0;
    compare_band(0, GO_Y - 2, GO_Y + BIG_H + 1, dollars_i, target_i, level_i, secs_i, 1'b1);
    check(hud.gameOver && pix_bad == 0 && pix_red > 0,
          $sformatf("GAME OVER band = the old drawing code: %0d mismatches, %0d red pixels", pix_bad, pix_red));

    // ------------------------------------------------------------ T6
    begin_test(6, "T6 settings: 3 difficulties x 3 times");
    vals_bad = 0; pics = 0; pics_bad = 0;
    for (int d = 0; d < 3; d++) for (int t = 0; t < 3; t++) begin
        @(negedge clk) begin resetN = 0; hDiff = 2'(d); hTime = 2'(t); end      // like the start screen: game in reset
        repeat (3) @(negedge clk);
        resetN = 1;
        repeat (3) @(negedge clk);
        exp_t = (d == 0) ? game_params::TARGET_START_EASY : (d == 2) ? game_params::TARGET_START_HARD : game_params::TARGET_START_NORMAL;
        exp_s = (t == 0) ? game_params::LEVEL_TIME_SHORT  : (t == 2) ? game_params::LEVEL_TIME_LONG   : game_params::LEVEL_TIME_NORMAL;
        if (target_i != exp_t || secs_i != exp_s || level_i != 1 || dollars_i != 0) begin
            vals_bad++; $display("   d %0d t %0d: target %0d (exp %0d), seconds %0d (exp %0d)", d, t, target_i, exp_t, secs_i, exp_s);
        end
        picture_now(bad, red); pics++; if (bad != 0) pics_bad++;
        $display("   difficulty %0d, time %0d: target %0d, clock %0d:%0d%0d, picture %0d mismatches", d, t, target_i, hud.minD, hud.secT, hud.secO, bad);
    end
    check(vals_bad == 0 && dig_bad == 0, $sformatf("all 9 choices: start target and time from game_params, digits right (%0d wrong values, %0d wrong digits)", vals_bad, dig_bad));
    check(pics_bad == 0, $sformatf("%0d pictures of the start values = the old drawing code (%0d with mismatches)", pics, pics_bad));

    // ------------------------------------------------------------ T7
    begin_test(7, "T7 cheats OFF");
    @(negedge clk) begin resetN = 0; hDiff = 2'(game_params::DIFFICULTY); hTime = 2'(game_params::DEFAULT_TIME_SEL); hCheats = 0; end
    repeat (3) @(negedge clk);
    resetN = 1;
    repeat (3) @(negedge clk);
    n_nl = 0;
    press_plus(); press_plus();
    @(negedge clk) gameOverKey = 1; @(negedge clk) gameOverKey = 0;
    repeat (5) @(negedge clk);
    check(level_i == 1 && n_nl == 0 && !hud.gameOver, $sformatf("cheatsOn = 0: + twice and * -> level %0d, %0d newLevel, gameOver %0d (all unchanged)", level_i, n_nl, hud.gameOver));
    @(negedge clk) hCheats = 1;

    // ------------------------------------------------------------ end
    t_end[7] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(7);
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
