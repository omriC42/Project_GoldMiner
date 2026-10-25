// tb_game_hud_equiv.sv - B10: the NEW game_hud (decimal digits only) must behave EXACTLY like the
// OLD one (binary + digits, Step 14 version, kept in tests/ref/game_hud_old.sv as module game_hud_old).
//
// Run:  ModelSim -> cd <project>/tests -> do run_game_hud_equiv.do      (expect VERSION 1.1)
// Checklist: tests/CHECKLIST_b10_hud.md
//
// Both HUDs get the SAME inputs on every clock, chosen at random (fixed seed, so every run is the same):
//   * many short games: reset, random difficulty / time / cheats, then random play
//   * collectPulse with random values 0..63 (also big ones, so the score reaches 999)
//   * keypad + (next level) presses: levels go up to 99 and targets up to 999
//   * keypad * (game over), sometimes; the time also runs out (CLOCK_HZ is tiny: 1 "second" = 7 clocks)
//   * the settings inputs sometimes change in the middle of a game
//   * pixelX / pixelY random, mostly over the HUD band and the GAME OVER band
// On EVERY clock all outputs are compared (RGBout, drawingRequest, gameOver, levelWon, newLevel) and
// also the digits inside (dollars, target, level, clock). Any difference = a FAIL line with the clock.
// T1 the comparison run (NCLK clocks)
// T2 coverage: the run really reached the interesting cases (999 dollars, 999 target, level 99,
//    game over by time, game over by *, level won by time, all 9 settings, levelWon high, pixels on text)
// Conventions: never exits ($stop), GUI waves, chk pulses, version banner, zt <n>, bounded loops,
// stimulus on the falling edge.

`timescale 1ns/1ps
module tb_game_hud_equiv;

localparam int CLK_HZ = 7;            // 1 "second" of the HUD clock = 7 clocks (90 s = 630 clocks)
localparam int NCLK   = 400_000;      // clocks compared in T1 (about 130 games)

logic clk = 0, resetN = 0;
always #5 clk = ~clk;

logic [10:0] pixelX = 0, pixelY = 0;
logic        collectPulse = 0, gameOverKey = 0, nextLevelKey = 0, cheatsOn = 1;
logic  [5:0] collectValue = 0;
logic  [1:0] difficulty = 1, timeSel = 1;

logic        oDR, oGameOver, oLevelWon, oNewLevel;  logic [7:0] oRGB;   // OLD
logic        nDR, nGameOver, nLevelWon, nNewLevel;  logic [7:0] nRGB;   // NEW

game_hud_old #(.CLOCK_HZ(CLK_HZ)) old_hud (.clk, .resetN, .pixelX, .pixelY, .collectPulse, .collectValue,
    .gameOverKey, .nextLevelKey, .difficulty, .timeSel, .cheatsOn,
    .drawingRequest(oDR), .RGBout(oRGB), .gameOver(oGameOver), .levelWon(oLevelWon), .newLevel(oNewLevel));
game_hud     #(.CLOCK_HZ(CLK_HZ)) new_hud (.clk, .resetN, .pixelX, .pixelY, .collectPulse, .collectValue,
    .gameOverKey, .nextLevelKey, .difficulty, .timeSel, .cheatsOn,
    .drawingRequest(nDR), .RGBout(nRGB), .gameOver(nGameOver), .levelWon(nLevelWon), .newLevel(nNewLevel));

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

// ---------------- the numbers of both HUDs as plain integers (for the waves and the coverage) ----------------
int oDol, oTgt, oLvl, oSec, nDol, nTgt, nLvl, nSec;
assign oDol = old_hud.dollars;   assign oTgt = old_hud.target;   assign oLvl = old_hud.level;
assign oSec = old_hud.secondsLeft;
assign nDol = new_hud.dolH * 100 + new_hud.dolT * 10 + new_hud.dolO;
assign nTgt = new_hud.tgtH * 100 + new_hud.tgtT * 10 + new_hud.tgtO;
assign nLvl = new_hud.lvlT * 10 + new_hud.lvlO;
assign nSec = new_hud.minD * 60 + new_hud.secT * 10 + new_hud.secO;

// ---------------- the comparison, on every clock ----------------
logic        comparing = 0;
int          compared = 0, diffs = 0;
logic        diff_now = 0;                     // 1 on a clock with a difference (red in the waves)
always @(posedge clk) begin
    #1;                                        // after the registers of both HUDs have changed
    diff_now = 0;
    if (comparing) begin
        compared++;
        if (oRGB !== nRGB || oDR !== nDR || oGameOver !== nGameOver || oLevelWon !== nLevelWon ||
            oNewLevel !== nNewLevel || oDol != nDol || oTgt != nTgt || oLvl != nLvl || oSec != nSec ||
            old_hud.dolH !== new_hud.dolH || old_hud.dolT !== new_hud.dolT || old_hud.dolO !== new_hud.dolO ||
            old_hud.tgtH !== new_hud.tgtH || old_hud.tgtT !== new_hud.tgtT || old_hud.tgtO !== new_hud.tgtO ||
            old_hud.lvlT !== new_hud.lvlT || old_hud.lvlO !== new_hud.lvlO ||
            old_hud.minD !== new_hud.minD || old_hud.secT !== new_hud.secT || old_hud.secO !== new_hud.secO) begin
            diff_now = 1;
            if (diffs < 10)
                $display("   [%0t] DIFFERENT: RGB %h/%h DR %b/%b over %b/%b won %b/%b newLvl %b/%b | $ %0d/%0d target %0d/%0d level %0d/%0d sec %0d/%0d | pixel (%0d,%0d)  (old/new)",
                         $time, oRGB, nRGB, oDR, nDR, oGameOver, nGameOver, oLevelWon, nLevelWon, oNewLevel, nNewLevel,
                         oDol, nDol, oTgt, nTgt, oLvl, nLvl, oSec, nSec, pixelX, pixelY);
            diffs++;
        end
    end
end

// ---------------- coverage counters (did the random run reach the interesting cases?) ----------------
int cov_dol999 = 0, cov_tgt999 = 0, cov_lvl99 = 0, cov_over_time = 0, cov_over_key = 0;
int cov_won_time = 0, cov_won_key = 0, cov_levelWon = 0, cov_red = 0, cov_games = 0;
int cov_set [0:2][0:2];
initial for (int d = 0; d < 3; d++) for (int t = 0; t < 3; t++) cov_set[d][t] = 0;
logic oGameOver_d = 0;
logic cheat_at_edge = 0;                      // was keypad + the reason of this newLevel?
always @(posedge clk) cheat_at_edge <= old_hud.cheatNextLevel;
always @(posedge clk) begin
    #2;
    if (comparing) begin
        if (oDol == 999) cov_dol999++;
        if (oTgt == 999) cov_tgt999++;
        if (oLvl == 99)  cov_lvl99++;
        if (oLevelWon)   cov_levelWon++;
        if (oRGB == 8'hE0) cov_red++;
        if (oGameOver && !oGameOver_d) begin
            if (oSec == 0) cov_over_time++; else cov_over_key++;
        end
        if (oNewLevel) begin
            if (cheat_at_edge) cov_won_key++; else cov_won_time++;
        end
    end
    oGameOver_d = oGameOver;
end

// ---------------- random stimulus ----------------
int seed = 20261025;
int rnd;
task automatic new_game();
    int d, t;
    @(negedge clk) resetN = 0;
    d = $urandom_range(2, 0); t = $urandom_range(2, 0);
    difficulty = 2'(d); timeSel = 2'(t); cheatsOn = ($urandom_range(9, 0) != 0);   // cheats on 90% of games
    cov_set[d][t]++;
    cov_games++;
    repeat (2) @(negedge clk);
    resetN = 1;
endtask

initial begin
    $display("\n##### tb_game_hud_equiv VERSION 1.1 (2026-10-25, B10: new game_hud = old game_hud, clock by clock - 400k clocks) - if not the version Claude announced, run the full  do run_game_hud_equiv.do  #####");
    void'($urandom(seed));
    repeat (3) @(negedge clk);

    // ------------------------------------------------------------ T1
    begin_test(1, "T1 old vs new, random play");
    new_game();
    comparing = 1;
    for (int n = 0; n < NCLK; n++) begin
        @(negedge clk);
        // a new game now and then (also in the middle of a level)
        if ($urandom_range(19999, 0) == 0 || (oGameOver && $urandom_range(299, 0) == 0)) new_game();
        // the settings change in the middle of a game, rarely (they are inputs of the HUD)
        if ($urandom_range(9999, 0) == 0) begin difficulty = 2'($urandom_range(2, 0)); timeSel = 2'($urandom_range(2, 0)); end
        // catches: random value 0..63, sometimes many big ones (score to 999)
        collectPulse = ($urandom_range(39, 0) == 0) || (oLvl > 40 && $urandom_range(3, 0) == 0);
        collectValue = 6'($urandom_range(63, 0));
        // keypad +: held for 1..4 clocks now and then -> next level (more often when cheats are on)
        if (nextLevelKey) nextLevelKey = ($urandom_range(2, 0) != 0);
        else              nextLevelKey = ($urandom_range(59, 0) == 0);
        // keypad *: rarely
        gameOverKey = ($urandom_range(19999, 0) == 0);
        // pixels: mostly on the HUD band and the GAME OVER band, sometimes anywhere (also off-screen)
        rnd = $urandom_range(9, 0);
        if (rnd < 6)      begin pixelX = 11'($urandom_range(639, 0)); pixelY = 11'($urandom_range(95, 0));  end
        else if (rnd < 8) begin pixelX = 11'($urandom_range(639, 0)); pixelY = 11'($urandom_range(275, 205)); end
        else              begin pixelX = 11'($urandom_range(2047, 0)); pixelY = 11'($urandom_range(2047, 0)); end
    end
    comparing = 0;
    check(diffs == 0, $sformatf("%0d clocks, %0d games: old and new game_hud gave the SAME outputs and digits on every clock (%0d different)", compared, cov_games, diffs));

    // ------------------------------------------------------------ T2
    begin_test(2, "T2 coverage");
    check(cov_dol999 > 0 && cov_tgt999 > 0 && cov_lvl99 > 0,
          $sformatf("reached the limits: 999 dollars (%0d clocks), target 999 (%0d), level 99 (%0d)", cov_dol999, cov_tgt999, cov_lvl99));
    check(cov_over_time > 0 && cov_over_key > 0,
          $sformatf("GAME OVER by the clock (%0d) and by keypad * (%0d)", cov_over_time, cov_over_key));
    check(cov_won_time > 0 && cov_won_key > 0 && cov_levelWon > 0,
          $sformatf("level won by the clock (%0d) and by keypad + (%0d), levelWon high on %0d clocks", cov_won_time, cov_won_key, cov_levelWon));
    begin
        int minSet; minSet = 1 << 30;
        for (int d = 0; d < 3; d++) for (int t = 0; t < 3; t++) if (cov_set[d][t] < minSet) minSet = cov_set[d][t];
        check(minSet > 0 && cov_red > 1000,
              $sformatf("all 9 difficulty x time settings were played (each at least %0d games), %0d clocks with red text pixels", minSet, cov_red));
    end

    // ------------------------------------------------------------ end
    t_end[2] = $realtime; test_no = 0;
    $sformat(test_name, "%s", (nFail == 0) ? "DONE - ALL PASSED" : "DONE - SEE FAILS");
    write_windows_file(2);
    $display("\n===== SUMMARY: %0d PASS, %0d FAIL  ->  %s =====",
             nPass, nFail, (nFail == 0) ? "ALL PASSED" : "FAILURES (red pulses on chk_fail)");
    $display("Simulation PAUSED (not closed). zt <n> zooms on test n.\n");
    $stop;
end

initial begin
    #2_000_000_000;
    $display("WATCHDOG: not finished after 2 s sim time - paused here, check test_name");
    $stop;
end
endmodule
